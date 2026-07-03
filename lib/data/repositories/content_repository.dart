import 'package:hive/hive.dart';

import '../models/content_item.dart';

/// Repositorio local offline-first sobre Hive.
class ContentRepository {
  ContentRepository(this._box);

  final Box<ContentItem> _box;

  List<ContentItem> getAll() {
    final items = _box.values.toList();
    items.sort((a, b) => b.addedAt.compareTo(a.addedAt));
    return items;
  }

  /// Emite la lista completa al suscribirse y en cada cambio del box.
  Stream<List<ContentItem>> watchAll() async* {
    yield getAll();
    yield* _box.watch().map((_) => getAll());
  }

  ContentItem? getById(String id) => _box.get(id);

  Future<void> save(ContentItem item) => _box.put(item.id, item);

  Future<void> saveAll(Iterable<ContentItem> items) =>
      _box.putAll({for (final item in items) item.id: item});

  Future<void> delete(String id) => _box.delete(id);

  Future<void> clear() => _box.clear();

  int get count => _box.length;
}
