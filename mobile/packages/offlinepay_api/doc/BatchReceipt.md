# offlinepay_api.model.BatchReceipt

## Load the model package
```dart
import 'package:offlinepay_api/api.dart';
```

## Properties
Name | Type | Description | Notes
------------ | ------------- | ------------- | -------------
**batchId** | **String** |  | 
**receiverUserId** | **String** |  | 
**totalSubmitted** | **int** |  | 
**totalSettled** | **int** |  | 
**totalPartial** | **int** |  | 
**totalRejected** | **int** |  | 
**totalAmountKobo** | **int** |  | 
**status** | **String** |  | 
**submittedAt** | [**DateTime**](DateTime.md) |  | 
**processedAt** | [**DateTime**](DateTime.md) |  | [optional] 
**results** | [**BuiltList&lt;SettlementResult&gt;**](SettlementResult.md) |  | 

[[Back to Model list]](../README.md#documentation-for-models) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to README]](../README.md)


