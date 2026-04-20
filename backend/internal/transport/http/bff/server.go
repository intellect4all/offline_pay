// Package bff hosts the hand-written BFF handlers that satisfy the
// generated StrictServerInterface from internal/transport/http/bff/gen.
package bff

import (
	"context"
	"encoding/json"
	"errors"
	"log/slog"
	"net/http"

	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/intellect/offlinepay/internal/domain"
	"github.com/intellect/offlinepay/internal/logging"
	"github.com/intellect/offlinepay/internal/service/account"
	"github.com/intellect/offlinepay/internal/service/identity"
	"github.com/intellect/offlinepay/internal/service/kyc"
	"github.com/intellect/offlinepay/internal/service/transfer"
	"github.com/intellect/offlinepay/internal/service/userauth"
	"github.com/intellect/offlinepay/internal/transport/grpc/server"
	bffgen "github.com/intellect/offlinepay/internal/transport/http/bff/gen"
)

// Handler backs the generated StrictServerInterface. DevTopUpEnabled gates
// the dev-only main-wallet credit endpoint — never set it in production.
// Pool is only consulted by that endpoint; nil-safe otherwise.
//
// Wallet / Settlement / Keys / Registration point at the in-process
// handler structs from internal/transport/grpc/server. They are plain
// Go structs now — no gRPC hop — but still use the protobuf message
// types as internal DTOs.
type Handler struct {
	Auth      *userauth.Service
	Transfers *transfer.Service
	Accounts  *account.Service
	KYC       *kyc.Service
	Identity  *identity.Service
	Logger    *slog.Logger

	Wallet       *server.WalletServer
	Settlement   *server.SettlementServer
	Keys         *server.KeysServer
	Registration *server.RegistrationServer

	DevTopUpEnabled bool
	Pool            *pgxpool.Pool
}

func NewHandler(auth *userauth.Service, transfers *transfer.Service, accounts *account.Service, kycSvc *kyc.Service, logger *slog.Logger) *Handler {
	return &Handler{Auth: auth, Transfers: transfers, Accounts: accounts, KYC: kycSvc, Logger: logging.Or(logger)}
}

// authCtx attaches the authenticated user to the context in the shape the
// in-process server handlers expect (server.AuthUser under a private key).
// DeviceID is synthetic — device-JWT auth went away with the gRPC hop;
// handlers that want "the caller's device" should continue reading
// AuthUser.DeviceID, which now carries "bff" for any in-process call.
func authCtx(ctx context.Context, userID string) context.Context {
	return server.WithAuthUser(ctx, server.AuthUser{UserID: userID, DeviceID: "bff"})
}

func (h *Handler) GetHealth(_ context.Context, _ bffgen.GetHealthRequestObject) (bffgen.GetHealthResponseObject, error) {
	return bffgen.GetHealth200JSONResponse{Status: "ok"}, nil
}

func (h *Handler) PostV1AuthSignup(ctx context.Context, req bffgen.PostV1AuthSignupRequestObject) (bffgen.PostV1AuthSignupResponseObject, error) {
	if req.Body == nil {
		return bffgen.PostV1AuthSignup400JSONResponse{Code: "bad_request", Message: "missing body"}, nil
	}
	res, err := h.Auth.Signup(ctx, userauth.SignupInput{
		Phone:     req.Body.Phone,
		Password:  req.Body.Password,
		FirstName: req.Body.FirstName,
		LastName:  req.Body.LastName,
		Email:     string(req.Body.Email),
		UserAgent: userAgentFromContext(ctx),
		IP:        clientIPFromContext(ctx),
	})
	if err != nil {
		switch {
		case errors.Is(err, userauth.ErrPhoneTaken):
			return bffgen.PostV1AuthSignup409JSONResponse{Code: "phone_taken", Message: "phone already registered"}, nil
		case errors.Is(err, userauth.ErrEmailTaken):
			return bffgen.PostV1AuthSignup409JSONResponse{Code: "email_taken", Message: "email already registered"}, nil
		case errors.Is(err, userauth.ErrInvalidPhone),
			errors.Is(err, userauth.ErrInvalidEmail),
			errors.Is(err, userauth.ErrInvalidName),
			errors.Is(err, userauth.ErrInvalidPassword),
			errors.Is(err, domain.ErrUnsupportedPhoneFormat):
			return bffgen.PostV1AuthSignup400JSONResponse{Code: "invalid_request", Message: err.Error()}, nil
		}
		h.Logger.Error("auth.signup", "err", err)
		return nil, err
	}
	dto := authResultToDTO(res)
	if h.Identity != nil {
		if card, err := h.Identity.IssueDisplayCard(ctx, res.UserID); err != nil {
			// Signup should not fail because the card couldn't be signed —
			// the client will refresh via GET /v1/identity/display-card. Log
			// loud so we catch misconfiguration quickly.
			h.Logger.Error("identity.display_card_signup", "user_id", res.UserID, "err", err)
		} else {
			c := displayCardToInput(server.DisplayCardToProto(card))
			dto.DisplayCard = &c
		}
	}
	return bffgen.PostV1AuthSignup200JSONResponse(dto), nil
}

