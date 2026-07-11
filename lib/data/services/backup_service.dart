import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/content_item.dart';

/// Resultado de importar un backup desde archivo.
class BackupImport {
  /// Títulos leídos del archivo.
  final List<ContentItem> items;

  /// Nombre del archivo elegido (para mostrarlo en el diálogo).
  final String fileName;

  const BackupImport({required this.items, required this.fileName});
}

/// Copia de seguridad local a/desde un archivo `.json`. Sin red: exporta
/// compartiendo un archivo y restaura leyendo uno que elija el usuario.
class BackupService {
  const BackupService();

  /// Versión del formato de backup; permite migraciones futuras.
  static const int formatVersion = 1;

  /// Serializa el catálogo a un JSON con metadatos (app, versión, fecha).
  String encode(List<ContentItem> items) {
    return const JsonEncoder.withIndent('  ').convert({
      'app': 'CineLog Pro',
      'version': formatVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'count': items.length,
      'items': items.map((e) => e.toJson()).toList(),
    });
  }

  /// Interpreta un backup. Acepta el formato nuevo (objeto con `items`) y el
  /// antiguo (lista pelada de items). Lanza [FormatException] si no es válido.
  List<ContentItem> decode(String raw) {
    final dynamic data;
    try {
      data = jsonDecode(raw);
    } on FormatException {
      throw const FormatException('El archivo no es un JSON válido.');
    }

    final List rawItems;
    if (data is List) {
      rawItems = data;
    } else if (data is Map && data['items'] is List) {
      rawItems = data['items'] as List;
    } else {
      throw const FormatException('El archivo no es un backup de CineLog Pro.');
    }

    try {
      return rawItems
          .map((e) => ContentItem.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      throw const FormatException('El backup tiene un formato incorrecto.');
    }
  }

  /// Escribe el backup en un archivo temporal y abre el diálogo de compartir
  /// para que el usuario lo guarde donde quiera (Drive, correo, Archivos…).
  /// Devuelve la ruta del archivo generado.
  Future<String> exportAndShare(List<ContentItem> items) async {
    final dir = await getTemporaryDirectory();
    final now = DateTime.now();
    final name = 'cinelog_backup_'
        '${now.year}-${_two(now.month)}-${_two(now.day)}_'
        '${_two(now.hour)}${_two(now.minute)}.json';
    final file = File('${dir.path}/$name');
    await file.writeAsString(encode(items));

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'application/json')],
        subject: 'Copia de seguridad CineLog Pro',
        text: 'Backup de tu catálogo (${items.length} títulos).',
      ),
    );
    return file.path;
  }

  /// Deja elegir un archivo y devuelve su contenido parseado, o null si el
  /// usuario cancela. Lanza [FormatException] si el archivo no es válido.
  Future<BackupImport?> pickAndDecode() async {
    final result = await FilePicker.pickFiles(
      type: FileType.any,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;

    final picked = result.files.first;
    final String raw;
    if (picked.bytes != null) {
      raw = utf8.decode(picked.bytes!);
    } else if (picked.path != null) {
      raw = await File(picked.path!).readAsString();
    } else {
      throw const FormatException('No se pudo leer el archivo elegido.');
    }

    return BackupImport(items: decode(raw), fileName: picked.name);
  }

  static String _two(int n) => n.toString().padLeft(2, '0');
}

final backupServiceProvider = Provider<BackupService>(
  (ref) => const BackupService(),
);
