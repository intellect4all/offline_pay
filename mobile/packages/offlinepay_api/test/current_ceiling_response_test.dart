import 'package:test/test.dart';
import 'package:offlinepay_api/offlinepay_api.dart';

// tests for CurrentCeilingResponse
void main() {
  final instance = CurrentCeilingResponseBuilder();
  // TODO add properties to the builder and call build()

  group(CurrentCeilingResponse, () {
    // False when the payer has no offline wallet (no ACTIVE or RECOVERY_PENDING ceiling). All other fields are omitted or zero in that case. 
    // bool present
    test('to test the property `present`', () async {
      // TODO
    });

    // String ceilingId
    test('to test the property `ceilingId`', () async {
      // TODO
    });

    // ACTIVE or RECOVERY_PENDING.
    // String status
    test('to test the property `status`', () async {
      // TODO
    });

    // int ceilingKobo
    test('to test the property `ceilingKobo`', () async {
      // TODO
    });

    // Total settled across every payment token issued against this ceiling. `ceiling_kobo - settled_kobo = remaining_kobo`. 
    // int settledKobo
    test('to test the property `settledKobo`', () async {
      // TODO
    });

    // The amount the lien would return to main if the ceiling released right now. Used for the offline-wallet card and to cross-check against the lien account balance. 
    // int remainingKobo
    test('to test the property `remainingKobo`', () async {
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

    // Populated only when status is RECOVERY_PENDING. After this instant the expiry sweep releases the remaining lien back to main. 
    // DateTime releaseAfter
    test('to test the property `releaseAfter`', () async {
      // TODO
    });

  });
}
