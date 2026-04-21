import 'dart:async';
import 'dart:developer' as developer;

import 'package:dio/dio.dart';

import '../../repositories/auth_repository.dart';
import '../auth/token_store.dart';

class AuthRefreshInterceptor extends Interceptor {
  final Dio _dio;
  final TokenStore _tokenStore;

  AuthRefreshInterceptor(this._dio, this._tokenStore);

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (!_isExpiredTokenError(err)) {
      handler.next(err);
      return;
    }
    final path = err.requestOptions.path;
    if (_isAuthEntrypoint(path)) {
      handler.next(err);
      return;
    }

    final accessAtFailure = _tokenStore.current?.accessToken ?? '';

    final AuthSession refreshed;
    try {
      refreshed = await _tokenStore.refresh();
    } on TokenRevokedException catch (e) {
      handler.next(err);
      return;
    } on TokenRefreshTransientException catch (e) {
      handler.next(err);
      return;
    } catch (e) {
      handler.next(err);
      return;
    }

    if (refreshed.accessToken.isEmpty ||
        refreshed.accessToken == accessAtFailure) {
      handler.next(err);
      return;
    }

    try {
      final retried = await _dio.fetch<dynamic>(
        err.requestOptions.copyWith(
          headers: <String, dynamic>{
            ...err.requestOptions.headers,
            'Authorization': 'Bearer ${refreshed.accessToken}',
          },
        ),
      );
      handler.resolve(retried);
    } on DioException catch (retryErr) {
      handler.next(retryErr);
    }
  }

  bool _isExpiredTokenError(DioException err) {
    if (err.response?.statusCode != 401) return false;
    final body = err.response?.data;
    if (body is Map) {
      final code = body['code'];
      if (code is String && code == 'invalid_credentials') return false;
    }
    return true;
  }

  bool _isAuthEntrypoint(String path) {
    return path.contains('/v1/auth/refresh') ||
        path.contains('/v1/auth/login') ||
        path.contains('/v1/auth/signup') ||
        path.contains('/v1/auth/logout');
  }
}
