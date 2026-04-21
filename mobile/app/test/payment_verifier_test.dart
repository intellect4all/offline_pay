import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:offlinepay_app/src/services/local_queue.dart';
import 'package:offlinepay_app/src/services/payment_verifier.dart';
import 'package:offlinepay_app/src/services/keystore.dart';

void main() {
  group('PaymentVerifier', () {
    test('empty frame list throws reassemble VerifyException', () async {
      final v = PaymentVerifier(
        keystore: Keystore(),
        queue: _StubQueue(),
        realmKeyResolver: (_) => null,
      );
      try {
        await v.verifyAndEnqueue(const <Uint8List>[], selfUserId: 'self');
        fail('expected VerifyException');
      } on VerifyException catch (e) {
        expect(e.reason, VerifyFailure.reassemble);
      }
    });

    test('malformed frame bytes throws reassemble VerifyException',
        () async {
      final v = PaymentVerifier(
        keystore: Keystore(),
        queue: _StubQueue(),
        realmKeyResolver: (_) => null,
      );
      try {
        await v.verifyAndEnqueue(
          [Uint8List.fromList([0xFF, 0xFF, 0xFF])],
          selfUserId: 'self',
        );
        fail('expected VerifyException');
      } on VerifyException catch (e) {
        expect(e.reason, VerifyFailure.reassemble);
      }
    });
  });
}

class _StubQueue implements LocalQueue {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
