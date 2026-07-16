import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/l10n/strings.dart';
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
        SnackBar(content: Text(tr('autobackup.nothingToCopy'))),
      );
      return;
    }

    final now = DateTime.now();
    final path = await ref.read(autoBackupServiceProvider).run(items, now: now);
    if (path == null) {
      messenger.showSnackBar(
        SnackBar(content: Text(tr('autobackup.createFailed'))),
      );
      return;
    }

    await ref.read(autoBackupLastRunProvider.notifier).markRun(now);
    messenger.showSnackBar(
      SnackBar(
        content: Text(tr('autobackup.created',
            {'count': trn('count.titles', items.length)})),
      ),
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
          SnackBar(content: Text(tr('autobackup.readFailed'))),
        );
        return null;
      }
    }();
    if (items == null || !mounted) return;

    if (items.isEmpty) {
      messenger.showSnackBar(
        SnackBar(content: Text(tr('autobackup.emptyBackup'))),
      );
      return;
    }

    final confirmed = await showAppConfirmDialog(
      context: context,
      title: tr('autobackup.restore.title',
          {'count': trn('count.titles', items.length)}),
      message: tr('profile.mergeConfirmMsg'),
      confirmLabel: tr('profile.restore.confirmLabel'),
      icon: Icons.restore_outlined,
      accent: AppColors.secondary,
    );
    if (!confirmed) return;

    await ref.read(contentRepositoryProvider).saveAll(items);
    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(content: Text(trn('profile.restored', items.length))),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('autobackup.screenTitle')),
        actions: [
          IconButton(
            onPressed: _backupNow,
            icon: const Icon(Icons.add),
            tooltip: tr('autobackup.backupNow'),
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
            return EmptyState(
              icon: Icons.history_toggle_off,
              title: tr('autobackup.noneTitle'),
              message: tr('autobackup.noneMessage'),
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
                      '${isLatest ? ' · ${tr('autobackup.latest')}' : ''}',
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
              tr('autobackup.caveat'),
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
