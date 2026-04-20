import 'package:test/test.dart';
import 'package:offlinepay_api/offlinepay_api.dart';

// tests for DeviceSessionRequest
void main() {
  final instance = DeviceSessionRequestBuilder();
  // TODO add properties to the builder and call build()

  group(DeviceSessionRequest, () {
    // Caller's registered device identifier (returned by `POST /v1/devices`). Must be active and owned by the authenticated user, otherwise the server returns 403. 
    // String deviceId
    test('to test the property `deviceId`', () async {
      // TODO
    });

    // Capability scope this token grants on-device. Defaults to `offline_pay`. Reserved for future tiers; unknown scopes 400. 
    // String scope
    test('to test the property `scope`', () async {
      // TODO
    });

  });
}
