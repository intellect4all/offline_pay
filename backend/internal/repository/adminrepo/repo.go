// Package adminrepo is the sqlc-backed repository for the backoffice
// admin-api. It owns admin users + roles + sessions + audit log, plus
// the read-only projections the dashboard needs (user lookups, payment
// token lists, settlement rollups, KYC submissions).
package adminrepo

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgtype"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/intellect/offlinepay/internal/repository/sqlcgen"
)

// ErrNotFound is returned by single-row lookups when no row matches.
// The service maps this to invalid-credentials / invalid-refresh /
// user-not-found domain errors.
var ErrNotFound = errors.New("adminrepo: not found")

type Repo struct {
	pool *pgxpool.Pool
	q    *sqlcgen.Queries
}

func New(pool *pgxpool.Pool) *Repo {
	return &Repo{pool: pool, q: sqlcgen.New(pool)}
}

// AdminUser is the service-facing projection.
type AdminUser struct {
	ID       string
	Email    string
	FullName string
	Status   string
	Created  time.Time
}

type CreateAdminInput struct {
	ID           string
	Email        string
	FullName     string
	PasswordHash string
	Roles        []string
}

// CreateAdmin inserts the admin user + role grants + re-reads the row
// in one tx. Returns the canonical AdminUser projection.
func (r *Repo) CreateAdmin(ctx context.Context, in CreateAdminInput) (AdminUser, error) {
	var out AdminUser
	err := r.tx(ctx, func(q *sqlcgen.Queries) error {
		if err := q.CreateAdminUser(ctx, sqlcgen.CreateAdminUserParams{
			ID:           in.ID,
			Email:        in.Email,
			FullName:     in.FullName,
			PasswordHash: in.PasswordHash,
		}); err != nil {
			return err
		}
		for _, name := range in.Roles {
			if err := q.GrantAdminRoleByName(ctx, sqlcgen.GrantAdminRoleByNameParams{
				AdminUserID: in.ID,
				Name:        name,
			}); err != nil {
				return fmt.Errorf("grant role %s: %w", name, err)
			}
		}
		row, err := q.GetAdminUserByID(ctx, in.ID)
		if err != nil {
			return err
		}
		out = AdminUser{
			ID:       row.ID,
			Email:    row.Email,
			FullName: row.FullName,
			Status:   row.Status,
			Created:  row.CreatedAt.Time,
		}
		return nil
	})
	return out, err
}

// GetAdminForLogin returns the public fields + password hash in one
// round trip.
func (r *Repo) GetAdminForLogin(ctx context.Context, email string) (AdminUser, string, error) {
	row, err := r.q.GetAdminUserForLogin(ctx, email)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return AdminUser{}, "", ErrNotFound
		}
		return AdminUser{}, "", err
	}
	return AdminUser{
		ID:       row.ID,
		Email:    row.Email,
		FullName: row.FullName,
		Status:   row.Status,
		Created:  row.CreatedAt.Time,
	}, row.PasswordHash, nil
}

func (r *Repo) GetAdminByID(ctx context.Context, id string) (AdminUser, error) {
	row, err := r.q.GetAdminUserByID(ctx, id)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return AdminUser{}, ErrNotFound
		}
		return AdminUser{}, err
	}
	return AdminUser{
		ID:       row.ID,
		Email:    row.Email,
		FullName: row.FullName,
		Status:   row.Status,
		Created:  row.CreatedAt.Time,
	}, nil
}

func (r *Repo) TouchAdminLastLogin(ctx context.Context, id string) error {
	return r.q.TouchAdminUserLastLogin(ctx, id)
}

func (r *Repo) ListAdminRoleNames(ctx context.Context, id string) ([]string, error) {
	return r.q.ListAdminRoleNamesForUser(ctx, id)
}

// AdminSession is the service-facing refresh-session projection.
type AdminSession struct {
	ID          string
	AdminUserID string
	RevokedAt   *time.Time
	ExpiresAt   time.Time
}

func (r *Repo) CreateAdminSession(ctx context.Context, id, adminUserID, refreshHash, ua, ip string, expiresAt time.Time) error {
	return r.q.CreateAdminSession(ctx, sqlcgen.CreateAdminSessionParams{
		ID:          id,
		AdminUserID: adminUserID,
		RefreshHash: refreshHash,
		UserAgent:   ua,
		Ip:          ip,
		ExpiresAt:   ts(expiresAt),
	})
}

func (r *Repo) GetAdminSessionByRefreshHash(ctx context.Context, refreshHash string) (AdminSession, error) {
	row, err := r.q.GetAdminSessionByRefreshHash(ctx, refreshHash)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return AdminSession{}, ErrNotFound
		}
		return AdminSession{}, err
	}
	return AdminSession{
		ID:          row.ID,
		AdminUserID: row.AdminUserID,
		RevokedAt:   tsPtr(row.RevokedAt),
		ExpiresAt:   row.ExpiresAt.Time,
	}, nil
}

