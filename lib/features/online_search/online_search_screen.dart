import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/content_item.dart';
import '../../data/models/online_result.dart';
import '../../data/services/online_search_service.dart';
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

  // Categorías buscables online.
  static const _types = [
    ContentType.movie,
    ContentType.series,
    ContentType.anime,
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
          widget.pickerMode ? 'Buscar carátula e info' : 'Buscar en internet',
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: Column(
                children: [
                  if (widget.lockedType == null) ...[
                    _TypeSelector(
                      types: _types,
                      selected: _type,
                      onSelect: _selectType,
                    ),
                    const SizedBox(height: 14),
                  ],
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
                          const Icon(Icons.search, color: AppColors.textMuted),
                      suffixIcon: _controller.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close,
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

  String _hintForType() => switch (_type) {
        ContentType.series => 'Ej. Breaking Bad, Dark…',
        ContentType.anime => 'Ej. Naruto, Frieren…',
        _ => 'Ej. Interstellar, Matrix…',
      };

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
            title: 'Sin conexión',
            message: snapshot.error.toString(),
            actionLabel: 'Reintentar',
            onAction: () => _runSearch(_query, force: true),
          );
        }
        final results = snapshot.data ?? const [];
        if (results.isEmpty) {
          return EmptyState(
            icon: Icons.search_off_rounded,
            title: 'Sin resultados',
            message:
                'No encontramos "$_query" en ${_type.pluralLabel.toLowerCase()}. '
                'Prueba con otro título o cambia de categoría.',
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

/// Selector segmentado de categoría (Película / Serie / Anime).
class _TypeSelector extends StatelessWidget {
  final List<ContentType> types;
  final ContentType selected;
  final ValueChanged<ContentType> onSelect;

  const _TypeSelector({
    required this.types,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          for (final type in types)
            Expanded(
              child: GestureDetector(
                onTap: () => onSelect(type),
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  height: 42,
                  decoration: BoxDecoration(
                    gradient: type == selected
                        ? const LinearGradient(colors: AppColors.primaryGradient)
                        : null,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: type == selected
                        ? [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.35),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        type.icon,
                        size: 16,
                        color: type == selected
                            ? Colors.white
                            : AppColors.textSecondary,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          type.pluralLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: type == selected
                                ? Colors.white
                                : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
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
                        result.genres.join(' · '),
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
      parts.add('${result.episodes} ep');
    } else if (!result.type.hasEpisodes && result.durationMinutes > 0) {
      final h = result.durationMinutes ~/ 60;
      final m = result.durationMinutes % 60;
      parts.add(h > 0 ? '${h}h ${m}m' : '${m}m');
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
            'Buscando…',
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
              pickerMode ? 'Trae la carátula' : 'Descubre y agrega',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              pickerMode
                  ? 'Busca ${type.pluralLabel.toLowerCase()} por su título y '
                      'elige uno: traeremos su póster y la info que falte a la ficha.'
                  : 'Busca ${type.pluralLabel.toLowerCase()} por su título. Elegí un '
                      'resultado y lo agregás a tu catálogo con su póster e información.',
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
