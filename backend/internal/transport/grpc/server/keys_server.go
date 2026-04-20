package server

import (
	"context"

	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"

	"github.com/intellect/offlinepay/internal/domain"
	"github.com/intellect/offlinepay/internal/repository/pgrepo"
	pb "github.com/intellect/offlinepay/internal/transport/grpc/gen/offlinepay/v1"
)

// KeysServer implements pb.KeysServiceServer. Bank public keys and the
// active realm key come from the repository; the server sealed-box pubkey
// is injected at construction time (lives in-process; private half never
// leaves the server).
type KeysServer struct {
	pb.UnimplementedKeysServiceServer

	Repo                *pgrepo.Repo
	SealedBoxPublicKey  []byte
	SealedBoxKeyID      string
}

// NewKeysServer constructs a KeysServer.
func NewKeysServer(repo *pgrepo.Repo, sealedPub []byte, keyID string) *KeysServer {
	return &KeysServer{Repo: repo, SealedBoxPublicKey: sealedPub, SealedBoxKeyID: keyID}
}

// GetBankPublicKeys returns the active bank signing key. The repo exposes
// only the active key; overlap-window rotation is out of scope for MVP but
// the service will still accept specific key_ids if provided.
func (s *KeysServer) GetBankPublicKeys(ctx context.Context, req *pb.GetBankPublicKeysRequest) (*pb.GetBankPublicKeysResponse, error) {
	out := &pb.GetBankPublicKeysResponse{}
	if ids := req.GetKeyIds(); len(ids) > 0 {
		for _, id := range ids {
			k, err := s.Repo.GetBankSigningKey(ctx, id)
			if err != nil {
				continue
			}
			out.Keys = append(out.Keys, &pb.BankPublicKey{
				KeyId:      k.KeyID,
				PublicKey:  k.PublicKey,
				ActiveFrom: tsOrNil(k.ActiveFrom),
				RetiredAt:  tsPtrOrNil(k.ActiveTo),
			})
		}
		return out, nil
	}
	active, err := s.Repo.GetActiveBankSigningKey(ctx)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "active bank key: %v", err)
	}
	out.Keys = append(out.Keys, &pb.BankPublicKey{
		KeyId:      active.KeyID,
		PublicKey:  active.PublicKey,
		ActiveFrom: tsOrNil(active.ActiveFrom),
		RetiredAt:  tsPtrOrNil(active.ActiveTo),
	})
	return out, nil
}

// GetRealmKey returns the realm key for the requested version. Version=0
// means "current active". Clients use this for lazy backfill when they
// encounter a key_version byte outside their cached keyring.
func (s *KeysServer) GetRealmKey(ctx context.Context, req *pb.GetRealmKeyRequest) (*pb.GetRealmKeyResponse, error) {
	if req.GetDeviceId() == "" {
		return nil, status.Error(codes.InvalidArgument, "device_id required")
	}
	var (
		rk  domain.RealmKey
		err error
	)
	if v := req.GetVersion(); v > 0 {
		rk, err = s.Repo.GetRealmKey(ctx, int(v))
	} else {
		rk, err = s.Repo.GetActiveRealmKey(ctx)
	}
	if err != nil {
		return nil, status.Errorf(codes.Internal, "realm key: %v", err)
	}
	return &pb.GetRealmKeyResponse{
		Version:    int32(rk.Version),
		Key:        rk.Key,
		ActiveFrom: tsOrNil(rk.ActiveFrom),
		ExpiresAt:  tsOrNil(rk.ExpiresAt),
	}, nil
}

// GetActiveRealmKeys returns every realm-key version still inside its
// overlap window, newest-first. Clients populate a Keyring from this so
// they can decrypt a backlog of QRs sealed under recently-retired versions.
func (s *KeysServer) GetActiveRealmKeys(ctx context.Context, req *pb.GetActiveRealmKeysRequest) (*pb.GetActiveRealmKeysResponse, error) {
	if req.GetDeviceId() == "" {
		return nil, status.Error(codes.InvalidArgument, "device_id required")
	}
	limit := int(req.GetLimit())
	if limit <= 0 {
		limit = 3
	}
	keys, err := s.Repo.ListActiveRealmKeys(ctx, limit)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "list realm keys: %v", err)
	}
	out := &pb.GetActiveRealmKeysResponse{Keys: make([]*pb.RealmKey, 0, len(keys))}
	for _, k := range keys {
		out.Keys = append(out.Keys, &pb.RealmKey{
			Version:    int32(k.Version),
			Key:        k.Key,
			ActiveFrom: tsOrNil(k.ActiveFrom),
			RetiredAt:  tsOrNil(k.ExpiresAt),
		})
	}
	return out, nil
}

// GetServerSealedBoxPubkey returns the server's X25519 public key.
func (s *KeysServer) GetServerSealedBoxPubkey(ctx context.Context, req *pb.GetServerSealedBoxPubkeyRequest) (*pb.GetServerSealedBoxPubkeyResponse, error) {
	if len(s.SealedBoxPublicKey) == 0 {
		return nil, status.Error(codes.FailedPrecondition, "sealed-box key not provisioned")
	}
	return &pb.GetServerSealedBoxPubkeyResponse{
		PublicKey: s.SealedBoxPublicKey,
		KeyId:     s.SealedBoxKeyID,
	}, nil
}
