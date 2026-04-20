# offlinepay_api.model.AuthTokens

## Load the model package
```dart
import 'package:offlinepay_api/api.dart';
```

## Properties
Name | Type | Description | Notes
------------ | ------------- | ------------- | -------------
**userId** | **String** |  | 
**accountNumber** | **String** |  | 
**accessToken** | **String** |  | 
**refreshToken** | **String** |  | 
**accessExpiresAt** | [**DateTime**](DateTime.md) |  | 
**refreshExpiresAt** | [**DateTime**](DateTime.md) |  | 
**displayCard** | [**DisplayCardInput**](DisplayCardInput.md) | Server-issued identity credential. Clients cache this for use in every PaymentRequest they publish. Optional on login responses (clients should fall back to GET /v1/identity/display-card); always populated on signup.  | [optional] 

[[Back to Model list]](../README.md#documentation-for-models) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to README]](../README.md)


