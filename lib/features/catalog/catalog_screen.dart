import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/content_item.dart';
import '../../providers/providers.dart';
import '../../shared/widgets/content_card.dart';
import '../../shared/widgets/custom_bottom_sheet.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/genre_chip.dart';
import '../../shared/widgets/shimmer_card.dart';
import '../../shared/widgets/staggered_item.dart';
import '../collections/collections_screen.dart';
import '../content_form/content_form_screen.dart';
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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
                              'Tu catálogo personal de cine y series',
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
                        tooltip: 'Buscar en internet',
                        highlighted: true,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const OnlineSearchScreen(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      _HeaderIconButton(
                        icon: Icons.collections_bookmark_outlined,
                        tooltip: 'Colecciones',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const CollectionsScreen(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      _FavoritesToggle(
                        active: filter.onlyFavorites,
                        onTap: () => ref
                            .read(catalogFilterProvider.notifier)
                            .toggleFavorites(),
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
                        hintText: 'Buscar por título o género…',
                        prefixIcon: const Icon(
                          Icons.search,
                          color: AppColors.textMuted,
                        ),
                        suffixIcon: filter.query.isNotEmpty
                            ? IconButton(
                                icon: const Icon(
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
                ],
              ),
            ),
          ),
          // Chips de filtro rápido por tipo + filtro de género.
          SliverToBoxAdapter(
            child: SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GenreChip(
                      label: 'Todo',
                      selected: filter.type == null,
                      onTap: () =>
                          ref.read(catalogFilterProvider.notifier).setType(null),
                    ),
                  ),
                  for (final type in ContentType.values)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GenreChip(
                        label: type.pluralLabel,
                        icon: type.icon,
                        selected: filter.type == type,
                        onTap: () => ref
                            .read(catalogFilterProvider.notifier)
                            .setType(filter.type == type ? null : type),
                      ),
                    ),
                  GenreChip(
                    label: filter.genre ?? 'Género',
                    icon: Icons.tune,
                    selected: filter.genre != null,
                    onTap: () => _openGenreSheet(context),
                  ),
                ],
              ),
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
                title: 'Algo salió mal',
                message: 'No pudimos cargar tu catálogo: $error',
              ),
            ),
            data: (_) => items.isEmpty
                ? SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyState(
                      icon: filter.hasActiveFilters
                          ? Icons.search_off_rounded
                          : Icons.movie_filter_outlined,
                      title: filter.hasActiveFilters
                          ? 'Sin resultados'
                          : 'Tu catálogo está vacío',
                      message: filter.hasActiveFilters
                          ? 'Prueba con otros filtros o términos de búsqueda.'
                          : 'Agrega tu primera película o serie y empieza a organizar tu cine.',
                      actionLabel:
                          filter.hasActiveFilters ? null : 'Agregar contenido',
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

  void _openGenreSheet(BuildContext context) {
    final current = ref.read(catalogFilterProvider).genre;
    showAppBottomSheet<void>(
      context: context,
      title: 'Filtrar por género',
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.all(20),
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              GenreChip(
                label: 'Todos',
                selected: current == null,
                onTap: () {
                  ref.read(catalogFilterProvider.notifier).setGenre(null);
                  Navigator.of(context).pop();
                },
              ),
              for (final genre in kGenres)
                GenreChip(
                  label: genre,
                  selected: current == genre,
                  onTap: () {
                    ref
                        .read(catalogFilterProvider.notifier)
                        .setGenre(current == genre ? null : genre);
                    Navigator.of(context).pop();
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }
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

class _FavoritesToggle extends StatelessWidget {
  final bool active;
  final VoidCallback onTap;

  const _FavoritesToggle({required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: active
              ? AppColors.primary.withValues(alpha: 0.18)
              : AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: active ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Icon(
          active ? Icons.favorite_rounded : Icons.favorite_outline_rounded,
          color: active ? AppColors.primary : AppColors.textSecondary,
          size: 24,
        ),
      ),
    );
  }
}
