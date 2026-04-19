// Package kyc is the user-facing KYC service. Users submit their NIN
// to reach TIER_2 and their BVN to reach TIER_3. Admin retains a
// read-only view via adminrepo.
//
// Mock verification model:
//
//   For a phone like "+2348012345678" we strip to digits and take the
//   last 8. Then:
//
//     NIN = "333" + last8   → promotes to TIER_2
//     BVN = "222" + last8   → promotes to TIER_3
//
//   Any other value is REJECTED with a reason. This keeps CI hermetic
//   while matching production's pattern: the real service would call
//   out to NIMC / NIBSS.
package kyc

import (
	"context"
	"crypto/rand"
	"errors"
	"fmt"
	"strings"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/oklog/ulid/v2"

	"github.com/intellect/offlinepay/internal/cache"
	"github.com/intellect/offlinepay/internal/repository/kycrepo"
)

const (
	IDTypeNIN = "NIN"
	IDTypeBVN = "BVN"

	statusVerified = "VERIFIED"
	statusRejected = "REJECTED"

	TierTwo   = "TIER_2"
	TierThree = "TIER_3"
)

var (
	ErrUserNotFound = errors.New("kyc: user not found")
	ErrInvalidInput = errors.New("kyc: invalid input")
)

type Service struct {
	Repo *kycrepo.Repo
}

func New(pool *pgxpool.Pool, c cache.Cache) *Service {
	return &Service{Repo: kycrepo.New(pool, c)}
}

// Submission is the user-facing projection.
type Submission struct {
	ID              string     `json:"id"`
	UserID          string     `json:"user_id"`
	IDType          string     `json:"id_type"`
	IDNumber        string     `json:"id_number"`
	Status          string     `json:"status"`
	RejectionReason *string    `json:"rejection_reason"`
	TierGranted     *string    `json:"tier_granted"`
	SubmittedBy     *string    `json:"submitted_by"`
	SubmittedAt     time.Time  `json:"submitted_at"`
	VerifiedAt      *time.Time `json:"verified_at"`
}

// Submit is the user-facing entry point. SubmittedByID == UserID since
// the user submits on their own behalf (admin no longer does this).
func (s *Service) Submit(ctx context.Context, userID, idType, idNumber string) (Submission, error) {
	var zero Submission
	idType = strings.ToUpper(strings.TrimSpace(idType))
	idNumber = strings.TrimSpace(idNumber)
	if idType != IDTypeNIN && idType != IDTypeBVN {
		return zero, fmt.Errorf("%w: id_type must be NIN or BVN", ErrInvalidInput)
	}
	if len(idNumber) != 11 || !allDigits(idNumber) {
		return zero, fmt.Errorf("%w: id_number must be 11 digits", ErrInvalidInput)
	}

	uc, err := s.Repo.GetUserContext(ctx, userID)
	if err != nil {
		if errors.Is(err, kycrepo.ErrNotFound) {
			return zero, ErrUserNotFound
		}
		return zero, err
	}

	expected, err := Expected(uc.Phone, idType)
	if err != nil {
		return zero, err
	}

	status := statusVerified
	var rejectionReason *string
	var tierGranted *string
	var verifiedAt *time.Time
	if idNumber != expected {
		status = statusRejected
		r := "id_number does not match expected pattern for this user"
		rejectionReason = &r
	} else {
		now := time.Now().UTC()
		verifiedAt = &now
		t := tierFor(idType)
		tierGranted = &t
	}

	sub := Submission{
		ID:              newID(),
		UserID:          userID,
		IDType:          idType,
		IDNumber:        idNumber,
		Status:          status,
		RejectionReason: rejectionReason,
		TierGranted:     tierGranted,
		SubmittedBy:     &userID,
		VerifiedAt:      verifiedAt,
	}

	submittedAt, err := s.Repo.Submit(ctx, kycrepo.SubmissionInput{
		ID:              sub.ID,
		UserID:          sub.UserID,
		IDType:          sub.IDType,
		IDNumber:        sub.IDNumber,
		Status:          sub.Status,
		RejectionReason: sub.RejectionReason,
		TierGranted:     sub.TierGranted,
		SubmittedBy:     sub.SubmittedBy,
		VerifiedAt:      sub.VerifiedAt,
	})
	if err != nil {
		return zero, err
	}
	sub.SubmittedAt = submittedAt
	return sub, nil
}

// List returns a user's KYC submission history, newest-first.
func (s *Service) List(ctx context.Context, userID string) ([]Submission, error) {
	rows, err := s.Repo.ListByUser(ctx, userID)
	if err != nil {
		return nil, err
	}
	out := make([]Submission, 0, len(rows))
	for _, r := range rows {
		out = append(out, Submission{
			ID:              r.ID,
			UserID:          r.UserID,
			IDType:          r.IDType,
			IDNumber:        r.IDNumber,
			Status:          r.Status,
			RejectionReason: r.RejectionReason,
			TierGranted:     r.TierGranted,
			SubmittedBy:     r.SubmittedBy,
			SubmittedAt:     r.SubmittedAt,
			VerifiedAt:      r.VerifiedAt,
		})
	}
	return out, nil
}

// Hint returns the deterministic mock expected values for the given
// user, intended for dev/tester UX (never call in production).
func (s *Service) Hint(ctx context.Context, userID string) (map[string]string, error) {
	phone, err := s.Repo.GetUserPhone(ctx, userID)
	if err != nil {
		if errors.Is(err, kycrepo.ErrNotFound) {
			return nil, ErrUserNotFound
		}
		return nil, err
	}
	bvn, err := Expected(phone, IDTypeBVN)
	if err != nil {
		return nil, err
	}
	nin, err := Expected(phone, IDTypeNIN)
	if err != nil {
		return nil, err
	}
	return map[string]string{"BVN": bvn, "NIN": nin}, nil
}

// Expected derives the deterministic mock id for (phone, idType) — the
// helper is exported so the admin backoffice hint view can reuse it.
func Expected(phone, idType string) (string, error) {
	last8 := last8Digits(phone)
	if last8 == "" {
		return "", errors.New("phone has fewer than 8 digits; cannot derive mock KYC id")
	}
	switch strings.ToUpper(idType) {
	case IDTypeBVN:
		return "222" + last8, nil
	case IDTypeNIN:
		return "333" + last8, nil
	default:
		return "", fmt.Errorf("unknown id_type %q", idType)
	}
}

func tierFor(idType string) string {
	if idType == IDTypeBVN {
		return TierThree
	}
	return TierTwo
}

func newID() string {
	return strings.ToLower(ulid.MustNew(ulid.Timestamp(time.Now()), rand.Reader).String())
}

func allDigits(s string) bool {
	for _, r := range s {
		if r < '0' || r > '9' {
			return false
		}
	}
	return len(s) > 0
}

func last8Digits(phone string) string {
	digits := make([]byte, 0, len(phone))
	for i := 0; i < len(phone); i++ {
		if phone[i] >= '0' && phone[i] <= '9' {
			digits = append(digits, phone[i])
		}
	}
	if len(digits) < 8 {
		return ""
	}
	return string(digits[len(digits)-8:])
}
