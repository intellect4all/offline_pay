# offlinepay_api.model.DeviceSessionResponse

## Load the model package
```dart
import 'package:offlinepay_api/api.dart';
```

## Properties
Name | Type | Description | Notes
------------ | ------------- | ------------- | -------------
**token** | **String** | Compact base64url-encoded `header.claims.signature` blob signed with Ed25519. The device verifies it locally against `server_public_key`.  | 
**serverPublicKey** | **String** | 32-byte Ed25519 public key the device should cache. | 
**keyId** | **String** | Identifier of the signing key (for rotation). | 
**issuedAt** | [**DateTime**](DateTime.md) |  | 
**expiresAt** | [**DateTime**](DateTime.md) |  | 
**scope** | **String** |  | 

[[Back to Model list]](../README.md#documentation-for-models) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to README]](../README.md)