func (r *Repo) RevokeAdminSessionByHash(ctx context.Context, refreshHash string) error {
	return r.q.RevokeAdminSessionByHash(ctx, refreshHash)
}

// RotateAdminSession revokes the prior session and inserts a fresh one
// atomically, mirroring the service's Refresh flow.
func (r *Repo) RotateAdminSession(ctx context.Context, oldSessionID, newSessionID, adminUserID, newRefreshHash string, newExpiresAt time.Time) error {
	return r.tx(ctx, func(q *sqlcgen.Queries) error {
		if err := q.RevokeAdminSessionByID(ctx, oldSessionID); err != nil {
			return err
		}
		return q.CreateAdminSessionRotation(ctx, sqlcgen.CreateAdminSessionRotationParams{
			ID:          newSessionID,
			AdminUserID: adminUserID,
			RefreshHash: newRefreshHash,
			ExpiresAt:   ts(newExpiresAt),
		})
	})
}

type AuditEntry struct {
	ActorID    string // empty -> null
	ActorEmail string
	Action     string
	TargetType string
	TargetID   string
	Payload    []byte // pre-marshalled JSON, may be nil
	IP         string
	UserAgent  string
}

func (r *Repo) InsertAuditLog(ctx context.Context, e AuditEntry) error {
	var actorID *string
	if e.ActorID != "" {
		actorID = &e.ActorID
	}
	return r.q.InsertAdminAuditLog(ctx, sqlcgen.InsertAdminAuditLogParams{
		AdminUserID: actorID,
		AdminEmail:  e.ActorEmail,
		Action:      e.Action,
		TargetType:  e.TargetType,
		TargetID:    e.TargetID,
		Payload:     e.Payload,
		Ip:          e.IP,
		UserAgent:   e.UserAgent,
	})
}

type AuditRow struct {
	ID         int64
	ActorEmail string
	Action     string
	TargetType string
	TargetID   string
	IP         string
	CreatedAt  time.Time
}

func (r *Repo) CountAuditLog(ctx context.Context) (int64, error) {
	return r.q.CountAdminAuditLog(ctx)
}

func (r *Repo) ListAuditLog(ctx context.Context, limit, offset int32) ([]AuditRow, error) {
	rows, err := r.q.ListAdminAuditLog(ctx, sqlcgen.ListAdminAuditLogParams{
		Limit:  limit,
		Offset: offset,
	})
	if err != nil {
		return nil, err
	}
	out := make([]AuditRow, 0, len(rows))
	for _, row := range rows {
		out = append(out, AuditRow{
			ID:         row.ID,
			ActorEmail: row.AdminEmail,
			Action:     row.Action,
			TargetType: row.TargetType,
			TargetID:   row.TargetID,
			IP:         row.Ip,
			CreatedAt:  row.CreatedAt.Time,
		})
	}
	return out, nil
}

// UserRow is the row the backoffice dashboard lists / fetches for one
// end user.
type UserRow struct {
	ID          string
	Phone       string
	KYCTier     string
	RealmKeyVer int
	CreatedAt   time.Time
	MainBalance int64
	LienBalance int64
	LastSeenAt  *time.Time
}

func (r *Repo) GetUserWithBalances(ctx context.Context, id string) (UserRow, error) {
	row, err := r.q.GetUserBalancesForAdmin(ctx, id)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return UserRow{}, ErrNotFound
		}
		return UserRow{}, err
	}
	return UserRow{
		ID:          row.ID,
		Phone:       row.Phone,
		KYCTier:     row.KycTier,
		RealmKeyVer: int(row.RealmKeyVersion),
		CreatedAt:   row.CreatedAt.Time,
		MainBalance: row.MainBalanceKobo,
		LienBalance: row.LienBalanceKobo,
		LastSeenAt:  tsPtr(row.LastSeenAt),
	}, nil
}

func (r *Repo) ListUsers(ctx context.Context, limit, offset int32) ([]UserRow, error) {
	rows, err := r.q.ListUsersForAdmin(ctx, sqlcgen.ListUsersForAdminParams{
		Limit:  limit,
		Offset: offset,
	})
	if err != nil {
		return nil, err
	}
	out := make([]UserRow, 0, len(rows))
	for _, row := range rows {
		out = append(out, UserRow{
			ID:          row.ID,
			Phone:       row.Phone,
			KYCTier:     row.KycTier,
			RealmKeyVer: int(row.RealmKeyVersion),
			CreatedAt:   row.CreatedAt.Time,
			MainBalance: row.MainBalanceKobo,
			LienBalance: row.LienBalanceKobo,
			LastSeenAt:  tsPtr(row.LastSeenAt),
		})
	}
	return out, nil
}

