import 'dart:io' show Platform;

import 'package:flutter/services.dart';
import 'package:offlinepay_core/offlinepay_core.dart';

import 'nfc_channels.dart';

class NfcSendTransport implements PaymentSendTransport {
  static const _channel = MethodChannel(nfcHceMethodChannel);

  static bool get isAvailable => Platform.isAndroid;

  List<Uint8List> _stagedResponses = const [];
  List<Uint8List> get stagedResponses => _stagedResponses;

  @override
  PaymentChannel get channel => PaymentChannel.nfc;

  @override
  Future<void> start(Uint8List sealedWireBytes, {int? chunkSize}) async {
    _stagedResponses = stageChunkResponses(sealedWireBytes);
    if (!isAvailable) return;
    await _channel.invokeMethod<void>('armPayload', <String, Object?>{
      'chunkResponses': _stagedResponses,
    });
  }

  @override
  Future<void> stop() async {
    _stagedResponses = const [];
    if (!isAvailable) return;
    await _channel.invokeMethod<void>('disarm');
  }
}