func (h *Handler) GetV1IdentityDisplayCard(ctx context.Context, _ bffgen.GetV1IdentityDisplayCardRequestObject) (bffgen.GetV1IdentityDisplayCardResponseObject, error) {
	claims, ok := ClaimsFromContext(ctx)
	if !ok || claims.Sub == "" {
		return bffgen.GetV1IdentityDisplayCard401JSONResponse{Code: "unauthorized", Message: "missing claims"}, nil
	}
	if h.Identity == nil {
		return bffgen.GetV1IdentityDisplayCard502JSONResponse{Code: "unconfigured", Message: "identity service not wired"}, nil
	}
	card, err := h.Identity.IssueDisplayCard(ctx, claims.Sub)
	if err != nil {
		h.Logger.Warn("identity.display_card", "user_id", claims.Sub, "err", err)
		return bffgen.GetV1IdentityDisplayCard502JSONResponse{Code: "sign_failure", Message: err.Error()}, nil
	}
	return bffgen.GetV1IdentityDisplayCard200JSONResponse(displayCardToInput(server.DisplayCardToProto(card))), nil
}

func (h *Handler) PostV1AuthLogin(ctx context.Context, req bffgen.PostV1AuthLoginRequestObject) (bffgen.PostV1AuthLoginResponseObject, error) {
	if req.Body == nil {
		return bffgen.PostV1AuthLogin401JSONResponse{Code: "invalid_credentials", Message: "invalid credentials"}, nil
	}
	res, err := h.Auth.Login(ctx, req.Body.Phone, req.Body.Password, userAgentFromContext(ctx), clientIPFromContext(ctx))
	if err != nil {
		if errors.Is(err, userauth.ErrInvalidCredentials) {
			return bffgen.PostV1AuthLogin401JSONResponse{Code: "invalid_credentials", Message: "invalid credentials"}, nil
		}
		h.Logger.Error("auth.login", "err", err)
		return nil, err
	}
	return bffgen.PostV1AuthLogin200JSONResponse(authResultToDTO(res)), nil
}

func (h *Handler) PostV1AuthEmailVerifyRequest(ctx context.Context, _ bffgen.PostV1AuthEmailVerifyRequestRequestObject) (bffgen.PostV1AuthEmailVerifyRequestResponseObject, error) {
	claims, ok := ClaimsFromContext(ctx)
	if !ok {
		return bffgen.PostV1AuthEmailVerifyRequest401JSONResponse{Code: "unauthorized", Message: "missing claims"}, nil
	}
	if err := h.Auth.RequestEmailVerification(ctx, claims.Sub); err != nil {
		if errors.Is(err, userauth.ErrUserNotFound) {
			return bffgen.PostV1AuthEmailVerifyRequest401JSONResponse{Code: "unauthorized", Message: "user not found"}, nil
		}
		h.Logger.Error("auth.email.verify.request", "err", err)
		return nil, err
	}
	return bffgen.PostV1AuthEmailVerifyRequest204Response{}, nil
}

