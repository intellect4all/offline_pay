import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:offlinepay_api/offlinepay_api.dart';

import '../auth/token_store.dart';
import '../http/debug_logger.dart';
import '../../presentation/cubits/app/app_cubit.dart';
import '../../presentation/cubits/kyc/kyc_cubit.dart';
import '../../presentation/cubits/send_money/send_money_cubit.dart';
import '../../presentation/cubits/session/session_cubit.dart';
import '../../repositories/auth_repository.dart';
import '../../repositories/device_session_repository.dart';
import '../../repositories/keys_repository.dart';
import '../../repositories/kyc_repository.dart';
import '../../repositories/settlement_repository.dart';
import '../../repositories/transfer_repository.dart';
import '../../repositories/wallet_repository.dart';
import '../../services/biometric_unlock.dart';
import '../../services/claim_submitter.dart';
import '../../services/connectivity.dart';
import '../../services/device_registrar.dart';
import '../../services/gossip_pool.dart';
import '../../services/gossip_uploader.dart';
import '../../services/keystore.dart';
import '../../services/local_queue.dart';
import '../../services/offline_auth.dart';
import '../../services/payment_verifier.dart';
import '../../services/push_notifications_service.dart';
import '../../services/receive_coordinator.dart';
import '../../services/session_store.dart';
import '../../services/sync.dart';

final GetIt sl = GetIt.instance;


final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

