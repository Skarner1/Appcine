import 'package:cineapp/data/models/content_item.dart';
import 'package:cineapp/data/models/watch_event.dart';
import 'package:cineapp/features/catalog/catalog_search.dart';
import 'package:flutter_test/flutter_test.dart';

ContentItem _item({
  required String title,
  List<String> genres = const [],
  String? note,
  String? recommendedBy,
  ContentType type = ContentType.movie,
  double? rating,
  int duration = 100,
  bool favorite = false,
  DateTime? addedAt,
  DateTime? watchDate,
  List<WatchEvent> watchLog = const [],
}) {
  return ContentItem(
    id: title,
    title: title,
    type: type,
    genres: genres,
    durationMinutes: duration,
    userRating: rating,
    personalNote: note,
    recommendedBy: recommendedBy,
    isFavorite: favorite,
    watchDate: watchDate,
    watchLog: watchLog,
    addedAt: addedAt ?? DateTime(2026),
  );
}

List<String> _titles(List<ContentItem> items) =>
    items.map((e) => e.title).toList();

void main() {
  group('normalize', () {
    test('quita tildes y baja a minúsculas', () {
      expect(normalize('Amélie'), 'amelie');
      expect(normalize('Ciencia Ficción'), 'ciencia ficcion');
      expect(normalize('EL PADRINO'), 'el padrino');
      expect(normalize('Coraçao'), 'coracao');
      expect(normalize('Ñu'), 'nu');
    });

    test('deja en paz lo que ya está limpio', () {
      expect(normalize('dune'), 'dune');
      expect(normalize(''), '');
    });
  });

  group('editDistance', () {
    test('cuenta los cambios de una letra', () {
      expect(editDistance('dune', 'dune'), 0);
      expect(editDistance('dune', 'dume'), 1); // sustitución
      expect(editDistance('dune', 'dun'), 1); // borrado
      expect(editDistance('dune', 'dunes'), 1); // inserción
      expect(editDistance('interestelar', 'interstelar'), 1);
    });

    test('corta pronto cuando no se parecen en nada', () {
      expect(editDistance('dune', 'matrix', max: 2), greaterThan(2));
    });
  });

  group('typoTolerance', () {
    test('a las palabras cortas no se les perdona nada', () {
      // Con margen, "up" encajaría con media biblioteca.
      expect(typoTolerance(2), 0);
      expect(typoTolerance(3), 0);
      expect(typoTolerance(5), 1);
      expect(typoTolerance(10), 2);
    });
  });

  group('búsqueda sin tildes', () {
    test('encuentra "Amélie" escribiendo "amelie"', () {
      final items = [_item(title: 'Amélie'), _item(title: 'Dune')];

      expect(_titles(searchCatalog(items, query: 'amelie')), ['Amélie']);
    });

    test('encuentra el género aunque lo escribas sin acento', () {
      final items = [
        _item(title: 'Blade Runner', genres: ['Ciencia ficción']),
        _item(title: 'Rocky', genres: ['Drama']),
      ];

      expect(_titles(searchCatalog(items, query: 'ficcion')), ['Blade Runner']);
    });
  });

  group('tolerancia a erratas', () {
    test('encuentra pese a una letra cambiada', () {
      final items = [_item(title: 'Interstellar'), _item(title: 'Dune')];

      expect(_titles(searchCatalog(items, query: 'intersteller')), ['Interstellar']);
    });

    test('no inventa resultados con palabras cortas', () {
      final items = [_item(title: 'Up'), _item(title: 'It'), _item(title: 'Us')];

      // "Ax" no se parece a nada aunque esté a 1 letra de varios.
      expect(searchCatalog(items, query: 'ax'), isEmpty);
    });

    test('lo que no se parece no sale', () {
      final items = [_item(title: 'Dune'), _item(title: 'Matrix')];

      expect(searchCatalog(items, query: 'titanic'), isEmpty);
    });
  });

  group('dónde busca', () {
    test('busca dentro de tus notas', () {
      final items = [
        _item(title: 'Dune', note: 'Me la recomendó mi hermano en verano'),
        _item(title: 'Matrix'),
      ];

      expect(_titles(searchCatalog(items, query: 'hermano')), ['Dune']);
    });

    test('busca por quién te lo recomendó', () {
      final items = [
        _item(title: 'Dune', recommendedBy: 'Marta'),
        _item(title: 'Matrix'),
      ];

      expect(_titles(searchCatalog(items, query: 'marta')), ['Dune']);
    });
  });

  group('relevancia', () {
    test('el título pesa más que la nota', () {
      final items = [
        _item(title: 'Una peli cualquiera', note: 'trata sobre dune y gusanos'),
        _item(title: 'Dune'),
      ];

      expect(_titles(searchCatalog(items, query: 'dune')).first, 'Dune');
    });

    test('empezar por lo buscado gana a mencionarlo por el medio', () {
      final items = [
        _item(title: 'El regreso de Dune'),
        _item(title: 'Dune: Parte Dos'),
      ];

      expect(_titles(searchCatalog(items, query: 'dune')).first, 'Dune: Parte Dos');
    });

    test('un encaje exacto gana a uno con errata', () {
      final items = [
        _item(title: 'Interstellar'),
        _item(title: 'Interstelar bootleg'),
      ];

      expect(
        _titles(searchCatalog(items, query: 'interstellar')).first,
        'Interstellar',
      );
    });
  });

  group('varias palabras', () {
    test('todas tienen que encajar en algún sitio', () {
      final items = [
        _item(title: 'Dune', genres: ['Ciencia ficción']),
        _item(title: 'Rocky', genres: ['Drama']),
      ];

      // "dune drama" no debe traer nada: Dune no es drama.
      expect(searchCatalog(items, query: 'dune drama'), isEmpty);
    });

    test('cruza título y género', () {
      final items = [
        _item(title: 'Dune', genres: ['Ciencia ficción']),
        _item(title: 'Dune Messiah', genres: ['Drama']),
      ];

      expect(_titles(searchCatalog(items, query: 'dune drama')), ['Dune Messiah']);
    });
  });

  group('filtros', () {
    final items = [
      _item(title: 'Dune', type: ContentType.movie, favorite: true),
      _item(title: 'Fargo', type: ContentType.series, genres: ['Drama']),
      _item(title: 'Planeta Tierra', type: ContentType.documentary),
    ];

    test('por tipo', () {
      expect(
        _titles(searchCatalog(items, type: ContentType.series)),
        ['Fargo'],
      );
    });

    test('por género', () {
      expect(_titles(searchCatalog(items, genre: 'Drama')), ['Fargo']);
    });

    test('solo favoritos', () {
      expect(_titles(searchCatalog(items, onlyFavorites: true)), ['Dune']);
    });

    test('los filtros se combinan con la búsqueda', () {
      expect(
        searchCatalog(items, query: 'dune', type: ContentType.series),
        isEmpty,
      );
    });
  });

  group('orden', () {
    test('por título, ignorando tildes', () {
      final items = [
        _item(title: 'Zulú'),
        _item(title: 'Ámsterdam'),
        _item(title: 'Bourne'),
      ];

      expect(
        _titles(searchCatalog(items, sort: CatalogSort.title)),
        ['Ámsterdam', 'Bourne', 'Zulú'],
      );
    });

    test('por nota, y lo no puntuado al final', () {
      final items = [
        _item(title: 'Sin nota'),
        _item(title: 'Buena', rating: 9),
        _item(title: 'Regular', rating: 5),
      ];

      expect(
        _titles(searchCatalog(items, sort: CatalogSort.rating)),
        ['Buena', 'Regular', 'Sin nota'],
      );
    });

    test('por duración, de más larga a más corta', () {
      final items = [
        _item(title: 'Corta', duration: 90),
        _item(title: 'Larga', duration: 200),
      ];

      expect(
        _titles(searchCatalog(items, sort: CatalogSort.duration)),
        ['Larga', 'Corta'],
      );
    });

    test('por visto, mirando el diario', () {
      final items = [
        _item(
          title: 'Vista hace poco',
          watchLog: [WatchEvent(date: DateTime(2026, 7, 1), minutes: 100)],
        ),
        _item(
          title: 'Vista hace tiempo',
          watchLog: [WatchEvent(date: DateTime(2026, 1, 1), minutes: 100)],
        ),
        _item(title: 'Nunca vista'),
      ];

      expect(
        _titles(searchCatalog(items, sort: CatalogSort.watched)),
        ['Vista hace poco', 'Vista hace tiempo', 'Nunca vista'],
      );
    });

    test('sin búsqueda, relevancia significa lo más reciente', () {
      final items = [
        _item(title: 'Vieja', addedAt: DateTime(2026, 1, 1)),
        _item(title: 'Nueva', addedAt: DateTime(2026, 7, 1)),
      ];

      expect(
        _titles(searchCatalog(items, sort: CatalogSort.relevance)),
        ['Nueva', 'Vieja'],
      );
    });
  });

  group('casos límite', () {
    test('sin búsqueda salen todos', () {
      final items = [_item(title: 'A'), _item(title: 'B')];

      expect(searchCatalog(items, query: ''), hasLength(2));
      expect(searchCatalog(items, query: '   '), hasLength(2));
    });

    test('un catálogo vacío no revienta', () {
      expect(searchCatalog([], query: 'lo que sea'), isEmpty);
    });
  });
}
