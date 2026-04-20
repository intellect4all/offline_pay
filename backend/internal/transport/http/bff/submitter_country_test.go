package bff

import (
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestRequestMetadata_CapturesSubmitterCountry(t *testing.T) {
	cases := []struct {
		name   string
		header string
		want   string
	}{
		{"absent", "", ""},
		{"plain", "NG", "NG"},
		{"lowercase", "gh", "GH"},
		{"padded", "  zw  ", "ZW"},
		{"whitespace only", "   ", ""},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			var got string
			h := RequestMetadata(http.HandlerFunc(func(_ http.ResponseWriter, r *http.Request) {
				got = SubmitterCountryFromContext(r.Context())
			}))
			req := httptest.NewRequest("POST", "/v1/settlement/claims", nil)
			if tc.header != "" {
				req.Header.Set(submitterCountryHeader, tc.header)
			}
			h.ServeHTTP(httptest.NewRecorder(), req)
			if got != tc.want {
				t.Fatalf("SubmitterCountryFromContext = %q, want %q", got, tc.want)
			}
		})
	}
}
