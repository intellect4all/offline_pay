# offlinepay_api.api.DefaultApi

## Load the API package
```dart
import 'package:offlinepay_api/api.dart';
```

All URIs are relative to *http://localhost:8082*

Method | HTTP request | Description
------------- | ------------- | -------------
[**deleteV1DevicesPushToken**](DefaultApi.md#deletev1devicespushtoken) | **DELETE** /v1/devices/push-token | Remove an FCM push token for the authenticated user.
[**getHealth**](DefaultApi.md#gethealth) | **GET** /health | Liveness probe.
[**getV1AccountsResolveAccountNumber**](DefaultApi.md#getv1accountsresolveaccountnumber) | **GET** /v1/accounts/resolve/{accountNumber} | Resolve an account number to a masked owner label.
[**getV1AuthDeviceSessionPublicKeys**](DefaultApi.md#getv1authdevicesessionpublickeys) | **GET** /v1/auth/device-session/public-keys | Return the active server public key(s) the device should trust when verifying device session tokens offline. Cached at registration; the device falls back to the cache if this endpoint is unreachable. 
[**getV1AuthSessions**](DefaultApi.md#getv1authsessions) | **GET** /v1/auth/sessions | List the authenticated user&#39;s active refresh sessions.
[**getV1IdentityDisplayCard**](DefaultApi.md#getv1identitydisplaycard) | **GET** /v1/identity/display-card | Fetch the caller&#39;s currently-issued DisplayCard.
[**getV1KeysRealmActive**](DefaultApi.md#getv1keysrealmactive) | **GET** /v1/keys/realm/active | Fetch all active realm key versions in the overlap window.
[**getV1KeysRealmVersion**](DefaultApi.md#getv1keysrealmversion) | **GET** /v1/keys/realm/{version} | Fetch a specific realm key version (authed, device-scoped).
[**getV1KeysSealedBoxPubkey**](DefaultApi.md#getv1keyssealedboxpubkey) | **GET** /v1/keys/sealed-box-pubkey | Fetch the server&#39;s X25519 sealed-box public key (keyless).
[**getV1KycHint**](DefaultApi.md#getv1kychint) | **GET** /v1/kyc/hint | Dev helper — expected mock NIN/BVN for the caller&#39;s phone.
[**getV1KycSubmissions**](DefaultApi.md#getv1kycsubmissions) | **GET** /v1/kyc/submissions | List the caller&#39;s KYC submission history.
[**getV1Me**](DefaultApi.md#getv1me) | **GET** /v1/me | Fetch the authenticated user&#39;s profile.
[**getV1SettlementClaimsBatchID**](DefaultApi.md#getv1settlementclaimsbatchid) | **GET** /v1/settlement/claims/{batchId} | Fetch a previously submitted batch receipt.
[**getV1Transfers**](DefaultApi.md#getv1transfers) | **GET** /v1/transfers | List transfers for the authenticated user (sender or receiver).
[**getV1TransfersID**](DefaultApi.md#getv1transfersid) | **GET** /v1/transfers/{id} | Fetch a transfer by id (must be a party).
[**getV1WalletBalances**](DefaultApi.md#getv1walletbalances) | **GET** /v1/wallet/balances | Fetch all five account balances for the authenticated user.
[**getV1WalletCeilingCurrent**](DefaultApi.md#getv1walletceilingcurrent) | **GET** /v1/wallet/ceiling/current | Fetch the payer&#39;s current non-terminal ceiling (ACTIVE or RECOVERY_PENDING) with live settled / remaining totals. Used by the mobile client to render the tri-state offline-wallet card and to converge local state after a recovery. 
[**postV1AuthDeviceSession**](DefaultApi.md#postv1authdevicesession) | **POST** /v1/auth/device-session | Issue an Ed25519-signed device session token. The token authorizes offline-scope operations on this device (PIN/biometric-gated) when the app starts cold without internet. Token verification is purely local against the embedded &#x60;server_public_key&#x60;. 
[**postV1AuthEmailVerifyConfirm**](DefaultApi.md#postv1authemailverifyconfirm) | **POST** /v1/auth/email/verify/confirm | Confirm the email-verification OTP for the authenticated user.
[**postV1AuthEmailVerifyRequest**](DefaultApi.md#postv1authemailverifyrequest) | **POST** /v1/auth/email/verify/request | Dispatch an email-verification OTP for the authenticated user.
[**postV1AuthForgotPasswordRequest**](DefaultApi.md#postv1authforgotpasswordrequest) | **POST** /v1/auth/forgot-password/request | Dispatch a password-reset OTP by email. Always returns 204 (no enumeration).
[**postV1AuthForgotPasswordReset**](DefaultApi.md#postv1authforgotpasswordreset) | **POST** /v1/auth/forgot-password/reset | Reset a password by email + OTP.
[**postV1AuthLogin**](DefaultApi.md#postv1authlogin) | **POST** /v1/auth/login | Authenticate with phone + password.
[**postV1AuthLogout**](DefaultApi.md#postv1authlogout) | **POST** /v1/auth/logout | Revoke a refresh token.
[**postV1AuthPin**](DefaultApi.md#postv1authpin) | **POST** /v1/auth/pin | Set (or replace) the authenticated user&#39;s transaction PIN.
[**postV1AuthRefresh**](DefaultApi.md#postv1authrefresh) | **POST** /v1/auth/refresh | Rotate a refresh token.
[**postV1AuthSessionsIdRevoke**](DefaultApi.md#postv1authsessionsidrevoke) | **POST** /v1/auth/sessions/{id}/revoke | Revoke a single session owned by the authenticated user.
[**postV1AuthSessionsRevokeAllOthers**](DefaultApi.md#postv1authsessionsrevokeallothers) | **POST** /v1/auth/sessions/revoke-all-others | Revoke every session for the caller except the current one.
[**postV1AuthSignup**](DefaultApi.md#postv1authsignup) | **POST** /v1/auth/signup | Register a new user (phone + password + profile). Lands at KYC tier TIER_1.
[**postV1Devices**](DefaultApi.md#postv1devices) | **POST** /v1/devices | Register a new device for the authenticated user.
[**postV1DevicesAttestationChallenge**](DefaultApi.md#postv1devicesattestationchallenge) | **POST** /v1/devices/attestation-challenge | Obtain a fresh server-issued attestation nonce.
[**postV1DevicesDeviceIdAttest**](DefaultApi.md#postv1devicesdeviceidattest) | **POST** /v1/devices/{deviceId}/attest | Re-attest an existing device and receive a fresh device JWT.
[**postV1DevicesDeviceIdDeactivate**](DefaultApi.md#postv1devicesdeviceiddeactivate) | **POST** /v1/devices/{deviceId}/deactivate | Deactivate a device owned by the authenticated user.
[**postV1DevicesDeviceIdRevoke**](DefaultApi.md#postv1devicesdeviceidrevoke) | **POST** /v1/devices/{deviceId}/revoke | Revoke another device belonging to the authenticated user.
[**postV1DevicesPushToken**](DefaultApi.md#postv1devicespushtoken) | **POST** /v1/devices/push-token | Register (or refresh) an FCM push token for the authenticated user.
[**postV1DevicesRecover**](DefaultApi.md#postv1devicesrecover) | **POST** /v1/devices/recover | Provision a replacement device via recovery proof (keyless).
[**postV1DevicesRotate**](DefaultApi.md#postv1devicesrotate) | **POST** /v1/devices/rotate | Rotate to a new device (retires the old one atomically).
[**postV1KeysBankPublicKeys**](DefaultApi.md#postv1keysbankpublickeys) | **POST** /v1/keys/bank-public-keys | Fetch bank Ed25519 public keys (keyless).
[**postV1KycSubmit**](DefaultApi.md#postv1kycsubmit) | **POST** /v1/kyc/submit | Submit a NIN (promotes to TIER_2) or BVN (promotes to TIER_3).
[**postV1SettlementClaims**](DefaultApi.md#postv1settlementclaims) | **POST** /v1/settlement/claims | Submit a batch of offline payment tokens for claim (Phase 4a).
[**postV1SettlementGossip**](DefaultApi.md#postv1settlementgossip) | **POST** /v1/settlement/gossip | Upload carried gossip blobs for settlement decryption and routing.
[**postV1SettlementSync**](DefaultApi.md#postv1settlementsync) | **POST** /v1/settlement/sync | Sync payer-side and receiver-side settled transactions for reconciliation.
[**postV1Transfers**](DefaultApi.md#postv1transfers) | **POST** /v1/transfers | Initiate a user-to-user transfer.
[**postV1WalletFundOffline**](DefaultApi.md#postv1walletfundoffline) | **POST** /v1/wallet/fund-offline | Debit main wallet, place lien, and issue a fresh ceiling token.
[**postV1WalletMoveToMain**](DefaultApi.md#postv1walletmovetomain) | **POST** /v1/wallet/move-to-main | Revoke active ceiling and release lien back to the main wallet.
[**postV1WalletRecoverOfflineCeiling**](DefaultApi.md#postv1walletrecoverofflineceiling) | **POST** /v1/wallet/recover-offline-ceiling | Begin recovery of a ceiling whose device-side token was lost. The lien stays locked during a quarantine window (expires_at + auto_settle_timeout + grace) so any offline-carried claims can still land; the expiry sweep then returns the remaining lien to the main wallet. 
[**postV1WalletRefreshCeiling**](DefaultApi.md#postv1walletrefreshceiling) | **POST** /v1/wallet/refresh-ceiling | Consume the remaining ceiling into a fresh one with a new amount/TTL.
[**postV1WalletTopUp**](DefaultApi.md#postv1wallettopup) | **POST** /v1/wallet/top-up | Dev-only endpoint to credit the user&#39;s main wallet with fake funds.


# **deleteV1DevicesPushToken**
> deleteV1DevicesPushToken(pushTokenDeleteBody)

Remove an FCM push token for the authenticated user.

### Example
```dart
import 'package:offlinepay_api/api.dart';

final api = OfflinepayApi().getDefaultApi();
final PushTokenDeleteBody pushTokenDeleteBody = ; // PushTokenDeleteBody | 

try {
    api.deleteV1DevicesPushToken(pushTokenDeleteBody);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->deleteV1DevicesPushToken: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **pushTokenDeleteBody** | [**PushTokenDeleteBody**](PushTokenDeleteBody.md)|  | 

### Return type

void (empty response body)

### Authorization

[bearerAuth](../README.md#bearerAuth)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getHealth**
> HealthResponse getHealth()

Liveness probe.

### Example
```dart
import 'package:offlinepay_api/api.dart';

final api = OfflinepayApi().getDefaultApi();

try {
    final response = api.getHealth();
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->getHealth: $e\n');
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

[**HealthResponse**](HealthResponse.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getV1AccountsResolveAccountNumber**
> ResolvedAccount getV1AccountsResolveAccountNumber(accountNumber)

Resolve an account number to a masked owner label.

### Example
```dart
import 'package:offlinepay_api/api.dart';

final api = OfflinepayApi().getDefaultApi();
final String accountNumber = accountNumber_example; // String | 

try {
    final response = api.getV1AccountsResolveAccountNumber(accountNumber);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->getV1AccountsResolveAccountNumber: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **accountNumber** | **String**|  | 

### Return type

[**ResolvedAccount**](ResolvedAccount.md)

### Authorization

[bearerAuth](../README.md#bearerAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getV1AuthDeviceSessionPublicKeys**
> DeviceSessionPublicKeys getV1AuthDeviceSessionPublicKeys()

Return the active server public key(s) the device should trust when verifying device session tokens offline. Cached at registration; the device falls back to the cache if this endpoint is unreachable. 

### Example
```dart
import 'package:offlinepay_api/api.dart';

final api = OfflinepayApi().getDefaultApi();

try {
    final response = api.getV1AuthDeviceSessionPublicKeys();
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->getV1AuthDeviceSessionPublicKeys: $e\n');
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

[**DeviceSessionPublicKeys**](DeviceSessionPublicKeys.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getV1AuthSessions**
> SessionList getV1AuthSessions()

List the authenticated user's active refresh sessions.

### Example
```dart
import 'package:offlinepay_api/api.dart';

final api = OfflinepayApi().getDefaultApi();

try {
    final response = api.getV1AuthSessions();
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->getV1AuthSessions: $e\n');
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

[**SessionList**](SessionList.md)

### Authorization

[bearerAuth](../README.md#bearerAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getV1IdentityDisplayCard**
> DisplayCardInput getV1IdentityDisplayCard()

Fetch the caller's currently-issued DisplayCard.

Receivers embed the DisplayCard in every PaymentRequest they publish. Clients should refresh this on login and whenever the name/account shown in the UI changes. 

### Example
```dart
import 'package:offlinepay_api/api.dart';

final api = OfflinepayApi().getDefaultApi();

try {
    final response = api.getV1IdentityDisplayCard();
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->getV1IdentityDisplayCard: $e\n');
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

[**DisplayCardInput**](DisplayCardInput.md)

### Authorization

[bearerAuth](../README.md#bearerAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getV1KeysRealmActive**
> GetActiveRealmKeysResponse getV1KeysRealmActive(deviceId, limit)

Fetch all active realm key versions in the overlap window.

### Example
```dart
import 'package:offlinepay_api/api.dart';

final api = OfflinepayApi().getDefaultApi();
final String deviceId = deviceId_example; // String | 
final int limit = 56; // int | 

try {
    final response = api.getV1KeysRealmActive(deviceId, limit);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->getV1KeysRealmActive: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **deviceId** | **String**|  | 
 **limit** | **int**|  | [optional] 

### Return type

[**GetActiveRealmKeysResponse**](GetActiveRealmKeysResponse.md)

### Authorization

[bearerAuth](../README.md#bearerAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getV1KeysRealmVersion**
> GetRealmKeyResponse getV1KeysRealmVersion(version, deviceId)

Fetch a specific realm key version (authed, device-scoped).

### Example
```dart
import 'package:offlinepay_api/api.dart';

final api = OfflinepayApi().getDefaultApi();
final int version = 56; // int | 
final String deviceId = deviceId_example; // String | 

try {
    final response = api.getV1KeysRealmVersion(version, deviceId);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->getV1KeysRealmVersion: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **version** | **int**|  | 
 **deviceId** | **String**|  | 

### Return type

[**GetRealmKeyResponse**](GetRealmKeyResponse.md)

### Authorization

[bearerAuth](../README.md#bearerAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getV1KeysSealedBoxPubkey**
> SealedBoxPubkeyResponse getV1KeysSealedBoxPubkey()

Fetch the server's X25519 sealed-box public key (keyless).

### Example
```dart
import 'package:offlinepay_api/api.dart';

final api = OfflinepayApi().getDefaultApi();

try {
    final response = api.getV1KeysSealedBoxPubkey();
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->getV1KeysSealedBoxPubkey: $e\n');
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

[**SealedBoxPubkeyResponse**](SealedBoxPubkeyResponse.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getV1KycHint**
> BuiltMap<String, String> getV1KycHint()

Dev helper — expected mock NIN/BVN for the caller's phone.

### Example
```dart
import 'package:offlinepay_api/api.dart';

final api = OfflinepayApi().getDefaultApi();

try {
    final response = api.getV1KycHint();
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->getV1KycHint: $e\n');
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

**BuiltMap&lt;String, String&gt;**

### Authorization

[bearerAuth](../README.md#bearerAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getV1KycSubmissions**
> KYCSubmissionList getV1KycSubmissions()

List the caller's KYC submission history.

### Example
```dart
import 'package:offlinepay_api/api.dart';

final api = OfflinepayApi().getDefaultApi();

try {
    final response = api.getV1KycSubmissions();
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->getV1KycSubmissions: $e\n');
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

[**KYCSubmissionList**](KYCSubmissionList.md)

### Authorization

[bearerAuth](../README.md#bearerAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getV1Me**
> Me getV1Me()

Fetch the authenticated user's profile.

### Example
```dart
import 'package:offlinepay_api/api.dart';

final api = OfflinepayApi().getDefaultApi();

try {
    final response = api.getV1Me();
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->getV1Me: $e\n');
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

[**Me**](Me.md)

### Authorization

[bearerAuth](../README.md#bearerAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getV1SettlementClaimsBatchID**
> BatchReceipt getV1SettlementClaimsBatchID(batchId)

Fetch a previously submitted batch receipt.

### Example
```dart
import 'package:offlinepay_api/api.dart';

final api = OfflinepayApi().getDefaultApi();
final String batchId = batchId_example; // String | 

try {
    final response = api.getV1SettlementClaimsBatchID(batchId);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->getV1SettlementClaimsBatchID: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **batchId** | **String**|  | 

### Return type

[**BatchReceipt**](BatchReceipt.md)

### Authorization

[bearerAuth](../README.md#bearerAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getV1Transfers**
> TransferList getV1Transfers(limit, offset)

List transfers for the authenticated user (sender or receiver).

### Example
```dart
import 'package:offlinepay_api/api.dart';

final api = OfflinepayApi().getDefaultApi();
final int limit = 56; // int | 
final int offset = 56; // int | 

try {
    final response = api.getV1Transfers(limit, offset);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->getV1Transfers: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **limit** | **int**|  | [optional] 
 **offset** | **int**|  | [optional] 

### Return type

[**TransferList**](TransferList.md)

### Authorization

[bearerAuth](../README.md#bearerAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getV1TransfersID**
> Transfer getV1TransfersID(id)

Fetch a transfer by id (must be a party).

### Example
```dart
import 'package:offlinepay_api/api.dart';

final api = OfflinepayApi().getDefaultApi();
final String id = id_example; // String | 

try {
    final response = api.getV1TransfersID(id);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->getV1TransfersID: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **id** | **String**|  | 

### Return type

[**Transfer**](Transfer.md)

### Authorization

[bearerAuth](../README.md#bearerAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getV1WalletBalances**
> GetBalancesResponse getV1WalletBalances()

Fetch all five account balances for the authenticated user.

### Example
```dart
import 'package:offlinepay_api/api.dart';

final api = OfflinepayApi().getDefaultApi();

try {
    final response = api.getV1WalletBalances();
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->getV1WalletBalances: $e\n');
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

[**GetBalancesResponse**](GetBalancesResponse.md)

### Authorization

[bearerAuth](../README.md#bearerAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getV1WalletCeilingCurrent**
> CurrentCeilingResponse getV1WalletCeilingCurrent()

Fetch the payer's current non-terminal ceiling (ACTIVE or RECOVERY_PENDING) with live settled / remaining totals. Used by the mobile client to render the tri-state offline-wallet card and to converge local state after a recovery. 

Always returns 200 — `present: false` means the payer has no offline wallet right now. `present: true` carries the full status snapshot; `release_after` is populated only when status is RECOVERY_PENDING. 

### Example
```dart
import 'package:offlinepay_api/api.dart';

final api = OfflinepayApi().getDefaultApi();

try {
    final response = api.getV1WalletCeilingCurrent();
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->getV1WalletCeilingCurrent: $e\n');
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

[**CurrentCeilingResponse**](CurrentCeilingResponse.md)

### Authorization

[bearerAuth](../README.md#bearerAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **postV1AuthDeviceSession**
> DeviceSessionResponse postV1AuthDeviceSession(deviceSessionRequest)

Issue an Ed25519-signed device session token. The token authorizes offline-scope operations on this device (PIN/biometric-gated) when the app starts cold without internet. Token verification is purely local against the embedded `server_public_key`. 

### Example
```dart
import 'package:offlinepay_api/api.dart';

final api = OfflinepayApi().getDefaultApi();
final DeviceSessionRequest deviceSessionRequest = ; // DeviceSessionRequest | 

try {
    final response = api.postV1AuthDeviceSession(deviceSessionRequest);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->postV1AuthDeviceSession: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **deviceSessionRequest** | [**DeviceSessionRequest**](DeviceSessionRequest.md)|  | 

### Return type

[**DeviceSessionResponse**](DeviceSessionResponse.md)

### Authorization

[bearerAuth](../README.md#bearerAuth)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **postV1AuthEmailVerifyConfirm**
> postV1AuthEmailVerifyConfirm(emailVerifyConfirmBody)

Confirm the email-verification OTP for the authenticated user.

### Example
```dart
import 'package:offlinepay_api/api.dart';

final api = OfflinepayApi().getDefaultApi();
final EmailVerifyConfirmBody emailVerifyConfirmBody = ; // EmailVerifyConfirmBody | 

try {
    api.postV1AuthEmailVerifyConfirm(emailVerifyConfirmBody);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->postV1AuthEmailVerifyConfirm: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **emailVerifyConfirmBody** | [**EmailVerifyConfirmBody**](EmailVerifyConfirmBody.md)|  | 

### Return type

void (empty response body)

### Authorization

[bearerAuth](../README.md#bearerAuth)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **postV1AuthEmailVerifyRequest**
> postV1AuthEmailVerifyRequest()

Dispatch an email-verification OTP for the authenticated user.

### Example
```dart
import 'package:offlinepay_api/api.dart';

final api = OfflinepayApi().getDefaultApi();

try {
    api.postV1AuthEmailVerifyRequest();
} on DioException catch (e) {
    print('Exception when calling DefaultApi->postV1AuthEmailVerifyRequest: $e\n');
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

void (empty response body)

### Authorization

[bearerAuth](../README.md#bearerAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **postV1AuthForgotPasswordRequest**
> postV1AuthForgotPasswordRequest(forgotPasswordRequestBody)

Dispatch a password-reset OTP by email. Always returns 204 (no enumeration).

### Example
```dart
import 'package:offlinepay_api/api.dart';

final api = OfflinepayApi().getDefaultApi();
final ForgotPasswordRequestBody forgotPasswordRequestBody = ; // ForgotPasswordRequestBody | 

try {
    api.postV1AuthForgotPasswordRequest(forgotPasswordRequestBody);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->postV1AuthForgotPasswordRequest: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **forgotPasswordRequestBody** | [**ForgotPasswordRequestBody**](ForgotPasswordRequestBody.md)|  | 

### Return type

void (empty response body)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: Not defined

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **postV1AuthForgotPasswordReset**
> postV1AuthForgotPasswordReset(forgotPasswordResetBody)

Reset a password by email + OTP.

### Example
```dart
import 'package:offlinepay_api/api.dart';

final api = OfflinepayApi().getDefaultApi();
final ForgotPasswordResetBody forgotPasswordResetBody = ; // ForgotPasswordResetBody | 

try {
    api.postV1AuthForgotPasswordReset(forgotPasswordResetBody);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->postV1AuthForgotPasswordReset: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **forgotPasswordResetBody** | [**ForgotPasswordResetBody**](ForgotPasswordResetBody.md)|  | 

### Return type

void (empty response body)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **postV1AuthLogin**
> AuthTokens postV1AuthLogin(loginBody)

Authenticate with phone + password.

### Example
```dart
import 'package:offlinepay_api/api.dart';

final api = OfflinepayApi().getDefaultApi();
final LoginBody loginBody = ; // LoginBody | 

try {
    final response = api.postV1AuthLogin(loginBody);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->postV1AuthLogin: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **loginBody** | [**LoginBody**](LoginBody.md)|  | 

### Return type

[**AuthTokens**](AuthTokens.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **postV1AuthLogout**
> postV1AuthLogout(logoutBody)

Revoke a refresh token.

### Example
```dart
import 'package:offlinepay_api/api.dart';

final api = OfflinepayApi().getDefaultApi();
final LogoutBody logoutBody = ; // LogoutBody | 

try {
    api.postV1AuthLogout(logoutBody);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->postV1AuthLogout: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **logoutBody** | [**LogoutBody**](LogoutBody.md)|  | 

### Return type

void (empty response body)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: Not defined

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **postV1AuthPin**
> postV1AuthPin(setPinBody)

Set (or replace) the authenticated user's transaction PIN.

### Example
```dart
import 'package:offlinepay_api/api.dart';

final api = OfflinepayApi().getDefaultApi();
final SetPinBody setPinBody = ; // SetPinBody | 

try {
    api.postV1AuthPin(setPinBody);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->postV1AuthPin: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **setPinBody** | [**SetPinBody**](SetPinBody.md)|  | 

### Return type

void (empty response body)

### Authorization

[bearerAuth](../README.md#bearerAuth)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **postV1AuthRefresh**
> AuthTokens postV1AuthRefresh(refreshBody)

Rotate a refresh token.

### Example
```dart
import 'package:offlinepay_api/api.dart';

final api = OfflinepayApi().getDefaultApi();
final RefreshBody refreshBody = ; // RefreshBody | 

try {
    final response = api.postV1AuthRefresh(refreshBody);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->postV1AuthRefresh: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **refreshBody** | [**RefreshBody**](RefreshBody.md)|  | 

### Return type

[**AuthTokens**](AuthTokens.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **postV1AuthSessionsIdRevoke**
> postV1AuthSessionsIdRevoke(id)

Revoke a single session owned by the authenticated user.

### Example
```dart
import 'package:offlinepay_api/api.dart';

final api = OfflinepayApi().getDefaultApi();
final String id = id_example; // String | 

try {
    api.postV1AuthSessionsIdRevoke(id);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->postV1AuthSessionsIdRevoke: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **id** | **String**|  | 

### Return type

void (empty response body)

### Authorization

[bearerAuth](../README.md#bearerAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **postV1AuthSessionsRevokeAllOthers**
> RevokeAllOthersResponse postV1AuthSessionsRevokeAllOthers()

Revoke every session for the caller except the current one.

### Example
```dart
import 'package:offlinepay_api/api.dart';

final api = OfflinepayApi().getDefaultApi();

try {
    final response = api.postV1AuthSessionsRevokeAllOthers();
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->postV1AuthSessionsRevokeAllOthers: $e\n');
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

[**RevokeAllOthersResponse**](RevokeAllOthersResponse.md)

### Authorization

[bearerAuth](../README.md#bearerAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **postV1AuthSignup**
> AuthTokens postV1AuthSignup(signupBody)

Register a new user (phone + password + profile). Lands at KYC tier TIER_1.

### Example
```dart
import 'package:offlinepay_api/api.dart';

final api = OfflinepayApi().getDefaultApi();
final SignupBody signupBody = ; // SignupBody | 

try {
    final response = api.postV1AuthSignup(signupBody);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->postV1AuthSignup: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **signupBody** | [**SignupBody**](SignupBody.md)|  | 

### Return type

[**AuthTokens**](AuthTokens.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **postV1Devices**
> RegisterDeviceResponse postV1Devices(registerDeviceBody)

Register a new device for the authenticated user.

### Example
```dart
import 'package:offlinepay_api/api.dart';

final api = OfflinepayApi().getDefaultApi();
final RegisterDeviceBody registerDeviceBody = ; // RegisterDeviceBody | 

try {
    final response = api.postV1Devices(registerDeviceBody);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->postV1Devices: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **registerDeviceBody** | [**RegisterDeviceBody**](RegisterDeviceBody.md)|  | 

### Return type

[**RegisterDeviceResponse**](RegisterDeviceResponse.md)

### Authorization

[bearerAuth](../README.md#bearerAuth)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **postV1DevicesAttestationChallenge**
> AttestationChallengeResponse postV1DevicesAttestationChallenge()

Obtain a fresh server-issued attestation nonce.

### Example
```dart
import 'package:offlinepay_api/api.dart';

final api = OfflinepayApi().getDefaultApi();

try {
    final response = api.postV1DevicesAttestationChallenge();
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->postV1DevicesAttestationChallenge: $e\n');
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

[**AttestationChallengeResponse**](AttestationChallengeResponse.md)

### Authorization

[bearerAuth](../README.md#bearerAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **postV1DevicesDeviceIdAttest**
> AttestResponse postV1DevicesDeviceIdAttest(deviceId, attestBody)

Re-attest an existing device and receive a fresh device JWT.

### Example
```dart
import 'package:offlinepay_api/api.dart';

final api = OfflinepayApi().getDefaultApi();
final String deviceId = deviceId_example; // String | 
final AttestBody attestBody = ; // AttestBody | 

try {
    final response = api.postV1DevicesDeviceIdAttest(deviceId, attestBody);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->postV1DevicesDeviceIdAttest: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **deviceId** | **String**|  | 
 **attestBody** | [**AttestBody**](AttestBody.md)|  | 

### Return type

[**AttestResponse**](AttestResponse.md)

### Authorization

[bearerAuth](../README.md#bearerAuth)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **postV1DevicesDeviceIdDeactivate**
> DeactivateDeviceResponse postV1DevicesDeviceIdDeactivate(deviceId, deactivateDeviceBody)

Deactivate a device owned by the authenticated user.

### Example
```dart
import 'package:offlinepay_api/api.dart';

final api = OfflinepayApi().getDefaultApi();
final String deviceId = deviceId_example; // String | 
final DeactivateDeviceBody deactivateDeviceBody = ; // DeactivateDeviceBody | 

try {
    final response = api.postV1DevicesDeviceIdDeactivate(deviceId, deactivateDeviceBody);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->postV1DevicesDeviceIdDeactivate: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **deviceId** | **String**|  | 
 **deactivateDeviceBody** | [**DeactivateDeviceBody**](DeactivateDeviceBody.md)|  | 

### Return type

[**DeactivateDeviceResponse**](DeactivateDeviceResponse.md)

### Authorization

[bearerAuth](../README.md#bearerAuth)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **postV1DevicesDeviceIdRevoke**
> RevokeDeviceResponse postV1DevicesDeviceIdRevoke(deviceId, revokeDeviceBody)

Revoke another device belonging to the authenticated user.

### Example
```dart
import 'package:offlinepay_api/api.dart';

final api = OfflinepayApi().getDefaultApi();
final String deviceId = deviceId_example; // String | 
final RevokeDeviceBody revokeDeviceBody = ; // RevokeDeviceBody | 

try {
    final response = api.postV1DevicesDeviceIdRevoke(deviceId, revokeDeviceBody);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->postV1DevicesDeviceIdRevoke: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **deviceId** | **String**|  | 
 **revokeDeviceBody** | [**RevokeDeviceBody**](RevokeDeviceBody.md)|  | 

### Return type

[**RevokeDeviceResponse**](RevokeDeviceResponse.md)

### Authorization

[bearerAuth](../README.md#bearerAuth)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **postV1DevicesPushToken**
> postV1DevicesPushToken(pushTokenBody)

Register (or refresh) an FCM push token for the authenticated user.

### Example
```dart
import 'package:offlinepay_api/api.dart';

final api = OfflinepayApi().getDefaultApi();
final PushTokenBody pushTokenBody = ; // PushTokenBody | 

try {
    api.postV1DevicesPushToken(pushTokenBody);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->postV1DevicesPushToken: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **pushTokenBody** | [**PushTokenBody**](PushTokenBody.md)|  | 

### Return type

void (empty response body)

### Authorization

[bearerAuth](../README.md#bearerAuth)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **postV1DevicesRecover**
> RecoverDeviceResponse postV1DevicesRecover(recoverDeviceBody)

Provision a replacement device via recovery proof (keyless).

### Example
```dart
import 'package:offlinepay_api/api.dart';

final api = OfflinepayApi().getDefaultApi();
final RecoverDeviceBody recoverDeviceBody = ; // RecoverDeviceBody | 

try {
    final response = api.postV1DevicesRecover(recoverDeviceBody);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->postV1DevicesRecover: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **recoverDeviceBody** | [**RecoverDeviceBody**](RecoverDeviceBody.md)|  | 

### Return type

[**RecoverDeviceResponse**](RecoverDeviceResponse.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **postV1DevicesRotate**
> RotateDeviceResponse postV1DevicesRotate(rotateDeviceBody)

Rotate to a new device (retires the old one atomically).

### Example
```dart
import 'package:offlinepay_api/api.dart';

final api = OfflinepayApi().getDefaultApi();
final RotateDeviceBody rotateDeviceBody = ; // RotateDeviceBody | 

try {
    final response = api.postV1DevicesRotate(rotateDeviceBody);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->postV1DevicesRotate: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **rotateDeviceBody** | [**RotateDeviceBody**](RotateDeviceBody.md)|  | 

### Return type

[**RotateDeviceResponse**](RotateDeviceResponse.md)

### Authorization

[bearerAuth](../README.md#bearerAuth)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **postV1KeysBankPublicKeys**
> BankPublicKeysResponse postV1KeysBankPublicKeys(bankPublicKeysBody)

Fetch bank Ed25519 public keys (keyless).

### Example
```dart
import 'package:offlinepay_api/api.dart';

final api = OfflinepayApi().getDefaultApi();
final BankPublicKeysBody bankPublicKeysBody = ; // BankPublicKeysBody | 

try {
    final response = api.postV1KeysBankPublicKeys(bankPublicKeysBody);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->postV1KeysBankPublicKeys: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **bankPublicKeysBody** | [**BankPublicKeysBody**](BankPublicKeysBody.md)|  | 

### Return type

[**BankPublicKeysResponse**](BankPublicKeysResponse.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **postV1KycSubmit**
> KYCSubmission postV1KycSubmit(kYCSubmitBody)

Submit a NIN (promotes to TIER_2) or BVN (promotes to TIER_3).

### Example
```dart
import 'package:offlinepay_api/api.dart';

final api = OfflinepayApi().getDefaultApi();
final KYCSubmitBody kYCSubmitBody = ; // KYCSubmitBody | 

try {
    final response = api.postV1KycSubmit(kYCSubmitBody);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->postV1KycSubmit: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **kYCSubmitBody** | [**KYCSubmitBody**](KYCSubmitBody.md)|  | 

### Return type

[**KYCSubmission**](KYCSubmission.md)

### Authorization

[bearerAuth](../README.md#bearerAuth)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **postV1SettlementClaims**
> BatchReceipt postV1SettlementClaims(submitClaimBody)

Submit a batch of offline payment tokens for claim (Phase 4a).

### Example
```dart
import 'package:offlinepay_api/api.dart';

final api = OfflinepayApi().getDefaultApi();
final SubmitClaimBody submitClaimBody = ; // SubmitClaimBody | 

try {
    final response = api.postV1SettlementClaims(submitClaimBody);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->postV1SettlementClaims: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **submitClaimBody** | [**SubmitClaimBody**](SubmitClaimBody.md)|  | 

### Return type

[**BatchReceipt**](BatchReceipt.md)

### Authorization

[bearerAuth](../README.md#bearerAuth)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **postV1SettlementGossip**
> GossipUploadResponse postV1SettlementGossip(gossipUploadBody)

Upload carried gossip blobs for settlement decryption and routing.

### Example
```dart
import 'package:offlinepay_api/api.dart';

final api = OfflinepayApi().getDefaultApi();
final GossipUploadBody gossipUploadBody = ; // GossipUploadBody | 

try {
    final response = api.postV1SettlementGossip(gossipUploadBody);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->postV1SettlementGossip: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **gossipUploadBody** | [**GossipUploadBody**](GossipUploadBody.md)|  | 

### Return type

[**GossipUploadResponse**](GossipUploadResponse.md)

### Authorization

[bearerAuth](../README.md#bearerAuth)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **postV1SettlementSync**
> SyncResponse postV1SettlementSync(syncBody)

Sync payer-side and receiver-side settled transactions for reconciliation.

### Example
```dart
import 'package:offlinepay_api/api.dart';

final api = OfflinepayApi().getDefaultApi();
final SyncBody syncBody = ; // SyncBody | 

try {
    final response = api.postV1SettlementSync(syncBody);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->postV1SettlementSync: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **syncBody** | [**SyncBody**](SyncBody.md)|  | 

### Return type

[**SyncResponse**](SyncResponse.md)

### Authorization

[bearerAuth](../README.md#bearerAuth)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **postV1Transfers**
> Transfer postV1Transfers(initiateTransferBody)

Initiate a user-to-user transfer.

### Example
```dart
import 'package:offlinepay_api/api.dart';

final api = OfflinepayApi().getDefaultApi();
final InitiateTransferBody initiateTransferBody = ; // InitiateTransferBody | 

try {
    final response = api.postV1Transfers(initiateTransferBody);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->postV1Transfers: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **initiateTransferBody** | [**InitiateTransferBody**](InitiateTransferBody.md)|  | 

### Return type

[**Transfer**](Transfer.md)

### Authorization

[bearerAuth](../README.md#bearerAuth)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **postV1WalletFundOffline**
> FundOfflineResponse postV1WalletFundOffline(fundOfflineBody)

Debit main wallet, place lien, and issue a fresh ceiling token.

### Example
```dart
import 'package:offlinepay_api/api.dart';

final api = OfflinepayApi().getDefaultApi();
final FundOfflineBody fundOfflineBody = ; // FundOfflineBody | 

try {
    final response = api.postV1WalletFundOffline(fundOfflineBody);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->postV1WalletFundOffline: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **fundOfflineBody** | [**FundOfflineBody**](FundOfflineBody.md)|  | 

### Return type

[**FundOfflineResponse**](FundOfflineResponse.md)

### Authorization

[bearerAuth](../README.md#bearerAuth)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **postV1WalletMoveToMain**
> MoveToMainResponse postV1WalletMoveToMain()

Revoke active ceiling and release lien back to the main wallet.

### Example
```dart
import 'package:offlinepay_api/api.dart';

final api = OfflinepayApi().getDefaultApi();

try {
    final response = api.postV1WalletMoveToMain();
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->postV1WalletMoveToMain: $e\n');
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

[**MoveToMainResponse**](MoveToMainResponse.md)

### Authorization

[bearerAuth](../README.md#bearerAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **postV1WalletRecoverOfflineCeiling**
> RecoverOfflineCeilingResponse postV1WalletRecoverOfflineCeiling()

Begin recovery of a ceiling whose device-side token was lost. The lien stays locked during a quarantine window (expires_at + auto_settle_timeout + grace) so any offline-carried claims can still land; the expiry sweep then returns the remaining lien to the main wallet. 

Use this ONLY when the device has genuinely lost the ceiling token (e.g. data corruption) — you cannot sign offline payments with it. Unsettled server-visible claims block the call with 409 `unsettled_claims`; wait for those to settle first. 

### Example
```dart
import 'package:offlinepay_api/api.dart';

final api = OfflinepayApi().getDefaultApi();

try {
    final response = api.postV1WalletRecoverOfflineCeiling();
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->postV1WalletRecoverOfflineCeiling: $e\n');
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

[**RecoverOfflineCeilingResponse**](RecoverOfflineCeilingResponse.md)

### Authorization

[bearerAuth](../README.md#bearerAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **postV1WalletRefreshCeiling**
> RefreshCeilingResponse postV1WalletRefreshCeiling(refreshCeilingBody)

Consume the remaining ceiling into a fresh one with a new amount/TTL.

### Example
```dart
import 'package:offlinepay_api/api.dart';

final api = OfflinepayApi().getDefaultApi();
final RefreshCeilingBody refreshCeilingBody = ; // RefreshCeilingBody | 

try {
    final response = api.postV1WalletRefreshCeiling(refreshCeilingBody);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->postV1WalletRefreshCeiling: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **refreshCeilingBody** | [**RefreshCeilingBody**](RefreshCeilingBody.md)|  | 

### Return type

[**RefreshCeilingResponse**](RefreshCeilingResponse.md)

### Authorization

[bearerAuth](../README.md#bearerAuth)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **postV1WalletTopUp**
> TopUpResponse postV1WalletTopUp(topUpBody)

Dev-only endpoint to credit the user's main wallet with fake funds.

### Example
```dart
import 'package:offlinepay_api/api.dart';

final api = OfflinepayApi().getDefaultApi();
final TopUpBody topUpBody = ; // TopUpBody | 

try {
    final response = api.postV1WalletTopUp(topUpBody);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->postV1WalletTopUp: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **topUpBody** | [**TopUpBody**](TopUpBody.md)|  | 

### Return type

[**TopUpResponse**](TopUpResponse.md)

### Authorization

[bearerAuth](../README.md#bearerAuth)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

