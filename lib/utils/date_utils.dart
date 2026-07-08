DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Calendar days from today to [target].
/// Today → 0, tomorrow → 1, yesterday → -1.
int daysUntil(DateTime target) {
  final today = dateOnly(DateTime.now());
  return dateOnly(target).difference(today).inDays;
}

/// Formats [d] as 'yyyy-MM-dd'. Replaces .toIso8601String().split('T')[0].
String toDateString(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// Null-safe wrapper: returns null when [d] is null.
String? dateStr(DateTime? d) => d == null ? null : toDateString(d);
