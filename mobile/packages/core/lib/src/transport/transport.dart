import 'dart:typed_data';

enum PaymentChannel { qr, nfc }

abstract class PaymentSendTransport {
  PaymentChannel get channel;
  Future<void> start(Uint8List sealedWireBytes, {int? chunkSize});
  Future<void> stop();
}

abstract class PaymentReceiveTransport {
  PaymentChannel get channel;
  Stream<Uint8List> get envelopes;
  Future<void> start();
  Future<void> stop();
}
