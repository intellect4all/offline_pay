package admin

import (
	"context"
	"strings"
	"time"

	"github.com/intellect/offlinepay/internal/repository/adminrepo"
)

// OverviewStats aggregates high-level numbers for the dashboard landing page.
type OverviewStats struct {
	UsersTotal         int64 `json:"users_total"`
	UsersActive24h     int64 `json:"users_active_24h"`
	UsersActive7d      int64 `json:"users_active_7d"`
	DevicesActive      int64 `json:"devices_active"`
	LienFloat          int64 `json:"lien_float_kobo"`
	PendingSettlement  int64 `json:"pending_settlement_kobo"`
	TxnCount24h        int64 `json:"txn_count_24h"`
	TxnVolume24h       int64 `json:"txn_volume_24h_kobo"`
	FraudSignals24h    int64 `json:"fraud_signals_24h"`
	CeilingsActive     int64 `json:"ceilings_active"`
}

func (s *Service) Overview(ctx context.Context) (OverviewStats, error) {
	o, err := s.Repo.OverviewStats(ctx)
	if err != nil {
		return OverviewStats{}, err
	}
	return OverviewStats(o), nil
}

type VolumePoint struct {
	Day    time.Time `json:"day"`
	Count  int64     `json:"count"`
	Volume int64     `json:"volume_kobo"`
}

func (s *Service) VolumeSeries(ctx context.Context, days int) ([]VolumePoint, error) {
	if days <= 0 || days > 180 {
		days = 14
	}
	rows, err := s.Repo.VolumeSeries(ctx, int32(days))
	if err != nil {
		return nil, err
	}
	out := make([]VolumePoint, 0, len(rows))
	for _, r := range rows {
		out = append(out, VolumePoint{Day: r.Day, Count: r.Count, Volume: r.Volume})
	}
	return out, nil
}

type UserRow struct {
	ID          string     `json:"id"`
	Phone       string     `json:"phone"`
	KYCTier     string     `json:"kyc_tier"`
	RealmKeyVer int        `json:"realm_key_version"`
	CreatedAt   time.Time  `json:"created_at"`
	MainBalance int64      `json:"main_balance_kobo"`
	LienBalance int64      `json:"lien_balance_kobo"`
	LastSeenAt  *time.Time `json:"last_seen_at"`
}

type Paged[T any] struct {
	Items   []T   `json:"items"`
	Total   int64 `json:"total"`
	Page    int   `json:"page"`
	PerPage int   `json:"per_page"`
}

// usersLike is the common subset of ListUsersForAdmin / SearchUsersForAdmin
// rows that the service maps into UserRow.
type usersLike struct {
	items []adminrepo.UserRow
}

func (s *Service) ListUsers(ctx context.Context, q string, page, perPage int) (Paged[UserRow], error) {
	if perPage <= 0 || perPage > 200 {
		perPage = 25
	}
	if page < 1 {
		page = 1
	}
	limit := int32(perPage)
	offset := int32((page - 1) * perPage)

	var (
		total int64
		rows  []adminrepo.UserRow
		err   error
	)
	if q == "" {
		total, err = s.Repo.CountUsers(ctx)
		if err != nil {
			return Paged[UserRow]{}, err
		}
		rows, err = s.Repo.ListUsers(ctx, limit, offset)
	} else {
		pattern := "%" + strings.ToLower(q) + "%"
		total, err = s.Repo.CountUsersByPhone(ctx, pattern)
		if err != nil {
			return Paged[UserRow]{}, err
		}
		rows, err = s.Repo.SearchUsersByPhone(ctx, pattern, limit, offset)
	}
	if err != nil {
		return Paged[UserRow]{}, err
	}
	items := make([]UserRow, 0, len(rows))
	for _, r := range rows {
		items = append(items, UserRow(r))
	}
	return Paged[UserRow]{Items: items, Total: total, Page: page, PerPage: perPage}, nil
}

type UserDetail struct {
	User     UserRow          `json:"user"`
	Accounts []AccountRow     `json:"accounts"`
	Devices  []DeviceRow      `json:"devices"`
	Ceilings []CeilingRow     `json:"ceilings"`
	Fraud    []FraudRow       `json:"fraud"`
	Recent   []TransactionRow `json:"recent_transactions"`
}

type AccountRow struct {
	ID      string `json:"id"`
	Kind    string `json:"kind"`
	Balance int64  `json:"balance_kobo"`
}

type DeviceRow struct {
	ID         string     `json:"id"`
	Active     bool       `json:"active"`
	LastSeenAt *time.Time `json:"last_seen_at"`
	CreatedAt  time.Time  `json:"created_at"`
}

type CeilingRow struct {
	ID        string    `json:"id"`
	Status    string    `json:"status"`
	Amount    int64     `json:"amount_kobo"`
	Remaining int64     `json:"remaining_kobo"`
	IssuedAt  time.Time `json:"issued_at"`
	ExpiresAt time.Time `json:"expires_at"`
}

type FraudRow struct {
	ID        string    `json:"id"`
	Signal    string    `json:"signal"`
	Severity  string    `json:"severity"`
	Weight    float64   `json:"weight"`
	CreatedAt time.Time `json:"created_at"`
}

