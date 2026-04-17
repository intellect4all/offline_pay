package domain

import (
	"errors"
	"regexp"
	"strings"
)

// ErrUnsupportedPhoneFormat is returned when a phone cannot be mapped to a
// 10-digit Nigerian account number.
var ErrUnsupportedPhoneFormat = errors.New("domain: unsupported phone format")

var phoneE164Re = regexp.MustCompile(`^\+?[0-9]{7,15}$`)

// AccountNumberFromPhone derives a 10-digit account number from a phone
// number. Supports Nigerian formats only: +234XXXXXXXXXX (E.164) or
// 0XXXXXXXXXX (national trunk). Non-Nigerian numbers return
// ErrUnsupportedPhoneFormat.
func AccountNumberFromPhone(phone string) (string, error) {
	normalized := strings.ReplaceAll(phone, " ", "")
	normalized = strings.ReplaceAll(normalized, "-", "")
	if normalized == "" {
		return "", ErrUnsupportedPhoneFormat
	}
	if !phoneE164Re.MatchString(normalized) {
		return "", ErrUnsupportedPhoneFormat
	}
	if strings.HasPrefix(normalized, "+234") {
		rest := normalized[len("+234"):]
		if len(rest) != 10 {
			return "", ErrUnsupportedPhoneFormat
		}
		return rest, nil
	}
	if strings.HasPrefix(normalized, "0") && len(normalized) == 11 {
		return normalized[1:], nil
	}
	return "", ErrUnsupportedPhoneFormat
}
