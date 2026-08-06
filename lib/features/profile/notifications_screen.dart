import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/l10n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/content_item.dart';
import '../../providers/providers.dart';
import '../../shared/widgets/empty_state.dart';
import '../detail/content_detail_screen.dart';

/// Pantalla de notificaciones (spec 7.3), agrupadas por horizonte temporal.
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheduled = ref.watch(scheduledNotificationsProvider);
    final allItems =
        ref.watch(contentListProvider).value ?? const <ContentItem>[];

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final in7 = today.add(const Duration(days: 7));
    final in30 = today.add(const Duration(days: 30));

    final todayItems = <ContentItem>[];
    final weekItems = <ContentItem>[];
    final monthItems = <ContentItem>[];
    final laterItems = <ContentItem>[];

    for (final item in scheduled) {
      final date = item.notificationDate!;
      final day = DateTime(date.year, date.month, date.day);
      if (day == today) {
        todayItems.add(item);
      } else if (day.isBefore(in7)) {
        weekItems.add(item);
      } else if (day.isBefore(in30)) {
        monthItems.add(item);
      } else {
        laterItems.add(item);
      }
    }

    // Pasadas: últimos visionados completados.
    final past = allItems
        .where((i) => i.status == WatchStatus.completed && i.watchDate != null)
        .toList()
      ..sort((a, b) => b.watchDate!.compareTo(a.watchDate!));

    final isEmpty = scheduled.isEmpty && past.isEmpty;

    return Scaffold(
      appBar: AppBar(title: Text(tr('notif.screenTitle'))),
      body: SafeArea(
        child: isEmpty
            ? EmptyState(
                imageAsset: 'assets/img/section/reminders.png',
                icon: Icons.notifications_none_rounded,
                title: tr('notif.empty.title'),
                message: tr('notif.empty.message'),
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                children: [
                  if (todayItems.isNotEmpty) ...[
                    _GroupHeader(label: tr('notif.group.today')),
                    for (final item in todayItems)
                      _NotificationCard(item: item, highlight: true),
                  ],
                  if (weekItems.isNotEmpty) ...[
                    _GroupHeader(label: tr('notif.group.next7')),
                    for (final item in weekItems)
                      _NotificationCard(item: item),
                  ],
                  if (monthItems.isNotEmpty) ...[
                    _GroupHeader(label: tr('notif.group.next30')),
                    for (final item in monthItems)
                      _NotificationCard(item: item),
                  ],
                  if (laterItems.isNotEmpty) ...[
                    _GroupHeader(label: tr('notif.group.later')),
                    for (final item in laterItems)
                      _NotificationCard(item: item),
                  ],
                  if (past.isNotEmpty) ...[
                    _GroupHeader(label: tr('notif.group.past')),
                    for (final item in past.take(10)) _PastTile(item: item),
                  ],
                ],
              ),
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  final String label;

  const _GroupHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 10),
      child: Text(
        label.toUpperCase(),
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
          color: AppColors.textMuted,
        ),
      ),
    );
  }
}

class _NotificationCard extends ConsumerWidget {
  final ContentItem item;
  final bool highlight;

  const _NotificationCard({required this.item, this.highlight = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actions = ref.read(contentActionsProvider);
    final date = item.notificationDate!;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: highlight
              ? AppColors.tertiary.withValues(alpha: 0.6)
              : AppColors.border,
        ),
        boxShadow: highlight
            ? [
                BoxShadow(
                  color: AppColors.tertiary.withValues(alpha: 0.12),
                  blurRadius: 14,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  item.type.emoji,
                  style: const TextStyle(fontSize: 20),
                ),
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
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tr('notif.scheduledAt', {'date': formatDateTime(date)}),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        color: highlight
                            ? AppColors.tertiary
                            : AppColors.textSecondary,
                        fontWeight:
                            highlight ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Acciones rápidas: nunca comprimidas gracias a Wrap.
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ActionChip(
                icon: Icons.play_arrow_rounded,
                label: tr('notif.action.watchNow'),
                color: AppColors.success,
                onTap: () async {
                  await actions.save(item.copyWith(
                    status: WatchStatus.watching,
                    notifyMe: false,
                    clearNotificationDate: true,
                  ));
                  if (context.mounted) {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            ContentDetailScreen(contentId: item.id),
                      ),
                    );
                  }
                },
              ),
              _ActionChip(
                icon: Icons.snooze,
                label: tr('notif.action.snooze'),
                color: AppColors.secondary,
                onTap: () async {
                  await actions.snooze(item);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(tr('notif.snoozed')),
                      ),
                    );
                  }
                },
              ),
              _ActionChip(
                icon: Icons.close,
                label: tr('notif.action.dismiss'),
                color: AppColors.error,
                onTap: () async {
                  await actions.dismissNotification(item);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(tr('notif.dismissed'))),
                    );
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.13),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PastTile extends StatelessWidget {
  final ContentItem item;

  const _PastTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle,
            size: 20,
            color: AppColors.success,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              item.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            tr('notif.watchedOn', {'date': formatDate(item.watchDate!)}),
            style: GoogleFonts.inter(
              fontSize: 11.5,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
