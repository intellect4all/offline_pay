# offlinepay_api.model.CurrentCeilingResponse

## Load the model package
```dart
import 'package:offlinepay_api/api.dart';
```

## Properties
Name | Type | Description | Notes
------------ | ------------- | ------------- | -------------
**present** | **bool** | False when the payer has no offline wallet (no ACTIVE or RECOVERY_PENDING ceiling). All other fields are omitted or zero in that case.  | 
**ceilingId** | **String** |  | [optional] 
**status** | **String** | ACTIVE or RECOVERY_PENDING. | [optional] 
**ceilingKobo** | **int** |  | [optional] 
**settledKobo** | **int** | Total settled across every payment token issued against this ceiling. `ceiling_kobo - settled_kobo = remaining_kobo`.  | [optional] 
**remainingKobo** | **int** | The amount the lien would return to main if the ceiling released right now. Used for the offline-wallet card and to cross-check against the lien account balance.  | [optional] 
**issuedAt** | [**DateTime**](DateTime.md) |  | [optional] 
**expiresAt** | [**DateTime**](DateTime.md) |  | [optional] 
**releaseAfter** | [**DateTime**](DateTime.md) | Populated only when status is RECOVERY_PENDING. After this instant the expiry sweep releases the remaining lien back to main.  | [optional] 

[[Back to Model list]](../README.md#documentation-for-models) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to README]](../README.md)


