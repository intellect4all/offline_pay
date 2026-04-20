// Package main is a one-shot simulator for the offline payment protocol.
//
// Spins up pgrepo + wallet + settlement services in-process against the
// running Postgres, registers a small roster of payers + merchants, funds
// each payer's offline wallet with a signed ceiling token, then generates
// N signed payment tokens from random payer→merchant pairs, submits each
// merchant's batch as a Phase-4a claim, and drives Phase-4b finalisation
// for every payer. Prints a summary with state distribution, settled
// volume, ledger deltas, and a reconciliation check.
//
// Run:
//
//	DB_URL=postgres://... go run ./cmd/opsim --txns 50 --payers 10 --merchants 5
package main

import (
	"context"
	"crypto/ed25519"
	crand "crypto/rand"
	"flag"
	"fmt"
	"math/rand/v2"
	"os"
	"sort"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/intellect/offlinepay/internal/cache"
	"github.com/intellect/offlinepay/internal/crypto"
	"github.com/intellect/offlinepay/internal/domain"
	"github.com/intellect/offlinepay/internal/repository/pgrepo"
	"github.com/intellect/offlinepay/internal/repository/sqlcgen"
	"github.com/intellect/offlinepay/internal/service/reconciliation"
	"github.com/intellect/offlinepay/internal/service/settlement"
	"github.com/intellect/offlinepay/internal/service/wallet"
)

type payer struct {
	ID      string
	Phone   string
	Acct    string
	Pub     ed25519.PublicKey
	Priv    ed25519.PrivateKey
	Ceiling domain.CeilingToken
	Seq     int64
}

type merchant struct {
	ID    string
	Phone string
	Acct  string
}

// localSigner satisfies crypto.CeilingSigner with an in-memory Ed25519
// private key. Used here so the wallet service can issue ceiling tokens
// without talking to a real KMS.
type localSigner struct {
	keyID string
	priv  ed25519.PrivateKey
}

func (l localSigner) Sign(_ context.Context, keyID string, msg []byte) ([]byte, error) {
	if keyID != l.keyID {
		return nil, fmt.Errorf("localSigner: key mismatch want=%s got=%s", l.keyID, keyID)
	}
	return ed25519.Sign(l.priv, msg), nil
}

