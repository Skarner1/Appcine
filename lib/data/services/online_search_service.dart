import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../core/l10n/strings.dart';
import '../models/content_item.dart';
import '../models/online_result.dart';

/// Error legible para mostrar en la UI cuando falla la búsqueda online.
class OnlineSearchException implements Exception {
  final String message;
  const OnlineSearchException(this.message);
  @override
  String toString() => message;
}

/// Busca contenido en internet usando APIs públicas y gratuitas (sin API key):
///  • Películas → Cinemeta (metadatos de IMDB, sin geo-restricción)
///  • Series    → TVMaze
///  • Anime     → AniList (GraphQL)
///  • Manga     → AniList (el mismo GraphQL, con type: MANGA)
///  • Libros    → Open Library
///
/// Cada resultado se normaliza a [OnlineResult]. Las películas se devuelven
/// "ligeras" (título, póster, año) y se completan con [enrich] al seleccionarlas.
class OnlineSearchService {
  OnlineSearchService({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;
  static const Duration _timeout = Duration(seconds: 12);

  Future<List<OnlineResult>> search(ContentType type, String query) async {
    final q = query.trim();
    if (q.isEmpty) return const [];
    try {
      switch (type) {
        case ContentType.series:
          return await _searchTvMaze(q);
        case ContentType.anime:
          return await _searchAniList(q, ContentType.anime);
        case ContentType.manga:
          return await _searchAniList(q, ContentType.manga);
        case ContentType.book:
          return await _searchOpenLibrary(q);
        case ContentType.movie:
        case ContentType.documentary:
        case ContentType.shortFilm:
          return await _searchCinemeta(q, type);
      }
    } on OnlineSearchException {
      rethrow;
    } on TimeoutException {
      throw OnlineSearchException(tr('search.err.timeout'));
    } catch (_) {
      throw OnlineSearchException(tr('search.err.noConnection'));
    }
  }

  /// Completa un resultado "ligero" (solo películas de Cinemeta) con géneros,
  /// duración, sinopsis, valoración y fecha. Para el resto devuelve el mismo
  /// resultado. Si falla el detalle, devuelve el original (no bloquea el alta).
  Future<OnlineResult> enrich(OnlineResult result) async {
    if (result.detailId == null) return result;
    try {
      final uri = Uri.parse(
        'https://v3-cinemeta.strem.io/meta/movie/${result.detailId}.json',
      );
      final data = await _getJson(uri);
      final meta = data['meta'];
      if (meta is! Map) return result;

      final genres = (meta['genres'] as List?)?.cast<String>() ?? const [];
      final releasedIso = meta['released'] as String?;
      final year = meta['year'];
      return result.copyWith(
        posterUrl: (meta['poster'] as String?),
        overview: _clip(meta['description'] as String?),
        genres: mapGenres(genres),
        durationMinutes: _parseIntPrefix(meta['runtime'] as String?),
        releaseDate:
            _parseDate(releasedIso) ?? _yearToDate(year?.toString()),
        rating: double.tryParse('${meta['imdbRating'] ?? ''}'),
      );
    } catch (_) {
      return result; // el usuario podrá completar los datos manualmente
    }
  }

  Future<Map<String, dynamic>> _getJson(Uri uri) async {
    final res = await _client.get(uri, headers: {
      'Accept': 'application/json',
    }).timeout(_timeout);
    if (res.statusCode != 200) {
      throw OnlineSearchException(
        tr('search.err.service', {'code': res.statusCode}),
      );
    }
    return json.decode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
  }

  // --- Cinemeta (películas) --------------------------------------------------
  Future<List<OnlineResult>> _searchCinemeta(
      String q, ContentType type) async {
    final uri = Uri.parse(
      'https://v3-cinemeta.strem.io/catalog/movie/top/search=${Uri.encodeComponent(q)}.json',
    );
    final data = await _getJson(uri);
    final metas = (data['metas'] as List?) ?? const [];

    final out = <OnlineResult>[];
    for (final raw in metas) {
      if (raw is! Map) continue;
      final title = raw['name'] as String?;
      if (title == null || title.isEmpty) continue;
      final id = (raw['imdb_id'] ?? raw['id']) as String?;

      out.add(OnlineResult(
        title: title,
        type: type,
        posterUrl: raw['poster'] as String?,
        releaseDate: _yearToDate(raw['releaseInfo']?.toString()),
        detailId: id, // se completa con enrich() al seleccionar
      ));
    }
    return out;
  }

  // --- TVMaze (series) -------------------------------------------------------
  Future<List<OnlineResult>> _searchTvMaze(String q) async {
    final uri = Uri.https('api.tvmaze.com', '/search/shows', {'q': q});
    final res = await _client.get(uri, headers: {
      'Accept': 'application/json',
    }).timeout(_timeout);
    if (res.statusCode != 200) {
      throw OnlineSearchException(
        tr('search.err.service', {'code': res.statusCode}),
      );
    }
    final list = json.decode(utf8.decode(res.bodyBytes)) as List;

    final out = <OnlineResult>[];
    for (final entry in list) {
      final show = (entry is Map) ? entry['show'] : null;
      if (show is! Map) continue;
      final title = show['name'] as String?;
      if (title == null || title.isEmpty) continue;

      final image = show['image'];
      final poster = image is Map
          ? (image['original'] ?? image['medium']) as String?
          : null;
      final runtime = (show['averageRuntime'] ?? show['runtime']) as num?;
      final ratingAvg =
          (show['rating'] is Map) ? show['rating']['average'] as num? : null;
      final genres = (show['genres'] as List?)?.cast<String>() ?? const [];

      out.add(OnlineResult(
        title: title,
        type: ContentType.series,
        posterUrl: poster,
        overview: _clip(_stripHtml(show['summary'] as String?)),
        genres: mapGenres(genres),
        durationMinutes: runtime?.toInt() ?? 0,
        releaseDate: _parseDate(show['premiered'] as String?),
        rating: ratingAvg?.toDouble(),
      ));
    }
    return out;
  }

  // --- AniList (anime y manga, GraphQL) --------------------------------------
  /// [t] es el MediaType de AniList (ANIME | MANGA). En manga, `episodes` y
  /// `duration` vienen siempre nulos y lo que trae son `volumes` y `chapters`.
  static const String _aniListQuery = r'''
query ($s: String, $t: MediaType) {
  Page(page: 1, perPage: 20) {
    media(search: $s, type: $t, sort: SEARCH_MATCH) {
      title { romaji english }
      coverImage { large }
      episodes
      duration
      volumes
      chapters
      averageScore
      genres
      startDate { year month day }
      description(asHtml: false)
    }
  }
}''';

  Future<List<OnlineResult>> _searchAniList(String q, ContentType type) async {
    final mediaType = type == ContentType.manga ? 'MANGA' : 'ANIME';
    final res = await _client
        .post(
          Uri.https('graphql.anilist.co', ''),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: json.encode({
            'query': _aniListQuery,
            'variables': {'s': q, 't': mediaType},
          }),
        )
        .timeout(_timeout);
    if (res.statusCode != 200) {
      throw OnlineSearchException(
        tr('search.err.service', {'code': res.statusCode}),
      );
    }
    final data = json.decode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final page = (data['data'] as Map?)?['Page'] as Map?;
    final media = (page?['media'] as List?) ?? const [];

    final out = <OnlineResult>[];
    for (final raw in media) {
      if (raw is! Map) continue;
      final title = raw['title'] as Map?;
      final name = (title?['english'] ?? title?['romaji']) as String?;
      if (name == null || name.isEmpty) continue;

      final cover = (raw['coverImage'] as Map?)?['large'] as String?;
      final score = raw['averageScore'] as num?;
      final genres = (raw['genres'] as List?)?.cast<String>() ?? const [];
      final start = raw['startDate'] as Map?;
      DateTime? date;
      if (start != null && start['year'] is int) {
        date = DateTime(
          start['year'] as int,
          (start['month'] as int?) ?? 1,
          (start['day'] as int?) ?? 1,
        );
      }

      // En manga las "partes" son tomos. Si la obra no los tiene contados
      // (típico de las que siguen publicándose) se cae a los capítulos, que es
      // lo que la gente sigue de verdad.
      final units = type == ContentType.manga
          ? ((raw['volumes'] as num?) ?? (raw['chapters'] as num?))?.toInt()
          : (raw['episodes'] as num?)?.toInt();

      out.add(OnlineResult(
        title: name,
        type: type,
        posterUrl: cover,
        overview: _clip(_stripHtml(raw['description'] as String?)),
        genres: mapGenres(genres),
        // AniList no da minutos de manga: los pone el usuario si le apetece.
        durationMinutes: (raw['duration'] as num?)?.toInt() ?? 0,
        episodes: units,
        releaseDate: date,
        rating: score != null ? score / 10.0 : null,
      ));
    }
    return out;
  }

  // --- Open Library (libros) -------------------------------------------------
  /// Busca en Open Library, que es libre, sin clave y sin límite práctico.
  ///
  /// Se piden solo los campos que se usan (`fields`): la respuesta por defecto
  /// trae decenas de kilobytes por libro que no pintan nada aquí.
  Future<List<OnlineResult>> _searchOpenLibrary(String q) async {
    final uri = Uri.https('openlibrary.org', '/search.json', {
      'q': q,
      'limit': '20',
      'fields': 'title,author_name,first_publish_year,cover_i,subject,'
          'number_of_pages_median,ratings_average',
    });
    final data = await _getJson(uri);
    final docs = (data['docs'] as List?) ?? const [];

    final out = <OnlineResult>[];
    for (final raw in docs) {
      if (raw is! Map) continue;
      final title = raw['title'] as String?;
      if (title == null || title.isEmpty) continue;

      final coverId = raw['cover_i'] as num?;
      final authors = (raw['author_name'] as List?)?.cast<String>();
      final subjects = (raw['subject'] as List?)?.cast<String>() ?? const [];
      final year = (raw['first_publish_year'] as num?)?.toInt();
      final rating = (raw['ratings_average'] as num?)?.toDouble();

      out.add(OnlineResult(
        title: title,
        type: ContentType.book,
        posterUrl: coverId == null
            ? null
            : 'https://covers.openlibrary.org/b/id/$coverId-L.jpg',
        // Open Library no da sinopsis en la búsqueda; el autor es lo que de
        // verdad distingue dos libros con el mismo título.
        overview: (authors != null && authors.isNotEmpty)
            ? tr('search.byAuthors', {'authors': authors.take(3).join(', ')})
            : null,
        genres: mapGenres(subjects),
        releaseDate: year == null ? null : DateTime(year),
        rating: rating,
      ));
    }
    return out;
  }

  // --- Helpers ---------------------------------------------------------------
  int _parseIntPrefix(String? s) {
    if (s == null) return 0;
    final match = RegExp(r'\d+').firstMatch(s);
    return match != null ? int.parse(match.group(0)!) : 0;
  }

  DateTime? _parseDate(String? s) =>
      (s == null || s.isEmpty) ? null : DateTime.tryParse(s);

  /// Extrae el primer año de un texto ("1999", "2008–2013") y lo convierte
  /// en una fecha (1 de enero de ese año).
  DateTime? _yearToDate(String? s) {
    if (s == null) return null;
    final match = RegExp(r'(19|20)\d{2}').firstMatch(s);
    return match != null ? DateTime(int.parse(match.group(0)!)) : null;
  }

  String? _clip(String? s, [int max = 600]) {
    if (s == null) return null;
    final trimmed = s.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.length <= max) return trimmed;
    return '${trimmed.substring(0, max).trimRight()}…';
  }

  String _stripHtml(String? s) {
    if (s == null) return '';
    var out = s.replaceAll(RegExp(r'<[^>]*>'), '');
    const entities = {
      '&amp;': '&',
      '&quot;': '"',
      '&#39;': "'",
      '&apos;': "'",
      '&lt;': '<',
      '&gt;': '>',
      '&nbsp;': ' ',
    };
    entities.forEach((k, v) => out = out.replaceAll(k, v));
    return out.trim();
  }
}

/// Servicio de búsqueda online, inyectable en la UI.
final onlineSearchServiceProvider =
    Provider<OnlineSearchService>((ref) => OnlineSearchService());
