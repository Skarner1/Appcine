import 'package:cineapp/data/models/content_item.dart';
import 'package:cineapp/data/models/watch_event.dart';
import 'package:cineapp/features/reminders/stalled_reminders.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime(2026, 7, 15, 12);

ContentItem _item({
  required String id,
  String? title,
  WatchStatus status = WatchStatus.watching,
  DateTime? addedAt,
  DateTime? watchDate,
  List<WatchEvent> watchLog = const [],
  bool notifyMe = false,
  DateTime? notificationDate,
}) {
  return ContentItem(
    id: id,
    title: title ?? 'Serie $id',
    type: ContentType.series,
    durationMinutes: 30,
    episodes: 10,
    status: status,
    watchDate: watchDate,
    watchLog: watchLog,
    notifyMe: notifyMe,
    notificationDate: notificationDate,
    addedAt: addedAt ?? DateTime(2026),
  );
}

void main() {
  group('lastActivityOf', () {
    test('manda el último visionado del diario', () {
      final item = _item(
        id: 'a',
        addedAt: DateTime(2026, 1, 1),
        watchDate: DateTime(2026, 2, 1),
        watchLog: [
          WatchEvent(date: DateTime(2026, 3, 1), minutes: 30),
          WatchEvent(date: DateTime(2026, 6, 1), minutes: 30),
        ],
      );

      expect(lastActivityOf(item, now: _now), DateTime(2026, 6, 1));
    });

    test('sin diario cae a watchDate', () {
      final item = _item(
        id: 'a',
        addedAt: DateTime(2026, 1, 1),
        watchDate: DateTime(2026, 2, 1),
      );

      expect(lastActivityOf(item, now: _now), DateTime(2026, 2, 1));
    });

    test('sin nada cae a cuándo se añadió', () {
      final item = _item(id: 'a', addedAt: DateTime(2026, 1, 1));

      expect(lastActivityOf(item, now: _now), DateTime(2026, 1, 1));
    });

    test('los eventos futuros no cuentan como actividad', () {
      final item = _item(
        id: 'a',
        addedAt: DateTime(2026, 1, 1),
        watchLog: [
          WatchEvent(date: DateTime(2026, 3, 1), minutes: 30),
          WatchEvent(date: DateTime(2026, 12, 24), minutes: 30),
        ],
      );

      expect(lastActivityOf(item, now: _now), DateTime(2026, 3, 1));
    });
  });

  group('findStalled', () {
    test('encuentra lo parado más de la cuenta', () {
      final parada = _item(
        id: 'a',
        watchLog: [WatchEvent(date: DateTime(2026, 6, 1), minutes: 30)],
      );
      final reciente = _item(
        id: 'b',
        watchLog: [WatchEvent(date: DateTime(2026, 7, 14), minutes: 30)],
      );

      final stalled = findStalled(
        [parada, reciente],
        after: const Duration(days: 14),
        now: _now,
      );

      expect(stalled.map((s) => s.item.id), ['a']);
      expect(stalled.single.daysStalled, 44);
    });

    test('no da la lata con lo pausado ni lo abandonado', () {
      final vieja = DateTime(2026, 1, 1);
      final items = [
        _item(id: 'pausada', status: WatchStatus.onHold, watchDate: vieja),
        _item(id: 'abandonada', status: WatchStatus.dropped, watchDate: vieja),
        _item(id: 'vista', status: WatchStatus.completed, watchDate: vieja),
        _item(id: 'sin-empezar', status: WatchStatus.notStarted, watchDate: vieja),
      ];

      expect(findStalled(items, after: const Duration(days: 14), now: _now), isEmpty);
    });

    test('no avisa de lo que ya tiene recordatorio propio', () {
      final item = _item(
        id: 'a',
        watchDate: DateTime(2026, 1, 1),
        notifyMe: true,
        notificationDate: DateTime(2026, 8, 1),
      );

      expect(findStalled([item], after: const Duration(days: 14), now: _now), isEmpty);
    });

    test('ordena del más abandonado al menos', () {
      final items = [
        _item(id: 'medio', watchDate: DateTime(2026, 5, 1)),
        _item(id: 'el-peor', watchDate: DateTime(2026, 1, 1)),
        _item(id: 'reciente', watchDate: DateTime(2026, 6, 20)),
      ];

      final stalled = findStalled(items, after: const Duration(days: 14), now: _now);

      expect(stalled.map((s) => s.item.id), ['el-peor', 'medio', 'reciente']);
    });

    test('el plazo se respeta: justo por debajo no entra', () {
      final item = _item(id: 'a', watchDate: _now.subtract(const Duration(days: 13)));

      expect(findStalled([item], after: const Duration(days: 14), now: _now), isEmpty);
    });
  });

  group('humanizeStalled', () {
    test('habla como una persona', () {
      expect(humanizeStalled(3), '3 días');
      expect(humanizeStalled(7), 'una semana');
      expect(humanizeStalled(21), '3 semanas');
      expect(humanizeStalled(30), 'un mes');
      expect(humanizeStalled(90), '3 meses');
      expect(humanizeStalled(400), 'un año');
      expect(humanizeStalled(800), '2 años');
    });
  });

  group('stalledMessage', () {
    List<StalledItem> stalledOf(List<ContentItem> items) =>
        findStalled(items, after: const Duration(days: 14), now: _now);

    test('con uno solo va al grano', () {
      final items = [
        _item(id: 'a', title: 'Dark', watchDate: DateTime(2026, 6, 24)),
      ];

      expect(
        stalledMessage(stalledOf(items)),
        'Llevas 3 semanas sin ver "Dark". ¿Lo retomas?',
      );
    });

    test('con dos menciona el otro en singular', () {
      final items = [
        _item(id: 'a', title: 'Dark', watchDate: DateTime(2026, 6, 24)),
        _item(id: 'b', title: 'Fargo', watchDate: DateTime(2026, 6, 25)),
      ];

      expect(
        stalledMessage(stalledOf(items)),
        'Llevas 3 semanas sin ver "Dark", y tienes otro título a medias.',
      );
    });

    test('con muchos nombra solo el peor y cuenta el resto', () {
      final items = [
        _item(id: 'a', title: 'Dark', watchDate: DateTime(2026, 6, 24)),
        _item(id: 'b', title: 'Fargo', watchDate: DateTime(2026, 6, 25)),
        _item(id: 'c', title: 'Severance', watchDate: DateTime(2026, 6, 26)),
      ];

      expect(
        stalledMessage(stalledOf(items)),
        'Llevas 3 semanas sin ver "Dark", y tienes 2 títulos más a medias.',
      );
    });
  });

  group('nextReminderSlot', () {
    test('deja al menos 12 h de colchón', () {
      // A las 12:00 el hueco de hoy (20:00) está a solo 8 h: se va a mañana.
      expect(
        nextReminderSlot(DateTime(2026, 7, 15, 12)),
        DateTime(2026, 7, 16, 20),
      );
    });

    test('de madrugada sí cabe el de hoy', () {
      // A las 2:00, las 20:00 de hoy están a 18 h.
      expect(
        nextReminderSlot(DateTime(2026, 7, 15, 2)),
        DateTime(2026, 7, 15, 20),
      );
    });

    test('siempre cae en el futuro', () {
      for (var hour = 0; hour < 24; hour++) {
        final now = DateTime(2026, 7, 15, hour, 30);
        expect(nextReminderSlot(now).isAfter(now), isTrue, reason: 'hora $hour');
      }
    });
  });
}
