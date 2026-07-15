import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/services/notification_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/content_item.dart';
import '../../data/services/auto_backup_service.dart';
import '../../data/services/backup_service.dart';
import '../../providers/providers.dart';
import '../../shared/widgets/app_buttons.dart';
import '../../shared/widgets/app_dialog.dart';
import '../reminders/stalled_reminders.dart';
import '../stats/watch_stats_screen.dart';
import 'auto_backups_screen.dart';
import 'catalog_qr_screen.dart';
import 'catalog_share.dart';
import 'notifications_screen.dart';

/// Tab 4 — Perfil: estadísticas, notificaciones programadas y configuración.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(profileStatsProvider);
    final name = ref.watch(profileNameProvider);
    final scheduled = ref.watch(scheduledNotificationsProvider);

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
        children: [
          // Header de perfil.
          Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.primarySoft],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.35),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Text(
                  name.isEmpty ? 'C' : name[0].toUpperCase(),
                  style: GoogleFonts.poppins(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      '${stats.totalItems} títulos en tu catálogo',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Editar nombre',
                onPressed: () => _editName(context, ref, name),
                icon: Icon(
                  Icons.edit_outlined,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Tarjetas resumen.
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.check_circle_outline,
                  color: AppColors.success,
                  value: '${stats.completedCount}',
                  label: 'Vistos',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  icon: Icons.schedule,
                  color: AppColors.warning,
                  value: '${stats.pendingCount}',
                  label: 'Pendientes',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.timer_outlined,
                  color: AppColors.secondary,
                  value: formatLongDuration(stats.totalWatchedMinutes),
                  label: 'Tiempo visto',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const WatchStatsScreen(),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  icon: Icons.local_fire_department_outlined,
                  color: AppColors.primary,
                  value:
                      '${stats.streakDays} ${stats.streakDays == 1 ? 'día' : 'días'}',
                  label: 'Racha',
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Gráfico: distribución por tipo (donut).
          if (stats.totalItems > 0) ...[
            _SectionCard(
              title: 'Tu catálogo por tipo',
              child: _TypeDonutChart(byType: stats.byType),
            ),
            const SizedBox(height: 16),
          ],
          // Gráfico: top géneros (barras).
          if (stats.topGenres.isNotEmpty) ...[
            _SectionCard(
              title: 'Géneros más frecuentes',
              child: _GenresBarChart(topGenres: stats.topGenres),
            ),
            const SizedBox(height: 24),
          ],
          // Notificaciones programadas (resumen).
          _SectionCard(
            title: 'Notificaciones',
            trailing: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const NotificationsScreen(),
                ),
              ),
              child: Text(
                'Ver todas',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.secondary,
                ),
              ),
            ),
            child: scheduled.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Icon(
                          Icons.notifications_off_outlined,
                          color: AppColors.textMuted,
                          size: 22,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'No tienes recordatorios programados.',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : Column(
                    children: [
                      for (final item in scheduled.take(3))
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              Text(
                                item.type.emoji,
                                style: const TextStyle(fontSize: 18),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  item.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                formatDateTime(item.notificationDate!),
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.tertiary,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
          ),
          const SizedBox(height: 24),
          // Configuración.
          Text(
            'Configuración',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          _SettingsTile(
            icon: Icons.notification_add_outlined,
            title: 'Probar notificaciones',
            subtitle: 'Envía una notificación de prueba',
            onTap: () async {
              final granted =
                  await NotificationService.instance.requestPermissions();
              await NotificationService.instance.showTestNotification();
              if (context.mounted && !granted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Activa los permisos de notificación del sistema para recibir recordatorios.',
                    ),
                  ),
                );
              }
            },
          ),
          _SettingsTile(
            icon: Icons.backup_outlined,
            title: 'Crear copia de seguridad',
            subtitle: 'Guarda tu catálogo en un archivo .json',
            onTap: () => _export(context, ref),
          ),
          _SettingsTile(
            icon: Icons.restore_outlined,
            title: 'Restaurar copia',
            subtitle: 'Importa un archivo .json de backup',
            onTap: () => _restore(context, ref),
          ),
          _SettingsTile(
            icon: Icons.ios_share_outlined,
            title: 'Compartir catálogo',
            subtitle: 'Envía tu colección a otras personas (.json o texto)',
            onTap: () => _share(context, ref),
          ),
          _SettingsTile(
            icon: Icons.download_outlined,
            title: 'Importar catálogo',
            subtitle: 'Añade un catálogo que te compartieron',
            onTap: () => _import(context, ref),
          ),
          _SettingsTile(
            icon: Icons.qr_code_scanner,
            title: 'Escanear QR',
            subtitle: 'Lee el catálogo de otro móvil, sin internet',
            onTap: () => _scanQr(context, ref),
          ),
          const _ThemeSelector(),
          const _StalledReminderSelector(),
          const _AutoBackupSelector(),
          _SettingsTile(
            icon: Icons.delete_sweep_outlined,
            title: 'Vaciar catálogo',
            subtitle: 'Elimina todo el contenido guardado',
            color: AppColors.error,
            onTap: () => _clearAll(context, ref),
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              'CineLog Pro v1.0 · Hecho con ❤️ y 🍿',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppColors.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editName(
    BuildContext context,
    WidgetRef ref,
    String current,
  ) async {
    final controller = TextEditingController(text: current);
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
                'Tu nombre',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                maxLines: 1,
                textCapitalization: TextCapitalization.words,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppColors.textPrimary,
                ),
                decoration: const InputDecoration(hintText: 'Ej. Iván'),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: SecondaryButton(
                      label: 'Cancelar',
                      onTap: () => Navigator.of(context).pop(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: PrimaryButton(
                      label: 'Guardar',
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
    if (result != null && result.isNotEmpty) {
      await ref.read(profileNameProvider.notifier).setName(result);
    }
  }

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    final items = ref.read(contentRepositoryProvider).getAll();
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay nada que respaldar todavía.')),
      );
      return;
    }
    try {
      await ref.read(backupServiceProvider).exportAndShare(items);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo crear la copia de seguridad.'),
          ),
        );
      }
    }
  }

  Future<void> _restore(BuildContext context, WidgetRef ref) async {
    final BackupImport? backup;
    try {
      backup = await ref.read(backupServiceProvider).pickAndDecode();
    } on FormatException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
      return;
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo leer el archivo.')),
        );
      }
      return;
    }

    if (backup == null) return; // El usuario canceló la selección.
    if (backup.items.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('El backup no contiene títulos.')),
        );
      }
      return;
    }

    if (!context.mounted) return;
    final confirmed = await showAppConfirmDialog(
      context: context,
      title: 'Restaurar ${backup.items.length} títulos',
      message:
          'Se añadirán a tu catálogo actual (los que tengan el mismo id se sobrescriben). ¿Continuar?',
      confirmLabel: 'Restaurar',
      icon: Icons.restore_outlined,
      accent: AppColors.secondary,
    );
    if (!confirmed) return;

    await ref.read(contentRepositoryProvider).saveAll(backup.items);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${backup.items.length} títulos restaurados')),
      );
    }
  }

  Future<void> _share(BuildContext context, WidgetRef ref) async {
    final items = ref.read(contentRepositoryProvider).getAll();
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tu catálogo está vacío: agrega títulos primero.'),
        ),
      );
      return;
    }
    final name = ref.read(profileNameProvider);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _ShareOptionsSheet(
        count: items.length,
        onText: () {
          Navigator.of(sheetContext).pop();
          shareCatalogAsText(name, items);
        },
        onImage: () {
          Navigator.of(sheetContext).pop();
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => CatalogImagePreviewScreen(
                userName: name,
                items: items,
              ),
            ),
          );
        },
        onQr: () {
          Navigator.of(sheetContext).pop();
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const CatalogQrScreen()),
          );
        },
      ),
    );
  }

  Future<void> _scanQr(BuildContext context, WidgetRef ref) async {
    final imported = await Navigator.of(context).push<int>(
      MaterialPageRoute(builder: (_) => const ScanCatalogQrScreen()),
    );
    if (imported == null || !context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$imported títulos importados')),
    );
  }

  Future<void> _import(BuildContext context, WidgetRef ref) async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text == null || text.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Copia primero el catálogo que te compartieron y vuelve a intentarlo.',
            ),
          ),
        );
      }
      return;
    }

    List<ContentItem> items;
    try {
      items = parseSharedCatalog(text);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('El portapapeles no contiene un catálogo válido.'),
          ),
        );
      }
      return;
    }

    if (items.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('El catálogo compartido está vacío.')),
        );
      }
      return;
    }

    if (!context.mounted) return;
    final confirmed = await showAppConfirmDialog(
      context: context,
      title: 'Importar ${items.length} títulos',
      message:
          'Se agregarán a tu catálogo actual (los que tengan el mismo id se sobrescriben). ¿Continuar?',
      confirmLabel: 'Importar',
      icon: Icons.download_outlined,
      accent: AppColors.secondary,
    );
    if (!confirmed) return;

    await ref.read(contentRepositoryProvider).saveAll(items);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${items.length} títulos importados')),
      );
    }
  }

  Future<void> _clearAll(BuildContext context, WidgetRef ref) async {
    final confirmed = await showAppConfirmDialog(
      context: context,
      title: '¿Vaciar todo el catálogo?',
      message:
          'Se eliminará todo tu contenido y recordatorios. Exporta antes si quieres conservar una copia.',
      confirmLabel: 'Vaciar todo',
      icon: Icons.delete_sweep_outlined,
      accent: AppColors.error,
    );
    if (!confirmed) return;

    final repo = ref.read(contentRepositoryProvider);
    for (final item in repo.getAll()) {
      await NotificationService.instance.cancelForContent(item.id);
    }
    await repo.clear();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Catálogo vaciado')),
      );
    }
  }
}

