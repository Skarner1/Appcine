import 'package:cineapp/data/migrations.dart';
import 'package:cineapp/data/models/content_item.dart';
import 'package:cineapp/data/models/watch_event.dart';
import 'package:cineapp/features/stats/watch_time_stats.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime(2026, 7, 15, 20);

ContentItem _movie({
  required String id,
  int duration = 120,
  WatchStatus status = WatchStatus.completed,
  DateTime? watchDate,
  int? rewatchCount,
  List<WatchEvent> watchLog = const [],
}) {
  return ContentItem(
    id: id,
    title: 'Peli $id',
    type: ContentType.movie,
    durationMinutes: duration,
    status: status,
    watchDate: watchDate,
    rewatchCount: rewatchCount,
    watchLog: watchLog,
    addedAt: DateTime(2020),
  );
}

ContentItem _series({
  required String id,
  int perEpisode = 30,
  int episodes = 10,
  int? currentEpisode,
  WatchStatus status = WatchStatus.watching,
  DateTime? watchDate,
  List<WatchEvent> watchLog = const [],
}) {
  return ContentItem(
    id: id,
    title: 'Serie $id',
    type: ContentType.series,
    durationMinutes: perEpisode,
    episodes: episodes,
    currentEpisode: currentEpisode,
    status: status,
    watchDate: watchDate,
    watchLog: watchLog,
    addedAt: DateTime(2020),
  );
}