func (r *Repo) SearchUsersByPhone(ctx context.Context, pattern string, limit, offset int32) ([]UserRow, error) {
	rows, err := r.q.SearchUsersForAdminByPhone(ctx, sqlcgen.SearchUsersForAdminByPhoneParams{
		Phone:  pattern,
		Limit:  limit,
		Offset: offset,
	})
	if err != nil {
		return nil, err
	}
	out := make([]UserRow, 0, len(rows))
	for _, row := range rows {
		out = append(out, UserRow{
			ID:          row.ID,
			Phone:       row.Phone,
			KYCTier:     row.KycTier,
			RealmKeyVer: int(row.RealmKeyVersion),
			CreatedAt:   row.CreatedAt.Time,
			MainBalance: row.MainBalanceKobo,
			LienBalance: row.LienBalanceKobo,
			LastSeenAt:  tsPtr(row.LastSeenAt),
		})
	}
	return out, nil
}

func (r *Repo) CountUsers(ctx context.Context) (int64, error) {
	return r.q.CountUsers(ctx)
}

func (r *Repo) CountUsersByPhone(ctx context.Context, pattern string) (int64, error) {
	return r.q.CountUsersByPhone(ctx, pattern)
}

type AccountRow struct {
	ID      string
	Kind    string
	Balance int64
}

func (r *Repo) ListAccountsForUser(ctx context.Context, userID string) ([]AccountRow, error) {
	rows, err := r.q.ListAccountsForAdmin(ctx, userID)
	if err != nil {
		return nil, err
	}
	out := make([]AccountRow, 0, len(rows))
	for _, row := range rows {
		out = append(out, AccountRow{
			ID:      row.ID,
			Kind:    row.Kind,
			Balance: row.BalanceKobo,
		})
	}
	return out, nil
}

type DeviceRow struct {
	ID         string
	Active     bool
	LastSeenAt *time.Time
	CreatedAt  time.Time
}

func (r *Repo) ListDevicesForUser(ctx context.Context, userID string) ([]DeviceRow, error) {
	rows, err := r.q.ListDevicesForAdmin(ctx, userID)
	if err != nil {
		return nil, err
	}
	out := make([]DeviceRow, 0, len(rows))
	for _, row := range rows {
		out = append(out, DeviceRow{
			ID:         row.ID,
			Active:     row.Active,
			LastSeenAt: tsPtr(row.LastSeenAt),
			CreatedAt:  row.CreatedAt.Time,
		})
	}
	return out, nil
}

type CeilingRow struct {
	ID        string
	Status    string
	Amount    int64
	Remaining int64
	IssuedAt  time.Time
	ExpiresAt time.Time
}

func (r *Repo) ListCeilingsForUser(ctx context.Context, userID string, limit int32) ([]CeilingRow, error) {
	rows, err := r.q.ListCeilingsForAdmin(ctx, sqlcgen.ListCeilingsForAdminParams{
		PayerUserID: userID,
		Limit:       limit,
	})
	if err != nil {
		return nil, err
	}
	out := make([]CeilingRow, 0, len(rows))
	for _, row := range rows {
		out = append(out, CeilingRow{
			ID:        row.ID,
			Status:    row.Status,
			Amount:    row.CeilingKobo,
			Remaining: row.RemainingKobo,
			IssuedAt:  row.IssuedAt.Time,
			ExpiresAt: row.ExpiresAt.Time,
		})
	}
	return out, nil
}

type FraudRow struct {
	ID        string
	Signal    string
	Severity  string
	Weight    float64
	CreatedAt time.Time
}

// FraudGlobalRow is the backoffice-wide fraud signal projection. Carries
// the payload needed by the dashboard's fraud console (user_id, details,
// and the optional ceiling/txn refs so operators can pivot into context).
type FraudGlobalRow struct {
	ID             string
	UserID         string
	Signal         string
	Severity       string
	Weight         float64
	Details        string
	CeilingTokenID *string
	TransactionID  *string
	CreatedAt      time.Time
}

func (r *Repo) ListFraudSignalsGlobal(ctx context.Context, limit, offset int32) ([]FraudGlobalRow, error) {
	rows, err := r.q.ListFraudSignalsGlobal(ctx, sqlcgen.ListFraudSignalsGlobalParams{
		Limit:  limit,
		Offset: offset,
	})
	if err != nil {
		return nil, err
	}
	out := make([]FraudGlobalRow, 0, len(rows))
	for _, row := range rows {
		out = append(out, FraudGlobalRow{
			ID:             row.ID,
			UserID:         row.UserID,
			Signal:         row.Signal,
			Severity:       row.Severity,
			Weight:         row.Weight,
			Details:        row.Details,
			CeilingTokenID: row.CeilingTokenID,
			TransactionID:  row.TransactionID,
			CreatedAt:      row.CreatedAt.Time,
		})
	}
	return out, nil
}

