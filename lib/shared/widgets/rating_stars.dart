import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';

/// Calificación 1–10 representada en 5 estrellas (cada una vale 2 puntos),
/// con media estrella permitida.
class RatingStars extends StatelessWidget {
  final double? rating; // 1.0 – 10.0
  final double size;
  final bool showValue;

  /// Si se define, las estrellas son interactivas (tap = media estrella).
  final ValueChanged<double>? onChanged;

  const RatingStars({
    super.key,
    required this.rating,
    this.size = 22,
    this.showValue = true,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final value = ((rating ?? 0) / 2).clamp(0.0, 5.0); // a escala 0–5

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 5; i++) _buildStar(i, value),
        if (showValue) ...[
          const SizedBox(width: 8),
          Text(
            rating == null ? '—' : rating!.toStringAsFixed(1),
            style: GoogleFonts.poppins(
              fontSize: size * 0.62,
              fontWeight: FontWeight.w600,
              color: AppColors.tertiary,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStar(int index, double value) {
    final filled = value - index;
    final IconData icon;
    if (filled >= 0.75) {
      icon = Icons.star_rounded;
    } else if (filled >= 0.25) {
      icon = Icons.star_half_rounded;
    } else {
      icon = Icons.star_outline_rounded;
    }

    final star = Icon(
      icon,
      size: size,
      color: filled >= 0.25 ? AppColors.tertiary : AppColors.textMuted,
    );

    if (onChanged == null) return star;

    // Interactivo: mitad izquierda = media estrella, derecha = completa.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: (details) {
        final isLeftHalf = details.localPosition.dx < size / 2;
        final newValue = (index + (isLeftHalf ? 0.5 : 1.0)) * 2;
        onChanged!(newValue.clamp(1.0, 10.0));
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 1),
        child: star,
      ),
    );
  }
}
