import 'models/content_item.dart';
import 'models/watch_event.dart';

/// Clave del flag de migración del diario en el box de ajustes.
const migratedWatchLogKey = 'watchlog_migrated';

bool _isWatched(ContentItem item) =>
    item.status == WatchStatus.completed ||
    item.status == WatchStatus.rewatchPending;

/// Rellena el diario de los ítems guardados antes de que existiera, a partir de
/// `watchDate` + `watchedMinutes`.
///
/// Crea **un solo evento** por ítem aunque tenga repeticiones: solo hay una
/// fecha guardada, así que repartirlo en varios eventos sería inventarse cuándo
/// ocurrieron. Con un único evento que suma todos los minutos, las cifras que la
/// app ya mostraba no se mueven, y a partir de ahora los visionados nuevos sí se
/// anotan uno a uno.
///
/// Se salta los que ya tienen diario, los no vistos, los que no tienen fecha y
/// los de fecha futura (ahí `watchDate` significa "planeo verlo", no "lo vi").
/// Devuelve solo los ítems que hay que reescribir.
List<ContentItem> migrateWatchLog(
  Iterable<ContentItem> items, {
  DateTime? now,
}) {
  final today = now ?? DateTime.now();
  final migrated = <ContentItem>[];

  for (final item in items) {
    if (item.watchLog.isNotEmpty) continue;
    if (!_isWatched(item)) continue;

    final watchedAt = item.watchDate;
    if (watchedAt == null || watchedAt.isAfter(today)) continue;

    final minutes = item.watchedMinutes;
    if (minutes <= 0) continue;

    migrated.add(item.copyWith(
      watchLog: [
        WatchEvent(
          date: watchedAt,
          minutes: minutes,
          episodes: item.type.hasEpisodes
              ? (item.episodes ?? item.currentEpisode)
              : null,
        ),
      ],
    ));
  }

  return migrated;
}
