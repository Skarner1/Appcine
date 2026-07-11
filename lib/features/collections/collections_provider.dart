import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../data/models/collection.dart';
import '../../data/models/content_item.dart';
import '../../providers/providers.dart';

/// Estado persistente de las colecciones personalizadas. Se serializa a JSON
/// en el box de ajustes (clave [_key]), sin TypeAdapter de Hive.
class CollectionsNotifier extends Notifier<List<Collection>> {
  static const _key = 'collections';
  static const _uuid = Uuid();

  @override
  List<Collection> build() {
    final raw = ref.watch(settingsBoxProvider).get(_key) as String?;
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw) as List;
      return decoded
          .map((e) => Collection.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> _persist(List<Collection> next) async {
    state = next;
    await ref
        .read(settingsBoxProvider)
        .put(_key, jsonEncode(next.map((e) => e.toJson()).toList()));
  }

  /// Crea una colección y devuelve su id.
  Future<String> create(String name, {int? color}) async {
    final collection = Collection(
      id: _uuid.v4(),
      name: name.trim(),
      color: color ?? Collection.palette.first.toARGB32(),
      createdAt: DateTime.now(),
    );
    await _persist([...state, collection]);
    return collection.id;
  }

  Future<void> rename(String id, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    await _persist([
      for (final c in state) c.id == id ? c.copyWith(name: trimmed) : c,
    ]);
  }

  Future<void> setColor(String id, int color) async {
    await _persist([
      for (final c in state) c.id == id ? c.copyWith(color: color) : c,
    ]);
  }

  Future<void> delete(String id) async {
    await _persist([for (final c in state) if (c.id != id) c]);
  }

  /// Añade o quita [itemId] de la colección [id].
  Future<void> toggleItem(String id, String itemId) async {
    await _persist([
      for (final c in state) c.id == id ? c.toggle(itemId) : c,
    ]);
  }

  Future<void> removeItem(String id, String itemId) async {
    await _persist([
      for (final c in state)
        c.id == id
            ? c.copyWith(itemIds: [...c.itemIds]..remove(itemId))
            : c,
    ]);
  }
}

final collectionsProvider =
    NotifierProvider<CollectionsNotifier, List<Collection>>(
  CollectionsNotifier.new,
);

/// Contenido de una colección resuelto contra el catálogo, respetando el orden
/// guardado y omitiendo ids cuyo contenido ya no existe.
final collectionItemsProvider =
    Provider.family<List<ContentItem>, String>((ref, collectionId) {
  final collections = ref.watch(collectionsProvider);
  final items = ref.watch(contentListProvider).value ?? const <ContentItem>[];
  final byId = {for (final i in items) i.id: i};

  Collection? collection;
  for (final c in collections) {
    if (c.id == collectionId) {
      collection = c;
      break;
    }
  }
  if (collection == null) return const [];

  return [
    for (final id in collection.itemIds)
      if (byId[id] != null) byId[id]!,
  ];
});

/// Colecciones a las que pertenece un contenido dado (para el detalle).
final collectionsForItemProvider =
    Provider.family<List<Collection>, String>((ref, itemId) {
  final collections = ref.watch(collectionsProvider);
  return [for (final c in collections) if (c.contains(itemId)) c];
});
