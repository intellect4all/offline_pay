// OfflinePayNfcReaderPlugin — iOS Core NFC reader for H-01 (merchant
// side). iOS cannot act as an HCE peer, so only the reader half lives
// here. Protocol mirrors nfc_pull_protocol.dart:
//
//   SELECT cmd       : 00 A4 04 00 08 <AID> 00
//   SELECT rsp       : 90 00
//   GET_CHUNK cmd    : 80 A0 <idx> 00 00
//   GET_CHUNK rsp    : <total:1B> <data...> 90 00
//
// On tag discovery we connect, run SELECT, then pull chunks 0..total-1.
// Assembled bytes are emitted on the `offlinepay/nfc-reader/events`
// EventChannel. Errors are surfaced as `{ "type": "error", "message": ... }`.

import CoreNFC
import Flutter
import Foundation

@available(iOS 13.0, *)
public class OfflinePayNfcReaderPlugin: NSObject, FlutterPlugin,
                                        NFCTagReaderSessionDelegate,
                                        FlutterStreamHandler {

    private static let aid: [UInt8] = [
        0xF0, 0x4F, 0x46, 0x4C, 0x50, 0x41, 0x59, 0x01,
    ]
    private static let selectApdu: [UInt8] = [
        0x00, 0xA4, 0x04, 0x00, UInt8(aid.count),
    ] + aid + [0x00]

    private var session: NFCTagReaderSession?
    private var eventSink: FlutterEventSink?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let method = FlutterMethodChannel(
            name: "offlinepay/nfc-reader",
            binaryMessenger: registrar.messenger())
        let events = FlutterEventChannel(
            name: "offlinepay/nfc-reader/events",
            binaryMessenger: registrar.messenger())
        let plugin = OfflinePayNfcReaderPlugin()
        registrar.addMethodCallDelegate(plugin, channel: method)
        events.setStreamHandler(plugin)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "startSession":
            guard NFCTagReaderSession.readingAvailable else {
                result(FlutterError(code: "nfc_unavailable",
                                    message: "Core NFC unavailable", details: nil))
                return
            }
            session = NFCTagReaderSession(pollingOption: [.iso14443],
                                          delegate: self,
                                          queue: nil)
            session?.alertMessage = "Hold near the payer's phone"
            session?.begin()
            result(nil)
        case "stopSession":
            session?.invalidate()
            session = nil
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - FlutterStreamHandler
    public func onListen(withArguments arguments: Any?, eventSink: @escaping FlutterEventSink)
        -> FlutterError? {
        self.eventSink = eventSink
        return nil
    }
    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        return nil
    }

    // MARK: - NFCTagReaderSessionDelegate
    public func tagReaderSessionDidBecomeActive(_ session: NFCTagReaderSession) {}

    public func tagReaderSession(_ session: NFCTagReaderSession,
                                 didInvalidateWithError error: Error) {
        emitError(error.localizedDescription)
    }

    public func tagReaderSession(_ session: NFCTagReaderSession,
                                 didDetect tags: [NFCTag]) {
        guard let first = tags.first else {
            session.invalidate(errorMessage: "no tag")
            return
        }
        session.connect(to: first) { [weak self] err in
            guard let self = self else { return }
            if let err = err {
                self.emitError("connect: \(err.localizedDescription)")
                session.invalidate()
                return
            }
            guard case let .iso7816(tag) = first else {
                self.emitError("not ISO7816")
                session.invalidate()
                return
            }
            self.runSelectAndPull(tag: tag, session: session)
        }
    }

    private func runSelectAndPull(tag: NFCISO7816Tag, session: NFCTagReaderSession) {
        let select = NFCISO7816APDU(data: Data(Self.selectApdu))!
        tag.sendCommand(apdu: select) { [weak self] data, sw1, sw2, err in
            guard let self = self else { return }
            if let err = err {
                self.emitError("select: \(err.localizedDescription)")
                session.invalidate(); return
            }
            guard sw1 == 0x90, sw2 == 0x00 else {
                self.emitError(String(format: "select sw=%02X%02X", sw1, sw2))
                session.invalidate(); return
            }
            self.pullChunk(idx: 0, total: nil, acc: Data(), tag: tag, session: session)
        }
    }

    private func pullChunk(idx: Int, total: Int?, acc: Data,
                           tag: NFCISO7816Tag, session: NFCTagReaderSession) {
        let get = NFCISO7816APDU(
            instructionClass: 0x80, instructionCode: 0xA0,
            p1Parameter: UInt8(idx & 0xFF), p2Parameter: 0x00,
            data: Data(), expectedResponseLength: 256)
        tag.sendCommand(apdu: get) { [weak self] data, sw1, sw2, err in
            guard let self = self else { return }
            if let err = err {
                self.emitError("chunk \(idx): \(err.localizedDescription)")
                session.invalidate(); return
            }
            guard sw1 == 0x90, sw2 == 0x00, data.count >= 1 else {
                self.emitError(String(format: "chunk %d sw=%02X%02X", idx, sw1, sw2))
                session.invalidate(); return
            }
            let advertisedTotal = Int(data[0])
            if let t = total, t != advertisedTotal {
                self.emitError("total mismatch at \(idx)")
                session.invalidate(); return
            }
            let effectiveTotal = total ?? advertisedTotal
            var next = acc
            next.append(data.subdata(in: 1..<data.count))
            let nextIdx = idx + 1
            if nextIdx >= effectiveTotal {
                self.emitWire(next)
                session.alertMessage = "Received"
                session.invalidate()
                return
            }
            self.pullChunk(idx: nextIdx, total: effectiveTotal, acc: next,
                           tag: tag, session: session)
        }
    }

    private func emitWire(_ bytes: Data) {
        DispatchQueue.main.async {
            self.eventSink?(["type": "wire",
                             "bytes": FlutterStandardTypedData(bytes: bytes)])
        }
    }
    private func emitError(_ msg: String) {
        DispatchQueue.main.async {
            self.eventSink?(["type": "error", "message": msg])
        }
    }
}
