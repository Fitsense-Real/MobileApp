/// Short label of the plan card about where the user is in the plan week.
///
/// The backend sends `weekStartDate`/`weekEndDate` as local dates (Monday to
/// Sunday in the user's time zone). The first plan may start in the future
/// (next Monday), so counting from today to the end would add days that are
/// not part of the plan ("8 DÍAS" the day before a 7-day plan).
///
/// - before the start: `EMPIEZA MAÑANA` / `EMPIEZA EN n DÍAS`;
/// - during the week: days left including today (`n DÍAS`, `ÚLTIMO DÍA`);
/// - after the end or without valid dates: null (nothing is shown).
///
/// Dates are compared as calendar days (UTC), so a daylight-saving change
/// never loses or adds a day.
String? planWeekLabel({Object? weekStartDate, Object? weekEndDate, required DateTime now}) {
  final start = _calendarDay(weekStartDate);
  final end = _calendarDay(weekEndDate);
  if (start == null || end == null || end.isBefore(start)) return null;
  final today = DateTime.utc(now.year, now.month, now.day);
  final untilStart = start.difference(today).inDays;
  if (untilStart == 1) return 'EMPIEZA MAÑANA';
  if (untilStart > 1) return 'EMPIEZA EN $untilStart DÍAS';
  final left = end.difference(today).inDays + 1;
  if (left <= 0) return null;
  return left == 1 ? 'ÚLTIMO DÍA' : '$left DÍAS';
}

DateTime? _calendarDay(Object? value) {
  final parsed = value == null ? null : DateTime.tryParse('$value');
  return parsed == null ? null : DateTime.utc(parsed.year, parsed.month, parsed.day);
}
