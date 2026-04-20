package server

import (
	"context"
	"errors"

	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
	"google.golang.org/protobuf/types/known/timestamppb"

	"github.com/intellect/offlinepay/internal/domain"
	"github.com/intellect/offlinepay/internal/service/gossip"
	"github.com/intellect/offlinepay/internal/service/reconciliation"
	"github.com/intellect/offlinepay/internal/service/settlement"
	pb "github.com/intellect/offlinepay/internal/transport/grpc/gen/offlinepay/v1"
)

// SettlementServer implements pb.SettlementServiceServer.
type SettlementServer struct {
	pb.UnimplementedSettlementServiceServer

	Settlement     *settlement.Service
	Reconciliation *reconciliation.Service
	Gossip         *gossip.Service
}

// NewSettlementServer constructs a SettlementServer.
func NewSettlementServer(ss *settlement.Service, rc *reconciliation.Service, gs *gossip.Service) *SettlementServer {
	return &SettlementServer{Settlement: ss, Reconciliation: rc, Gossip: gs}
}

// SubmitClaim is Phase 4a.
func (s *SettlementServer) SubmitClaim(ctx context.Context, req *pb.SubmitClaimRequest) (*pb.SubmitClaimResponse, error) {
	if req.GetReceiverUserId() == "" {
		return nil, status.Error(codes.InvalidArgument, "receiver_user_id required")
	}
	if _, err := MustMatchUser(ctx, req.GetReceiverUserId()); err != nil {
		return nil, err
	}
	items := ClaimItemsFromProto(req.GetTokens(), req.GetCeilings(), req.GetRequests())
	var opts []settlement.SubmitOption
	if country := SubmitterCountryFromContext(ctx); country != "" {
		opts = append(opts, settlement.WithSubmitterCountry(country))
	}
	batch, results, err := s.Settlement.SubmitClaim(ctx, req.GetReceiverUserId(), items, opts...)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "submit claim: %v", err)
	}
	return &pb.SubmitClaimResponse{Receipt: BatchReceiptToProto(batch, results)}, nil
}

// GetBatchReceipt re-fetches a batch receipt.
func (s *SettlementServer) GetBatchReceipt(ctx context.Context, req *pb.GetBatchReceiptRequest) (*pb.GetBatchReceiptResponse, error) {
	if req.GetBatchId() == "" {
		return nil, status.Error(codes.InvalidArgument, "batch_id required")
	}
	batch, results, err := s.Reconciliation.BatchReceipt(ctx, req.GetBatchId())
	if err != nil {
		if errors.Is(err, reconciliation.ErrNoSuchBatch) {
			return nil, status.Error(codes.NotFound, err.Error())
		}
		return nil, status.Errorf(codes.Internal, "batch receipt: %v", err)
	}
	return &pb.GetBatchReceiptResponse{Receipt: BatchReceiptToProto(batch, results)}, nil
}

// SyncUser returns both payer-side and receiver-side settled transactions.
//
// `finalize=true` no longer runs Phase 4b inline — it enqueues a
// settlement-finalize event for the caller and sets `finalize_pending` in
// the response so the client can show an "in progress" hint. The worker
// processes the event (typically <1s later) and fires an
// `offline_payment_settled` push when the ledger moves land.
func (s *SettlementServer) SyncUser(ctx context.Context, req *pb.SyncUserRequest) (*pb.SyncUserResponse, error) {
	if req.GetUserId() == "" {
		return nil, status.Error(codes.InvalidArgument, "user_id required")
	}
	if _, err := MustMatchUser(ctx, req.GetUserId()); err != nil {
		return nil, err
	}
	var finalizePending bool
	if req.GetFinalize() && s.Settlement != nil {
		if err := s.Settlement.EnqueueFinalize(ctx, req.GetUserId(), domain.FinalizeReasonSyncRequested); err != nil {
			return nil, status.Errorf(codes.Internal, "enqueue finalize: %v", err)
		}
		finalizePending = true
	}
	res, err := s.Reconciliation.SyncUser(ctx, req.GetUserId(), nil, req.GetDisputedTransactionIds())
	if err != nil {
		return nil, status.Errorf(codes.Internal, "sync user: %v", err)
	}
	out := &pb.SyncUserResponse{
		PayerSide:       make([]*pb.SyncedTransaction, 0, len(res.PayerSide)),
		ReceiverSide:    make([]*pb.SyncedTransaction, 0, len(res.ReceiverSide)),
		SyncedAt:        timestamppb.Now(),
		FinalizedCount:  0, // Informational: fresh work runs asynchronously now.
		FinalizePending: finalizePending,
	}
	for _, t := range res.PayerSide {
		out.PayerSide = append(out.PayerSide, TxnToSyncedProto(t))
	}
	for _, t := range res.ReceiverSide {
		out.ReceiverSide = append(out.ReceiverSide, TxnToSyncedProto(t))
	}
	return out, nil
}

// GossipUpload accepts encrypted gossip blobs and routes them to settlement.
func (s *SettlementServer) GossipUpload(ctx context.Context, req *pb.GossipUploadRequest) (*pb.GossipUploadResponse, error) {
	if s.Gossip == nil {
		return nil, status.Error(codes.Unimplemented, "gossip service not configured")
	}
	if req.GetUploaderUserId() == "" {
		return nil, status.Error(codes.InvalidArgument, "uploader_user_id required")
	}
	if _, err := MustMatchUser(ctx, req.GetUploaderUserId()); err != nil {
		return nil, err
	}
	blobs := make([]domain.GossipBlob, 0, len(req.GetBlobs()))
	for _, b := range req.GetBlobs() {
		blobs = append(blobs, GossipBlobFromProto(b))
	}
	res, err := s.Gossip.Upload(ctx, req.GetUploaderUserId(), blobs)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "gossip upload: %v", err)
	}
	return &pb.GossipUploadResponse{
		Accepted:   int32(res.Accepted),
		Duplicates: 0, // Gossip service doesn't currently distinguish duplicates from fresh accepts.
		Invalid:    int32(res.Rejected),
	}, nil
}
