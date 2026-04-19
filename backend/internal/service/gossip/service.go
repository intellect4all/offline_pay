// Package gossip implements the server-side gossip upload endpoint.
//
// A device carrying opaque gossip blobs periodically uploads them via the
// GossipUpload RPC. For each blob the server:
//
//   1. validates the blob envelope (hop limit, required fields);
//   2. opens the sealed box with the server's X25519 private key;
//   3. parses the plaintext as a canonical-JSON GossipInnerPayload containing
//      the full ceiling token, payment token, and the original recipient's
//      user id (the forwarder routing the claim);
//   4. routes the claim into the shared settlement code path
//      (settlement.SubmitClaim) so that idempotency on (payer_id,
//      sequence_number) absorbs duplicates.
//
// Bad blobs do not poison the batch — each one is reported individually.
package gossip

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"time"

	"github.com/intellect/offlinepay/internal/crypto"
	"github.com/intellect/offlinepay/internal/domain"
	"github.com/intellect/offlinepay/internal/service/settlement"
)

// Sentinel errors.
var (
	// ErrBadBlob wraps any validation / decrypt / parse failure for a
	// single blob. The surrounding batch continues.
	ErrBadBlob = errors.New("gossip: bad blob")
	// ErrBlobHopLimitExceeded is returned when an uploaded blob has
	// hop_count > MaxGossipHops.
	ErrBlobHopLimitExceeded = errors.New("gossip: blob hop limit exceeded")
)

// SealedBoxKey is one X25519 key pair in the gossip keyring. KeyID is an
// opaque string returned to clients alongside the public key so rotated
// deployments can observe which key a blob was sealed to. RetiredAt, when
// non-nil, marks this key as retired — still accepted for opening inbound
// blobs (until the operator deletes the keyfile after the overlap window)
// but never used to issue new seals.
type SealedBoxKey struct {
	KeyID     string
	Public    *[32]byte
	Private   *[32]byte
	RetiredAt *time.Time
}

// SealedBoxKeyring carries the server's active + retired X25519 key pairs.
// Current is used for GetServerSealedBoxPubkey (the key clients seal new
// blobs to). Previous holds retired keys still in the overlap window —
// they decrypt inbound blobs sealed under them before rotation, but the
// server never directs clients to seal new blobs to them.
//
// Compromise of any Private[] reveals all blobs ever sealed to that key.
// Forward secrecy against server-key compromise requires (a) rotation via
// rotate_sealedbox_key, (b) operators securely deleting retired keyfiles
// after the overlap window.
type SealedBoxKeyring struct {
	Current  SealedBoxKey
	Previous []SealedBoxKey
}

// SealedBoxKeys is a deprecated alias retained so existing call sites
// (tests, early bootstraps) can still pass a single pair. Prefer
// SealedBoxKeyring in new code.
type SealedBoxKeys struct {
	Public  *[32]byte
	Private *[32]byte
}

// Keyring converts a legacy single-pair shape into a one-entry keyring.
func (s SealedBoxKeys) Keyring() SealedBoxKeyring {
	return SealedBoxKeyring{Current: SealedBoxKey{KeyID: "sealed-box-1", Public: s.Public, Private: s.Private}}
}

// openWithKeyring tries each candidate key until one decrypts ciphertext.
// Returns the plaintext on first success or crypto.ErrBadSealedBox if none
// match.
func openWithKeyring(candidates []SealedBoxKey, ciphertext []byte) ([]byte, error) {
	for _, k := range candidates {
		pt, err := crypto.OpenAnonymous(k.Public, k.Private, ciphertext)
		if err == nil {
			return pt, nil
		}
	}
	return nil, crypto.ErrBadSealedBox
}

// all returns the keys to try on decrypt, Current first. Used by Upload.
func (r SealedBoxKeyring) all() []SealedBoxKey {
	out := make([]SealedBoxKey, 0, 1+len(r.Previous))
	if r.Current.Private != nil {
		out = append(out, r.Current)
	}
	out = append(out, r.Previous...)
	return out
}

