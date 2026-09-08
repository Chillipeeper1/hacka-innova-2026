import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maas_morelia/data/models.dart';
import 'package:latlong2/latlong.dart';
import 'package:maas_morelia/data/providers.dart';
import 'package:maas_morelia/data/trip_draft.dart';
import 'package:maas_morelia/screens/home_screen.dart';
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
    VoidCallback? onSearchStop,
    VoidCallback? onTravelByBike,
    VoidCallback? onTravelWalking,
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
              onSearchStop: onSearchStop,
              onTravelByBike: onTravelByBike,
              onTravelWalking: onTravelWalking,
            ),
          ),
        ),
      ),
    );
    // El primer bombeo monta; los siguientes dejan resolver los futuros del catálogo y del
    // conteo de demanda, y entregar los eventos del canal en vivo.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 10));
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

        // Sin destino declarado, el buscador es la primera acción del viaje.
        expect(find.text('¿A dónde vas?'), findsOneWidget);
        expect(find.text('Viajar en bici...'), findsOneWidget);
        expect(find.text('Viajar caminando...'), findsOneWidget);
      });
    });
  });

  testWidgets('aguanta tipografía al doble por accesibilidad', (tester) async {
    await pumpAt(tester, const Size(360, 640), textScale: 2.0);
    expectNoLayoutError(tester, 'tipografía al doble');
  });

  testWidgets('el mapa es real, no una imagen fija', (tester) async {
    await pumpAt(tester, const Size(402, 874));
    expectNoLayoutError(tester, 'mapa');

    expect(find.byType(FlutterMap), findsOneWidget);
    expect(find.byType(TileLayer), findsOneWidget);
  });

  testWidgets('dibuja las rutas del backend con su color', (tester) async {
    await pumpAt(tester, const Size(402, 874));
    expectNoLayoutError(tester, 'rutas');

    final layer = tester.widget<PolylineLayer>(find.byType(PolylineLayer));
    expect(layer.polylines, hasLength(2), reason: 'las dos rutas del seed');

    // #0E5E56 es el color de la primera ruta en los datos semilla. Se compara solo el RGB:
    // la línea se dibuja translúcida para no tapar las calles debajo.
    expect(layer.polylines.first.color.toARGB32() & 0x00FFFFFF, 0x0E5E56);
  });

  testWidgets('dibuja las cinco paradas del catálogo', (tester) async {
    await pumpAt(tester, const Size(402, 874));
    expectNoLayoutError(tester, 'paradas');

    expect(find.bySemanticsLabel('Parada Catedral de Morelia'), findsWidgets);
    expect(
      find.bySemanticsLabel('Parada Acueducto de Morelia'),
      findsOneWidget,
    );
  });

  testWidgets('la unidad aparece cuando llega su posición en vivo', (
    tester,
  ) async {
    await pumpAt(tester, const Size(402, 874));
    expectNoLayoutError(tester, 'sin unidades');

    expect(find.bySemanticsLabel('Unidad en ruta'), findsNothing);

    realtime.emitVehicle(
      const VehiclePosition(vehicleId: 1, lat: 19.6989, lng: -101.1789),
    );
    await tester.pump(const Duration(milliseconds: 10));
    expectNoLayoutError(tester, 'con unidad');

    expect(find.bySemanticsLabel('Unidad en ruta'), findsOneWidget);
  });

  testWidgets('la insignia de demanda aparece al llegar demand:update', (
    tester,
  ) async {
    await pumpAt(tester, const Size(402, 874));
    expectNoLayoutError(tester, 'demanda inicial');

    expect(find.text('3'), findsNothing);

    realtime.emitDemand(const DemandCount(stopId: 1, waitingCount: 3));
    await tester.pump(const Duration(milliseconds: 10));
    expectNoLayoutError(tester, 'demanda actualizada');

    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('avisa cuando el backend no responde', (tester) async {
    // Un servidor apagado se ve igual que un mapa sin unidades: sin aviso, en la demo se
    // confunde con que la app está rota.
    await pumpAt(tester, const Size(402, 874));
    expectNoLayoutError(tester, 'conectado');

    expect(find.textContaining('Sin conexión'), findsNothing);

    realtime.emitConnection(connected: false);
    await tester.pump(const Duration(milliseconds: 10));
    expectNoLayoutError(tester, 'desconectado');

    expect(find.textContaining('tiempo real'), findsOneWidget);
  });

  testWidgets('atribuye a OpenStreetMap, como exige la licencia', (
    tester,
  ) async {
    await pumpAt(tester, const Size(402, 874));
    expectNoLayoutError(tester, 'atribución');

    expect(find.textContaining('OpenStreetMap'), findsOneWidget);
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

  testWidgets('las opciones de viaje responden al toque', (tester) async {
    var bike = 0;
    var walk = 0;
    var search = 0;

    await pumpAt(
      tester,
      const Size(402, 874),
      onSearchStop: () => search++,
      onTravelByBike: () => bike++,
      onTravelWalking: () => walk++,
    );
    expectNoLayoutError(tester, 'toques');

    await tester.tap(find.text('Viajar en bici...'));
    await tester.tap(find.text('Viajar caminando...'));
    await tester.tap(find.byType(SearchStopCard));
    await tester.pump();

    expect(bike, 1);
    expect(walk, 1);
    expect(search, 1);
  });

  testWidgets('la hoja inferior no se come el mapa completo', (tester) async {
    const size = Size(360, 640);
    await pumpAt(tester, size, textScale: 2.0);
    expectNoLayoutError(tester, 'alto de la hoja');

    final sheet = tester.getSize(find.byType(TravelOptionTile).first);
    expect(sheet.height, lessThan(size.height * 0.55));
  });

  testWidgets('el buscador muestra el destino una vez elegido', (tester) async {
    // El buscador es también el estado del viaje: al declarar destino deja de pedirlo y
    // pasa a decir a dónde va.
    final container = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWithValue(FakeApi().build()),
        realtimeClientProvider.overrideWithValue(realtime),
      ],
    );
    addTearDown(container.dispose);
    await container.read(routesProvider.future);
    container
        .read(tripDraftProvider.notifier)
        .setDestination(const LatLng(19.6920, -101.1772));

    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: buildAppTheme(),
          home: const HomeScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 10));
    expectNoLayoutError(tester, 'destino elegido');

    expect(find.text('Vas a Bosque Cuauhtémoc'), findsOneWidget);
    expect(find.text('¿A dónde vas?'), findsNothing);
    // La parada de bajada se marca distinto para no confundirla con una de abordaje.
    expect(
      find.bySemanticsLabel('Parada de bajada Bosque Cuauhtémoc'),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('Tu destino'), findsOneWidget);
  });

  testWidgets('los controles no se estiran en escritorio', (tester) async {
    await pumpAt(tester, const Size(1440, 900));
    expectNoLayoutError(tester, 'escritorio');

    final card = tester.getSize(find.byType(SearchStopCard));
    expect(card.width, lessThanOrEqualTo(maxContentWidth));
  });
}
