package crypto

import (
	"bytes"
	"encoding/json"
	"testing"
)

func FuzzCanonicalize(f *testing.F) {
	seeds := []string{
		`{"a":1,"b":2}`,
		`{"b":2,"a":1}`,
		`[1,2,3]`,
		`{"nested":{"y":[true,false,null],"x":"s"}}`,
		`"hello"`,
		`123.456`,
		`null`,
	}
	for _, s := range seeds {
		f.Add([]byte(s))
	}

	f.Fuzz(func(t *testing.T, raw []byte) {
		var v any
		if err := json.Unmarshal(raw, &v); err != nil {
			return
		}
		out1, err := Canonicalize(v)
		if err != nil {
			t.Fatalf("canonicalize: %v on %q", err, raw)
		}
		out2, err := Canonicalize(v)
		if err != nil {
			t.Fatalf("canonicalize 2: %v", err)
		}
		if !bytes.Equal(out1, out2) {
			t.Fatalf("non-deterministic: %q vs %q", out1, out2)
		}
		var v2 any
		if err := json.Unmarshal(out1, &v2); err != nil {
			t.Fatalf("output not valid JSON: %v (%q)", err, out1)
		}
		out3, err := Canonicalize(v2)
		if err != nil {
			t.Fatalf("re-canonicalize: %v", err)
		}
		if !bytes.Equal(out1, out3) {
			t.Fatalf("not idempotent: %q vs %q", out1, out3)
		}
	})
}
