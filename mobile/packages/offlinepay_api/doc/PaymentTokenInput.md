# offlinepay_api.model.PaymentTokenInput

## Load the model package
```dart
import 'package:offlinepay_api/api.dart';
```

## Properties
Name | Type | Description | Notes
------------ | ------------- | ------------- | -------------
**payerId** | **String** |  | 
**payeeId** | **String** |  | 
**amountKobo** | **int** |  | 
**sequenceNumber** | **int** |  | 
**remainingCeilingKobo** | **int** |  | 
**timestamp** | [**DateTime**](DateTime.md) |  | 
**ceilingTokenId** | **String** |  | 
**payerSignature** | **String** |  | 
**sessionNonce** | **String** | 16-byte nonce from the PaymentRequest; single-use per receiver. | 
**requestHash** | **String** | sha256(canonical(PaymentRequest)) — server recomputes to detect tampering. | 

[[Back to Model list]](../README.md#documentation-for-models) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to README]](../README.md)