func main() {
	dbURL := flag.String("db", getenv("DB_URL", "postgres://offlinepay:offlinepay@localhost:5432/offlinepay?sslmode=disable"), "Postgres DSN")
	nTxns := flag.Int("txns", 50, "number of offline txns to simulate")
	nPayers := flag.Int("payers", 10, "payer count")
	nMerchants := flag.Int("merchants", 5, "merchant count")
	fundKobo := flag.Int64("fund", 10_000_00, "kobo to fund each payer's offline wallet with (default ₦10k)")
	seed := flag.Int64("seed", time.Now().UnixNano(), "prng seed")
	flag.Parse()

	ctx := context.Background()
	rng := rand.New(rand.NewPCG(uint64(*seed), 0))

	pool, err := pgxpool.New(ctx, *dbURL)
	must(err)
	defer pool.Close()
	must(pool.Ping(ctx))

	repo := pgrepo.New(pool, cache.Noop{})
	walletSvc := wallet.New(wallet.NewPgRepoAdapter(repo))
	settleSvc := settlement.New(settlement.NewPgRepoAdapter(repo))
	reconSvc := reconciliation.New(reconciliation.NewPgRepoAdapter(repo))

	active, err := repo.GetActiveBankSigningKey(ctx)
	if err != nil {
		fmt.Fprintf(os.Stderr, "need an active bank signing key (run `opsctl rotate-bank-key`): %v\n", err)
		os.Exit(1)
	}
	walletSvc.Signer = localSigner{keyID: active.KeyID, priv: active.PrivateKey}
	fmt.Printf("seed=%d  db=%s  active bank key=%s\n", *seed, *dbURL, active.KeyID)

	// Migration 0019 truncates the users table, which also drops the
	// system-settlement user + system-suspense account seeded by 0005.
	// Re-seed them here (idempotent) so the double-entry ledger can
	// post against the suspense account.
	seedSystemAccounts(ctx, pool)

	// Use the seed to place phone/account_number in a unique 6-digit
	// bucket so multiple sim runs don't collide on uniqueness.
	ns := uint64(*seed) % 1_000_000 // 6 digits
	payers := make([]*payer, *nPayers)
	for i := range payers {
		pub, priv, err := ed25519.GenerateKey(crand.Reader)
		must(err)
		// +234 + 10 digits = 14. Layout: 8 (Nigerian prefix) + 6-digit ns + 3-digit user idx.
		phone := fmt.Sprintf("+2348%06d%03d", ns, i)
		acct := phone[len(phone)-10:]
		uid, err := repo.RegisterUser(ctx, phone, acct, "", "TIER_3", 1)
		must(err)
		must(repo.SetUserPayerPubkey(ctx, uid, pub))
		payers[i] = &payer{ID: uid, Phone: phone, Acct: acct, Pub: pub, Priv: priv}
	}
	merchants := make([]*merchant, *nMerchants)
	for i := range merchants {
		phone := fmt.Sprintf("+2349%06d%03d", ns, i)
		acct := phone[len(phone)-10:]
		uid, err := repo.RegisterUser(ctx, phone, acct, "", "TIER_3", 1)
		must(err)
		merchants[i] = &merchant{ID: uid, Phone: phone, Acct: acct}
	}
	fmt.Printf("registered %d payers + %d merchants (phone ns=%07d)\n", len(payers), len(merchants), ns)

	// Fund each payer's offline wallet.
	for _, p := range payers {
		creditMain(ctx, repo, p.ID, *fundKobo)
		ct, err := walletSvc.FundOffline(ctx, p.ID, *fundKobo, 30*time.Minute)
		must(err)
		p.Ceiling = ct
		p.Seq = ct.SequenceStart
	}
	fmt.Printf("funded each payer's offline wallet with ₦%s (ceiling token signed by bank)\n\n",
		kobo(*fundKobo))

	// Generate N offline payment tokens.
	type pendingClaim struct {
		Payer    *payer
		Merchant *merchant
		Item     settlement.ClaimItem
		Amount   int64
	}
	var pending []pendingClaim
	for i := 0; i < *nTxns; i++ {
		p := payers[rng.IntN(len(payers))]
		m := merchants[rng.IntN(len(merchants))]
		amount := int64(50_00 + rng.IntN(500_00)) // ₦50 – ₦550
		tok := signPayment(p, m.ID, amount, time.Now().UTC())
		pending = append(pending, pendingClaim{
			Payer: p, Merchant: m,
			Item: settlement.ClaimItem{Payment: tok, Ceiling: p.Ceiling}, Amount: amount,
		})
	}
	fmt.Printf("generated %d offline payment tokens (signed with payer Ed25519 keys)\n\n", len(pending))

	// Phase 4a: merchant claim (group by merchant).
	fmt.Println("Phase 4a — Merchant claims:")
	byMerchant := map[string][]pendingClaim{}
	for _, c := range pending {
		byMerchant[c.Merchant.ID] = append(byMerchant[c.Merchant.ID], c)
	}
	var totalSettled, totalPartial, totalRejected int
	var totalVolume int64
	batches := 0
	for _, m := range merchants {
		items := byMerchant[m.ID]
		if len(items) == 0 {
			continue
		}
		batch := make([]settlement.ClaimItem, 0, len(items))
		for _, c := range items {
			batch = append(batch, c.Item)
		}
		b, _, err := settleSvc.SubmitClaim(ctx, m.ID, batch)
		must(err)
		totalSettled += b.TotalSettled
		totalPartial += b.TotalPartial
		totalRejected += b.TotalRejected
		totalVolume += b.TotalAmount
		batches++
		fmt.Printf("  batch=%s merchant=%s submitted=%d pending=%d rejected=%d\n",
			trunc(b.ID, 12), m.Acct, b.TotalSubmitted,
			b.TotalSubmitted-b.TotalRejected, b.TotalRejected)
	}

	// Phase 4b: payer finalises.
	fmt.Println("\nPhase 4b — Payer finalisation:")
	finalByStatus := map[string]int{}
	var finalAmount int64
	for _, p := range payers {
		results, err := settleSvc.FinalizeForPayer(ctx, p.ID)
		must(err)
		if len(results) == 0 {
			continue
		}
		settled, partial := 0, 0
		for _, r := range results {
			finalByStatus[string(r.Status)]++
			if r.Status == domain.TxSettled {
				settled++
			}
			if r.Status == domain.TxPartiallySettled {
				partial++
			}
			finalAmount += r.SettledAmount
		}
		fmt.Printf("  payer=%s processed=%d settled=%d partial=%d\n",
			p.Acct, len(results), settled, partial)
	}

	fmt.Println("\n=== Summary ===")
	fmt.Printf("offline txns signed:        %d\n", len(pending))
	fmt.Printf("merchants who submitted:    %d / %d\n", batches, len(merchants))
	fmt.Printf("Phase 4a rejected:          %d\n", totalRejected)
	fmt.Printf("Phase 4b terminal states:   %v\n", sortedCounts(finalByStatus))
	fmt.Printf("final settled volume:       ₦%s\n", kobo(finalAmount))
	fmt.Printf("seed:                       %d\n", *seed)

	// Merchant balances. Settled offline-payment funds are now credited
	// directly to each merchant's main wallet (the intermediate
	// receiving_available bucket was retired).
	fmt.Println("\nMerchant balances (receiving_pending in-flight + main spendable):")
	fmt.Printf("  %-13s %-13s %-13s %-s\n", "merchant", "pending", "main", "total")
	var totPending, totMain int64
	for _, m := range merchants {
		pendID, _ := repo.GetAccountID(ctx, m.ID, sqlcgen.AccountKindReceivingPending)
		mainID, _ := repo.GetAccountID(ctx, m.ID, sqlcgen.AccountKindMain)
		pendBal := balanceOf(ctx, pool, pendID)
		mainBal := balanceOf(ctx, pool, mainID)
		fmt.Printf("  %-13s ₦%-12s ₦%-12s ₦%s\n", m.Acct, kobo(pendBal), kobo(mainBal), kobo(pendBal+mainBal))
		totPending += pendBal
		totMain += mainBal
	}
	fmt.Printf("  %-13s ₦%-12s ₦%-12s ₦%s\n", "TOTAL", kobo(totPending), kobo(totMain), kobo(totPending+totMain))

	// Payer lien state
	fmt.Println("\nPayer lien-holding balances (remaining held funds):")
	var totLien int64
	for _, p := range payers {
		lienID, _ := repo.GetAccountID(ctx, p.ID, sqlcgen.AccountKindLienHolding)
		totLien += balanceOf(ctx, pool, lienID)
	}
	funded := *fundKobo * int64(len(payers))
	fmt.Printf("  total lien-holding across %d payers: ₦%s (funded: ₦%s, spent: ₦%s)\n",
		len(payers), kobo(totLien), kobo(funded), kobo(funded-totLien))

	fmt.Println("\nLedger reconciliation (double-entry check):")
	res, err := reconSvc.NightlyLedgerReconcile(ctx)
	if err != nil {
		fmt.Printf("  reconcile err: %v\n", err)
	} else {
		fmt.Printf("  run=%s status=%s discrepancies=%d\n", res.ID, res.Status, len(res.Discrepancies))
		for _, d := range res.Discrepancies {
			fmt.Printf("   - txn=%s field=%s expected=%s actual=%s severity=%s\n",
				d.TransactionID, d.Field, d.Expected, d.Actual, d.Severity)
		}
	}
}

