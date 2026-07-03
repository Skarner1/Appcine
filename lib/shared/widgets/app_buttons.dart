import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';

/// Botón principal de la app: alto mínimo 48dp (56dp en pantallas normales),
/// nunca se comprime, texto con ellipsis.
class PrimaryButton extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final buttonHeight = Responsive.buttonHeight(context);
    final background = color ?? AppColors.primary;

    return SizedBox(
      width: isFullWidth ? double.infinity : null,
      height: buttonHeight,
      child: ElevatedButton(
        onPressed: isLoading ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: background,
          foregroundColor: Colors.white,
          disabledBackgroundColor: background.withValues(alpha: 0.5),
          disabledForegroundColor: Colors.white70,
          elevation: 4,
          shadowColor: background.withValues(alpha: 0.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          minimumSize: Size(isFullWidth ? double.infinity : 120, buttonHeight),
        ),
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 20),
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
          side: const BorderSide(color: AppColors.border, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
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

/// FAB de 64dp con esquinas redondeadas (20dp) y entrada animada
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
          child: Material(
            color: AppColors.primary,
            elevation: 8,
            shadowColor: AppColors.primary.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(20),
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
    );
  }
}