func (s *Service) GetUser(ctx context.Context, id string) (UserDetail, error) {
	var d UserDetail
	header, err := s.Repo.GetUserWithBalances(ctx, id)
	if err != nil {
		return d, err
	}
	d.User = UserRow(header)
	accs, err := s.Repo.ListAccountsForUser(ctx, id)
	if err != nil {
		return d, err
	}
	d.Accounts = make([]AccountRow, 0, len(accs))
	for _, a := range accs {
		d.Accounts = append(d.Accounts, AccountRow(a))
	}
	devs, err := s.Repo.ListDevicesForUser(ctx, id)
	if err != nil {
		return d, err
	}
	d.Devices = make([]DeviceRow, 0, len(devs))
	for _, v := range devs {
		d.Devices = append(d.Devices, DeviceRow(v))
	}
	ceils, err := s.Repo.ListCeilingsForUser(ctx, id, 20)
	if err != nil {
		return d, err
	}
	d.Ceilings = make([]CeilingRow, 0, len(ceils))
	for _, c := range ceils {
		d.Ceilings = append(d.Ceilings, CeilingRow(c))
	}
	frauds, err := s.Repo.ListFraudSignalsForUser(ctx, id, 20)
	if err != nil {
		return d, err
	}
	d.Fraud = make([]FraudRow, 0, len(frauds))
	for _, f := range frauds {
		d.Fraud = append(d.Fraud, FraudRow(f))
	}
	txns, _ := s.listTxns(ctx, txnFilter{Payer: id, PerPage: 10, Page: 1})
	d.Recent = txns.Items
	return d, nil
}

// TransactionRow is the unified admin txn projection. `Kind` is one of
// "payment_token" (offline-pay ceiling-backed flow) or "transfer"
// (online P2P). Sequence/CeilingID/BatchID/SubmittedAt only carry
// meaning for "payment_token" rows; transfers leave them zero/empty.
type TransactionRow struct {
	ID              string     `json:"id"`
	PayerID         string     `json:"payer_id"`
	PayeeID         string     `json:"payee_id"`
	Amount          int64      `json:"amount_kobo"`
	Settled         int64      `json:"settled_amount_kobo"`
	Status          string     `json:"status"`
	Sequence        int64      `json:"sequence_number"`
	CeilingID       string     `json:"ceiling_id"`
	BatchID         *string    `json:"settlement_batch_id"`
	RejectionReason *string    `json:"rejection_reason"`
	CreatedAt       time.Time  `json:"created_at"`
	SubmittedAt     *time.Time `json:"submitted_at"`
	SettledAt       *time.Time `json:"settled_at"`
	Kind            string     `json:"kind"`
}

type txnFilter struct {
	Status  string
	Payer   string
	Payee   string
	Batch   string
	Page    int
	PerPage int
}

func (s *Service) ListTransactions(ctx context.Context, status, payer, payee string, page, perPage int) (Paged[TransactionRow], error) {
	return s.listTxns(ctx, txnFilter{Status: status, Payer: payer, Payee: payee, Page: page, PerPage: perPage})
}

func (s *Service) listTxns(ctx context.Context, f txnFilter) (Paged[TransactionRow], error) {
	if f.PerPage <= 0 || f.PerPage > 500 {
		f.PerPage = 25
	}
	if f.Page < 1 {
		f.Page = 1
	}
	filter := adminrepo.TxnFilter{Status: f.Status, Payer: f.Payer, Payee: f.Payee, Batch: f.Batch}
	total, err := s.Repo.CountTxns(ctx, filter)
	if err != nil {
		return Paged[TransactionRow]{}, err
	}
	rows, err := s.Repo.ListTxns(ctx, filter, adminrepo.TxnPage{
		Limit: int32(f.PerPage), Offset: int32((f.Page - 1) * f.PerPage),
	})
	if err != nil {
		return Paged[TransactionRow]{}, err
	}
	items := make([]TransactionRow, 0, len(rows))
	for _, r := range rows {
		items = append(items, TransactionRow(r))
	}
	return Paged[TransactionRow]{Items: items, Total: total, Page: f.Page, PerPage: f.PerPage}, nil
}

func (s *Service) GetTransaction(ctx context.Context, id string) (TransactionRow, error) {
	r, err := s.Repo.GetTxn(ctx, id)
	if err != nil {
		return TransactionRow{}, err
	}
	return TransactionRow(r), nil
}

// Settlements: batched views over payment_tokens.settlement_batch_id.
type SettlementBatch struct {
	ID             string           `json:"id"`
	TxnCount       int64            `json:"txn_count"`
	SubmittedVol   int64            `json:"submitted_volume_kobo"`
	SettledVol     int64            `json:"settled_volume_kobo"`
	StatesCount    map[string]int64 `json:"state_counts"`
	FirstSubmitted *time.Time       `json:"first_submitted_at"`
	LastSettled    *time.Time       `json:"last_settled_at"`
}

