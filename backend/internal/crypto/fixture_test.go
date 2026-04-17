//go:build fixtures

// Emit the cross-language compatibility fixture consumed by the Dart core
// package's test suite. Run with:
//
//	go test -tags=fixtures ./internal/crypto/...
//
// This is a test so it runs under `go test`, but it does no assertions — it
// writes a single JSON file at a fixed path and returns.
package crypto

import (
	"bytes"
	"crypto/ed25519"
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"encoding/json"
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/intellect/offlinepay/internal/domain"
	"github.com/intellect/offlinepay/pkg/qr"

	boxgen "golang.org/x/crypto/nacl/box"
)

type fixture struct {
	// Canonical encoding: one handwritten sample echoed to confirm both
	// sides agree on key ordering, byte escaping, time formatting, etc.
	Canonical fixtureCanonical `json:"canonical"`
	// Ceiling signing fixture.
	Ceiling fixtureCeiling `json:"ceiling"`
	// Payment signing fixture.
	Payment fixturePayment `json:"payment"`
	// AES-GCM encryption fixture with known key/nonce/plaintext/ciphertext.
	AESGCM fixtureAESGCM `json:"aes_gcm"`
	// Chunked QR frame sequence.
	Frames fixtureFrames `json:"frames"`
	// Gossip inner-payload + sealed-box fixture.
	Gossip fixtureGossip `json:"gossip"`
}

type fixtureGossip struct {
	// The canonically-encoded inner payload bytes (UTF-8 string).
	CanonicalInner string `json:"canonical_inner"`
	// Sealed-box ciphertext of the inner payload (server X25519 key).
	CiphertextB64 string `json:"ciphertext_b64"`
	// Server X25519 key pair used for the fixture.
	ServerPubB64  string `json:"server_public_key_b64"`
	ServerPrivB64 string `json:"server_private_key_b64"`
	// Expected SHA-256 over the canonical inner payload → transaction_hash.
	TransactionHashB64 string `json:"transaction_hash_b64"`
	// Expected SHA-256 over the canonical ceiling payload → ceiling_token_hash.
	CeilingTokenHashB64 string `json:"ceiling_token_hash_b64"`
	// The inner payload in readable form for debugging.
	Inner json.RawMessage `json:"inner"`
}

type fixtureCanonical struct {
	Input     json.RawMessage `json:"input"`     // JSON value to canonicalize
	Canonical string          `json:"canonical"` // expected canonical bytes (UTF-8 string)
}

type fixtureCeiling struct {
	Payload     json.RawMessage `json:"payload"`
	Canonical   string          `json:"canonical"` // canonical JSON of payload
	Signature   string          `json:"signature_b64"`
	BankPubKey  string          `json:"bank_public_key_b64"`
	BankPrivKey string          `json:"bank_private_key_b64"` // useful for round-trip tests
}

type fixturePayment struct {
	Payload      json.RawMessage `json:"payload"`
	Canonical    string          `json:"canonical"`
	Signature    string          `json:"signature_b64"`
	PayerPubKey  string          `json:"payer_public_key_b64"`
	PayerPrivKey string          `json:"payer_private_key_b64"`
}

type fixtureAESGCM struct {
	KeyB64        string `json:"key_b64"`
	NonceB64      string `json:"nonce_b64"`
	PlaintextB64  string `json:"plaintext_b64"`
	AadB64        string `json:"aad_b64"`
	CiphertextB64 string `json:"ciphertext_b64"` // ciphertext || tag (Go format)
}

type fixtureFrame struct {
	Kind        int    `json:"kind"`
	Index       uint32 `json:"index"`
	TotalFrames uint32 `json:"total_frames"`
	Protocol    uint16 `json:"protocol"`
	ContentType string `json:"content_type"`
	PayloadB64  string `json:"payload_b64"`
	EncodedB64  string `json:"encoded_b64"`
}

type fixtureFrames struct {
	Content     string         `json:"content_b64"`
	ContentType string         `json:"content_type"`
	ChunkSize   int            `json:"chunk_size"`
	Frames      []fixtureFrame `json:"frames"`
}

