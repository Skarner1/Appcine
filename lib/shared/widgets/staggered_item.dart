import 'package:flutter/material.dart';

/// Entrada escalonada para listas/grids: fade + slide hacia arriba,
/// con retraso incremental por índice.
class StaggeredItem extends StatelessWidget {
  final int index;
  final Widget child;

  const StaggeredItem({super.key, required this.index, required this.child});

  @override
  Widget build(BuildContext context) {
    final delayMs = (index.clamp(0, 8)) * 60;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 350 + delayMs),
      curve: Interval(
        delayMs / (350 + delayMs),
        1,
        curve: Curves.easeOutCubic,
      ),
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 24 * (1 - value)),
          child: child,
        ),
      ),
      child: child,
    );
  }
}
