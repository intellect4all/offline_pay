import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:offlinepay_core/offlinepay_core.dart' show DisplayCard;

import '../../../core/auth/token_store.dart';
import '../../../repositories/auth_repository.dart';
import '../../../repositories/device_session_repository.dart';
import '../../../services/biometric_unlock.dart';
import '../../../services/device_registrar.dart';
import '../../../services/keystore.dart';
import '../../../services/offline_auth.dart';
import '../../../services/push_notifications_service.dart';
import '../../../services/session_store.dart';
import 'session_state.dart';

export 'session_state.dart';

typedef DisplayCardInstaller = void Function(DisplayCard card);
typedef UserIdInstaller = void Function(String userId);

class SessionCubit extends Cubit<SessionUiState> {
  final AuthRepository _repo;
  final TokenStore _tokenStore;
  final SessionStore _store;
  final DeviceRegistrar? _deviceRegistrar;
  final OfflineAuthService _offlineAuth;
  final DeviceSessionRepository _deviceSessionRepo;
  final BiometricUnlock _biometric;
  final Keystore _keystore;
  final PushNotificationsService? _push;

  Future<void>? _logoutFuture;
  StreamSubscription<AuthSession?>? _tokenSub;

  SessionCubit({
    required AuthRepository repo,
    required TokenStore tokenStore,
    required SessionStore store,
    required OfflineAuthService offlineAuth,
    required DeviceSessionRepository deviceSessionRepo,
    required BiometricUnlock biometric,
    required Keystore keystore,
    DeviceRegistrar? deviceRegistrar,
    PushNotificationsService? push,
  })  : _repo = repo,
        _tokenStore = tokenStore,
        _store = store,
        _offlineAuth = offlineAuth,
        _deviceSessionRepo = deviceSessionRepo,
        _biometric = biometric,
        _keystore = keystore,
        _deviceRegistrar = deviceRegistrar,
        _push = push,
        super(const SessionUiState()) {
    _tokenSub = _tokenStore.changes.listen(_onTokenChanged);
  }

  void _onTokenChanged(AuthSession? session) {
    if (isClosed) return;
    if (session == null) {
      if (state.session != null) {
        emit(state.copyWith(clearSession: true));
      }
      return;
    }
    emit(state.copyWith(session: session));
    if (session.displayCard != null) {
      _pushDisplayCard(session.displayCard);
    }
  }

  @override
  Future<void> close() async {
    await _tokenSub?.cancel();
    return super.close();
  }

  DeviceRegistrar? get deviceRegistrar => _deviceRegistrar;
  OfflineAuthService get offlineAuth => _offlineAuth;
  BiometricUnlock get biometric => _biometric;
  AuthSession? get currentSession => state.session;

  DisplayCardInstaller? displayCardInstaller;
  UserIdInstaller? userIdInstaller;

  void _pushDisplayCard(DisplayCard? card) {
    final install = displayCardInstaller;
    if (card == null || install == null) return;
    install(card);
  }

  Future<void> _pushUserId(String userId) async {
    await _keystore.setUserId(userId);
    userIdInstaller?.call(userId);
  }

