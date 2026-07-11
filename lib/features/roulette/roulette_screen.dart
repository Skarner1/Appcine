import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/content_item.dart';
import '../../providers/providers.dart';
import '../../shared/widgets/app_buttons.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/poster_image.dart';
import '../detail/content_detail_screen.dart';

/// Filtros del sorteo "¿Qué veo hoy?".
class RouletteFilter {
  /// null = cualquier tipo.
  final ContentType? type;

  /// null = cualquier género.
  final String? genre;

  /// Duración máxima por sesión en minutos (película completa o episodio de
  /// serie/anime). null = sin límite.
  final int? maxMinutes;

  const RouletteFilter({this.type, this.genre, this.maxMinutes});

  RouletteFilter copyWith({
    ContentType? type,
    String? genre,
    int? maxMinutes,
    bool clearType = false,
    bool clearGenre = false,
    bool clearMaxMinutes = false,
  }) {
    return RouletteFilter(
      type: clearType ? null : (type ?? this.type),
      genre: clearGenre ? null : (genre ?? this.genre),
      maxMinutes: clearMaxMinutes ? null : (maxMinutes ?? this.maxMinutes),
    );
  }
}

/// Candidatos del sorteo: contenido aún por ver que cumple los filtros.
///
/// El pool son los estados "pendientes" (falta ver, viendo, en pausa y
/// volver a ver). Con [RouletteFilter.maxMinutes] se excluyen los títulos sin
/// duración registrada (0) porque no se puede garantizar que quepan.
List<ContentItem> rouletteCandidates(
  List<ContentItem> items,
  RouletteFilter filter,
) {
  return items.where((i) {
    final isPending = i.status == WatchStatus.notStarted ||
        i.status == WatchStatus.watching ||
        i.status == WatchStatus.onHold ||
        i.status == WatchStatus.rewatchPending;
    if (!isPending) return false;
    if (filter.type != null && i.type != filter.type) return false;
    if (filter.genre != null && !i.genres.contains(filter.genre)) return false;
    if (filter.maxMinutes != null) {
      if (i.durationMinutes <= 0 || i.durationMinutes > filter.maxMinutes!) {
        return false;
      }
    }
    return true;
  }).toList();
}

/// Pantalla de la ruleta: elige al azar algo pendiente de ver, con filtros
/// opcionales de tipo, género y duración. Todo local, sin red.
class RouletteScreen extends ConsumerStatefulWidget {
  /// Inyectable para tests deterministas.
  final Random? random;

  const RouletteScreen({super.key, this.random});

  @override
  ConsumerState<RouletteScreen> createState() => _RouletteScreenState();
}

class _RouletteScreenState extends ConsumerState<RouletteScreen> {
  late final Random _random = widget.random ?? Random();

  RouletteFilter _filter = const RouletteFilter();
  bool _spinning = false;
  ContentItem? _result;

  /// Título mostrado durante el giro (parpadeo entre candidatos).
  ContentItem? _flicker;

  static const _durationOptions = <int?>[null, 30, 60, 90, 120];

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(contentListProvider).value ?? const <ContentItem>[];
    final candidates = rouletteCandidates(items, _filter);
    // Géneros presentes en el pool (ignorando el filtro de género) para no
    // ofrecer géneros que nunca darían resultado.
    final poolForGenres = rouletteCandidates(
      items,
      _filter.copyWith(clearGenre: true),
    );
    final availableGenres = <String>{
      for (final i in poolForGenres) ...i.genres,
    }.toList()
      ..sort((a, b) => kGenres.indexOf(a).compareTo(kGenres.indexOf(b)));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('¿Qué veo hoy?'),
        centerTitle: false,
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            _Filters(
              filter: _filter,
              availableGenres: availableGenres,
              durationOptions: _durationOptions,
              enabled: !_spinning,
              onChanged: (f) => setState(() {
                _filter = f;
                _result = null;
              }),
            ),
            Expanded(
              child: candidates.isEmpty
                  ? EmptyState(
                      icon: Icons.casino_outlined,
                      title: 'Sin candidatos',
                      message: _filter.type == null &&
                              _filter.genre == null &&
                              _filter.maxMinutes == null
                          ? 'No tienes contenido pendiente de ver. Agrega títulos a tu catálogo y vuelve a intentarlo.'
                          : 'Ningún pendiente cumple estos filtros. Prueba a relajarlos.',
                    )
                  : _Stage(
                      spinning: _spinning,
                      result: _result,
                      flicker: _flicker,
                      poolSize: candidates.length,
                    ),
            ),
            if (candidates.isNotEmpty)
              _ActionBar(
                spinning: _spinning,
                hasResult: _result != null,
                onSpin: () => _spin(candidates),
                onOpen: _result == null
                    ? null
                    : () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                ContentDetailScreen(contentId: _result!.id),
                          ),
                        ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _spin(List<ContentItem> pool) async {
    if (_spinning || pool.isEmpty) return;
    final chosen = pool[_random.nextInt(pool.length)];
    setState(() {
      _spinning = true;
      _result = null;
      _flicker = pool[_random.nextInt(pool.length)];
    });

    // Parpadeo que desacelera hasta detenerse en el elegido.
    var delay = 45;
    for (var step = 0; step < 22; step++) {
      if (!mounted) return;
      setState(() => _flicker = pool[_random.nextInt(pool.length)]);
      await Future<void>.delayed(Duration(milliseconds: delay));
      delay = (delay * 1.14).round();
    }
    if (!mounted) return;
    setState(() {
      _result = chosen;
      _flicker = null;
      _spinning = false;
    });
  }
}

