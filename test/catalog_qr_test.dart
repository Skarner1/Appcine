import 'package:cineapp/data/models/content_item.dart';
import 'package:cineapp/data/models/watch_event.dart';
import 'package:cineapp/features/profile/catalog_qr.dart';
import 'package:cineapp/features/profile/catalog_share.dart';
import 'package:flutter_test/flutter_test.dart';

ContentItem _item({
  String id = 'a',
  String title = 'Interstellar',
  String? posterUrl,
  bool notifyMe = false,
  DateTime? notificationDate,
  List<WatchEvent> watchLog = const [],
}) {
  return ContentItem(
    id: id,
    title: title,
    type: ContentType.movie,
    genres: const ['Ciencia ficción'],
    durationMinutes: 169,
    status: WatchStatus.completed,
    userRating: 9.5,
    personalNote: 'Brutal en cine.',
    posterUrl: posterUrl,
    notifyMe: notifyMe,
    notificationDate: notificationDate,
    watchLog: watchLog,
    addedAt: DateTime(2026, 1, 1),
  );
}

void main() {
  group('ida y vuelta', () {
    test('lo que entra es lo que sale', () {
      final items = [
        _item(id: 'a', title: 'Interstellar'),
        _item(id: 'b', title: 'Dune'),
      ];

      final payload = buildCatalogQrPayload(items);
      expect(payload.fits, isTrue);

      final parsed = parseCatalogQr(payload.data!);

      expect(parsed.map((e) => e.id), ['a', 'b']);
      expect(parsed.first.title, 'Interstellar');
      expect(parsed.first.userRating, 9.5);
      expect(parsed.first.personalNote, 'Brutal en cine.');
      expect(parsed.first.genres, ['Ciencia ficción']);
    });

    test('el diario de visionados viaja con el título', () {
      final items = [
        _item(watchLog: [
          WatchEvent(date: DateTime(2026, 3, 10), minutes: 169),
          WatchEvent(date: DateTime(2026, 5, 1), minutes: 169),
        ]),
      ];

      final parsed = parseCatalogQr(buildCatalogQrPayload(items).data!);

      expect(parsed.single.watchLog, hasLength(2));
      expect(parsed.single.loggedMinutes, 338);
    });

    test('un catálogo vacío también va y vuelve', () {
      final payload = buildCatalogQrPayload([]);

      expect(payload.fits, isTrue);
      expect(parseCatalogQr(payload.data!), isEmpty);
    });
  });

  group('qué se comparte y qué no', () {
    test('el póster local no viaja: esa ruta no existe en el otro móvil', () {
      final items = [_item(posterUrl: '/data/user/0/app/posters/x.jpg')];

      final parsed = parseCatalogQr(buildCatalogQrPayload(items).data!);

      expect(parsed.single.posterUrl, isNull);
    });

    test('el póster remoto sí viaja: funciona en cualquier sitio', () {
      final items = [_item(posterUrl: 'https://img.com/poster.jpg')];

      final parsed = parseCatalogQr(buildCatalogQrPayload(items).data!);

      expect(parsed.single.posterUrl, 'https://img.com/poster.jpg');
    });

    test('las alarmas del que comparte no se le cuelan al que recibe', () {
      final items = [
        _item(notifyMe: true, notificationDate: DateTime(2026, 8, 1)),
      ];

      final parsed = parseCatalogQr(buildCatalogQrPayload(items).data!);

      expect(parsed.single.notifyMe, isFalse);
      expect(parsed.single.notificationDate, isNull);
    });
  });

  group('límite de tamaño', () {
    test('un catálogo normal cabe', () {
      final items = List.generate(30, (i) => _item(id: '$i', title: 'Título $i'));

      expect(buildCatalogQrPayload(items).fits, isTrue);
    });

    test('uno enorme no cabe y lo dice, en vez de dar un QR roto', () {
      // Títulos y notas distintos entre sí: aquí gzip no puede hacer magia.
      final items = List.generate(
        4000,
        (i) => _item(
          id: 'id-numero-$i',
          title: 'Película $i con un título largo y distinto ${i * 7919}',
        ),
      );

      final payload = buildCatalogQrPayload(items);

      expect(payload.fits, isFalse);
      expect(payload.data, isNull);
      expect(payload.bytes, greaterThan(kQrMaxBytes));
      expect(payload.overflowPercent, greaterThan(0));
    });

    test('el gzip es lo que hace viable esto', () {
      // Sin comprimir, el JSON de 30 títulos se sale del QR de largo.
      final items = List.generate(30, (i) => _item(id: '$i', title: 'Título $i'));
      final jsonSize =
          items.fold<int>(0, (sum, i) => sum + i.toJson().toString().length);

      expect(jsonSize, greaterThan(kQrMaxBytes));
      expect(buildCatalogQrPayload(items).bytes, lessThan(kQrMaxBytes));
    });
  });

  group('entradas que no son nuestras', () {
    test('reconoce lo que es un catálogo y lo que no', () {
      expect(isCatalogQr('${kQrMarker}abc'), isTrue);
      expect(isCatalogQr('https://ejemplo.com'), isFalse);
      expect(isCatalogQr('WIFI:S:MiRed;T:WPA;P:1234;;'), isFalse);
      expect(isCatalogQr(''), isFalse);
    });

    test('el QR de una wifi no se intenta importar', () {
      expect(
        () => parseCatalogQr('WIFI:S:MiRed;T:WPA;P:1234;;'),
        throwsA(isA<FormatException>()),
      );
    });

    test('un QR nuestro pero corrupto se detecta', () {
      expect(
        () => parseCatalogQr('${kQrMarker}esto-no-es-base64-valido!!'),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('interoperabilidad con el resto de importaciones', () {
    test('parseSharedCatalog acepta un QR pegado en el portapapeles', () {
      final items = [_item(id: 'a', title: 'Dune')];
      final payload = buildCatalogQrPayload(items).data!;

      final parsed = parseSharedCatalog(payload);

      expect(parsed.single.title, 'Dune');
    });

    test('y sigue aceptando el texto de siempre', () {
      final items = [_item(id: 'a', title: 'Dune')];

      final parsed = parseSharedCatalog(buildCatalogText('Ivan', items));

      expect(parsed.single.title, 'Dune');
    });
  });
}
