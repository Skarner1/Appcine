import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'app.dart';
import 'core/l10n/app_language.dart';
import 'core/l10n/strings.dart';
import 'core/services/notification_service.dart';
import 'core/theme/app_colors.dart';
import 'data/migrations.dart';
import 'data/models/content_adapters.dart';
import 'data/models/content_item.dart';
import 'data/repositories/content_repository.dart';
import 'data/seed_data.dart';
import 'providers/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Almacenamiento local offline-first.
  await Hive.initFlutter();
  Hive.registerAdapter(WatchEventAdapter());
  Hive.registerAdapter(ContentItemAdapter());
  final contentBox = await Hive.openBox<ContentItem>('content');
  final settingsBox = await Hive.openBox<dynamic>('settings');

  // La app ya no carga contenido de ejemplo: el usuario agrega el suyo.
  // Limpieza única: elimina el contenido de ejemplo sembrado por versiones
  // anteriores (identificado por su título), respetando lo que agregó el usuario.
  if (settingsBox.get('example_cleared') != true) {
    if (settingsBox.get('seeded') == true) {
      final titles = seedTitles();
      final idsToRemove = contentBox.values
          .where((item) => titles.contains(item.title))
          .map((item) => item.id)
          .toList();
      await contentBox.deleteAll(idsToRemove);
    }
    await settingsBox.put('example_cleared', true);
  }

  // Backfill único del diario de visionados para el contenido guardado antes de
  // que existiera (ver migrateWatchLog).
  if (settingsBox.get(migratedWatchLogKey) != true) {
    final migrated = migrateWatchLog(contentBox.values);
    if (migrated.isNotEmpty) {
      await contentBox.putAll({for (final item in migrated) item.id: item});
    }
    await settingsBox.put(migratedWatchLogKey, true);
  }

  // Paleta inicial según el tema guardado (evita parpadeo en el primer frame).
  final storedThemeMode = settingsBox.get('theme_mode') as String?;
  final startsDark = switch (storedThemeMode) {
    'light' => false,
    'dark' => true,
    _ => WidgetsBinding.instance.platformDispatcher.platformBrightness ==
        Brightness.dark,
  };
  AppColors.setBrightness(startsDark ? Brightness.dark : Brightness.light);

  // Idioma inicial: el guardado, o el del dispositivo si está soportado, o
  // inglés. Se fija antes del primer frame para evitar parpadeo de textos.
  final storedLang = settingsBox.get('app_language') as String?;
  final language = AppLanguage.resolveInitial(
    storedLang,
    WidgetsBinding.instance.platformDispatcher.locale,
  );
  S.setLanguage(language);

  // Formateo de fechas para todos los idiomas soportados + el activo por defecto.
  for (final l in AppLanguage.values) {
    await initializeDateFormatting(l.code);
  }
  Intl.defaultLocale = language.code;

  // Notificaciones locales (no debe bloquear el arranque si falla).
  try {
    await NotificationService.instance.init();
  } catch (_) {}

  runApp(
    ProviderScope(
      overrides: [
        contentRepositoryProvider
            .overrideWithValue(ContentRepository(contentBox)),
        settingsBoxProvider.overrideWithValue(settingsBox),
      ],
      child: const CineLogApp(),
    ),
  );
}
