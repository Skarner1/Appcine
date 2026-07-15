import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';
import '../../providers/providers.dart';

/// Clave del flag: el aviso sale una vez en la vida de la instalación.
const firstRunHintSeenKey = 'first_run_hint_seen';

/// Comprueba si hay red. Solo mira si el aparato está conectado a algo, no si
/// internet funciona de verdad: para el aviso basta y no cuesta una petición.
Future<bool> hasConnection() async {
  try {
    final result = await Connectivity().checkConnectivity();
    return !result.contains(ConnectivityResult.none) && result.isNotEmpty;
  } catch (_) {
    // Si no se puede saber, se asume que sí: más vale invitar a probar que
    // decirle a alguien con red que no la tiene.
    return true;
  }
}

/// Si al usuario ya se le enseñó el aviso.
class FirstRunHintNotifier extends Notifier<bool> {
  @override
  bool build() =>
      ref.watch(settingsBoxProvider).get(firstRunHintSeenKey) as bool? ?? false;

  Future<void> markSeen() async {
    if (state) return;
    await ref.read(settingsBoxProvider).put(firstRunHintSeenKey, true);
    state = true;
  }
}

final firstRunHintSeenProvider =
    NotifierProvider<FirstRunHintNotifier, bool>(FirstRunHintNotifier.new);

/// Aviso de bienvenida que señala el botón de búsqueda online.
///
/// Sale una sola vez, la primera que se abre la app. Tiene dos caras porque
/// mandarle a buscar en internet a alguien sin cobertura es una pérdida de
/// tiempo: sin red se explica que puede agregar a mano ahora y traer la carátula
/// más tarde.
class FirstRunHint extends StatelessWidget {
  /// Si hay conexión. Cambia el mensaje entero.
  final bool online;

  /// Abrir la búsqueda online (solo con red).
  final VoidCallback onSearchOnline;

  /// Abrir el formulario a mano (solo sin red).
  final VoidCallback onAddManually;

  final VoidCallback onDismiss;

  const FirstRunHint({
    super.key,
    required this.online,
    required this.onSearchOnline,
    required this.onAddManually,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final accent = online ? AppColors.primary : AppColors.warning;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                online ? Icons.travel_explore_rounded : Icons.wifi_off_rounded,
                size: 22,
                color: accent,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      online
                          ? '¡Bienvenido a CineLog!'
                          : 'Estás sin conexión',
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      online
                          ? 'Pincha arriba en 🔍 para agregar pelis, series, '
                              'animes, mangas o libros buscándolos en internet: '
                              'se traen con su portada y su info.'
                          : 'Para buscar en internet necesitas red. Puedes '
                              'agregar lo que quieras a mano ahora mismo y '
                              'traerle la portada desde internet más tarde.',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        height: 1.45,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onDismiss,
                icon: const Icon(Icons.close, size: 18),
                color: AppColors.textMuted,
                tooltip: 'Entendido',
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: online ? onSearchOnline : onAddManually,
              icon: Icon(
                online ? Icons.travel_explore_rounded : Icons.add,
                size: 18,
              ),
              label: Text(
                online ? 'Buscar en internet' : 'Agregar a mano',
              ),
              style: TextButton.styleFrom(
                foregroundColor: accent,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
