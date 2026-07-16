import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../core/l10n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/content_item.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/poster_image.dart';
import '../detail/content_detail_screen.dart';
import 'watch_time_stats.dart';

/// Pantalla "Estadísticas de tiempo": desglose de cuánto y qué has visto.
class WatchStatsScreen extends ConsumerWidget {
  const WatchStatsScreen({super.key});

  static const Map<ContentType, Color> _typeColors = {
    ContentType.movie: AppColors.primary,
    ContentType.series: AppColors.secondary,
    ContentType.documentary: AppColors.success,
    ContentType.anime: AppColors.tertiary,
    ContentType.shortFilm: AppColors.info,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(watchTimeStatsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(tr('stats.title'))),
      body: stats.isEmpty
          ? EmptyState(
              icon: Icons.query_stats_outlined,
              title: tr('stats.empty.title'),
              message: tr('stats.empty.message'),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              children: [
                _TotalCard(minutes: stats.totalMinutes),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _MiniStat(
                        icon: Icons.calendar_today_outlined,
                        color: AppColors.secondary,
                        value: formatLongDuration(stats.thisMonthMinutes),
                        label: tr('stats.thisMonth'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _MiniStat(
                        icon: Icons.event_available_outlined,
                        color: AppColors.tertiary,
                        value: formatLongDuration(stats.thisYearMinutes),
                        label: tr('stats.thisYear'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _MiniStat(
                        icon: Icons.local_fire_department_outlined,
                        color: AppColors.primary,
                        value: _days(stats.currentStreak),
                        label: tr('stats.currentStreak'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _MiniStat(
                        icon: Icons.emoji_events_outlined,
                        color: AppColors.warning,
                        value: _days(stats.longestStreak),
                        label: tr('stats.bestStreak'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                if (stats.minutesByType.isNotEmpty) ...[
                  _Section(
                    title: tr('stats.byType'),
                    child: _ByTypeBars(
                      minutesByType: stats.minutesByType,
                      colors: _typeColors,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                _Section(
                  title: tr('stats.activity12m'),
                  child: _MonthlyChart(monthly: stats.monthly),
                ),
                const SizedBox(height: 16),
                if (stats.longestTitle != null) ...[
                  _Section(
                    title: tr('stats.longestMarathon'),
                    child: _LongestTitle(item: stats.longestTitle!),
                  ),
                  const SizedBox(height: 16),
                ],
                Row(
                  children: [
                    Expanded(
                      child: _MiniStat(
                        icon: Icons.check_circle_outline,
                        color: AppColors.success,
                        value: '${stats.completedCount}',
                        label: tr('stats.titlesWatched'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _MiniStat(
                        icon: Icons.star_outline_rounded,
                        color: AppColors.tertiary,
                        value: stats.averageRating == null
                            ? '—'
                            : stats.averageRating!.toStringAsFixed(1),
                        label: tr('stats.avgRating'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  static String _days(int n) => trn('stats.days', n);
}

/// Tarjeta destacada con el total y una equivalencia divertida.
class _TotalCard extends StatelessWidget {
  final int minutes;

  const _TotalCard({required this.minutes});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: AppColors.primaryGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.35),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.timer_outlined, color: Colors.white, size: 22),
              const SizedBox(width: 8),
              Text(
                tr('stats.totalWatched'),
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            formatLongDuration(minutes),
            style: GoogleFonts.poppins(
              fontSize: 34,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _equivalence(minutes),
            style: GoogleFonts.inter(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }

  String _equivalence(int minutes) {
    if (minutes <= 0) return tr('stats.equiv.start');
    final hours = minutes / 60;
    if (hours < 24) {
      return tr('stats.equiv.hours', {'h': hours.toStringAsFixed(1)});
    }
    final days = hours / 24;
    return tr('stats.equiv.days', {'d': days.toStringAsFixed(1)});
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String value;
  final String label;

  const _MiniStat({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });

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
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 10),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              fontSize: 18,
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
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;

  const _Section({required this.title, required this.child});

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
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

/// Barras proporcionales del tiempo por tipo de contenido.
class _ByTypeBars extends StatelessWidget {
  final Map<ContentType, int> minutesByType;
  final Map<ContentType, Color> colors;

  const _ByTypeBars({required this.minutesByType, required this.colors});

  @override
  Widget build(BuildContext context) {
    final entries = minutesByType.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maxValue =
        entries.isEmpty ? 1 : entries.first.value.clamp(1, 1 << 30);

    return Column(
      children: [
        for (final entry in entries)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Text(entry.key.emoji, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                SizedBox(
                  width: 78,
                  child: Text(
                    entry.key.pluralLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: entry.value / maxValue,
                      minHeight: 10,
                      backgroundColor: AppColors.surfaceElevated,
                      valueColor: AlwaysStoppedAnimation(
                        colors[entry.key] ?? AppColors.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 62,
                  child: Text(
                    formatLongDuration(entry.value),
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Barras de minutos vistos por mes en los últimos 12 meses.
class _MonthlyChart extends StatelessWidget {
  final List<MonthBucket> monthly;

  const _MonthlyChart({required this.monthly});

  @override
  Widget build(BuildContext context) {
    final maxMinutes = monthly.fold<int>(0, (m, b) => b.minutes > m ? b.minutes : m);
    if (maxMinutes == 0) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(
          tr('stats.noActivity'),
          style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted),
        ),
      );
    }

    return SizedBox(
      height: 170,
      child: BarChart(
        BarChartData(
          maxY: maxMinutes * 1.2,
          alignment: BarChartAlignment.spaceAround,
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => AppColors.surfaceElevated,
              getTooltipItem: (group, _, rod, _) {
                final bucket = monthly[group.x];
                return BarTooltipItem(
                  '${formatLongDuration(bucket.minutes)}\n${trn('stats.views', bucket.count)}',
                  GoogleFonts.inter(
                    fontSize: 11,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                );
              },
            ),
          ),
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
                reservedSize: 26,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= monthly.length) {
                    return const SizedBox.shrink();
                  }
                  // Muestra la inicial del mes (uno de cada dos para no saturar).
                  if (index.isOdd) return const SizedBox.shrink();
                  final label =
                      DateFormat('MMM', S.lang.code).format(monthly[index].month);
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      label.substring(0, label.length >= 3 ? 3 : label.length),
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
            for (var i = 0; i < monthly.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: monthly[i].minutes.toDouble(),
                    width: 12,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(4),
                    ),
                    color: monthly[i].minutes == 0
                        ? AppColors.surfaceElevated
                        : AppColors.secondary,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _LongestTitle extends StatelessWidget {
  final ContentItem item;

  const _LongestTitle({required this.item});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ContentDetailScreen(contentId: item.id),
        ),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: PosterImage(item: item, width: 54, height: 80),
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
                  style: GoogleFonts.inter(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${item.type.emoji} ${item.type.label}  ·  ${formatLongDuration(item.totalMinutes)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: AppColors.textMuted, size: 20),
        ],
      ),
    );
  }
}
