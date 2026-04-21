import 'dart:convert' show base64;
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:offlinepay_api/offlinepay_api.dart';
import 'package:offlinepay_core/offlinepay_core.dart' as core;


class AuthSession {
  final String userId;
  final String accountNumber;
  final String accessToken;
  final String refreshToken;
  final DateTime accessExpiresAt;
  final DateTime refreshExpiresAt;
  final core.DisplayCard? displayCard;

  const AuthSession({
    required this.userId,
    required this.accountNumber,
    required this.accessToken,
    required this.refreshToken,
    required this.accessExpiresAt,
    required this.refreshExpiresAt,
    this.displayCard,
  });

  factory AuthSession.fromTokens(AuthTokens t) => AuthSession(
        userId: t.userId,
        accountNumber: t.accountNumber,
        accessToken: t.accessToken,
        refreshToken: t.refreshToken,
        accessExpiresAt: t.accessExpiresAt,
        refreshExpiresAt: t.refreshExpiresAt,
        displayCard: _cardFromDto(t.displayCard),
      );
}

Uint8List _decodeBase64(String s) => Uint8List.fromList(base64.decode(s));

core.DisplayCard? _cardFromDto(DisplayCardInput? c) {
  if (c == null) return null;
  return core.DisplayCard(
    payload: core.DisplayCardPayload(
      userId: c.userId,
      displayName: c.displayName,
      accountNumber: c.accountNumber,
      issuedAt: c.issuedAt,
      bankKeyId: c.bankKeyId,
    ),
    serverSignature: _decodeBase64(c.serverSignature),
  );
}

class UserSession {
  final String id;
  final String userAgent;
  final String ip;
  final String? deviceId;
  final DateTime createdAt;
  final DateTime expiresAt;
  final bool isCurrent;

  const UserSession({
    required this.id,
    required this.userAgent,
    required this.ip,
    required this.deviceId,
    required this.createdAt,
    required this.expiresAt,
    required this.isCurrent,
  });

  factory UserSession.fromDto(Session s) => UserSession(
        id: s.id,
        userAgent: s.userAgent,
        ip: s.ip,
        deviceId: s.deviceId,
        createdAt: s.createdAt,
        expiresAt: s.expiresAt,
        isCurrent: s.isCurrent,
      );
}

class UserProfile {
  final String userId;
  final String phone;
  final String accountNumber;
  final String kycTier;
  final core.DisplayCard? displayCard;

  const UserProfile({
    required this.userId,
    required this.phone,
    required this.accountNumber,
    required this.kycTier,
    this.displayCard,
  });

  factory UserProfile.fromMe(Me m) => UserProfile(
        userId: m.userId,
        phone: m.phone,
        accountNumber: m.accountNumber,
        kycTier: m.kycTier,
        displayCard: _cardFromDto(m.displayCard),
      );
}

class AuthRepository {
  final OfflinepayApi _api;

  AuthRepository({required OfflinepayApi api}) : _api = api;

  DefaultApi get _default => _api.getDefaultApi();

  Map<String, dynamic> _authHeaders(String accessToken) => <String, dynamic>{
        'Authorization': 'Bearer $accessToken',
      };

  Future<AuthSession> signup({
    required String phone,
    required String password,
    required String firstName,
    required String lastName,
    required String email,
  }) async {
    final body = SignupBody((b) => b
      ..phone = phone
      ..password = password
      ..firstName = firstName
      ..lastName = lastName
      ..email = email);
    final resp = await _default.postV1AuthSignup(signupBody: body);
    final data = resp.data;
    if (data == null) {
      throw StateError('auth: signup returned empty body');
    }
    return AuthSession.fromTokens(data);
  }

  Future<AuthSession> login({
    required String phone,
    required String password,
  }) async {
    final body = LoginBody((b) => b
      ..phone = phone
      ..password = password);
    final resp = await _default.postV1AuthLogin(loginBody: body);
    final data = resp.data;
    if (data == null) {
      throw StateError('auth: login returned empty body');
    }
    return AuthSession.fromTokens(data);
  }