func signPayment(p *payer, toID string, amount int64, ts time.Time) domain.PaymentToken {
	p.Seq++
	remaining := p.Ceiling.CeilingAmount - amount
	if remaining < 0 {
		remaining = 0
	}
	payload := domain.PaymentPayload{
		PayerID:          p.ID,
		PayeeID:          toID,
		Amount:           amount,
		SequenceNumber:   p.Seq,
		RemainingCeiling: remaining,
		Timestamp:        ts,
		CeilingTokenID:   p.Ceiling.ID,
	}
	sig, err := crypto.SignPayment(p.Priv, payload)
	must(err)
	return domain.PaymentToken{
		PayerID: p.ID, PayeeID: toID, Amount: amount,
		SequenceNumber: p.Seq, RemainingCeiling: remaining,
		Timestamp: ts, CeilingTokenID: p.Ceiling.ID,
		PayerSignature: sig,
	}
}

// creditMain posts a balanced ledger pair that credits a user's main
// account (funded from the system-suspense account). Records a
// transactions row first so the ledger FK resolves.
func creditMain(ctx context.Context, repo *pgrepo.Repo, userID string, amountKobo int64) {
	accID, err := repo.GetAccountID(ctx, userID, sqlcgen.AccountKindMain)
	must(err)
	txnID := pgrepo.NewID()
	groupID := pgrepo.NewID()
	must(repo.Tx(ctx, func(tx *pgrepo.Repo) error {
		// A transactions row is required for the ledger_entries FK. We
		// use the DEBIT side's id as the ledger txn_id; the CREDIT side
		// gets its own row sharing GroupID.
		if err := tx.RecordTransaction(ctx, pgrepo.RecordTransactionParams{
			ID: txnID, GroupID: groupID, UserID: "system-settlement",
			Kind: domain.TxKindOfflineFund, Status: domain.TxStatusCompleted,
			Direction: "DEBIT", AmountKobo: amountKobo, Memo: "opsim seed",
		}); err != nil {
			return err
		}
		if err := tx.RecordTransaction(ctx, pgrepo.RecordTransactionParams{
			ID: pgrepo.NewID(), GroupID: groupID, UserID: userID,
			Kind: domain.TxKindOfflineFund, Status: domain.TxStatusCompleted,
			Direction: "CREDIT", AmountKobo: amountKobo, Memo: "opsim seed",
		}); err != nil {
			return err
		}
		if err := tx.PostLedger(ctx, txnID, []pgrepo.LedgerLeg{
			{AccountID: settlement.SystemSuspenseAccountID, Direction: "DEBIT", Amount: amountKobo, Memo: "opsim seed"},
			{AccountID: accID, Direction: "CREDIT", Amount: amountKobo, Memo: "opsim seed"},
		}); err != nil {
			return err
		}
		if err := tx.ForceDebitAccount(ctx, settlement.SystemSuspenseAccountID, amountKobo); err != nil {
			return err
		}
		return tx.CreditAccount(ctx, accID, amountKobo)
	}))
}

