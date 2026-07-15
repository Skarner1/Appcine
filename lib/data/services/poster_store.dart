import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../models/content_item.dart';

/// Guarda los pósters en el almacenamiento de la app para que el catálogo
/// funcione sin red.
///
/// Un `posterUrl` remoto es frágil: sin conexión no se ve, y si la URL muere se
/// pierde para siempre. Al elegir un póster de internet se copia al disco y a
/// partir de ahí el ítem ya no depende de nadie. [localizePending] repesca los
/// que quedaron con URL (contenido antiguo, catálogos importados, o descargas
/// que fallaron por estar sin cobertura).
class PosterStore {
  PosterStore({http.Client? client, Directory? directory})
      : _client = client ?? http.Client(),
        _directory = directory;

  final http.Client _client;
  Directory? _directory;

  /// Tamaño máximo aceptado (4 MB). Evita llenar el móvil si una URL apunta a
  /// algo que no es un póster.
  static const maxBytes = 4 * 1024 * 1024;

  static const _extensionByMimeType = {
    'image/jpeg': '.jpg',
    'image/png': '.png',
    'image/webp': '.webp',
    'image/gif': '.gif',
  };

  /// True si [posterUrl] apunta a un archivo del móvil (no a la red).
  static bool isLocal(String? posterUrl) =>
      posterUrl != null && posterUrl.isNotEmpty && !posterUrl.startsWith('http');

  /// True si [posterUrl] todavía depende de la red.
  static bool isRemote(String? posterUrl) =>
      posterUrl != null && posterUrl.startsWith('http');

  Future<Directory> _postersDir() async {
    final cached = _directory;
    if (cached != null) return cached;
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/posters');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    _directory = dir;
    return dir;
  }

  /// Ruta nueva y libre dentro de la carpeta de pósters.
  Future<String> newPath(String extension) async {
    final dir = await _postersDir();
    return '${dir.path}/${const Uuid().v4()}$extension';
  }

  /// Copia [file] a la carpeta de pósters y devuelve la ruta resultante.
  Future<String> adopt(File file) async {
    final ext = file.path.contains('.')
        ? file.path.substring(file.path.lastIndexOf('.'))
        : '.jpg';
    final target = await newPath(ext);
    await file.copy(target);
    return target;
  }

  /// Descarga [url] al disco y devuelve la ruta local, o null si no se pudo
  /// (sin red, 404, no es una imagen, demasiado grande...). Nunca lanza: el
  /// póster es un adorno, no vale la pena romper un guardado por él.
  Future<String?> download(String url) async {
    if (!isRemote(url)) return null;
    try {
      final response = await _client
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 20));

      if (response.statusCode != 200) return null;
      if (response.bodyBytes.length > maxBytes) return null;

      final mimeType =
          response.headers['content-type']?.split(';').first.trim().toLowerCase();
      final ext = _extensionByMimeType[mimeType];
      if (ext == null) return null; // No es una imagen que sepamos mostrar.

      final target = await newPath(ext);
      await File(target).writeAsBytes(response.bodyBytes);
      return target;
    } catch (_) {
      return null;
    }
  }

  /// Borra el archivo si el póster era local. Da igual si ya no estaba.
  Future<void> delete(String? posterUrl) async {
    if (!isLocal(posterUrl)) return;
    try {
      final file = File(posterUrl!);
      if (file.existsSync()) await file.delete();
    } catch (_) {}
  }

  /// Baja al disco los pósters que aún son URLs remotas y devuelve los ítems ya
  /// actualizados (solo los que cambiaron). Los que fallen se quedan como están
  /// y se reintentan la próxima vez.
  Future<List<ContentItem>> localizePending(Iterable<ContentItem> items) async {
    final updated = <ContentItem>[];
    for (final item in items) {
      if (!isRemote(item.posterUrl)) continue;
      final path = await download(item.posterUrl!);
      if (path != null) updated.add(item.copyWith(posterUrl: path));
    }
    return updated;
  }

  /// Borra los archivos de póster que ya no usa ningún ítem y devuelve cuántos
  /// se fueron. Los pósters quedan huérfanos al cambiar la portada o al borrar
  /// contenido.
  Future<int> pruneOrphans(Iterable<ContentItem> items) async {
    try {
      final dir = await _postersDir();
      if (!dir.existsSync()) return 0;

      final inUse = items
          .map((i) => i.posterUrl)
          .where(isLocal)
          .cast<String>()
          .map((p) => p.replaceAll(r'\', '/'))
          .toSet();

      var removed = 0;
      for (final entity in dir.listSync()) {
        if (entity is! File) continue;
        if (inUse.contains(entity.path.replaceAll(r'\', '/'))) continue;
        try {
          await entity.delete();
          removed++;
        } catch (_) {}
      }
      return removed;
    } catch (_) {
      return 0;
    }
  }
}

final posterStoreProvider = Provider<PosterStore>((ref) => PosterStore());
