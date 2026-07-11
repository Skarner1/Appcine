// Test temporal: flujo "Buscar en internet" dentro del formulario.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cineapp/core/theme/app_theme.dart';
import 'package:cineapp/data/models/content_item.dart';
import 'package:cineapp/data/models/online_result.dart';
import 'package:cineapp/data/services/online_search_service.dart';
import 'package:cineapp/features/content_form/content_form_screen.dart';

class _FakeService extends OnlineSearchService {
  @override
  Future<List<OnlineResult>> search(ContentType type, String query) async {
    return [
      OnlineResult(
        title: 'Pelicula Falsa',
        type: type,
        posterUrl: null, // evita cargas de red en el test
        genres: const ['Acción', 'Ciencia Ficción'],
        overview: 'Sinopsis de prueba.',
        durationMinutes: 100,
        releaseDate: DateTime(2020),
      ),
    ];
  }

  @override
  Future<OnlineResult> enrich(OnlineResult r) async => r;
}

void main() {
  testWidgets('Formulario: buscar en internet y rellenar la ficha',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        onlineSearchServiceProvider.overrideWithValue(_FakeService()),
      ],
      child: MaterialApp(
        theme: AppTheme.dark(),
        home: const ContentFormScreen(),
      ),
    ));
    await tester.pumpAndSettle();

    // Abre el menú de portada tocando el icono de la cámara.
    await tester.tap(find.byIcon(Icons.photo_camera_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Buscar en internet'), findsOneWidget);

    // Abre el selector online.
    await tester.tap(find.text('Buscar en internet'));
    await tester.pumpAndSettle();
    expect(find.text('Buscar carátula e info'), findsOneWidget);

    // Escribe y espera al debounce + resolución del futuro (sin pumpAndSettle
    // para no colgar en el spinner infinito).
    await tester.enterText(find.byType(TextField).first, 'x');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
    await tester.pump();
    expect(find.text('Pelicula Falsa'), findsOneWidget);

    // Elige el resultado → vuelve al formulario y rellena.
    await tester.tap(find.text('Pelicula Falsa'));
    await tester.pumpAndSettle();

    // El título se importó al campo del formulario.
    expect(find.text('Pelicula Falsa'), findsOneWidget);
    expect(find.text('Póster e información importados de internet'),
        findsOneWidget);
    // El género importado aparece como chip seleccionado.
    expect(find.text('Acción'), findsWidgets);
  });
}