// SettlementSubmitter is the narrow interface the gossip service depends
// on. The production *settlement.Service satisfies it via SubmitClaim.
type SettlementSubmitter interface {
	SubmitClaim(ctx context.Context, receiverUserID string, batch []settlement.ClaimItem, opts ...settlement.SubmitOption) (domain.SettlementBatch, []domain.SettlementResult, error)
}

// GossipInnerPayload is the plaintext inside a sealed gossip blob. It is
// encoded via the canonical JSON encoder so that Go-produced and
// Dart-produced payloads are byte-identical.
//
// SenderUserID is the user who originally received the payment (i.e. the
// payment's PayeeID at scan time). That user acts as the "receiver" the
// settlement service will credit when the claim is routed.
type GossipInnerPayload struct {
	CeilingToken domain.CeilingToken `json:"ceiling_token"`
	PaymentToken domain.PaymentToken `json:"payment_token"`
	SenderUserID string              `json:"sender_user_id"`
}

// Note: domain.CeilingToken does not carry JSON tags for every field; only
// the fields needed to reconstruct a valid ClaimItem need to cross the wire.
// We emit a reduced ceiling view in the inner payload via MarshalJSON.
// See CeilingTokenWire below.

// CeilingTokenWire is the on-wire representation of a ceiling token
// carried inside a gossip inner payload. It mirrors CeilingTokenPayload
// plus the bank signature and ceiling id that SubmitClaim needs.
type CeilingTokenWire struct {
	ID             string                      `json:"id"`
	Payload        domain.CeilingTokenPayload  `json:"payload"`
	BankSignature  []byte                      `json:"bank_signature"`
}

// WireInnerPayload is the canonicalized form used on the wire. We switched
// to this reduced form because domain.CeilingToken/PaymentToken contain
// DB-only fields (status, created_at, etc.) that vary across stores and
// would break byte-identical cross-lang canonicalization.
//
// Request is the receiver-issued PaymentRequest the payer counter-signed.
// SubmitClaim requires it to verify the (payer, receiver, amount,
// session_nonce) binding. Without it the gossip path routes to
// SubmitClaim with a zero-value Request and every blob gets rejected by
// settlement.ErrRequestReceiverMismatch.
type WireInnerPayload struct {
	Ceiling      CeilingTokenWire       `json:"ceiling"`
	Payment      domain.PaymentToken    `json:"payment"`
	Request      domain.PaymentRequest  `json:"request"`
	SenderUserID string                 `json:"sender_user_id"`
}

// EncodeInner canonicalizes a WireInnerPayload into its sealable bytes.
func EncodeInner(p WireInnerPayload) ([]byte, error) {
	return crypto.Canonicalize(p)
}

// DecodeInner parses canonical-JSON bytes into a WireInnerPayload.
// Uses encoding/json (any valid JSON produced by our canonical encoder
// is still valid JSON).
func DecodeInner(b []byte) (WireInnerPayload, error) {
	var w WireInnerPayload
	if err := json.Unmarshal(b, &w); err != nil {
		return WireInnerPayload{}, fmt.Errorf("gossip: decode inner: %w", err)
	}
	return w, nil
}

// UploadResult holds the per-blob outcome of an Upload call.
type UploadResult struct {
	// Accepted is the number of blobs whose inner payload was decrypted
	// and successfully forwarded to settlement (including idempotent
	// duplicates).
	Accepted int
	// Rejected is the number of blobs rejected for validation, hop limit,
	// or decrypt/parse failures.
	Rejected int
	// Items is the per-blob detail, in input order.
	Items []BlobResult
}

// BlobResult is the outcome for a single blob in an upload batch.
type BlobResult struct {
	// TransactionHash is the input blob's transaction hash (may be empty
	// if the blob failed validation before that field was read).
	TransactionHash []byte
	// Accepted is true iff the blob was decrypted and routed to
	// settlement. An accepted blob's settlement result (including
	// dedupe / rejection) is carried in SettlementResult.
	Accepted bool
	// Err is populated when Accepted is false.
	Err error
	// SettlementResult is the result returned by settlement.SubmitClaim
	// for the one claim derived from this blob. nil when Accepted=false.
	SettlementResult *domain.SettlementResult
}

