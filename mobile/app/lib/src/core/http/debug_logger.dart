import 'dart:developer' as developer;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:offlinepay_api/offlinepay_api.dart';

import '../auth/token_store.dart';
import 'auth_refresh_interceptor.dart';
import 'auth_request_interceptor.dart';

OfflinepayApi buildDebugApi(Uri baseUrl, TokenStore tokenStore) {
  final api = OfflinepayApi(basePathOverride: baseUrl.toString());
  api.dio.interceptors.add(AuthRequestInterceptor(tokenStore));
  api.dio.interceptors.add(AuthRefreshInterceptor(api.dio, tokenStore));
  if (kDebugMode) {
    api.dio.interceptors.add(_DebugInterceptor());
  }
  return api;
}


class _DebugInterceptor extends Interceptor {
  static const _maxBodyChars = 2000;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final headers = _redactHeaders(options.headers);
    developer.log(
      '→ ${options.method} ${options.uri}\n'
      '  headers: $headers'
      '${options.data == null ? '' : '\n  body: ${_truncate(options.data)}'}',
      name: 'http',
    );
    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    final req = response.requestOptions;
    developer.log(
      '← ${response.statusCode} ${req.method} ${req.uri}'
      '${response.data == null ? '' : '\n  body: ${_truncate(response.data)}'}',
      name: 'http',
    );
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final req = err.requestOptions;
    final status = err.response?.statusCode;
    final resp = err.response;
    developer.log(
      '✗ ${status ?? '-'} ${req.method} ${req.uri}\n'
      '  type: ${err.type}\n'
      '  message: ${err.message}\n'
      '  resp-headers: ${resp?.headers.map ?? '-'}\n'
      '  body-type: ${resp?.data?.runtimeType ?? 'null'}\n'
      '  body: ${resp == null ? '-' : _truncate(resp.data)}',
      name: 'http',
      level: 1000,
    );
    handler.next(err);
  }

  Map<String, dynamic> _redactHeaders(Map<String, dynamic> headers) {
    if (!headers.containsKey('Authorization')) return headers;
    final copy = Map<String, dynamic>.from(headers);
    copy['Authorization'] = '<redacted>';
    return copy;
  }

  String _truncate(Object? data) {
    final s = data?.toString() ?? '';
    return s.length <= _maxBodyChars
        ? s
        : '${s.substring(0, _maxBodyChars)}… (+${s.length - _maxBodyChars} more)';
  }
}
