import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/content_item.dart';
import '../../providers/providers.dart';

/// Minutos y nº de títulos vistos en un mes concreto.
class MonthBucket {
  final DateTime month; // primer día del mes
  final int minutes;
  final int count;

  const MonthBucket({
    required this.month,
    required this.minutes,
    required this.count,
  });
}

/// Estadísticas de tiempo de visionado, todas derivadas del catálogo local.
class WatchTimeStats {
  /// Total de minutos vistos (incluye repeticiones y progreso de series).
  final int totalMinutes;
  final int thisYearMinutes;
  final int thisMonthMinutes;

  /// Minutos vistos por tipo de contenido (solo tipos con > 0).
  final Map<ContentType, int> minutesByType;

  /// Últimos 12 meses, del más antiguo al más reciente.
  final List<MonthBucket> monthly;

  final int completedCount;
  final int seenThisYear;

  /// Racha actual y mejor racha histórica (días consecutivos con visionado).
  final int currentStreak;
  final int longestStreak;

  /// Título visto de mayor duración total (o null si no hay ninguno con duración).
  final ContentItem? longestTitle;

  /// Media de tus valoraciones (1–10) o null si no has puntuado nada.
  final double? averageRating;

  const WatchTimeStats({
    required this.totalMinutes,
    required this.thisYearMinutes,
    required this.thisMonthMinutes,
    required this.minutesByType,
    required this.monthly,
    required this.completedCount,
    required this.seenThisYear,
    required this.currentStreak,
    required this.longestStreak,
    required this.longestTitle,
    required this.averageRating,
  });

  bool get isEmpty => totalMinutes == 0 && completedCount == 0;

  static const empty = WatchTimeStats(
    totalMinutes: 0,
    thisYearMinutes: 0,
    thisMonthMinutes: 0,
    minutesByType: {},
    monthly: [],
    completedCount: 0,
    seenThisYear: 0,
    currentStreak: 0,
    longestStreak: 0,
    longestTitle: null,
    averageRating: null,
  );
}

bool _isWatched(ContentItem i) =>
    i.status == WatchStatus.completed ||
    i.status == WatchStatus.rewatchPending;

/// Calcula las estadísticas de tiempo. [now] es inyectable para tests.
WatchTimeStats computeWatchTimeStats(
  List<ContentItem> items, {
  DateTime? now,
}) {
  final today = now ?? DateTime.now();
  final todayDay = DateTime(today.year, today.month, today.day);
  // Primer día del mes 11 meses atrás → ventana de 12 meses.
  final windowStart = DateTime(today.year, today.month - 11, 1);

  var total = 0;
  var thisYear = 0;
  var thisMonth = 0;
  var completed = 0;
  var seenThisYear = 0;
  final byType = <ContentType, int>{};
  final monthMinutes = <String, int>{};
  final monthCount = <String, int>{};
  final watchedDays = <DateTime>{};
  var ratingSum = 0.0;
  var ratingCount = 0;
  ContentItem? longest;

  String monthKey(DateTime d) => '${d.year}-${d.month}';

  for (final item in items) {
    if (item.userRating != null) {
      ratingSum += item.userRating!;
      ratingCount++;
    }

    if (!_isWatched(item)) continue;

    completed++;
    final minutes = item.watchedMinutes;
    total += minutes;
    byType[item.type] = (byType[item.type] ?? 0) + minutes;

    if (item.totalMinutes > 0 &&
        (longest == null || item.totalMinutes > longest.totalMinutes)) {
      longest = item;
    }

    final wd = item.watchDate;
    if (wd == null || wd.isAfter(today)) continue;
    final day = DateTime(wd.year, wd.month, wd.day);
    watchedDays.add(day);

    if (wd.year == today.year) {
      thisYear += minutes;
      seenThisYear++;
      if (wd.month == today.month) thisMonth += minutes;
    }

    if (!day.isBefore(windowStart)) {
      final key = monthKey(day);
      monthMinutes[key] = (monthMinutes[key] ?? 0) + minutes;
      monthCount[key] = (monthCount[key] ?? 0) + 1;
    }
  }

  // Buckets de los 12 meses de la ventana (incluye meses vacíos).
  final monthly = <MonthBucket>[];
  for (var offset = 0; offset < 12; offset++) {
    final m = DateTime(windowStart.year, windowStart.month + offset, 1);
    final key = monthKey(m);
    monthly.add(MonthBucket(
      month: m,
      minutes: monthMinutes[key] ?? 0,
      count: monthCount[key] ?? 0,
    ));
  }

  // Racha actual: hacia atrás desde hoy (o ayer si aún no hay visionado hoy).
  var current = 0;
  var cursor = todayDay;
  if (!watchedDays.contains(cursor)) {
    cursor = cursor.subtract(const Duration(days: 1));
  }
  while (watchedDays.contains(cursor)) {
    current++;
    cursor = cursor.subtract(const Duration(days: 1));
  }

  // Mejor racha histórica: recorre los días ordenados buscando el tramo
  // consecutivo más largo.
  var longestStreak = 0;
  final sortedDays = watchedDays.toList()..sort();
  var run = 0;
  DateTime? prev;
  for (final day in sortedDays) {
    if (prev != null && day.difference(prev).inDays == 1) {
      run++;
    } else {
      run = 1;
    }
    if (run > longestStreak) longestStreak = run;
    prev = day;
  }

  return WatchTimeStats(
    totalMinutes: total,
    thisYearMinutes: thisYear,
    thisMonthMinutes: thisMonth,
    minutesByType: byType,
    monthly: monthly,
    completedCount: completed,
    seenThisYear: seenThisYear,
    currentStreak: current,
    longestStreak: longestStreak,
    longestTitle: longest,
    averageRating: ratingCount == 0 ? null : ratingSum / ratingCount,
  );
}

final watchTimeStatsProvider = Provider<WatchTimeStats>((ref) {
  final items = ref.watch(contentListProvider).value ?? const <ContentItem>[];
  return computeWatchTimeStats(items);
});
