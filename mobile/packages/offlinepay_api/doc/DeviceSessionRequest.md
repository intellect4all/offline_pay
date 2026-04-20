# offlinepay_api.model.DeviceSessionRequest

## Load the model package
```dart
import 'package:offlinepay_api/api.dart';
```

## Properties
Name | Type | Description | Notes
------------ | ------------- | ------------- | -------------
**deviceId** | **String** | Caller's registered device identifier (returned by `POST /v1/devices`). Must be active and owned by the authenticated user, otherwise the server returns 403.  | 
**scope** | **String** | Capability scope this token grants on-device. Defaults to `offline_pay`. Reserved for future tiers; unknown scopes 400.  | [optional] 

[[Back to Model list]](../README.md#documentation-for-models) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to README]](../README.md)


