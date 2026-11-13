/// Calendar days as `YYYY-MM-DD` strings in the device's local time.
///
/// Days are stored as text so a quest done on the 14th stays on the 14th no
/// matter what happens to time zones or daylight saving later.
class DayKey {
  DayKey._();

  static String of(DateTime local) {
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// Midnight, local time, at the start of [key].
  static DateTime parse(String key) {
    final parts = key.split('-');
    return DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
  }

  static DateTime _utc(String key) {
    final parts = key.split('-');
    return DateTime.utc(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
  }

  /// Whole calendar days from [from] to [to]; negative if [to] is earlier.
  /// Computed in UTC so daylight-saving changes never shift the count.
  static int daysBetween(String from, String to) =>
      _utc(to).difference(_utc(from)).inDays;

  static String addDays(String key, int days) {
    final d = _utc(key).add(Duration(days: days));
    return of(DateTime(d.year, d.month, d.day));
  }

  /// ISO weekday, Monday = 1 … Sunday = 7.
  static int weekday(String key) => _utc(key).weekday;

  static const List<String> weekdayShort = <String>[
    'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun',
  ];
  static const List<String> weekdayLong = <String>[
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday',
    'Sunday',
  ];
  static const List<String> monthLong = <String>[
    'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August',
    'September', 'October', 'November', 'December',
  ];

  /// e.g. "Saturday 14 November".
  static String friendly(String key) {
    final d = _utc(key);
    return '${weekdayLong[d.weekday - 1]} ${d.day} ${monthLong[d.month - 1]}';
  }
}
