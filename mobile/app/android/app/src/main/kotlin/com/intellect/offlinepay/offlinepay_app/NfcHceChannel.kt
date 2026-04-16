package com.intellect.offlinepay.offlinepay_app

// NfcHceChannel — MethodChannel that stages HCE response APDUs from Dart.
// The Dart side (lib/src/nfc/nfc_send_transport.dart) calls:
//
//   armPayload { chunkResponses: List<ByteArray> }  — cache chunks
//   disarm                                           — clear cache
//
// We intentionally do NOT reopen the Dart bridge from inside
// processCommandApdu: that runs on the NFC binder thread and can't await
// the Dart isolate. Chunks are precomputed by Dart and pushed in full
// before the user holds the device against the reader.

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodChannel

class NfcHceChannel : FlutterPlugin {
    private var channel: MethodChannel? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        val mc = MethodChannel(binding.binaryMessenger, "offlinepay/nfc-hce")
        channel = mc
        mc.setMethodCallHandler { call, result ->
            when (call.method) {
                "armPayload" -> {
                    val raw = call.argument<List<ByteArray>>("chunkResponses")
                    if (raw == null) {
                        result.error("bad_args", "chunkResponses missing", null)
                        return@setMethodCallHandler
                    }
                    PayloadRegistry.staged = raw
                    result.success(null)
                }
                "disarm" -> {
                    PayloadRegistry.staged = emptyList()
                    result.success(null)
                }
                "isArmed" -> result.success(PayloadRegistry.staged.isNotEmpty())
                else -> result.notImplemented()
            }
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
    }
}
