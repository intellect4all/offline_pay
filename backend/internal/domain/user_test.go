package domain

import (
	"errors"
	"testing"
)

func TestAccountNumberFromPhone(t *testing.T) {
	cases := []struct {
		name    string
		phone   string
		want    string
		wantErr error
	}{
		{"e164 nigerian", "+2348108678294", "8108678294", nil},
		{"national nigerian", "08108678294", "8108678294", nil},
		{"us number", "+15551234567", "", ErrUnsupportedPhoneFormat},
		{"empty", "", "", ErrUnsupportedPhoneFormat},
		{"nigerian too short", "+234810867829", "", ErrUnsupportedPhoneFormat},
		{"with spaces", "+234 810 867 8294", "8108678294", nil},
		{"with dashes", "0810-867-8294", "8108678294", nil},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			got, err := AccountNumberFromPhone(tc.phone)
			if tc.wantErr != nil {
				if !errors.Is(err, tc.wantErr) {
					t.Fatalf("want err %v, got %v", tc.wantErr, err)
				}
				return
			}
			if err != nil {
				t.Fatalf("unexpected error: %v", err)
			}
			if got != tc.want {
				t.Fatalf("want %q, got %q", tc.want, got)
			}
		})
	}
}
