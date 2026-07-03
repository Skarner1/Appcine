import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../core/services/notification_service.dart';
import '../data/models/content_item.dart';
import '../data/repositories/content_repository.dart';

/// Repositorio de contenido. Se inyecta ya inicializado desde main().
final contentRepositoryProvider = Provider<ContentRepository>(
  (ref) => throw UnimplementedError('Override en main()'),
);

/// Box de ajustes (nombre de perfil, flags). Se inyecta desde main().
final settingsBoxProvider = Provider<Box<dynamic>>(
  (ref) => throw UnimplementedError('Override en main()'),
);

/// Lista completa del catálogo, reactiva a los cambios en Hive.
final contentListProvider = StreamProvider<List<ContentItem>>((ref) {
  return ref.watch(contentRepositoryProvider).watchAll();
});

/// Un elemento puntual por id (reactivo).
final contentByIdProvider =
    Provider.family<ContentItem?, String>((ref, id) {
  final items = ref.watch(contentListProvider).value ?? const <ContentItem>[];
  for (final item in items) {
    if (item.id == id) return item;
  }
  return null;
});

// ---------------------------------------------------------------------------
// Catálogo: búsqueda y filtros
// ---------------------------------------------------------------------------

class CatalogFilter {
  final String query;
  final ContentType? type; // null = Todo
  final String? genre; // null = todos los géneros
  final bool onlyFavorites;

  const CatalogFilter({
    this.query = '',
    this.type,
    this.genre,
    this.onlyFavorites = false,
  });

  bool get hasActiveFilters =>
      query.isNotEmpty || type != null || genre != null || onlyFavorites;

  CatalogFilter copyWith({
    String? query,
    ContentType? type,
    String? genre,
    bool? onlyFavorites,
    bool clearType = false,
    bool clearGenre = false,
  }) {
    return CatalogFilter(
      query: query ?? this.query,
      type: clearType ? null : (type ?? this.type),
      genre: clearGenre ? null : (genre ?? this.genre),
      onlyFavorites: onlyFavorites ?? this.onlyFavorites,
    );
  }
}

class CatalogFilterNotifier extends Notifier<CatalogFilter> {
  @override
  CatalogFilter build() => const CatalogFilter();

  void setQuery(String query) => state = state.copyWith(query: query);

  void setType(ContentType? type) => state = type == null
      ? state.copyWith(clearType: true)
      : state.copyWith(type: type);

  void setGenre(String? genre) => state = genre == null
      ? state.copyWith(clearGenre: true)
      : state.copyWith(genre: genre);

  void toggleFavorites() =>
      state = state.copyWith(onlyFavorites: !state.onlyFavorites);

  void clear() => state = const CatalogFilter();
}

final catalogFilterProvider =
    NotifierProvider<CatalogFilterNotifier, CatalogFilter>(
  CatalogFilterNotifier.new,
);

/// Catálogo filtrado por búsqueda, tipo, género y favoritos.
final filteredCatalogProvider = Provider<List<ContentItem>>((ref) {
  final items = ref.watch(contentListProvider).value ?? const <ContentItem>[];
  final filter = ref.watch(catalogFilterProvider);

  return items.where((item) {
    if (filter.type != null && item.type != filter.type) return false;
    if (filter.genre != null && !item.genres.contains(filter.genre)) {
      return false;
    }
    if (filter.onlyFavorites && !item.isFavorite) return false;
    if (filter.query.isNotEmpty) {
      final query = filter.query.toLowerCase();
      final inTitle = item.title.toLowerCase().contains(query);
      final inGenres =
          item.genres.any((g) => g.toLowerCase().contains(query));
      if (!inTitle && !inGenres) return false;
    }
    return true;
  }).toList();
});

// ---------------------------------------------------------------------------
// Por Ver (watchlist)
// ---------------------------------------------------------------------------

enum WatchlistTab { pending, rewatch, seen }

extension WatchlistTabX on WatchlistTab {
  String get label => switch (this) {
        WatchlistTab.pending => 'Falta Ver',
        WatchlistTab.rewatch => 'Volver a Ver',
        WatchlistTab.seen => 'Vistos',
      };
}