func (s *Service) ListSettlements(ctx context.Context, page, perPage int) (Paged[SettlementBatch], error) {
	if perPage <= 0 || perPage > 200 {
		perPage = 25
	}
	if page < 1 {
		page = 1
	}
	total, err := s.Repo.CountSettlementBatches(ctx)
	if err != nil {
		return Paged[SettlementBatch]{}, err
	}
	rows, err := s.Repo.ListSettlementBatches(ctx, int32(perPage), int32((page-1)*perPage))
	if err != nil {
		return Paged[SettlementBatch]{}, err
	}
	items := make([]SettlementBatch, 0, len(rows))
	for _, r := range rows {
		items = append(items, SettlementBatch{
			ID:             r.ID,
			TxnCount:       r.TxnCount,
			SubmittedVol:   r.SubmittedVol,
			SettledVol:     r.SettledVol,
			StatesCount:    map[string]int64{},
			FirstSubmitted: r.FirstSubmitted,
			LastSettled:    r.LastSettled,
		})
	}
	return Paged[SettlementBatch]{Items: items, Total: total, Page: page, PerPage: perPage}, nil
}

type SettlementDetail struct {
	Batch        SettlementBatch  `json:"batch"`
	Transactions []TransactionRow `json:"transactions"`
}

func (s *Service) GetSettlement(ctx context.Context, batchID string) (SettlementDetail, error) {
	var d SettlementDetail
	header, err := s.Repo.GetSettlementHeader(ctx, batchID)
	if err != nil {
		return d, err
	}
	counts, err := s.Repo.GetSettlementStateCounts(ctx, batchID)
	if err != nil {
		return d, err
	}
	d.Batch = SettlementBatch{
		ID:             header.ID,
		TxnCount:       header.TxnCount,
		SubmittedVol:   header.SubmittedVol,
		SettledVol:     header.SettledVol,
		StatesCount:    counts,
		FirstSubmitted: header.FirstSubmitted,
		LastSettled:    header.LastSettled,
	}
	txns, err := s.listTxns(ctx, txnFilter{Batch: batchID, PerPage: 500, Page: 1})
	if err != nil {
		return d, err
	}
	d.Transactions = txns.Items
	return d, nil
}

// FraudSignalRow is the dashboard-facing fraud signal projection. It
// differs from the user-scoped FraudRow above by carrying user_id,
// details, and the optional ceiling/txn refs.
type FraudSignalRow struct {
	ID             string    `json:"id"`
	UserID         string    `json:"user_id"`
	Signal         string    `json:"signal"`
	Severity       string    `json:"severity"`
	Weight         float64   `json:"weight"`
	Details        string    `json:"details"`
	CeilingTokenID *string   `json:"ceiling_token_id,omitempty"`
	TransactionID  *string   `json:"transaction_id,omitempty"`
	CreatedAt      time.Time `json:"created_at"`
}

func (s *Service) ListFraudSignals(ctx context.Context, page, perPage int) (Paged[FraudSignalRow], error) {
	if perPage <= 0 || perPage > 200 {
		perPage = 50
	}
	if page < 1 {
		page = 1
	}
	total, err := s.Repo.CountFraudSignalsGlobal(ctx)
	if err != nil {
		return Paged[FraudSignalRow]{}, err
	}
	rows, err := s.Repo.ListFraudSignalsGlobal(ctx, int32(perPage), int32((page-1)*perPage))
	if err != nil {
		return Paged[FraudSignalRow]{}, err
	}
	items := make([]FraudSignalRow, 0, len(rows))
	for _, r := range rows {
		items = append(items, FraudSignalRow{
			ID:             r.ID,
			UserID:         r.UserID,
			Signal:         r.Signal,
			Severity:       r.Severity,
			Weight:         r.Weight,
			Details:        r.Details,
			CeilingTokenID: r.CeilingTokenID,
			TransactionID:  r.TransactionID,
			CreatedAt:      r.CreatedAt,
		})
	}
	return Paged[FraudSignalRow]{Items: items, Total: total, Page: page, PerPage: perPage}, nil
}

type AuditRow struct {
	ID         int64     `json:"id"`
	ActorEmail string    `json:"actor_email"`
	Action     string    `json:"action"`
	TargetType string    `json:"target_type"`
	TargetID   string    `json:"target_id"`
	IP         string    `json:"ip"`
	CreatedAt  time.Time `json:"created_at"`
}

func (s *Service) ListAudit(ctx context.Context, page, perPage int) (Paged[AuditRow], error) {
	if perPage <= 0 || perPage > 200 {
		perPage = 50
	}
	if page < 1 {
		page = 1
	}
	total, err := s.Repo.CountAuditLog(ctx)
	if err != nil {
		return Paged[AuditRow]{}, err
	}
	rows, err := s.Repo.ListAuditLog(ctx, int32(perPage), int32((page-1)*perPage))
	if err != nil {
		return Paged[AuditRow]{}, err
	}
	items := make([]AuditRow, 0, len(rows))
	for _, r := range rows {
		items = append(items, AuditRow(r))
	}
	return Paged[AuditRow]{Items: items, Total: total, Page: page, PerPage: perPage}, nil
}
