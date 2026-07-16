import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/l10n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/content_item.dart';
import '../../providers/providers.dart';
import '../../shared/widgets/content_actions_sheet.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/genre_chip.dart';
import '../../shared/widgets/poster_image.dart';
import '../../shared/widgets/scale_tap.dart';
import '../../shared/widgets/staggered_item.dart';
import '../content_form/content_form_screen.dart';
import '../detail/content_detail_screen.dart';

/// Tab 3 — Recomendados: Amigos | Sistema | Tendencias.
class RecommendationsScreen extends ConsumerStatefulWidget {
  const RecommendationsScreen({super.key});

  @override
  ConsumerState<RecommendationsScreen> createState() =>
      _RecommendationsScreenState();
}

class _RecommendationsScreenState
    extends ConsumerState<RecommendationsScreen> {
  RecommendationTab _tab = RecommendationTab.friends;

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(recommendationsProvider(_tab));

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Text(
              tr('nav.recommendations'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                for (final tab in RecommendationTab.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GenreChip(
                      label: tab.label,
                      icon: switch (tab) {
                        RecommendationTab.friends => Icons.people_outline,
                        RecommendationTab.system => Icons.auto_awesome_outlined,
                        RecommendationTab.trending =>
                          Icons.local_fire_department_outlined,
                      },
                      selected: _tab == tab,
                      onTap: () => setState(() => _tab = tab),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: items.isEmpty
                ? EmptyState(
                    icon: switch (_tab) {
                      RecommendationTab.friends => Icons.people_outline,
                      RecommendationTab.system => Icons.auto_awesome_outlined,
                      RecommendationTab.trending =>
                        Icons.local_fire_department_outlined,
                    },
                    title: tr('rec.empty.title'),
                    message: switch (_tab) {
                      RecommendationTab.friends =>
                        tr('rec.empty.friends.msg'),
                      RecommendationTab.system => tr('rec.empty.system.msg'),
                      RecommendationTab.trending =>
                        tr('rec.empty.trending.msg'),
                    },
                    actionLabel: _tab == RecommendationTab.friends
                        ? tr('rec.empty.action')
                        : null,
                    onAction: _tab == RecommendationTab.friends
                        ? () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const ContentFormScreen(),
                              ),
                            )
                        : null,
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 14),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return StaggeredItem(
                        index: index,
                        child: _RecommendationCard(
                          item: item,
                          tab: _tab,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  ContentDetailScreen(contentId: item.id),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _RecommendationCard extends ConsumerWidget {
  final ContentItem item;
  final RecommendationTab tab;
  final VoidCallback onTap;

  const _RecommendationCard({
    required this.item,
    required this.tab,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final friendName = item.recommendedBy ?? tr('rec.friendDefault');
    final isPendingAlready = item.status == WatchStatus.notStarted;

    return ScaleTap(
      onTap: onTap,
      onLongPress: () => showContentActionsSheet(context, ref, item),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Encabezado: quién recomienda / origen.
              Row(
                children: [
                  if (tab == RecommendationTab.friends)
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: AppColors.tertiary,
                      child: Text(
                        friendName[0].toUpperCase(),
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                        ),
                      ),
                    )
                  else
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.secondary.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        tab == RecommendationTab.system
                            ? Icons.auto_awesome
                            : Icons.local_fire_department,
                        size: 18,
                        color: tab == RecommendationTab.system
                            ? AppColors.secondary
                            : AppColors.primary,
                      ),
                    ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          switch (tab) {
                            RecommendationTab.friends =>
                              tr('rec.recommendsYou', {'name': friendName}),
                            RecommendationTab.system =>
                              tr('source.algorithm'),
                            RecommendationTab.trending =>
                              tr('rec.header.trending'),
                          },
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Text(
                          formatRelative(item.addedAt),
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
                ],
              ),
              const SizedBox(height: 12),
              // Contenido: mini póster + info.
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      width: 64,
                      height: 96,
                      child: PosterImage(item: item),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          [
                            item.type.label,
                            if (item.genres.isNotEmpty)
                              item.genres.take(2).join(', '),
                            if (item.durationMinutes > 0)
                              item.type.hasEpisodes
                                  ? '${item.episodes ?? '?'} ${tr('abbr.ep')}'
                                  : formatDuration(item.durationMinutes),
                          ].join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        if (item.recommendedNote != null &&
                            item.recommendedNote!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            '"${item.recommendedNote}"',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 12.5,
                              fontStyle: FontStyle.italic,
                              height: 1.4,
                              color: AppColors.tertiary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Acción: marcar como pendiente.
              SizedBox(
                width: double.infinity,
                height: 48,
                child: isPendingAlready
                    ? OutlinedButton.icon(
                        onPressed: null,
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: AppColors.border),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(
                          Icons.bookmark_added_outlined,
                          size: 18,
                          color: AppColors.warning,
                        ),
                        label: Text(
                          tr('rec.inWatchlist'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.warning,
                          ),
                        ),
                      )
                    : ElevatedButton.icon(
                        onPressed: () async {
                          await ref
                              .read(contentActionsProvider)
                              .markPending(item);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  tr('rec.addedToWatchlist', {
                                    'title': item.title,
                                  }),
                                ),
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              AppColors.primary.withValues(alpha: 0.15),
                          foregroundColor: AppColors.primary,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color:
                                  AppColors.primary.withValues(alpha: 0.5),
                            ),
                          ),
                        ),
                        icon: const Icon(Icons.bookmark_add_outlined, size: 18),
                        label: Text(
                          tr('rec.markPending'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
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