func (r *Repo) CountFraudSignalsGlobal(ctx context.Context) (int64, error) {
	return r.q.CountFraudSignalsGlobal(ctx)
}

func (r *Repo) ListFraudSignalsForUser(ctx context.Context, userID string, limit int32) ([]FraudRow, error) {
	rows, err := r.q.ListFraudSignalsForAdmin(ctx, sqlcgen.ListFraudSignalsForAdminParams{
		UserID: userID,
		Limit:  limit,
	})
	if err != nil {
		return nil, err
	}
	out := make([]FraudRow, 0, len(rows))
	for _, row := range rows {
		out = append(out, FraudRow{
			ID:        row.ID,
			Signal:    row.Signal,
			Severity:  row.Severity,
			Weight:    row.Weight,
			CreatedAt: row.CreatedAt.Time,
		})
	}
	return out, nil
}

// TxnRow is the unified row shape every ListPaymentTokensForAdmin*
// variant maps into. The unfiltered listing UNION-ALLs both flows
// — `payment_tokens` (offline ceiling-backed) and `transfers` (online
// P2P) — so `Kind` is the column that lets the UI tell them apart:
//   - "payment_token" → offline pay; Sequence/CeilingID/BatchID populated
//   - "transfer"      → online P2P; Sequence=0, CeilingID="", BatchID=nil
type TxnRow struct {
	ID              string
	PayerID         string
	PayeeID         string
	Amount          int64
	Settled         int64
	Status          string
	Sequence        int64
	CeilingID       string
	BatchID         *string
	RejectionReason *string
	CreatedAt       time.Time
	SubmittedAt     *time.Time
	SettledAt       *time.Time
	Kind            string
}

// TxnFilter mirrors admin.txnFilter; any combination of fields may be
// set. The repo picks the right sqlc query based on which filters are
// non-empty.
type TxnFilter struct {
	Status string
	Payer  string
	Payee  string
	Batch  string
}

type TxnPage struct {
	Limit  int32
	Offset int32
}

// ListTxns dispatches to one of the pre-enumerated filtered queries.
// Refuses unsupported combinations (state+batch, payer+batch, etc.) to
// keep the matrix small — the HTTP layer never passes those.
func (r *Repo) ListTxns(ctx context.Context, f TxnFilter, p TxnPage) ([]TxnRow, error) {
	switch {
	case f.Batch != "":
		rows, err := r.q.ListPaymentTokensForAdminByBatch(ctx, sqlcgen.ListPaymentTokensForAdminByBatchParams{
			SettlementBatchID: &f.Batch,
			Limit:             p.Limit,
			Offset:            p.Offset,
		})
		if err != nil {
			return nil, err
		}
		out := make([]TxnRow, 0, len(rows))
		for _, row := range rows {
			out = append(out, txnRowFromBatch(row))
		}
		return out, nil
	case f.Status != "" && f.Payer != "" && f.Payee != "":
		rows, err := r.q.ListPaymentTokensForAdminByStatusAndPayerAndPayee(ctx, sqlcgen.ListPaymentTokensForAdminByStatusAndPayerAndPayeeParams{
			Status:      sqlcgen.PaymentStatus(f.Status),
			PayerUserID: f.Payer,
			PayeeUserID: f.Payee,
			Limit:       p.Limit,
			Offset:      p.Offset,
		})
		if err != nil {
			return nil, err
		}
		return mapTxnStatePayerPayee(rows), nil
	case f.Status != "" && f.Payer != "":
		rows, err := r.q.ListPaymentTokensForAdminByStatusAndPayer(ctx, sqlcgen.ListPaymentTokensForAdminByStatusAndPayerParams{
			Status:      sqlcgen.PaymentStatus(f.Status),
			PayerUserID: f.Payer,
			Limit:       p.Limit,
			Offset:      p.Offset,
		})
		if err != nil {
			return nil, err
		}
		return mapTxnStatePayer(rows), nil
	case f.Status != "" && f.Payee != "":
		rows, err := r.q.ListPaymentTokensForAdminByStatusAndPayee(ctx, sqlcgen.ListPaymentTokensForAdminByStatusAndPayeeParams{
			Status:      sqlcgen.PaymentStatus(f.Status),
			PayeeUserID: f.Payee,
			Limit:       p.Limit,
			Offset:      p.Offset,
		})
		if err != nil {
			return nil, err
		}
		return mapTxnStatePayee(rows), nil
	case f.Payer != "" && f.Payee != "":
		rows, err := r.q.ListPaymentTokensForAdminByPayerAndPayee(ctx, sqlcgen.ListPaymentTokensForAdminByPayerAndPayeeParams{
			PayerUserID: f.Payer,
			PayeeUserID: f.Payee,
			Limit:       p.Limit,
			Offset:      p.Offset,
		})
		if err != nil {
			return nil, err
		}
		return mapTxnPayerPayee(rows), nil
	case f.Status != "":
		rows, err := r.q.ListPaymentTokensForAdminByStatus(ctx, sqlcgen.ListPaymentTokensForAdminByStatusParams{
			Status: sqlcgen.PaymentStatus(f.Status),
			Limit:  p.Limit,
			Offset: p.Offset,
		})
		if err != nil {
			return nil, err
		}
		return mapTxnState(rows), nil
	case f.Payer != "":
		rows, err := r.q.ListPaymentTokensForAdminByPayer(ctx, sqlcgen.ListPaymentTokensForAdminByPayerParams{
			PayerUserID: f.Payer,
			Limit:       p.Limit,
			Offset:      p.Offset,
		})
		if err != nil {
			return nil, err
		}
		return mapTxnPayer(rows), nil
	case f.Payee != "":
		rows, err := r.q.ListPaymentTokensForAdminByPayee(ctx, sqlcgen.ListPaymentTokensForAdminByPayeeParams{
			PayeeUserID: f.Payee,
			Limit:       p.Limit,
			Offset:      p.Offset,
		})
		if err != nil {
			return nil, err
		}
		return mapTxnPayee(rows), nil
	default:
		rows, err := r.q.ListPaymentTokensForAdmin(ctx, sqlcgen.ListPaymentTokensForAdminParams{
			Limit:  p.Limit,
			Offset: p.Offset,
		})
		if err != nil {
			return nil, err
		}
		return mapTxnAll(rows), nil
	}
}

