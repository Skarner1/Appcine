import 'package:hive/hive.dart';

import 'content_item.dart';
import 'watch_event.dart';

/// TypeAdapter manual de [WatchEvent] (typeId 2), sin build_runner.
class WatchEventAdapter extends TypeAdapter<WatchEvent> {
  @override
  final int typeId = 2;

  @override
  WatchEvent read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };

    return WatchEvent(
      date: fields[0] as DateTime? ?? DateTime.now(),
      minutes: fields[1] as int? ?? 0,
      episodes: fields[2] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, WatchEvent obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.date)
      ..writeByte(1)
      ..write(obj.minutes)
      ..writeByte(2)
      ..write(obj.episodes);
  }
}

/// TypeAdapter manual de [ContentItem] (typeId 1), sin build_runner.
/// Los enums se guardan como índice; las fechas como DateTime nativo de Hive.
class ContentItemAdapter extends TypeAdapter<ContentItem> {
  @override
  final int typeId = 1;

  @override
  ContentItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };

    T enumFromIndex<T extends Enum>(List<T> values, dynamic index, T fallback) {
      if (index is int && index >= 0 && index < values.length) {
        return values[index];
      }
      return fallback;
    }

    return ContentItem(
      id: fields[0] as String,
      title: fields[1] as String,
      type: enumFromIndex(ContentType.values, fields[2], ContentType.movie),
      genres: (fields[3] as List?)?.cast<String>() ?? const [],
      durationMinutes: fields[4] as int? ?? 0,
      episodes: fields[5] as int?,
      currentEpisode: fields[6] as int?,
      status:
          enumFromIndex(WatchStatus.values, fields[7], WatchStatus.notStarted),
      userRating: (fields[8] as num?)?.toDouble(),
      personalNote: fields[9] as String?,
      posterUrl: fields[10] as String?,
      watchDate: fields[11] as DateTime?,
      releaseDate: fields[12] as DateTime?,
      addedAt: fields[13] as DateTime? ?? DateTime.now(),
      source: enumFromIndex(ContentSource.values, fields[14], ContentSource.own),
      recommendedBy: fields[15] as String?,
      recommendedNote: fields[16] as String?,
      notifyMe: fields[17] as bool? ?? false,
      notificationDate: fields[18] as DateTime?,
      rewatchCount: fields[19] as int?,
      isFavorite: fields[20] as bool? ?? false,
      // Campo nuevo: los registros escritos antes del diario no lo traen y se
      // quedan con la lista vacía. El backfill lo hace migrateWatchLog().
      watchLog: (fields[21] as List?)?.cast<WatchEvent>() ?? const [],
    );
  }

  @override
  void write(BinaryWriter writer, ContentItem obj) {
    writer
      ..writeByte(22)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.type.index)
      ..writeByte(3)
      ..write(obj.genres)
      ..writeByte(4)
      ..write(obj.durationMinutes)
      ..writeByte(5)
      ..write(obj.episodes)
      ..writeByte(6)
      ..write(obj.currentEpisode)
      ..writeByte(7)
      ..write(obj.status.index)
      ..writeByte(8)
      ..write(obj.userRating)
      ..writeByte(9)
      ..write(obj.personalNote)
      ..writeByte(10)
      ..write(obj.posterUrl)
      ..writeByte(11)
      ..write(obj.watchDate)
      ..writeByte(12)
      ..write(obj.releaseDate)
      ..writeByte(13)
      ..write(obj.addedAt)
      ..writeByte(14)
      ..write(obj.source.index)
      ..writeByte(15)
      ..write(obj.recommendedBy)
      ..writeByte(16)
      ..write(obj.recommendedNote)
      ..writeByte(17)
      ..write(obj.notifyMe)
      ..writeByte(18)
      ..write(obj.notificationDate)
      ..writeByte(19)
      ..write(obj.rewatchCount)
      ..writeByte(20)
      ..write(obj.isFavorite)
      ..writeByte(21)
      ..write(obj.watchLog);
  }
}
