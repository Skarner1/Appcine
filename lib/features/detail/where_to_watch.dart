import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/l10n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/content_item.dart';
import '../../shared/widgets/app_buttons.dart';

/// Sección "Dónde ver / Dónde leer" del detalle.
///
/// No alojamos, descargamos ni reproducimos ningún contenido: solo abrimos la
/// app o web OFICIAL de cada plataforma/tienda con el título ya buscado. Es el
/// mismo enfoque legal que JustWatch — enlazar, no distribuir.
class WhereToWatch extends StatelessWidget {
  final ContentItem item;

  const WhereToWatch({super.key, required this.item});

  /// Una plataforma/tienda a la que enlazamos por búsqueda del título.
  static _Platform get _justWatch => _Platform(
        name: 'JustWatch',
        color: AppColors.tertiary,
        url: (q) => 'https://www.justwatch.com/search?q=$q',
      );

  /// Streaming de vídeo (series, pelis, documentales, anime, cortos).
  static List<_Platform> _videoPlatforms(bool isAnime) => [
        _Platform(
          name: 'Netflix',
          color: const Color(0xFFE50914),
          url: (q) => 'https://www.netflix.com/search?q=$q',
        ),
        _Platform(
          name: 'Prime Video',
          color: const Color(0xFF00A8E1),
          url: (q) => 'https://www.primevideo.com/search/?phrase=$q',
        ),
        _Platform(
          name: 'Disney+',
          color: const Color(0xFF1F80E0),
          url: (q) => 'https://www.disneyplus.com/search?q=$q',
        ),
        _Platform(
          name: 'Max',
          color: const Color(0xFF3B1EAE),
          url: (q) => 'https://play.max.com/search?q=$q',
        ),
        // El anime rara vez está en las grandes: Crunchyroll es la casa.
        if (isAnime)
          _Platform(
            name: 'Crunchyroll',
            color: const Color(0xFFF47521),
            url: (q) => 'https://www.crunchyroll.com/search?q=$q',
          ),
      ];

  /// Tiendas/lecturas para libros y mangas.
  static List<_Platform> get _readPlatforms => [
        _Platform(
          name: 'Amazon',
          color: const Color(0xFFFF9900),
          url: (q) => 'https://www.amazon.com/s?k=$q',
        ),
        _Platform(
          name: 'Google Books',
          color: const Color(0xFF4285F4),
          url: (q) => 'https://www.google.com/search?tbm=bks&q=$q',
        ),
      ];

  Future<void> _open(BuildContext context, String rawUrl, String name) async {
    // Capturamos el messenger antes del await para no usar el context cruzando
    // el hueco asíncrono.
    final messenger = ScaffoldMessenger.of(context);
    var ok = false;
    try {
      ok = await launchUrl(
        Uri.parse(rawUrl),
        // Abre la app oficial si está instalada (App Links) o el navegador.
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      ok = false;
    }
    if (!ok) {
      messenger.showSnackBar(
        SnackBar(content: Text(tr('detail.whereToWatch.error', {'app': name}))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isRead = item.type.isRead;
    final query = Uri.encodeQueryComponent(item.title);

    final platforms =
        isRead ? _readPlatforms : _videoPlatforms(item.type == ContentType.anime);

    final findLabel =
        tr(isRead ? 'detail.whereToRead.find' : 'detail.whereToWatch.find');
    final findUrl = isRead
        ? 'https://www.google.com/search?tbm=bks&q=$query'
        : _justWatch.url(query);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isRead ? Icons.menu_book_rounded : Icons.play_circle_fill_rounded,
                color: AppColors.primary,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  tr(isRead
                      ? 'detail.section.whereToRead'
                      : 'detail.section.whereToWatch'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Acción principal: el buscador que responde "¿dónde está disponible?"
          // (JustWatch para vídeo, Google Books para lectura).
          PrimaryButton(
            label: findLabel,
            icon: Icons.travel_explore_rounded,
            onTap: () => _open(context, findUrl, isRead ? 'Google Books' : 'JustWatch'),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final p in platforms)
                _PlatformChip(
                  name: p.name,
                  color: p.color,
                  onTap: () => _open(context, p.url(query), p.name),
                ),
              // Tráiler (solo vídeo): abre la búsqueda en YouTube.
              if (!isRead)
                _PlatformChip(
                  name: tr('detail.whereToWatch.trailer'),
                  color: const Color(0xFFFF0000),
                  icon: Icons.smart_display_rounded,
                  onTap: () => _open(
                    context,
                    'https://www.youtube.com/results?search_query=$query+trailer',
                    'YouTube',
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.info_outline_rounded,
                  size: 14, color: AppColors.textMuted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  tr('detail.whereToWatch.hint'),
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Platform {
  final String name;
  final Color color;
  final String Function(String encodedQuery) url;

  const _Platform({required this.name, required this.color, required this.url});
}

/// Pastilla de plataforma con acento de marca. Usamos el color de cada servicio
/// (no su logo, para no meternos con marcas registradas) más un icono genérico.
class _PlatformChip extends StatelessWidget {
  final String name;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  const _PlatformChip({
    required this.name,
    required this.color,
    required this.onTap,
    this.icon = Icons.play_circle_fill_rounded,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.45)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Text(
                name,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.north_east_rounded,
                  size: 13, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
