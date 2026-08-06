import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/l10n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/collection.dart';
import '../../data/models/content_item.dart';
import '../../shared/widgets/app_buttons.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/poster_image.dart';
import 'collection_detail_screen.dart';
import 'collections_provider.dart';

/// Pantalla de colecciones personalizadas: crea listas propias y agrúpalas.
class CollectionsScreen extends ConsumerWidget {
  const CollectionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final collections = ref.watch(collectionsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(tr('coll.title'))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _create(context, ref),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(
          tr('coll.new'),
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
      body: collections.isEmpty
          ? EmptyState(
              imageAsset: 'assets/img/section/collections.png',
              icon: Icons.collections_bookmark_outlined,
              title: tr('coll.empty.title'),
              message: tr('coll.empty.message'),
              actionLabel: tr('coll.empty.action'),
              onAction: () => _create(context, ref),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
              itemCount: collections.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final collection = collections[index];
                return _CollectionTile(
                  collection: collection,
                  items: ref.watch(collectionItemsProvider(collection.id)),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          CollectionDetailScreen(collectionId: collection.id),
                    ),
                  ),
                );
              },
            ),
    );
  }

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final created = await showCollectionEditor(context: context);
    if (created == null) return;
    await ref
        .read(collectionsProvider.notifier)
        .create(created.name, color: created.color);
  }
}

/// Fila de una colección con pila de pósters y conteo.
class _CollectionTile extends StatelessWidget {
  final Collection collection;
  final List<ContentItem> items;
  final VoidCallback onTap;

  const _CollectionTile({
    required this.collection,
    required this.items,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              _PosterStack(items: items, accent: collection.accent),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: collection.accent,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            collection.name,
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
                    const SizedBox(height: 4),
                    Text(
                      trn('count.titles', collection.itemIds.length),
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

/// Miniatura: hasta 3 pósters superpuestos (o placeholder si está vacía).
class _PosterStack extends StatelessWidget {
  final List<ContentItem> items;
  final Color accent;

  const _PosterStack({required this.items, required this.accent});

  @override
  Widget build(BuildContext context) {
    const height = 66.0;
    if (items.isEmpty) {
      return Container(
        width: 56,
        height: height,
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: accent.withValues(alpha: 0.4)),
        ),
        child: Icon(Icons.movie_outlined, color: accent, size: 24),
      );
    }

    final preview = items.take(3).toList();
    return SizedBox(
      width: 78,
      height: height,
      child: Stack(
        children: [
          for (var i = preview.length - 1; i >= 0; i--)
            Positioned(
              left: i * 11.0,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.surface, width: 2),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(7),
                  child: PosterImage(item: preview[i], width: 44, height: 62),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Datos devueltos por el editor de colección.
class CollectionDraft {
  final String name;
  final int color;
  const CollectionDraft(this.name, this.color);
}

/// Muestra un diálogo para crear o editar el nombre y color de una colección.
/// Devuelve el borrador o null si se cancela.
Future<CollectionDraft?> showCollectionEditor({
  required BuildContext context,
  String initialName = '',
  int? initialColor,
}) {
  return showDialog<CollectionDraft>(
    context: context,
    builder: (context) => _CollectionEditorDialog(
      initialName: initialName,
      initialColor: initialColor ?? Collection.palette.first.toARGB32(),
    ),
  );
}

class _CollectionEditorDialog extends StatefulWidget {
  final String initialName;
  final int initialColor;

  const _CollectionEditorDialog({
    required this.initialName,
    required this.initialColor,
  });

  @override
  State<_CollectionEditorDialog> createState() =>
      _CollectionEditorDialogState();
}

class _CollectionEditorDialogState extends State<_CollectionEditorDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialName);
  late int _color = widget.initialColor;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initialName.isNotEmpty;
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              tr(isEditing ? 'coll.editor.editTitle' : 'coll.editor.newTitle'),
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              autofocus: true,
              maxLines: 1,
              textCapitalization: TextCapitalization.sentences,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: tr('coll.editor.nameHint'),
              ),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 18),
            Text(
              tr('coll.editor.color'),
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final color in Collection.palette)
                  _ColorDot(
                    color: color,
                    selected: color.toARGB32() == _color,
                    onTap: () => setState(() => _color = color.toARGB32()),
                  ),
              ],
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: SecondaryButton(
                    label: tr('common.cancel'),
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: PrimaryButton(
                    label: tr(isEditing ? 'common.save' : 'coll.editor.create'),
                    onTap: _submit,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    Navigator.of(context).pop(CollectionDraft(name, _color));
  }
}

class _ColorDot extends StatelessWidget {
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _ColorDot({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? AppColors.textPrimary : Colors.transparent,
            width: 2.5,
          ),
        ),
        child: selected
            ? const Icon(Icons.check, color: Colors.white, size: 18)
            : null,
      ),
    );
  }
}
