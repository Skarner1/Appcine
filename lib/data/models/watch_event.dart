/// Un visionado concreto: cuándo fue y cuánto se vio.
///
/// El diario ([ContentItem.watchLog]) es la fuente de verdad de *cuándo* se vio
/// algo. `watchDate` no vale para eso por dos motivos: guarda una sola fecha
/// (así que las repeticiones se amontonaban todas en el mismo día) y además se
/// reutiliza para programar visionados futuros.
class WatchEvent {
  /// Momento del visionado.
  final DateTime date;

  /// Minutos vistos en esta sesión. Se guardan en vez de recalcularlos desde la
  /// duración del ítem para que el historial no cambie si luego corriges esa
  /// duración.
  final int minutes;

  /// Episodios vistos en esta sesión. Null en películas y demás tipos sin
  /// episodios.
  final int? episodes;

  const WatchEvent({
    required this.date,
    required this.minutes,
    this.episodes,
  });

  /// Día natural del visionado, sin hora. Es la clave para rachas y calendario.
  DateTime get day => DateTime(date.year, date.month, date.day);

  WatchEvent copyWith({
    DateTime? date,
    int? minutes,
    int? episodes,
    bool clearEpisodes = false,
  }) {
    return WatchEvent(
      date: date ?? this.date,
      minutes: minutes ?? this.minutes,
      episodes: clearEpisodes ? null : (episodes ?? this.episodes),
    );
  }

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'minutes': minutes,
        'episodes': episodes,
      };

  factory WatchEvent.fromJson(Map<String, dynamic> json) => WatchEvent(
        date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
        minutes: (json['minutes'] as num?)?.toInt() ?? 0,
        episodes: (json['episodes'] as num?)?.toInt(),
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WatchEvent &&
          other.date == date &&
          other.minutes == minutes &&
          other.episodes == episodes;

  @override
  int get hashCode => Object.hash(date, minutes, episodes);

  @override
  String toString() =>
      'WatchEvent(${date.toIso8601String()}, ${minutes}min, ep: $episodes)';
}
