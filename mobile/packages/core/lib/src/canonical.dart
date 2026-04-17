// Byte-for-byte parity with backend/internal/crypto/canonical.go.
// Any change here must land on both sides or signatures stop verifying.

import 'dart:convert' show base64, utf8;
import 'dart:typed_data';

class CanonicalBytes {
  final List<int> bytes;
  const CanonicalBytes(this.bytes);
}

Uint8List canonicalize(Object? value) {
  final buf = BytesBuilder(copy: false);
  _writeCanonical(buf, _normalize(value));
  return buf.toBytes();
}

Object? _normalize(Object? v) {
  if (v == null || v is bool || v is num || v is BigInt || v is String) {
    return v;
  }
  if (v is DateTime) return v;
  if (v is CanonicalBytes) return v;
  if (v is Uint8List) return CanonicalBytes(v);
  if (v is List<int>) {
    return CanonicalBytes(v);
  }
  if (v is List) {
    return v.map(_normalize).toList(growable: false);
  }
  if (v is Map) {
    final out = <String, Object?>{};
    v.forEach((k, val) {
      if (k is! String) {
        throw ArgumentError('canonical: map key must be String, got ${k.runtimeType}');
      }
      out[k] = _normalize(val);
    });
    return out;
  }
  try {
    final dyn = v as dynamic;
    return _normalize(dyn.toJson());
  } catch (_) {
    throw ArgumentError('canonical: unsupported type ${v.runtimeType}');
  }
}

void _writeCanonical(BytesBuilder buf, Object? v) {
  if (v == null) {
    buf.add(_nullBytes);
    return;
  }
  if (v is bool) {
    buf.add(v ? _trueBytes : _falseBytes);
    return;
  }
  if (v is int) {
    buf.add(utf8.encode(v.toString()));
    return;
  }
  if (v is BigInt) {
    buf.add(utf8.encode(v.toString()));
    return;
  }
  if (v is double) {
    if (v.isNaN || v.isInfinite) {
      throw ArgumentError('canonical: NaN/Inf not allowed');
    }
    if (v == v.truncateToDouble() && v.abs() < 1e16) {
      buf.add(utf8.encode(v.toInt().toString()));
    } else {
      buf.add(utf8.encode(v.toString()));
    }
    return;
  }
  if (v is String) {
    _writeJsonString(buf, v);
    return;
  }
  if (v is DateTime) {
    _writeJsonString(buf, formatRfc3339Nano(v));
    return;
  }
  if (v is CanonicalBytes) {
    _writeJsonString(buf, base64.encode(v.bytes));
    return;
  }
  if (v is List) {
    buf.addByte(0x5b);
    for (var i = 0; i < v.length; i++) {
      if (i > 0) buf.addByte(0x2c);
      _writeCanonical(buf, v[i]);
    }
    buf.addByte(0x5d);
    return;
  }
  if (v is Map<String, Object?>) {
    final keyBytes = <String, Uint8List>{
      for (final k in v.keys) k: Uint8List.fromList(utf8.encode(k)),
    };
    final keys = v.keys.toList()
      ..sort((a, b) => _compareBytes(keyBytes[a]!, keyBytes[b]!));
    buf.addByte(0x7b);
    for (var i = 0; i < keys.length; i++) {
      if (i > 0) buf.addByte(0x2c);
      _writeJsonString(buf, keys[i]);
      buf.addByte(0x3a);
      _writeCanonical(buf, v[keys[i]]);
    }
    buf.addByte(0x7d);
    return;
  }
  throw ArgumentError('canonical: unsupported normalized type ${v.runtimeType}');
}

final Uint8List _nullBytes = Uint8List.fromList(utf8.encode('null'));
final Uint8List _trueBytes = Uint8List.fromList(utf8.encode('true'));
final Uint8List _falseBytes = Uint8List.fromList(utf8.encode('false'));

int _compareBytes(Uint8List a, Uint8List b) {
  final n = a.length < b.length ? a.length : b.length;
  for (var i = 0; i < n; i++) {
    final d = a[i] - b[i];
    if (d != 0) return d;
  }
  return a.length - b.length;
}

void _writeJsonString(BytesBuilder buf, String s) {
  buf.addByte(0x22);
  for (final r in s.runes) {
    switch (r) {
      case 0x22:
        buf.add(const [0x5c, 0x22]);
        continue;
      case 0x5c:
        buf.add(const [0x5c, 0x5c]);
        continue;
      case 0x08:
        buf.add(const [0x5c, 0x62]);
        continue;
      case 0x09:
        buf.add(const [0x5c, 0x74]);
        continue;
      case 0x0a:
        buf.add(const [0x5c, 0x6e]);
        continue;
      case 0x0c:
        buf.add(const [0x5c, 0x66]);
        continue;
      case 0x0d:
        buf.add(const [0x5c, 0x72]);
        continue;
      case 0x3c:
        buf.add(const [0x5c, 0x75, 0x30, 0x30, 0x33, 0x63]);
        continue;
      case 0x3e:
        buf.add(const [0x5c, 0x75, 0x30, 0x30, 0x33, 0x65]);
        continue;
      case 0x26:
        buf.add(const [0x5c, 0x75, 0x30, 0x30, 0x32, 0x36]);
        continue;
      case 0x2028:
        buf.add(const [0x5c, 0x75, 0x32, 0x30, 0x32, 0x38]);
        continue;
      case 0x2029:
        buf.add(const [0x5c, 0x75, 0x32, 0x30, 0x32, 0x39]);
        continue;
    }
    if (r < 0x20) {
      buf.add(utf8.encode(
          '\\u${r.toRadixString(16).padLeft(4, '0')}'));
    } else {
      buf.add(utf8.encode(String.fromCharCode(r)));
    }
  }
  buf.addByte(0x22);
}

String formatRfc3339Nano(DateTime t) {
  final u = t.toUtc();
  final y = u.year.toString().padLeft(4, '0');
  final mo = u.month.toString().padLeft(2, '0');
  final d = u.day.toString().padLeft(2, '0');
  final h = u.hour.toString().padLeft(2, '0');
  final mi = u.minute.toString().padLeft(2, '0');
  final s = u.second.toString().padLeft(2, '0');

  final micros = u.millisecond * 1000 + u.microsecond;
  final nanos = micros * 1000;

  final base = '$y-$mo-${d}T$h:$mi:$s';
  if (nanos == 0) return '${base}Z';
  var frac = nanos.toString().padLeft(9, '0');
  var end = frac.length;
  while (end > 1 && frac.codeUnitAt(end - 1) == 0x30) {
    end--;
  }
  frac = frac.substring(0, end);
  return '$base.${frac}Z';
}