func (h *Handler) PostV1AuthEmailVerifyConfirm(ctx context.Context, req bffgen.PostV1AuthEmailVerifyConfirmRequestObject) (bffgen.PostV1AuthEmailVerifyConfirmResponseObject, error) {
	claims, ok := ClaimsFromContext(ctx)
	if !ok {
		return bffgen.PostV1AuthEmailVerifyConfirm401JSONResponse{Code: "unauthorized", Message: "missing claims"}, nil
	}
	if req.Body == nil {
		return bffgen.PostV1AuthEmailVerifyConfirm401JSONResponse{Code: "otp_invalid", Message: "missing code"}, nil
	}
	if err := h.Auth.VerifyEmail(ctx, claims.Sub, req.Body.Code); err != nil {
		switch {
		case errors.Is(err, userauth.ErrInvalidCode),
			errors.Is(err, userauth.ErrChallengeMissing),
			errors.Is(err, userauth.ErrChallengeExpired),
			errors.Is(err, userauth.ErrChallengeUsed),
			errors.Is(err, userauth.ErrTooManyAttempts):
			return bffgen.PostV1AuthEmailVerifyConfirm401JSONResponse{Code: "otp_invalid", Message: "invalid or expired otp"}, nil
		case errors.Is(err, userauth.ErrUserNotFound):
			return bffgen.PostV1AuthEmailVerifyConfirm401JSONResponse{Code: "unauthorized", Message: "user not found"}, nil
		}
		h.Logger.Error("auth.email.verify.confirm", "err", err)
		return nil, err
	}
	return bffgen.PostV1AuthEmailVerifyConfirm204Response{}, nil
}

func (h *Handler) PostV1AuthForgotPasswordRequest(ctx context.Context, req bffgen.PostV1AuthForgotPasswordRequestRequestObject) (bffgen.PostV1AuthForgotPasswordRequestResponseObject, error) {
	if req.Body != nil {
		if err := h.Auth.ForgotPasswordRequest(ctx, string(req.Body.Email)); err != nil {
			h.Logger.Error("auth.forgot.request", "err", err)
			// Still 204: never leak whether the email was registered.
		}
	}
	return bffgen.PostV1AuthForgotPasswordRequest204Response{}, nil
}

func (h *Handler) PostV1AuthForgotPasswordReset(ctx context.Context, req bffgen.PostV1AuthForgotPasswordResetRequestObject) (bffgen.PostV1AuthForgotPasswordResetResponseObject, error) {
	if req.Body == nil {
		return bffgen.PostV1AuthForgotPasswordReset401JSONResponse{Code: "invalid_credentials", Message: "missing body"}, nil
	}
	err := h.Auth.ForgotPasswordReset(ctx, string(req.Body.Email), req.Body.Code, req.Body.NewPassword)
	if err != nil {
		switch {
		case errors.Is(err, userauth.ErrInvalidCode),
			errors.Is(err, userauth.ErrChallengeMissing),
			errors.Is(err, userauth.ErrChallengeExpired),
			errors.Is(err, userauth.ErrChallengeUsed),
			errors.Is(err, userauth.ErrTooManyAttempts),
			errors.Is(err, userauth.ErrInvalidCredentials):
			return bffgen.PostV1AuthForgotPasswordReset401JSONResponse{Code: "otp_invalid", Message: "invalid or expired otp"}, nil
		case errors.Is(err, userauth.ErrInvalidPassword):
			return bffgen.PostV1AuthForgotPasswordReset400JSONResponse{Code: "invalid_password", Message: err.Error()}, nil
		}
		h.Logger.Error("auth.forgot.reset", "err", err)
		return nil, err
	}
	return bffgen.PostV1AuthForgotPasswordReset204Response{}, nil
}

func (h *Handler) PostV1AuthRefresh(ctx context.Context, req bffgen.PostV1AuthRefreshRequestObject) (bffgen.PostV1AuthRefreshResponseObject, error) {
	if req.Body == nil {
		return bffgen.PostV1AuthRefresh401JSONResponse{Code: "unauthorized", Message: "missing body"}, nil
	}
	res, err := h.Auth.Refresh(ctx, req.Body.RefreshToken)
	if err != nil {
		if errors.Is(err, userauth.ErrInvalidRefresh) {
			return bffgen.PostV1AuthRefresh401JSONResponse{Code: "invalid_refresh", Message: "refresh token invalid or revoked"}, nil
		}
		h.Logger.Error("auth.refresh", "err", err)
		return nil, err
	}
	return bffgen.PostV1AuthRefresh200JSONResponse(authResultToDTO(res)), nil
}

func (h *Handler) PostV1AuthLogout(ctx context.Context, req bffgen.PostV1AuthLogoutRequestObject) (bffgen.PostV1AuthLogoutResponseObject, error) {
	if req.Body != nil && req.Body.RefreshToken != "" {
		_ = h.Auth.Logout(ctx, req.Body.RefreshToken)
	}
	return bffgen.PostV1AuthLogout204Response{}, nil
}

