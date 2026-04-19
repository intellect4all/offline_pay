import 'dart:async';
import 'dart:typed_data';

import '../gossip/wire.dart';
import '../qr/frames.dart';
import 'transport.dart';

class QrSendTransport implements PaymentSendTransport {
  List<Uint8List> _frames = const [];

  @override
  PaymentChannel get channel => PaymentChannel.qr;

  List<Uint8List> get encodedFrames => _frames;

  @override
  Future<void> start(Uint8List sealedWireBytes, {int? chunkSize}) async {
    _frames = chunkEnvelopeFrames(sealedWireBytes, chunkSize: chunkSize ?? defaultChunkSize);
  }

  @override
  Future<void> stop() async {
    _frames = const [];
  }
}

class QrReceiveTransport implements PaymentReceiveTransport {
  final _ctrl = StreamController<Uint8List>.broadcast();
  Reassembler _reassembler = Reassembler();

  @override
  PaymentChannel get channel => PaymentChannel.qr;

  @override
  Stream<Uint8List> get envelopes => _ctrl.stream;

  Reassembler get reassembler => _reassembler;

  @override
  Future<void> start() async {
    _reassembler = Reassembler();
  }

  bool acceptFrameBytes(Uint8List rawFrame) {
    try {
      final f = decodeFrame(rawFrame);
      _reassembler.accept(f);
    } on QrFrameException {
      return false;
    }
    if (!_reassembler.complete()) return false;
    final wire = reassembleEnvelopeWire(_reassembler);
    if (wire == null) return false;
    _ctrl.add(wire);
    _reassembler = Reassembler();
    return true;
  }

  @override
  Future<void> stop() async {
    await _ctrl.close();
  }
}
