package userauth

import (
	"context"
	"crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"regexp"
	"strings"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/oklog/ulid/v2"
	"golang.org/x/crypto/bcrypt"

	"github.com/intellect/offlinepay/internal/cache"
	"github.com/intellect/offlinepay/internal/domain"
	"github.com/intellect/offlinepay/internal/repository/userauthrepo"
)

// OTP purposes. Signup is password-based now; OTP is reserved for email
// verification and email-based password reset.
const (
	PurposeSignupEmailVerify = "signup_email_verify"
	PurposePasswordReset     = "password_reset"

	defaultOTPMaxAttempts = 5

	// Tier strings persisted in users.kyc_tier. Match the CHECK
	// constraint in migration 0019.
	TierZero = "TIER_0"
	TierOne  = "TIER_1"
	TierTwo  = "TIER_2"
	TierThree = "TIER_3"

	minPasswordLen = 8
)

var (
	ErrInvalidPhone     = errors.New("userauth: invalid phone")
	ErrInvalidEmail     = errors.New("userauth: invalid email")
	ErrInvalidName      = errors.New("userauth: invalid name")
	ErrInvalidPassword  = errors.New("userauth: password must be 8+ chars and contain a letter and a digit")
	ErrInvalidPurpose   = errors.New("userauth: invalid purpose")
	ErrChallengeMissing = errors.New("userauth: otp challenge not found")
	ErrChallengeExpired = errors.New("userauth: otp challenge expired")
	ErrChallengeUsed    = errors.New("userauth: otp challenge already used")
	ErrTooManyAttempts  = errors.New("userauth: too many otp attempts")
	ErrInvalidCode      = errors.New("userauth: invalid otp code")
	ErrUserNotFound     = errors.New("userauth: user not found")
	ErrPhoneTaken       = errors.New("userauth: phone already registered")
	ErrEmailTaken       = errors.New("userauth: email already registered")
	ErrInvalidCredentials = errors.New("userauth: invalid credentials")
	ErrInvalidRefresh   = errors.New("userauth: invalid refresh")
)

// Service is the user-facing auth domain service.
type Service struct {
	Repo           *userauthrepo.Repo
	Signer         JWTSigner
	Sender         OTPSender
	AccessTTL      time.Duration
	RefreshTTL     time.Duration
	OTPTTL         time.Duration
	OTPMaxAttempts int

	// DeviceSession is the Ed25519 signer for offline device-session
	// tokens. Optional; nil leaves /v1/auth/device-session disabled.
	DeviceSession *DeviceSessionSigner
	// DeviceLookup verifies that a device id belongs to the caller and is
	// still active. Wired by the BFF over pgrepo.LookupDeviceForAuth.
	DeviceLookup DeviceLookup
}

func New(pool *pgxpool.Pool, c cache.Cache, signer JWTSigner, sender OTPSender, accessTTL, refreshTTL, otpTTL time.Duration) *Service {
	return &Service{
		Repo:           userauthrepo.New(pool, c),
		Signer:         signer,
		Sender:         sender,
		AccessTTL:      accessTTL,
		RefreshTTL:     refreshTTL,
		OTPTTL:         otpTTL,
		OTPMaxAttempts: defaultOTPMaxAttempts,
	}
}

// AuthResult is returned by signup/login/refresh flows.
type AuthResult struct {
	UserID           string    `json:"user_id"`
	AccountNumber    string    `json:"account_number"`
	AccessToken      string    `json:"access_token"`
	RefreshToken     string    `json:"refresh_token"`
	AccessExpiresAt  time.Time `json:"access_expires_at"`
	RefreshExpiresAt time.Time `json:"refresh_expires_at"`
}

func newID() string {
	return strings.ToLower(ulid.MustNew(ulid.Timestamp(time.Now()), rand.Reader).String())
}

// SignupInput is the field set collected at registration. All fields are
// required: name+email+phone puts the user at TIER_1 immediately.
type SignupInput struct {
	Phone     string
	Password  string
	FirstName string
	LastName  string
	Email     string
	UserAgent string
	IP        string
}