  Future<void> bootstrap() async {
    emit(state.copyWith(loading: true));
    CachedDeviceSession? cached;
    String? deviceId;
    try {
      try {
        cached = await _offlineAuth.readCachedSession();
        deviceId = await _keystore.deviceId();
      } catch (e, st) {
        developer.log(
          'session: cached-state read threw',
          error: e,
          stackTrace: st,
          name: 'session_cubit',
        );
      }
      emit(state.copyWith(deviceSession: cached));

      final hydrated = _tokenStore.current;
      if (hydrated == null || hydrated.refreshToken.isEmpty) {
        emit(state.copyWith(
          gate: await _evaluateOfflineGate(cached, deviceId),
        ));
        return;
      }

      try {
        final session = await _tokenStore
            .refresh()
            .timeout(const Duration(seconds: 6));
        UserProfile? profile;
        try {
          profile = await _repo
              .me(session.accessToken)
              .timeout(const Duration(seconds: 5));
        } catch (_) {}
        CachedDeviceSession? fresh = cached;
        try {
          fresh = await _offlineAuth.readCachedSession();
        } catch (e, st) {
          developer.log(
            'session: readCachedSession after refresh threw',
            error: e,
            stackTrace: st,
            name: 'session_cubit',
          );
        }
        emit(state.copyWith(
          session: session,
          profile: profile,
          deviceSession: fresh,
          gate: AuthGate.unlocked,
          unlockedThisRun: true,
        ));
        _pushDisplayCard(session.displayCard ?? profile?.displayCard);
        try {
          await _pushUserId(session.userId);
        } catch (e, st) {
          developer.log(
            'session: pushUserId failed',
            error: e,
            stackTrace: st,
            name: 'session_cubit',
          );
        }
        await _refreshDeviceReady();
        _kickDeviceRegistration(session.userId);
        _kickDeviceSession();
        _kickPushRegistration(session.accessToken);
      } on TimeoutException {
        developer.log(
          'session: refresh timed out',
          name: 'session_cubit',
        );
        emit(state.copyWith(
          gate: await _evaluateOfflineGate(cached, deviceId),
        ));
      } on TokenRevokedException catch (e, st) {
        developer.log(
          'session: refresh revoked',
          error: e,
          stackTrace: st,
          name: 'session_cubit',
        );
        await logout();
      } on TokenRefreshTransientException catch (e, st) {
        developer.log(
          'session: refresh failed transiently',
          error: e,
          stackTrace: st,
          name: 'session_cubit',
        );
        emit(state.copyWith(
          gate: await _evaluateOfflineGate(cached, deviceId),
        ));
      } catch (e, st) {
        developer.log(
          'session: bootstrap refresh threw',
          error: e,
          stackTrace: st,
          name: 'session_cubit',
        );
        emit(state.copyWith(
          gate: await _evaluateOfflineGate(cached, deviceId),
        ));
      }
    } catch (e, st) {
      developer.log(
        'session: bootstrap outer failure',
        error: e,
        stackTrace: st,
        name: 'session_cubit',
      );
      emit(state.copyWith(
        gate: cached == null ? AuthGate.needsOnlineLogin : AuthGate.expired,
      ));
    } finally {
      emit(state.copyWith(loading: false));
    }
  }

  Future<AuthGate> _evaluateOfflineGate(
    CachedDeviceSession? cached,
    String? deviceId,
  ) async {
    if (cached == null) return AuthGate.needsOnlineLogin;
    try {
      final eval =
          await _offlineAuth.evaluateGate(expectedDeviceId: deviceId);
      return _gateFromEval(eval);
    } catch (e, st) {
      developer.log(
        'session: offline gate evaluation threw',
        error: e,
        stackTrace: st,
        name: 'session_cubit',
      );
      return AuthGate.expired;
    }
  }

  Future<void> signup({
    required String phone,
    required String password,
    required String firstName,
    required String lastName,
    required String email,
  }) async {
    emit(state.copyWith(loading: true, clearError: true));
    try {
      final session = await _repo.signup(
        phone: phone,
        password: password,
        firstName: firstName,
        lastName: lastName,
        email: email,
      );
      await _tokenStore.save(session, lastPhone: phone);
      UserProfile? profile;
      try {
        profile = await _repo.me(session.accessToken);
      } catch (_) {}
      emit(state.copyWith(
        session: session,
        profile: profile,
        gate: AuthGate.unlocked,
        unlockedThisRun: true,
      ));
      _pushDisplayCard(session.displayCard ?? profile?.displayCard);
      await _pushUserId(session.userId);
      _kickDeviceRegistration(session.userId);
      _kickDeviceSession();
      _kickPushRegistration(session.accessToken);
    } catch (e, s) {
      developer.log(
        'session: signup failed',
        error: e,
        stackTrace: s,
        name: 'session_cubit',
      );
      emit(state.copyWith(error: _friendly(e)));
      rethrow;
    } finally {
      emit(state.copyWith(loading: false));
    }
  }

