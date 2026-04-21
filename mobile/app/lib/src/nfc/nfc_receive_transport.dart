import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/services.dart';
import 'package:offlinepay_core/offlinepay_core.dart';

import 'nfc_channels.dart';

class NfcReceiveTransport implements PaymentReceiveTransport {
  static const _method = MethodChannel(nfcReaderMethodChannel);
  static const _events = EventChannel(nfcReaderEventChannel);

  static bool get isAvailable => Platform.isAndroid || Platform.isIOS;

  final _envelopes = StreamController<Uint8List>.broadcast();
  final _errors = StreamController<String>.broadcast();
  StreamSubscription<dynamic>? _sub;

  @override
  PaymentChannel get channel => PaymentChannel.nfc;

  @override
  Stream<Uint8List> get envelopes => _envelopes.stream;
  Stream<String> get errors => _errors.stream;

  @override
  Future<void> start() async {
    if (!isAvailable) return;
    await _method.invokeMethod<void>('startSession');
    _sub = _events.receiveBroadcastStream().listen(
      _onEvent,
      onError: (Object e) {
        _errors.add('event stream: $e');
      },
    );
  }

  void injectWireForTest(Uint8List wire) =>
      _onEvent({'type': 'wire', 'bytes': wire});

  void _onEvent(dynamic event) {
    if (event is! Map) return;
    switch (event['type']) {
      case 'wire':
        final bytes = event['bytes'];
        if (bytes is List<int>) {
          _envelopes.add(Uint8List.fromList(bytes));
        } else if (bytes is Uint8List) {
          _envelopes.add(bytes);
        }
        break;
      case 'error':
        final msg = event['message'];
        if (msg is String) _errors.add(msg);
        break;
    }
  }

  @override
  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    if (isAvailable) {
      await _method.invokeMethod<void>('stopSession');
    }
    await _envelopes.close();
    await _errors.close();
  }
}