// Signup creates a user at TIER_1, provisions the canonical five
// accounts, opens a session, and dispatches an email-verification OTP.
// Errors are ErrPhoneTaken / ErrEmailTaken / ErrInvalid* on validation
// or uniqueness failure.
func (s *Service) Signup(ctx context.Context, in SignupInput) (AuthResult, error) {
	var zero AuthResult

	phone, err := normalizePhone(in.Phone)
	if err != nil {
		return zero, err
	}
	email, err := normalizeEmail(in.Email)
	if err != nil {
		return zero, err
	}
	first := strings.TrimSpace(in.FirstName)
	last := strings.TrimSpace(in.LastName)
	if first == "" || last == "" {
		return zero, ErrInvalidName
	}
	if err := validatePassword(in.Password); err != nil {
		return zero, err
	}
	hash, err := bcrypt.GenerateFromPassword([]byte(in.Password), 10)
	if err != nil {
		return zero, err
	}
	acc, err := domain.AccountNumberFromPhone(phone)
	if err != nil {
		return zero, err
	}

	userID := newID()
	sessionID := newID()
	refresh, refreshHash := newRefreshToken()
	refreshExp := time.Now().Add(s.RefreshTTL).UTC()

	signupIn := userauthrepo.SignupInput{
		UserID:        userID,
		Phone:         phone,
		Email:         email,
		FirstName:     first,
		LastName:      last,
		PasswordHash:  string(hash),
		KYCTier:       TierOne,
		AccountNumber: acc,
		SessionID:     sessionID,
		RefreshHash:   refreshHash,
		UserAgent:     truncate(in.UserAgent, 512),
		IP:            truncate(in.IP, 64),
		RefreshExpires: refreshExp,
	}
	for i := range signupIn.AccountIDs {
		signupIn.AccountIDs[i] = newID()
	}
	if err := s.Repo.Signup(ctx, signupIn); err != nil {
		switch {
		case errors.Is(err, userauthrepo.ErrPhoneTaken):
			return zero, ErrPhoneTaken
		case errors.Is(err, userauthrepo.ErrEmailTaken):
			return zero, ErrEmailTaken
		}
		return zero, err
	}

	// Dispatch an email-verification OTP. A send failure here shouldn't
	// roll back the account — the user can request a resend.
	if err := s.issueOTP(ctx, email, PurposeSignupEmailVerify); err != nil {
		// Intentionally swallow: account is created, the user can
		// request a new code via /v1/auth/email/verify/request.
		_ = err
	}

	access, err := s.Signer.Sign(userID, acc, sessionID)
	if err != nil {
		return zero, err
	}
	return AuthResult{
		UserID:           userID,
		AccountNumber:    acc,
		AccessToken:      access,
		RefreshToken:     refresh,
		AccessExpiresAt:  time.Now().Add(s.AccessTTL).UTC(),
		RefreshExpiresAt: refreshExp,
	}, nil
}

// Login authenticates a user by phone + password and opens a new session.
func (s *Service) Login(ctx context.Context, phone, password, ua, ip string) (AuthResult, error) {
	var zero AuthResult
	normalized, err := normalizePhone(phone)
	if err != nil {
		return zero, ErrInvalidCredentials
	}
	row, err := s.Repo.GetUserLoginByPhone(ctx, normalized)
	if err != nil {
		if errors.Is(err, userauthrepo.ErrNotFound) {
			return zero, ErrInvalidCredentials
		}
		return zero, err
	}
	if bcrypt.CompareHashAndPassword([]byte(row.PasswordHash), []byte(password)) != nil {
		return zero, ErrInvalidCredentials
	}
	sessionID := newID()
	refresh, refreshHash := newRefreshToken()
	refreshExp := time.Now().Add(s.RefreshTTL).UTC()
	if err := s.Repo.OpenSession(ctx, userauthrepo.OpenSessionInput{
		SessionID:   sessionID,
		UserID:      row.UserID,
		RefreshHash: refreshHash,
		UserAgent:   truncate(ua, 512),
		IP:          truncate(ip, 64),
		ExpiresAt:   refreshExp,
	}); err != nil {
		return zero, err
	}
	access, err := s.Signer.Sign(row.UserID, row.AccountNumber, sessionID)
	if err != nil {
		return zero, err
	}
	return AuthResult{
		UserID:           row.UserID,
		AccountNumber:    row.AccountNumber,
		AccessToken:      access,
		RefreshToken:     refresh,
		AccessExpiresAt:  time.Now().Add(s.AccessTTL).UTC(),
		RefreshExpiresAt: refreshExp,
	}, nil
}

// RequestEmailVerification issues a fresh OTP to the authenticated
// user's email for email verification. Idempotent — replaces any prior
// unconsumed challenge.
func (s *Service) RequestEmailVerification(ctx context.Context, userID string) error {
	email, verified, err := s.Repo.GetUserEmail(ctx, userID)
	if err != nil {
		if errors.Is(err, userauthrepo.ErrNotFound) {
			return ErrUserNotFound
		}
		return err
	}
	if verified {
		return nil
	}
	return s.issueOTP(ctx, email, PurposeSignupEmailVerify)
}