void main() {
  group('logProgressSince', () {
    test('ver una peli por primera vez anota su duración', () {
      final before = _movie(id: 'a', status: WatchStatus.notStarted);
      final after = before.copyWith(status: WatchStatus.completed);

      final logged = after.logProgressSince(before, at: _now);

      expect(logged.watchLog, [
        WatchEvent(date: _now, minutes: 120),
      ]);
    });

    test('revisar una peli anota otro evento, no pisa el anterior', () {
      final first = DateTime(2026, 1, 1);
      final before = _movie(
        id: 'a',
        rewatchCount: 0,
        watchLog: [WatchEvent(date: first, minutes: 120)],
      );
      final after = before.copyWith(rewatchCount: 1);

      final logged = after.logProgressSince(before, at: _now);

      expect(logged.watchLog, [
        WatchEvent(date: first, minutes: 120),
        WatchEvent(date: _now, minutes: 120),
      ]);
    });

    test('avanzar episodios anota solo el tramo nuevo', () {
      final before = _series(id: 's', currentEpisode: 2);
      final after = before.copyWith(currentEpisode: 5);

      final logged = after.logProgressSince(before, at: _now);

      // 3 episodios nuevos x 30 min.
      expect(logged.watchLog, [
        WatchEvent(date: _now, minutes: 90, episodes: 3),
      ]);
    });

    test('corregir el contador hacia atrás no anota nada', () {
      final before = _series(id: 's', currentEpisode: 5);
      final after = before.copyWith(currentEpisode: 2);

      final logged = after.logProgressSince(before, at: _now);

      expect(logged.watchLog, isEmpty);
      expect(identical(logged, after), isTrue);
    });

    test('guardar sin ver nada nuevo no anota nada', () {
      final before = _movie(id: 'a', watchLog: [WatchEvent(date: _now, minutes: 120)]);
      final after = before.copyWith(isFavorite: true);

      expect(after.logProgressSince(before, at: _now).watchLog.length, 1);
    });

    test('el diario suma lo mismo que watchedMinutes', () {
      final before = _series(id: 's', currentEpisode: 0);
      final mid = before.copyWith(currentEpisode: 4).logProgressSince(before, at: _now);
      final end = mid
          .copyWith(currentEpisode: 10, status: WatchStatus.completed)
          .logProgressSince(mid, at: _now);

      expect(end.loggedMinutes, end.watchedMinutes);
      expect(end.loggedMinutes, 300);
    });
  });

  group('migrateWatchLog', () {
    test('crea un solo evento con todos los minutos, sin inventar fechas', () {
      final seen = DateTime(2026, 3, 10);
      // Vista 3 veces (2 repeticiones) pero solo hay una fecha guardada.
      final item = _movie(id: 'a', watchDate: seen, rewatchCount: 2);

      final migrated = migrateWatchLog([item], now: _now);

      expect(migrated, hasLength(1));
      expect(migrated.single.watchLog, [
        WatchEvent(date: seen, minutes: 360), // 120 x 3, todo en su fecha
      ]);
    });

    test('los totales que ya mostraba la app no se mueven', () {
      final item = _movie(id: 'a', watchDate: DateTime(2026, 3, 10), rewatchCount: 2);

      final antes = computeWatchTimeStats([item], now: _now);
      final despues = computeWatchTimeStats(migrateWatchLog([item], now: _now), now: _now);

      expect(despues.totalMinutes, antes.totalMinutes);
      expect(despues.thisYearMinutes, antes.thisYearMinutes);
      expect(despues.completedCount, antes.completedCount);
    });

    test('se salta los que ya tienen diario', () {
      final item = _movie(
        id: 'a',
        watchDate: DateTime(2026, 3, 10),
        watchLog: [WatchEvent(date: DateTime(2026, 3, 10), minutes: 120)],
      );

      expect(migrateWatchLog([item], now: _now), isEmpty);
    });

    test('se salta los no vistos y los de fecha futura', () {
      final pendiente = _movie(
        id: 'a',
        status: WatchStatus.notStarted,
        watchDate: DateTime(2026, 3, 10),
      );
      // watchDate futura significa "planeo verlo", no "lo vi".
      final programada = _movie(id: 'b', watchDate: DateTime(2026, 12, 24));

      expect(migrateWatchLog([pendiente, programada], now: _now), isEmpty);
    });

    test('se salta los vistos sin fecha', () {
      expect(migrateWatchLog([_movie(id: 'a')], now: _now), isEmpty);
    });
  });

  group('stats con diario', () {
    test('las repeticiones caen en su propio día, no todas en uno', () {
      // Misma peli vista en tres meses distintos del año.
      final item = _movie(
        id: 'a',
        rewatchCount: 2,
        watchDate: DateTime(2026, 7, 1),
        watchLog: [
          WatchEvent(date: DateTime(2026, 5, 1), minutes: 120),
          WatchEvent(date: DateTime(2026, 6, 1), minutes: 120),
          WatchEvent(date: DateTime(2026, 7, 1), minutes: 120),
        ],
      );

      final stats = computeWatchTimeStats([item], now: _now);

      expect(stats.totalMinutes, 360);
      expect(stats.thisYearMinutes, 360);
      // Solo el visionado de julio cae en el mes en curso.
      expect(stats.thisMonthMinutes, 120);
      // El título cuenta una vez al año aunque se haya visto tres.
      expect(stats.seenThisYear, 1);

      final julio = stats.monthly.firstWhere((b) => b.month == DateTime(2026, 7));
      final mayo = stats.monthly.firstWhere((b) => b.month == DateTime(2026, 5));
      expect(julio.minutes, 120);
      expect(mayo.minutes, 120);
    });

    test('las rachas cuentan cada visionado en su día', () {
      final item = _movie(
        id: 'a',
        rewatchCount: 2,
        watchLog: [
          WatchEvent(date: DateTime(2026, 7, 13), minutes: 120),
          WatchEvent(date: DateTime(2026, 7, 14), minutes: 120),
          WatchEvent(date: DateTime(2026, 7, 15), minutes: 120),
        ],
      );

      final stats = computeWatchTimeStats([item], now: _now);

      // Antes del diario esto era 1: las 3 vueltas compartían watchDate.
      expect(stats.currentStreak, 3);
      expect(stats.longestStreak, 3);
    });

    test('los eventos futuros no cuentan todavía', () {
      final item = _movie(
        id: 'a',
        watchLog: [
          WatchEvent(date: DateTime(2026, 7, 10), minutes: 120),
          WatchEvent(date: DateTime(2026, 12, 24), minutes: 120),
        ],
      );

      expect(computeWatchTimeStats([item], now: _now).totalMinutes, 120);
    });

    test('sin diario se sigue estimando desde la duración', () {
      final item = _movie(id: 'a', watchDate: DateTime(2026, 7, 10), rewatchCount: 1);

      final stats = computeWatchTimeStats([item], now: _now);

      expect(stats.totalMinutes, 240);
      expect(stats.thisMonthMinutes, 240);
    });
  });
}