// Service is the stateless gossip upload engine.
type Service struct {
	Settlement SettlementSubmitter
	Keyring    SealedBoxKeyring
}

// New constructs a Service. Accepts either a SealedBoxKeys (legacy
// single-pair) or a SealedBoxKeyring — the former is promoted to a
// one-entry keyring.
func New(sub SettlementSubmitter, keys any) *Service {
	var kr SealedBoxKeyring
	switch v := keys.(type) {
	case SealedBoxKeyring:
		kr = v
	case SealedBoxKeys:
		kr = v.Keyring()
	default:
		panic(fmt.Sprintf("gossip.New: unsupported key type %T", keys))
	}
	return &Service{Settlement: sub, Keyring: kr}
}

// Upload processes a batch of gossip blobs from `uploaderUserID`. One bad
// blob does not abort the batch — errors are attached per-blob.
//
// `uploaderUserID` is the device currently carrying the blob; it is NOT
// necessarily the receiver of the original transaction. The actual
// receiver (the user who will be credited) is carried inside the
// decrypted inner payload as SenderUserID.
//TODO no record of this upload is kept, no auditing anywhere? ALso, the function can optimized with goroutines
func (s *Service) Upload(ctx context.Context, uploaderUserID string, blobs []domain.GossipBlob) (*UploadResult, error) {
	candidates := s.Keyring.all()
	if len(candidates) == 0 {
		return nil, errors.New("gossip: sealed-box keys not configured")
	}
	out := &UploadResult{Items: make([]BlobResult, 0, len(blobs))}

	for _, blob := range blobs {
		res := BlobResult{TransactionHash: blob.TransactionHash}

		if err := blob.Validate(); err != nil {
			res.Err = errors.Join(ErrBadBlob, err)
			out.Rejected++
			out.Items = append(out.Items, res)
			continue
		}
		if blob.HopCount > domain.MaxGossipHops {
			res.Err = ErrBlobHopLimitExceeded
			out.Rejected++
			out.Items = append(out.Items, res)
			continue
		}

		pt, err := openWithKeyring(candidates, blob.EncryptedBlob)
		if err != nil {
			res.Err = errors.Join(ErrBadBlob, err)
			out.Rejected++
			out.Items = append(out.Items, res)
			continue
		}

		inner, err := DecodeInner(pt)
		if err != nil {
			res.Err = errors.Join(ErrBadBlob, err)
			out.Rejected++
			out.Items = append(out.Items, res)
			continue
		}

		// Reconstruct a CeilingToken for the settlement ClaimItem.
		ct := domain.CeilingToken{
			ID:             inner.Ceiling.ID,
			PayerID:        inner.Ceiling.Payload.PayerID,
			CeilingAmount:  inner.Ceiling.Payload.CeilingAmount,
			IssuedAt:       inner.Ceiling.Payload.IssuedAt,
			ExpiresAt:      inner.Ceiling.Payload.ExpiresAt,
			SequenceStart:  inner.Ceiling.Payload.SequenceStart,
			PayerPublicKey: inner.Ceiling.Payload.PayerPublicKey,
			BankKeyID:      inner.Ceiling.Payload.BankKeyID,
			BankSignature:  inner.Ceiling.BankSignature,
		}

		receiverUserID := inner.SenderUserID
		if receiverUserID == "" {
			receiverUserID = inner.Payment.PayeeID
		}

		_, results, err := s.Settlement.SubmitClaim(ctx, receiverUserID, []settlement.ClaimItem{
			{Payment: inner.Payment, Ceiling: ct, Request: inner.Request},
		})
		if err != nil {
			// Infrastructure error — surface as per-blob failure so caller
			// can retry later; don't kill the batch.
			res.Err = fmt.Errorf("gossip: settlement submit: %w", err)
			out.Rejected++
			out.Items = append(out.Items, res)
			continue
		}
		res.Accepted = true
		if len(results) > 0 {
			rr := results[0]
			res.SettlementResult = &rr
		}
		out.Accepted++
		out.Items = append(out.Items, res)
	}
	return out, nil
}
