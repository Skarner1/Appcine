import 'package:intl/intl.dart';

import '../l10n/strings.dart';

String _min() => tr('dur.minShort');
String _hour() => tr('dur.hourShort');
String _day() => tr('dur.dayShort');

/// Formatea minutos como "2h 15min" o "45 min" (unidades según el idioma).
String formatDuration(int minutes) {
  if (minutes <= 0) return '—';
  final hours = minutes ~/ 60;
  final mins = minutes % 60;
  if (hours == 0) return '$mins ${_min()}';
  if (mins == 0) return '$hours${_hour()}';
  return '$hours${_hour()} $mins${_min()}';
}

/// Formatea una duración larga acumulada como "3d 4h" / "12h 30min".
String formatLongDuration(int minutes) {
  if (minutes <= 0) return '0 ${_min()}';
  final days = minutes ~/ (60 * 24);
  final hours = (minutes % (60 * 24)) ~/ 60;
  final mins = minutes % 60;
  if (days > 0) return '$days${_day()} $hours${_hour()}';
  if (hours > 0) {
    return mins > 0 ? '$hours${_hour()} $mins${_min()}' : '$hours${_hour()}';
  }
  return '$mins ${_min()}';
}

/// "15 mar 2026" (nombres de mes en el idioma activo).
String formatDate(DateTime date) =>
    DateFormat('d MMM y', S.lang.code).format(date);

/// "Viernes 22:00" / "15 mar, 20:00" (localizado).
String formatDateTime(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(date.year, date.month, date.day);
  final time = DateFormat('HH:mm').format(date);

  if (day == today) return tr('time.todayAt', {'t': time});
  if (day == today.add(const Duration(days: 1))) {
    return tr('time.tomorrowAt', {'t': time});
  }
  if (day.difference(today).inDays.abs() < 7) {
    final weekday = DateFormat('EEEE', S.lang.code).format(date);
    return '${weekday[0].toUpperCase()}${weekday.substring(1)} $time';
  }
  return '${DateFormat('d MMM', S.lang.code).format(date)}, $time';
}

/// Tiempo relativo: "hace 3 días", "hace 1 año".
String formatRelative(DateTime date) {
  final diff = DateTime.now().difference(date);
  if (diff.inDays >= 365) {
    return formatRelativeYears(diff.inDays ~/ 365);
  }
  if (diff.inDays >= 30) {
    return trn('time.monthsAgo', diff.inDays ~/ 30);
  }
  if (diff.inDays >= 1) {
    return trn('time.daysAgo', diff.inDays);
  }
  if (diff.inHours >= 1) return tr('time.hoursAgo', {'n': diff.inHours});
  return tr('time.justNow');
}

String formatRelativeYears(int years) => trn('time.yearsAgo', years);
