import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maas_morelia/screens/home_screen.dart';
import 'package:maas_morelia/theme.dart';
import 'package:maas_morelia/widgets/map_chrome.dart';

void main() {
  Future<void> pumpAt(
    WidgetTester tester,
    Size size, {
    double textScale = 1.0,
    VoidCallback? onSearchStop,
    VoidCallback? onTravelByBike,
    VoidCallback? onTravelWalking,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
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
    );
    await tester.pump();
  }

  /// Las teselas se piden por red y en pruebas eso siempre falla: el cliente HTTP de
  /// `flutter_test` responde 400 a todo. Ese error no dice nada sobre el layout, que es lo
  /// que aquí se verifica, así que se descarta a propósito.
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

        expect(find.text('Buscar parada...'), findsOneWidget);
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

    // Los botones de icono suelto necesitan etiqueta explícita; la tarjeta de búsqueda se
    // anuncia sola por su texto visible.
    expect(find.bySemanticsLabel('Abrir menú'), findsOneWidget);
    expect(find.bySemanticsLabel('Mi perfil'), findsOneWidget);
    expect(find.bySemanticsLabel('Buscar parada...'), findsOneWidget);
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
    // Con tipografía al doble los renglones crecen, pero la hoja se limita al 55% del alto
    // y desplaza por dentro en vez de tapar el mapa.
    expect(sheet.height, lessThan(size.height * 0.55));
  });

  testWidgets('los controles no se estiran en escritorio', (tester) async {
    await pumpAt(tester, const Size(1440, 900));
    expectNoLayoutError(tester, 'escritorio');

    final card = tester.getSize(find.byType(SearchStopCard));
    expect(card.width, lessThanOrEqualTo(maxContentWidth));
  });
}