func (h *Handler) GetV1Me(ctx context.Context, _ bffgen.GetV1MeRequestObject) (bffgen.GetV1MeResponseObject, error) {
	claims, ok := ClaimsFromContext(ctx)
	if !ok {
		return bffgen.GetV1Me401JSONResponse{Code: "unauthorized", Message: "missing claims"}, nil
	}
	me, err := h.Auth.GetMe(ctx, claims.Sub)
	if err != nil {
		if errors.Is(err, userauth.ErrUserNotFound) {
			return bffgen.GetV1Me401JSONResponse{Code: "unauthorized", Message: "user not found"}, nil
		}
		h.Logger.Error("me.query", "err", err)
		return nil, err
	}
	resp := bffgen.GetV1Me200JSONResponse{
		UserId:        me.ID,
		Phone:         me.Phone,
		AccountNumber: me.AccountNumber,
		KycTier:       me.KYCTier,
		FirstName:     me.FirstName,
		LastName:      me.LastName,
		Email:         me.Email,
		EmailVerified: me.EmailVerified,
	}
	if h.Identity != nil {
		if card, err := h.Identity.IssueDisplayCard(ctx, me.ID); err != nil {
			// Non-fatal: profile still returns, client can refresh via
			// GET /v1/identity/display-card.
			h.Logger.Warn("identity.display_card_me", "user_id", me.ID, "err", err)
		} else {
			c := displayCardToInput(server.DisplayCardToProto(card))
			resp.DisplayCard = &c
		}
	}
	return resp, nil
}

func kycSubmissionToDTO(s kyc.Submission) bffgen.KYCSubmission {
	return bffgen.KYCSubmission{
		Id:              s.ID,
		UserId:          s.UserID,
		IdType:          s.IDType,
		IdNumber:        s.IDNumber,
		Status:          bffgen.KYCSubmissionStatus(s.Status),
		RejectionReason: s.RejectionReason,
		TierGranted:     s.TierGranted,
		SubmittedBy:     s.SubmittedBy,
		SubmittedAt:     s.SubmittedAt,
		VerifiedAt:      s.VerifiedAt,
	}
}

func (h *Handler) PostV1KycSubmit(ctx context.Context, req bffgen.PostV1KycSubmitRequestObject) (bffgen.PostV1KycSubmitResponseObject, error) {
	claims, ok := ClaimsFromContext(ctx)
	if !ok {
		return bffgen.PostV1KycSubmit401JSONResponse{Code: "unauthorized", Message: "missing claims"}, nil
	}
	if req.Body == nil {
		return bffgen.PostV1KycSubmit400JSONResponse{Code: "bad_request", Message: "missing body"}, nil
	}
	sub, err := h.KYC.Submit(ctx, claims.Sub, string(req.Body.IdType), req.Body.IdNumber)
	if err != nil {
		switch {
		case errors.Is(err, kyc.ErrInvalidInput):
			return bffgen.PostV1KycSubmit400JSONResponse{Code: "invalid_request", Message: err.Error()}, nil
		case errors.Is(err, kyc.ErrUserNotFound):
			return bffgen.PostV1KycSubmit401JSONResponse{Code: "unauthorized", Message: "user not found"}, nil
		}
		h.Logger.Error("kyc.submit", "err", err)
		return nil, err
	}
	return bffgen.PostV1KycSubmit200JSONResponse(kycSubmissionToDTO(sub)), nil
}

func (h *Handler) GetV1KycSubmissions(ctx context.Context, _ bffgen.GetV1KycSubmissionsRequestObject) (bffgen.GetV1KycSubmissionsResponseObject, error) {
	claims, ok := ClaimsFromContext(ctx)
	if !ok {
		return bffgen.GetV1KycSubmissions401JSONResponse{Code: "unauthorized", Message: "missing claims"}, nil
	}
	subs, err := h.KYC.List(ctx, claims.Sub)
	if err != nil {
		h.Logger.Error("kyc.list", "err", err)
		return nil, err
	}
	items := make([]bffgen.KYCSubmission, 0, len(subs))
	for _, s := range subs {
		items = append(items, kycSubmissionToDTO(s))
	}
	return bffgen.GetV1KycSubmissions200JSONResponse{Items: items}, nil
}

func (h *Handler) GetV1KycHint(ctx context.Context, _ bffgen.GetV1KycHintRequestObject) (bffgen.GetV1KycHintResponseObject, error) {
	claims, ok := ClaimsFromContext(ctx)
	if !ok {
		return bffgen.GetV1KycHint401JSONResponse{Code: "unauthorized", Message: "missing claims"}, nil
	}
	hint, err := h.KYC.Hint(ctx, claims.Sub)
	if err != nil {
		if errors.Is(err, kyc.ErrUserNotFound) {
			return bffgen.GetV1KycHint401JSONResponse{Code: "unauthorized", Message: "user not found"}, nil
		}
		h.Logger.Error("kyc.hint", "err", err)
		return nil, err
	}
	return bffgen.GetV1KycHint200JSONResponse(hint), nil
}

