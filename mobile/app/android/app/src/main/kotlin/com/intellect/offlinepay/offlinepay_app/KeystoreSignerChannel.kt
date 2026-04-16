package com.intellect.offlinepay.offlinepay_app

// KeystoreSignerChannel — Android-side scaffold for the hardware-backed
// [HardwareSigner] (Dart-side interface). Wiring notes for the follow-up
// task:
//
//   1. Use KeyGenParameterSpec.Builder("offlinepay.signer", PURPOSE_SIGN)
//      with setIsStrongBoxBacked(true) on API 28+ (handle IllegalStateException
//      and fall back to non-StrongBox TEE).
//   2. For Ed25519 support (Android 12+), set
//      setAlgorithmParameterSpec(EdECKey.NamedParameterSpec.named("Ed25519")).
//      Where Ed25519 is unavailable, fall back to ECDSA P-256
//      (setDigests(DIGEST_SHA256); setAlgorithmParameterSpec(
//      ECGenParameterSpec("secp256r1"))). Communicate the algorithm back to
//      Dart via SignerKeyDescriptor.algorithm so server-side verification
//      branches on it.
//   3. Register the MethodChannel named "offlinepay/keystore-signer":
//        - "getPublic" -> { algorithm, publicKey, hardwareBacked }
//        - "generate"  -> same
//        - "sign"      -> raw signature bytes
//        - "wipe"      -> void
//   4. After provisioning, run KeyInfo.isInsideSecureHardware() on the
//      private key entry to set `hardwareBacked` truthfully. Do NOT claim
//      hardwareBacked when the key landed in software fallback.
//   5. Attach setUserAuthenticationRequired(true) + a reasonable timeout
//      only when the app has a biometric prompt flow — otherwise signing
//      silently fails inside background sync loops.
//
// This file is intentionally a placeholder to keep the Gradle build
// unaffected until the follow-up lands.

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodChannel

class KeystoreSignerChannel : FlutterPlugin {
    private var channel: MethodChannel? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, "offlinepay/keystore-signer")
        channel?.setMethodCallHandler { call, result ->
            // TODO(A-05-followup): wire to AndroidKeyStore (StrongBox) per the
            // scaffold comment above.
            result.notImplemented()
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
    }
}
