import 'package:flutter/material.dart';

/// Paleta oficial CineLog Pro — tono cinematográfico oscuro.
class AppColors {
  AppColors._();

  // Fondos
  static const Color background = Color(0xFF0F0F0F); // Negro profundo
  static const Color surface = Color(0xFF1A1A1A); // Tarjetas/secciones
  static const Color surfaceElevated = Color(0xFF252525); // Elevación superior

  // Acentos cinematográficos
  static const Color primary = Color(0xFFE50914); // Rojo cinemático
  static const Color primarySoft = Color(0xFFB81D25); // Rojo suave (hover)
  static const Color secondary = Color(0xFF00B4D8); // Cyan info/duración
  static const Color tertiary = Color(0xFFFFB703); // Ámbar recomendaciones

  // Estados
  static const Color success = Color(0xFF2ECC71); // Visto / Completado
  static const Color warning = Color(0xFFF39C12); // Pendiente / Falta ver
  static const Color info = Color(0xFF3498DB); // Recomendado
  static const Color error = Color(0xFFE74C3C); // Eliminar / Error

  // Texto
  static const Color textPrimary = Color(0xFFF5F5F5); // Blanco hueso
  static const Color textSecondary = Color(0xFFB0B0B0); // Gris claro
  static const Color textMuted = Color(0xFF707070); // Gris medio

  // Bordes y divisores — hairlines sutiles con un matiz frío premium.
  static const Color border = Color(0xFF2F2F37); // borde estándar
  static const Color borderStrong = Color(0xFF3C3C46); // énfasis / foco / hover
  static const Color divider = Color(0xFF26262E); // divisores internos

  // Degradados cinematográficos.
  static const List<Color> primaryGradient = [
    Color(0xFFFF3B44), // rojo brillante
    Color(0xFFC01019), // rojo profundo
  ];
}
