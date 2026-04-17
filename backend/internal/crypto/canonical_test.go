package crypto

import (
	"bytes"
	"testing"
	"time"
)

func TestCanonicalizeSortsKeys(t *testing.T) {
	v := map[string]any{"b": 2, "a": 1, "c": 3}
	got, err := Canonicalize(v)
	if err != nil {
		t.Fatal(err)
	}
	want := []byte(`{"a":1,"b":2,"c":3}`)
	if !bytes.Equal(got, want) {
		t.Errorf("got %s, want %s", got, want)
	}
}

func TestCanonicalizeNested(t *testing.T) {
	type inner struct {
		Z int `json:"z"`
		A int `json:"a"`
	}
	type outer struct {
		M inner `json:"m"`
		K int   `json:"k"`
	}
	got, err := Canonicalize(outer{M: inner{Z: 1, A: 2}, K: 3})
	if err != nil {
		t.Fatal(err)
	}
	want := []byte(`{"k":3,"m":{"a":2,"z":1}}`)
	if !bytes.Equal(got, want) {
		t.Errorf("got %s, want %s", got, want)
	}
}

func TestCanonicalizeDeterministic(t *testing.T) {
	type payload struct {
		ID     string    `json:"id"`
		When   time.Time `json:"when"`
		Amount int64     `json:"amount"`
		Bytes  []byte    `json:"bytes"`
	}
	p := payload{
		ID:     "user_1",
		When:   time.Date(2026, 4, 13, 12, 0, 0, 0, time.UTC),
		Amount: 50000,
		Bytes:  []byte{0x01, 0x02, 0x03},
	}
	a, err := Canonicalize(p)
	if err != nil {
		t.Fatal(err)
	}
	for range 50 {
		b, err := Canonicalize(p)
		if err != nil {
			t.Fatal(err)
		}
		if !bytes.Equal(a, b) {
			t.Fatalf("non-deterministic: %s vs %s", a, b)
		}
	}
}

func TestCanonicalizeBytesBase64(t *testing.T) {
	v := map[string]any{"k": []byte{0xff, 0x00, 0x7f}}
	got, err := Canonicalize(v)
	if err != nil {
		t.Fatal(err)
	}
	// json.Marshal encodes []byte as standard base64.
	want := []byte(`{"k":"/wB/"}`)
	if !bytes.Equal(got, want) {
		t.Errorf("got %s, want %s", got, want)
	}
}
