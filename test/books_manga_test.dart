import 'dart:convert';

import 'package:cineapp/core/l10n/app_language.dart';
import 'package:cineapp/core/l10n/strings.dart';
import 'package:cineapp/data/models/content_item.dart';
import 'package:cineapp/data/services/online_search_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

OnlineSearchService _service(String body, {int status = 200}) {
  return OnlineSearchService(
    client: MockClient((_) async => http.Response(
          body,
          status,
          headers: {'content-type': 'application/json; charset=utf-8'},
        )),
  );
}

ContentItem _item({
  required ContentType type,
  int duration = 0,
  int? episodes,
  int? currentEpisode,
  WatchStatus status = WatchStatus.notStarted,
}) {
  return ContentItem(
    id: 'a',
    title: 'Algo',
    type: type,
    durationMinutes: duration,
    episodes: episodes,
    currentEpisode: currentEpisode,
    status: status,
    addedAt: DateTime(2026),
  );
}

void main() {
  // Los textos generados (p. ej. "De <autor>") se afirman en español.
  S.setLanguage(AppLanguage.es);

  group('los tipos nuevos', () {
    test('el orden del enum no se toca: Hive guarda por índice', () {
      // Si esto falla, alguien reordenó el enum y acaba de convertir las
      // películas de todo el mundo en otra cosa.
      expect(ContentType.values.map((e) => e.name), [
        'movie',
        'series',
        'documentary',
        'anime',
        'shortFilm',
        'book',
        'manga',
      ]);
    });

    test('libros y mangas se llevan por tomos, no por episodios', () {
      expect(ContentType.book.unitLabel, 'tomo');
      expect(ContentType.book.unitsLabel, 'tomos');
      expect(ContentType.manga.unitLabel, 'tomo');
      expect(ContentType.manga.unitsLabel, 'tomos');

      expect(ContentType.series.unitLabel, 'episodio');
      expect(ContentType.anime.unitsLabel, 'episodios');
    });

    test('los dos guardan progreso', () {
      expect(ContentType.book.hasEpisodes, isTrue);
      expect(ContentType.manga.hasEpisodes, isTrue);
      expect(ContentType.movie.hasEpisodes, isFalse);
    });

    test('lo que se lee se distingue de lo que se ve', () {
      expect(ContentType.book.isRead, isTrue);
      expect(ContentType.manga.isRead, isTrue);
      expect(ContentType.series.isRead, isFalse);
      expect(ContentType.movie.isRead, isFalse);
    });

    test('todos los tipos tienen etiqueta y emoji', () {
      for (final type in ContentType.values) {
        expect(type.label, isNotEmpty, reason: type.name);
        expect(type.pluralLabel, isNotEmpty, reason: type.name);
        expect(type.emoji, isNotEmpty, reason: type.name);
      }
    });
  });

  group('watchedMinutes sin número de tomos', () {
    test('un libro suelto leído cuenta como uno, no como cero', () {
      // Este era el fallo: sin tomos, seen caía a 0 y un libro leído entero
      // sumaba 0 minutos.
      final leido = _item(
        type: ContentType.book,
        duration: 300,
        status: WatchStatus.completed,
      );

      expect(leido.watchedMinutes, 300);
    });

    test('con tomos contados manda ese número', () {
      final saga = _item(
        type: ContentType.book,
        duration: 300,
        episodes: 3,
        status: WatchStatus.completed,
      );

      expect(saga.watchedMinutes, 900);
    });

    test('a medias cuenta solo lo leído', () {
      final aMedias = _item(
        type: ContentType.manga,
        duration: 40,
        episodes: 10,
        currentEpisode: 4,
        status: WatchStatus.watching,
      );

      expect(aMedias.watchedMinutes, 160);
    });

    test('sin empezar no suma nada', () {
      expect(_item(type: ContentType.book, duration: 300).watchedMinutes, 0);
    });

    test('sin duración no inventa minutos', () {
      final sinDuracion = _item(
        type: ContentType.book,
        status: WatchStatus.completed,
      );

      expect(sinDuracion.watchedMinutes, 0);
    });
  });

  group('Open Library (libros)', () {
    test('normaliza un libro con todos sus campos', () async {
      final body = jsonEncode({
        'docs': [
          {
            'title': 'Dune',
            'author_name': ['Frank Herbert'],
            'first_publish_year': 1965,
            'cover_i': 8567890,
            'subject': ['Science Fiction', 'Adventure'],
            'ratings_average': 4.5,
          },
        ],
      });

      final results =
          await _service(body).search(ContentType.book, 'dune');

      expect(results, hasLength(1));
      final book = results.single;
      expect(book.title, 'Dune');
      expect(book.type, ContentType.book);
      expect(book.posterUrl, 'https://covers.openlibrary.org/b/id/8567890-L.jpg');
      expect(book.overview, 'De Frank Herbert');
      expect(book.genres, ['Ciencia Ficción', 'Aventura']);
      expect(book.releaseDate?.year, 1965);
      expect(book.rating, 4.5);
    });

    test('aguanta un libro pelado, sin portada ni autor', () async {
      final body = jsonEncode({
        'docs': [
          {'title': 'Un libro sin nada'},
        ],
      });

      final results = await _service(body).search(ContentType.book, 'x');

      expect(results.single.title, 'Un libro sin nada');
      expect(results.single.posterUrl, isNull);
      expect(results.single.overview, isNull);
    });

    test('se salta los que no tienen título', () async {
      final body = jsonEncode({
        'docs': [
          {'cover_i': 1},
          {'title': ''},
          {'title': 'Este sí'},
        ],
      });

      final results = await _service(body).search(ContentType.book, 'x');

      expect(results.map((e) => e.title), ['Este sí']);
    });

    test('lista solo los tres primeros autores, no veinte', () async {
      final body = jsonEncode({
        'docs': [
          {
            'title': 'Antología',
            'author_name': ['A', 'B', 'C', 'D', 'E'],
          },
        ],
      });

      final results = await _service(body).search(ContentType.book, 'x');

      expect(results.single.overview, 'De A, B, C');
    });
  });

  group('AniList (manga)', () {
    String aniListBody(Map<String, dynamic> media) => jsonEncode({
          'data': {
            'Page': {
              'media': [media],
            },
          },
        });

    test('los tomos salen de volumes', () async {
      final body = aniListBody({
        'title': {'romaji': 'Berserk', 'english': null},
        'coverImage': {'large': 'https://img/berserk.jpg'},
        'episodes': null,
        'duration': null,
        'volumes': 42,
        'chapters': 380,
        'averageScore': 93,
        'genres': ['Action', 'Drama'],
        'startDate': {'year': 1989, 'month': 8, 'day': 25},
        'description': 'Guts.',
      });

      final results = await _service(body).search(ContentType.manga, 'berserk');

      final manga = results.single;
      expect(manga.title, 'Berserk');
      expect(manga.type, ContentType.manga);
      expect(manga.episodes, 42); // tomos, no capítulos
      expect(manga.rating, closeTo(9.3, 0.01));
      expect(manga.genres, ['Acción', 'Drama']);
      expect(manga.releaseDate, DateTime(1989, 8, 25));
    });

    test('sin tomos contados se cae a los capítulos', () async {
      // Típico de las obras que siguen publicándose.
      final body = aniListBody({
        'title': {'romaji': 'En curso'},
        'volumes': null,
        'chapters': 150,
      });

      final results = await _service(body).search(ContentType.manga, 'x');

      expect(results.single.episodes, 150);
    });

    test('sin tomos ni capítulos se queda a null, no en cero', () async {
      final body = aniListBody({
        'title': {'romaji': 'Recién empezado'},
        'volumes': null,
        'chapters': null,
      });

      expect((await _service(body).search(ContentType.manga, 'x')).single.episodes,
          isNull);
    });

    test('un manga no trae minutos: los pone el usuario', () async {
      final body = aniListBody({
        'title': {'romaji': 'Berserk'},
        'volumes': 42,
        'duration': null,
      });

      expect(
        (await _service(body).search(ContentType.manga, 'x')).single.durationMinutes,
        0,
      );
    });

    test('el anime sigue usando episodes, no volumes', () async {
      final body = aniListBody({
        'title': {'english': 'Cowboy Bebop'},
        'episodes': 26,
        'duration': 24,
        'volumes': null,
      });

      final anime = (await _service(body).search(ContentType.anime, 'x')).single;

      expect(anime.type, ContentType.anime);
      expect(anime.episodes, 26);
      expect(anime.durationMinutes, 24);
    });
  });

  group('el borrador que llega al formulario', () {
    test('un libro llega con su tipo y sus tomos', () async {
      final body = jsonEncode({
        'docs': [
          {'title': 'Dune', 'author_name': ['Frank Herbert']},
        ],
      });

      final draft =
          (await _service(body).search(ContentType.book, 'dune')).single.toDraft();

      expect(draft.type, ContentType.book);
      expect(draft.type.unitsLabel, 'tomos');
      expect(draft.personalNote, 'De Frank Herbert');
    });
  });

  group('cuando la red falla', () {
    test('el error habla de conexión, no de un stack trace', () async {
      final service = OnlineSearchService(
        client: MockClient((_) async => throw Exception('sin red')),
      );

      expect(
        () => service.search(ContentType.book, 'dune'),
        throwsA(isA<OnlineSearchException>()),
      );
    });

    test('un 500 tampoco revienta la app', () async {
      expect(
        () => _service('{}', status: 500).search(ContentType.book, 'x'),
        throwsA(isA<OnlineSearchException>()),
      );
    });
  });
}
