const List<String> _monthLabels = <String>[
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String formatUpdatedAt(int epochMs, {DateTime? now}) {
  final current = now ?? DateTime.now();
  final updated = DateTime.fromMillisecondsSinceEpoch(epochMs);
  final diff = current.difference(updated);

  if (diff.inMinutes < 1) {
    return 'just now';
  }
  if (diff.inHours < 1) {
    return '${diff.inMinutes}m ago';
  }
  if (diff.inDays < 1) {
    return '${diff.inHours}h ago';
  }
  if (diff.inDays < 30) {
    return '${diff.inDays}d ago';
  }

  final day = updated.day.toString();
  final month = _monthLabels[updated.month - 1];
  if (updated.year == current.year) {
    return '$day $month';
  }
  return '$day $month ${updated.year}';
}
