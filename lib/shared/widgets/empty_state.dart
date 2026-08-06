import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';
import 'app_buttons.dart';

/// Estado vacío con visual animado (pulso suave) y mensaje amigable.
///
/// Por defecto muestra un icono en un círculo. Si se pasa [imageAsset], muestra
/// esa ilustración 3D de marca dentro de un tile redondeado (los renders vienen
/// sobre negro con glow rojo, así que el tile los enmarca bien en claro y
/// oscuro por igual).
class EmptyState extends StatefulWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? imageAsset;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.imageAsset,
  });

  @override
  State<EmptyState> createState() => _EmptyStateState();
}

class _EmptyStateState extends State<EmptyState>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                final t = Curves.easeInOut.transform(_controller.value);
                return Transform.scale(
                  scale: 1 + 0.06 * t,
                  child: widget.imageAsset != null
                      ? _ImageTile(asset: widget.imageAsset!, glow: t)
                      : _IconCircle(icon: widget.icon, glow: t),
                );
              },
            ),
            const SizedBox(height: 24),
            Text(
              widget.title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.message,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            if (widget.actionLabel != null && widget.onAction != null) ...[
              const SizedBox(height: 24),
              PrimaryButton(
                label: widget.actionLabel!,
                icon: Icons.add,
                isFullWidth: false,
                onTap: widget.onAction,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _IconCircle extends StatelessWidget {
  final IconData icon;
  final double glow;

  const _IconCircle({required this.icon, required this.glow});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 110,
      height: 110,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.surfaceElevated,
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.10 * glow),
            blurRadius: 30,
            spreadRadius: 6,
          ),
        ],
      ),
      child: Icon(icon, size: 48, color: AppColors.textMuted),
    );
  }
}

/// Tile de la ilustración 3D. Fondo negro propio (igual que el render) para que
/// se vea intencional en cualquier tema, con un glow rojo que respira.
class _ImageTile extends StatelessWidget {
  final String asset;
  final double glow;

  const _ImageTile({required this.asset, required this.glow});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 156,
      height: 156,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F0F),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.22 * glow),
            blurRadius: 36,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Image.asset(asset, fit: BoxFit.cover),
    );
  }
}