// CountTxns is the matching count dispatcher.
func (r *Repo) CountTxns(ctx context.Context, f TxnFilter) (int64, error) {
	switch {
	case f.Batch != "":
		return r.q.CountPaymentTokensForAdminByBatch(ctx, &f.Batch)
	case f.Status != "" && f.Payer != "" && f.Payee != "":
		return r.q.CountPaymentTokensForAdminByStatusAndPayerAndPayee(ctx, sqlcgen.CountPaymentTokensForAdminByStatusAndPayerAndPayeeParams{
			Status: sqlcgen.PaymentStatus(f.Status), PayerUserID: f.Payer, PayeeUserID: f.Payee,
		})
	case f.Status != "" && f.Payer != "":
		return r.q.CountPaymentTokensForAdminByStatusAndPayer(ctx, sqlcgen.CountPaymentTokensForAdminByStatusAndPayerParams{
			Status: sqlcgen.PaymentStatus(f.Status), PayerUserID: f.Payer,
		})
	case f.Status != "" && f.Payee != "":
		return r.q.CountPaymentTokensForAdminByStatusAndPayee(ctx, sqlcgen.CountPaymentTokensForAdminByStatusAndPayeeParams{
			Status: sqlcgen.PaymentStatus(f.Status), PayeeUserID: f.Payee,
		})
	case f.Payer != "" && f.Payee != "":
		return r.q.CountPaymentTokensForAdminByPayerAndPayee(ctx, sqlcgen.CountPaymentTokensForAdminByPayerAndPayeeParams{
			PayerUserID: f.Payer, PayeeUserID: f.Payee,
		})
	case f.Status != "":
		return r.q.CountPaymentTokensForAdminByStatus(ctx, sqlcgen.PaymentStatus(f.Status))
	case f.Payer != "":
		return r.q.CountPaymentTokensForAdminByPayer(ctx, f.Payer)
	case f.Payee != "":
		return r.q.CountPaymentTokensForAdminByPayee(ctx, f.Payee)
	default:
		return r.q.CountPaymentTokensForAdmin(ctx)
	}
}

// GetTxn looks up a row by id across both money-movement tables.
// Tries `payment_tokens` first, falls back to `transfers`. Returns
// ErrNotFound only when neither table has the id.
func (r *Repo) GetTxn(ctx context.Context, id string) (TxnRow, error) {
	row, err := r.q.GetPaymentTokenForAdmin(ctx, id)
	if err == nil {
		return TxnRow{
			ID:              row.ID,
			PayerID:         row.PayerUserID,
			PayeeID:         row.PayeeUserID,
			Amount:          row.AmountKobo,
			Settled:         row.SettledAmountKobo,
			Status:          row.Status,
			Sequence:        row.SequenceNumber,
			CeilingID:       row.CeilingID,
			BatchID:         row.SettlementBatchID,
			RejectionReason: row.RejectionReason,
			CreatedAt:       row.CreatedAt.Time,
			SubmittedAt:     tsPtr(row.SubmittedAt),
			SettledAt:       tsPtr(row.SettledAt),
			Kind:            row.Kind,
		}, nil
	}
	if !errors.Is(err, pgx.ErrNoRows) {
		return TxnRow{}, err
	}
	// Fallback: maybe it's a transfer.
	t, err := r.q.GetTransferForAdmin(ctx, id)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return TxnRow{}, ErrNotFound
		}
		return TxnRow{}, err
	}
	return TxnRow{
		ID:              t.ID,
		PayerID:         t.PayerUserID,
		PayeeID:         t.PayeeUserID,
		Amount:          t.AmountKobo,
		Settled:         t.SettledAmountKobo,
		Status:          t.Status,
		Sequence:        t.SequenceNumber,
		CeilingID:       t.CeilingID,
		BatchID:         t.SettlementBatchID,
		RejectionReason: t.RejectionReason,
		CreatedAt:       t.CreatedAt.Time,
		SubmittedAt:     tsPtr(t.SubmittedAt),
		SettledAt:       tsPtr(t.SettledAt),
		Kind:            t.Kind,
	}, nil
}

