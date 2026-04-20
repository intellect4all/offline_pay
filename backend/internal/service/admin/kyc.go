package admin

import (
	"context"
	"time"

	"github.com/intellect/offlinepay/internal/service/kyc"
)

type KYCSubmission struct {
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

func (s *Service) ListKYC(ctx context.Context, userID string) ([]KYCSubmission, error) {
	rows, err := s.Repo.ListKYCByUser(ctx, userID)
	if err != nil {
		return nil, err
	}
	out := make([]KYCSubmission, 0, len(rows))
	for _, r := range rows {
		out = append(out, KYCSubmission{
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

// KYCHint returns the deterministic mock expected values for the given
// user, useful for the backoffice form's helper text during testing.
func (s *Service) KYCHint(ctx context.Context, userID string) (map[string]string, error) {
	phone, err := s.Repo.GetUserPhone(ctx, userID)
	if err != nil {
		return nil, err
	}
	bvn, err := kyc.Expected(phone, kyc.IDTypeBVN)
	if err != nil {
		return nil, err
	}
	nin, err := kyc.Expected(phone, kyc.IDTypeNIN)
	if err != nil {
		return nil, err
	}
	return map[string]string{"BVN": bvn, "NIN": nin}, nil
}
