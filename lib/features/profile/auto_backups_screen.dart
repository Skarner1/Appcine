import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/services/auto_backup_service.dart';
import '../../providers/providers.dart';
import '../../shared/widgets/app_dialog.dart';
import '../../shared/widgets/empty_state.dart';

/// Copias que la app se ha guardado sola, con opción de volver a cualquiera.
class AutoBackupsScreen extends ConsumerStatefulWidget {
  const AutoBackupsScreen({super.key});

  @override
  ConsumerState<AutoBackupsScreen> createState() => _AutoBackupsScreenState();
}

class _AutoBackupsScreenState extends ConsumerState<AutoBackupsScreen> {
  late Future<List<AutoBackup>> _backups;

  @override
  void initState() {
    super.initState();
    _backups = ref.read(autoBackupServiceProvider).list();
  }

  void _reload() {
    setState(() {
      _backups = ref.read(autoBackupServiceProvider).list();
    });
  }

  Future<void> _backupNow() async {
    final messenger = ScaffoldMessenger.of(context);
    final items = ref.read(contentRepositoryProvider).getAll();

    if (items.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('No hay nada que copiar todavía.')),
      );
      return;
    }

    final now = DateTime.now();
    final path = await ref.read(autoBackupServiceProvider).run(items, now: now);
    if (path == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('No se pudo crear la copia.')),
      );
      return;
    }

    await ref.read(autoBackupLastRunProvider.notifier).markRun(now);
    messenger.showSnackBar(
      SnackBar(content: Text('Copia creada con ${items.length} títulos')),
    );
    _reload();
  }

  Future<void> _restore(AutoBackup backup) async {
    final messenger = ScaffoldMessenger.of(context);
    final service = ref.read(autoBackupServiceProvider);

    final items = await () async {
      try {
        return await service.read(backup.path);
      } on FormatException catch (e) {
        messenger.showSnackBar(SnackBar(content: Text(e.message)));
        return null;
      } catch (_) {
        messenger.showSnackBar(
          const SnackBar(content: Text('No se pudo leer la copia.')),
        );
        return null;
      }
    }();
    if (items == null || !mounted) return;

    if (items.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Esa copia está vacía.')),
      );
      return;
    }

    final confirmed = await showAppConfirmDialog(
      context: context,
      title: 'Restaurar ${items.length} títulos',
      message:
          'Se añadirán a tu catálogo actual (los que tengan el mismo id se sobrescriben). ¿Continuar?',
      confirmLabel: 'Restaurar',
      icon: Icons.restore_outlined,
      accent: AppColors.secondary,
    );
    if (!confirmed) return;

    await ref.read(contentRepositoryProvider).saveAll(items);
    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(content: Text('${items.length} títulos restaurados')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Copias automáticas'),
        actions: [
          IconButton(
            onPressed: _backupNow,
            icon: const Icon(Icons.add),
            tooltip: 'Copiar ahora',
          ),
        ],
      ),
      body: FutureBuilder<List<AutoBackup>>(
        future: _backups,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          final backups = snapshot.data ?? const <AutoBackup>[];
          if (backups.isEmpty) {
            return const EmptyState(
              icon: Icons.history_toggle_off,
              title: 'Todavía no hay copias',
              message:
                  'La app guarda una sola, cada cierto tiempo, mientras tengas '
                  'contenido. También puedes crear una ahora con el +.',
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: backups.length + 1,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              if (index == backups.length) return const _Caveat();
              return _BackupTile(
                backup: backups[index],
                isLatest: index == 0,
                onRestore: () => _restore(backups[index]),
              );
            },
          );
        },
      ),
    );
  }
}

class _BackupTile extends StatelessWidget {
  final AutoBackup backup;
  final bool isLatest;
  final VoidCallback onRestore;

  const _BackupTile({
    required this.backup,
    required this.isLatest,
    required this.onRestore,
  });

  @override
  Widget build(BuildContext context) {
    final kb = (backup.sizeBytes / 1024).ceil();

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onRestore,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isLatest ? AppColors.secondary : AppColors.border,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.save_outlined,
                size: 22,
                color: isLatest ? AppColors.secondary : AppColors.textSecondary,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formatDateTime(backup.date),
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
                      '${formatRelative(backup.date)} · $kb KB'
                      '${isLatest ? ' · la más reciente' : ''}',
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
              Icon(Icons.restore, size: 20, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

/// Lo que estas copias NO hacen. Mejor decirlo que dar una falsa sensación de
/// seguridad.
class _Caveat extends StatelessWidget {
  const _Caveat();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 16, color: AppColors.textMuted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Estas copias viven dentro de la app: te salvan de un borrado sin '
              'querer o de un import que salga mal, pero se van si desinstalas '
              'CineLog. Para eso usa "Crear copia de seguridad" y guárdala fuera.',
              style: GoogleFonts.inter(
                fontSize: 12,
                height: 1.5,
                color: AppColors.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
