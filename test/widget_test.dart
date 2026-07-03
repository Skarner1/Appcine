import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:cineapp/data/models/content_adapters.dart';
import 'package:cineapp/data/models/content_item.dart';
import 'package:cineapp/data/repositories/content_repository.dart';

void main() {
  late Directory tempDir;
  late Box<ContentItem> box;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('cinelog_test');
    Hive.init(tempDir.path);
    Hive.registerAdapter(ContentItemAdapter());
    box = await Hive.openBox<ContentItem>('content_test');
  });

  tearDownAll(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  ContentItem buildItem({String id = 'test-1'}) => ContentItem(
        id: id,
        title: 'Interstellar',
        type: ContentType.movie,
        genres: const ['Ciencia Ficción', 'Drama'],
        durationMinutes: 169,
        status: WatchStatus.completed,
        userRating: 9.5,
        personalNote: 'Obra maestra',
        watchDate: DateTime(2026, 6, 1, 20, 30),
        releaseDate: DateTime(2014, 11, 7),
        addedAt: DateTime(2026, 5, 20),
        source: ContentSource.friendRecommended,
        recommendedBy: 'Juan',
        recommendedNote: 'Tienes que verla',
        notifyMe: true,
        notificationDate: DateTime(2026, 12, 24, 21),
        rewatchCount: 2,
        isFavorite: true,
      );

  test('El adapter de Hive conserva todos los campos (round-trip)', () async {
    final original = buildItem();
    await box.put(original.id, original);

    final restored = box.get(original.id);

    expect(restored, isNotNull);
    expect(restored!.id, original.id);
    expect(restored.title, original.title);
    expect(restored.type, ContentType.movie);
    expect(restored.genres, original.genres);
    expect(restored.durationMinutes, 169);
    expect(restored.episodes, isNull);
    expect(restored.status, WatchStatus.completed);
    expect(restored.userRating, 9.5);
    expect(restored.personalNote, 'Obra maestra');
    expect(restored.watchDate, original.watchDate);
    expect(restored.releaseDate, original.releaseDate);
    expect(restored.addedAt, original.addedAt);
    expect(restored.source, ContentSource.friendRecommended);
    expect(restored.recommendedBy, 'Juan');
    expect(restored.recommendedNote, 'Tienes que verla');
    expect(restored.notifyMe, isTrue);
    expect(restored.notificationDate, original.notificationDate);
    expect(restored.rewatchCount, 2);
    expect(restored.isFavorite, isTrue);
  });

  test('El repositorio guarda, lista y elimina', () async {
    final repo = ContentRepository(box);
    final item = buildItem(id: 'repo-1');

    await repo.save(item);
    expect(repo.getById('repo-1')?.title, 'Interstellar');
    expect(repo.getAll().any((i) => i.id == 'repo-1'), isTrue);

    await repo.delete('repo-1');
    expect(repo.getById('repo-1'), isNull);
  });

  test('JSON export/import conserva los datos', () {
    final original = buildItem(id: 'json-1');
    final restored = ContentItem.fromJson(original.toJson());

    expect(restored.id, original.id);
    expect(restored.title, original.title);
    expect(restored.type, original.type);
    expect(restored.status, original.status);
    expect(restored.source, original.source);
    expect(restored.watchDate, original.watchDate);
    expect(restored.userRating, original.userRating);
    expect(restored.isFavorite, original.isFavorite);
  });

  test('watchedMinutes calcula series por episodios vistos', () {
    final series = ContentItem(
      id: 's1',
      title: 'Breaking Bad',
      type: ContentType.series,
      durationMinutes: 47,
      episodes: 62,
      currentEpisode: 10,
      status: WatchStatus.watching,
      addedAt: DateTime.now(),
    );
    expect(series.watchedMinutes, 470);
    expect(series.totalMinutes, 47 * 62);
    expect(series.episodeProgress, closeTo(10 / 62, 0.001));
  });
}
