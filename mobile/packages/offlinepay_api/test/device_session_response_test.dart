import 'package:test/test.dart';
import 'package:offlinepay_api/offlinepay_api.dart';

// tests for DeviceSessionResponse
void main() {
  final instance = DeviceSessionResponseBuilder();
  // TODO add properties to the builder and call build()

  group(DeviceSessionResponse, () {
    // Compact base64url-encoded `header.claims.signature` blob signed with Ed25519. The device verifies it locally against `server_public_key`. 
    // String token
    test('to test the property `token`', () async {
      // TODO
    });

    // 32-byte Ed25519 public key the device should cache.
    // String serverPublicKey
    test('to test the property `serverPublicKey`', () async {
      // TODO
    });

    // Identifier of the signing key (for rotation).
    // String keyId
    test('to test the property `keyId`', () async {
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

    // String scope
    test('to test the property `scope`', () async {
      // TODO
    });

  });
}
