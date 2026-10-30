const weekdayNames = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];
const weekdayShort = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

String amPm(int minutes) => (minutes ~/ 60) % 24 < 12 ? 'AM' : 'PM';

/// 8:00 AM, or 8:00 without the AM/PM.
String clock(int minutes, {bool withAmPm = true}) {
  var hour = ((minutes ~/ 60) % 24) % 12;
  if (hour == 0) hour = 12;
  final mins = (minutes % 60).toString().padLeft(2, '0');
  final text = '$hour:$mins';
  return withAmPm ? '$text ${amPm(minutes)}' : text;
}

/// 8:00 – 9:00 AM, or 11:00 AM – 12:30 PM.
String timeRange(int start, int end) => amPm(start) == amPm(end)
    ? '${clock(start, withAmPm: false)} – ${clock(end)}'
    : '${clock(start)} – ${clock(end)}';

int minuteOfDay(DateTime t) => t.hour * 60 + t.minute;

String clockOf(DateTime t) => clock(minuteOfDay(t));

/// Friday 30 October
String longDate(DateTime d) =>
    '${weekdayNames[d.weekday - 1]} ${d.day} ${monthNames[d.month - 1]}';

/// Fri 30 Oct
String shortDate(DateTime d) =>
    '${weekdayShort[d.weekday - 1]} ${d.day} ${monthNames[d.month - 1].substring(0, 3)}';

/// 2026-10-30, the key for everything stored per day.
String dayKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Every day, No days, or Mon, Wed, Fri.
String daysLabel(Set<int> days) {
  if (days.length == 7) return 'Every day';
  if (days.isEmpty) return 'No days';
  final sorted = days.toList()..sort();
  return sorted.map((d) => weekdayShort[d - 1]).join(', ');
}

/// 1 h 20 min, or 45 min.
String hoursMinutes(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes % 60;
  if (h == 0) return '$m min';
  return m == 0 ? '$h h' : '$h h $m min';
}
