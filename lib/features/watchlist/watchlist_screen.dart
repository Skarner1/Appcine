import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/content_item.dart';
import '../../providers/providers.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/horizontal_content_card.dart';
import '../../shared/widgets/poster_image.dart';
import '../../shared/widgets/shimmer_card.dart';
import '../../shared/widgets/staggered_item.dart';
import '../content_form/content_form_screen.dart';
import '../detail/content_detail_screen.dart';
import '../roulette/roulette_screen.dart';

/// Tab 2 — Por Ver: segmented control con Falta Ver | Volver a Ver | Vistos.
class WatchlistScreen extends ConsumerStatefulWidget {
  const WatchlistScreen({super.key});

  @override
  ConsumerState<WatchlistScreen> createState() => _WatchlistScreenState();
}

class _WatchlistScreenState extends ConsumerState<WatchlistScreen> {
  WatchlistTab _tab = WatchlistTab.pending;

  @override
  Widget build(BuildContext context) {
    final asyncItems = ref.watch(contentListProvider);
    final items = ref.watch(watchlistItemsProvider(_tab));

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Por Ver',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                _RouletteButton(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const RouletteScreen(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _SegmentedControl(
              selected: _tab,
              onChanged: (tab) => setState(() => _tab = tab),
              onItemDropped: _moveItem,
            ),
          ),
          if (items.isNotEmpty) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Icon(
                    Icons.drag_indicator,
                    size: 15,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Mantén pulsada una tarjeta y arrástrala a otra lista',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          Expanded(
            child: asyncItems.when(
              loading: () => ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
                itemCount: 4,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (_, _) => const ShimmerListTile(),
              ),
              error: (error, _) => EmptyState(
                icon: Icons.error_outline,
                title: 'Algo salió mal',
                message: '$error',
              ),
              data: (_) => items.isEmpty
                  ? EmptyState(
                      icon: switch (_tab) {
                        WatchlistTab.pending => Icons.playlist_add_check,
                        WatchlistTab.rewatch => Icons.replay,
                        WatchlistTab.seen => Icons.check_circle_outline,
                      },
                      title: switch (_tab) {
                        WatchlistTab.pending => 'Nada pendiente',
                        WatchlistTab.rewatch => 'Nada para repetir',
                        WatchlistTab.seen => 'Aún no has visto nada',
                      },
                      message: switch (_tab) {
                        WatchlistTab.pending =>
                          'Agrega contenido a tu catálogo y aparecerá aquí lo que te falta ver.',
                        WatchlistTab.rewatch =>
                          'Marca tus favoritas como "Volver a ver" y organiza tu maratón.',
                        WatchlistTab.seen =>
                          'Cuando marques contenido como visto se acumulará aquí.',
                      },
                      actionLabel: _tab == WatchlistTab.pending
                          ? 'Agregar contenido'
                          : null,
                      onAction: _tab == WatchlistTab.pending
                          ? () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const ContentFormScreen(),
                                ),
                              )
                          : null,
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return StaggeredItem(
                          index: index,
                          child: LongPressDraggable<ContentItem>(
                            data: item,
                            dragAnchorStrategy: pointerDragAnchorStrategy,
                            feedback: _DragFeedback(item: item),
                            childWhenDragging: Opacity(
                              opacity: 0.35,
                              child: HorizontalContentCard(item: item),
                            ),
                            child: HorizontalContentCard(
                              item: item,
                              trailing:
                                  _QuickStatusButton(item: item, tab: _tab),
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      ContentDetailScreen(contentId: item.id),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  /// Mueve un contenido a la lista destino soltándolo sobre su pestaña.
  Future<void> _moveItem(WatchlistTab tab, ContentItem item) async {
    final actions = ref.read(contentActionsProvider);
    switch (tab) {
      case WatchlistTab.pending:
        await actions.markPending(item);
      case WatchlistTab.rewatch:
        await actions.save(item.copyWith(status: WatchStatus.rewatchPending));
      case WatchlistTab.seen:
        await actions.markCompleted(item);
    }
    if (!mounted) return;
    setState(() => _tab = tab);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('"${item.title}" movida a ${tab.label}')),
    );
  }
}

/// Botón "¿Qué veo hoy?" — abre la ruleta para elegir algo pendiente al azar.
class _RouletteButton extends StatelessWidget {
  final VoidCallback onTap;

  const _RouletteButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '¿Qué veo hoy?',
      child: Material(
        color: AppColors.primary.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.primary),
            ),
            child: const Icon(
              Icons.casino_rounded,
              size: 24,
              color: AppColors.primary,
            ),
          ),
        ),
      ),
    );
  }
}

/// Segmented control de 3 opciones que además actúa como zona de destino:
/// al soltar una tarjeta sobre una pestaña se mueve el contenido a esa lista.
class _SegmentedControl extends StatelessWidget {
  final WatchlistTab selected;
  final ValueChanged<WatchlistTab> onChanged;
  final void Function(WatchlistTab tab, ContentItem item) onItemDropped;

  const _SegmentedControl({
    required this.selected,
    required this.onChanged,
    required this.onItemDropped,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final tab in WatchlistTab.values)
            Expanded(
              child: DragTarget<ContentItem>(
                onWillAcceptWithDetails: (_) => true,
                onAcceptWithDetails: (details) =>
                    onItemDropped(tab, details.data),
                builder: (context, candidate, rejected) {
                  final isTarget = candidate.isNotEmpty;
                  final isSelected = selected == tab;
                  final accent =
                      isTarget ? AppColors.secondary : AppColors.primary;
                  return GestureDetector(
                    onTap: () => onChanged(tab),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOutCubic,
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      decoration: BoxDecoration(
                        color: (isSelected || isTarget)
                            ? accent
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: isTarget
                            ? Border.all(color: Colors.white, width: 1.5)
                            : null,
                        boxShadow: (isSelected || isTarget)
                            ? [
                                BoxShadow(
                                  color: accent.withValues(alpha: 0.35),
                                  blurRadius: 10,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        tab.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: (isSelected || isTarget)
                              ? Colors.white
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

/// Vista flotante que sigue al dedo mientras se arrastra una tarjeta.
class _DragFeedback extends StatelessWidget {
  final ContentItem item;

  const _DragFeedback({required this.item});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Opacity(
        opacity: 0.95,
        child: Container(
          width: 230,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.primary, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 40,
                  height: 60,
                  child: PosterImage(item: item),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Acción rápida contextual por pestaña (marcar visto / re-ver / pendiente).
class _QuickStatusButton extends ConsumerWidget {
  final ContentItem item;
  final WatchlistTab tab;

  const _QuickStatusButton({required this.item, required this.tab});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actions = ref.read(contentActionsProvider);

    final (icon, color, tooltip, onTap) = switch (tab) {
      WatchlistTab.pending => (
          Icons.check_circle_outline,
          AppColors.success,
          'Marcar como visto',
          () => actions.markCompleted(item),
        ),
      WatchlistTab.rewatch => (
          Icons.check_circle_outline,
          AppColors.success,
          'Ya la volví a ver',
          () => actions.markCompleted(item),
        ),
      WatchlistTab.seen => (
          Icons.replay,
          AppColors.tertiary,
          'Volver a ver',
          () =>
              actions.save(item.copyWith(status: WatchStatus.rewatchPending)),
        ),
    };

    return Material(
      color: color.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () async {
          await onTap();
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('$tooltip: "${item.title}"')),
            );
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          child: Icon(icon, size: 22, color: color),
        ),
      ),
    );
  }
}