func authResultToDTO(res userauth.AuthResult) bffgen.AuthTokens {
	return bffgen.AuthTokens{
		UserId:           res.UserID,
		AccountNumber:    res.AccountNumber,
		AccessToken:      res.AccessToken,
		RefreshToken:     res.RefreshToken,
		AccessExpiresAt:  res.AccessExpiresAt,
		RefreshExpiresAt: res.RefreshExpiresAt,
	}
}

func (h *Handler) GetV1AccountsResolveAccountNumber(ctx context.Context, req bffgen.GetV1AccountsResolveAccountNumberRequestObject) (bffgen.GetV1AccountsResolveAccountNumberResponseObject, error) {
	if err := domain.ValidateAccountNumber(req.AccountNumber); err != nil {
		return bffgen.GetV1AccountsResolveAccountNumber400JSONResponse{Code: "invalid_account_number", Message: err.Error()}, nil
	}
	res, err := h.Accounts.ResolveAccount(ctx, req.AccountNumber)
	if err != nil {
		if errors.Is(err, account.ErrNotFound) {
			return bffgen.GetV1AccountsResolveAccountNumber404JSONResponse{Code: "account_not_found", Message: "account not found"}, nil
		}
		if errors.Is(err, domain.ErrInvalidAccountNumber) {
			return bffgen.GetV1AccountsResolveAccountNumber400JSONResponse{Code: "invalid_account_number", Message: err.Error()}, nil
		}
		h.Logger.Error("accounts.resolve", "err", err)
		return nil, err
	}
	return bffgen.GetV1AccountsResolveAccountNumber200JSONResponse{
		AccountNumber: res.AccountNumber,
		MaskedName:    res.MaskedName,
	}, nil
}

func transferToDTO(t *domain.Transfer) bffgen.Transfer {
	return bffgen.Transfer{
		Id:                    t.ID,
		SenderUserId:          t.SenderUserID,
		ReceiverUserId:        t.ReceiverUserID,
		SenderDisplayName:     t.SenderDisplayName,
		ReceiverDisplayName:   t.ReceiverDisplayName,
		ReceiverAccountNumber: t.ReceiverAccountNumber,
		AmountKobo:            t.AmountKobo,
		Status:                bffgen.TransferStatus(t.Status),
		Reference:             t.Reference,
		FailureReason:         t.FailureReason,
		CreatedAt:             t.CreatedAt,
		SettledAt:             t.SettledAt,
	}
}

