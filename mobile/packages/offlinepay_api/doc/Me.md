# offlinepay_api.model.Me

## Load the model package
```dart
import 'package:offlinepay_api/api.dart';
```

## Properties
Name | Type | Description | Notes
------------ | ------------- | ------------- | -------------
**userId** | **String** |  | 
**phone** | **String** |  | 
**accountNumber** | **String** |  | 
**kycTier** | **String** |  | 
**firstName** | **String** |  | 
**lastName** | **String** |  | 
**email** | **String** |  | 
**emailVerified** | **bool** |  | 
**displayCard** | [**DisplayCardInput**](DisplayCardInput.md) | Freshly-issued DisplayCard for the caller. Optional so a transient bank-key or signing failure doesn't break /me — clients fall back to GET /v1/identity/display-card.  | [optional] 

[[Back to Model list]](../README.md#documentation-for-models) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to README]](../README.md)


