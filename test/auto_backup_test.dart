import 'dart:io';

import 'package:cineapp/data/models/content_item.dart';
import 'package:cineapp/data/services/auto_backup_service.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime(2026, 7, 15, 20, 30);

ContentItem _item(String id) => ContentItem(
      id: id,
      title: 'Título $id',
      type: ContentType.movie,
      durationMinutes: 120,
      addedAt: DateTime(2026),
    );

void main() {
  group('shouldRun', () {
    bool run({
      bool enabled = true,
      DateTime? lastRun,
      BackupFrequency frequency = BackupFrequency.daily,
      bool hasContent = true,
      DateTime? now,
    }) {
      return AutoBackupService.shouldRun(
        enabled: enabled,
        lastRun: lastRun,
        frequency: frequency,
        hasContent: hasContent,
        now: now ?? _now,
      );
    }

    test('apagado no hace nada', () {
      expect(run(enabled: false, lastRun: null), isFalse);
    });

    test('la primera copia toca siempre', () {
      expect(run(lastRun: null), isTrue);
    });

    test('un catálogo vacío no se copia: pisaría las copias buenas', () {
      expect(run(lastRun: null, hasContent: false), isFalse);
    });

    test('a diario: pasadas 24 h toca, antes no', () {
      expect(run(lastRun: _now.subtract(const Duration(hours: 23))), isFalse);
      expect(run(lastRun: _now.subtract(const Duration(hours: 25))), isTrue);
    });

    test('semanal: espera los 7 días', () {
      expect(
        run(
          lastRun: _now.subtract(const Duration(days: 3)),
          frequency: BackupFrequency.weekly,
        ),
        isFalse,
      );
      expect(
        run(
          lastRun: _now.subtract(const Duration(days: 8)),
          frequency: BackupFrequency.weekly,
        ),
        isTrue,
      );
    });

    test('un reloj movido al pasado no congela la copia para siempre', () {
      // lastRun en el futuro: pasaría si el usuario cambia la fecha del móvil.
      expect(run(lastRun: _now.add(const Duration(days: 30))), isTrue);
    });
  });

  group('nombres de archivo', () {
    test('el nombre lleva la fecha y se puede volver a leer', () {
      final name = AutoBackupService.fileNameFor(_now);

      expect(name, 'cinelog_auto_2026-07-15_2030.json');
      expect(AutoBackupService.dateFromName(name), _now);
    });

    test('ordenar por nombre ordena por fecha', () {
      final names = [
        AutoBackupService.fileNameFor(DateTime(2026, 7, 15, 9, 5)),
        AutoBackupService.fileNameFor(DateTime(2026, 1, 2, 23, 59)),
        AutoBackupService.fileNameFor(DateTime(2026, 7, 15, 10, 0)),
      ]..sort();

      expect(names.map(AutoBackupService.dateFromName), [
        DateTime(2026, 1, 2, 23, 59),
        DateTime(2026, 7, 15, 9, 5),
        DateTime(2026, 7, 15, 10, 0),
      ]);
    });

    test('los archivos ajenos se ignoran', () {
      expect(AutoBackupService.dateFromName('otra_cosa.json'), isNull);
      expect(AutoBackupService.dateFromName('cinelog_backup_manual.json'), isNull);
      expect(AutoBackupService.dateFromName('cinelog_auto_mal.json'), isNull);
    });
  });

  group('run, list y rotación', () {
    late Directory tmp;
    late AutoBackupService service;

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('auto_backup_test');
      service = AutoBackupService(directory: tmp);
    });

    tearDown(() {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    });

    test('escribe una copia que se puede volver a leer', () async {
      final items = [_item('a'), _item('b')];

      final path = await service.run(items, now: _now);

      expect(path, isNotNull);
      expect(File(path!).existsSync(), isTrue);
      expect((await service.read(path)).map((e) => e.id), ['a', 'b']);
    });

    test('list devuelve de la más nueva a la más vieja', () async {
      await service.run([_item('a')], now: DateTime(2026, 7, 13, 10));
      await service.run([_item('a')], now: DateTime(2026, 7, 15, 10));
      await service.run([_item('a')], now: DateTime(2026, 7, 14, 10));

      final backups = await service.list();

      expect(backups.map((b) => b.date), [
        DateTime(2026, 7, 15, 10),
        DateTime(2026, 7, 14, 10),
        DateTime(2026, 7, 13, 10),
      ]);
    });

    test('solo se guardan las últimas y se tiran las viejas', () async {
      // Una copia al día durante 8 días.
      for (var day = 1; day <= 8; day++) {
        await service.run([_item('a')], now: DateTime(2026, 7, day, 10));
      }

      final backups = await service.list();

      expect(backups, hasLength(AutoBackupService.keepCount));
      // Sobreviven las 5 más recientes: del 4 al 8.
      expect(backups.first.date, DateTime(2026, 7, 8, 10));
      expect(backups.last.date, DateTime(2026, 7, 4, 10));
    });

    test('no toca los archivos que no son suyos', () async {
      final ajeno = File('${tmp.path}/no_es_mio.json')..writeAsStringSync('{}');
      for (var day = 1; day <= 8; day++) {
        await service.run([_item('a')], now: DateTime(2026, 7, day, 10));
      }

      expect(ajeno.existsSync(), isTrue);
      expect(await service.list(), hasLength(AutoBackupService.keepCount));
    });

    test('leer una copia dañada avisa en vez de reventar', () async {
      final roto = File('${tmp.path}/${AutoBackupService.fileNameFor(_now)}')
        ..writeAsStringSync('esto no es json');

      expect(
        () => service.read(roto.path),
        throwsA(isA<FormatException>()),
      );
    });

    test('sin copias, list no se queja', () async {
      expect(await service.list(), isEmpty);
    });
  });
}
