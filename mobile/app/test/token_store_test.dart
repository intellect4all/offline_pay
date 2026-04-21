import 'dart:async';

import 'package:dio/dio.dart';
// ignore: depend_on_referenced_packages
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offlinepay_app/src/core/auth/token_store.dart';
import 'package:offlinepay_app/src/repositories/auth_repository.dart';
import 'package:offlinepay_app/src/services/session_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final storage = _InMemorySecureStorage();
  FlutterSecureStoragePlatform.instance = storage;

  setUp(() async {
    storage._m.clear();
  });

  group('TokenStore — single-flight refresh', () {
    test('10 concurrent refresh() calls invoke the refresher exactly once',
        () async {
      final persistent = SessionStore();
      await persistent.save(_session('s0', refresh: 'rt-old'));
      var calls = 0;
      final inflight = Completer<AuthSession>();
      final store = TokenStore(
        persistent: persistent,
        refresher: (rt) {
          calls++;
          return inflight.future;
        },
      );
      await store.hydrate();

      final futures = List.generate(10, (_) => store.refresh());
      inflight.complete(_session('s1', refresh: 'rt-new'));
      final results = await Future.wait(futures);

      expect(calls, 1);
      expect(results.every((s) => s.accessToken == 's1'), isTrue);
    });

    test('a second refresh() AFTER the first completes does call the refresher',
        () async {
      final persistent = SessionStore();
      await persistent.save(_session('s0', refresh: 'rt-old'));
      var calls = 0;
      final store = TokenStore(
        persistent: persistent,
        refresher: (rt) async {
          calls++;
          return _session('s$calls', refresh: 'rt$calls');
        },
      );
      await store.hydrate();

      await store.refresh();
      await store.refresh();
      expect(calls, 2);
    });
  });

  group('TokenStore — revoked refresh', () {
    test('401 from refresher throws TokenRevokedException + fires onSessionDead',
        () async {
      final persistent = SessionStore();
      await persistent.save(_session('s0', refresh: 'rt-bad'));
      var deadFired = 0;
      final store = TokenStore(
        persistent: persistent,
        refresher: (rt) async {
          throw DioException(
            requestOptions: RequestOptions(path: '/v1/auth/refresh'),
            response: Response(
              requestOptions: RequestOptions(path: '/v1/auth/refresh'),
              statusCode: 401,
            ),
          );
        },
      );
      store.onSessionDead = () => deadFired++;
      await store.hydrate();

      await expectLater(store.refresh(), throwsA(isA<TokenRevokedException>()));
      await Future<void>.delayed(Duration.zero);
      expect(deadFired, 1);
    });

    test('403 from refresher also maps to TokenRevokedException', () async {
      final persistent = SessionStore();
      await persistent.save(_session('s0', refresh: 'rt-bad'));
      final store = TokenStore(
        persistent: persistent,
        refresher: (rt) async {
          throw DioException(
            requestOptions: RequestOptions(path: '/v1/auth/refresh'),
            response: Response(
              requestOptions: RequestOptions(path: '/v1/auth/refresh'),
              statusCode: 403,
            ),
          );
        },
      );
      await store.hydrate();
      await expectLater(store.refresh(), throwsA(isA<TokenRevokedException>()));
    });

    test('no refresh token → TokenRevokedException + onSessionDead', () async {
      final persistent = SessionStore();
      var deadFired = 0;
      final store = TokenStore(
        persistent: persistent,
        refresher: (_) async => fail('refresher must not run'),
      );
      store.onSessionDead = () => deadFired++;

      await expectLater(store.refresh(), throwsA(isA<TokenRevokedException>()));
      await Future<void>.delayed(Duration.zero);
      expect(deadFired, 1);
    });
  });

  group('TokenStore — transient failures', () {
    test('500 throws TokenRefreshTransientException, does NOT fire onSessionDead',
        () async {
      final persistent = SessionStore();
      await persistent.save(_session('s0', refresh: 'rt'));
      var deadFired = 0;
      final store = TokenStore(
        persistent: persistent,
        refresher: (rt) async {
          throw DioException(
            requestOptions: RequestOptions(path: '/v1/auth/refresh'),
            response: Response(
              requestOptions: RequestOptions(path: '/v1/auth/refresh'),
              statusCode: 500,
            ),
          );
        },
      );
      store.onSessionDead = () => deadFired++;
      await store.hydrate();

      await expectLater(
        store.refresh(),
        throwsA(isA<TokenRefreshTransientException>()),
      );
      await Future<void>.delayed(Duration.zero);
      expect(deadFired, 0);
    });

    test('connection error throws TokenRefreshTransientException', () async {
      final persistent = SessionStore();
      await persistent.save(_session('s0', refresh: 'rt'));
      final store = TokenStore(
        persistent: persistent,
        refresher: (rt) async {
          throw DioException(
            requestOptions: RequestOptions(path: '/v1/auth/refresh'),
            type: DioExceptionType.connectionError,
          );
        },
      );
      await store.hydrate();
      await expectLater(
        store.refresh(),
        throwsA(isA<TokenRefreshTransientException>()),
      );
    });
  });

  group('TokenStore — atomic save', () {
    test('save() persists to disk before returning, emits on stream', () async {
      final persistent = SessionStore();
      final store = TokenStore(
        persistent: persistent,
        refresher: (_) async => fail('unused'),
      );
      final emissions = <String?>[];
      final sub = store.changes.listen((s) => emissions.add(s?.refreshToken));

      await store.save(_session('s1', refresh: 'rt-first'));
      expect((await persistent.load())?.refreshToken, 'rt-first');
      expect(store.current?.refreshToken, 'rt-first');

      await store.save(_session('s2', refresh: 'rt-second'));
      expect((await persistent.load())?.refreshToken, 'rt-second');
      expect(store.current?.refreshToken, 'rt-second');

      await Future<void>.delayed(Duration.zero);
      expect(emissions, ['rt-first', 'rt-second']);
      await sub.cancel();
    });
  });

  group('TokenStore — hydrate / clear', () {
    test('hydrate loads persisted session into current', () async {
      final persistent = SessionStore();
      await persistent.save(_session('s-persisted', refresh: 'rt-persisted'));
      final store = TokenStore(
        persistent: persistent,
        refresher: (_) async => fail('unused'),
      );
      final had = await store.hydrate();
      expect(had, isTrue);
      expect(store.current?.refreshToken, 'rt-persisted');
      expect(store.current?.accessToken, '');
    });

    test('hydrate returns false when nothing is persisted', () async {
      final store = TokenStore(
        persistent: SessionStore(),
        refresher: (_) async => fail('unused'),
      );
      final had = await store.hydrate();
      expect(had, isFalse);
      expect(store.current, isNull);
    });

    test('clear wipes memory + disk + emits null', () async {
      final persistent = SessionStore();
      final store = TokenStore(
        persistent: persistent,
        refresher: (_) async => fail('unused'),
      );
      await store.save(_session('s', refresh: 'rt'));
      expect(store.current, isNotNull);

      final emissions = <AuthSession?>[];
      final sub = store.changes.listen(emissions.add);

      await store.clear();
      await Future<void>.delayed(Duration.zero);

      expect(store.current, isNull);
      expect(await persistent.load(), isNull);
      expect(emissions, [null]);
      await sub.cancel();
    });
  });
}

AuthSession _session(String access, {required String refresh}) {
  final now = DateTime.now().toUtc();
  return AuthSession(
    userId: 'u-1',
    accountNumber: '0000000001',
    accessToken: access,
    refreshToken: refresh,
    accessExpiresAt: now.add(const Duration(minutes: 15)),
    refreshExpiresAt: now.add(const Duration(days: 30)),
    displayCard: null,
  );
}

class _InMemorySecureStorage extends FlutterSecureStoragePlatform {
  final Map<String, String> _m = {};

  @override
  Future<bool> containsKey({
    required String key,
    required Map<String, String> options,
  }) async =>
      _m.containsKey(key);

  @override
  Future<void> delete({
    required String key,
    required Map<String, String> options,
  }) async {
    _m.remove(key);
  }

  @override
  Future<void> deleteAll({required Map<String, String> options}) async {
    _m.clear();
  }

  @override
  Future<String?> read({
    required String key,
    required Map<String, String> options,
  }) async =>
      _m[key];

  @override
  Future<Map<String, String>> readAll({
    required Map<String, String> options,
  }) async =>
      Map.of(_m);

  @override
  Future<void> write({
    required String key,
    required String value,
    required Map<String, String> options,
  }) async {
    _m[key] = value;
  }
}
