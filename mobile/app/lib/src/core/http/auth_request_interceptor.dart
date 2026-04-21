import 'package:dio/dio.dart';

import '../auth/token_store.dart';

class AuthRequestInterceptor extends Interceptor {
  final TokenStore _tokenStore;

  AuthRequestInterceptor(this._tokenStore);

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) {
    if (!_isAuthEntrypoint(options.path)) {
      final access = _tokenStore.current?.accessToken;
      if (access != null && access.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $access';
      }
    }
    handler.next(options);
  }

  bool _isAuthEntrypoint(String path) {
    return path.contains('/v1/auth/refresh') ||
        path.contains('/v1/auth/login') ||
        path.contains('/v1/auth/signup') ||
        path.contains('/v1/auth/forgot-password') ||
        path.contains('/v1/auth/email-verify');
  }
}
