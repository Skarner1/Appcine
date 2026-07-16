import 'package:flutter/material.dart';

import '../../core/l10n/strings.dart';
import '../../core/theme/app_colors.dart';
import 'watch_event.dart';

/// Tipos de contenido del catálogo.
///
/// Los valores nuevos van SIEMPRE al final: Hive los guarda por índice, así que
/// reordenarlos convertiría las películas de todo el mundo en otra cosa.
enum ContentType { movie, series, documentary, anime, shortFilm, book, manga }

enum WatchStatus {
  notStarted, // Falta ver
  watching, // Viendo ahora
  completed, // Visto
  onHold, // Pausada
  dropped, // Abandonada
  rewatchPending, // Volver a ver
}

enum ContentSource { own, friendRecommended, trending, algorithm }

extension ContentTypeX on ContentType {
  String get label => tr('type.$name');

  String get pluralLabel => tr('type.$name.plural');

  String get emoji => switch (this) {
        ContentType.movie => '🎬',
        ContentType.series => '📺',
        ContentType.documentary => '🎞️',
        ContentType.anime => '🌸',
        ContentType.shortFilm => '⏱️',
        ContentType.book => '📖',
        ContentType.manga => '📙',
      };

  IconData get icon => switch (this) {
        ContentType.movie => Icons.movie_outlined,
        ContentType.series => Icons.live_tv_outlined,
        ContentType.documentary => Icons.camera_roll_outlined,
        ContentType.anime => Icons.animation_outlined,
        ContentType.shortFilm => Icons.timelapse_outlined,
        ContentType.book => Icons.menu_book_outlined,
        ContentType.manga => Icons.auto_stories_outlined,
      };

  /// Tipos que se llevan por partes numeradas y guardan progreso: episodios en
  /// series y anime, tomos en libros y mangas. Unos y otros comparten los campos
  /// `episodes` / `currentEpisode`; lo que cambia es cómo se llaman de cara al
  /// usuario (ver [unitLabel]).
  bool get hasEpisodes =>
      this == ContentType.series ||
      this == ContentType.anime ||
      this == ContentType.book ||
      this == ContentType.manga;

  /// Cómo se llama cada parte en este tipo. Un manga tiene tomos, no episodios.
  String get unitLabel => switch (this) {
        ContentType.book || ContentType.manga => tr('unit.volume'),
        _ => tr('unit.episode'),
      };

  String get unitsLabel => switch (this) {
        ContentType.book || ContentType.manga => tr('unit.volumes'),
        _ => tr('unit.episodes'),
      };

  /// Lo que se lee no se "ve". Cambia los verbos de la interfaz.
  bool get isRead => this == ContentType.book || this == ContentType.manga;
}

extension WatchStatusX on WatchStatus {
  String get label => tr('status.$name');

  Color get color => switch (this) {
        WatchStatus.notStarted => AppColors.warning,
        WatchStatus.watching => AppColors.secondary,
        WatchStatus.completed => AppColors.success,
        WatchStatus.onHold => AppColors.textMuted,
        WatchStatus.dropped => AppColors.error,
        WatchStatus.rewatchPending => AppColors.tertiary,
      };

  IconData get icon => switch (this) {
        WatchStatus.notStarted => Icons.schedule_outlined,
        WatchStatus.watching => Icons.play_circle_outline,
        WatchStatus.completed => Icons.check_circle_outline,
        WatchStatus.onHold => Icons.pause_circle_outline,
        WatchStatus.dropped => Icons.cancel_outlined,
        WatchStatus.rewatchPending => Icons.replay_outlined,
      };
}

extension ContentSourceX on ContentSource {
  String get label => tr('source.$name');
}

/// Elemento del catálogo: película, serie, documental, anime o corto.
class ContentItem {
  final String id; // UUID v4
  final String title;
  final ContentType type;
  final List<String> genres;
  final int durationMinutes; // Película: total. Serie: por episodio.
  final int? episodes;
  final int? currentEpisode;
  final WatchStatus status;
  final double? userRating; // 1.0 – 10.0
  final String? personalNote;
  final String? posterUrl; // URL remota o ruta local
  final DateTime? watchDate; // Fecha en que la vio / planea ver
  final DateTime? releaseDate;
  final DateTime addedAt;
  final ContentSource source;
  final String? recommendedBy;
  final String? recommendedNote;
  final bool notifyMe;
  final DateTime? notificationDate;
  final int? rewatchCount;
  final bool isFavorite;

