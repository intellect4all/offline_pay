import '../tokens.dart' show GossipBlob;
import 'bloom.dart';

const int maxGossipHops = 3;
const int maxCarryCapacity = 500;

class _Entry {
  final GossipBlob blob;
  final bool isOwn;
  final int insertSeq;
  _Entry(this.blob, this.isOwn, this.insertSeq);
}

class CarryCache {
  final List<_Entry> _entries = [];
  final Set<String> _storedHashes = {};
  final BloomFilter _seen = BloomFilter();
  int _seq = 0;
  final int capacity;

  CarryCache({this.capacity = maxCarryCapacity});

  int get length => _entries.length;

  List<GossipBlob> get blobs =>
      List<GossipBlob>.unmodifiable(_entries.map((e) => e.blob));

  void add(GossipBlob blob, {required bool isOwnTxn}) {
    final key = _hex(blob.transactionHash);
    if (_storedHashes.contains(key)) return;
    _entries.add(_Entry(blob, isOwnTxn, _seq++));
    _storedHashes.add(key);
    _seen.add(blob.transactionHash);
    _evictIfNeeded();
  }

  void _evictIfNeeded() {
    if (_entries.length <= capacity) return;
    while (_entries.length > capacity) {
      var victim = -1;
      for (var i = 0; i < _entries.length; i++) {
        if (!_entries[i].isOwn) {
          victim = i;
          break;
        }
      }
      if (victim < 0) {
        return;
      }
      final removed = _entries.removeAt(victim);
      _storedHashes.remove(_hex(removed.blob.transactionHash));
    }
  }

  void markSeen(List<int> transactionHash) {
    _seen.add(transactionHash);
  }

  bool alreadySeen(List<int> transactionHash) {
    return _seen.contains(transactionHash);
  }

  List<GossipBlob> incrementHops() {
    final out = <GossipBlob>[];
    final kept = <_Entry>[];
    for (final e in _entries) {
      final newHop = e.blob.hopCount + 1;
      if (newHop > maxGossipHops) {
        _storedHashes.remove(_hex(e.blob.transactionHash));
        continue;
      }
      final bumped = GossipBlob(
        transactionHash: e.blob.transactionHash,
        encryptedBlob: e.blob.encryptedBlob,
        bankSignature: e.blob.bankSignature,
        ceilingTokenHash: e.blob.ceilingTokenHash,
        hopCount: newHop,
        blobSize: e.blob.blobSize,
      );
      out.add(bumped);
      kept.add(_Entry(bumped, e.isOwn, e.insertSeq));
    }
    _entries
      ..clear()
      ..addAll(kept);
    return out;
  }

  List<GossipBlob> outgoingBundle(int maxBytes) {
    if (maxBytes <= 0) return const [];
    final byRecency = [..._entries]
      ..sort((a, b) => b.insertSeq.compareTo(a.insertSeq));
    final pickedSeqs = <int>{};
    var used = 0;
    for (final e in byRecency) {
      final size = e.blob.blobSize;
      if (used + size > maxBytes) continue;
      used += size;
      pickedSeqs.add(e.insertSeq);
    }
    return [
      for (final e in _entries)
        if (pickedSeqs.contains(e.insertSeq)) e.blob,
    ];
  }

  bool remove(List<int> transactionHash) {
    final key = _hex(transactionHash);
    if (!_storedHashes.contains(key)) return false;
    _entries.removeWhere((e) => _hex(e.blob.transactionHash) == key);
    _storedHashes.remove(key);
    return true;
  }

  static String _hex(List<int> bytes) {
    final sb = StringBuffer();
    for (final b in bytes) {
      sb.write((b & 0xFF).toRadixString(16).padLeft(2, '0'));
    }
    return sb.toString();
  }
}
