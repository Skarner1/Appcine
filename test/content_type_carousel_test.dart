import 'package:cineapp/core/l10n/app_language.dart';
import 'package:cineapp/core/l10n/strings.dart';
import 'package:cineapp/data/models/content_item.dart';
import 'package:cineapp/shared/widgets/content_type_carousel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Monta [child] en un móvil estrecho, que es donde aparecían los cortes.
Future<void> _pumpPhone(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: Align(alignment: Alignment.topCenter, child: child)),
    ),
  );
}

void main() {
  // El carrusel muestra etiquetas traducidas; los tests las afirman en español.
  S.setLanguage(AppLanguage.es);

  group('el ancho de cada chip lo manda su texto', () {
    testWidgets('dos etiquetas de distinto largo miden distinto', (tester) async {
      // Esta es LA propiedad que se rompió: el selector repartía el ancho a
      // partes iguales (Row de Expanded), así que todos medían lo mismo y las
      // etiquetas largas salían como "Pelícu…".
      await _pumpPhone(
        tester,
        ContentTypeCarousel(
          types: const [ContentType.movie, ContentType.documentary],
          selected: null,
          onSelect: (_) {},
          includeAll: true,
        ),
      );

      final todo = tester.getSize(find.text('Todo'));
      final peliculas = tester.getSize(find.text('Películas'));
      final documentales = tester.getSize(find.text('Documentales'));

      expect(todo.width, lessThan(peliculas.width));
      expect(peliculas.width, lessThan(documentales.width));
    });

    testWidgets('nada desborda con todos los tipos en pantalla estrecha',
        (tester) async {
      await _pumpPhone(
        tester,
        ContentTypeCarousel(
          types: ContentType.values,
          selected: null,
          onSelect: (_) {},
          includeAll: true,
        ),
      );

      // Un RenderFlex desbordado deja excepción; si la hay, esto falla.
      expect(tester.takeException(), isNull);
    });

    testWidgets('el alto es fijo, salgan los tipos que salgan', (tester) async {
      await _pumpPhone(
        tester,
        ContentTypeCarousel(
          types: ContentType.values,
          selected: ContentType.movie,
          onSelect: (_) {},
          includeAll: true,
        ),
      );

      expect(tester.getSize(find.byType(ContentTypeCarousel)).height, 44);
    });
  });

  group('se arrastra en horizontal', () {
    testWidgets('hay un scroll y no un salto de línea', (tester) async {
      await _pumpPhone(
        tester,
        ContentTypeCarousel(
          types: ContentType.values,
          selected: null,
          onSelect: (_) {},
          includeAll: true,
        ),
      );

      final scrollable = tester.widget<Scrollable>(find.byType(Scrollable));
      expect(scrollable.axisDirection, AxisDirection.right);
      expect(find.byType(Wrap), findsNothing);
    });

    testWidgets('arrastrando se llega a los últimos tipos', (tester) async {
      await _pumpPhone(
        tester,
        ContentTypeCarousel(
          types: ContentType.values,
          selected: null,
          onSelect: (_) {},
          includeAll: true,
        ),
      );

      // Los de la derecha aún no están construidos (es una lista perezosa).
      expect(find.text('Mangas'), findsNothing);

      await tester.scrollUntilVisible(
        find.text('Mangas'),
        200,
        scrollable: find.byType(Scrollable),
      );

      expect(find.text('Mangas'), findsOneWidget);
    });
  });

  group('etiquetas', () {
    testWidgets('van enteras, sin abreviar', (tester) async {
      await _pumpPhone(
        tester,
        ContentTypeCarousel(
          types: const [ContentType.movie, ContentType.documentary],
          selected: null,
          onSelect: (_) {},
        ),
      );

      expect(find.text('Películas'), findsOneWidget);
      expect(find.text('Documentales'), findsOneWidget);
      // Nada de "Pelis" ni "Docus".
      expect(find.text('Pelis'), findsNothing);
      expect(find.text('Docus'), findsNothing);
    });

    testWidgets('"Todo" solo cuando se pide', (tester) async {
      await _pumpPhone(
        tester,
        ContentTypeCarousel(
          types: const [ContentType.movie],
          selected: ContentType.movie,
          onSelect: (_) {},
        ),
      );

      expect(find.text('Todo'), findsNothing);
    });
  });

  group('selección', () {
    testWidgets('tocar un tipo lo devuelve', (tester) async {
      ContentType? elegido;
      await _pumpPhone(
        tester,
        ContentTypeCarousel(
          types: const [ContentType.movie, ContentType.series],
          selected: null,
          onSelect: (type) => elegido = type,
          includeAll: true,
        ),
      );

      await tester.tap(find.text('Series'));

      expect(elegido, ContentType.series);
    });

    testWidgets('volver a tocar el activo lo quita, si hay "Todo"',
        (tester) async {
      ContentType? elegido = ContentType.movie;
      var llamado = false;
      await _pumpPhone(
        tester,
        ContentTypeCarousel(
          types: const [ContentType.movie],
          selected: ContentType.movie,
          onSelect: (type) {
            elegido = type;
            llamado = true;
          },
          includeAll: true,
        ),
      );

      await tester.tap(find.text('Películas'));

      expect(llamado, isTrue);
      expect(elegido, isNull);
    });

    testWidgets('sin "Todo" no se puede quedar sin nada elegido',
        (tester) async {
      ContentType? elegido;
      await _pumpPhone(
        tester,
        ContentTypeCarousel(
          types: const [ContentType.movie],
          selected: ContentType.movie,
          onSelect: (type) => elegido = type,
        ),
      );

      await tester.tap(find.text('Películas'));

      // Sigue siendo película: en la búsqueda online hay que buscar algo.
      expect(elegido, ContentType.movie);
    });

    testWidgets('apagado no responde a los toques', (tester) async {
      var llamado = false;
      await _pumpPhone(
        tester,
        ContentTypeCarousel(
          types: const [ContentType.movie],
          selected: null,
          onSelect: (_) => llamado = true,
          includeAll: true,
          enabled: false,
        ),
      );

      await tester.tap(find.text('Películas'));

      expect(llamado, isFalse);
    });
  });

  group('ChipCarousel genérico', () {
    testWidgets('sirve para cualquier lista, no solo tipos', (tester) async {
      var tocado = '';
      await _pumpPhone(
        tester,
        ChipCarousel(
          options: [
            ChipCarouselOption(
              label: 'Cualquiera',
              selected: true,
              onTap: () => tocado = 'Cualquiera',
            ),
            ChipCarouselOption(
              label: '≤ 1 h 30 min',
              selected: false,
              onTap: () => tocado = 'corta',
            ),
          ],
        ),
      );

      expect(find.text('≤ 1 h 30 min'), findsOneWidget);
      await tester.tap(find.text('≤ 1 h 30 min'));
      expect(tocado, 'corta');
    });
  });
}