  /// Diario de visionados, del más antiguo al más reciente. Fuente de verdad de
  /// *cuándo* se vio esto y cuánto; [watchDate] no sirve porque es una sola
  /// fecha y además se usa para programar visionados futuros.
  final List<WatchEvent> watchLog;

  const ContentItem({
    required this.id,
    required this.title,
    required this.type,
    this.genres = const [],
    this.durationMinutes = 0,
    this.episodes,
    this.currentEpisode,
    this.status = WatchStatus.notStarted,
    this.userRating,
    this.personalNote,
    this.posterUrl,
    this.watchDate,
    this.releaseDate,
    required this.addedAt,
    this.source = ContentSource.own,
    this.recommendedBy,
    this.recommendedNote,
    this.notifyMe = false,
    this.notificationDate,
    this.rewatchCount,
    this.isFavorite = false,
    this.watchLog = const [],
  });

  /// Minutos totales estimados si se completa todo el contenido.
  int get totalMinutes => type.hasEpisodes
      ? durationMinutes * (episodes ?? 0)
      : durationMinutes;

  /// Minutos ya vistos según estado y progreso.
  int get watchedMinutes {
    if (type.hasEpisodes) {
      // Terminado y sin saber cuántas partes tiene: cuenta como una. Es el caso
      // normal de un libro suelto (no tiene tomos), y antes daba cero minutos
      // aunque estuviera leído entero.
      final seen = status == WatchStatus.completed ||
              status == WatchStatus.rewatchPending
          ? (episodes ?? currentEpisode ?? 1)
          : (currentEpisode ?? 0);
      return durationMinutes * seen;
    }
    final wasSeen = status == WatchStatus.completed ||
        status == WatchStatus.rewatchPending;
    return wasSeen ? durationMinutes * ((rewatchCount ?? 0) + 1) : 0;
  }

  double? get episodeProgress {
    if (!type.hasEpisodes || episodes == null || episodes == 0) return null;
    return ((currentEpisode ?? 0) / episodes!).clamp(0.0, 1.0);
  }

  bool get isRecommendation => source == ContentSource.friendRecommended;

  /// Minutos del diario. Cuando hay diario manda él sobre [watchedMinutes]:
  /// es lo que de verdad se vio, no una estimación desde la duración actual.
  int get loggedMinutes =>
      watchLog.fold(0, (sum, event) => sum + event.minutes);

  /// Copia con el avance de visionado respecto a [previous] anotado en el
  /// diario, o este mismo ítem si no se vio nada nuevo.
  ///
  /// El evento se mide como el incremento de [watchedMinutes], que cubre por
  /// igual los dos casos: una película revista suma su duración entera y una
  /// serie suma solo el tramo de episodios nuevos.
  ContentItem logProgressSince(ContentItem previous, {DateTime? at}) {
    final minutes = watchedMinutes - previous.watchedMinutes;
    if (minutes <= 0) return this;

    final newEpisodes = type.hasEpisodes
        ? (currentEpisode ?? 0) - (previous.currentEpisode ?? 0)
        : null;

    return copyWith(
      watchLog: [
        ...watchLog,
        WatchEvent(
          date: at ?? DateTime.now(),
          minutes: minutes,
          episodes: (newEpisodes != null && newEpisodes > 0) ? newEpisodes : null,
        ),
      ],
    );
  }

