import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/content_item.dart';
import '../../shared/widgets/poster_image.dart';
import 'catalog_qr.dart';

/// Marcador del bloque de datos incrustado al final del texto compartido.
/// Permite que un catálogo legible se pueda volver a importar.
const _kDataMarker = 'CINELOG_DATA:';

/// Construye el texto legible (estilo bloc de notas) del catálogo, agrupado por
/// estado. Al final incrusta un bloque de datos base64 para poder reimportarlo.
String buildCatalogText(String name, List<ContentItem> items) {
  final b = StringBuffer();
  final who = name.trim().isEmpty ? 'Mi catálogo' : 'Catálogo de ${name.trim()}';
  final completed =
      items.where((i) => i.status == WatchStatus.completed).length;
  final pending = items.length - completed;

  b.writeln('🎬 $who — CineLog Pro');
  b.writeln('${items.length} títulos · $completed vistos · $pending por ver');
  b.writeln();

  void section(String header, Iterable<ContentItem> list) {
    final l = list.toList();
    if (l.isEmpty) return;
    b.writeln('$header (${l.length})');
    for (final i in l) {
      final parts = <String>[i.type.label];
      if (i.genres.isNotEmpty) parts.add(i.genres.take(2).join(', '));
      if (i.type.hasEpisodes && i.episodes != null) {
        parts.add('${i.episodes} ep');
      }
      final extras = <String>[];
      if (i.userRating != null) {
        extras.add('⭐ ${i.userRating!.toStringAsFixed(1)}');
      }
      if (i.isFavorite) extras.add('❤ favorita');
      final extra = extras.isEmpty ? '' : ' · ${extras.join(' · ')}';
      b.writeln('• ${i.title} (${parts.join(' · ')})$extra');
      final note = i.personalNote?.trim();
      if (note != null && note.isNotEmpty) {
        b.writeln('    "$note"');
      }
    }
    b.writeln();
  }

  section(
    '⏳ POR VER',
    items.where((i) =>
        i.status == WatchStatus.notStarted ||
        i.status == WatchStatus.watching ||
        i.status == WatchStatus.onHold),
  );
  section('🔁 VOLVER A VER',
      items.where((i) => i.status == WatchStatus.rewatchPending));
  section(
      '✅ VISTOS', items.where((i) => i.status == WatchStatus.completed));
  section('🚫 ABANDONADAS',
      items.where((i) => i.status == WatchStatus.dropped));

  b.writeln('Compartido desde CineLog Pro 🍿');

  // Bloque de datos oculto (una sola línea) para poder reimportar el catálogo.
  final data = jsonEncode(items.map((e) => e.toJson()).toList());
  final encoded = base64.encode(utf8.encode(data));
  b.writeln();
  b.writeln('——— No borres la línea de abajo si quieres reimportarlo ———');
  b.write('$_kDataMarker$encoded');

  return b.toString();
}

/// Interpreta un catálogo compartido. Acepta el payload de un QR, el bloque de
/// datos incrustado (base64), el formato nuevo `{items:[...]}` y la lista JSON
/// antigua.
List<ContentItem> parseSharedCatalog(String text) {
  // Un QR pegado en el portapapeles debe importarse igual que lo demás.
  if (isCatalogQr(text)) return parseCatalogQr(text);

  String jsonStr;
  final idx = text.indexOf(_kDataMarker);
  if (idx != -1) {
    final after = text.substring(idx + _kDataMarker.length).trim();
    final token = after.split(RegExp(r'\s+')).first;
    jsonStr = utf8.decode(base64.decode(token));
  } else {
    jsonStr = text.trim();
  }

  final decoded = jsonDecode(jsonStr);
  final List raw = decoded is Map
      ? (decoded['items'] as List? ?? const [])
      : decoded as List;
  return raw
      .map((e) => ContentItem.fromJson(Map<String, dynamic>.from(e as Map)))
      .toList();
}

/// Comparte el catálogo como texto legible mediante la hoja de compartir.
Future<void> shareCatalogAsText(String name, List<ContentItem> items) {
  return SharePlus.instance.share(
    ShareParams(
      text: buildCatalogText(name, items),
      subject: 'Mi catálogo CineLog Pro',
    ),
  );
}

