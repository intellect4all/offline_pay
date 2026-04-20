import 'package:test/test.dart';
import 'package:offlinepay_api/offlinepay_api.dart';


/// tests for DefaultApi
void main() {
  final instance = OfflinepayApi().getDefaultApi();

  group(DefaultApi, () {
    // Liveness probe.
    //
    //Future<HealthResponse> getHealth() async
    test('test getHealth', () async {
      // TODO
    });

  });
}
