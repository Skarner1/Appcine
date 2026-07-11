import '../../core/constants/app_constants.dart';
import 'content_item.dart';

/// Resultado de una búsqueda en internet (iTunes, TVMaze o Jikan),
/// normalizado a los campos que usa la app. Se convierte en un [ContentItem]
/// borrador con [toDraft] para pre-rellenar el formulario de "Agregar".
class OnlineResult {
  final String title;
  final ContentType type;
  final String? posterUrl;
  final String? overview;
  final List<String> genres; // ya mapeados a los géneros en español (kGenres)
  final int durationMinutes; // 0 si se desconoce
  final int? episodes;
  final DateTime? releaseDate;
  final double? rating; // valoración externa 0–10 (solo informativa)

  /// Id para pedir detalles completos (p. ej. id de IMDB en Cinemeta). Cuando
  /// no es null, el resultado es "ligero" y se enriquece antes de agregarlo.
  final String? detailId;

  const OnlineResult({
    required this.title,
    required this.type,
    this.posterUrl,
    this.overview,
    this.genres = const [],
    this.durationMinutes = 0,
    this.episodes,
    this.releaseDate,
    this.rating,
    this.detailId,
  });

  int? get year => releaseDate?.year;

  OnlineResult copyWith({
    String? posterUrl,
    String? overview,
    List<String>? genres,
    int? durationMinutes,
    int? episodes,
    DateTime? releaseDate,
    double? rating,
  }) {
    return OnlineResult(
      title: title,
      type: type,
      posterUrl: posterUrl ?? this.posterUrl,
      overview: overview ?? this.overview,
      genres: genres ?? this.genres,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      episodes: episodes ?? this.episodes,
      releaseDate: releaseDate ?? this.releaseDate,
      rating: rating ?? this.rating,
      detailId: detailId,
    );
  }

  /// Borrador para el formulario. Mantiene `id` temporal: al guardar se genera
  /// un UUID nuevo (es contenido nuevo, no edición).
  ContentItem toDraft() => ContentItem(
        id: 'draft',
        title: title,
        type: type,
        genres: genres,
        durationMinutes: durationMinutes,
        episodes: episodes,
        posterUrl: posterUrl,
        releaseDate: releaseDate,
        personalNote: (overview != null && overview!.trim().isNotEmpty)
            ? overview!.trim()
            : null,
        addedAt: DateTime.now(),
      );
}

/// Normaliza un nombre de género (en inglés o combinado, p. ej. de iTunes) a
/// uno de los géneros en español de [kGenres]. Devuelve `null` si no hay match.
String? mapGenreToSpanish(String raw) {
  final g = raw.toLowerCase().trim();
  bool has(String s) => g.contains(s);

  // El orden importa: primero los más específicos / combinados.
  if (has('sci') || has('ciencia')) return 'Ciencia Ficción';
  if (has('animation') || has('animación') || has('anime')) return 'Animación';
  if (has('action') || has('acción')) return 'Acción';
  if (has('adventure') || has('aventura')) return 'Aventura';
  if (has('biograph') || has('biograf')) return 'Biografía';
  if (has('comedy') || has('comedia')) return 'Comedia';
  if (has('crime') || has('crimen')) return 'Crimen';
  if (has('documentary') || has('documental')) return 'Documental';
  if (has('drama')) return 'Drama';
  if (has('family') || has('kids') || has('familiar') || has('niños')) {
    return 'Familiar';
  }
  if (has('fantasy') || has('fantasía') || has('fantasia')) return 'Fantasía';
  if (has('war') || has('guerra') || has('military')) return 'Guerra';
  if (has('history') || has('histor')) return 'Historia';
  if (has('mystery') || has('misterio')) return 'Misterio';
  if (has('music')) return 'Musical';
  if (has('romance') || has('romant')) return 'Romance';
  if (has('thriller') || has('suspense') || has('suspenso') || has('psycho')) {
    return 'Suspenso';
  }
  if (has('horror') || has('terror')) return 'Terror';
  if (has('western')) return 'Western';
  return null;
}

/// Aplica [mapGenreToSpanish] a una lista, elimina nulos y duplicados y
/// conserva el orden. Limita a 4 géneros para no saturar la ficha.
List<String> mapGenres(Iterable<String> raw) {
  final result = <String>[];
  for (final r in raw) {
    final mapped = mapGenreToSpanish(r);
    if (mapped != null && !result.contains(mapped)) {
      result.add(mapped);
    }
    if (result.length >= 4) break;
  }
  return result;
}
