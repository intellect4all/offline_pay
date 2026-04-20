//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_import

import 'package:one_of_serializer/any_of_serializer.dart';
import 'package:one_of_serializer/one_of_serializer.dart';
import 'package:built_collection/built_collection.dart';
import 'package:built_value/json_object.dart';
import 'package:built_value/serializer.dart';
import 'package:built_value/standard_json_plugin.dart';
import 'package:built_value/iso_8601_date_time_serializer.dart';
import 'package:offlinepay_api/src/date_serializer.dart';
import 'package:offlinepay_api/src/model/date.dart';

import 'package:offlinepay_api/src/model/account_balance.dart';
import 'package:offlinepay_api/src/model/attest_body.dart';
import 'package:offlinepay_api/src/model/attest_response.dart';
import 'package:offlinepay_api/src/model/attestation_challenge_response.dart';
import 'package:offlinepay_api/src/model/auth_tokens.dart';
import 'package:offlinepay_api/src/model/bank_public_key.dart';
import 'package:offlinepay_api/src/model/bank_public_keys_body.dart';
import 'package:offlinepay_api/src/model/bank_public_keys_response.dart';
import 'package:offlinepay_api/src/model/batch_receipt.dart';
import 'package:offlinepay_api/src/model/ceiling_token.dart';
import 'package:offlinepay_api/src/model/ceiling_token_input.dart';
import 'package:offlinepay_api/src/model/current_ceiling_response.dart';
import 'package:offlinepay_api/src/model/deactivate_device_body.dart';
import 'package:offlinepay_api/src/model/deactivate_device_response.dart';
import 'package:offlinepay_api/src/model/device_session_public_key.dart';
import 'package:offlinepay_api/src/model/device_session_public_keys.dart';
import 'package:offlinepay_api/src/model/device_session_request.dart';
import 'package:offlinepay_api/src/model/device_session_response.dart';
import 'package:offlinepay_api/src/model/display_card_input.dart';
import 'package:offlinepay_api/src/model/email_verify_confirm_body.dart';
import 'package:offlinepay_api/src/model/error.dart';
import 'package:offlinepay_api/src/model/forgot_password_request_body.dart';
import 'package:offlinepay_api/src/model/forgot_password_reset_body.dart';
import 'package:offlinepay_api/src/model/fund_offline_body.dart';
import 'package:offlinepay_api/src/model/fund_offline_response.dart';
import 'package:offlinepay_api/src/model/get_active_realm_keys_response.dart';
import 'package:offlinepay_api/src/model/get_balances_response.dart';
import 'package:offlinepay_api/src/model/get_realm_key_response.dart';
import 'package:offlinepay_api/src/model/gossip_blob_input.dart';
import 'package:offlinepay_api/src/model/gossip_upload_body.dart';
import 'package:offlinepay_api/src/model/gossip_upload_response.dart';
import 'package:offlinepay_api/src/model/health_response.dart';
import 'package:offlinepay_api/src/model/initiate_transfer_body.dart';
import 'package:offlinepay_api/src/model/kyc_submission.dart';
import 'package:offlinepay_api/src/model/kyc_submission_list.dart';
import 'package:offlinepay_api/src/model/kyc_submit_body.dart';
import 'package:offlinepay_api/src/model/login_body.dart';
import 'package:offlinepay_api/src/model/logout_body.dart';
import 'package:offlinepay_api/src/model/me.dart';
import 'package:offlinepay_api/src/model/move_to_main_response.dart';
import 'package:offlinepay_api/src/model/payment_request_input.dart';
import 'package:offlinepay_api/src/model/payment_token_input.dart';
import 'package:offlinepay_api/src/model/push_token_body.dart';
import 'package:offlinepay_api/src/model/push_token_delete_body.dart';
import 'package:offlinepay_api/src/model/realm_key.dart';
import 'package:offlinepay_api/src/model/recover_device_body.dart';
import 'package:offlinepay_api/src/model/recover_device_response.dart';
import 'package:offlinepay_api/src/model/recover_offline_ceiling_response.dart';
import 'package:offlinepay_api/src/model/refresh_body.dart';
import 'package:offlinepay_api/src/model/refresh_ceiling_body.dart';
import 'package:offlinepay_api/src/model/refresh_ceiling_response.dart';
import 'package:offlinepay_api/src/model/register_device_body.dart';
import 'package:offlinepay_api/src/model/register_device_response.dart';
import 'package:offlinepay_api/src/model/resolved_account.dart';
import 'package:offlinepay_api/src/model/revoke_all_others_response.dart';
import 'package:offlinepay_api/src/model/revoke_device_body.dart';
import 'package:offlinepay_api/src/model/revoke_device_response.dart';
import 'package:offlinepay_api/src/model/rotate_device_body.dart';
import 'package:offlinepay_api/src/model/rotate_device_response.dart';
import 'package:offlinepay_api/src/model/sealed_box_pubkey_response.dart';
import 'package:offlinepay_api/src/model/session.dart';
import 'package:offlinepay_api/src/model/session_list.dart';
import 'package:offlinepay_api/src/model/set_pin_body.dart';
import 'package:offlinepay_api/src/model/settlement_result.dart';
import 'package:offlinepay_api/src/model/signup_body.dart';
import 'package:offlinepay_api/src/model/submit_claim_body.dart';
import 'package:offlinepay_api/src/model/sync_body.dart';
import 'package:offlinepay_api/src/model/sync_response.dart';
import 'package:offlinepay_api/src/model/synced_transaction.dart';
import 'package:offlinepay_api/src/model/top_up_body.dart';
import 'package:offlinepay_api/src/model/top_up_response.dart';
import 'package:offlinepay_api/src/model/transfer.dart';
import 'package:offlinepay_api/src/model/transfer_list.dart';

