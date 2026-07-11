import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:cineapp/data/models/collection.dart';
import 'package:cineapp/data/models/content_item.dart';
import 'package:cineapp/data/repositories/content_repository.dart';
import 'package:cineapp/features/collections/collections_provider.dart';
import 'package:cineapp/providers/providers.dart';

ContentItem _item(String id) => ContentItem(
      id: id,
      title: 'Título $id',
      type: ContentType.movie,
      addedAt: DateTime(2026, 1, 1),
    );

class _FakeRepo implements ContentRepository {
  _FakeRepo(this._items);
  final List<ContentItem> _items;

  @override
  Stream<List<ContentItem>> watchAll() => Stream.value(_items);

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('Collection model', () {
    test('toggle añade y quita conservando el orden', () {
      var c = Collection(
        id: '1',
        name: 'X',
        color: 0xFFFFFFFF,
        createdAt: DateTime(2026),
      );
      c = c.toggle('a');
      c = c.toggle('b');
      expect(c.itemIds, ['a', 'b']);
      c = c.toggle('a'); // quita
      expect(c.itemIds, ['b']);
    });

    test('json round-trip', () {
      final c = Collection(
        id: 'id1',
        name: 'Halloween',
        color: 0xFF112233,
        itemIds: const ['x', 'y'],
        createdAt: DateTime(2026, 5, 4),
      );
      final restored = Collection.fromJson(c.toJson());
      expect(restored.id, 'id1');
      expect(restored.name, 'Halloween');
      expect(restored.color, 0xFF112233);
      expect(restored.itemIds, ['x', 'y']);
      expect(restored.createdAt, DateTime(2026, 5, 4));
    });
  });

  group('CollectionsNotifier', () {
    late Directory dir;
    late Box<dynamic> box;

    setUp(() async {
      dir = Directory.systemTemp.createTempSync('cinelog_collections');
      Hive.init(dir.path);
      box = await Hive.openBox<dynamic>('settings_test');
    });

    tearDown(() async {
      await box.close();
      await Hive.deleteBoxFromDisk('settings_test');
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });

    ProviderContainer makeContainer({List<ContentItem> items = const []}) {
      final container = ProviderContainer(overrides: [
        settingsBoxProvider.overrideWithValue(box),
        contentRepositoryProvider.overrideWithValue(_FakeRepo(items)),
      ]);
      addTearDown(container.dispose);
      return container;
    }

    test('crear, renombrar, colorear, alternar y borrar', () async {
      final container = makeContainer();
      final notifier = container.read(collectionsProvider.notifier);

      final id = await notifier.create('Halloween', color: 0xFF00FF00);
      expect(container.read(collectionsProvider).length, 1);

      await notifier.toggleItem(id, 'a');
      await notifier.toggleItem(id, 'b');
      expect(container.read(collectionsProvider).first.itemIds, ['a', 'b']);

      await notifier.toggleItem(id, 'a'); // quita 'a'
      expect(container.read(collectionsProvider).first.itemIds, ['b']);

      await notifier.rename(id, 'Terror');
      await notifier.setColor(id, 0xFFFF0000);
      final c = container.read(collectionsProvider).first;
      expect(c.name, 'Terror');
      expect(c.color, 0xFFFF0000);

      await notifier.delete(id);
      expect(container.read(collectionsProvider), isEmpty);
    });

    test('persisten entre instancias (se releen del box)', () async {
      final c1 = makeContainer();
      await c1.read(collectionsProvider.notifier).create('Favoritas');

      // Nuevo contenedor con el mismo box → debe leer lo guardado.
      final c2 = ProviderContainer(overrides: [
        settingsBoxProvider.overrideWithValue(box),
        contentRepositoryProvider.overrideWithValue(_FakeRepo(const [])),
      ]);
      addTearDown(c2.dispose);
      expect(c2.read(collectionsProvider).single.name, 'Favoritas');
    });

    test('collectionItemsProvider resuelve en orden y omite ids inexistentes',
        () async {
      final container = makeContainer(items: [_item('a'), _item('b'), _item('c')]);
      container.listen(contentListProvider, (_, _) {});
      await Future<void>.delayed(Duration.zero);

      final notifier = container.read(collectionsProvider.notifier);
      final id = await notifier.create('Mix');
      await notifier.toggleItem(id, 'c');
      await notifier.toggleItem(id, 'a');
      await notifier.toggleItem(id, 'fantasma'); // ya no existe en catálogo

      final resolved = container.read(collectionItemsProvider(id));
      expect(resolved.map((e) => e.id), ['c', 'a']);
    });

    test('collectionsForItemProvider lista las colecciones con el título',
        () async {
      final container = makeContainer(items: [_item('a')]);
      container.listen(contentListProvider, (_, _) {});
      await Future<void>.delayed(Duration.zero);
      final notifier = container.read(collectionsProvider.notifier);

      final id1 = await notifier.create('Uno');
      await notifier.create('Dos');
      await notifier.toggleItem(id1, 'a');

      final forA = container.read(collectionsForItemProvider('a'));
      expect(forA.map((c) => c.name), ['Uno']);
    });
  });
}
