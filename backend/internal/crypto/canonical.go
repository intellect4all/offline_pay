// Package crypto provides the cryptographic primitives used across the
// offlinepay system: Ed25519 token signing, AES-256-GCM realm-key encryption,
// X25519 sealed-box envelopes for gossip, and a stable canonical encoder so
// that signatures verify byte-for-byte across the Go backend and the Dart
// client.
package crypto

import (
	"bytes"
	"encoding/json"
	"fmt"
	"sort"
)

// Canonicalize returns a deterministic JSON encoding of v with lexicographically
// sorted object keys and no insignificant whitespace. Byte slices are base64
// encoded (standard alphabet, with padding) via encoding/json defaults.
// time.Time values are emitted as RFC3339Nano strings via encoding/json defaults.
//
// Callers MUST use this encoder for any bytes that will be signed or verified.
// The Dart port applies the identical rules so that Ed25519 signatures match.
func Canonicalize(v any) ([]byte, error) {
	raw, err := json.Marshal(v)
	if err != nil {
		return nil, fmt.Errorf("canonical: marshal: %w", err)
	}
	var generic any
	dec := json.NewDecoder(bytes.NewReader(raw))
	dec.UseNumber()
	if err := dec.Decode(&generic); err != nil {
		return nil, fmt.Errorf("canonical: decode: %w", err)
	}
	var buf bytes.Buffer
	if err := writeCanonical(&buf, generic); err != nil {
		return nil, err
	}
	return buf.Bytes(), nil
}

func writeCanonical(buf *bytes.Buffer, v any) error {
	switch t := v.(type) {
	case nil:
		buf.WriteString("null")
	case bool:
		if t {
			buf.WriteString("true")
		} else {
			buf.WriteString("false")
		}
	case json.Number:
		buf.WriteString(t.String())
	case string:
		enc, err := json.Marshal(t)
		if err != nil {
			return err
		}
		buf.Write(enc)
	case []any:
		buf.WriteByte('[')
		for i, el := range t {
			if i > 0 {
				buf.WriteByte(',')
			}
			if err := writeCanonical(buf, el); err != nil {
				return err
			}
		}
		buf.WriteByte(']')
	case map[string]any:
		keys := make([]string, 0, len(t))
		for k := range t {
			keys = append(keys, k)
		}
		sort.Strings(keys)
		buf.WriteByte('{')
		for i, k := range keys {
			if i > 0 {
				buf.WriteByte(',')
			}
			keyBytes, err := json.Marshal(k)
			if err != nil {
				return err
			}
			buf.Write(keyBytes)
			buf.WriteByte(':')
			if err := writeCanonical(buf, t[k]); err != nil {
				return err
			}
		}
		buf.WriteByte('}')
	default:
		return fmt.Errorf("canonical: unsupported type %T", v)
	}
	return nil
}
