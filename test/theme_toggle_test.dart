import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:cineapp/core/theme/app_colors.dart';
import 'package:cineapp/data/models/content_adapters.dart';
import 'package:cineapp/data/models/content_item.dart';
import 'package:cineapp/data/repositories/content_repository.dart';
import 'package:cineapp/providers/providers.dart';

void main() {
  late Directory tempDir;
  late Box<ContentItem> contentBox;
  late Box<dynamic> settingsBox;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('cinelog_theme_test');
    Hive.init(tempDir.path);
    Hive.registerAdapter(ContentItemAdapter());
    contentBox = await Hive.openBox<ContentItem>('content_theme_test');
    settingsBox = await Hive.openBox<dynamic>('settings_theme_test');
  });

  tearDownAll(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  setUp(() async {
    await settingsBox.clear();
  });

  ProviderContainer makeContainer() {
    final container = ProviderContainer(
      overrides: [
        contentRepositoryProvider
            .overrideWithValue(ContentRepository(contentBox)),
        settingsBoxProvider.overrideWithValue(settingsBox),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('themeModeProvider', () {
    test('por defecto sigue al sistema cuando no hay ajuste guardado', () {
      final container = makeContainer();
      expect(container.read(themeModeProvider), ThemeMode.system);
    });

    test('lee el modo persistido al construirse', () async {
      await settingsBox.put('theme_mode', 'light');
      final container = makeContainer();
      expect(container.read(themeModeProvider), ThemeMode.light);
    });

    test('setMode actualiza el estado y lo persiste', () async {
      final container = makeContainer();

      await container.read(themeModeProvider.notifier).setMode(ThemeMode.light);
      expect(container.read(themeModeProvider), ThemeMode.light);
      expect(settingsBox.get('theme_mode'), 'light');

      await container.read(themeModeProvider.notifier).setMode(ThemeMode.dark);
      expect(container.read(themeModeProvider), ThemeMode.dark);
      expect(settingsBox.get('theme_mode'), 'dark');
    });
  });

  group('AppColors paleta activa', () {
    test('setBrightness alterna los colores semánticos', () {
      AppColors.setBrightness(Brightness.dark);
      expect(AppColors.background, AppColors.darkPalette.background);
      expect(AppColors.surface, AppColors.darkPalette.surface);
      expect(AppColors.textPrimary, AppColors.darkPalette.textPrimary);
      expect(AppColors.border, AppColors.darkPalette.border);

      AppColors.setBrightness(Brightness.light);
      expect(AppColors.background, AppColors.lightPalette.background);
      expect(AppColors.surface, AppColors.lightPalette.surface);
      expect(AppColors.textPrimary, AppColors.lightPalette.textPrimary);
      expect(AppColors.border, AppColors.lightPalette.border);

      // Restaura el default para no afectar a otros tests.
      AppColors.setBrightness(Brightness.dark);
    });

    test('los acentos de marca no cambian entre temas', () {
      const brand = AppColors.primary;
      AppColors.setBrightness(Brightness.light);
      expect(AppColors.primary, brand);
      AppColors.setBrightness(Brightness.dark);
      expect(AppColors.primary, brand);
    });
  });
}
