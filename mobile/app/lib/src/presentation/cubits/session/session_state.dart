import 'package:equatable/equatable.dart';

import '../../../repositories/auth_repository.dart';
import '../../../services/offline_auth.dart';

enum AuthGate {
  needsOnlineLogin,

  locked,

  unlocked,

  expired,
}

class SessionUiState extends Equatable {
  final AuthSession? session;
  final UserProfile? profile;
  final bool loading;
  final String? error;
  final bool deviceReady;

  final AuthGate gate;

  final CachedDeviceSession? deviceSession;

  final bool unlockedThisRun;

  const SessionUiState({
    this.session,
    this.profile,
    this.loading = false,
    this.error,
    this.deviceReady = false,
    this.gate = AuthGate.needsOnlineLogin,
    this.deviceSession,
    this.unlockedThisRun = false,
  });

  bool get signedIn => session != null;

  bool get offlineReady => gate == AuthGate.unlocked;

  SessionUiState copyWith({
    AuthSession? session,
    UserProfile? profile,
    bool? loading,
    String? error,
    bool? deviceReady,
    AuthGate? gate,
    CachedDeviceSession? deviceSession,
    bool? unlockedThisRun,
    bool clearSession = false,
    bool clearProfile = false,
    bool clearError = false,
    bool clearDeviceSession = false,
  }) {
    return SessionUiState(
      session: clearSession ? null : (session ?? this.session),
      profile: clearProfile ? null : (profile ?? this.profile),
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
      deviceReady: deviceReady ?? this.deviceReady,
      gate: gate ?? this.gate,
      deviceSession: clearDeviceSession ? null : (deviceSession ?? this.deviceSession),
      unlockedThisRun: unlockedThisRun ?? this.unlockedThisRun,
    );
  }

  @override
  List<Object?> get props => [
        session,
        profile,
        loading,
        error,
        deviceReady,
        gate,
        deviceSession,
        unlockedThisRun,
      ];
}
