import 'dart:typed_data';

import 'package:cryptography/cryptography.dart' show Sha256;

Future<String> deriveTransactionId(Uint8List paymentBytes) async {
  final hash = await Sha256().hash(paymentBytes);
  final sb = StringBuffer();
  for (final b in hash.bytes) {
    sb.write(b.toRadixString(16).padLeft(2, '0'));
  }
  return sb.toString();
}
