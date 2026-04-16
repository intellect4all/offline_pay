package com.intellect.offlinepay.offlinepay_app

import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine

/// `FlutterFragmentActivity` (not `FlutterActivity`) is required by the
/// `local_auth` plugin so the biometric prompt can attach to a
/// FragmentManager. Everything else about the Flutter engine config is
/// identical to the default activity.
class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // H-01 NFC plugins: HCE payload cache + reader-mode merchant.
        flutterEngine.plugins.add(NfcHceChannel())
        flutterEngine.plugins.add(NfcReaderChannel())
    }
}
