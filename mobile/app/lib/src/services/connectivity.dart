import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  final Connectivity _c;
  final _controller = StreamController<bool>.broadcast();
  StreamSubscription<List<ConnectivityResult>>? _sub;
  bool _online = false;

  ConnectivityService([Connectivity? c]) : _c = c ?? Connectivity();

  bool get online => _online;
  Stream<bool> get stream => _controller.stream;

  Future<void> start() async {
    final initial = await _c.checkConnectivity();
    _update(initial);
    _sub = _c.onConnectivityChanged.listen(_update);
  }

  void _update(List<ConnectivityResult> results) {
    final nowOnline =
        results.any((r) => r != ConnectivityResult.none);
    if (nowOnline != _online) {
      _online = nowOnline;
      _controller.add(_online);
    }
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    await _controller.close();
  }
}
