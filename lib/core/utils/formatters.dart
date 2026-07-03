import 'package:intl/intl.dart';

/// Formatea minutos como "2h 15min" o "45 min".
String formatDuration(int minutes) {
  if (minutes <= 0) return '—';
  final hours = minutes ~/ 60;
  final mins = minutes % 60;
  if (hours == 0) return '$mins min';
  if (mins == 0) return '${hours}h';
  return '${hours}h ${mins}min';
}

/// Formatea una duración larga acumulada como "3d 4h" / "12h 30min".
String formatLongDuration(int minutes) {
  if (minutes <= 0) return '0 min';
  final days = minutes ~/ (60 * 24);
  final hours = (minutes % (60 * 24)) ~/ 60;
  final mins = minutes % 60;
  if (days > 0) return '${days}d ${hours}h';
  if (hours > 0) return mins > 0 ? '${hours}h ${mins}min' : '${hours}h';
  return '$mins min';
}

/// "15 mar 2026"
String formatDate(DateTime date) =>
    DateFormat('d MMM y', 'es').format(date);

/// "Viernes 22:00" / "15 mar, 20:00"
String formatDateTime(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(date.year, date.month, date.day);
  final time = DateFormat('HH:mm').format(date);

  if (day == today) return 'Hoy, $time';
  if (day == today.add(const Duration(days: 1))) return 'Mañana, $time';
  if (day.difference(today).inDays.abs() < 7) {
    final weekday = DateFormat('EEEE', 'es').format(date);
    return '${weekday[0].toUpperCase()}${weekday.substring(1)} $time';
  }
  return '${DateFormat('d MMM', 'es').format(date)}, $time';
}

/// Tiempo relativo: "hace 3 días", "hace 1 año".
String formatRelative(DateTime date) {
  final diff = DateTime.now().difference(date);
  if (diff.inDays >= 365) {
    final years = diff.inDays ~/ 365;
    return 'hace $years ${years == 1 ? 'año' : 'años'}';
  }
  if (diff.inDays >= 30) {
    final months = diff.inDays ~/ 30;
    return 'hace $months ${months == 1 ? 'mes' : 'meses'}';
  }
  if (diff.inDays >= 1) {
    return 'hace ${diff.inDays} ${diff.inDays == 1 ? 'día' : 'días'}';
  }
  if (diff.inHours >= 1) return 'hace ${diff.inHours} h';
  return 'hace un momento';
}