func TestEmitCrossLangFixture(t *testing.T) {
	// Canonical sample.
	canonIn := map[string]any{
		"b": 2,
		"a": 1,
		"nested": map[string]any{
			"z": []any{3, 2, 1},
			"a": "hello",
		},
	}
	canonInJSON, err := json.Marshal(canonIn)
	if err != nil {
		t.Fatal(err)
	}
	canonBytes, err := Canonicalize(canonIn)
	if err != nil {
		t.Fatal(err)
	}

	// Ceiling signing.
	bankPub, bankPriv, err := ed25519.GenerateKey(rand.Reader)
	if err != nil {
		t.Fatal(err)
	}
	payerPub, payerPriv, err := ed25519.GenerateKey(rand.Reader)
	if err != nil {
		t.Fatal(err)
	}
	issued := time.Date(2026, 4, 13, 12, 0, 0, 0, time.UTC)
	expires := issued.Add(24 * time.Hour)
	ceiling := domain.CeilingTokenPayload{
		PayerID:        "user_abc123",
		CeilingAmount:  500000, // kobo
		IssuedAt:       issued,
		ExpiresAt:      expires,
		SequenceStart:  1,
		PayerPublicKey: payerPub,
		BankKeyID:      "bank_key_1",
	}
	ceilingJSON, err := json.Marshal(ceiling)
	if err != nil {
		t.Fatal(err)
	}
	ceilingCanon, err := Canonicalize(ceiling)
	if err != nil {
		t.Fatal(err)
	}
	ceilingSig, err := SignCeiling(bankPriv, ceiling)
	if err != nil {
		t.Fatal(err)
	}

	// Payment signing.
	sessionNonce := bytes.Repeat([]byte{0xAA}, domain.SessionNonceSize)
	requestHash := bytes.Repeat([]byte{0xCC}, 32)
	payment := domain.PaymentPayload{
		PayerID:          "user_abc123",
		PayeeID:          "user_xyz789",
		Amount:           25000,
		SequenceNumber:   1,
		RemainingCeiling: 475000,
		Timestamp:        issued.Add(5 * time.Minute),
		CeilingTokenID:   "ceil_1",
		SessionNonce:     sessionNonce,
		RequestHash:      requestHash,
	}
	paymentJSON, err := json.Marshal(payment)
	if err != nil {
		t.Fatal(err)
	}
	paymentCanon, err := Canonicalize(payment)
	if err != nil {
		t.Fatal(err)
	}
	paymentSig, err := SignPayment(payerPriv, payment)
	if err != nil {
		t.Fatal(err)
	}

	// AES-GCM.
	aesKey := bytes.Repeat([]byte{0x42}, 32)
	aesNonce := []byte{0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11}
	aesPT := []byte("cross-lang AES-GCM plaintext 0123456789")
	aesAD := []byte("fixture-ad")
	aesCT, err := Seal(aesKey, aesNonce, aesPT, aesAD)
	if err != nil {
		t.Fatal(err)
	}

	// QR frames.
	content := make([]byte, 3500)
	for i := range content {
		content[i] = byte(i * 7)
	}
	frames, err := qr.Chunk(content, 1024, "payment")
	if err != nil {
		t.Fatal(err)
	}
	fixtureFramesOut := make([]fixtureFrame, 0, len(frames))
	for _, f := range frames {
		fixtureFramesOut = append(fixtureFramesOut, fixtureFrame{
			Kind:        int(f.Kind),
			Index:       f.Index,
			TotalFrames: f.TotalFrames,
			Protocol:    f.Protocol,
			ContentType: f.ContentType,
			PayloadB64:  base64.StdEncoding.EncodeToString(f.Payload),
			EncodedB64:  base64.StdEncoding.EncodeToString(qr.Encode(f)),
		})
	}

	// Gossip inner payload + sealed box. Use a deterministic server X25519
	// keypair derived from a fixed seed so the fixture is reproducible.
	// box.GenerateKey normally reads from an io.Reader; we feed it a
	// constant stream.
	serverPub, serverPriv, err := generateDeterministicX25519([32]byte{
		1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16,
		17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32,
	})
	if err != nil {
		t.Fatal(err)
	}
	// Inner payload — uses an inline wire struct mirroring the one in
	// internal/service/gossip.WireInnerPayload. Kept inline here to avoid
	// an import cycle (crypto is lower-level than service/gossip).
	type ceilingTokenWire struct {
		ID            string                     `json:"id"`
		Payload       domain.CeilingTokenPayload `json:"payload"`
		BankSignature []byte                     `json:"bank_signature"`
	}
	type wireInner struct {
		Ceiling      ceilingTokenWire       `json:"ceiling"`
		Payment      domain.PaymentToken    `json:"payment"`
		Request      domain.PaymentRequest  `json:"request"`
		SenderUserID string                 `json:"sender_user_id"`
	}
	paymentTok := domain.PaymentToken{
		PayerID:          payment.PayerID,
		PayeeID:          payment.PayeeID,
		Amount:           payment.Amount,
		SequenceNumber:   payment.SequenceNumber,
		RemainingCeiling: payment.RemainingCeiling,
		Timestamp:        payment.Timestamp,
		CeilingTokenID:   payment.CeilingTokenID,
		SessionNonce:     payment.SessionNonce,
		RequestHash:      payment.RequestHash,
		PayerSignature:   paymentSig,
	}
	// PaymentRequest signing (receiver-issued invoice). Needed in the
	// gossip inner payload so the backend's SubmitClaim can verify the
	// (payer, receiver, amount, session_nonce) binding when a claim
	// arrives via the gossip channel.
	recvDevicePub, recvDevicePriv, err := ed25519.GenerateKey(rand.Reader)
	if err != nil {
		t.Fatal(err)
	}
	_ = recvDevicePub
	displayCardPayload := domain.DisplayCardPayload{
		UserID:        payment.PayeeID,
		DisplayName:   "Fixture Receiver",
		AccountNumber: "0000000001",
		IssuedAt:      issued,
		BankKeyID:     ceiling.BankKeyID,
	}
	displayCardSig, err := SignDisplayCard(bankPriv, displayCardPayload)
	if err != nil {
		t.Fatal(err)
	}
	displayCard := domain.DisplayCard{
		UserID:          displayCardPayload.UserID,
		DisplayName:     displayCardPayload.DisplayName,
		AccountNumber:   displayCardPayload.AccountNumber,
		IssuedAt:        displayCardPayload.IssuedAt,
		BankKeyID:       displayCardPayload.BankKeyID,
		ServerSignature: displayCardSig,
	}
	requestPayload := domain.PaymentRequestPayload{
		ReceiverID:           payment.PayeeID,
		ReceiverDisplayCard:  displayCard,
		Amount:               payment.Amount,
		SessionNonce:         sessionNonce,
		IssuedAt:             issued,
		ExpiresAt:            issued.Add(10 * time.Minute),
		ReceiverDevicePubkey: recvDevicePub,
	}
	requestSig, err := SignRequest(recvDevicePriv, requestPayload)
	if err != nil {
		t.Fatal(err)
	}
	paymentRequest := domain.PaymentRequest{
		ReceiverID:           requestPayload.ReceiverID,
		ReceiverDisplayCard:  requestPayload.ReceiverDisplayCard,
		Amount:               requestPayload.Amount,
		SessionNonce:         requestPayload.SessionNonce,
		IssuedAt:             requestPayload.IssuedAt,
		ExpiresAt:            requestPayload.ExpiresAt,
		ReceiverDevicePubkey: requestPayload.ReceiverDevicePubkey,
		ReceiverSignature:    requestSig,
	}
	inner := wireInner{
		Ceiling: ceilingTokenWire{
			ID:            "ceil_fix_1",
			Payload:       ceiling,
			BankSignature: ceilingSig,
		},
		Payment:      paymentTok,
		Request:      paymentRequest,
		SenderUserID: payment.PayeeID,
	}
	innerCanon, err := Canonicalize(inner)
	if err != nil {
		t.Fatal(err)
	}
	innerJSON, err := json.Marshal(inner)
	if err != nil {
		t.Fatal(err)
	}
	sealedCT, err := SealAnonymous(serverPub, innerCanon)
	if err != nil {
		t.Fatal(err)
	}
	// Sanity round-trip: decrypt and compare.
	got, err := OpenAnonymous(serverPub, serverPriv, sealedCT)
	if err != nil {
		t.Fatalf("self-open failed: %v", err)
	}
	if !bytes.Equal(got, innerCanon) {
		t.Fatal("fixture sealed box did not round-trip")
	}
	txHash := sha256.Sum256(innerCanon)
	ctHash := sha256.Sum256(ceilingCanon)

	fix := fixture{
		Canonical: fixtureCanonical{
			Input:     canonInJSON,
			Canonical: string(canonBytes),
		},
		Ceiling: fixtureCeiling{
			Payload:     ceilingJSON,
			Canonical:   string(ceilingCanon),
			Signature:   base64.StdEncoding.EncodeToString(ceilingSig),
			BankPubKey:  base64.StdEncoding.EncodeToString(bankPub),
			BankPrivKey: base64.StdEncoding.EncodeToString(bankPriv),
		},
		Payment: fixturePayment{
			Payload:      paymentJSON,
			Canonical:    string(paymentCanon),
			Signature:    base64.StdEncoding.EncodeToString(paymentSig),
			PayerPubKey:  base64.StdEncoding.EncodeToString(payerPub),
			PayerPrivKey: base64.StdEncoding.EncodeToString(payerPriv),
		},
		AESGCM: fixtureAESGCM{
			KeyB64:        base64.StdEncoding.EncodeToString(aesKey),
			NonceB64:      base64.StdEncoding.EncodeToString(aesNonce),
			PlaintextB64:  base64.StdEncoding.EncodeToString(aesPT),
			AadB64:        base64.StdEncoding.EncodeToString(aesAD),
			CiphertextB64: base64.StdEncoding.EncodeToString(aesCT),
		},
		Frames: fixtureFrames{
			Content:     base64.StdEncoding.EncodeToString(content),
			ContentType: "payment",
			ChunkSize:   1024,
			Frames:      fixtureFramesOut,
		},
		Gossip: fixtureGossip{
			CanonicalInner:      string(innerCanon),
			CiphertextB64:       base64.StdEncoding.EncodeToString(sealedCT),
			ServerPubB64:        base64.StdEncoding.EncodeToString(serverPub[:]),
			ServerPrivB64:       base64.StdEncoding.EncodeToString(serverPriv[:]),
			TransactionHashB64:  base64.StdEncoding.EncodeToString(txHash[:]),
			CeilingTokenHashB64: base64.StdEncoding.EncodeToString(ctHash[:]),
			Inner:               innerJSON,
		},
	}

	out, err := json.MarshalIndent(fix, "", "  ")
	if err != nil {
		t.Fatal(err)
	}

	// Write relative to the repo root. This test file lives at
	// backend/internal/crypto/; the fixture target is
	// mobile/packages/core/test/fixtures/crosslang.json.
	target, err := filepath.Abs(filepath.Join(
		"..", "..", "..",
		"mobile", "packages", "core", "test", "fixtures", "crosslang.json",
	))
	if err != nil {
		t.Fatal(err)
	}
	if err := os.MkdirAll(filepath.Dir(target), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(target, out, 0o644); err != nil {
		t.Fatal(err)
	}
	t.Logf("wrote fixture: %s (%d bytes)", target, len(out))
}

// generateDeterministicX25519 returns an X25519 keypair seeded from
// the supplied 32 bytes. Uses box.GenerateKey with a constant reader
// so fixture output is stable across runs.
func generateDeterministicX25519(seed [32]byte) (*[32]byte, *[32]byte, error) {
	return boxgen.GenerateKey(&constReader{seed: seed})
}

// constReader is a deterministic io.Reader that emits a repeating seed.
type constReader struct {
	seed [32]byte
	pos  int
}

func (r *constReader) Read(p []byte) (int, error) {
	for i := range p {
		p[i] = r.seed[r.pos%32]
		r.pos++
	}
	return len(p), nil
}