func (h *Handler) PostV1Transfers(ctx context.Context, req bffgen.PostV1TransfersRequestObject) (bffgen.PostV1TransfersResponseObject, error) {
	claims, ok := ClaimsFromContext(ctx)
	if !ok {
		return bffgen.PostV1Transfers401JSONResponse{Code: "unauthorized", Message: "missing claims"}, nil
	}
	if req.Body == nil {
		return bffgen.PostV1Transfers400JSONResponse{Code: "bad_request", Message: "missing body"}, nil
	}
	// Transaction-PIN gate — required even though the JWT is already valid.
	// This defends against session theft: a stolen access token alone can't
	// move money.
	if err := h.Auth.VerifyPIN(ctx, claims.Sub, req.Body.Pin); err != nil {
		switch {
		case errors.Is(err, userauth.ErrPINNotSet):
			return bffgen.PostV1Transfers409JSONResponse{Code: "pin_not_set", Message: "set a transaction pin before transferring"}, nil
		case errors.Is(err, userauth.ErrPINLocked):
			return bffgen.PostV1Transfers423JSONResponse{Code: "pin_locked", Message: "pin locked — try again later"}, nil
		case errors.Is(err, userauth.ErrBadPIN):
			return bffgen.PostV1Transfers401JSONResponse{Code: "pin_bad", Message: "incorrect pin"}, nil
		case errors.Is(err, userauth.ErrInvalidPIN):
			return bffgen.PostV1Transfers400JSONResponse{Code: "invalid_pin", Message: "pin must be 4 or 6 digits"}, nil
		case errors.Is(err, userauth.ErrUserNotFound):
			return bffgen.PostV1Transfers401JSONResponse{Code: "unauthorized", Message: "user not found"}, nil
		}
		h.Logger.Error("transfers.pin.verify", "err", err)
		return nil, err
	}
	t, err := h.Transfers.InitiateTransfer(ctx, transfer.InitiateTransferInput{
		SenderUserID:          claims.Sub,
		ReceiverAccountNumber: req.Body.ReceiverAccountNumber,
		AmountKobo:            req.Body.AmountKobo,
		Reference:             req.Body.Reference,
	})
	if err != nil {
		switch {
		case errors.Is(err, transfer.ErrSelfTransfer):
			return bffgen.PostV1Transfers409JSONResponse{Code: "self_transfer", Message: err.Error()}, nil
		case errors.Is(err, transfer.ErrReceiverNotFound):
			return bffgen.PostV1Transfers404JSONResponse{Code: "receiver_not_found", Message: err.Error()}, nil
		case errors.Is(err, transfer.ErrTierBlocked):
			return bffgen.PostV1Transfers402JSONResponse{Code: "kyc_tier_blocked", Message: "Complete KYC to send money"}, nil
		case errors.Is(err, transfer.ErrExceedsSingleLimit):
			return bffgen.PostV1Transfers402JSONResponse{Code: "exceeds_single_limit", Message: err.Error()}, nil
		case errors.Is(err, transfer.ErrExceedsDailyLimit):
			return bffgen.PostV1Transfers402JSONResponse{Code: "exceeds_daily_limit", Message: err.Error()}, nil
		case errors.Is(err, transfer.ErrFraudBlocked):
			return bffgen.PostV1Transfers403JSONResponse{
				Code:    "fraud_block",
				Message: "This transfer was blocked for review. Please try again later or contact support.",
			}, nil
		case errors.Is(err, domain.ErrInvalidAmount),
			errors.Is(err, domain.ErrInvalidReference),
			errors.Is(err, domain.ErrInvalidAccountNumber):
			return bffgen.PostV1Transfers400JSONResponse{Code: "invalid_request", Message: err.Error()}, nil
		}
		h.Logger.Error("transfers.initiate", "err", err)
		return nil, err
	}
	return bffgen.PostV1Transfers200JSONResponse(transferToDTO(t)), nil
}

func (h *Handler) GetV1TransfersID(ctx context.Context, req bffgen.GetV1TransfersIDRequestObject) (bffgen.GetV1TransfersIDResponseObject, error) {
	claims, ok := ClaimsFromContext(ctx)
	if !ok {
		return bffgen.GetV1TransfersID401JSONResponse{Code: "unauthorized", Message: "missing claims"}, nil
	}
	t, err := h.Transfers.GetTransfer(ctx, req.Id)
	if err != nil {
		h.Logger.Error("transfers.get", "err", err)
		return nil, err
	}
	if t == nil || (t.SenderUserID != claims.Sub && t.ReceiverUserID != claims.Sub) {
		return bffgen.GetV1TransfersID404JSONResponse{Code: "transfer_not_found", Message: "transfer not found"}, nil
	}
	return bffgen.GetV1TransfersID200JSONResponse(transferToDTO(t)), nil
}

func (h *Handler) GetV1Transfers(ctx context.Context, req bffgen.GetV1TransfersRequestObject) (bffgen.GetV1TransfersResponseObject, error) {
	claims, ok := ClaimsFromContext(ctx)
	if !ok {
		return bffgen.GetV1Transfers401JSONResponse{Code: "unauthorized", Message: "missing claims"}, nil
	}
	limit := 20
	offset := 0
	if req.Params.Limit != nil {
		limit = *req.Params.Limit
	}
	if req.Params.Offset != nil {
		offset = *req.Params.Offset
	}
	if limit <= 0 {
		limit = 20
	}
	if limit > 100 {
		limit = 100
	}
	if offset < 0 {
		offset = 0
	}
	rows, err := h.Transfers.ListTransfers(ctx, claims.Sub, limit, offset)
	if err != nil {
		h.Logger.Error("transfers.list", "err", err)
		return nil, err
	}
	items := make([]bffgen.Transfer, 0, len(rows))
	for i := range rows {
		items = append(items, transferToDTO(&rows[i]))
	}
	return bffgen.GetV1Transfers200JSONResponse{
		Items:  items,
		Limit:  limit,
		Offset: offset,
	}, nil
}

func writeJSONErr(w http.ResponseWriter, status int, code, msg string) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(map[string]string{"code": code, "message": msg})
}