type OverviewStats struct {
	UsersTotal        int64
	UsersActive24h    int64
	UsersActive7d     int64
	DevicesActive     int64
	LienFloat         int64
	PendingSettlement int64
	TxnCount24h       int64
	TxnVolume24h      int64
	FraudSignals24h   int64
	CeilingsActive    int64
}

func (r *Repo) OverviewStats(ctx context.Context) (OverviewStats, error) {
	row, err := r.q.AdminOverviewStats(ctx)
	if err != nil {
		return OverviewStats{}, err
	}
	return OverviewStats{
		UsersTotal:        row.UsersTotal,
		UsersActive24h:    row.UsersActive24h,
		UsersActive7d:     row.UsersActive7d,
		DevicesActive:     row.DevicesActive,
		LienFloat:         row.LienFloatKobo,
		PendingSettlement: row.PendingSettlementKobo,
		TxnCount24h:       row.TxnCount24h,
		TxnVolume24h:      row.TxnVolume24hKobo,
		FraudSignals24h:   row.FraudSignals24h,
		CeilingsActive:    row.CeilingsActive,
	}, nil
}

type VolumePoint struct {
	Day    time.Time
	Count  int64
	Volume int64
}

func (r *Repo) VolumeSeries(ctx context.Context, days int32) ([]VolumePoint, error) {
	rows, err := r.q.AdminVolumeSeries(ctx, days)
	if err != nil {
		return nil, err
	}
	out := make([]VolumePoint, 0, len(rows))
	for _, row := range rows {
		out = append(out, VolumePoint{
			Day:    row.Day.Time,
			Count:  row.Count,
			Volume: row.VolumeKobo,
		})
	}
	return out, nil
}

type SettlementBatch struct {
	ID             string
	TxnCount       int64
	SubmittedVol   int64
	SettledVol     int64
	FirstSubmitted *time.Time
	LastSettled    *time.Time
}

func (r *Repo) CountSettlementBatches(ctx context.Context) (int64, error) {
	return r.q.CountSettlementBatches(ctx)
}

func (r *Repo) ListSettlementBatches(ctx context.Context, limit, offset int32) ([]SettlementBatch, error) {
	rows, err := r.q.ListSettlementBatches(ctx, sqlcgen.ListSettlementBatchesParams{
		Limit:  limit,
		Offset: offset,
	})
	if err != nil {
		return nil, err
	}
	out := make([]SettlementBatch, 0, len(rows))
	for _, row := range rows {
		id := ""
		if row.ID != nil {
			id = *row.ID
		}
		out = append(out, SettlementBatch{
			ID:             id,
			TxnCount:       row.TxnCount,
			SubmittedVol:   row.SubmittedVolumeKobo,
			SettledVol:     row.SettledVolumeKobo,
			FirstSubmitted: tsPtr(row.FirstSubmittedAt),
			LastSettled:    tsPtr(row.LastSettledAt),
		})
	}
	return out, nil
}



func (r *Repo) GetSettlementHeader(ctx context.Context, batchID string) (SettlementBatch, error) {
	row, err := r.q.GetSettlementBatchHeader(ctx, batchID)
	if err != nil {
		return SettlementBatch{}, err
	}
	return SettlementBatch{
		ID:             row.ID,
		TxnCount:       row.TxnCount,
		SubmittedVol:   row.SubmittedVolumeKobo,
		SettledVol:     row.SettledVolumeKobo,
		FirstSubmitted: tsPtr(row.FirstSubmittedAt),
		LastSettled:    tsPtr(row.LastSettledAt),
	}, nil
}

func (r *Repo) GetSettlementStateCounts(ctx context.Context, batchID string) (map[string]int64, error) {
	rows, err := r.q.GetSettlementBatchStatusCounts(ctx, &batchID)
	if err != nil {
		return nil, err
	}
	out := map[string]int64{}
	for _, row := range rows {
		out[row.Status] = row.Count
	}
	return out, nil
}

// KYC submission + tier-promotion logic moved to internal/service/kyc
// (user-facing). Admin keeps list/detail access only.

