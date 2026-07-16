import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/l10n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/content_item.dart';
import '../../features/content_form/content_form_screen.dart';
import '../../providers/providers.dart';
import 'app_dialog.dart';
import 'poster_image.dart';
import 'poster_picker.dart';

/// Menú contextual de acciones rápidas para un contenido, pensado para
/// abrirse al mantener pulsada una tarjeta del catálogo o de "Por Ver".
/// Ofrece editar (abre el formulario) o eliminar (con confirmación).
Future<void> showContentActionsSheet(
  BuildContext context,
  WidgetRef ref,
  ContentItem item,
) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => _ContentActionsSheet(item: item, hostContext: context),
  );
}

class _ContentActionsSheet extends ConsumerWidget {
  final ContentItem item;

  /// Contexto de la pantalla que abrió el menú; sigue montado tras cerrarlo,
  /// necesario para abrir el selector de portada después de hacer pop.
  final BuildContext hostContext;

  const _ContentActionsSheet({required this.item, required this.hostContext});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 32,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textMuted,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _header(),
            const Divider(height: 24),
            _ActionTile(
              icon: item.isFavorite
                  ? Icons.favorite_rounded
                  : Icons.favorite_outline_rounded,
              label: item.isFavorite
                  ? tr('actions.favRemove')
                  : tr('actions.favAdd'),
              color: AppColors.primary,
              onTap: () {
                final actions = ref.read(contentActionsProvider);
                Navigator.of(context).pop();
                actions.toggleFavorite(item);
              },
            ),
            _ActionTile(
              icon: Icons.image_outlined,
              label: item.posterUrl == null
                  ? tr('actions.imageAdd')
                  : tr('actions.imageChange'),
              color: AppColors.tertiary,
              onTap: () {
                final actions = ref.read(contentActionsProvider);
                final messenger = ScaffoldMessenger.of(hostContext);
                Navigator.of(context).pop();
                showPosterOptions(
                  hostContext,
                  hasPoster: item.posterUrl != null,
                  currentUrl: item.posterUrl,
                  onChanged: (value) async {
                    await actions.save(
                      item.copyWith(
                        posterUrl: value,
                        clearPosterUrl: value == null,
                      ),
                    );
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(
                          value == null
                              ? tr('actions.posterRemoved')
                              : tr('actions.posterUpdated'),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
            _ActionTile(
              icon: Icons.edit_outlined,
              label: tr('common.edit'),
              color: AppColors.secondary,
              onTap: () {
                final navigator = Navigator.of(context);
                navigator.pop();
                navigator.push(
                  MaterialPageRoute(
                    builder: (_) => ContentFormScreen(original: item),
                  ),
                );
              },
            ),
            _ActionTile(
              icon: Icons.delete_outline,
              label: tr('common.delete'),
              color: AppColors.error,
              onTap: () => _confirmDelete(context, ref),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 44,
              height: 66,
              child: PosterImage(item: item),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${item.type.emoji} ${item.type.label}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final actions = ref.read(contentActionsProvider);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final confirmed = await showAppConfirmDialog(
      context: context,
      title: tr('actions.deleteConfirmTitle', {'title': item.title}),
      message: tr('actions.deleteConfirmMsg'),
      confirmLabel: tr('common.delete'),
      icon: Icons.delete_outline,
      accent: AppColors.error,
    );
    if (!confirmed) return;

    navigator.pop(); // Cierra el menú de acciones.
    await actions.delete(item);
    messenger.showSnackBar(
      SnackBar(content: Text(tr('actions.deleted', {'title': item.title}))),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
