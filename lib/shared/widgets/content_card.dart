import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/content_item.dart';
import 'poster_image.dart';
import 'scale_tap.dart';
import 'status_badge.dart';

/// Tarjeta de contenido para el grid del catálogo.
/// Póster 2:3, radio 16, overlay degradado, badge de estado y meta info.
class ContentCard extends StatelessWidget {
  final ContentItem item;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const ContentCard({
    super.key,
    required this.item,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return ScaleTap(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: AspectRatio(
            aspectRatio: 2 / 3,
            child: Stack(
              fit: StackFit.expand,
              children: [
                PosterImage(item: item),
                // Overlay degradado inferior para legibilidad del texto.
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: [0.45, 0.78, 1.0],
                      colors: [
                        Colors.transparent,
                        Color(0xB3000000),
                        Color(0xE6000000),
                      ],
                    ),
                  ),
                ),
                // Badge de estado, esquina superior derecha.
                Positioned(
                  top: 10,
                  right: 10,
                  child: StatusBadge(status: item.status, compact: true),
                ),
                if (item.isFavorite)
                  const Positioned(
                    top: 10,
                    left: 10,
                    child: Icon(
                      Icons.favorite_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                // Info inferior.
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 12,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (item.genres.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            item.genres.first,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                        ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(
                            Icons.schedule,
                            size: 13,
                            color: AppColors.secondary,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              _metaText(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                          if (item.userRating != null) ...[
                            const Icon(
                              Icons.star_rounded,
                              size: 14,
                              color: AppColors.tertiary,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              item.userRating!.toStringAsFixed(1),
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.tertiary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _metaText() {
    if (item.type.hasEpisodes) {
      final episodes = item.episodes;
      if (episodes == null) return item.type.label;
      return '$episodes ep · ${formatDuration(item.durationMinutes)}';
    }
    return formatDuration(item.durationMinutes);
  }
}
