import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../models/content_item.dart';
import 'backup_service.dart';

/// Cada cuánto se hace la copia silenciosa.
enum BackupFrequency { daily, weekly }

extension BackupFrequencyX on BackupFrequency {
  String get label => switch (this) {
        BackupFrequency.daily => 'A diario',
        BackupFrequency.weekly => 'Semanal',
      };

  Duration get interval => switch (this) {
        BackupFrequency.daily => const Duration(days: 1),
        BackupFrequency.weekly => const Duration(days: 7),
      };
}

/// Una copia automática que existe en el disco.
class AutoBackup {
  final String path;
  final DateTime date;
  final int sizeBytes;

  const AutoBackup({
    required this.path,
    required this.date,
    required this.sizeBytes,
  });
}

/// Copias de seguridad automáticas en el propio móvil.
///
/// La copia manual protege del "se me perdió el móvil"; esta protege de lo que
/// pasa mucho más a menudo: vaciar el catálogo sin querer, un import que sale
/// mal o que Hive se corrompa. Vive en el almacenamiento privado de la app, así
/// que **no** sobrevive a desinstalarla: para eso está la copia manual.
class AutoBackupService {
  AutoBackupService({BackupService? backup, Directory? directory})
      : _backup = backup ?? const BackupService(),
        _directory = directory;

  final BackupService _backup;
  Directory? _directory;

  /// Copias que se conservan. Con más de esto, las viejas ya no dicen nada.
  static const keepCount = 5;

  static final _namePattern =
      RegExp(r'^cinelog_auto_(\d{4})-(\d{2})-(\d{2})_(\d{2})(\d{2})\.json$');

  Future<Directory> _dir() async {
    final cached = _directory;
    if (cached != null) return cached;
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/backups');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    _directory = dir;
    return dir;
  }

  static String _two(int n) => n.toString().padLeft(2, '0');

  static String fileNameFor(DateTime date) =>
      'cinelog_auto_${date.year}-${_two(date.month)}-${_two(date.day)}_'
      '${_two(date.hour)}${_two(date.minute)}.json';

  /// Saca la fecha del nombre del archivo, o null si no es una copia nuestra.
  static DateTime? dateFromName(String fileName) {
    final m = _namePattern.firstMatch(fileName);
    if (m == null) return null;
    return DateTime(
      int.parse(m.group(1)!),
      int.parse(m.group(2)!),
      int.parse(m.group(3)!),
      int.parse(m.group(4)!),
      int.parse(m.group(5)!),
    );
  }

  /// ¿Toca copia? Puro y sin disco de por medio, que es lo que hay que probar.
  ///
  /// Sin copias previas toca siempre: la primera es la que más falta hace.
  static bool shouldRun({
    required bool enabled,
    required DateTime? lastRun,
    required BackupFrequency frequency,
    required bool hasContent,
    required DateTime now,
  }) {
    if (!enabled) return false;
    // Copiar un catálogo vacío solo serviría para pisar las copias buenas.
    if (!hasContent) return false;
    if (lastRun == null) return true;
    // Un reloj movido hacia atrás no debe dejar la copia congelada para siempre.
    if (lastRun.isAfter(now)) return true;
    return now.difference(lastRun) >= frequency.interval;
  }

  /// Escribe una copia y tira las sobrantes. Devuelve la ruta, o null si falló
  /// (nunca lanza: es una tarea de fondo, no puede tumbar la app).
  Future<String?> run(List<ContentItem> items, {DateTime? now}) async {
    try {
      final dir = await _dir();
      final file = File('${dir.path}/${fileNameFor(now ?? DateTime.now())}');
      await file.writeAsString(_backup.encode(items));
      await _rotate();
      return file.path;
    } catch (_) {
      return null;
    }
  }

  /// Copias que hay ahora mismo, de la más reciente a la más antigua.
  Future<List<AutoBackup>> list() async {
    try {
      final dir = await _dir();
      if (!dir.existsSync()) return [];

      final backups = <AutoBackup>[];
      for (final entity in dir.listSync()) {
        if (entity is! File) continue;
        final name = entity.uri.pathSegments.last;
        final date = dateFromName(name);
        if (date == null) continue;
        backups.add(AutoBackup(
          path: entity.path,
          date: date,
          sizeBytes: entity.lengthSync(),
        ));
      }

      backups.sort((a, b) => b.date.compareTo(a.date));
      return backups;
    } catch (_) {
      return [];
    }
  }

  /// Lee una copia. Lanza [FormatException] si está dañada.
  Future<List<ContentItem>> read(String path) async {
    final raw = await File(path).readAsString();
    return _backup.decode(raw);
  }

  Future<void> _rotate() async {
    final backups = await list();
    for (final old in backups.skip(keepCount)) {
      try {
        await File(old.path).delete();
      } catch (_) {}
    }
  }
}

final autoBackupServiceProvider =
    Provider<AutoBackupService>((ref) => AutoBackupService());
