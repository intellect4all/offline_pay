# offlinepay Protobuf Contracts

All gRPC service and message definitions for the offlinepay backend live
under `offlinepay/v1/`. The package is `offlinepay.v1`; all files share the
same `go_package` so generated Go lands in a single import path.

## Regenerating stubs

```
cd backend
make proto     # runs `buf generate`
```

Generated Go sources are written to
`backend/internal/transport/grpc/gen/offlinepay/v1/` (configured in
`buf.gen.yaml`).

## Lint

```
cd backend
buf lint
```

## Service ownership map

| Proto file | Service | Owning backend package |
| --- | --- | --- |
| `wallet.proto` | `WalletService` | `internal/service/wallet` |
| `settlement.proto` | `SettlementService` | `internal/service/settlement` |
| `keys.proto` | `KeysService` | `internal/service/keys` (TBD) |
| `registration.proto` | `RegistrationService` | `internal/service/registration` (TBD) |
| `common.proto` | _shared messages / enums_ | — |

Every service consumes `common.proto`; shared enums (`TransactionStatus`,
`CeilingStatus`, `AccountKind`, `SettlementBatchStatus`) and wire forms
(`CeilingToken`, `PaymentToken`, `GossipBlob`, `BatchReceipt`,
`AccountBalance`, `SettlementResult`) are defined there and mirror
`backend/internal/domain/` field-for-field.

## Conventions

- proto3; package `offlinepay.v1`.
- All monetary amounts are `int64` kobo. Never `double`/`float`.
- All timestamps are `google.protobuf.Timestamp`.
- All crypto material (public keys, signatures, ciphertexts, nonces) is
  `bytes`.
- Enum zero values are `*_UNSPECIFIED`.
- Field numbers are frozen at introduction. Removed fields must be
  `reserved`; new fields must claim unused numbers.
- All RPCs are user-scoped. There is no "merchant" surface — the C2C model
  means the same user can act as sender (`FundOffline`, `RefreshCeiling`)
  and receiver (`SubmitClaim`, `GossipUpload`) through the same service.