func (r *Repo) GetUserPhone(ctx context.Context, userID string) (string, error) {
	s, err := r.q.GetUserPhoneByID(ctx, userID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return "", ErrNotFound
		}
		return "", err
	}
	return s, nil
}

type KYCSubmissionRow struct {
	ID              string
	UserID          string
	IDType          string
	IDNumber        string
	Status          string
	RejectionReason *string
	TierGranted     *string
	SubmittedBy     *string
	SubmittedAt     time.Time
	VerifiedAt      *time.Time
}

func (r *Repo) ListKYCByUser(ctx context.Context, userID string) ([]KYCSubmissionRow, error) {
	rows, err := r.q.ListKYCSubmissionsByUser(ctx, userID)
	if err != nil {
		return nil, err
	}
	out := make([]KYCSubmissionRow, 0, len(rows))
	for _, row := range rows {
		out = append(out, KYCSubmissionRow{
			ID:              row.ID,
			UserID:          row.UserID,
			IDType:          row.IDType,
			IDNumber:        row.IDNumber,
			Status:          row.Status,
			RejectionReason: row.RejectionReason,
			TierGranted:     row.TierGranted,
			SubmittedBy:     row.SubmittedBy,
			SubmittedAt:     row.SubmittedAt.Time,
			VerifiedAt:      tsPtr(row.VerifiedAt),
		})
	}
	return out, nil
}

func (r *Repo) tx(ctx context.Context, fn func(*sqlcgen.Queries) error) error {
	tx, err := r.pool.BeginTx(ctx, pgx.TxOptions{})
	if err != nil {
		return fmt.Errorf("adminrepo: begin tx: %w", err)
	}
	committed := false
	defer func() {
		if !committed {
			_ = tx.Rollback(context.Background())
		}
	}()
	if err := fn(r.q.WithTx(tx)); err != nil {
		return err
	}
	if err := tx.Commit(ctx); err != nil {
		return err
	}
	committed = true
	return nil
}

func ts(t time.Time) pgtype.Timestamptz {
	return pgtype.Timestamptz{Time: t, Valid: true}
}

func tsPtr(t pgtype.Timestamptz) *time.Time {
	if !t.Valid {
		return nil
	}
	v := t.Time
	return &v
}

func txnRowFromBatch(row sqlcgen.ListPaymentTokensForAdminByBatchRow) TxnRow {
	return TxnRow{
		ID:              row.ID,
		PayerID:         row.PayerUserID,
		PayeeID:         row.PayeeUserID,
		Amount:          row.AmountKobo,
		Settled:         row.SettledAmountKobo,
		Status:          row.Status,
		Sequence:        row.SequenceNumber,
		CeilingID:       row.CeilingID,
		BatchID:         row.SettlementBatchID,
		RejectionReason: row.RejectionReason,
		CreatedAt:       row.CreatedAt.Time,
		SubmittedAt:     tsPtr(row.SubmittedAt),
		SettledAt:       tsPtr(row.SettledAt),
		Kind:            row.Kind,
	}
}

func mapTxnAll(rows []sqlcgen.ListPaymentTokensForAdminRow) []TxnRow {
	out := make([]TxnRow, 0, len(rows))
	for _, row := range rows {
		out = append(out, TxnRow{
			ID: row.ID, PayerID: row.PayerUserID, PayeeID: row.PayeeUserID,
			Amount: row.AmountKobo, Settled: row.SettledAmountKobo, Status: row.Status,
			Sequence: row.SequenceNumber, CeilingID: row.CeilingID, BatchID: row.SettlementBatchID,
			RejectionReason: row.RejectionReason, CreatedAt: row.CreatedAt.Time,
			SubmittedAt: tsPtr(row.SubmittedAt), SettledAt: tsPtr(row.SettledAt),
			Kind: row.Kind,
		})
	}
	return out
}

func mapTxnState(rows []sqlcgen.ListPaymentTokensForAdminByStatusRow) []TxnRow {
	out := make([]TxnRow, 0, len(rows))
	for _, row := range rows {
		out = append(out, TxnRow{
			ID: row.ID, PayerID: row.PayerUserID, PayeeID: row.PayeeUserID,
			Amount: row.AmountKobo, Settled: row.SettledAmountKobo, Status: row.Status,
			Sequence: row.SequenceNumber, CeilingID: row.CeilingID, BatchID: row.SettlementBatchID,
			RejectionReason: row.RejectionReason, CreatedAt: row.CreatedAt.Time,
			SubmittedAt: tsPtr(row.SubmittedAt), SettledAt: tsPtr(row.SettledAt),
			Kind: row.Kind,
		})
	}
	return out
}

