import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/l10n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/content_item.dart';
import '../../data/models/watch_event.dart';
import '../../providers/providers.dart';
import '../../shared/widgets/app_dialog.dart';
import '../../shared/widgets/content_card.dart';
import '../../shared/widgets/genre_chip.dart';
import '../../shared/widgets/poster_image.dart';
import '../../shared/widgets/rating_stars.dart';
import '../../shared/widgets/status_badge.dart';
import '../collections/add_to_collection.dart';
import '../content_form/content_form_screen.dart';
import 'where_to_watch.dart';

/// Pantalla de detalle (spec 7.2): SliverAppBar con póster, acciones rápidas,
/// info grid, notas, recomendación y contenido relacionado.
class ContentDetailScreen extends ConsumerWidget {
  final String contentId;

  const ContentDetailScreen({super.key, required this.contentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final item = ref.watch(contentByIdProvider(contentId));

    if (item == null) {
      // El contenido fue eliminado mientras la pantalla estaba abierta.
      return const Scaffold(body: SizedBox.shrink());
    }

    final allItems =
        ref.watch(contentListProvider).value ?? const <ContentItem>[];
    final related = allItems
        .where((other) =>
            other.id != item.id &&
            other.genres.any((g) => item.genres.contains(g)))
        .take(8)
        .toList();

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          _buildAppBar(context, ref, item),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildQuickActions(context, ref, item),
                  const SizedBox(height: 24),
                  _buildInfoGrid(context, item),
                  const SizedBox(height: 24),
                  WhereToWatch(item: item),
                  const SizedBox(height: 24),
                  if (item.type.hasEpisodes && item.episodes != null) ...[
                    _EpisodeProgress(item: item),
                    const SizedBox(height: 24),
                  ],
                  if (item.userRating != null) ...[
                    _sectionTitle(tr('detail.section.yourRating')),
                    RatingStars(rating: item.userRating, size: 26),
                    const SizedBox(height: 24),
                  ],
                  if (item.genres.isNotEmpty) ...[
                    _sectionTitle(tr('form.field.genres')),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final genre in item.genres)
                          GenreChip(label: localizedGenre(genre)),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],
                  if (item.personalNote != null &&
                      item.personalNote!.isNotEmpty) ...[
                    _sectionTitle(tr('form.field.note')),
                    _ExpandableNote(text: item.personalNote!),
                    const SizedBox(height: 24),
                  ],
                  if (item.isRecommendation) ...[
                    _RecommendationCard(item: item),
                    const SizedBox(height: 24),
                  ],
                  if (item.watchLog.isNotEmpty ||
                      item.status == WatchStatus.completed ||
                      item.status == WatchStatus.rewatchPending) ...[
                    _sectionTitle(tr('detail.section.watchHistory')),
                    _WatchHistory(item: item),
                    const SizedBox(height: 24),
                  ],
                  if (related.isNotEmpty) ...[
                    _sectionTitle(tr('detail.section.similar')),
                    SizedBox(
                      height: 210,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: related.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 12),
                        itemBuilder: (context, index) {
                          final other = related[index];
                          return SizedBox(
                            width: 140,
                            child: ContentCard(
                              item: other,
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => ContentDetailScreen(
                                    contentId: other.id,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                  SizedBox(
                    height: MediaQuery.paddingOf(context).bottom,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, WidgetRef ref, ContentItem item) {
    return SliverAppBar(
      pinned: true,
      expandedHeight: 400,
      collapsedHeight: 80,
      backgroundColor: AppColors.background,
      leading: Padding(
        padding: const EdgeInsets.only(left: 8),
        child: _CircleIconButton(
          icon: Icons.arrow_back,
          onTap: () => Navigator.of(context).pop(),
        ),
      ),
      actions: [
        _CircleIconButton(
          icon: Icons.collections_bookmark_outlined,
          onTap: () => showItemCollectionsSheet(context: context, itemId: item.id),
        ),
        const SizedBox(width: 8),
        _CircleIconButton(
          icon: item.isFavorite
              ? Icons.favorite_rounded
              : Icons.favorite_outline_rounded,
          color: item.isFavorite ? AppColors.primary : Colors.white,
          onTap: () => ref.read(contentActionsProvider).toggleFavorite(item),
        ),
        const SizedBox(width: 8),
        _CircleIconButton(
          icon: Icons.delete_outline,
          onTap: () => _confirmDelete(context, ref, item),
        ),
        const SizedBox(width: 12),
      ],
      flexibleSpace: FlexibleSpaceBar(
        titlePadding:
            const EdgeInsets.only(left: 64, right: 110, bottom: 22),
        title: LayoutBuilder(
          builder: (context, constraints) {
            final settings = context
                .dependOnInheritedWidgetOfExactType<FlexibleSpaceBarSettings>();
            final collapsed = settings != null &&
                settings.currentExtent <= settings.minExtent + 20;
            return AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: collapsed ? 1 : 0,
              child: Text(
                item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            );
          },
        ),
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Fondo: póster desenfocado a pantalla completa.
            PosterImage(item: item),
            ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  color: AppColors.background.withValues(alpha: 0.55),
                ),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    AppColors.background.withValues(alpha: 0.65),
                    AppColors.background,
                  ],
                  stops: const [0.4, 0.8, 1.0],
                ),
              ),
            ),
            // Póster nítido centrado + título.
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(top: 48, bottom: 16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      height: 190,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.55),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: AspectRatio(
                          aspectRatio: 2 / 3,
                          child: PosterImage(item: item),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        item.title,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        StatusBadge(status: item.status),
                        Text(
                          '${item.type.emoji} ${item.type.label}',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions(
    BuildContext context,
    WidgetRef ref,
    ContentItem item,
  ) {
    final actions = ref.read(contentActionsProvider);
    final isSeen = item.status == WatchStatus.completed;

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      alignment: WrapAlignment.center,
      children: [
        _QuickAction(
          icon: isSeen ? Icons.replay : Icons.check_circle_outline,
          label: tr(isSeen ? 'detail.action.rewatch' : 'detail.action.markWatched'),
          color: isSeen ? AppColors.tertiary : AppColors.success,
          onTap: () async {
            if (isSeen) {
              await actions
                  .save(item.copyWith(status: WatchStatus.rewatchPending));
            } else {
              await actions.markCompleted(item);
            }
          },
        ),
        _QuickAction(
          icon: Icons.alarm_add_outlined,
          label: tr('detail.action.schedule'),
          color: AppColors.secondary,
          onTap: () => _scheduleReminder(context, ref, item),
        ),
        _QuickAction(
          icon: Icons.share_outlined,
          label: tr('detail.action.share'),
          color: AppColors.info,
          onTap: () => _share(item),
        ),
        _QuickAction(
          icon: Icons.edit_outlined,
          label: tr('common.edit'),
          color: AppColors.textSecondary,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ContentFormScreen(original: item),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoGrid(BuildContext context, ContentItem item) {
    final entries = <(String, String)>[
      if (item.releaseDate != null)
        (tr('detail.info.year'), item.releaseDate!.year.toString()),
      (
        item.type.hasEpisodes
            ? tr('detail.info.per', {'unit': item.type.unitLabel})
            : tr('form.field.duration'),
        formatDuration(item.durationMinutes),
      ),
      if (item.episodes != null)
        (
          item.type.unitsLabel[0].toUpperCase() +
              item.type.unitsLabel.substring(1),
          '${item.episodes}',
        ),
      (tr('detail.info.added'), formatRelative(item.addedAt)),
      if (item.watchDate != null)
        (
          item.status == WatchStatus.completed
              ? (item.type.isRead
                  ? tr('detail.info.readOn')
                  : tr('detail.info.watchedOn'))
              : tr('detail.info.scheduled'),
          formatDate(item.watchDate!),
        ),
      if (item.notifyMe && item.notificationDate != null)
        (tr('detail.info.reminder'), formatDateTime(item.notificationDate!)),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Wrap(
        spacing: 24,
        runSpacing: 16,
        children: [
          for (final (label, value) in entries)
            SizedBox(
              width: 130,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.8,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      );

  Future<void> _scheduleReminder(
    BuildContext context,
    WidgetRef ref,
    ContentItem item,
  ) async {
    final now = DateTime.now();
    final initial = item.notificationDate != null &&
            item.notificationDate!.isAfter(now)
        ? item.notificationDate!
        : now.add(const Duration(hours: 2));

    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 5),
      locale: S.lang.locale,
    );
    if (date == null || !context.mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null || !context.mounted) return;

    final scheduled =
        DateTime(date.year, date.month, date.day, time.hour, time.minute);
    if (scheduled.isBefore(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('detail.schedule.mustBeFuture'))),
      );
      return;
    }

    await ref.read(contentActionsProvider).save(
          item.copyWith(
            notifyMe: true,
            notificationDate: scheduled,
            watchDate: scheduled,
          ),
        );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('detail.schedule.set',
              {'date': formatDateTime(scheduled)})),
        ),
      );
    }
  }

  void _share(ContentItem item) {
    final buffer =
        StringBuffer(tr('detail.share.recommend', {'title': item.title}));
    if (item.genres.isNotEmpty) {
      buffer.write('\n');
      buffer.write(tr('detail.share.genres',
          {'genres': item.genres.map(localizedGenre).join(', ')}));
    }
    if (item.userRating != null) {
      buffer.write('\n');
      buffer.write(tr('detail.share.myRating',
          {'rating': item.userRating!.toStringAsFixed(1)}));
    }
    if (item.personalNote != null && item.personalNote!.isNotEmpty) {
      buffer.write('\n"${item.personalNote}"');
    }
    buffer.write('\n\n');
    buffer.write(tr('detail.share.footer'));
    SharePlus.instance.share(ShareParams(text: buffer.toString()));
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    ContentItem item,
  ) async {
    final confirmed = await showAppConfirmDialog(
      context: context,
      title: tr('detail.delete.title', {'title': item.title}),
      message: tr('detail.delete.message'),
      confirmLabel: tr('common.delete'),
      icon: Icons.delete_outline,
      accent: AppColors.error,
    );
    if (!confirmed || !context.mounted) return;

    await ref.read(contentActionsProvider).delete(item);
    if (context.mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('actions.deleted', {'title': item.title}))),
      );
    }
  }
}

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color color;

  const _CircleIconButton({
    required this.icon,
    required this.onTap,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.black.withValues(alpha: 0.35),
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 42,
            height: 42,
            child: Icon(icon, size: 22, color: color),
          ),
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 76,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: color.withValues(alpha: 0.4)),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Progreso de episodios con stepper (+/-) para series y anime.
class _EpisodeProgress extends ConsumerWidget {
  final ContentItem item;

  const _EpisodeProgress({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final total = item.episodes ?? 0;
    final current = (item.currentEpisode ?? 0).clamp(0, total);
    final actions = ref.read(contentActionsProvider);

    Future<void> setEpisode(int value) async {
      final clamped = value.clamp(0, total);
      var updated = item.copyWith(currentEpisode: clamped);
      if (clamped >= total && total > 0) {
        updated = updated.copyWith(
          status: WatchStatus.completed,
          watchDate: DateTime.now(),
        );
      } else if (clamped > 0 && item.status == WatchStatus.notStarted) {
        updated = updated.copyWith(status: WatchStatus.watching);
      }
      // Anota en el diario los episodios nuevos. Si el usuario corrige el
      // contador hacia atrás no se registra nada.
      await actions.save(updated.logProgressSince(item));
    }

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
                  tr('detail.progress.title', {'units': item.type.unitsLabel}),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Text(
                '$current / $total',
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.secondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: total == 0 ? 0 : current / total,
              minHeight: 8,
              backgroundColor: AppColors.surfaceElevated,
              color: AppColors.secondary,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed:
                        current > 0 ? () => setEpisode(current - 1) : null,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textPrimary,
                      side: BorderSide(color: AppColors.border),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.remove, size: 20),
                    label: Text(
                      tr('detail.progress.previous'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed:
                        current < total ? () => setEpisode(current + 1) : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.secondary,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.add, size: 20),
                    label: Text(
                      tr('detail.progress.watchedPlusOne'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Nota personal expandible (3 líneas colapsada).
class _ExpandableNote extends StatefulWidget {
  final String text;

  const _ExpandableNote({required this.text});

  @override
  State<_ExpandableNote> createState() => _ExpandableNoteState();
}

class _ExpandableNoteState extends State<_ExpandableNote> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              alignment: Alignment.topCenter,
              child: Text(
                widget.text,
                maxLines: _expanded ? null : 3,
                overflow: _expanded ? null : TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  height: 1.6,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            if (widget.text.length > 120) ...[
              const SizedBox(height: 8),
              Text(
                tr(_expanded ? 'detail.note.less' : 'detail.note.more'),
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.secondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Card especial cuando el contenido fue recomendado por un amigo.
class _RecommendationCard extends StatelessWidget {
  final ContentItem item;

  const _RecommendationCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final name = item.recommendedBy ?? tr('detail.rec.defaultName');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.tertiary.withValues(alpha: 0.5)),
        gradient: LinearGradient(
          colors: [
            AppColors.tertiary.withValues(alpha: 0.12),
            AppColors.surface,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.tertiary,
            child: Text(
              name[0].toUpperCase(),
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.black,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr('detail.rec.by', {'name': name}),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.tertiary,
                  ),
                ),
                if (item.recommendedNote != null &&
                    item.recommendedNote!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    '"${item.recommendedNote}"',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                      height: 1.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Diario de visionados: cuándo se vio y cuánto, con opción de añadir a mano
/// una vuelta antigua o borrar un registro equivocado.
class _WatchHistory extends ConsumerWidget {
  final ContentItem item;

  const _WatchHistory({required this.item});

  Future<void> _addEvent(BuildContext context, WidgetRef ref) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(1950),
      lastDate: now,
      helpText: tr('detail.history.whenSeen'),
      locale: S.lang.locale,
    );
    if (picked == null) return;

    // Una vuelta entera: la duración total del título.
    final minutes = item.totalMinutes;
    if (minutes <= 0) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('detail.history.needDuration')),
          ),
        );
      }
      return;
    }

    final log = [
      ...item.watchLog,
      WatchEvent(
        date: picked,
        minutes: minutes,
        episodes: item.type.hasEpisodes ? item.episodes : null,
      ),
    ]..sort((a, b) => a.date.compareTo(b.date));

    await ref.read(contentActionsProvider).save(item.copyWith(
          watchLog: log,
          rewatchCount: log.length > 1 ? log.length - 1 : null,
          watchDate: log.last.date,
        ));
  }

  Future<void> _removeEvent(
    BuildContext context,
    WidgetRef ref,
    WatchEvent event,
  ) async {
    final confirmed = await showAppConfirmDialog(
      context: context,
      title: tr('detail.history.deleteTitle'),
      message: tr('detail.history.deleteMessage',
          {'date': formatDate(event.date)}),
      confirmLabel: tr('common.delete'),
      icon: Icons.delete_outline,
      accent: AppColors.error,
    );
    if (!confirmed) return;

    final log = [...item.watchLog]..remove(event);
    await ref.read(contentActionsProvider).save(item.copyWith(
          watchLog: log,
          rewatchCount: log.length > 1 ? log.length - 1 : null,
          watchDate: log.isEmpty ? null : log.last.date,
          clearWatchDate: log.isEmpty,
        ));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Del más reciente al más antiguo: lo último es lo que interesa.
    final events = item.watchLog.reversed.toList();

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
              const Icon(Icons.history, color: AppColors.success, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  trn('detail.history.seenTimes', events.length),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              if (item.loggedMinutes > 0)
                Text(
                  formatLongDuration(item.loggedMinutes),
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.secondary,
                  ),
                ),
            ],
          ),
          if (events.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            for (final event in events)
              _WatchEventRow(
                event: event,
                type: item.type,
                onDelete: () => _removeEvent(context, ref, event),
              ),
          ],
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => _addEvent(context, ref),
              icon: const Icon(Icons.add, size: 18),
              label: Text(tr('detail.history.addAnother')),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.secondary,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WatchEventRow extends StatelessWidget {
  final WatchEvent event;
  final ContentType type;
  final VoidCallback onDelete;

  const _WatchEventRow({
    required this.event,
    required this.type,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final units = event.episodes;
    final detail = [
      formatDuration(event.minutes),
      if (units != null && units > 0)
        '$units ${units == 1 ? type.unitLabel : type.unitsLabel}',
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  formatDate(event.date),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  '$detail · ${formatRelative(event.date)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onDelete,
            icon: const Icon(Icons.close, size: 16),
            color: AppColors.textMuted,
            tooltip: tr('detail.history.deleteTooltip'),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}
