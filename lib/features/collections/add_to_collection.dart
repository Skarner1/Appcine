import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/l10n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/custom_bottom_sheet.dart';
import 'collections_provider.dart';
import 'collections_screen.dart';

/// Abre un panel para marcar en qué colecciones está un título, con opción de
/// crear una nueva sobre la marcha.
Future<void> showItemCollectionsSheet({
  required BuildContext context,
  required String itemId,
}) {
  return showAppBottomSheet<void>(
    context: context,
    title: tr('coll.save.title'),
    builder: (context, controller) =>
        _ItemCollectionsList(itemId: itemId, controller: controller),
  );
}

class _ItemCollectionsList extends ConsumerWidget {
  final String itemId;
  final ScrollController controller;

  const _ItemCollectionsList({required this.itemId, required this.controller});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final collections = ref.watch(collectionsProvider);

    return ListView(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        _CreateTile(
          onTap: () async {
            final draft = await showCollectionEditor(context: context);
            if (draft == null) return;
            final notifier = ref.read(collectionsProvider.notifier);
            final id = await notifier.create(draft.name, color: draft.color);
            await notifier.toggleItem(id, itemId);
          },
        ),
        const SizedBox(height: 8),
        for (final collection in collections)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _CollectionCheck(
              name: collection.name,
              accent: collection.accent,
              count: collection.itemIds.length,
              selected: collection.contains(itemId),
              onTap: () => ref
                  .read(collectionsProvider.notifier)
                  .toggleItem(collection.id, itemId),
            ),
          ),
        if (collections.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              tr('coll.save.empty'),
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ),
      ],
    );
  }
}

class _CreateTile extends StatelessWidget {
  final VoidCallback onTap;

  const _CreateTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primary.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.primary),
          ),
          child: Row(
            children: [
              const Icon(Icons.add, color: AppColors.primary),
              const SizedBox(width: 12),
              Text(
                tr('coll.save.createNew'),
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CollectionCheck extends StatelessWidget {
  final String name;
  final Color accent;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  const _CollectionCheck({
    required this.name,
    required this.accent,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? accent.withValues(alpha: 0.12)
          : AppColors.surfaceElevated,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? accent : AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      trn('count.titles', count),
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
                    : Icons.radio_button_unchecked,
                color: selected ? accent : AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