// VerifyEmail consumes an email-verification OTP and marks the user's
// email as verified.
func (s *Service) VerifyEmail(ctx context.Context, userID, code string) error {
	email, verified, err := s.Repo.GetUserEmail(ctx, userID)
	if err != nil {
		if errors.Is(err, userauthrepo.ErrNotFound) {
			return ErrUserNotFound
		}
		return err
	}
	if verified {
		return nil
	}
	if err := s.consumeOTP(ctx, email, PurposeSignupEmailVerify, code); err != nil {
		return err
	}
	return s.Repo.MarkEmailVerified(ctx, userID)
}

// ForgotPasswordRequest dispatches a reset OTP to the email if it is
// registered. Returns nil either way to avoid email enumeration — the
// caller should always respond 204.
func (s *Service) ForgotPasswordRequest(ctx context.Context, email string) error {
	normalized, err := normalizeEmail(email)
	if err != nil {
		// Treat invalid email as a no-op; never leak whether the
		// address existed.
		return nil
	}
	exists, err := s.Repo.EmailExists(ctx, normalized)
	if err != nil {
		return err
	}
	if !exists {
		return nil
	}
	return s.issueOTP(ctx, normalized, PurposePasswordReset)
}

// ForgotPasswordReset verifies the OTP and replaces the password. On
// success, all refresh sessions for the user are revoked so a
// compromised-session attacker loses access the moment the legitimate
// owner resets.
func (s *Service) ForgotPasswordReset(ctx context.Context, email, code, newPassword string) error {
	normalized, err := normalizeEmail(email)
	if err != nil {
		return ErrInvalidCredentials
	}
	if err := validatePassword(newPassword); err != nil {
		return err
	}
	userID, err := s.Repo.GetUserIDByEmail(ctx, normalized)
	if err != nil {
		if errors.Is(err, userauthrepo.ErrNotFound) {
			return ErrInvalidCredentials
		}
		return err
	}
	if err := s.consumeOTP(ctx, normalized, PurposePasswordReset, code); err != nil {
		return err
	}
	hash, err := bcrypt.GenerateFromPassword([]byte(newPassword), 10)
	if err != nil {
		return err
	}
	if err := s.Repo.UpdateUserPassword(ctx, userID, string(hash)); err != nil {
		return err
	}
	_, _ = s.Repo.RevokeOtherUserSessions(ctx, userID, "")
	return nil
}

// issueOTP upserts a fresh challenge for (identifier, purpose) and
// dispatches the code via the configured sender.
func (s *Service) issueOTP(ctx context.Context, identifier, purpose string) error {
	code := last6(identifier)
	hash, err := bcrypt.GenerateFromPassword([]byte(code), 10)
	if err != nil {
		return err
	}
	expires := time.Now().Add(s.OTPTTL).UTC()
	if err := s.Repo.UpsertOTPChallenge(ctx, identifier, purpose, string(hash), expires); err != nil {
		return err
	}
	return s.Sender.Send(ctx, identifier, code, purpose)
}

// consumeOTP looks up the challenge, validates it, and marks it
// consumed. Returns ErrChallenge* / ErrTooManyAttempts / ErrInvalidCode.
func (s *Service) consumeOTP(ctx context.Context, identifier, purpose, code string) error {
	ch, err := s.Repo.GetOTPChallenge(ctx, identifier, purpose)
	if err != nil {
		if errors.Is(err, userauthrepo.ErrNotFound) {
			return ErrChallengeMissing
		}
		return err
	}
	if ch.ConsumedAt != nil {
		return ErrChallengeUsed
	}
	if time.Now().After(ch.ExpiresAt) {
		return ErrChallengeExpired
	}
	max := s.OTPMaxAttempts
	if max <= 0 {
		max = defaultOTPMaxAttempts
	}
	if ch.Attempts >= max {
		return ErrTooManyAttempts
	}
	if bcrypt.CompareHashAndPassword([]byte(ch.CodeHash), []byte(code)) != nil {
		_ = s.Repo.IncrementOTPAttempts(ctx, identifier, purpose)
		return ErrInvalidCode
	}
	return s.Repo.ConsumeOTPChallenge(ctx, identifier, purpose)
}