final watchlistItemsProvider =
    Provider.family<List<ContentItem>, WatchlistTab>((ref, tab) {
  final items = ref.watch(contentListProvider).value ?? const <ContentItem>[];

  List<ContentItem> result = switch (tab) {
    WatchlistTab.pending => items
        .where((i) =>
            i.status == WatchStatus.notStarted ||
            i.status == WatchStatus.watching ||
            i.status == WatchStatus.onHold)
        .toList(),
    WatchlistTab.rewatch =>
      items.where((i) => i.status == WatchStatus.rewatchPending).toList(),
    WatchlistTab.seen =>
      items.where((i) => i.status == WatchStatus.completed).toList(),
  };

  if (tab == WatchlistTab.pending) {
    // Viendo primero, luego por fecha programada más próxima.
    int weight(ContentItem i) => switch (i.status) {
          WatchStatus.watching => 0,
          WatchStatus.notStarted => 1,
          _ => 2,
        };
    result.sort((a, b) {
      final byStatus = weight(a).compareTo(weight(b));
      if (byStatus != 0) return byStatus;
      final aDate = a.watchDate;
      final bDate = b.watchDate;
      if (aDate != null && bDate != null) return aDate.compareTo(bDate);
      if (aDate != null) return -1;
      if (bDate != null) return 1;
      return b.addedAt.compareTo(a.addedAt);
    });
  } else if (tab == WatchlistTab.seen) {
    result.sort((a, b) {
      final aDate = a.watchDate ?? a.addedAt;
      final bDate = b.watchDate ?? b.addedAt;
      return bDate.compareTo(aDate);
    });
  }
  return result;
});

// ---------------------------------------------------------------------------
// Recomendaciones
// ---------------------------------------------------------------------------

enum RecommendationTab { friends, system, trending }

extension RecommendationTabX on RecommendationTab {
  String get label => switch (this) {
        RecommendationTab.friends => 'Amigos',
        RecommendationTab.system => 'Sistema',
        RecommendationTab.trending => 'Tendencias',
      };
}

final recommendationsProvider =
    Provider.family<List<ContentItem>, RecommendationTab>((ref, tab) {
  final items = ref.watch(contentListProvider).value ?? const <ContentItem>[];
  final source = switch (tab) {
    RecommendationTab.friends => ContentSource.friendRecommended,
    RecommendationTab.system => ContentSource.algorithm,
    RecommendationTab.trending => ContentSource.trending,
  };
  return items.where((i) => i.source == source).toList();
});

// ---------------------------------------------------------------------------
// Estadísticas del perfil
// ---------------------------------------------------------------------------

class ProfileStats {
  final int totalItems;
  final int completedCount;
  final int pendingCount;
  final int favoriteCount;
  final int totalWatchedMinutes;
  final Map<ContentType, int> byType;
  final List<MapEntry<String, int>> topGenres;
  final int streakDays;

  const ProfileStats({
    required this.totalItems,
    required this.completedCount,
    required this.pendingCount,
    required this.favoriteCount,
    required this.totalWatchedMinutes,
    required this.byType,
    required this.topGenres,
    required this.streakDays,
  });
}

final profileStatsProvider = Provider<ProfileStats>((ref) {
  final items = ref.watch(contentListProvider).value ?? const <ContentItem>[];

  final byType = <ContentType, int>{};
  final byGenre = <String, int>{};
  var completed = 0;
  var pending = 0;
  var favorites = 0;
  var watchedMinutes = 0;
  final watchedDays = <DateTime>{};

  for (final item in items) {
    byType[item.type] = (byType[item.type] ?? 0) + 1;
    for (final genre in item.genres) {
      byGenre[genre] = (byGenre[genre] ?? 0) + 1;
    }
    if (item.status == WatchStatus.completed ||
        item.status == WatchStatus.rewatchPending) {
      completed++;
    }
    if (item.status == WatchStatus.notStarted ||
        item.status == WatchStatus.watching) {
      pending++;
    }
    if (item.isFavorite) favorites++;
    watchedMinutes += item.watchedMinutes;

    final watchDate = item.watchDate;
    if (watchDate != null &&
        (item.status == WatchStatus.completed ||
            item.status == WatchStatus.rewatchPending) &&
        !watchDate.isAfter(DateTime.now())) {
      watchedDays
          .add(DateTime(watchDate.year, watchDate.month, watchDate.day));
    }
  }

  final genresSorted = byGenre.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  // Racha: días consecutivos con al menos un visionado, contando hacia atrás
  // desde hoy (o ayer, para no romper la racha antes de terminar el día).
  var streak = 0;
  final now = DateTime.now();
  var cursor = DateTime(now.year, now.month, now.day);
  if (!watchedDays.contains(cursor)) {
    cursor = cursor.subtract(const Duration(days: 1));
  }
  while (watchedDays.contains(cursor)) {
    streak++;
    cursor = cursor.subtract(const Duration(days: 1));
  }

  return ProfileStats(
    totalItems: items.length,
    completedCount: completed,
    pendingCount: pending,
    favoriteCount: favorites,
    totalWatchedMinutes: watchedMinutes,
    byType: byType,
    topGenres: genresSorted.take(5).toList(),
    streakDays: streak,
  );
});

