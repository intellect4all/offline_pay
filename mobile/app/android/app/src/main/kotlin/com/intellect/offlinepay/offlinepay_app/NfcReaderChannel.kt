package com.intellect.offlinepay.offlinepay_app

// NfcReaderChannel — merchant-side NFC reader over IsoDep / ISO-DEP.
//
// Uses NfcAdapter.enableReaderMode so Android delivers us the raw tag
// without launching another activity. On tag discovery we:
//
//   1. Open IsoDep.
//   2. SELECT our AID (identical bytes to nfc_pull_protocol.dart).
//   3. Pull chunk 0 to learn `total`, then chunks 1..total-1.
//   4. Concatenate and hand the assembled wire bytes to Dart via the
//      EventChannel at `offlinepay/nfc-reader/events` as
//      `{ "type": "wire", "bytes": ByteArray }`.
//
// Errors are surfaced as `{ "type": "error", "message": String }` — Dart
// decides whether to retry or fall back to QR.

import android.app.Activity
import android.nfc.NfcAdapter
import android.nfc.Tag
import android.nfc.tech.IsoDep
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.IOException

class NfcReaderChannel : FlutterPlugin, ActivityAware, MethodChannel.MethodCallHandler {
    private var methodChannel: MethodChannel? = null
    private var eventChannel: EventChannel? = null
    private var events: EventChannel.EventSink? = null
    private var activity: Activity? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel = MethodChannel(binding.binaryMessenger, "offlinepay/nfc-reader").also {
            it.setMethodCallHandler(this)
        }
        eventChannel = EventChannel(binding.binaryMessenger, "offlinepay/nfc-reader/events").also {
            it.setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, eventSink: EventChannel.EventSink?) {
                    events = eventSink
                }
                override fun onCancel(arguments: Any?) {
                    events = null
                }
            })
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel?.setMethodCallHandler(null)
        methodChannel = null
        eventChannel?.setStreamHandler(null)
        eventChannel = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
    }
    override fun onDetachedFromActivityForConfigChanges() { stopSession(); activity = null }
    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
    }
    override fun onDetachedFromActivity() { stopSession(); activity = null }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "startSession" -> {
                val a = activity ?: return result.error("no_activity", "not attached", null)
                val adapter = NfcAdapter.getDefaultAdapter(a)
                if (adapter == null || !adapter.isEnabled) {
                    return result.error("nfc_unavailable", "NFC off or absent", null)
                }
                val flags = NfcAdapter.FLAG_READER_NFC_A or
                    NfcAdapter.FLAG_READER_NFC_B or
                    NfcAdapter.FLAG_READER_SKIP_NDEF_CHECK
                adapter.enableReaderMode(a, { tag -> handleTag(tag) }, flags, null)
                result.success(null)
            }
            "stopSession" -> { stopSession(); result.success(null) }
            else -> result.notImplemented()
        }
    }

    private fun stopSession() {
        val a = activity ?: return
        NfcAdapter.getDefaultAdapter(a)?.disableReaderMode(a)
    }

    private fun handleTag(tag: Tag) {
        // Runs on a dedicated reader thread. Do all IsoDep I/O here, then
        // hop to main to emit events. Bail fast on any IO error.
        try {
            val isoDep = IsoDep.get(tag) ?: run { emitError("not IsoDep"); return }
            isoDep.connect()
            isoDep.timeout = 5_000
            try {
                val selectRsp = isoDep.transceive(SELECT_AID)
                if (!isOk(selectRsp)) {
                    emitError("SELECT failed: ${hex(selectRsp)}"); return
                }
                // Pull chunk 0 first so we can learn `total`.
                val first = isoDep.transceive(buildGetChunk(0))
                val firstParsed = parseChunkResponse(first) ?: run {
                    emitError("bad chunk 0"); return
                }
                val total = firstParsed.total
                val buffer = ByteArray(0).toMutableList()
                buffer.addAll(firstParsed.data.toList())
                for (i in 1 until total) {
                    val rsp = isoDep.transceive(buildGetChunk(i))
                    val parsed = parseChunkResponse(rsp) ?: run {
                        emitError("bad chunk $i"); return
                    }
                    if (parsed.total != total) {
                        emitError("total mismatch at $i"); return
                    }
                    buffer.addAll(parsed.data.toList())
                }
                emitWire(buffer.toByteArray())
            } finally {
                try { isoDep.close() } catch (_: IOException) { /* ignored */ }
            }
        } catch (e: IOException) {
            emitError("io: ${e.message}")
        }
    }

    private fun emitWire(bytes: ByteArray) {
        mainHandler.post {
            events?.success(mapOf("type" to "wire", "bytes" to bytes))
        }
    }
    private fun emitError(msg: String) {
        mainHandler.post {
            events?.success(mapOf("type" to "error", "message" to msg))
        }
    }

    private data class ChunkResponse(val total: Int, val data: ByteArray)

    companion object {
        // Mirror of nfc_pull_protocol.dart.
        private val AID = byteArrayOf(
            0xF0.toByte(), 0x4F, 0x46, 0x4C, 0x50, 0x41, 0x59, 0x01,
        )
        private val SELECT_AID = byteArrayOf(
            0x00, 0xA4.toByte(), 0x04, 0x00, AID.size.toByte(),
        ) + AID + byteArrayOf(0x00)

        private fun buildGetChunk(idx: Int): ByteArray = byteArrayOf(
            0x80.toByte(), 0xA0.toByte(), (idx and 0xFF).toByte(), 0x00, 0x00,
        )

        private fun isOk(rsp: ByteArray): Boolean =
            rsp.size >= 2 &&
                rsp[rsp.size - 2] == 0x90.toByte() &&
                rsp[rsp.size - 1] == 0x00.toByte()

        private fun parseChunkResponse(rsp: ByteArray): ChunkResponse? {
            if (!isOk(rsp) || rsp.size < 3) return null
            val total = rsp[0].toInt() and 0xFF
            if (total < 1 || total > 255) return null
            val data = rsp.copyOfRange(1, rsp.size - 2)
            return ChunkResponse(total, data)
        }

        private fun hex(b: ByteArray): String =
            b.joinToString("") { "%02X".format(it) }
    }
}