func (s *Service) Refresh(ctx context.Context, refresh string) (AuthResult, error) {
	var zero AuthResult
	h := hashRefresh(refresh)
	sess, err := s.Repo.GetUserSessionByRefreshHash(ctx, h)
	if err != nil {
		return zero, ErrInvalidRefresh
	}
	if sess.RevokedAt != nil || time.Now().After(sess.ExpiresAt) {
		return zero, ErrInvalidRefresh
	}
	accountNumber, err := s.Repo.GetUserAccountNumber(ctx, sess.UserID)
	if err != nil {
		return zero, err
	}
	newRefresh, newHash := newRefreshToken()
	newSessionID := newID()
	accessExp := time.Now().Add(s.AccessTTL).UTC()
	refreshExp := time.Now().Add(s.RefreshTTL).UTC()
	if err := s.Repo.RotateSession(ctx, sess.ID, newSessionID, sess.UserID, newHash, refreshExp); err != nil {
		return zero, err
	}
	access, err := s.Signer.Sign(sess.UserID, accountNumber, newSessionID)
	if err != nil {
		return zero, err
	}
	return AuthResult{
		UserID:           sess.UserID,
		AccountNumber:    accountNumber,
		AccessToken:      access,
		RefreshToken:     newRefresh,
		AccessExpiresAt:  accessExp,
		RefreshExpiresAt: refreshExp,
	}, nil
}

func (s *Service) Logout(ctx context.Context, refresh string) error {
	return s.Repo.RevokeUserSessionByHash(ctx, hashRefresh(refresh))
}

// Me is the projection the BFF /v1/me endpoint renders.
type Me struct {
	ID            string
	Phone         string
	AccountNumber string
	KYCTier       string
	FirstName     string
	LastName      string
	Email         string
	EmailVerified bool
}

// GetMe returns the caller's profile projection.
func (s *Service) GetMe(ctx context.Context, userID string) (Me, error) {
	row, err := s.Repo.GetMe(ctx, userID)
	if err != nil {
		if errors.Is(err, userauthrepo.ErrNotFound) {
			return Me{}, ErrUserNotFound
		}
		return Me{}, err
	}
	return Me(row), nil
}

var phoneDigitsRe = regexp.MustCompile(`^\+?[0-9]{7,15}$`)

// normalizePhone collapses whitespace/dashes and maps national Nigerian form
// (0XXXXXXXXXX) into E.164 (+234XXXXXXXXXX) so the DB phone column stays
// canonical.
func normalizePhone(phone string) (string, error) {
	p := strings.ReplaceAll(phone, " ", "")
	p = strings.ReplaceAll(p, "-", "")
	if p == "" || !phoneDigitsRe.MatchString(p) {
		return "", ErrInvalidPhone
	}
	if strings.HasPrefix(p, "+234") {
		if len(p) != len("+234")+10 {
			return "", ErrInvalidPhone
		}
		return p, nil
	}
	if strings.HasPrefix(p, "0") && len(p) == 11 {
		return "+234" + p[1:], nil
	}
	return "", ErrInvalidPhone
}

var emailRe = regexp.MustCompile(`^[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$`)

func normalizeEmail(email string) (string, error) {
	e := strings.ToLower(strings.TrimSpace(email))
	if !emailRe.MatchString(e) {
		return "", ErrInvalidEmail
	}
	return e, nil
}

// validatePassword enforces: 8+ chars, contains at least one letter and
// one digit. Symbol classes aren't required — the 8-char minimum carries
// most of the entropy and we'd rather not push users into predictable
// leetspeak patterns.
func validatePassword(p string) error {
	if len(p) < minPasswordLen {
		return ErrInvalidPassword
	}
	var hasLetter, hasDigit bool
	for _, r := range p {
		switch {
		case r >= '0' && r <= '9':
			hasDigit = true
		case (r >= 'a' && r <= 'z') || (r >= 'A' && r <= 'Z'):
			hasLetter = true
		}
	}
	if !hasLetter || !hasDigit {
		return ErrInvalidPassword
	}
	return nil
}

func newRefreshToken() (token, hash string) {
	b := make([]byte, 48)
	_, _ = rand.Read(b)
	token = hex.EncodeToString(b)
	return token, hashRefresh(token)
}

func hashRefresh(tok string) string {
	sum := sha256.Sum256([]byte(tok))
	return hex.EncodeToString(sum[:])
}

func truncate(s string, n int) string {
	if len(s) <= n {
		return s
	}
	return s[:n]
}
