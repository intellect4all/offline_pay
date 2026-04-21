String shortRelative(DateTime t, {DateTime? now}) {
  final n = (now ?? DateTime.now()).toLocal();
  final local = t.toLocal();
  final diff = n.difference(local);
  if (diff.inSeconds.abs() < 45) return 'just now';
  if (diff.inMinutes.abs() < 60) return '${diff.inMinutes.abs()}m';
  if (diff.inHours.abs() < 24 && local.day == n.day) {
    return '${diff.inHours.abs()}h';
  }
  final yesterday = DateTime(n.year, n.month, n.day - 1);
  if (local.year == yesterday.year &&
      local.month == yesterday.month &&
      local.day == yesterday.day) {
    return 'Yesterday';
  }
  if (local.year == n.year) return '${_mon(local.month)} ${local.day}';
  return '${_mon(local.month)} ${local.day}, ${local.year}';
}

String dayGroup(DateTime t, {DateTime? now}) {
  final n = (now ?? DateTime.now()).toLocal();
  final local = t.toLocal();
  final today = DateTime(n.year, n.month, n.day);
  final yesterday = today.subtract(const Duration(days: 1));
  final d = DateTime(local.year, local.month, local.day);
  if (d == today) return 'Today';
  if (d == yesterday) return 'Yesterday';
  return '${_mon(local.month)} ${local.day}, ${local.year}';
}

String untilOrAgo(DateTime target, {DateTime? now}) {
  final n = (now ?? DateTime.now()).toLocal();
  final diff = target.toLocal().difference(n);
  final expired = diff.isNegative;
  final d = diff.abs();
  final hours = d.inHours;
  final minutes = d.inMinutes.remainder(60);
  final body = hours > 0 ? '${hours}h ${minutes}m' : '${d.inMinutes}m';
  return expired ? 'expired $body ago' : 'in $body';
}

String _mon(int m) {
  const names = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return names[(m - 1).clamp(0, 11)];
}
