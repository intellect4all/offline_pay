package domain

import "errors"

// MaxGossipHops is the maximum number of hops a gossip blob may traverse
// before being dropped. Limits propagation amplification.
const MaxGossipHops = 3

// GossipBlob is an encrypted transaction blob carried by devices for
// propagation through the gossip network. Carriers cannot decrypt the blob;
// only the settlement server can.
type GossipBlob struct {
	// TransactionHash is the SHA-256 digest of the plaintext transaction.
	// Used for deduplication across devices.
	TransactionHash []byte `json:"transaction_hash"`
	// EncryptedBlob is the transaction JSON sealed with the server's X25519
	// public key via libsodium crypto_box_seal.
	EncryptedBlob []byte `json:"encrypted_blob"`
	// BankSignature copies the bank signature from the originating ceiling
	// token, letting carriers verify authenticity without decrypting.
	BankSignature []byte `json:"bank_signature"`
	// CeilingTokenHash is the SHA-256 digest of the originating ceiling token.
	CeilingTokenHash []byte `json:"ceiling_token_hash"`
	// HopCount is the number of times this blob has been propagated. Capped
	// at MaxGossipHops.
	HopCount int `json:"hop_count"`
	// BlobSize is the byte length of EncryptedBlob.
	BlobSize int `json:"blob_size"`
}

// ErrInvalidGossipBlob is returned by GossipBlob.Validate.
var ErrInvalidGossipBlob = errors.New("invalid gossip blob")

// Validate checks hop limits, blob size, and required hashes.
func (b GossipBlob) Validate() error {
	if b.HopCount < 0 {
		return errors.Join(ErrInvalidGossipBlob, errors.New("hop_count must be non-negative"))
	}
	if b.HopCount > MaxGossipHops {
		return errors.Join(ErrInvalidGossipBlob, errors.New("hop_count exceeds MaxGossipHops"))
	}
	if b.BlobSize <= 0 {
		return errors.Join(ErrInvalidGossipBlob, errors.New("blob_size must be positive"))
	}
	if len(b.EncryptedBlob) == 0 {
		return errors.Join(ErrInvalidGossipBlob, errors.New("encrypted_blob required"))
	}
	if len(b.EncryptedBlob) != b.BlobSize {
		return errors.Join(ErrInvalidGossipBlob, errors.New("blob_size must match encrypted_blob length"))
	}
	if len(b.TransactionHash) == 0 {
		return errors.Join(ErrInvalidGossipBlob, errors.New("transaction_hash required"))
	}
	if len(b.CeilingTokenHash) == 0 {
		return errors.Join(ErrInvalidGossipBlob, errors.New("ceiling_token_hash required"))
	}
	if len(b.BankSignature) == 0 {
		return errors.Join(ErrInvalidGossipBlob, errors.New("bank_signature required"))
	}
	return nil
}

// GossipManifest is the compact list of transaction hashes a device carries.
// Devices exchange manifests to compute deltas and avoid redundant transfer.
type GossipManifest struct {
	// DeviceID identifies the carrying device.
	DeviceID string
	// TransactionHashes is the set of SHA-256 transaction hashes held.
	TransactionHashes [][]byte
}

// GossipPayload is the full payload embedded in an animated QR stream:
// a direct payment plus any accumulated gossip blobs.
type GossipPayload struct {
	// PaymentToken is the direct payment (payer → merchant).
	PaymentToken PaymentToken
	// CeilingToken is the ceiling payload backing the direct payment.
	CeilingToken CeilingTokenPayload
	// Blobs are accumulated encrypted gossip blobs, opaque to the merchant.
	Blobs []GossipBlob
}

// GossipEnvelope is the realm-key-encrypted plaintext carried inside the
// animated QR frames. It pairs the direct payer→merchant payment token
// with any accumulated (opaque) gossip blobs the payer is forwarding.
//
// After decoding (outer AES-GCM open with the realm key), the merchant
// extracts PaymentToken for settlement and places Blobs in its local
// CarryCache for eventual GossipUpload (or re-embedding in its own
// outgoing QR). Blobs remain sealed to the server X25519 key; carriers
// never decrypt them.
//
// The Go and Dart implementations MUST produce byte-identical canonical
// encodings so that payloads fit the same QR envelope regardless of who
// generated them.
type GossipEnvelope struct {
	// PaymentToken is the direct payment (payer → receiver).
	PaymentToken PaymentToken `json:"payment_token"`
	// Blobs is the list of sealed gossip blobs the payer is forwarding.
	// May be empty for the first hop.
	Blobs []GossipBlob `json:"blobs"`
}
