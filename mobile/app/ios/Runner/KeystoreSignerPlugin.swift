// KeystoreSignerPlugin — iOS-side scaffold for the hardware-backed
// HardwareSigner. Wiring notes for the follow-up task:
//
//   1. Use CryptoKit's `SecureEnclave.P256.Signing.PrivateKey` when
//      `SecureEnclave.isAvailable` (returns false on simulator + devices
//      without the SE). Store the encoded representation in the Keychain
//      with kSecAttrTokenIDSecureEnclave.
//   2. Ed25519 in Secure Enclave is not supported. The follow-up protocol
//      decision in A-05 is to adopt ECDSA P-256 for device signatures so
//      Android StrongBox and iOS SE share the same algorithm. Communicate
//      the algorithm back to Dart via SignerKeyDescriptor.algorithm.
//   3. Register FlutterMethodChannel named "offlinepay/keystore-signer":
//        - "getPublic" -> { algorithm, publicKey, hardwareBacked }
//        - "generate"  -> same
//        - "sign"      -> DER-encoded signature for ECDSA P-256
//        - "wipe"      -> void
//   4. Mark hardwareBacked=true only when `SecureEnclave.isAvailable` AND
//      the key actually landed in the SE (LAContext restricted).
//   5. Wrap every `try` in proper error mapping — Flutter's
//      MethodCall.error surfaces user-actionable messages.
//
// This file is intentionally a placeholder. `flutter create` does not
// generate Swift plugin boilerplate automatically; to activate it, the
// follow-up PR must register this plugin in AppDelegate.swift and include
// the file in the Runner target.

import Flutter
import Foundation

public class KeystoreSignerPlugin: NSObject, FlutterPlugin {
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "offlinepay/keystore-signer",
            binaryMessenger: registrar.messenger()
        )
        let instance = KeystoreSignerPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        // TODO(A-05-followup): wire to Secure Enclave per the scaffold comment.
        result(FlutterMethodNotImplemented)
    }
}
