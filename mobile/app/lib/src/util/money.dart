int? parseNairaToKobo(String input) {
  final trimmed = input.trim().replaceAll(',', '');
  if (trimmed.isEmpty) return null;
  var s = trimmed;
  if (s.startsWith('₦')) s = s.substring(1);
  if (s.toUpperCase().startsWith('NGN')) s = s.substring(3);
  if (s.toUpperCase().startsWith('N')) s = s.substring(1);
  s = s.trim();
  if (s.isEmpty) return null;

  final dotIdx = s.indexOf('.');
  String whole;
  String fraction;
  if (dotIdx < 0) {
    whole = s;
    fraction = '00';
  } else {
    whole = s.substring(0, dotIdx);
    fraction = s.substring(dotIdx + 1);
    if (fraction.length > 2) return null;
    if (fraction.length == 1) fraction = '${fraction}0';
    if (fraction.isEmpty) fraction = '00';
  }
  if (whole.isEmpty) whole = '0';
  final wInt = int.tryParse(whole);
  final fInt = int.tryParse(fraction);
  if (wInt == null || fInt == null) return null;
  if (wInt < 0 || fInt < 0) return null;
  return wInt * 100 + fInt;
}

String formatNaira(int kobo) {
  final negative = kobo < 0;
  final abs = kobo.abs();
  final whole = abs ~/ 100;
  final fraction = abs % 100;
  final wholeStr = _groupThousands(whole);
  final fracStr = fraction.toString().padLeft(2, '0');
  return '${negative ? '-' : ''}₦$wholeStr.$fracStr';
}

String _groupThousands(int n) {
  final s = n.toString();
  if (s.length <= 3) return s;
  final buf = StringBuffer();
  final firstGroup = s.length % 3;
  if (firstGroup != 0) {
    buf.write(s.substring(0, firstGroup));
    if (s.length > firstGroup) buf.write(',');
  }
  for (var i = firstGroup; i < s.length; i += 3) {
    buf.write(s.substring(i, i + 3));
    if (i + 3 < s.length) buf.write(',');
  }
  return buf.toString();
}
