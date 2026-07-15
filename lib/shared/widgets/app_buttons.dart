import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';

/// Botón principal de la app: degradado cinematográfico, glow suave, esquinas
/// de 16dp y micro-interacción de pulsado (escala a 0.97). Alto mínimo 48dp
/// (56dp en pantallas normales), nunca se comprime, texto con ellipsis.
class PrimaryButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool isFullWidth;
  final Color? color;
  final bool isLoading;

  const PrimaryButton({
    super.key,
    required this.label,
    this.icon,
    required this.onTap,
    this.isFullWidth = true,
    this.color,
    this.isLoading = false,
  });

  @override
  State<PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<PrimaryButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final height = Responsive.buttonHeight(context);
    final base = widget.color ?? AppColors.primary;
    final enabled = widget.onTap != null && !widget.isLoading;

    // Degradado: la paleta oficial cuando es el color por defecto; si viene un
    // color personalizado (p. ej. rojo de eliminar), se genera un degradado
    // oscureciéndolo ligeramente.
    final gradientColors = widget.color != null
        ? [base, Color.lerp(base, Colors.black, 0.28)!]
        : AppColors.primaryGradient;
    final colors = enabled
        ? gradientColors
        : gradientColors.map((c) => c.withValues(alpha: 0.45)).toList();

    final List<Widget> children = widget.isLoading
        ? const [
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Colors.white,
              ),
            ),
          ]
        : [
            if (widget.icon != null) ...[
              Icon(widget.icon, size: 20, color: Colors.white),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Text(
                widget.label,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  letterSpacing: 0.3,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ];

    return AnimatedScale(
      scale: _pressed && enabled ? 0.97 : 1.0,
      duration: const Duration(milliseconds: 110),
      curve: Curves.easeOut,
      child: ConstrainedBox(
        constraints: BoxConstraints(minWidth: widget.isFullWidth ? 0 : 120),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: colors,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: base.withValues(alpha: 0.38),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: enabled ? widget.onTap : null,
              onTapDown: (_) => setState(() => _pressed = true),
              onTapUp: (_) => setState(() => _pressed = false),
              onTapCancel: () => setState(() => _pressed = false),
              borderRadius: BorderRadius.circular(16),
              splashColor: Colors.white.withValues(alpha: 0.12),
              highlightColor: Colors.white.withValues(alpha: 0.06),
              child: SizedBox(
                height: height,
                width: widget.isFullWidth ? double.infinity : null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    mainAxisSize: widget.isFullWidth
                        ? MainAxisSize.max
                        : MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: children,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Botón secundario (outline) con las mismas garantías anti-compresión.
class SecondaryButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool isFullWidth;
  final Color? foreground;

  const SecondaryButton({
    super.key,
    required this.label,
    this.icon,
    required this.onTap,
    this.isFullWidth = true,
    this.foreground,
  });

  @override
  Widget build(BuildContext context) {
    final buttonHeight = Responsive.buttonHeight(context);
    final textColor = foreground ?? AppColors.textPrimary;

    return SizedBox(
      width: isFullWidth ? double.infinity : null,
      height: buttonHeight,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: textColor,
          backgroundColor: AppColors.surfaceElevated.withValues(alpha: 0.4),
          side: BorderSide(color: AppColors.borderStrong, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          minimumSize: Size(isFullWidth ? double.infinity : 120, buttonHeight),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 20, color: textColor),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Text(
                label,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  letterSpacing: 0.3,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// FAB de 64dp con degradado, esquinas redondeadas (20dp) y entrada animada
/// (scale + rotate, elasticOut).
class AppFab extends StatefulWidget {
  final IconData icon;
  final String? label;
  final VoidCallback onTap;

  const AppFab({
    super.key,
    required this.icon,
    this.label,
    required this.onTap,
  });

  @override
  State<AppFab> createState() => _AppFabState();
}

class _AppFabState extends State<AppFab> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 400),
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curved =
        CurvedAnimation(parent: _controller, curve: Curves.elasticOut);

    return ScaleTransition(
      scale: curved,
      child: RotationTransition(
        turns: Tween<double>(begin: -0.08, end: 0).animate(curved),
        child: SizedBox(
          height: 64,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: AppColors.primaryGradient,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.4),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.onTap,
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: widget.label != null ? 24 : 20,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(widget.icon, color: Colors.white, size: 26),
                      if (widget.label != null) ...[
                        const SizedBox(width: 10),
                        Text(
                          widget.label!,
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
