import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/l10n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../data/services/poster_store.dart';
import 'app_buttons.dart';
import 'custom_bottom_sheet.dart';

/// Elige una imagen de la galería del dispositivo y la copia de forma
/// persistente al almacenamiento de la app. Devuelve la ruta local resultante
/// o null si el usuario cancela. Lanza en caso de error de E/S.
Future<String?> pickPosterFromGallery([PosterStore? store]) async {
  final picked = await ImagePicker().pickImage(
    source: ImageSource.gallery,
    maxWidth: 1200,
    imageQuality: 88,
  );
  if (picked == null) return null;

  return (store ?? PosterStore()).adopt(File(picked.path));
}

/// Pide una URL de imagen mediante un diálogo. Devuelve la URL (http/https)
/// o null si se cancela o no es válida.
Future<String?> askPosterUrl(BuildContext context, {String? current}) async {
  final controller = TextEditingController(
    text: (current?.startsWith('http') ?? false) ? current : '',
  );
  final result = await showDialog<String>(
    context: context,
    builder: (context) => Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              tr('poster.urlTitle'),
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              maxLines: 1,
              keyboardType: TextInputType.url,
              autofocus: true,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppColors.textPrimary,
              ),
              decoration: const InputDecoration(hintText: 'https://…'),
            ),
            const SizedBox(height: 20),
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
                    label: tr('poster.use'),
                    onTap: () =>
                        Navigator.of(context).pop(controller.text.trim()),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  if (result != null && result.startsWith('http')) return result;
  return null;
}

/// Muestra el menú de opciones de portada (galería / URL / quitar) y notifica
/// el nuevo valor por [onChanged]: una ruta/URL nueva, o null para quitarla.
/// Reutilizado por el formulario y por el menú de acciones rápidas.
///
/// Si se pasa [onSearchOnline] se añade la opción "Buscar en internet". Va por
/// callback y no por [onChanged] porque el buscador devuelve además título,
/// géneros y fecha: quién sabe qué hacer con eso es quien abre el menú, no este
/// widget.
Future<void> showPosterOptions(
  BuildContext context, {
  required bool hasPoster,
  String? currentUrl,
  required ValueChanged<String?> onChanged,
  VoidCallback? onSearchOnline,
}) {
  return showAppBottomSheet<void>(
    context: context,
    title: tr('poster.sheetTitle'),
    builder: (sheetContext, controller) {
      final messenger = ScaffoldMessenger.of(context);
      return ListView(
        controller: controller,
        padding: const EdgeInsets.all(20),
        children: [
          if (onSearchOnline != null) ...[
            _PosterOption(
              icon: Icons.travel_explore_rounded,
              label: tr('catalog.searchOnline'),
              color: AppColors.primary,
              onTap: () {
                Navigator.of(sheetContext).pop();
                onSearchOnline();
              },
            ),
            const SizedBox(height: 12),
          ],
          _PosterOption(
            icon: Icons.photo_library_outlined,
            label: tr('poster.fromGallery'),
            onTap: () async {
              Navigator.of(sheetContext).pop();
              try {
                final path = await pickPosterFromGallery();
                if (path != null) onChanged(path);
              } catch (_) {
                messenger.showSnackBar(
                  SnackBar(content: Text(tr('poster.loadFailed'))),
                );
              }
            },
          ),
          const SizedBox(height: 12),
          _PosterOption(
            icon: Icons.link,
            label: tr('poster.useUrl'),
            onTap: () async {
              Navigator.of(sheetContext).pop();
              if (!context.mounted) return;
              final url = await askPosterUrl(context, current: currentUrl);
              if (url == null) return;
              // Se baja al disco para que la portada no dependa de que la URL
              // siga viva. Si falla se guarda la URL y ya se repescará.
              final local = await PosterStore().download(url);
              onChanged(local ?? url);
            },
          ),
          if (hasPoster) ...[
            const SizedBox(height: 12),
            _PosterOption(
              icon: Icons.delete_outline,
              label: tr('poster.remove'),
              color: AppColors.error,
              onTap: () {
                Navigator.of(sheetContext).pop();
                onChanged(null);
              },
            ),
          ],
        ],
      );
    },
  );
}

class _PosterOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  const _PosterOption({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = color ?? AppColors.textPrimary;
    return Material(
      color: AppColors.surfaceElevated,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Icon(icon, color: iconColor, size: 22),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: iconColor,
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
