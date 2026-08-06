import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/l10n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/content_item.dart';
import '../../data/models/online_result.dart';
import '../../data/services/online_search_service.dart';
import '../../shared/widgets/content_type_carousel.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/poster_image.dart';
import '../content_form/content_form_screen.dart';

/// Búsqueda de contenido en internet. El usuario elige categoría
/// (Película / Serie / Anime), busca, y toca un resultado para agregarlo
/// al catálogo (abre el formulario ya pre-rellenado).
///
/// En [pickerMode] no abre el formulario: devuelve el [OnlineResult] elegido
/// con `Navigator.pop`, para que el formulario en edición traiga póster/datos.
class OnlineSearchScreen extends ConsumerStatefulWidget {
  final bool pickerMode;

  /// Si se indica, fija la categoría de búsqueda y oculta el selector.
  final ContentType? lockedType;

  const OnlineSearchScreen({
    super.key,
    this.pickerMode = false,
    this.lockedType,
  });

  @override
  ConsumerState<OnlineSearchScreen> createState() => _OnlineSearchScreenState();
}

class _OnlineSearchScreenState extends ConsumerState<OnlineSearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;

  late ContentType _type = widget.lockedType ?? ContentType.movie;
  Future<List<OnlineResult>>? _future;
  String _query = '';

  // Categorías buscables online. Documentales y cortos no están: Cinemeta los
  // devuelve mezclados con las películas, así que tendrían el mismo buscador.
  static const _types = [
    ContentType.movie,
    ContentType.series,
    ContentType.anime,
    ContentType.manga,
    ContentType.book,
  ];

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    setState(() {}); // refresca el botón "limpiar" mientras se escribe
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () {
      _runSearch(value);
    });
  }

  void _runSearch(String value, {bool force = false}) {
    final q = value.trim();
    if (!force && q == _query && _future != null) return;
    setState(() {
      _query = q;
      _future = q.isEmpty
          ? null
          : ref.read(onlineSearchServiceProvider).search(_type, q);
    });
  }

  void _selectType(ContentType type) {
    if (type == _type) return;
    setState(() {
      _type = type;
      _future = _query.isEmpty
          ? null
          : ref.read(onlineSearchServiceProvider).search(_type, _query);
    });
  }

  Future<void> _addResult(OnlineResult result) async {
    // Las películas llegan "ligeras": se completan (géneros, duración,
    // sinopsis…) al seleccionarlas, mostrando un indicador mientras carga.
    final source =
        result.detailId != null ? await _enrichResult(result) : result;
    if (!mounted) return;
    if (widget.pickerMode) {
      Navigator.of(context).pop(source); // devuelve el resultado al formulario
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ContentFormScreen(draft: source.toDraft()),
      ),
    );
  }

  Future<OnlineResult> _enrichResult(OnlineResult result) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: SizedBox(
          width: 46,
          height: 46,
          child: CircularProgressIndicator(strokeWidth: 3),
        ),
      ),
    );
    final enriched =
        await ref.read(onlineSearchServiceProvider).enrich(result);
    if (mounted) Navigator.of(context, rootNavigator: true).pop();
    return enriched;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          tr(widget.pickerMode ? 'search.title.picker' : 'search.title.online'),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (widget.lockedType == null) ...[
              const SizedBox(height: 8),
              // El mismo carrusel del catálogo: aquí antes era un segmentado
              // que repartía el ancho entre los tipos, y al pasar de tres a
              // cinco empezó a cortar las etiquetas.
              ContentTypeCarousel(
                types: _types,
                selected: _type,
                onSelect: (type) {
                  if (type != null) _selectType(type);
                },
              ),
              const SizedBox(height: 6),
            ],
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: Column(
                children: [
                  TextField(
                    controller: _controller,
                    autofocus: true,
                    textInputAction: TextInputAction.search,
                    onChanged: _onQueryChanged,
                    onSubmitted: _runSearch,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: _hintForType(),
                      prefixIcon:
                          Icon(Icons.search, color: AppColors.textMuted),
                      suffixIcon: _controller.text.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.close,
                                  color: AppColors.textMuted),
                              onPressed: () {
                                _debounce?.cancel();
                                _controller.clear();
                                _runSearch('');
                              },
                            )
                          : null,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  String _hintForType() {
    final example = switch (_type) {
      ContentType.series => 'Breaking Bad, Dark…',
      ContentType.anime => 'Naruto, Frieren…',
      ContentType.manga => 'Berserk, One Piece…',
      ContentType.book => 'Dune, 1984…',
      _ => 'Interstellar, Matrix…',
    };
    return tr('form.hint.example', {'x': example});
  }

  Widget _buildBody() {
    final future = _future;
    if (future == null) {
      return _IdleHint(type: _type, pickerMode: widget.pickerMode);
    }
    return FutureBuilder<List<OnlineResult>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingState();
        }
        if (snapshot.hasError) {
          return EmptyState(
            icon: Icons.wifi_off_rounded,
            title: tr('search.offline.title'),
            // En pickerMode ya está en el formulario: decirle que lo agregue a
            // mano sería absurdo, es justo lo que está haciendo.
            message: widget.pickerMode
                ? snapshot.error.toString()
                : tr('search.offline.message',
                    {'error': snapshot.error.toString()}),
            actionLabel: tr('common.retry'),
            onAction: () => _runSearch(_query, force: true),
          );
        }
        final results = snapshot.data ?? const [];
        if (results.isEmpty) {
          return EmptyState(
            imageAsset: 'assets/img/empty/no_results.png',
            icon: Icons.search_off_rounded,
            title: tr('search.noResults.title'),
            message: tr('search.noResults.message', {
              'query': _query,
              'category': _type.pluralLabel.toLowerCase(),
            }),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          itemCount: results.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) => _ResultTile(
            result: results[index],
            onTap: () => _addResult(results[index]),
          ),
        );
      },
    );
  }
}


