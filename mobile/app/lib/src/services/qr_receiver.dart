import 'dart:async';
import 'dart:convert' show base64;
import 'dart:typed_data';

import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:offlinepay_core/offlinepay_core.dart';

import 'payment_verifier.dart';

class QrReceiver {
  final PaymentVerifier verifier;
  final String selfUserId;

  final _completed = StreamController<VerifiedPayment>.broadcast();
  final _failures = StreamController<VerifyException>.broadcast();

  final Map<int, Uint8List> _rawFrames = {};

  Reassembler _reassembler = Reassembler();

  int? _totalFrames;
  bool _finalizing = false;
  Uint8List? _sessionHash;

  QrReceiver({required this.verifier, required this.selfUserId});

  Stream<VerifiedPayment> get completed => _completed.stream;
  Stream<VerifyException> get failures => _failures.stream;

  int get framesReceived => _rawFrames.length;
  int? get totalFrames => _totalFrames;

  double get progress {
    final total = _totalFrames;
    if (total == null || total == 0) return 0;
    return (_rawFrames.length / total).clamp(0.0, 1.0);
  }

  void reset() {
    _rawFrames.clear();
    _reassembler = Reassembler();
    _totalFrames = null;
    _finalizing = false;
    _sessionHash = null;
  }

  void ingest(BarcodeCapture capture) {
    print("ingesting capture with ${capture.barcodes.length} barcodes");
    if (_finalizing) {
      print("currently finalizing, dropping capture");
      return;
    }
    for (final b in capture.barcodes) {
      final raw = _maybeBase64(b.rawValue) ?? b.rawBytes;

      if (raw == null) {
        print("barcode missing raw bytes and raw value, skipping");
        continue;
      }
      print("ingesting barcode with raw bytes: $raw");
      _ingestRaw(Uint8List.fromList(raw));
    }
    if (_reassembler.complete() && !_finalizing) {
      _finalizing = true;
      scheduleMicrotask(_finalize);
    }
  }

  void _ingestRaw(Uint8List rawFrame) {
    print("ingesting raw frame: $rawFrame");
    final Frame frame;
    try {
      frame = decodeFrame(rawFrame);
    } on QrFrameException {
      print("malformed frame, skipping: $rawFrame");
      return;
    }

    print("decoded frame: index=${frame.index} total=${frame.totalFrames} kind=${frame.kind}");
    if (frame.kind == kindHeader) {
      final hash = frame.payload;
      if (_sessionHash == null) {
        _sessionHash = Uint8List.fromList(hash);
      } else if (!_bytesEqual(_sessionHash!, hash)) {
        reset();
        _sessionHash = Uint8List.fromList(hash);
      }
    }
    _totalFrames ??= frame.totalFrames;
    try {
      _reassembler.accept(frame);
    } on QrFrameException {
      print("frame failed reassembly checks, skipping: index=${frame.index} total=${frame.totalFrames}");
      return;
    }
    _rawFrames[frame.index] = rawFrame;
    _totalFrames = frame.totalFrames;

    print("frame accepted: index=${frame.index} total=${frame.totalFrames}, progress=$progress");
  }

  Future<void> _finalize() async {
    final framesInOrder = _rawFrames.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final rawList = framesInOrder.map((e) => e.value).toList(growable: false);

    try {
      final verified = await verifier.verifyAndEnqueue(
        rawList,
        selfUserId: selfUserId,
      );
      _completed.add(verified);
    } on VerifyException catch (e) {
      _failures.add(e);
    } catch (e) {
      _failures.add(VerifyException(VerifyFailure.decrypt, '$e'));
    } finally {
      _rawFrames.clear();
      _reassembler = Reassembler();
      _totalFrames = null;
      _sessionHash = null;
      _finalizing = false;
    }
  }

  Future<void> dispose() async {
    await _completed.close();
    await _failures.close();
  }

  static Uint8List? _maybeBase64(String? s) {
    if (s == null || s.isEmpty) return null;
    try {
      return Uint8List.fromList(base64.decode(s));
    } catch (_) {
      return null;
    }
  }

  static bool _bytesEqual(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
