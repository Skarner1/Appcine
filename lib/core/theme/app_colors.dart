import 'package:flutter/material.dart';

/// Grupo de colores que cambian entre el tema claro y el oscuro
/// (fondos, texto, bordes). Los acentos de marca viven aparte en [AppColors]
/// porque funcionan igual sobre cualquier fondo.
class AppPalette {
  const AppPalette({
    required this.background,
    required this.surface,
    required this.surfaceElevated,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.border,
    required this.borderStrong,
    required this.divider,
  });

  final Color background;
  final Color surface;
  final Color surfaceElevated;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color border;
  final Color borderStrong;
  final Color divider;
}

/// Paleta oficial CineLog Pro.
///
/// Los acentos cinematográficos (rojo, cyan, ámbar y estados) son constantes:
/// se ven bien tanto en claro como en oscuro. Los colores semánticos de
/// superficie y texto son *getters* que devuelven la paleta activa, de modo que
/// las ~226 referencias existentes (`AppColors.surface`, etc.) cambian solas al
/// alternar el tema. Fija la paleta con [setBrightness] antes de reconstruir la
/// interfaz (se hace en `main()` y en `CineLogApp`).
class AppColors {
  AppColors._();

  // Acentos cinematográficos (idénticos en claro y oscuro).
  static const Color primary = Color(0xFFE50914); // Rojo cinemático
  static const Color primarySoft = Color(0xFFB81D25); // Rojo suave (hover)
  static const Color secondary = Color(0xFF00B4D8); // Cyan info/duración
  static const Color tertiary = Color(0xFFFFB703); // Ámbar recomendaciones

  // Estados.
  static const Color success = Color(0xFF2ECC71); // Visto / Completado
  static const Color warning = Color(0xFFF39C12); // Pendiente / Falta ver
  static const Color info = Color(0xFF3498DB); // Recomendado
  static const Color error = Color(0xFFE74C3C); // Eliminar / Error

  /// Paleta oscura original — tono cinematográfico profundo.
  static const AppPalette darkPalette = AppPalette(
    background: Color(0xFF0F0F0F), // Negro profundo
    surface: Color(0xFF1A1A1A), // Tarjetas/secciones
    surfaceElevated: Color(0xFF252525), // Elevación superior
    textPrimary: Color(0xFFF5F5F5), // Blanco hueso
    textSecondary: Color(0xFFB0B0B0), // Gris claro
    textMuted: Color(0xFF707070), // Gris medio
    // Bordes y divisores — hairlines sutiles con un matiz frío premium.
    border: Color(0xFF2F2F37), // borde estándar
    borderStrong: Color(0xFF3C3C46), // énfasis / foco / hover
    divider: Color(0xFF26262E), // divisores internos
  );

  /// Paleta clara — fondos suaves, alto contraste de texto.
  static const AppPalette lightPalette = AppPalette(
    background: Color(0xFFF4F4F7), // Gris muy claro
    surface: Color(0xFFFFFFFF), // Tarjetas blancas
    surfaceElevated: Color(0xFFEAEAEF), // Inputs / elevación
    textPrimary: Color(0xFF17171A), // Casi negro
    textSecondary: Color(0xFF5C5C66), // Gris medio
    textMuted: Color(0xFF9A9AA5), // Gris suave
    border: Color(0xFFE1E1E7),
    borderStrong: Color(0xFFC6C6D0), // énfasis / foco / hover
    divider: Color(0xFFD6D6DE),
  );

  // Degradados cinematográficos (marca: iguales en claro y oscuro).
  static const List<Color> primaryGradient = [
    Color(0xFFFF3B44), // rojo brillante
    Color(0xFFC01019), // rojo profundo
  ];

  static AppPalette _active = darkPalette;

  /// Paleta activa actual.
  static AppPalette get palette => _active;

  /// Fija la paleta según el brillo. Llamar antes de reconstruir la UI.
  static void setBrightness(Brightness brightness) {
    _active = brightness == Brightness.dark ? darkPalette : lightPalette;
  }

  // Colores semánticos (dependen del tema activo).
  static Color get background => _active.background;
  static Color get surface => _active.surface;
  static Color get surfaceElevated => _active.surfaceElevated;
  static Color get textPrimary => _active.textPrimary;
  static Color get textSecondary => _active.textSecondary;
  static Color get textMuted => _active.textMuted;
  static Color get border => _active.border;
  static Color get borderStrong => _active.borderStrong;
  static Color get divider => _active.divider;
}
