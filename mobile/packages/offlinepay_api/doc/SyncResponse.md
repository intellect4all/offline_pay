# offlinepay_api.model.SyncResponse

## Load the model package
```dart
import 'package:offlinepay_api/api.dart';
```

## Properties
Name | Type | Description | Notes
------------ | ------------- | ------------- | -------------
**payerSide** | [**BuiltList&lt;SyncedTransaction&gt;**](SyncedTransaction.md) |  | 
**receiverSide** | [**BuiltList&lt;SyncedTransaction&gt;**](SyncedTransaction.md) |  | 
**syncedAt** | [**DateTime**](DateTime.md) |  | 
**finalizedCount** | **int** |  | 
**finalizePending** | **bool** | True when the caller set `finalize=true` and the server enqueued a settlement-finalize event. The ledger move runs asynchronously in the worker; clients should surface an \"in progress\" hint and wait for the `offline_payment_settled` push or the next sync cycle.  | [optional] 

[[Back to Model list]](../README.md#documentation-for-models) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to README]](../README.md)