/// Fila de filtros: tipo, duración y género.
class _Filters extends StatelessWidget {
  final RouletteFilter filter;
  final List<String> availableGenres;
  final List<int?> durationOptions;
  final bool enabled;
  final ValueChanged<RouletteFilter> onChanged;

  const _Filters({
    required this.filter,
    required this.availableGenres,
    required this.durationOptions,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label('Tipo'),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _pill(
                  label: 'Todo',
                  selected: filter.type == null,
                  onTap: () => onChanged(filter.copyWith(clearType: true)),
                ),
                for (final type in ContentType.values)
                  _pill(
                    label: type.label,
                    selected: filter.type == type,
                    onTap: () => onChanged(filter.copyWith(type: type)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _label('Duración máx.'),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final opt in durationOptions)
                  _pill(
                    label: opt == null ? 'Cualquiera' : '≤ ${formatDuration(opt)}',
                    selected: filter.maxMinutes == opt,
                    onTap: () => onChanged(
                      opt == null
                          ? filter.copyWith(clearMaxMinutes: true)
                          : filter.copyWith(maxMinutes: opt),
                    ),
                  ),
              ],
            ),
          ),
          if (availableGenres.isNotEmpty) ...[
            const SizedBox(height: 12),
            _label('Género'),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _pill(
                    label: 'Todos',
                    selected: filter.genre == null,
                    onTap: () => onChanged(filter.copyWith(clearGenre: true)),
                  ),
                  for (final genre in availableGenres)
                    _pill(
                      label: genre,
                      selected: filter.genre == genre,
                      onTap: () => onChanged(filter.copyWith(genre: genre)),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _label(String text) => Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.textMuted,
          letterSpacing: 0.3,
        ),
      );

  Widget _pill({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: selected ? AppColors.primary : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? AppColors.primary : AppColors.border,
              ),
            ),
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Zona central: póster grande que parpadea al girar y revela el elegido.
class _Stage extends StatelessWidget {
  final bool spinning;
  final ContentItem? result;
  final ContentItem? flicker;
  final int poolSize;

  const _Stage({
    required this.spinning,
    required this.result,
    required this.flicker,
    required this.poolSize,
  });

  @override
  Widget build(BuildContext context) {
    final shown = spinning ? flicker : result;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (shown == null)
              _Idle(poolSize: poolSize)
            else
              _PosterCard(item: shown, dimmed: spinning),
            const SizedBox(height: 20),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: result != null && !spinning
                  ? Column(
                      key: const ValueKey('result-info'),
                      children: [
                        Text(
                          result!.title,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _subtitle(result!),
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    )
                  : const SizedBox(height: 8, key: ValueKey('empty-info')),
            ),
          ],
        ),
      ),
    );
  }

  String _subtitle(ContentItem item) {
    final parts = <String>['${item.type.emoji} ${item.type.label}'];
    if (item.durationMinutes > 0) {
      parts.add(formatDuration(item.durationMinutes));
    }
    if (item.genres.isNotEmpty) parts.add(item.genres.first);
    return parts.join('  ·  ');
  }
}

class _Idle extends StatelessWidget {
  final int poolSize;

  const _Idle({required this.poolSize});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.12),
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
          ),
          child: const Icon(
            Icons.casino_rounded,
            size: 60,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          '$poolSize ${poolSize == 1 ? 'título' : 'títulos'} en juego',
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Pulsa "Girar" y deja que la suerte elija',
          style: GoogleFonts.inter(
            fontSize: 13,
            color: AppColors.textMuted,
          ),
        ),
      ],
    );
  }
}

class _PosterCard extends StatelessWidget {
  final ContentItem item;
  final bool dimmed;

  const _PosterCard({required this.item, required this.dimmed});

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: dimmed ? 0.65 : 1,
      duration: const Duration(milliseconds: 120),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: dimmed ? 0.15 : 0.35),
              blurRadius: 28,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: PosterImage(item: item, width: 190, height: 285),
        ),
      ),
    );
  }
}

/// Barra inferior con "Girar / Otra" y "Ver ficha".
class _ActionBar extends StatelessWidget {
  final bool spinning;
  final bool hasResult;
  final VoidCallback onSpin;
  final VoidCallback? onOpen;

  const _ActionBar({
    required this.spinning,
    required this.hasResult,
    required this.onSpin,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Row(
        children: [
          if (hasResult && !spinning) ...[
            Expanded(
              child: SecondaryButton(
                label: 'Ver ficha',
                icon: Icons.open_in_new_rounded,
                onTap: onOpen,
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: PrimaryButton(
              label: spinning
                  ? 'Girando…'
                  : hasResult
                      ? 'Otra'
                      : 'Girar',
              icon: spinning ? null : Icons.casino_rounded,
              isLoading: spinning,
              onTap: spinning ? null : onSpin,
            ),
          ),
        ],
      ),
    );
  }
}