  Future<void> login({
    required String phone,
    required String password,
  }) async {
    emit(state.copyWith(loading: true, clearError: true));
    try {
      final session = await _repo.login(phone: phone, password: password);
      await _tokenStore.save(session, lastPhone: phone);
      UserProfile? profile;
      try {
        profile = await _repo.me(session.accessToken);
      } catch (_) {}
      emit(state.copyWith(
        session: session,
        profile: profile,
        gate: AuthGate.unlocked,
        unlockedThisRun: true,
      ));
      _pushDisplayCard(session.displayCard ?? profile?.displayCard);
      await _pushUserId(session.userId);
      unawaited(_keystore
          .saveBiometricLoginCredential(phone: phone, password: password)
          .catchError((_) {}));
      _kickDeviceRegistration(session.userId);
      _kickDeviceSession();
      _kickPushRegistration(session.accessToken);
    } catch (e) {
      emit(state.copyWith(error: _friendly(e)));
      rethrow;
    } finally {
      emit(state.copyWith(loading: false));
    }
  }

  Future<void> loginWithBiometric({
    String reason = 'Sign in to Offline Pay',
  }) async {
    final cred = await _keystore.readBiometricLoginCredential();
    if (cred == null) {
      throw StateError('biometric credential not available');
    }
    final ok = await _biometric.authenticate(reason: reason);
    if (!ok) {
      throw StateError('biometric authentication cancelled');
    }
    await login(phone: cred.phone, password: cred.password);
  }

  Future<bool> hasBiometricLoginCredential() =>
      _keystore.hasBiometricLoginCredential();

  Future<String?> lastPhone() => _store.lastPhone();

  Future<bool> biometricAvailable() => _biometric.isAvailable();

  Future<PinVerifyResult> unlockWithPin(String pin) async {
    final res = await _offlineAuth.verifyPin(pin);
    if (res.ok) {
      emit(state.copyWith(gate: AuthGate.unlocked, unlockedThisRun: true));
    }
    return res;
  }

  Future<bool> unlockWithBiometric({String reason = 'Unlock to use offline pay'}) async {
    final available = await _biometric.isAvailable();
    if (!available) return false;
    final ok = await _biometric.authenticate(reason: reason);
    if (ok) {
      emit(state.copyWith(gate: AuthGate.unlocked, unlockedThisRun: true));
    }
    return ok;
  }

  Future<void> reevaluateGate() async {
    final cached = await _offlineAuth.readCachedSession();
    final deviceId = await _keystore.deviceId();
    final eval = cached == null
        ? OfflineGateState.needsOnlineLogin
        : await _offlineAuth.evaluateGate(expectedDeviceId: deviceId);
    emit(state.copyWith(
      gate: _gateFromEval(eval),
      deviceSession: cached,
    ));
  }

  Future<void> refreshProfile() async {
    final session = state.session;
    if (session == null) return;
    try {
      final profile = await _repo.me(session.accessToken);
      if (isClosed) return;
      emit(state.copyWith(profile: profile));
      _pushDisplayCard(session.displayCard ?? profile.displayCard);
    } catch (_) {}
  }

  Future<void> requestEmailVerify() async {
    final session = state.session;
    if (session == null) {
      throw StateError('requestEmailVerify requires an active session');
    }
    await _repo.requestEmailVerify(session.accessToken);
  }

  Future<void> confirmEmailVerify(String code) async {
    final session = state.session;
    if (session == null) {
      throw StateError('confirmEmailVerify requires an active session');
    }
    await _repo.confirmEmailVerify(
      code: code,
      accessToken: session.accessToken,
    );
  }

