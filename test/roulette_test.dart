import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cineapp/core/theme/app_theme.dart';
import 'package:cineapp/data/models/content_item.dart';
import 'package:cineapp/data/repositories/content_repository.dart';
import 'package:cineapp/features/roulette/roulette_screen.dart';
import 'package:cineapp/providers/providers.dart';

ContentItem _item({
  required String id,
  required String title,
  ContentType type = ContentType.movie,
  WatchStatus status = WatchStatus.notStarted,
  List<String> genres = const [],
  int duration = 100,
}) {
  return ContentItem(
    id: id,
    title: title,
    type: type,
    status: status,
    genres: genres,
    durationMinutes: duration,
    addedAt: DateTime(2026, 1, 1),
  );
}

/// Repo en memoria para inyectar un catálogo fijo en el widget.
class _FakeRepo implements ContentRepository {
  _FakeRepo(this._items);
  final List<ContentItem> _items;

  @override
  Stream<List<ContentItem>> watchAll() => Stream.value(_items);

  @override
  ContentItem? getById(String id) {
    for (final i in _items) {
      if (i.id == id) return i;
    }
    return null;
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('rouletteCandidates', () {
    final catalog = [
      _item(id: '1', title: 'Peli corta', duration: 50),
      _item(id: '2', title: 'Peli larga', duration: 140),
      _item(
        id: '3',
        title: 'Vista',
        status: WatchStatus.completed,
      ),
      _item(
        id: '4',
        title: 'Serie pendiente',
        type: ContentType.series,
        genres: const ['Drama'],
        duration: 45,
      ),
      _item(id: '5', title: 'Sin duración', duration: 0),
    ];

    test('excluye lo ya visto', () {
      final result = rouletteCandidates(catalog, const RouletteFilter());
      expect(result.map((e) => e.id), isNot(contains('3')));
      expect(result.length, 4);
    });

    test('filtra por tipo', () {
      final result = rouletteCandidates(
        catalog,
        const RouletteFilter(type: ContentType.series),
      );
      expect(result.map((e) => e.id), ['4']);
    });

    test('filtra por género', () {
      final result = rouletteCandidates(
        catalog,
        const RouletteFilter(genre: 'Drama'),
      );
      expect(result.map((e) => e.id), ['4']);
    });

    test('duración máx. excluye largas y las de duración desconocida', () {
      final result = rouletteCandidates(
        catalog,
        const RouletteFilter(maxMinutes: 60),
      );
      // '1' (50) y '4' (45) entran; '2' (140) fuera; '5' (0) fuera.
      expect(result.map((e) => e.id).toSet(), {'1', '4'});
    });
  });

  testWidgets('girar la ruleta revela un resultado', (tester) async {
    final repo = _FakeRepo([
      _item(id: '1', title: 'Ganadora', duration: 90),
    ]);

    await tester.pumpWidget(ProviderScope(
      overrides: [contentRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(
        theme: AppTheme.dark(),
        home: RouletteScreen(random: Random(1)),
      ),
    ));
    await tester.pumpAndSettle();

    // Estado inicial: un título en juego, botón Girar visible.
    expect(find.text('1 título en juego'), findsOneWidget);
    expect(find.text('Girar'), findsOneWidget);

    await tester.tap(find.text('Girar'));
    // Avanza el parpadeo desacelerado hasta que se detiene.
    await tester.pump();
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    // Aparece el resultado y las acciones.
    expect(find.text('Ganadora'), findsOneWidget);
    expect(find.text('Ver ficha'), findsOneWidget);
    expect(find.text('Otra'), findsOneWidget);
  });
}