/// Pantalla de vista previa que renderiza el catálogo como una tarjeta y la
/// comparte como imagen PNG.
class CatalogImagePreviewScreen extends StatefulWidget {
  final String userName;
  final List<ContentItem> items;

  const CatalogImagePreviewScreen({
    super.key,
    required this.userName,
    required this.items,
  });

  @override
  State<CatalogImagePreviewScreen> createState() =>
      _CatalogImagePreviewScreenState();
}

class _CatalogImagePreviewScreenState extends State<CatalogImagePreviewScreen> {
  final GlobalKey _boundaryKey = GlobalKey();
  bool _ready = false;
  bool _sharing = false;

  static const _maxPosters = 12;

  List<ContentItem> get _shown => widget.items.take(_maxPosters).toList();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _precachePosters());
  }

  Future<void> _precachePosters() async {
    for (final item in _shown) {
      final url = item.posterUrl;
      if (url == null || url.isEmpty) continue;
      try {
        final ImageProvider provider = url.startsWith('http')
            ? CachedNetworkImageProvider(url)
            : FileImage(File(url));
        if (mounted) await precacheImage(provider, context);
      } catch (_) {
        // Se ignora: PosterImage muestra su placeholder.
      }
    }
    if (mounted) setState(() => _ready = true);
  }

  Future<void> _shareImage() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _sharing = true);
    try {
      // Deja pintar el frame actual antes de capturar.
      await Future.delayed(const Duration(milliseconds: 120));
      final boundary = _boundaryKey.currentContext!.findRenderObject()
          as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) throw StateError('sin datos de imagen');

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/catalogo_cinelog.png');
      await file.writeAsBytes(bytes.buffer.asUint8List());

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'image/png')],
          subject: 'Mi catálogo CineLog Pro',
          text: 'Te comparto mi catálogo de CineLog Pro 🍿',
        ),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('No se pudo generar la imagen.')),
      );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Vista previa')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: FittedBox(
                    child: RepaintBoundary(
                      key: _boundaryKey,
                      child: _CatalogCard(
                        userName: widget.userName,
                        items: widget.items,
                        shown: _shown,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: (_ready && !_sharing) ? _shareImage : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: _sharing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.ios_share_outlined, size: 20),
                  label: Text(
                    _ready ? 'Compartir imagen' : 'Preparando…',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tarjeta visual del catálogo que se captura como imagen.
class _CatalogCard extends StatelessWidget {
  final String userName;
  final List<ContentItem> items;
  final List<ContentItem> shown;

  const _CatalogCard({
    required this.userName,
    required this.items,
    required this.shown,
  });

  @override
  Widget build(BuildContext context) {
    final total = items.length;
    final completed =
        items.where((i) => i.status == WatchStatus.completed).length;
    final pending = total - completed;
    final remaining = total - shown.length;
    final who = userName.trim().isEmpty ? 'Mi catálogo' : userName.trim();

    return Container(
      width: 380,
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1B1030), Color(0xFF0F0F0F)],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🎬', style: TextStyle(fontSize: 28)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      who,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.darkPalette.textPrimary,
                      ),
                    ),
                    Text(
                      'Catálogo de CineLog Pro',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.darkPalette.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _statChip('$total', 'títulos', AppColors.primary),
              const SizedBox(width: 8),
              _statChip('$pending', 'por ver', AppColors.warning),
              const SizedBox(width: 8),
              _statChip('$completed', 'vistos', AppColors.success),
            ],
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 16,
            children: [
              for (final item in shown)
                SizedBox(
                  width: 100,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: AspectRatio(
                          aspectRatio: 2 / 3,
                          child: PosterImage(item: item),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.darkPalette.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          if (remaining > 0) ...[
            const SizedBox(height: 12),
            Text(
              'y $remaining título${remaining == 1 ? '' : 's'} más…',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: AppColors.darkPalette.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 20),
          Center(
            child: Text(
              'CineLog Pro 🍿',
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.darkPalette.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statChip(String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Column(
          children: [
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 10.5,
                color: AppColors.darkPalette.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
