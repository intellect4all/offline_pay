# offlinepay_api.model.PaymentRequestInput

## Load the model package
```dart
import 'package:offlinepay_api/api.dart';
```

## Properties
Name | Type | Description | Notes
------------ | ------------- | ------------- | -------------
**receiverId** | **String** |  | 
**receiverDisplayCard** | [**DisplayCardInput**](DisplayCardInput.md) |  | 
**amountKobo** | **int** | 0 means \"unbound\" — the payer picks the amount. | 
**sessionNonce** | **String** | 16 random bytes; single-use per receiver. | 
**issuedAt** | [**DateTime**](DateTime.md) |  | 
**expiresAt** | [**DateTime**](DateTime.md) |  | 
**receiverDevicePubkey** | **String** |  | 
**receiverSignature** | **String** |  | 

[[Back to Model list]](../README.md#documentation-for-models) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to README]](../README.md)


