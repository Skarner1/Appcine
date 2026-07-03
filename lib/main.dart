import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'app.dart';
import 'core/services/notification_service.dart';
import 'data/models/content_adapters.dart';
import 'data/models/content_item.dart';
import 'data/repositories/content_repository.dart';
import 'data/seed_data.dart';
import 'providers/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Almacenamiento local offline-first.
  await Hive.initFlutter();
  Hive.registerAdapter(ContentItemAdapter());
  final contentBox = await Hive.openBox<ContentItem>('content');
  final settingsBox = await Hive.openBox<dynamic>('settings');

  // Contenido de ejemplo solo en el primer arranque.
  if (settingsBox.get('seeded') != true) {
    final seed = buildSeedContent();
    await contentBox.putAll({for (final item in seed) item.id: item});
    await settingsBox.put('seeded', true);
  }

  // Fechas en español.
  await initializeDateFormatting('es');
  Intl.defaultLocale = 'es';

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
