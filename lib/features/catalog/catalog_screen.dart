import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_constants.dart';
import '../../core/l10n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/content_item.dart';
import '../../providers/providers.dart';
import '../../shared/widgets/app_buttons.dart';
import '../../shared/widgets/content_actions_sheet.dart';
import '../../shared/widgets/content_card.dart';
import '../../shared/widgets/content_type_carousel.dart';
import '../../shared/widgets/custom_bottom_sheet.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/genre_chip.dart';
import '../../shared/widgets/shimmer_card.dart';
import '../../shared/widgets/staggered_item.dart';
import '../collections/collections_screen.dart';
import '../content_form/content_form_screen.dart';
import 'catalog_search.dart';
import 'first_run_hint.dart';
import '../detail/content_detail_screen.dart';
import '../online_search/online_search_screen.dart';

/// Tab 1 — Catálogo: búsqueda, filtros rápidos y grid responsive.
class CatalogScreen extends ConsumerStatefulWidget {
  const CatalogScreen({super.key});

  @override
  ConsumerState<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends ConsumerState<CatalogScreen> {
  final _searchController = TextEditingController();

  /// Null mientras se comprueba la red. El aviso no aparece hasta saberlo: con
  /// el mensaje equivocado haría más daño que bien.
  bool? _online;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (ref.read(firstRunHintSeenProvider)) return;
      final online = await hasConnection();
      if (mounted) setState(() => _online = online);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _dismissHint() async {
    await ref.read(firstRunHintSeenProvider.notifier).markSeen();
  }

  @override
  Widget build(BuildContext context) {
    final asyncItems = ref.watch(contentListProvider);
    final items = ref.watch(filteredCatalogProvider);
    final filter = ref.watch(catalogFilterProvider);
    final columns = Responsive.gridColumns(context);

    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'CineLog Pro',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                fontSize: 26,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              tr('catalog.subtitle'),
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
                      const SizedBox(width: 12),
                      _HeaderIconButton(
                        icon: Icons.travel_explore_rounded,
                        tooltip: tr('catalog.searchOnline'),
                        highlighted: true,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const OnlineSearchScreen(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      _HeaderIconButton(
                        icon: Icons.add_rounded,
                        tooltip: tr('action.addContent'),
                        onTap: () => _openForm(context),
                      ),
                      const SizedBox(width: 10),
                      _HeaderIconButton(
                        icon: Icons.collections_bookmark_outlined,
                        tooltip: tr('catalog.collections'),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const CollectionsScreen(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Barra de búsqueda integrada.
                  SizedBox(
                    height: 56,
                    child: TextField(
                      controller: _searchController,
                      onChanged: (value) => ref
                          .read(catalogFilterProvider.notifier)
                          .setQuery(value),
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      ),
                      decoration: InputDecoration(
                        hintText: tr('catalog.searchHint'),
                        prefixIcon: Icon(
                          Icons.search,
                          color: AppColors.textMuted,
                        ),
                        suffixIcon: filter.query.isNotEmpty
                            ? IconButton(
                                icon: Icon(
                                  Icons.close,
                                  color: AppColors.textMuted,
                                ),
                                onPressed: () {
                                  _searchController.clear();
                                  ref
                                      .read(catalogFilterProvider.notifier)
                                      .setQuery('');
                                },
                              )
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Aviso de bienvenida: solo la primera vez, y solo cuando ya
                  // se sabe si hay red (el mensaje depende de eso).
                  if (_online != null && !ref.watch(firstRunHintSeenProvider))
                    FirstRunHint(
                      online: _online!,
                      onSearchOnline: () {
                        _dismissHint();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const OnlineSearchScreen(),
                          ),
                        );
                      },
                      onAddManually: () {
                        _dismissHint();
                        _openForm(context);
                      },
                      onDismiss: _dismissHint,
                    ),
                ],
              ),
            ),
          ),
          // Filtros: los tipos siempre a la vista, sin arrastrar nada.
          SliverToBoxAdapter(
            child: _FilterBar(
              filter: filter,
              onOpenFilters: () => _openFiltersSheet(context),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
          // Contenido: shimmer → vacío → grid.
          asyncItems.when(
            loading: () => SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 2 / 3,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) => const ShimmerCard(),
                  childCount: columns * 2,
                ),
              ),
            ),
            error: (error, stack) => SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(
                icon: Icons.error_outline,
                title: tr('common.error.title'),
                message: tr('catalog.loadError', {'error': error}),
              ),
            ),
            data: (_) => items.isEmpty
                ? SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyState(
                      imageAsset: !filter.hasActiveFilters
                          ? 'assets/img/empty/empty_box.png'
                          : (filter.type == ContentType.book ||
                                  filter.type == ContentType.manga)
                              ? 'assets/img/section/books.png'
                              : 'assets/img/empty/no_results.png',
                      icon: filter.hasActiveFilters
                          ? Icons.search_off_rounded
                          : Icons.movie_filter_outlined,
                      title: filter.hasActiveFilters
                          ? tr('catalog.empty.noResultsTitle')
                          : tr('catalog.empty.title'),
                      message: filter.hasActiveFilters
                          ? tr('catalog.empty.noResultsMsg')
                          : tr('catalog.empty.msg'),
                      actionLabel: filter.hasActiveFilters
                          ? null
                          : tr('action.addContent'),
                      onAction: filter.hasActiveFilters
                          ? null
                          : () => _openForm(context),
                    ),
                  )
                : SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
                    sliver: SliverGrid(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        childAspectRatio: 2 / 3,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final item = items[index];
                          return StaggeredItem(
                            index: index,
                            child: ContentCard(
                              item: item,
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      ContentDetailScreen(contentId: item.id),
                                ),
                              ),
                              onLongPress: () =>
                                  showContentActionsSheet(context, ref, item),
                            ),
                          );
                        },
                        childCount: items.length,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  void _openForm(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ContentFormScreen()),
    );
  }

  /// Una sola hoja para lo que no cabe fuera: género y orden. Antes eran dos
  /// chips distintos en el carrusel; juntarlos deja una sola puerta y libera
  /// la fila de tipos.
  void _openFiltersSheet(BuildContext context) {
    showAppBottomSheet<void>(
      context: context,
      title: tr('filters.title'),
      builder: (sheetContext, controller) {
        // Se lee dentro del builder para que la hoja se repinte al elegir sin
        // tener que cerrarla y volver a abrirla.
        return Consumer(
          builder: (context, ref, _) {
            final filter = ref.watch(catalogFilterProvider);
            final notifier = ref.read(catalogFilterProvider.notifier);

            // Sin búsqueda escrita, "Relevancia" no ordena por nada: se llama
            // por lo que hace de verdad, enseñar lo último que añadiste.
            final relevanceLabel = filter.query.trim().isEmpty
                ? tr('sort.recent')
                : tr('sort.relevance');

            return ListView(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              children: [
                _sheetSection(tr('filters.sortBy')),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final sort in CatalogSort.values)
                      GenreChip(
                        label: sort == CatalogSort.relevance
                            ? relevanceLabel
                            : sort.label,
                        selected: filter.sort == sort,
                        onTap: () => notifier.setSort(sort),
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                _sheetSection(tr('filters.genre')),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    GenreChip(
                      label: tr('filters.all'),
                      selected: filter.genre == null,
                      onTap: () => notifier.setGenre(null),
                    ),
                    for (final genre in kGenres)
                      GenreChip(
                        label: localizedGenre(genre),
                        selected: filter.genre == genre,
                        onTap: () => notifier
                            .setGenre(filter.genre == genre ? null : genre),
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                SecondaryButton(
                  label: tr('filters.seeResults'),
                  isFullWidth: true,
                  onTap: () => Navigator.of(sheetContext).pop(),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _sheetSection(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      );
}

/// Botón de icono para la cabecera (48dp). Con [highlighted] se tiñe de rojo
/// para destacar la acción de búsqueda online.
class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool highlighted;
  final VoidCallback onTap;

  const _HeaderIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: highlighted
            ? AppColors.primary.withValues(alpha: 0.14)
            : AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: highlighted ? AppColors.primary : AppColors.border,
              ),
            ),
            child: Icon(
              icon,
              size: 24,
              color: highlighted ? AppColors.primary : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

/// Barra de filtros del catálogo.
///
/// Los seis tipos van en un [Wrap] y no en un carrusel: son pocos y fijos, así
/// que caben enteros y se cambian de un toque. Lo que sí crece —géneros y
/// orden— se recoge tras un botón, y lo que tengas puesto se ve abajo con su
/// aspa para quitarlo sin entrar a ningún sitio.
class _FilterBar extends ConsumerWidget {
  final CatalogFilter filter;
  final VoidCallback onOpenFilters;

  const _FilterBar({required this.filter, required this.onOpenFilters});

  /// Filtros escondidos tras el botón. El tipo y favoritos no cuentan: se ven.
  int get _hiddenCount =>
      (filter.genre != null ? 1 : 0) +
      (filter.sort != CatalogSort.relevance ? 1 : 0);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(catalogFilterProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Sin Padding alrededor: el carrusel pone el suyo dentro para poder
        // arrastrarse de borde a borde en vez de quedarse en una caja.
        ContentTypeCarousel(
          types: ContentType.values,
          selected: filter.type,
          onSelect: notifier.setType,
          includeAll: true,
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _FilterButton(
                    icon: Icons.tune,
                    label: tr('filters.title'),
                    badge: _hiddenCount,
                    onTap: onOpenFilters,
                  ),
                  const SizedBox(width: 10),
                  _FilterButton(
                    icon: filter.onlyFavorites
                        ? Icons.favorite_rounded
                        : Icons.favorite_outline_rounded,
                    label: tr('filters.favorites'),
                    active: filter.onlyFavorites,
                    onTap: notifier.toggleFavorites,
                  ),
                ],
              ),
              if (_hiddenCount > 0) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (filter.genre != null)
                      _ActiveFilterChip(
                        label: localizedGenre(filter.genre!),
                        onRemove: () => notifier.setGenre(null),
                      ),
                    if (filter.sort != CatalogSort.relevance)
                      _ActiveFilterChip(
                        label: filter.sort.label,
                        onRemove: () => notifier.setSort(CatalogSort.relevance),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Botón de la fila de acciones. Con [badge] > 0 muestra cuántos filtros hay
/// puestos ahí dentro, que si no no se enterarían.
class _FilterButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final int badge;
  final bool active;
  final VoidCallback onTap;

  const _FilterButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.badge = 0,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    final on = active || badge > 0;
    final accent = on ? AppColors.primary : AppColors.textSecondary;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: on
              ? AppColors.primary.withValues(alpha: 0.14)
              : AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: on ? AppColors.primary : AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: accent),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: accent,
              ),
            ),
            if (badge > 0) ...[
              const SizedBox(width: 8),
              Container(
                width: 18,
                height: 18,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$badge',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
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

/// Filtro puesto, con su aspa para quitarlo de un toque.
class _ActiveFilterChip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;

  const _ActiveFilterChip({required this.label, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onRemove,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 6, 8, 6),
        decoration: BoxDecoration(
          color: AppColors.secondary.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.secondary.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.secondary,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.close, size: 14, color: AppColors.secondary),
          ],
        ),
      ),
    );
  }
}
