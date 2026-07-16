import 'package:flutter/widgets.dart';

/// Idiomas que soporta la app. El orden es el que se muestra en el selector.
///
/// Los códigos coinciden con [Locale.languageCode] para poder cablearlos con
/// `flutter_localizations` y el formateo de fechas de `intl`.
enum AppLanguage {
  en(Locale('en'), 'English'),
  es(Locale('es'), 'Español'),
  pt(Locale('pt'), 'Português'),
  ko(Locale('ko'), '한국어'),
  ja(Locale('ja'), '日本語'),
  tr(Locale('tr'), 'Türkçe'),
  zh(Locale('zh'), '中文'),
  ar(Locale('ar'), 'العربية');

  const AppLanguage(this.locale, this.nativeName);

  /// Locale para `MaterialApp` e `intl`.
  final Locale locale;

  /// Nombre del idioma en su propia escritura (lo que ve el usuario).
  final String nativeName;

  String get code => locale.languageCode;

  /// El árabe se escribe de derecha a izquierda; Flutter aplica el
  /// [TextDirection] automáticamente, pero exponerlo aquí es útil para casos
  /// puntuales.
  bool get isRtl => this == AppLanguage.ar;

  static AppLanguage fromCode(String? code) {
    for (final lang in AppLanguage.values) {
      if (lang.code == code) return lang;
    }
    return AppLanguage.en;
  }

  /// Idioma inicial: el guardado por el usuario si existe; si no, el del
  /// dispositivo cuando esté entre los soportados; en último caso, inglés.
  static AppLanguage resolveInitial(String? storedCode, Locale deviceLocale) {
    if (storedCode != null) {
      for (final lang in AppLanguage.values) {
        if (lang.code == storedCode) return lang;
      }
    }
    for (final lang in AppLanguage.values) {
      if (lang.code == deviceLocale.languageCode) return lang;
    }
    return AppLanguage.en;
  }
}
