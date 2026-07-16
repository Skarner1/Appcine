import '../../core/l10n/strings.dart';
import '../../data/models/content_item.dart';

/// Cómo ordenar el catálogo.
enum CatalogSort { relevance, title, rating, duration, added, watched }

extension CatalogSortX on CatalogSort {
  String get label => tr('sort.$name');
}

const _accented = 'áàäâãéèëêíìïîóòöôõúùüûñç';
const _plain = 'aaaaaeeeeiiiiooooouuuunc';

/// Deja el texto en minúsculas y sin tildes.
///
/// En español esto es media búsqueda: nadie escribe "Amélie" con acento en el
/// buscador, ni "ciencia ficción" completo. Sin esto, `contains` no encuentra
/// ninguna de las dos.
String normalize(String input) {
  final lower = input.toLowerCase();
  final buffer = StringBuffer();
  for (final rune in lower.runes) {
    final char = String.fromCharCode(rune);
    final index = _accented.indexOf(char);
    buffer.write(index == -1 ? char : _plain[index]);
  }
  return buffer.toString();
}

/// Distancia de edición entre dos palabras (cuántos cambios de una letra hacen
/// falta para convertir una en la otra). Corta en cuanto se pasa de [max], que
/// es lo que la hace barata para el caso normal: no se parecen en nada.
int editDistance(String a, String b, {int max = 2}) {
  if (a == b) return 0;
  if ((a.length - b.length).abs() > max) return max + 1;
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;

  var previous = List<int>.generate(b.length + 1, (i) => i);
  var current = List<int>.filled(b.length + 1, 0);

  for (var i = 1; i <= a.length; i++) {
    current[0] = i;
    var rowBest = current[0];

    for (var j = 1; j <= b.length; j++) {
      final cost = a[i - 1] == b[j - 1] ? 0 : 1;
      current[j] = [
        current[j - 1] + 1, // inserción
        previous[j] + 1, // borrado
        previous[j - 1] + cost, // sustitución
      ].reduce((x, y) => x < y ? x : y);
      if (current[j] < rowBest) rowBest = current[j];
    }

    // Si toda la fila se pasó del máximo, ya no hay vuelta atrás.
    if (rowBest > max) return max + 1;

    final swap = previous;
    previous = current;
    current = swap;
  }

  return previous[b.length];
}

/// Erratas que se le perdonan a una palabra según lo larga que sea.
///
/// A las cortas no se les perdona nada: con dos letras de margen, "Up" encaja
/// con media biblioteca.
int typoTolerance(int length) {
  if (length <= 3) return 0;
  if (length <= 6) return 1;
  return 2;
}

/// Cómo de bien encaja [term] en [field]: 1 lo contiene tal cual, 0 no encaja.
double _matchField(String field, String term) {
  if (field.isEmpty) return 0;
  if (field.contains(term)) return 1;

  final tolerance = typoTolerance(term.length);
  if (tolerance == 0) return 0;

  var best = 0.0;
  for (final word in field.split(RegExp(r'[\s,;:.\-_/()]+'))) {
    if (word.isEmpty) continue;
    if (word.startsWith(term)) return 0.9;
    if (editDistance(word, term, max: tolerance) <= tolerance) {
      best = best > 0.6 ? best : 0.6;
    }
  }
  return best;
}

/// Peso de cada campo: que coincida el título vale mucho más que una palabra
/// suelta de una nota.
const _titleWeight = 3.0;
const _genreWeight = 1.5;
const _noteWeight = 1.0;

/// Puntúa [item] contra [query]. 0 = no sale en los resultados.
///
/// Todas las palabras de la búsqueda tienen que encajar en algún sitio: buscar
/// "dark drama" debe pedir las dos cosas, no traer todo lo que sea drama.
double scoreItem(ContentItem item, String query) {
  final terms = normalize(query).split(RegExp(r'\s+'))
    ..removeWhere((t) => t.isEmpty);
  if (terms.isEmpty) return 0;

  final title = normalize(item.title);
  final genres = normalize(item.genres.join(' '));
  final note = normalize(item.personalNote ?? '');
  final by = normalize(item.recommendedBy ?? '');

  var total = 0.0;
  for (final term in terms) {
    final best = [
      _matchField(title, term) * _titleWeight,
      _matchField(genres, term) * _genreWeight,
      _matchField(note, term) * _noteWeight,
      _matchField(by, term) * _noteWeight,
    ].reduce((a, b) => a > b ? a : b);

    if (best == 0) return 0; // Falta una palabra: fuera.
    total += best;
  }

  // Empezar por lo buscado manda sobre mencionarlo por el medio.
  if (title.startsWith(terms.first)) total += 1;

  return total;
}

int _compareBySort(ContentItem a, ContentItem b, CatalogSort sort) {
  switch (sort) {
    case CatalogSort.title:
      return normalize(a.title).compareTo(normalize(b.title));
    case CatalogSort.rating:
      // Sin puntuar va al final, no arriba con un cero.
      final ar = a.userRating;
      final br = b.userRating;
      if (ar == null && br == null) return 0;
      if (ar == null) return 1;
      if (br == null) return -1;
      return br.compareTo(ar);
    case CatalogSort.duration:
      return b.totalMinutes.compareTo(a.totalMinutes);
    case CatalogSort.added:
      return b.addedAt.compareTo(a.addedAt);
    case CatalogSort.watched:
      final ad = a.watchLog.isNotEmpty ? a.watchLog.last.date : a.watchDate;
      final bd = b.watchLog.isNotEmpty ? b.watchLog.last.date : b.watchDate;
      if (ad == null && bd == null) return 0;
      if (ad == null) return 1;
      if (bd == null) return -1;
      return bd.compareTo(ad);
    case CatalogSort.relevance:
      return 0;
  }
}

/// Filtra y ordena el catálogo. Es lo que alimenta la pestaña de catálogo.
///
/// Sin búsqueda, `relevance` no significa nada y se ordena por lo más reciente.
List<ContentItem> searchCatalog(
  List<ContentItem> items, {
  String query = '',
  ContentType? type,
  String? genre,
  bool onlyFavorites = false,
  CatalogSort sort = CatalogSort.relevance,
}) {
  final trimmed = query.trim();

  final scored = <(ContentItem, double)>[];
  for (final item in items) {
    if (type != null && item.type != type) continue;
    if (genre != null && !item.genres.contains(genre)) continue;
    if (onlyFavorites && !item.isFavorite) continue;

    if (trimmed.isEmpty) {
      scored.add((item, 0));
      continue;
    }

    final score = scoreItem(item, trimmed);
    if (score > 0) scored.add((item, score));
  }

  final effective = (sort == CatalogSort.relevance && trimmed.isEmpty)
      ? CatalogSort.added
      : sort;

  scored.sort((a, b) {
    if (effective == CatalogSort.relevance) {
      final byScore = b.$2.compareTo(a.$2);
      if (byScore != 0) return byScore;
      return b.$1.addedAt.compareTo(a.$1.addedAt); // desempate estable
    }
    return _compareBySort(a.$1, b.$1, effective);
  });

  return scored.map((e) => e.$1).toList();
}
