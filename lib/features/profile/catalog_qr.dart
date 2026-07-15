import 'dart:convert';
import 'dart:io';

import '../../data/models/content_item.dart';

/// Prefijo que identifica un catálogo de CineLog en un QR. Sirve para no
/// intentar importar el QR de una wifi o de un ticket del súper.
const kQrMarker = 'CINELOGQR1:';

/// Bytes que aguanta un QR versión 40 con corrección de errores baja (L) en
/// modo binario. Es el techo absoluto del formato: por encima, no hay QR.
const kQrMaxBytes = 2953;

/// Campos que no tienen sentido mandarle a otra persona:
///
/// - `posterUrl` local: es una ruta del *tu* móvil, en el suyo no existe. Las
///   URLs remotas sí se mantienen, que esas funcionan en cualquier sitio.
/// - `notifyMe` / `notificationDate`: tus alarmas son tuyas.
Map<String, dynamic> _shareable(ContentItem item) {
  final json = item.toJson();
  final poster = json['posterUrl'] as String?;
  if (poster != null && !poster.startsWith('http')) {
    json['posterUrl'] = null;
  }
  json['notifyMe'] = false;
  json['notificationDate'] = null;
  return json;
}

/// Empaqueta el catálogo para un QR: JSON → gzip → base64.
///
/// El gzip no es un lujo: el JSON en crudo de 10 títulos ya se sale del QR, y
/// comprimido caben unos cuantos cientos. Aun así el formato tiene un techo
/// duro, así que esto puede devolver null: ver [buildCatalogQrPayload].
String _encode(List<ContentItem> items) {
  final json = jsonEncode(items.map(_shareable).toList());
  final gz = gzip.encode(utf8.encode(json));
  return '$kQrMarker${base64.encode(gz)}';
}

/// Resultado de intentar meter un catálogo en un QR.
class QrPayload {
  /// El texto del QR, o null si no cabe.
  final String? data;

  /// Bytes que ocuparía (aunque no quepa), para poder explicarlo.
  final int bytes;

  const QrPayload({required this.data, required this.bytes});

  bool get fits => data != null;

  /// Cuánto se pasa del límite, en tanto por ciento.
  int get overflowPercent => ((bytes / kQrMaxBytes - 1) * 100).ceil();
}

/// Prepara el QR del catálogo. Si no cabe devuelve [QrPayload.fits] false con
/// el tamaño, para poder decirle al usuario qué pasa en vez de dar un QR roto.
QrPayload buildCatalogQrPayload(List<ContentItem> items) {
  final encoded = _encode(items);
  final bytes = utf8.encode(encoded).length;
  return QrPayload(data: bytes <= kQrMaxBytes ? encoded : null, bytes: bytes);
}

/// True si [text] parece un catálogo de CineLog leído de un QR.
bool isCatalogQr(String text) => text.trimLeft().startsWith(kQrMarker);

/// Deshace [buildCatalogQrPayload]. Lanza [FormatException] si el texto no es
/// un catálogo nuestro o viene corrupto.
List<ContentItem> parseCatalogQr(String text) {
  final trimmed = text.trim();
  if (!isCatalogQr(trimmed)) {
    throw const FormatException('Este QR no es un catálogo de CineLog.');
  }

  final List raw;
  try {
    final payload = trimmed.substring(kQrMarker.length).trim();
    final json = utf8.decode(gzip.decode(base64.decode(payload)));
    raw = jsonDecode(json) as List;
  } catch (_) {
    throw const FormatException('El QR está dañado o incompleto.');
  }

  return raw
      .map((e) => ContentItem.fromJson(Map<String, dynamic>.from(e as Map)))
      .toList();
}
