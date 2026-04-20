import 'package:test/test.dart';
import 'package:offlinepay_api/offlinepay_api.dart';

// tests for RecoverOfflineCeilingResponse
void main() {
  final instance = RecoverOfflineCeilingResponseBuilder();
  // TODO add properties to the builder and call build()

  group(RecoverOfflineCeilingResponse, () {
    // String ceilingId
    test('to test the property `ceilingId`', () async {
      // TODO
    });

    // Amount held in quarantine. Funds are released to the main wallet by the expiry sweep once `release_after` passes. Late-arriving offline claims against this ceiling will settle first and reduce the released amount accordingly. 
    // int quarantinedKobo
    test('to test the property `quarantinedKobo`', () async {
      // TODO
    });

    // Wall-clock time after which the expiry sweep returns the remaining lien balance to the main wallet. Equals the ceiling's original expiry plus the auto-settle timeout plus a 30-minute grace. 
    // DateTime releaseAfter
    test('to test the property `releaseAfter`', () async {
      // TODO
    });

  });
}