Future<void> setupServiceLocator({required Uri bffBase}) async {
  if (sl.isRegistered<LocalQueue>()) return;

  final queue = await LocalQueue.open().timeout(
    const Duration(seconds: 10),
    onTimeout: () =>
        throw TimeoutException('local storage open timed out'),
  );
  sl.registerSingleton<LocalQueue>(queue);

  sl.registerLazySingleton<Keystore>(Keystore.new);
  sl.registerLazySingleton<ConnectivityService>(ConnectivityService.new);
  sl.registerLazySingleton<SessionStore>(SessionStore.new);


  sl.registerLazySingleton<TokenStore>(
    () => TokenStore(
      persistent: sl<SessionStore>(),
      refresher: (rt) => sl<AuthRepository>().refresh(rt),
    ),
  );


  sl.registerLazySingleton<OfflinepayApi>(
    () => buildDebugApi(bffBase, sl<TokenStore>()),
  );

  sl.registerLazySingleton<OfflineAuthService>(OfflineAuthService.new);
  sl.registerLazySingleton<BiometricUnlock>(BiometricUnlock.new);

  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepository(api: sl<OfflinepayApi>()),
  );
  sl.registerLazySingleton<DeviceSessionRepository>(
    () => DeviceSessionRepository(api: sl<OfflinepayApi>()),
  );
  sl.registerLazySingleton<TransferRepository>(
    () => TransferRepository(api: sl<OfflinepayApi>()),
  );
  sl.registerLazySingleton<WalletRepository>(
    () => WalletRepository(api: sl<OfflinepayApi>()),
  );
  sl.registerLazySingleton<SettlementRepository>(
    () => SettlementRepository(api: sl<OfflinepayApi>()),
  );
  sl.registerLazySingleton<KeysRepository>(
    () => KeysRepository(api: sl<OfflinepayApi>()),
  );
  sl.registerLazySingleton<KycRepository>(
    () => KycRepository(api: sl<OfflinepayApi>()),
  );

  sl.registerLazySingleton<GossipPool>(
    () => GossipPool(db: sl<LocalQueue>().db),
  );


  String? tokenProvider() => sl<TokenStore>().current?.accessToken;

  sl.registerLazySingleton<DeviceRegistrar>(
    () => DeviceRegistrar(
      keystore: sl<Keystore>(),
      api: sl<OfflinepayApi>().getDefaultApi(),
      tokenProvider: tokenProvider,
    ),
  );

  sl.registerLazySingleton<PushNotificationsService>(
    () => PushNotificationsService(
      api: sl<OfflinepayApi>().getDefaultApi(),
      scaffoldMessengerKey: scaffoldMessengerKey,
    ),
  );

  sl.registerLazySingleton<ClaimSubmitter>(
    () => ClaimSubmitter(
      queue: sl<LocalQueue>(),
      settlement: sl<SettlementRepository>(),
      tokenProvider: tokenProvider,
      countryProvider: _deviceCountryCode,
    ),
  );

  sl.registerLazySingleton<GossipUploader>(
    () => GossipUploader(
      pool: sl<GossipPool>(),
      settlement: sl<SettlementRepository>(),
      tokenProvider: tokenProvider,
    ),
  );

  sl.registerLazySingleton<SyncService>(
    () => SyncService(
      queue: sl<LocalQueue>(),
      keystore: sl<Keystore>(),
      connectivity: sl<ConnectivityService>(),
      settlement: sl<SettlementRepository>(),
      keys: sl<KeysRepository>(),
      claimSubmitter: sl<ClaimSubmitter>(),
      gossipUploader: sl<GossipUploader>(),
      gossipPool: sl<GossipPool>(),
      tokenProvider: tokenProvider,
    ),
  );

  sl.registerLazySingleton<SessionCubit>(
    () => SessionCubit(
      repo: sl<AuthRepository>(),
      tokenStore: sl<TokenStore>(),
      store: sl<SessionStore>(),
      deviceRegistrar: sl<DeviceRegistrar>(),
      offlineAuth: sl<OfflineAuthService>(),
      deviceSessionRepo: sl<DeviceSessionRepository>(),
      biometric: sl<BiometricUnlock>(),
      keystore: sl<Keystore>(),
      push: sl<PushNotificationsService>(),
    ),
  );

  sl.registerLazySingleton<AppCubit>(
    () => AppCubit(
      queue: sl<LocalQueue>(),
      keystore: sl<Keystore>(),
      connectivity: sl<ConnectivityService>(),
      sync: sl<SyncService>(),
      walletRepo: sl<WalletRepository>(),
      transferRepo: sl<TransferRepository>(),
      authRepo: sl<AuthRepository>(),
      tokenProvider: tokenProvider,
    ),
  );

  sl.registerLazySingleton<SendMoneyCubit>(
    () => SendMoneyCubit(
      repo: sl<TransferRepository>(),
      session: sl<SessionCubit>(),
    ),
  );

  sl.registerLazySingleton<KycCubit>(
    () => KycCubit(
      repo: sl<KycRepository>(),
      session: sl<SessionCubit>(),
    ),
  );


  sl.registerLazySingleton<PaymentVerifier>(
    () => PaymentVerifier(
      keystore: sl<Keystore>(),
      queue: sl<LocalQueue>(),
      realmKeyResolver: (v) => sl<AppCubit>().realmKeyForVersion(v),
      activeRequestLookup: (nonce) =>
          sl<AppCubit>().matchActiveRequest(nonce),
      gossipPool: sl<GossipPool>(),
    ),
  );

  sl.registerLazySingleton<ReceiveCoordinator>(
    () => ReceiveCoordinator(keystore: sl<Keystore>()),
  );


  sl<SyncService>().realmInstaller = sl<AppCubit>().installRealmKey;


  sl<SessionCubit>().displayCardInstaller = sl<AppCubit>().setDisplayCard;
  sl<SessionCubit>().userIdInstaller = sl<AppCubit>().setUserId;

  sl<SyncService>().deviceSessionRetrier =
      () => sl<SessionCubit>().retryDeviceSessionMintIfPending();


  await sl<TokenStore>().hydrate();
  sl<TokenStore>().onSessionDead = () {
    unawaited(sl<SessionCubit>().logout());
  };
}

String? _deviceCountryCode() {
  try {
    final raw = Platform.localeName;
    final sep = raw.contains('_')
        ? '_'
        : raw.contains('-')
            ? '-'
            : '';
    if (sep.isEmpty) return null;
    final parts = raw.split(sep);
    if (parts.length < 2) return null;
    final cc = parts[1].trim();
    if (cc.length < 2) return null;
    return cc.substring(0, 2).toUpperCase();
  } catch (_) {
    return null;
  }
}
