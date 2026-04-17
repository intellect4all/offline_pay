import 'dart:typed_data';

class RealmKeyring {
  final Map<int, Uint8List> _keys = {};
  int? _activeVersion;

  RealmKeyring();

  RealmKeyring.seed(int version, Uint8List key) {
    add(version, key, activate: true);
  }

  bool get isEmpty => _keys.isEmpty;

  bool get isNotEmpty => _keys.isNotEmpty;

  int get activeVersion => _activeVersion ?? -1;

  Uint8List get activeKey {
    final v = _activeVersion;
    if (v == null) {
      throw StateError('RealmKeyring has no active key');
    }
    final k = _keys[v];
    if (k == null) {
      throw StateError('RealmKeyring has no active key');
    }
    return k;
  }

  int get length => _keys.length;

  bool contains(int version) => _keys.containsKey(version);

  Uint8List? keyFor(int version) => _keys[version];

  void add(int version, Uint8List key, {bool activate = false}) {
    _keys[version] = key;
    final current = _activeVersion;
    if (activate || current == null || version > current) {
      _activeVersion = version;
    }
  }

  void remove(int version) {
    _keys.remove(version);
    if (_activeVersion == version) {
      if (_keys.isEmpty) {
        _activeVersion = null;
      } else {
        _activeVersion = _keys.keys.reduce((a, b) => a > b ? a : b);
      }
    }
  }

  Iterable<int> get versionsNewestFirst {
    final keys = _keys.keys.toList()..sort((a, b) => b.compareTo(a));
    return keys;
  }
}