/// Fila de resultado: póster + título, metadatos, valoración y botón agregar.
class _ResultTile extends StatelessWidget {
  final OnlineResult result;
  final VoidCallback onTap;

  const _ResultTile({required this.result, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final thumb = ContentItem(
      id: 'r',
      title: result.title,
      type: result.type,
      posterUrl: result.posterUrl,
      addedAt: DateTime.now(),
    );

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 64,
                  height: 96,
                  child: PosterImage(item: thumb),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      result.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _meta(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    if (result.genres.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        result.genres.map(localizedGenre).join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                    if (result.rating != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.star_rounded,
                              size: 15, color: AppColors.tertiary),
                          const SizedBox(width: 3),
                          Text(
                            result.rating!.toStringAsFixed(1),
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.tertiary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.add_rounded,
                    color: AppColors.primary, size: 22),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _meta() {
    final parts = <String>[];
    if (result.year != null) parts.add('${result.year}');
    parts.add(result.type.label);
    if (result.type.hasEpisodes && result.episodes != null) {
      parts.add('${result.episodes} ${tr('abbr.ep')}');
    } else if (!result.type.hasEpisodes && result.durationMinutes > 0) {
      final h = result.durationMinutes ~/ 60;
      final m = result.durationMinutes % 60;
      parts.add(h > 0
          ? '$h${tr('dur.hourShort')} $m${tr('dur.minShort')}'
          : '$m${tr('dur.minShort')}');
    }
    return parts.join('  ·  ');
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 30,
            height: 30,
            child: CircularProgressIndicator(strokeWidth: 2.6),
          ),
          const SizedBox(height: 16),
          Text(
            tr('search.searching'),
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Pantalla inicial (aún sin búsqueda): explica la función.
class _IdleHint extends StatelessWidget {
  final ContentType type;
  final bool pickerMode;
  const _IdleHint({required this.type, this.pickerMode = false});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.surfaceElevated,
                border: Border.all(color: AppColors.border),
              ),
              child: const Icon(Icons.travel_explore_rounded,
                  size: 44, color: AppColors.primary),
            ),
            const SizedBox(height: 22),
            Text(
              tr(pickerMode
                  ? 'search.idle.picker.title'
                  : 'search.idle.add.title'),
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              tr(
                pickerMode
                    ? 'search.idle.picker.message'
                    : 'search.idle.add.message',
                {'category': type.pluralLabel.toLowerCase()},
              ),
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                height: 1.5,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
