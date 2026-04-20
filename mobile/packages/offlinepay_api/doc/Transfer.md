# offlinepay_api.model.Transfer

## Load the model package
```dart
import 'package:offlinepay_api/api.dart';
```

## Properties
Name | Type | Description | Notes
------------ | ------------- | ------------- | -------------
**id** | **String** |  | 
**senderUserId** | **String** |  | 
**receiverUserId** | **String** |  | 
**senderDisplayName** | **String** | Best-effort \"First Last\" rendering of the sender pulled from the users table at read time. Nullable so the API stays forward- compatible if the join ever falls back (e.g. deleted user row).  | [optional] 
**receiverDisplayName** | **String** | Best-effort \"First Last\" rendering of the receiver. Mirror of `sender_display_name`.  | [optional] 
**receiverAccountNumber** | **String** |  | 
**amountKobo** | **int** |  | 
**status** | **String** |  | 
**reference** | **String** |  | 
**failureReason** | **String** |  | [optional] 
**createdAt** | [**DateTime**](DateTime.md) |  | 
**settledAt** | [**DateTime**](DateTime.md) |  | [optional] 

[[Back to Model list]](../README.md#documentation-for-models) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to README]](../README.md)


