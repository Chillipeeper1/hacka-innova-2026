import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maas_morelia/data/providers.dart';
import 'package:maas_morelia/screens/home_screen.dart';
import 'package:maas_morelia/widgets/app_map.dart';
import 'package:maas_morelia/theme.dart';
import 'package:maas_morelia/widgets/map_chrome.dart';

import 'support/fakes.dart';

void main() {
  late FakeRealtimeClient realtime;

  setUp(() => realtime = FakeRealtimeClient());

  Future<void> pumpAt(
    WidgetTester tester,
    Size size, {
    double textScale = 1.0,
    FakeApi? api,
    VoidCallback? onFastestTrip,
    VoidCallback? onTravelByBus,
    VoidCallback? onTravelByBike,
    VoidCallback? onTravelWalking,
    VoidCallback? onTravelByCableCar,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue((api ?? FakeApi()).build()),
          realtimeClientProvider.overrideWithValue(realtime),
        ],
        child: MaterialApp(
          theme: buildAppTheme(),
          home: MediaQuery(
            data: MediaQueryData(
              size: size,
              textScaler: TextScaler.linear(textScale),
            ),
            child: HomeScreen(
              onFastestTrip: onFastestTrip,
              onTravelByBus: onTravelByBus,
              onTravelByBike: onTravelByBike,
              onTravelWalking: onTravelWalking,
              onTravelByCableCar: onTravelByCableCar,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 10));
  }

  /// Las teselas se piden por red y en pruebas eso siempre falla: el cliente HTTP de
  /// `flutter_test` responde 400 a todo. Ese error no dice nada sobre el layout.
  void expectNoLayoutError(WidgetTester tester, String context) {
    final exception = tester.takeException();
    if (exception == null) return;
    final text = exception.toString();
    final isTileFailure =
        text.contains('HttpException') ||
        text.contains('400') ||
        text.contains('NetworkImage') ||
        text.contains('Failed to load');
    expect(
      isTileFailure,
      isTrue,
      reason: 'excepción de layout en $context: $exception',
    );
  }

  const viewports = <String, Size>{
    'iPhone SE (pantalla chica)': Size(320, 568),
    'Android compacto': Size(360, 640),
    'lienzo del diseño': Size(402, 874),
    'iPhone Pro Max': Size(430, 932),
    'tablet vertical': Size(768, 1024),
    'tablet horizontal': Size(1024, 768),
    'escritorio / web': Size(1440, 900),
  };

  group('HomeScreen se acomoda sin desbordarse', () {
    viewports.forEach((name, size) {
      testWidgets(name, (tester) async {
        await pumpAt(tester, size);
        expectNoLayoutError(tester, name);

        expect(find.text('¿A dónde vas?'), findsOneWidget);
        expect(find.text('Viajar en camión...'), findsOneWidget);
        expect(find.text('Viajar en bici...'), findsOneWidget);
        expect(find.text('Viajar caminando...'), findsOneWidget);
        expect(find.text('Viajar en teleférico...'), findsOneWidget);
      });
    });
  });

  testWidgets('aguanta tipografía al doble por accesibilidad', (tester) async {
    await pumpAt(tester, const Size(360, 640), textScale: 2.0);
    expectNoLayoutError(tester, 'tipografía al doble');
  });

  testWidgets('el mapa arranca limpio: sin rutas ni paradas', (tester) async {
    // Mostrar todo el catálogo de entrada satura y no ayuda a decidir. Las paradas que
    // importan son las que llevan a donde el usuario va, y eso se sabe hasta que lo dice.
    await pumpAt(tester, const Size(402, 874));
    expectNoLayoutError(tester, 'mapa limpio');

    final map = tester.widget<AppMap>(find.byType(AppMap));
    expect(map.lines, isEmpty);
    expect(map.areas, isEmpty);
    // El único marcador es el propio usuario.
    expect(map.markers, hasLength(1));
    expect(find.bySemanticsLabel('Parada Catedral de Morelia'), findsNothing);
    expect(find.bySemanticsLabel('Unidad en ruta'), findsNothing);
  });

  testWidgets('muestra dónde está el usuario', (tester) async {
    await pumpAt(tester, const Size(402, 874));
    expectNoLayoutError(tester, 'posición');

    expect(find.bySemanticsLabel('Tu posición'), findsOneWidget);
  });

  testWidgets('avisa cuando el backend no responde', (tester) async {
    // Un servidor apagado se ve igual que un mapa sin novedades: sin aviso, en la demo se
    // confunde con que la app está rota.
    await pumpAt(tester, const Size(402, 874));
    expectNoLayoutError(tester, 'conectado');

    expect(find.textContaining('tiempo real'), findsNothing);

    realtime.emitConnection(connected: false);
    await tester.pump(const Duration(milliseconds: 10));
    expectNoLayoutError(tester, 'desconectado');

    expect(find.textContaining('tiempo real'), findsOneWidget);
  });

  testWidgets('los controles del mapa son accesibles por lector de pantalla', (
    tester,
  ) async {
    await pumpAt(tester, const Size(402, 874));
    expectNoLayoutError(tester, 'accesibilidad');

    expect(find.bySemanticsLabel('Abrir menú'), findsOneWidget);
    expect(find.bySemanticsLabel('Mi perfil'), findsOneWidget);
    expect(find.bySemanticsLabel('¿A dónde vas?'), findsOneWidget);
  });

  testWidgets('el buscador es la puerta de entrada al viaje', (tester) async {
    var search = 0;
    await pumpAt(tester, const Size(402, 874), onFastestTrip: () => search++);
    expectNoLayoutError(tester, 'buscador');

    await tester.tap(find.byType(SearchStopCard));
    await tester.pump();
    expect(search, 1);
  });

  testWidgets('las opciones de viaje responden al toque', (tester) async {
    var bike = 0;
    var walk = 0;

    await pumpAt(
      tester,
      const Size(402, 874),
      onTravelByBike: () => bike++,
      onTravelWalking: () => walk++,
    );
    expectNoLayoutError(tester, 'toques');

    await tester.tap(find.text('Viajar en bici...'));
    await tester.tap(find.text('Viajar caminando...'));
    await tester.pump();

    expect(bike, 1);
    expect(walk, 1);
  });

  testWidgets('la hoja inferior no se come el mapa completo', (tester) async {
    const size = Size(360, 640);
    await pumpAt(tester, size, textScale: 2.0);
    expectNoLayoutError(tester, 'alto de la hoja');

    final sheet = tester.getSize(find.byType(TravelOptionTile).first);
    expect(sheet.height, lessThan(size.height * 0.55));
  });

  testWidgets('los controles no se estiran en escritorio', (tester) async {
    await pumpAt(tester, const Size(1440, 900));
    expectNoLayoutError(tester, 'escritorio');

    final card = tester.getSize(find.byType(SearchStopCard));
    expect(card.width, lessThanOrEqualTo(maxContentWidth));
  });

  testWidgets('el teleférico responde al toque', (tester) async {
    var tapped = false;
    await pumpAt(
      tester,
      const Size(402, 874),
      onTravelByCableCar: () => tapped = true,
    );
    expectNoLayoutError(tester, 'teleférico');

    await tester.tap(find.text('Viajar en teleférico...'));
    await tester.pump();
    expect(tapped, isTrue);
  });
}
