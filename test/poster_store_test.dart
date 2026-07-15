import 'dart:io';

import 'package:cineapp/data/models/content_item.dart';
import 'package:cineapp/data/services/poster_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

ContentItem _item({required String id, String? posterUrl}) => ContentItem(
      id: id,
      title: 'Título $id',
      type: ContentType.movie,
      posterUrl: posterUrl,
      addedAt: DateTime(2026),
    );

/// Cliente que responde siempre lo mismo.
MockClient _client(
  List<int> body, {
  int status = 200,
  String contentType = 'image/jpeg',
}) {
  return MockClient((_) async => http.Response.bytes(
        body,
        status,
        headers: {'content-type': contentType},
      ));
}

void main() {
  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('posters_test');
  });

  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  PosterStore store(http.Client client) =>
      PosterStore(client: client, directory: tmp);

  group('isLocal / isRemote', () {
    test('distingue rutas del móvil de URLs', () {
      expect(PosterStore.isRemote('https://x.com/a.jpg'), isTrue);
      expect(PosterStore.isLocal('https://x.com/a.jpg'), isFalse);

      expect(PosterStore.isLocal('/data/user/0/posters/a.jpg'), isTrue);
      expect(PosterStore.isRemote('/data/user/0/posters/a.jpg'), isFalse);
    });

    test('null y vacío no son ninguna de las dos', () {
      expect(PosterStore.isLocal(null), isFalse);
      expect(PosterStore.isRemote(null), isFalse);
      expect(PosterStore.isLocal(''), isFalse);
      expect(PosterStore.isRemote(''), isFalse);
    });
  });

  group('download', () {
    test('guarda la imagen y devuelve una ruta local que existe', () async {
      final path = await store(_client([1, 2, 3])).download('https://x.com/a.jpg');

      expect(path, isNotNull);
      expect(PosterStore.isLocal(path), isTrue);
      expect(File(path!).readAsBytesSync(), [1, 2, 3]);
      expect(path, endsWith('.jpg'));
    });

    test('la extensión sale del content-type, no de la URL', () async {
      final path = await store(_client([1], contentType: 'image/png'))
          .download('https://x.com/sin-extension');

      expect(path, endsWith('.png'));
    });

    test('devuelve null si el servidor falla', () async {
      final path =
          await store(_client([], status: 404)).download('https://x.com/a.jpg');

      expect(path, isNull);
    });

    test('devuelve null si no es una imagen', () async {
      final path = await store(_client([1], contentType: 'text/html'))
          .download('https://x.com/a.jpg');

      expect(path, isNull);
    });

    test('devuelve null si pesa demasiado', () async {
      final enorme = List.filled(PosterStore.maxBytes + 1, 0);
      final path = await store(_client(enorme)).download('https://x.com/a.jpg');

      expect(path, isNull);
    });

    test('no lanza si no hay red, devuelve null', () async {
      final sinRed = MockClient((_) async => throw const SocketException('sin red'));

      expect(await store(sinRed).download('https://x.com/a.jpg'), isNull);
    });

    test('ignora lo que ya es local', () async {
      expect(await store(_client([1])).download('/ya/es/local.jpg'), isNull);
    });
  });

  group('localizePending', () {
    test('solo baja los remotos y devuelve los cambiados', () async {
      final items = [
        _item(id: 'remoto', posterUrl: 'https://x.com/a.jpg'),
        _item(id: 'local', posterUrl: '/ya/local.jpg'),
        _item(id: 'sin-poster'),
      ];

      final updated = await store(_client([1, 2])).localizePending(items);

      expect(updated, hasLength(1));
      expect(updated.single.id, 'remoto');
      expect(PosterStore.isLocal(updated.single.posterUrl), isTrue);
    });

    test('si la descarga falla el ítem se queda igual para reintentarlo', () async {
      final items = [_item(id: 'a', posterUrl: 'https://x.com/a.jpg')];

      final updated = await store(_client([], status: 500)).localizePending(items);

      expect(updated, isEmpty);
    });
  });

  group('pruneOrphans', () {
    test('borra los pósters que ya no usa nadie y respeta los vivos', () async {
      final s = store(_client([1]));
      final enUso = await s.download('https://x.com/vivo.jpg');
      final huerfano = await s.download('https://x.com/muerto.jpg');

      final removed = await s.pruneOrphans([_item(id: 'a', posterUrl: enUso)]);

      expect(removed, 1);
      expect(File(enUso!).existsSync(), isTrue);
      expect(File(huerfano!).existsSync(), isFalse);
    });

    test('un póster remoto no salva ningún archivo local', () async {
      final s = store(_client([1]));
      final huerfano = await s.download('https://x.com/a.jpg');

      final removed =
          await s.pruneOrphans([_item(id: 'a', posterUrl: 'https://x.com/a.jpg')]);

      expect(removed, 1);
      expect(File(huerfano!).existsSync(), isFalse);
    });
  });

  group('delete', () {
    test('borra el archivo local', () async {
      final s = store(_client([1]));
      final path = await s.download('https://x.com/a.jpg');

      await s.delete(path);

      expect(File(path!).existsSync(), isFalse);
    });

    test('no se queja de una URL ni de algo que ya no está', () async {
      final s = store(_client([1]));

      await s.delete('https://x.com/a.jpg');
      await s.delete('${tmp.path}/no-existe.jpg');
      await s.delete(null);
    });
  });
}