  ContentItem copyWith({
    String? id,
    String? title,
    ContentType? type,
    List<String>? genres,
    int? durationMinutes,
    int? episodes,
    int? currentEpisode,
    WatchStatus? status,
    double? userRating,
    String? personalNote,
    String? posterUrl,
    DateTime? watchDate,
    DateTime? releaseDate,
    DateTime? addedAt,
    ContentSource? source,
    String? recommendedBy,
    String? recommendedNote,
    bool? notifyMe,
    DateTime? notificationDate,
    int? rewatchCount,
    bool? isFavorite,
    List<WatchEvent>? watchLog,
    bool clearEpisodes = false,
    bool clearUserRating = false,
    bool clearPersonalNote = false,
    bool clearPosterUrl = false,
    bool clearWatchDate = false,
    bool clearNotificationDate = false,
    bool clearRecommendation = false,
  }) {
    return ContentItem(
      id: id ?? this.id,
      title: title ?? this.title,
      type: type ?? this.type,
      genres: genres ?? this.genres,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      episodes: clearEpisodes ? null : (episodes ?? this.episodes),
      currentEpisode:
          clearEpisodes ? null : (currentEpisode ?? this.currentEpisode),
      status: status ?? this.status,
      userRating: clearUserRating ? null : (userRating ?? this.userRating),
      personalNote:
          clearPersonalNote ? null : (personalNote ?? this.personalNote),
      posterUrl: clearPosterUrl ? null : (posterUrl ?? this.posterUrl),
      watchDate: clearWatchDate ? null : (watchDate ?? this.watchDate),
      releaseDate: releaseDate ?? this.releaseDate,
      addedAt: addedAt ?? this.addedAt,
      source: source ?? this.source,
      recommendedBy:
          clearRecommendation ? null : (recommendedBy ?? this.recommendedBy),
      recommendedNote: clearRecommendation
          ? null
          : (recommendedNote ?? this.recommendedNote),
      notifyMe: notifyMe ?? this.notifyMe,
      notificationDate: clearNotificationDate
          ? null
          : (notificationDate ?? this.notificationDate),
      rewatchCount: rewatchCount ?? this.rewatchCount,
      isFavorite: isFavorite ?? this.isFavorite,
      watchLog: watchLog ?? this.watchLog,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'type': type.name,
        'genres': genres,
        'durationMinutes': durationMinutes,
        'episodes': episodes,
        'currentEpisode': currentEpisode,
        'status': status.name,
        'userRating': userRating,
        'personalNote': personalNote,
        'posterUrl': posterUrl,
        'watchDate': watchDate?.toIso8601String(),
        'releaseDate': releaseDate?.toIso8601String(),
        'addedAt': addedAt.toIso8601String(),
        'source': source.name,
        'recommendedBy': recommendedBy,
        'recommendedNote': recommendedNote,
        'notifyMe': notifyMe,
        'notificationDate': notificationDate?.toIso8601String(),
        'rewatchCount': rewatchCount,
        'isFavorite': isFavorite,
        'watchLog': watchLog.map((e) => e.toJson()).toList(),
      };

  factory ContentItem.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic value) =>
        value is String ? DateTime.tryParse(value) : null;

    return ContentItem(
      id: json['id'] as String,
      title: json['title'] as String,
      type: ContentType.values.asNameMap()[json['type']] ?? ContentType.movie,
      genres: (json['genres'] as List?)?.cast<String>() ?? const [],
      durationMinutes: (json['durationMinutes'] as num?)?.toInt() ?? 0,
      episodes: (json['episodes'] as num?)?.toInt(),
      currentEpisode: (json['currentEpisode'] as num?)?.toInt(),
      status: WatchStatus.values.asNameMap()[json['status']] ??
          WatchStatus.notStarted,
      userRating: (json['userRating'] as num?)?.toDouble(),
      personalNote: json['personalNote'] as String?,
      posterUrl: json['posterUrl'] as String?,
      watchDate: parseDate(json['watchDate']),
      releaseDate: parseDate(json['releaseDate']),
      addedAt: parseDate(json['addedAt']) ?? DateTime.now(),
      source:
          ContentSource.values.asNameMap()[json['source']] ?? ContentSource.own,
      recommendedBy: json['recommendedBy'] as String?,
      recommendedNote: json['recommendedNote'] as String?,
      notifyMe: json['notifyMe'] as bool? ?? false,
      notificationDate: parseDate(json['notificationDate']),
      rewatchCount: (json['rewatchCount'] as num?)?.toInt(),
      isFavorite: json['isFavorite'] as bool? ?? false,
      // Los backups y catálogos compartidos anteriores al diario no lo traen.
      watchLog: (json['watchLog'] as List?)
              ?.map((e) => WatchEvent.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          const [],
    );
  }
}