/// Menú compacto para elegir cómo compartir el catálogo: texto o imagen.
class _ShareOptionsSheet extends StatelessWidget {
  final int count;
  final VoidCallback onText;
  final VoidCallback onImage;
  final VoidCallback onQr;

  const _ShareOptionsSheet({
    required this.count,
    required this.onText,
    required this.onImage,
    required this.onQr,
  });

  @override
  Widget build(BuildContext context) {
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Compartir $count títulos',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const Divider(height: 24),
            _ShareOptionTile(
              icon: Icons.notes_outlined,
              color: AppColors.secondary,
              title: 'Como texto (bloc de notas)',
              subtitle: 'Lista legible para cualquier chat',
              onTap: onText,
            ),
            _ShareOptionTile(
              icon: Icons.image_outlined,
              color: AppColors.tertiary,
              title: 'Como imagen',
              subtitle: 'Una tarjeta .png con tus pósters',
              onTap: onImage,
            ),
            _ShareOptionTile(
              icon: Icons.qr_code_2,
              color: AppColors.primary,
              title: 'Como código QR',
              subtitle: 'Que lo escaneen del móvil, sin internet',
              onTap: onQr,
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

class _ShareOptionTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ShareOptionTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
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
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String value;
  final String label;
  final VoidCallback? onTap;

  const _StatCard({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const Spacer(),
              if (onTap != null)
                Icon(
                  Icons.arrow_outward_rounded,
                  size: 18,
                  color: AppColors.textMuted,
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: content,
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;

  const _SectionCard({required this.title, required this.child, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

/// Donut de distribución por tipo de contenido.
class _TypeDonutChart extends StatelessWidget {
  final Map<ContentType, int> byType;

  const _TypeDonutChart({required this.byType});

  static const Map<ContentType, Color> _colors = {
    ContentType.movie: AppColors.primary,
    ContentType.series: AppColors.secondary,
    ContentType.documentary: AppColors.success,
    ContentType.anime: AppColors.tertiary,
    ContentType.shortFilm: AppColors.info,
  };

  @override
  Widget build(BuildContext context) {
    final total = byType.values.fold<int>(0, (a, b) => a + b);
    final entries = byType.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Row(
      children: [
        SizedBox(
          width: 130,
          height: 130,
          child: PieChart(
            PieChartData(
              sectionsSpace: 3,
              centerSpaceRadius: 34,
              startDegreeOffset: -90,
              sections: [
                for (final entry in entries)
                  PieChartSectionData(
                    value: entry.value.toDouble(),
                    color: _colors[entry.key],
                    radius: 26,
                    showTitle: false,
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final entry in entries)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: _colors[entry.key],
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          entry.key.pluralLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      Text(
                        total == 0
                            ? '0%'
                            : '${(entry.value * 100 / total).round()}%',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Barras horizontales-verticales con los géneros más frecuentes.
class _GenresBarChart extends StatelessWidget {
  final List<MapEntry<String, int>> topGenres;

  const _GenresBarChart({required this.topGenres});

  @override
  Widget build(BuildContext context) {
    final maxValue = topGenres.isEmpty
        ? 1.0
        : topGenres.first.value.toDouble();

    return SizedBox(
      height: 180,
      child: BarChart(
        BarChartData(
          maxY: maxValue * 1.2,
          alignment: BarChartAlignment.spaceAround,
          barTouchData: BarTouchData(enabled: false),
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 34,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= topGenres.length) {
                    return const SizedBox.shrink();
                  }
                  final label = topGenres[index].key;
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      label.length > 8 ? '${label.substring(0, 7)}…' : label,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          barGroups: [
            for (var i = 0; i < topGenres.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: topGenres[i].value.toDouble(),
                    width: 22,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(6),
                    ),
                    gradient: const LinearGradient(
                      colors: [AppColors.primarySoft, AppColors.primary],
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// Selector de tema: Sistema / Claro / Oscuro. Persiste vía [themeModeProvider].
class _ThemeSelector extends ConsumerWidget {
  const _ThemeSelector();

  static const List<({ThemeMode mode, IconData icon, String label})> _options = [
    (
      mode: ThemeMode.system,
      icon: Icons.brightness_auto_outlined,
      label: 'Sistema',
    ),
    (mode: ThemeMode.light, icon: Icons.light_mode_outlined, label: 'Claro'),
    (mode: ThemeMode.dark, icon: Icons.dark_mode_outlined, label: 'Oscuro'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.dark_mode_outlined,
                  size: 22,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tema',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Claro, oscuro o según el sistema',
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
            const SizedBox(height: 14),
            Row(
              children: [
                for (var i = 0; i < _options.length; i++) ...[
                  if (i > 0) const SizedBox(width: 10),
                  Expanded(
                    child: _ThemeOptionButton(
                      icon: _options[i].icon,
                      label: _options[i].label,
                      selected: mode == _options[i].mode,
                      onTap: () => ref
                          .read(themeModeProvider.notifier)
                          .setMode(_options[i].mode),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Ajuste del aviso de títulos a medias: activarlo y decidir cuánta paciencia
/// tiene la app antes de decir algo.
class _StalledReminderSelector extends ConsumerWidget {
  const _StalledReminderSelector();

  static String _label(int days) => switch (days) {
        7 => '1 semana',
        14 => '2 semanas',
        _ => '1 mes',
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(stalledReminderEnabledProvider);
    final days = ref.watch(stalledReminderDaysProvider);
    final stalled = ref.watch(stalledItemsProvider);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.bookmark_added_outlined,
                  size: 22,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Avisarme de lo que dejo a medias',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        enabled && stalled.isNotEmpty
                            ? '${stalled.length} ${stalled.length == 1 ? 'título parado' : 'títulos parados'} ahora mismo'
                            : 'Un recordatorio si no retomas algo que empezaste',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: enabled,
                  activeThumbColor: AppColors.primary,
                  onChanged: (value) async {
                    await ref
                        .read(stalledReminderEnabledProvider.notifier)
                        .setEnabled(value);
                    if (value) await NotificationService.instance.requestPermissions();
                    await syncStalledReminder(ref);
                  },
                ),
              ],
            ),
            if (enabled) ...[
              const SizedBox(height: 14),
              Text(
                'Tras cuánto tiempo sin tocarlo',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  for (var i = 0;
                      i < StalledReminderDaysNotifier.options.length;
                      i++) ...[
                    if (i > 0) const SizedBox(width: 10),
                    Expanded(
                      child: _ThemeOptionButton(
                        icon: Icons.schedule,
                        label: _label(StalledReminderDaysNotifier.options[i]),
                        selected: days == StalledReminderDaysNotifier.options[i],
                        onTap: () async {
                          await ref
                              .read(stalledReminderDaysProvider.notifier)
                              .setDays(StalledReminderDaysNotifier.options[i]);
                          await syncStalledReminder(ref);
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Ajuste de las copias automáticas: activarlas, cada cuánto, y entrar a verlas.
class _AutoBackupSelector extends ConsumerWidget {
  const _AutoBackupSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(autoBackupEnabledProvider);
    final frequency = ref.watch(autoBackupFrequencyProvider);
    final lastRun = ref.watch(autoBackupLastRunProvider);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.save_outlined,
                  size: 22,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Copias automáticas',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        enabled && lastRun != null
                            ? 'Última: ${formatRelative(lastRun)}'
                            : 'Guarda ${AutoBackupService.keepCount} copias dentro del móvil',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: enabled,
                  activeThumbColor: AppColors.primary,
                  onChanged: (value) => ref
                      .read(autoBackupEnabledProvider.notifier)
                      .setEnabled(value),
                ),
              ],
            ),
            if (enabled) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  for (var i = 0; i < BackupFrequency.values.length; i++) ...[
                    if (i > 0) const SizedBox(width: 10),
                    Expanded(
                      child: _ThemeOptionButton(
                        icon: Icons.schedule,
                        label: BackupFrequency.values[i].label,
                        selected: frequency == BackupFrequency.values[i],
                        onTap: () => ref
                            .read(autoBackupFrequencyProvider.notifier)
                            .setFrequency(BackupFrequency.values[i]),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const AutoBackupsScreen(),
                    ),
                  ),
                  icon: const Icon(Icons.history, size: 18),
                  label: const Text('Ver copias y restaurar'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.secondary,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ThemeOptionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeOptionButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = selected ? AppColors.primary : AppColors.textSecondary;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.12)
              : AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: accent),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: accent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Color? color;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final effective = color ?? AppColors.textPrimary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 22,
                  color: color ?? AppColors.textSecondary,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: effective,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
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
                if (onTap != null)
                  Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: AppColors.textMuted,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
