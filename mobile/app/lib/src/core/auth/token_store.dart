import 'dart:async';

import 'package:dio/dio.dart';

import '../../repositories/auth_repository.dart';
import '../../services/session_store.dart';

class TokenRevokedException implements Exception {
  final String message;
  const TokenRevokedException(this.message);
  @override
  String toString() => 'TokenRevokedException: $message';
}

class TokenRefreshTransientException implements Exception {
  final Object cause;
  const TokenRefreshTransientException(this.cause);
  @override
  String toString() => 'TokenRefreshTransientException: $cause';
}

class TokenStore {
  final SessionStore _persistent;
  final Future<AuthSession> Function(String refreshToken) _refresher;
  final StreamController<AuthSession?> _changes =
      StreamController<AuthSession?>.broadcast();

  AuthSession? _current;
  Completer<AuthSession>? _inflight;

  void Function()? onSessionDead;

  TokenStore({
    required SessionStore persistent,
    required Future<AuthSession> Function(String refreshToken) refresher,
  })  : _persistent = persistent,
        _refresher = refresher;

  AuthSession? get current => _current;

  Stream<AuthSession?> get changes => _changes.stream;

  Future<bool> hydrate() async {
    final stored = await _persistent.load();
    if (stored == null) {
      _current = null;
      return false;
    }
    final epoch = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    _current = AuthSession(
      userId: stored.userId,
      accountNumber: stored.accountNumber,
      accessToken: '',
      refreshToken: stored.refreshToken,
      accessExpiresAt: epoch,
      refreshExpiresAt: epoch,
      displayCard: null,
    );
    return true;
  }

  Future<AuthSession> refresh() {
    final existing = _inflight;
    if (existing != null) return existing.future;
    final completer = Completer<AuthSession>();
    _inflight = completer;
    unawaited(_performRefresh(completer));
    return completer.future;
  }

  Future<void> _performRefresh(Completer<AuthSession> completer) async {
    try {
      final refreshToken = _current?.refreshToken;
      if (refreshToken == null || refreshToken.isEmpty) {
        const revoked = TokenRevokedException('no refresh token available');
        _signalDead();
        completer.completeError(revoked, StackTrace.current);
        return;
      }
      final AuthSession session;
      try {
        session = await _refresher(refreshToken);
      } on DioException catch (e) {
        final status = e.response?.statusCode;
        if (status == 401 || status == 403) {
          final revoked = TokenRevokedException('refresh rejected: $status');
          _signalDead();
          completer.completeError(revoked, StackTrace.current);
          return;
        }
        completer.completeError(
          TokenRefreshTransientException(e),
          StackTrace.current,
        );
        return;
      } catch (e, st) {
        completer.completeError(TokenRefreshTransientException(e), st);
        return;
      }
      await _applySession(session);
      completer.complete(session);
    } finally {
      _inflight = null;
    }
  }

  Future<void> save(AuthSession session, {String? lastPhone}) async {
    await _applySession(session, lastPhone: lastPhone);
  }

  Future<void> _applySession(AuthSession session, {String? lastPhone}) async {
    await _persistent.save(session, lastPhone: lastPhone);
    _current = session;
    if (!_changes.isClosed) _changes.add(session);
  }

  Future<void> clear() async {
    await _persistent.clear();
    _current = null;
    if (!_changes.isClosed) _changes.add(null);
  }

  void _signalDead() {
    final hook = onSessionDead;
    if (hook != null) {
      scheduleMicrotask(hook);
    }
  }

  Future<void> close() async {
    await _changes.close();
  }
}