// ---------------------------------------------------------------------------
// Notificaciones programadas
// ---------------------------------------------------------------------------

/// Contenido con recordatorio activo, ordenado por fecha.
final scheduledNotificationsProvider = Provider<List<ContentItem>>((ref) {
  final items = ref.watch(contentListProvider).value ?? const <ContentItem>[];
  final scheduled = items
      .where((i) => i.notifyMe && i.notificationDate != null)
      .toList()
    ..sort((a, b) => a.notificationDate!.compareTo(b.notificationDate!));
  return scheduled;
});

// ---------------------------------------------------------------------------
// Perfil: nombre de usuario
// ---------------------------------------------------------------------------

class ProfileNameNotifier extends Notifier<String> {
  static const _key = 'profile_name';

  @override
  String build() {
    final box = ref.watch(settingsBoxProvider);
    return box.get(_key, defaultValue: 'Cinéfilo') as String;
  }

  Future<void> setName(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    await ref.read(settingsBoxProvider).put(_key, trimmed);
    state = trimmed;
  }
}

final profileNameProvider =
    NotifierProvider<ProfileNameNotifier, String>(ProfileNameNotifier.new);

// ---------------------------------------------------------------------------
// Acciones sobre contenido (guardar + sincronizar notificaciones)
// ---------------------------------------------------------------------------

/// Guarda un item y sincroniza su recordatorio con el sistema.
class ContentActions {
  ContentActions(this._ref);

  final Ref _ref;

  ContentRepository get _repo => _ref.read(contentRepositoryProvider);

  Future<void> save(ContentItem item) async {
    await _repo.save(item);
    await _syncNotification(item);
  }

  Future<void> delete(ContentItem item) async {
    await NotificationService.instance.cancelForContent(item.id);
    await _repo.delete(item.id);
  }

  Future<void> _syncNotification(ContentItem item) async {
    final service = NotificationService.instance;
    if (item.notifyMe &&
        item.notificationDate != null &&
        item.notificationDate!.isAfter(DateTime.now())) {
      await service.requestPermissions();
      await service.scheduleWatchReminder(item);
    } else {
      await service.cancelForContent(item.id);
    }
  }

  /// Marca como visto: completa episodios, fija fecha y cancela recordatorio.
  Future<void> markCompleted(ContentItem item) async {
    final wasSeen = item.status == WatchStatus.completed ||
        item.status == WatchStatus.rewatchPending;
    await save(item.copyWith(
      status: WatchStatus.completed,
      currentEpisode: item.type.hasEpisodes ? item.episodes : null,
      watchDate: DateTime.now(),
      rewatchCount:
          wasSeen ? (item.rewatchCount ?? 0) + 1 : item.rewatchCount,
      notifyMe: false,
      clearNotificationDate: true,
    ));
  }

  Future<void> markPending(ContentItem item) async {
    await save(item.copyWith(status: WatchStatus.notStarted));
  }

  Future<void> toggleFavorite(ContentItem item) async {
    await save(item.copyWith(isFavorite: !item.isFavorite));
  }

  /// Pospone el recordatorio la duración indicada (default 1 hora).
  Future<void> snooze(ContentItem item,
      [Duration delay = const Duration(hours: 1)]) async {
    final base = item.notificationDate ?? DateTime.now();
    final from = base.isAfter(DateTime.now()) ? base : DateTime.now();
    await save(item.copyWith(
      notifyMe: true,
      notificationDate: from.add(delay),
    ));
  }

  Future<void> dismissNotification(ContentItem item) async {
    await save(item.copyWith(notifyMe: false, clearNotificationDate: true));
  }
}

final contentActionsProvider = Provider<ContentActions>(ContentActions.new);
