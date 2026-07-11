import 'package:flutter_test/flutter_test.dart';

import 'package:cineapp/data/models/content_item.dart';
import 'package:cineapp/features/stats/watch_time_stats.dart';

ContentItem _item({
  required String id,
  ContentType type = ContentType.movie,
  WatchStatus status = WatchStatus.completed,
  int duration = 120,
  int? episodes,
  int? currentEpisode,
  double? rating,
  DateTime? watchDate,
  int? rewatchCount,
}) {
  return ContentItem(
    id: id,
    title: id,
    type: type,
    status: status,
    durationMinutes: duration,
    episodes: episodes,
    currentEpisode: currentEpisode,
    userRating: rating,
    watchDate: watchDate,
    rewatchCount: rewatchCount,
    addedAt: DateTime(2026, 1, 1),
  );
}

void main() {
  final now = DateTime(2026, 7, 11);

  test('catálogo vacío → stats vacías', () {
    final s = computeWatchTimeStats(const [], now: now);
    expect(s.isEmpty, isTrue);
    expect(s.totalMinutes, 0);
    expect(s.averageRating, isNull);
  });

  test('suma minutos solo de lo visto y por tipo', () {
    final s = computeWatchTimeStats([
      _item(id: 'peli', duration: 120, watchDate: DateTime(2026, 7, 1)),
      _item(
        id: 'serie',
        type: ContentType.series,
        duration: 40,
        episodes: 10,
        currentEpisode: 10,
        watchDate: DateTime(2026, 6, 15),
      ),
      _item(id: 'pendiente', status: WatchStatus.notStarted, duration: 200),
    ], now: now);

    // peli 120 + serie 40*10=400 = 520; la pendiente no cuenta.
    expect(s.totalMinutes, 520);
    expect(s.minutesByType[ContentType.movie], 120);
    expect(s.minutesByType[ContentType.series], 400);
    expect(s.completedCount, 2);
    expect(s.longestTitle?.id, 'serie'); // 400 min de total
  });

  test('rewatch multiplica los minutos', () {
    final s = computeWatchTimeStats([
      _item(
        id: 'reloj',
        duration: 100,
        rewatchCount: 2, // vista 3 veces → 300
        watchDate: DateTime(2026, 7, 5),
      ),
    ], now: now);
    expect(s.totalMinutes, 300);
  });

  test('divide por periodo (mes/año) según watchDate', () {
    final s = computeWatchTimeStats([
      _item(id: 'jul', duration: 100, watchDate: DateTime(2026, 7, 3)),
      _item(id: 'mar', duration: 60, watchDate: DateTime(2026, 3, 20)),
      _item(id: 'ene25', duration: 90, watchDate: DateTime(2025, 1, 10)),
    ], now: now);

    expect(s.thisMonthMinutes, 100); // solo julio 2026
    expect(s.thisYearMinutes, 160); // julio + marzo 2026
    expect(s.seenThisYear, 2);
    // Ventana de 12 meses: ago-2025 … jul-2026 → 12 buckets.
    expect(s.monthly.length, 12);
    final julBucket = s.monthly.last;
    expect(julBucket.month.month, 7);
    expect(julBucket.minutes, 100);
  });

  test('racha actual y mejor racha', () {
    final s = computeWatchTimeStats([
      // Racha actual: 10 y 11 de julio (hoy).
      _item(id: 'a', watchDate: DateTime(2026, 7, 11)),
      _item(id: 'b', watchDate: DateTime(2026, 7, 10)),
      // Racha histórica más larga: 1,2,3 de junio.
      _item(id: 'c', watchDate: DateTime(2026, 6, 1)),
      _item(id: 'd', watchDate: DateTime(2026, 6, 2)),
      _item(id: 'e', watchDate: DateTime(2026, 6, 3)),
    ], now: now);

    expect(s.currentStreak, 2);
    expect(s.longestStreak, 3);
  });

  test('nota media sobre lo puntuado', () {
    final s = computeWatchTimeStats([
      _item(id: 'x', rating: 8, watchDate: now),
      _item(id: 'y', rating: 6, watchDate: now),
      _item(id: 'z'), // sin nota
    ], now: now);
    expect(s.averageRating, 7.0);
  });
}