  Future<void> requestEmailVerify(String accessToken) async {
    await _default.postV1AuthEmailVerifyRequest(
      headers: _authHeaders(accessToken),
    );
  }

  Future<void> confirmEmailVerify({
    required String code,
    required String accessToken,
  }) async {
    final body = EmailVerifyConfirmBody((b) => b..code = code);
    await _default.postV1AuthEmailVerifyConfirm(
      emailVerifyConfirmBody: body,
      headers: _authHeaders(accessToken),
    );
  }

  Future<void> requestForgotPassword({required String email}) async {
    final body = ForgotPasswordRequestBody((b) => b..email = email);
    await _default.postV1AuthForgotPasswordRequest(
      forgotPasswordRequestBody: body,
    );
  }

  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    final body = ForgotPasswordResetBody((b) => b
      ..email = email
      ..code = code
      ..newPassword = newPassword);
    await _default.postV1AuthForgotPasswordReset(
      forgotPasswordResetBody: body,
    );
  }

  Future<AuthSession> refresh(String refreshToken) async {
    final body = RefreshBody((b) => b..refreshToken = refreshToken);
    final resp = await _default.postV1AuthRefresh(refreshBody: body);
    final data = resp.data;
    if (data == null) {
      throw StateError('auth: refresh returned empty body');
    }
    return AuthSession.fromTokens(data);
  }

  Future<void> logout(String refreshToken) async {
    final body = LogoutBody((b) => b..refreshToken = refreshToken);
    await _default.postV1AuthLogout(logoutBody: body);
  }

  Future<UserProfile> me(String accessToken) async {
    final resp = await _default.getV1Me(headers: _authHeaders(accessToken));
    final data = resp.data;
    if (data == null) {
      throw StateError('auth: /me returned empty body');
    }
    return UserProfile.fromMe(data);
  }

  Future<core.DisplayCard> displayCard(String accessToken) async {
    final resp = await _default.getV1IdentityDisplayCard(
      headers: _authHeaders(accessToken),
    );
    final data = resp.data;
    if (data == null) {
      throw StateError('auth: /identity/display-card returned empty body');
    }
    final card = _cardFromDto(data);
    if (card == null) {
      throw StateError('auth: /identity/display-card returned invalid body');
    }
    return card;
  }

  Future<void> setPin({
    required String pin,
    required String accessToken,
  }) async {
    try {
      final body = SetPinBody((b) => b..pin = pin);
      await _default.postV1AuthPin(
        setPinBody: body,
        headers: _authHeaders(accessToken),
      );
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 400) {
        throw const PinRejected('invalid_pin', 'PIN must be 4 or 6 digits');
      }
      String? code;
      String message = e.message ?? 'set pin failed';
      final respData = e.response?.data;
      if (respData is Map) {
        final c = respData['code'];
        final m = respData['message'];
        if (c is String) code = c;
        if (m is String) message = m;
      }
      throw PinRejected(code, message);
    }
  }

  Future<List<UserSession>> listSessions(String accessToken) async {
    final resp = await _default.getV1AuthSessions(
      headers: _authHeaders(accessToken),
    );
    final data = resp.data;
    if (data == null) {
      return const <UserSession>[];
    }
    return data.items.map(UserSession.fromDto).toList(growable: false);
  }

  Future<void> revokeSession(String sessionId, String accessToken) async {
    await _default.postV1AuthSessionsIdRevoke(
      id: sessionId,
      headers: _authHeaders(accessToken),
    );
  }

  Future<int> revokeAllOtherSessions(String accessToken) async {
    final resp = await _default.postV1AuthSessionsRevokeAllOthers(
      headers: _authHeaders(accessToken),
    );
    return resp.data?.revoked ?? 0;
  }
}

class PinRejected implements Exception {
  final String? code;
  final String message;
  const PinRejected(this.code, this.message);
  @override
  String toString() => 'PinRejected(${code ?? 'unknown'}: $message)';
}

int? dioStatus(Object e) {
  if (e is DioException) return e.response?.statusCode;
  return null;
}
