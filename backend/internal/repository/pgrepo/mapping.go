package pgrepo

import (
	"time"

	"github.com/jackc/pgx/v5/pgtype"

	"github.com/intellect/offlinepay/internal/domain"
	"github.com/intellect/offlinepay/internal/repository/sqlcgen"
)

func tsz(t time.Time) pgtype.Timestamptz {
	if t.IsZero() {
		return pgtype.Timestamptz{Valid: false}
	}
	return pgtype.Timestamptz{Time: t, Valid: true}
}

func tszPtr(t *time.Time) pgtype.Timestamptz {
	if t == nil || t.IsZero() {
		return pgtype.Timestamptz{Valid: false}
	}
	return pgtype.Timestamptz{Time: *t, Valid: true}
}

// fromTSZ returns the timestamp normalized to UTC. Postgres timestamptz is
// timezone-agnostic at rest, but pgx renders it in the client's local zone;
// signed payloads canonicalize timestamps via Go's time.Time JSON encoder
// which embeds the zone offset, so a non-UTC zone breaks signature verify.
func fromTSZ(t pgtype.Timestamptz) time.Time {
	if !t.Valid {
		return time.Time{}
	}
	return t.Time.UTC()
}

func fromTSZPtr(t pgtype.Timestamptz) *time.Time {
	if !t.Valid {
		return nil
	}
	tt := t.Time.UTC()
	return &tt
}

func strPtr(s string) *string {
	if s == "" {
		return nil
	}
	return &s
}

func fromStrPtr(s *string) string {
	if s == nil {
		return ""
	}
	return *s
}

func ceilingToDomain(c sqlcgen.CeilingToken) domain.CeilingToken {
	return domain.CeilingToken{
		ID:             c.ID,
		PayerID:        c.PayerUserID,
		CeilingAmount:  c.CeilingKobo,
		IssuedAt:       fromTSZ(c.IssuedAt),
		ExpiresAt:      fromTSZ(c.ExpiresAt),
		SequenceStart:  c.SequenceStart,
		NextSequence:   c.SequenceStart + 1,
		PayerPublicKey: c.PayerPubkey,
		BankKeyID:      c.BankKeyID,
		BankSignature:  c.BankSig,
		Status:         domain.CeilingStatus(c.Status),
		ReleaseAfter:   fromTSZPtr(c.ReleaseAfter),
		CreatedAt:      fromTSZ(c.CreatedAt),
	}
}

func paymentToDomainTxn(p sqlcgen.PaymentToken) domain.Transaction {
	return domain.Transaction{
		ID:                p.ID,
		PayerID:           p.PayerUserID,
		PayeeID:           p.PayeeUserID,
		Amount:            p.AmountKobo,
		SequenceNumber:    p.SequenceNumber,
		CeilingTokenID:    p.CeilingID,
		Status:            domain.TransactionStatus(p.Status),
		SettledAmount:     p.SettledAmountKobo,
		SettlementBatchID: p.SettlementBatchID,
		RejectionReason:   p.RejectionReason,
		SubmittedAt:       fromTSZPtr(p.SubmittedAt),
		SettledAt:         fromTSZPtr(p.SettledAt),
		CreatedAt:         fromTSZ(p.CreatedAt),
		UpdatedAt:         fromTSZ(p.UpdatedAt),
	}
}

func fraudToDomain(f sqlcgen.FraudSignal) domain.FraudEvent {
	return domain.FraudEvent{
		ID:             f.ID,
		UserID:         f.UserID,
		SignalType:     domain.FraudSignalType(f.SignalType),
		CeilingTokenID: f.CeilingTokenID,
		TransactionID:  f.TransactionID,
		Details:        f.Details,
		Severity:       f.Severity,
		CreatedAt:      fromTSZ(f.CreatedAt),
	}
}

func bankKeyToDomain(b sqlcgen.BankSigningKey) domain.BankSigningKey {
	return domain.BankSigningKey{
		KeyID:      b.KeyID,
		PublicKey:  b.Pubkey,
		PrivateKey: b.PrivkeyEnc,
		ActiveFrom: fromTSZ(b.ActiveFrom),
		ActiveTo:   fromTSZPtr(b.RetiredAt),
		CreatedAt:  fromTSZ(b.CreatedAt),
	}
}

func realmKeyToDomain(r sqlcgen.RealmKey) domain.RealmKey {
	return domain.RealmKey{
		Version:    int(r.Version),
		Key:        r.KeyEnc,
		ActiveFrom: fromTSZ(r.ActiveFrom),
		ExpiresAt:  fromTSZ(r.RetiredAt),
	}
}
