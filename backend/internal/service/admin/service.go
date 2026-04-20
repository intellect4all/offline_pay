package admin

import (
	"context"
	"crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"strings"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/oklog/ulid/v2"
	"golang.org/x/crypto/bcrypt"

	"github.com/intellect/offlinepay/internal/repository/adminrepo"
)

// Role constants must match rows seeded by 0015_admin_users.up.sql.
const (
	RoleViewer     = "VIEWER"
	RoleSupport    = "SUPPORT"
	RoleFinanceOps = "FINANCE_OPS"
	RoleFraudOps   = "FRAUD_OPS"
	RoleSuperAdmin = "SUPERADMIN"
)

// Service is the admin-api domain service.
type Service struct {
	Repo       *adminrepo.Repo
	Signer     JWTSigner
	RefreshTTL time.Duration
}

func New(pool *pgxpool.Pool, signer JWTSigner, refreshTTL time.Duration) *Service {
	return &Service{Repo: adminrepo.New(pool), Signer: signer, RefreshTTL: refreshTTL}
}

type AdminUser struct {
	ID       string    `json:"id"`
	Email    string    `json:"email"`
	FullName string    `json:"full_name"`
	Status   string    `json:"status"`
	Roles    []string  `json:"roles"`
	Created  time.Time `json:"created_at"`
}

func newID() string {
	return strings.ToLower(ulid.MustNew(ulid.Timestamp(time.Now()), rand.Reader).String())
}

// CreateAdmin inserts an admin user with the given password and role names.
// Used by opsctl for seeding + by SUPERADMIN user-management endpoints.
func (s *Service) CreateAdmin(ctx context.Context, email, fullName, password string, roles []string) (AdminUser, error) {
	if password == "" {
		return AdminUser{}, errors.New("password required")
	}
	hash, err := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
	if err != nil {
		return AdminUser{}, err
	}
	out, err := s.Repo.CreateAdmin(ctx, adminrepo.CreateAdminInput{
		ID:           newID(),
		Email:        strings.ToLower(email),
		FullName:     fullName,
		PasswordHash: string(hash),
		Roles:        roles,
	})
	if err != nil {
		return AdminUser{}, err
	}
	return AdminUser{
		ID:       out.ID,
		Email:    out.Email,
		FullName: out.FullName,
		Status:   out.Status,
		Created:  out.Created,
		Roles:    roles,
	}, nil
}

type LoginResult struct {
	Access     string    `json:"access_token"`
	Refresh    string    `json:"refresh_token"`
	ExpiresAt  time.Time `json:"expires_at"`
	RefreshExp time.Time `json:"refresh_expires_at"`
	User       AdminUser `json:"user"`
}

func (s *Service) Login(ctx context.Context, email, password, ua, ip string) (LoginResult, error) {
	var zero LoginResult
	row, hash, err := s.Repo.GetAdminForLogin(ctx, strings.ToLower(email))
	if err != nil {
		return zero, errors.New("invalid credentials")
	}
	if row.Status != "ACTIVE" {
		return zero, errors.New("account not active")
	}
	if bcrypt.CompareHashAndPassword([]byte(hash), []byte(password)) != nil {
		return zero, errors.New("invalid credentials")
	}
	roles, err := s.Repo.ListAdminRoleNames(ctx, row.ID)
	if err != nil {
		return zero, err
	}
	u := AdminUser{
		ID:       row.ID,
		Email:    row.Email,
		FullName: row.FullName,
		Status:   row.Status,
		Created:  row.Created,
		Roles:    roles,
	}
	access, err := s.Signer.Sign(u.ID, u.Email, roles)
	if err != nil {
		return zero, err
	}
	refresh, refreshHash := newRefreshToken()
	exp := time.Now().Add(s.RefreshTTL).UTC()
	if err := s.Repo.CreateAdminSession(ctx, newID(), u.ID, refreshHash, truncate(ua, 512), truncate(ip, 64), exp); err != nil {
		return zero, err
	}
	_ = s.Repo.TouchAdminLastLogin(ctx, u.ID)
	return LoginResult{
		Access: access, Refresh: refresh,
		ExpiresAt:  time.Now().Add(s.Signer.TTL).UTC(),
		RefreshExp: exp,
		User:       u,
	}, nil
}

// Refresh rotates the session: old refresh revoked, new one issued.
func (s *Service) Refresh(ctx context.Context, refresh string) (LoginResult, error) {
	var zero LoginResult
	h := hashRefresh(refresh)
	sess, err := s.Repo.GetAdminSessionByRefreshHash(ctx, h)
	if err != nil {
		return zero, errors.New("invalid refresh")
	}
	if sess.RevokedAt != nil || time.Now().After(sess.ExpiresAt) {
		return zero, errors.New("refresh expired or revoked")
	}
	row, err := s.Repo.GetAdminByID(ctx, sess.AdminUserID)
	if err != nil {
		return zero, err
	}
	if row.Status != "ACTIVE" {
		return zero, errors.New("account not active")
	}
	roles, err := s.Repo.ListAdminRoleNames(ctx, row.ID)
	if err != nil {
		return zero, err
	}
	u := AdminUser{
		ID:       row.ID,
		Email:    row.Email,
		FullName: row.FullName,
		Status:   row.Status,
		Created:  row.Created,
		Roles:    roles,
	}
	access, err := s.Signer.Sign(u.ID, u.Email, roles)
	if err != nil {
		return zero, err
	}
	newRefresh, newHash := newRefreshToken()
	exp := time.Now().Add(s.RefreshTTL).UTC()
	if err := s.Repo.RotateAdminSession(ctx, sess.ID, newID(), u.ID, newHash, exp); err != nil {
		return zero, err
	}
	return LoginResult{
		Access: access, Refresh: newRefresh,
		ExpiresAt:  time.Now().Add(s.Signer.TTL).UTC(),
		RefreshExp: exp,
		User:       u,
	}, nil
}

func (s *Service) Logout(ctx context.Context, refresh string) error {
	return s.Repo.RevokeAdminSessionByHash(ctx, hashRefresh(refresh))
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

type AuditEntry struct {
	ActorID    string
	ActorEmail string
	Action     string
	TargetType string
	TargetID   string
	Payload    any
	IP         string
	UserAgent  string
}

func (s *Service) Audit(ctx context.Context, e AuditEntry) {
	var payload []byte
	if e.Payload != nil {
		if b, err := json.Marshal(e.Payload); err == nil {
			payload = b
		}
	}
	_ = s.Repo.InsertAuditLog(ctx, adminrepo.AuditEntry{
		ActorID:    e.ActorID,
		ActorEmail: e.ActorEmail,
		Action:     e.Action,
		TargetType: e.TargetType,
		TargetID:   e.TargetID,
		Payload:    payload,
		IP:         e.IP,
		UserAgent:  e.UserAgent,
	})
}
