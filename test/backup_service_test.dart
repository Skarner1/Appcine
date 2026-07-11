import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:cineapp/data/models/content_item.dart';
import 'package:cineapp/data/services/backup_service.dart';

ContentItem _item(String id) => ContentItem(
      id: id,
      title: 'Título $id',
      type: ContentType.series,
      genres: const ['Drama', 'Misterio'],
      durationMinutes: 45,
      episodes: 8,
      currentEpisode: 3,
      status: WatchStatus.watching,
      userRating: 7.5,
      addedAt: DateTime(2026, 5, 1),
    );

void main() {
  const service = BackupService();

  test('encode → decode conserva los títulos (round-trip)', () {
    final items = [_item('a'), _item('b')];
    final restored = service.decode(service.encode(items));

    expect(restored.length, 2);
    expect(restored.map((e) => e.id), ['a', 'b']);
    expect(restored.first.genres, ['Drama', 'Misterio']);
    expect(restored.first.episodes, 8);
    expect(restored.first.userRating, 7.5);
    expect(restored.first.status, WatchStatus.watching);
  });

  test('encode incluye metadatos de versión y conteo', () {
    final json = jsonDecode(service.encode([_item('a')])) as Map;
    expect(json['app'], 'CineLog Pro');
    expect(json['version'], BackupService.formatVersion);
    expect(json['count'], 1);
    expect(json['items'], isA<List>());
  });

  test('acepta el formato antiguo (lista pelada de items)', () {
    final legacy = jsonEncode([_item('x').toJson()]);
    final restored = service.decode(legacy);
    expect(restored.single.id, 'x');
  });

  test('JSON malformado lanza FormatException', () {
    expect(() => service.decode('no soy json'), throwsFormatException);
  });

  test('JSON válido pero sin items lanza FormatException', () {
    expect(
      () => service.decode(jsonEncode({'foo': 'bar'})),
      throwsFormatException,
    );
  });

  test('items con estructura incorrecta lanza FormatException', () {
    final bad = jsonEncode({
      'items': [
        {'no': 'tiene id ni title'},
      ],
    });
    expect(() => service.decode(bad), throwsFormatException);
  });
}
