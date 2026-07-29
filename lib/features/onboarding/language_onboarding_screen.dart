import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/l10n/app_language.dart';
import '../../core/l10n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/providers.dart';
import '../../shared/widgets/app_buttons.dart';

/// Clave del flag: la pantalla de idioma solo sale una vez, en la instalación.
const languageOnboardedKey = 'language_onboarded';

/// Si el usuario ya pasó por la elección de idioma de bienvenida.
///
/// En una instalación nueva arranca en `false` y se muestra la pantalla; en
/// cuanto el usuario confirma el idioma se pone en `true` y ya no vuelve a
/// salir. Para quien ya venía usando la app se marca hecho en `main()` para no
/// interrumpirlo tras actualizar.
class LanguageOnboardedNotifier extends Notifier<bool> {
  @override
  bool build() =>
      ref.watch(settingsBoxProvider).get(languageOnboardedKey) as bool? ?? false;

  Future<void> markDone() async {
    if (state) return;
    await ref.read(settingsBoxProvider).put(languageOnboardedKey, true);
    state = true;
  }
}

final languageOnboardedProvider =
    NotifierProvider<LanguageOnboardedNotifier, bool>(
  LanguageOnboardedNotifier.new,
);

/// Pantalla de bienvenida (solo la primera vez que se instala la app): deja
/// elegir el idioma para que la app se entienda desde el primer momento.
///
/// Tocar un idioma lo aplica al instante (vista previa en vivo: cabecera y botón
/// cambian de lengua), y "Continuar" fija el idioma, marca el flag y entra a la
/// app. El idioma resaltado de inicio es el que ya resolvió `localeProvider`
/// (el del dispositivo si está soportado, o inglés).
class LanguageOnboardingScreen extends ConsumerWidget {
  const LanguageOnboardingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(localeProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 28),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: AppColors.primaryGradient,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.35),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.language_rounded,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 2),
                        Text(
                          tr('onboarding.language.title'),
                          style: GoogleFonts.poppins(
                            fontSize: 23,
                            fontWeight: FontWeight.w700,
                            height: 1.15,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          tr('onboarding.language.subtitle'),
                          style: GoogleFonts.inter(
                            fontSize: 13.5,
                            height: 1.4,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: AppLanguage.values.length,
                itemBuilder: (context, index) {
                  final lang = AppLanguage.values[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _LanguageOption(
                      lang: lang,
                      selected: lang == current,
                      onTap: () =>
                          ref.read(localeProvider.notifier).setLanguage(lang),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
              child: PrimaryButton(
                label: tr('onboarding.continue'),
                isFullWidth: true,
                onTap: () async {
                  // El idioma ya está aplicado; solo se persiste y se cierra la
                  // bienvenida para no volver a mostrarla.
                  await ref.read(localeProvider.notifier).setLanguage(current);
                  await ref.read(languageOnboardedProvider.notifier).markDone();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fila de idioma: nombre nativo + marca de selección.
class _LanguageOption extends StatelessWidget {
  final AppLanguage lang;
  final bool selected;
  final VoidCallback onTap;

  const _LanguageOption({
    required this.lang,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? AppColors.primary.withValues(alpha: 0.12)
          : AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  lang.nativeName,
                  // `inherit: false` deja el nombre en la fuente del sistema en
                  // vez de Inter (sin glifos árabes/CJK), para que cada escritura
                  // se vea completa y no se corte.
                  style: TextStyle(
                    inherit: false,
                    fontSize: 16,
                    height: 1.4,
                    fontWeight:
                        selected ? FontWeight.w600 : FontWeight.w500,
                    color:
                        selected ? AppColors.primary : AppColors.textPrimary,
                  ),
                ),
              ),
              if (selected)
                Icon(Icons.check_circle, color: AppColors.primary, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}