// seedSystemAccounts ensures the system-settlement user + system-suspense
// account exist. Idempotent: ON CONFLICT DO NOTHING on both inserts.
func seedSystemAccounts(ctx context.Context, pool *pgxpool.Pool) {
	_, err := pool.Exec(ctx, `
		INSERT INTO users (id, phone, account_number, kyc_tier, realm_key_version,
		                   first_name, last_name, email, password_hash)
		VALUES ('system-settlement', 'system-settlement', '0000000000', 'TIER_0', 0,
		        'System', 'Settlement', 'system@offlinepay.local', '')
		ON CONFLICT (id) DO NOTHING`)
	must(err)
	_, err = pool.Exec(ctx, `
		INSERT INTO accounts (id, user_id, kind, balance_kobo)
		VALUES ('system-suspense', 'system-settlement', 'suspense', 0)
		ON CONFLICT (id) DO NOTHING`)
	must(err)
}

func balanceOf(ctx context.Context, pool *pgxpool.Pool, accountID string) int64 {
	var v int64
	_ = pool.QueryRow(ctx, `SELECT balance_kobo FROM accounts WHERE id = $1`, accountID).Scan(&v)
	return v
}

func must(err error) {
	if err != nil {
		panic(err)
	}
}

func getenv(k, def string) string {
	if v := os.Getenv(k); v != "" {
		return v
	}
	return def
}

// kobo → "123.45" naira string.
func kobo(v int64) string {
	return fmt.Sprintf("%d.%02d", v/100, v%100)
}

func trunc(s string, n int) string {
	if len(s) <= n {
		return s
	}
	return s[:n] + "…"
}

func sortedCounts(m map[string]int) []string {
	out := make([]string, 0, len(m))
	for k := range m {
		out = append(out, k)
	}
	sort.Strings(out)
	for i, k := range out {
		out[i] = fmt.Sprintf("%s=%d", k, m[k])
	}
	return out
}
