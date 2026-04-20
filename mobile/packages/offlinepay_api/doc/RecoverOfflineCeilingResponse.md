# offlinepay_api.model.RecoverOfflineCeilingResponse

## Load the model package
```dart
import 'package:offlinepay_api/api.dart';
```

## Properties
Name | Type | Description | Notes
------------ | ------------- | ------------- | -------------
**ceilingId** | **String** |  | 
**quarantinedKobo** | **int** | Amount held in quarantine. Funds are released to the main wallet by the expiry sweep once `release_after` passes. Late-arriving offline claims against this ceiling will settle first and reduce the released amount accordingly.  | 
**releaseAfter** | [**DateTime**](DateTime.md) | Wall-clock time after which the expiry sweep returns the remaining lien balance to the main wallet. Equals the ceiling's original expiry plus the auto-settle timeout plus a 30-minute grace.  | 

[[Back to Model list]](../README.md#documentation-for-models) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to README]](../README.md)


