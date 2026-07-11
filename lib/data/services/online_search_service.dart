import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

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
          return await _searchAniList(q);
        case ContentType.movie:
        case ContentType.documentary:
        case ContentType.shortFilm:
          return await _searchCinemeta(q, type);
      }
    } on OnlineSearchException {
      rethrow;
    } on TimeoutException {
      throw const OnlineSearchException(
        'La búsqueda tardó demasiado. Revisa tu conexión e inténtalo de nuevo.',
      );
    } catch (_) {
      throw const OnlineSearchException(
        'No se pudo conectar. Comprueba tu conexión a internet.',
      );
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
        'El servicio respondió con un error (${res.statusCode}).',
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
        'El servicio respondió con un error (${res.statusCode}).',
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

  // --- AniList (anime, GraphQL) ----------------------------------------------
  static const String _aniListQuery = r'''
query ($s: String) {
  Page(page: 1, perPage: 20) {
    media(search: $s, type: ANIME, sort: SEARCH_MATCH) {
      title { romaji english }
      coverImage { large }
      episodes
      duration
      averageScore
      genres
      startDate { year month day }
      description(asHtml: false)
    }
  }
}''';

  Future<List<OnlineResult>> _searchAniList(String q) async {
    final res = await _client
        .post(
          Uri.https('graphql.anilist.co', ''),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: json.encode({
            'query': _aniListQuery,
            'variables': {'s': q},
          }),
        )
        .timeout(_timeout);
    if (res.statusCode != 200) {
      throw OnlineSearchException(
        'El servicio respondió con un error (${res.statusCode}).',
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

      out.add(OnlineResult(
        title: name,
        type: ContentType.anime,
        posterUrl: cover,
        overview: _clip(_stripHtml(raw['description'] as String?)),
        genres: mapGenres(genres),
        durationMinutes: (raw['duration'] as num?)?.toInt() ?? 0,
        episodes: (raw['episodes'] as num?)?.toInt(),
        releaseDate: date,
        rating: score != null ? score / 10.0 : null,
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
