import 'package:flutter/widgets.dart';

/// Géneros disponibles para catalogar contenido.
const List<String> kGenres = [
  'Acción',
  'Aventura',
  'Animación',
  'Biografía',
  'Ciencia Ficción',
  'Comedia',
  'Crimen',
  'Documental',
  'Drama',
  'Familiar',
  'Fantasía',
  'Guerra',
  'Historia',
  'Misterio',
  'Musical',
  'Romance',
  'Suspenso',
  'Terror',
  'Western',
];

/// Breakpoints responsive de la app.
/// - Compact: < 360dp → 1 columna, botones apilados
/// - Medium: 360–600dp → 2 columnas
/// - Expanded: 600–900dp → 3 columnas
/// - Wide: > 900dp → 4 columnas
class Responsive {
  Responsive._();

  static const double compact = 360;
  static const double medium = 600;
  static const double expanded = 900;

  static bool isCompact(BuildContext context) =>
      MediaQuery.sizeOf(context).width < compact;

  static int gridColumns(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width < compact) return 1;
    if (width < medium) return 2;
    if (width < expanded) return 3;
    return 4;
  }

  /// Altura mínima de botón: 48dp en pantallas compactas, 56dp en el resto.
  static double buttonHeight(BuildContext context) =>
      isCompact(context) ? 48.0 : 56.0;
}
