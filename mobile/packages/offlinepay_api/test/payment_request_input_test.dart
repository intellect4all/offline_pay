import 'package:test/test.dart';
import 'package:offlinepay_api/offlinepay_api.dart';

// tests for PaymentRequestInput
void main() {
  final instance = PaymentRequestInputBuilder();
  // TODO add properties to the builder and call build()

  group(PaymentRequestInput, () {
    // String receiverId
    test('to test the property `receiverId`', () async {
      // TODO
    });

    // DisplayCardInput receiverDisplayCard
    test('to test the property `receiverDisplayCard`', () async {
      // TODO
    });

    // 0 means \"unbound\" — the payer picks the amount.
    // int amountKobo
    test('to test the property `amountKobo`', () async {
      // TODO
    });

    // 16 random bytes; single-use per receiver.
    // String sessionNonce
    test('to test the property `sessionNonce`', () async {
      // TODO
    });

    // DateTime issuedAt
    test('to test the property `issuedAt`', () async {
      // TODO
    });

    // DateTime expiresAt
    test('to test the property `expiresAt`', () async {
      // TODO
    });

    // String receiverDevicePubkey
    test('to test the property `receiverDevicePubkey`', () async {
      // TODO
    });

    // String receiverSignature
    test('to test the property `receiverSignature`', () async {
      // TODO
    });

  });
}