func mapTxnPayer(rows []sqlcgen.ListPaymentTokensForAdminByPayerRow) []TxnRow {
	out := make([]TxnRow, 0, len(rows))
	for _, row := range rows {
		out = append(out, TxnRow{
			ID: row.ID, PayerID: row.PayerUserID, PayeeID: row.PayeeUserID,
			Amount: row.AmountKobo, Settled: row.SettledAmountKobo, Status: row.Status,
			Sequence: row.SequenceNumber, CeilingID: row.CeilingID, BatchID: row.SettlementBatchID,
			RejectionReason: row.RejectionReason, CreatedAt: row.CreatedAt.Time,
			SubmittedAt: tsPtr(row.SubmittedAt), SettledAt: tsPtr(row.SettledAt),
			Kind: row.Kind,
		})
	}
	return out
}

func mapTxnPayee(rows []sqlcgen.ListPaymentTokensForAdminByPayeeRow) []TxnRow {
	out := make([]TxnRow, 0, len(rows))
	for _, row := range rows {
		out = append(out, TxnRow{
			ID: row.ID, PayerID: row.PayerUserID, PayeeID: row.PayeeUserID,
			Amount: row.AmountKobo, Settled: row.SettledAmountKobo, Status: row.Status,
			Sequence: row.SequenceNumber, CeilingID: row.CeilingID, BatchID: row.SettlementBatchID,
			RejectionReason: row.RejectionReason, CreatedAt: row.CreatedAt.Time,
			SubmittedAt: tsPtr(row.SubmittedAt), SettledAt: tsPtr(row.SettledAt),
			Kind: row.Kind,
		})
	}
	return out
}

func mapTxnStatePayer(rows []sqlcgen.ListPaymentTokensForAdminByStatusAndPayerRow) []TxnRow {
	out := make([]TxnRow, 0, len(rows))
	for _, row := range rows {
		out = append(out, TxnRow{
			ID: row.ID, PayerID: row.PayerUserID, PayeeID: row.PayeeUserID,
			Amount: row.AmountKobo, Settled: row.SettledAmountKobo, Status: row.Status,
			Sequence: row.SequenceNumber, CeilingID: row.CeilingID, BatchID: row.SettlementBatchID,
			RejectionReason: row.RejectionReason, CreatedAt: row.CreatedAt.Time,
			SubmittedAt: tsPtr(row.SubmittedAt), SettledAt: tsPtr(row.SettledAt),
			Kind: row.Kind,
		})
	}
	return out
}

func mapTxnStatePayee(rows []sqlcgen.ListPaymentTokensForAdminByStatusAndPayeeRow) []TxnRow {
	out := make([]TxnRow, 0, len(rows))
	for _, row := range rows {
		out = append(out, TxnRow{
			ID: row.ID, PayerID: row.PayerUserID, PayeeID: row.PayeeUserID,
			Amount: row.AmountKobo, Settled: row.SettledAmountKobo, Status: row.Status,
			Sequence: row.SequenceNumber, CeilingID: row.CeilingID, BatchID: row.SettlementBatchID,
			RejectionReason: row.RejectionReason, CreatedAt: row.CreatedAt.Time,
			SubmittedAt: tsPtr(row.SubmittedAt), SettledAt: tsPtr(row.SettledAt),
			Kind: row.Kind,
		})
	}
	return out
}

func mapTxnPayerPayee(rows []sqlcgen.ListPaymentTokensForAdminByPayerAndPayeeRow) []TxnRow {
	out := make([]TxnRow, 0, len(rows))
	for _, row := range rows {
		out = append(out, TxnRow{
			ID: row.ID, PayerID: row.PayerUserID, PayeeID: row.PayeeUserID,
			Amount: row.AmountKobo, Settled: row.SettledAmountKobo, Status: row.Status,
			Sequence: row.SequenceNumber, CeilingID: row.CeilingID, BatchID: row.SettlementBatchID,
			RejectionReason: row.RejectionReason, CreatedAt: row.CreatedAt.Time,
			SubmittedAt: tsPtr(row.SubmittedAt), SettledAt: tsPtr(row.SettledAt),
			Kind: row.Kind,
		})
	}
	return out
}

func mapTxnStatePayerPayee(rows []sqlcgen.ListPaymentTokensForAdminByStatusAndPayerAndPayeeRow) []TxnRow {
	out := make([]TxnRow, 0, len(rows))
	for _, row := range rows {
		out = append(out, TxnRow{
			ID: row.ID, PayerID: row.PayerUserID, PayeeID: row.PayeeUserID,
			Amount: row.AmountKobo, Settled: row.SettledAmountKobo, Status: row.Status,
			Sequence: row.SequenceNumber, CeilingID: row.CeilingID, BatchID: row.SettlementBatchID,
			RejectionReason: row.RejectionReason, CreatedAt: row.CreatedAt.Time,
			SubmittedAt: tsPtr(row.SubmittedAt), SettledAt: tsPtr(row.SettledAt),
			Kind: row.Kind,
		})
	}
	return out
}