part 'serializers.g.dart';

@SerializersFor([
  AccountBalance,
  AttestBody,
  AttestResponse,
  AttestationChallengeResponse,
  AuthTokens,
  BankPublicKey,
  BankPublicKeysBody,
  BankPublicKeysResponse,
  BatchReceipt,
  CeilingToken,
  CeilingTokenInput,
  CurrentCeilingResponse,
  DeactivateDeviceBody,
  DeactivateDeviceResponse,
  DeviceSessionPublicKey,
  DeviceSessionPublicKeys,
  DeviceSessionRequest,
  DeviceSessionResponse,
  DisplayCardInput,
  EmailVerifyConfirmBody,
  Error,
  ForgotPasswordRequestBody,
  ForgotPasswordResetBody,
  FundOfflineBody,
  FundOfflineResponse,
  GetActiveRealmKeysResponse,
  GetBalancesResponse,
  GetRealmKeyResponse,
  GossipBlobInput,
  GossipUploadBody,
  GossipUploadResponse,
  HealthResponse,
  InitiateTransferBody,
  KYCSubmission,
  KYCSubmissionList,
  KYCSubmitBody,
  LoginBody,
  LogoutBody,
  Me,
  MoveToMainResponse,
  PaymentRequestInput,
  PaymentTokenInput,
  PushTokenBody,
  PushTokenDeleteBody,
  RealmKey,
  RecoverDeviceBody,
  RecoverDeviceResponse,
  RecoverOfflineCeilingResponse,
  RefreshBody,
  RefreshCeilingBody,
  RefreshCeilingResponse,
  RegisterDeviceBody,
  RegisterDeviceResponse,
  ResolvedAccount,
  RevokeAllOthersResponse,
  RevokeDeviceBody,
  RevokeDeviceResponse,
  RotateDeviceBody,
  RotateDeviceResponse,
  SealedBoxPubkeyResponse,
  Session,
  SessionList,
  SetPinBody,
  SettlementResult,
  SignupBody,
  SubmitClaimBody,
  SyncBody,
  SyncResponse,
  SyncedTransaction,
  TopUpBody,
  TopUpResponse,
  Transfer,
  TransferList,
])
Serializers serializers = (_$serializers.toBuilder()
      ..addBuilderFactory(
        const FullType(BuiltMap, [FullType(String), FullType(String)]),
        () => MapBuilder<String, String>(),
      )
      ..add(const OneOfSerializer())
      ..add(const AnyOfSerializer())
      ..add(const DateSerializer())
      ..add(Iso8601DateTimeSerializer())
    ).build();

Serializers standardSerializers =
    (serializers.toBuilder()..addPlugin(StandardJsonPlugin())).build();