  Future<void> requestForgotPassword(String email) async {
    await _repo.requestForgotPassword(email: email);
  }

  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    await _repo.resetPassword(
      email: email,
      code: code,
      newPassword: newPassword,
    );
  }

  // Single-flighted: a burst of 401s across screens all share one logout.
  Future<void> logout() {
    return _logoutFuture ??=
        _performLogout().whenComplete(() => _logoutFuture = null);
  }

  Future<void> _performLogout() async {
    final session = state.session ?? _sessionSnapshotFromTokenStore();
    emit(state.copyWith(loading: true));
    try {
      await _tokenStore.clear();
      if (session != null) {
        try {
          await _push?.unregister(accessToken: session.accessToken);
        } catch (_) {}
        try {
          await _repo.logout(session.refreshToken);
        } catch (_) {}
      }
      try {
        await _deviceRegistrar?.clear();
      } catch (_) {}
      await _offlineAuth.clearDeviceSession();
      await _offlineAuth.clearPin();
      emit(state.copyWith(
        clearSession: true,
        clearProfile: true,
        deviceReady: false,
        clearDeviceSession: true,
        gate: AuthGate.needsOnlineLogin,
        unlockedThisRun: false,
      ));
    } finally {
      emit(state.copyWith(loading: false));
    }
  }

  AuthSession? _sessionSnapshotFromTokenStore() => _tokenStore.current;

  AuthGate _gateFromEval(OfflineGateState s) {
    switch (s) {
      case OfflineGateState.needsOnlineLogin:
        return AuthGate.needsOnlineLogin;
      case OfflineGateState.locked:
        return AuthGate.locked;
      case OfflineGateState.unlocked:
        return AuthGate.unlocked;
      case OfflineGateState.expired:
        return AuthGate.expired;
    }
  }

  Future<void> _refreshDeviceReady() async {
    final r = _deviceRegistrar;
    if (r == null) {
      emit(state.copyWith(deviceReady: false));
      return;
    }
    try {
      final ready = await r.isRegistered();
      if (ready != state.deviceReady) {
        emit(state.copyWith(deviceReady: ready));
      }
    } catch (_) {}
  }

  void _kickDeviceRegistration(String userId) {
    final r = _deviceRegistrar;
    if (r == null) return;
    Future<void>(() async {
      try {
        await r.ensureRegistered(userId: userId);
        await _refreshDeviceReady();
        _kickDeviceSession();
      } catch (e, st) {
        developer.log(
          'session: device registration failed: $e',
          error: e,
          stackTrace: st,
          name: 'session_cubit',
        );
      }
    });
  }

  void _kickDeviceSession() {
    Future<void>(() => _mintDeviceSession());
  }

  Future<void> _mintDeviceSession() async {
    try {
      final session = state.session;
      if (session == null) return;
      final deviceId = await _keystore.deviceId();
      if (deviceId == null || deviceId.isEmpty) {
        await _safeMarkDeviceSessionMintPending();
        return;
      }
      final res = await _deviceSessionRepo.issue(
        accessToken: session.accessToken,
        deviceId: deviceId,
      );
      await _offlineAuth.cacheDeviceSession(
        token: res.token,
        keyId: res.keyId,
        serverPublicKey: res.serverPublicKey,
        expiresAt: res.expiresAt,
        scope: res.scope,
      );
      await _safeClearDeviceSessionMintPending();
      if (isClosed) return;
      emit(state.copyWith(
        deviceSession: CachedDeviceSession(
          token: res.token,
          keyId: res.keyId,
          serverPublicKey: res.serverPublicKey,
          expiresAt: res.expiresAt,
          scope: res.scope,
        ),
      ));
    } catch (e, st) {
      developer.log(
        'session: device session mint failed: $e',
        error: e,
        stackTrace: st,
        name: 'session_cubit',
      );
      await _safeMarkDeviceSessionMintPending();
    }
  }

  Future<void> retryDeviceSessionMintIfPending() async {
    bool pending;
    try {
      pending = await _offlineAuth.isDeviceSessionMintPending();
    } catch (_) {
      return;
    }
    if (!pending) return;
    if (state.session == null) return;
    await _mintDeviceSession();
  }

  Future<void> _safeMarkDeviceSessionMintPending() async {
    try {
      await _offlineAuth.markDeviceSessionMintPending();
    } catch (_) {}
  }

  Future<void> _safeClearDeviceSessionMintPending() async {
    try {
      await _offlineAuth.clearDeviceSessionMintPending();
    } catch (_) {}
  }

  void _kickPushRegistration(String accessToken) {
    final p = _push;
    if (p == null) return;
    Future<void>(() async {
      try {
        await p.registerForUser(accessToken: accessToken);
      } catch (e, st) {
        developer.log(
          'session: push registration failed: $e',
          error: e,
          stackTrace: st,
          name: 'session_cubit',
        );
      }
    });
  }

  String _friendly(Object e) {
    final msg = e.toString();
    return msg.length > 240 ? msg.substring(0, 240) : msg;
  }
}
