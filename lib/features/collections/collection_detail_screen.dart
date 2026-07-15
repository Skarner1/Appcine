import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/collection.dart';
import '../../data/models/content_item.dart';
import '../../providers/providers.dart';
import '../../shared/widgets/app_dialog.dart';
import '../../shared/widgets/content_card.dart';
import '../../shared/widgets/custom_bottom_sheet.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/poster_image.dart';
import '../../shared/widgets/staggered_item.dart';
import '../detail/content_detail_screen.dart';
import 'collections_provider.dart';
import 'collections_screen.dart';

/// Detalle de una colección: su contenido, con opciones para añadir/quitar
/// títulos, renombrar y eliminar la colección.
class CollectionDetailScreen extends ConsumerWidget {
  final String collectionId;

  const CollectionDetailScreen({super.key, required this.collectionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final collection = ref.watch(collectionsProvider).where(
          (c) => c.id == collectionId,
        );
    // Si la colección se borró (p. ej. desde otra ruta), cerramos.
    if (collection.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) Navigator.of(context).maybePop();
      });
      return Scaffold(backgroundColor: AppColors.background);
    }

    final current = collection.first;
    final items = ref.watch(collectionItemsProvider(collectionId));
    final columns = Responsive.gridColumns(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: current.accent,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(current.name, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Editar',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => _edit(context, ref, current),
          ),
          IconButton(
            tooltip: 'Eliminar',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _delete(context, ref, current),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addItems(context, ref, collectionId),
        backgroundColor: current.accent,
        icon: const Icon(Icons.playlist_add, color: Colors.white),
        label: Text(
          'Añadir',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
      body: items.isEmpty
          ? EmptyState(
              icon: Icons.movie_filter_outlined,
              title: 'Colección vacía',
              message:
                  'Añade títulos de tu catálogo para empezar a llenar "${current.name}".',
              actionLabel: 'Añadir contenido',
              onAction: () => _addItems(context, ref, collectionId),
            )
          : GridView.builder(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 2 / 3,
              ),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return StaggeredItem(
                  index: index,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: ContentCard(
                          item: item,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  ContentDetailScreen(contentId: item.id),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 6,
                        right: 6,
                        child: _RemoveButton(
                          onTap: () => ref
                              .read(collectionsProvider.notifier)
                              .removeItem(collectionId, item.id),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    Collection current,
  ) async {
    final draft = await showCollectionEditor(
      context: context,
      initialName: current.name,
      initialColor: current.color,
    );
    if (draft == null) return;
    final notifier = ref.read(collectionsProvider.notifier);
    await notifier.rename(current.id, draft.name);
    await notifier.setColor(current.id, draft.color);
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    Collection current,
  ) async {
    final confirmed = await showAppConfirmDialog(
      context: context,
      title: '¿Eliminar "${current.name}"?',
      message:
          'Se borrará la colección. Tus títulos seguirán en el catálogo, solo se elimina la agrupación.',
      confirmLabel: 'Eliminar',
      icon: Icons.delete_outline,
      accent: AppColors.error,
    );
    if (!confirmed) return;
    await ref.read(collectionsProvider.notifier).delete(current.id);
    if (context.mounted) Navigator.of(context).maybePop();
  }

  void _addItems(BuildContext context, WidgetRef ref, String collectionId) {
    showAppBottomSheet<void>(
      context: context,
      title: 'Añadir a la colección',
      initialSize: 0.75,
      builder: (context, controller) =>
          _AddItemsList(collectionId: collectionId, controller: controller),
    );
  }
}

/// Botón circular para quitar un título de la colección.
class _RemoveButton extends StatelessWidget {
  final VoidCallback onTap;

  const _RemoveButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.55),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: const Padding(
          padding: EdgeInsets.all(5),
          child: Icon(Icons.close, size: 16, color: Colors.white),
        ),
      ),
    );
  }
}

/// Lista seleccionable del catálogo para marcar qué títulos pertenecen a la
/// colección. Los cambios se guardan al instante.
class _AddItemsList extends ConsumerWidget {
  final String collectionId;
  final ScrollController controller;

  const _AddItemsList({required this.collectionId, required this.controller});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(contentListProvider).value ?? const <ContentItem>[];
    final collection = ref.watch(collectionsProvider).where(
          (c) => c.id == collectionId,
        );
    final selectedIds =
        collection.isEmpty ? const <String>{} : collection.first.itemIds.toSet();

    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Tu catálogo está vacío. Agrega contenido primero.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    return ListView.separated(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = items[index];
        final selected = selectedIds.contains(item.id);
        return _SelectableItem(
          item: item,
          selected: selected,
          onTap: () => ref
              .read(collectionsProvider.notifier)
              .toggleItem(collectionId, item.id),
        );
      },
    );
  }
}

class _SelectableItem extends StatelessWidget {
  final ContentItem item;
  final bool selected;
  final VoidCallback onTap;

  const _SelectableItem({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? AppColors.primary.withValues(alpha: 0.12)
          : AppColors.surfaceElevated,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
            ),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: PosterImage(item: item, width: 40, height: 56),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${item.type.emoji} ${item.type.label}',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.add_circle_outline_rounded,
                color: selected ? AppColors.primary : AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
