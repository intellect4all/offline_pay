import 'dart:typed_data';

class BloomFilter {
  static const int bitCount = 8192;
  static const int byteCount = bitCount ~/ 8;
  static const int hashCount = 4;

  final Uint8List _bits;
  int _itemsAdded = 0;

  BloomFilter() : _bits = Uint8List(byteCount);

  int get itemsAdded => _itemsAdded;

  void reset() {
    for (var i = 0; i < _bits.length; i++) {
      _bits[i] = 0;
    }
    _itemsAdded = 0;
  }

  void add(List<int> key) {
    for (final idx in _indices(key)) {
      _bits[idx >> 3] |= 1 << (idx & 7);
    }
    _itemsAdded++;
  }

  bool contains(List<int> key) {
    for (final idx in _indices(key)) {
      if ((_bits[idx >> 3] & (1 << (idx & 7))) == 0) return false;
    }
    return true;
  }

  Iterable<int> _indices(List<int> key) sync* {
    final h1 = _fnv1a32(key);
    var h = h1;
    for (var i = 0; i < hashCount; i++) {
      h = ((h << 13) | (h >>> 19)) & 0xFFFFFFFF;
      h = (h * 0x5bd1e995) & 0xFFFFFFFF;
      h ^= h >>> 15;
      yield h % bitCount;
    }
  }

  int _fnv1a32(List<int> data) {
    var h = 0x811c9dc5;
    for (final b in data) {
      h ^= b & 0xFF;
      h = (h * 0x01000193) & 0xFFFFFFFF;
    }
    return h;
  }
}
