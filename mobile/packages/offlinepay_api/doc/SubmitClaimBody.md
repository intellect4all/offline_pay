# offlinepay_api.model.SubmitClaimBody

## Load the model package
```dart
import 'package:offlinepay_api/api.dart';
```

## Properties
Name | Type | Description | Notes
------------ | ------------- | ------------- | -------------
**clientBatchId** | **String** |  | 
**tokens** | [**BuiltList&lt;PaymentTokenInput&gt;**](PaymentTokenInput.md) |  | 
**ceilings** | [**BuiltList&lt;CeilingTokenInput&gt;**](CeilingTokenInput.md) |  | 
**requests** | [**BuiltList&lt;PaymentRequestInput&gt;**](PaymentRequestInput.md) | Receiver-signed PaymentRequests each token counter-signs. Match by session_nonce — every token must have exactly one request.  | 

[[Back to Model list]](../README.md#documentation-for-models) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to README]](../README.md)


