package com.intellect.offlinepay.offlinepay_app

// OfflinePayHceService — payer-side HCE endpoint for H-01 (NFC tap).
//
// The reader (merchant phone) is master: it SELECTs our AID and then
// issues GET_CHUNK(idx) commands; we reply from a cache of precomputed
// response APDUs staged by the Dart layer via `armPayload`.
//
// Wire match for lib/src/transport/nfc_pull_protocol.dart:
//   SELECT cmd       : 00 A4 04 00 08 <AID> 00
//   SELECT rsp       : 90 00
//   GET_CHUNK cmd    : 80 A0 <idx> 00 00
//   GET_CHUNK rsp    : <total:1B> <chunk_data> 90 00      (cached)
//   unknown cmd      : 6D 00 (INS not supported)
//
// processCommandApdu runs on the NFC binder thread and MUST return
// synchronously — any cache miss returns 6A82 (file not found) so the
// reader retries or aborts cleanly.

import android.nfc.cardemulation.HostApduService
import android.os.Bundle

class OfflinePayHceService : HostApduService() {

    override fun processCommandApdu(commandApdu: ByteArray?, extras: Bundle?): ByteArray {
        val cmd = commandApdu ?: return SW_WRONG_LENGTH
        // Matches `isSelectAidCommand` in nfc_pull_protocol.dart.
        if (isSelectAid(cmd)) {
            return SW_OK
        }
        // Matches `tryParseGetChunkCommand`: CLA=0x80 INS=0xA0 P1=idx.
        if (cmd.size >= 5 && cmd[0] == CLA_PROPRIETARY && cmd[1] == INS_GET_CHUNK) {
            val idx = cmd[2].toInt() and 0xFF
            val cache = PayloadRegistry.staged
            val response = cache.getOrNull(idx)
            return response ?: SW_FILE_NOT_FOUND
        }
        return SW_INS_NOT_SUPPORTED
    }

    override fun onDeactivated(reason: Int) {
        // Don't clear the payload on deactivation: the merchant may tap
        // again within the same payment if the link drops mid-transfer.
        // Dart calls `disarm` explicitly when the user cancels.
    }

    companion object {
        private val SW_OK = byteArrayOf(0x90.toByte(), 0x00.toByte())
        private val SW_WRONG_LENGTH = byteArrayOf(0x67.toByte(), 0x00.toByte())
        private val SW_INS_NOT_SUPPORTED = byteArrayOf(0x6D.toByte(), 0x00.toByte())
        private val SW_FILE_NOT_FOUND = byteArrayOf(0x6A.toByte(), 0x82.toByte())

        private const val CLA_PROPRIETARY: Byte = 0x80.toByte()
        private const val INS_GET_CHUNK: Byte = 0xA0.toByte()

        // AID `F04F464C50415901` — must match res/xml/apduservice.xml and
        // `offlinePayAid` in nfc_apdu.dart.
        private val AID = byteArrayOf(
            0xF0.toByte(), 0x4F, 0x46, 0x4C, 0x50, 0x41, 0x59, 0x01,
        )

        private fun isSelectAid(cmd: ByteArray): Boolean {
            if (cmd.size < 5 + AID.size) return false
            if (cmd[0] != 0x00.toByte()) return false
            if (cmd[1] != 0xA4.toByte()) return false
            if (cmd[2] != 0x04.toByte()) return false
            if (cmd[3] != 0x00.toByte()) return false
            if (cmd[4].toInt() != AID.size) return false
            for (i in AID.indices) {
                if (cmd[5 + i] != AID[i]) return false
            }
            return true
        }
    }
}

/// Shared cache populated by the Dart side via [NfcHceChannel.armPayload].
/// Process-wide — HCE services run in the same process as MainActivity
/// so we don't need IPC here.
object PayloadRegistry {
    @Volatile
    var staged: List<ByteArray> = emptyList()
}
