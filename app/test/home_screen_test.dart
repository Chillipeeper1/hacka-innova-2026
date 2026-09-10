import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maas_morelia/data/providers.dart';
import 'package:maas_morelia/screens/home_screen.dart';
import 'package:maas_morelia/theme.dart';
import 'package:maas_morelia/widgets/app_map.dart';
import 'package:maas_morelia/widgets/map_chrome.dart';
import 'package:maas_morelia/widgets/trip_widgets.dart';

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
    VoidCallback? onPlus,
    VoidCallback? onAd,
    VoidCallback? onCustomTrip,
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
              onSearchStop: onSearchStop,
              onPlus: onPlus,
              onAd: onAd,
              onCustomTrip: onCustomTrip,
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

        expect(find.text('Paradas de bus disponibles'), findsOneWidget);
        expect(find.text('Viaje personalizado...'), findsOneWidget);
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

  testWidgets('los controles son accesibles por lector de pantalla', (
    tester,
  ) async {
    await pumpAt(tester, const Size(402, 874));
    expectNoLayoutError(tester, 'accesibilidad');

    expect(find.bySemanticsLabel('Abrir menú'), findsOneWidget);
    expect(find.bySemanticsLabel('Mi perfil'), findsOneWidget);
    expect(find.bySemanticsLabel('Paradas de bus disponibles'), findsOneWidget);
  });

  testWidgets('el buscador es la puerta de entrada al viaje', (tester) async {
    var search = 0;
    await pumpAt(tester, const Size(402, 874), onSearchStop: () => search++);
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

  testWidgets('el menú cabe en pantalla chica con tipografía al doble', (
    tester,
  ) async {
    // Cuatro modos más la marca y el buscador no caben en 640 px con el texto al doble, así
    // que el menú tiene que poder desplazarse en vez de recortarse.
    await pumpAt(tester, const Size(360, 640), textScale: 2.0);
    expectNoLayoutError(tester, 'menú al doble');

    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(find.byType(TravelOptionTile), findsNWidgets(4));
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

  testWidgets('la tarjeta de arriba sigue llevando al viaje en camión', (
    tester,
  ) async {
    // Fue la entrada al flujo del camión desde el principio. Repuntarla a otro sitio deja al
    // usuario en un viaje que corre solo, sin entender qué pasó con el suyo.
    var camion = 0;
    var personalizado = 0;
    await pumpAt(
      tester,
      const Size(402, 874),
      onSearchStop: () => camion++,
      onCustomTrip: () => personalizado++,
    );

    await tester.tap(find.text('Paradas de bus disponibles'));
    await tester.pump();
    expect(camion, 1);
    expect(personalizado, 0);
  });

  testWidgets('el viaje personalizado vive en el menú, con los demás modos', (
    tester,
  ) async {
    var personalizado = 0;
    await pumpAt(
      tester,
      const Size(402, 874),
      onCustomTrip: () => personalizado++,
    );

    await tester.tap(find.text('Viaje personalizado...'));
    await tester.pump();
    expect(personalizado, 1);
  });

  group('el espacio publicitario', () {
    testWidgets('va debajo del buscador y mas angosto que el', (tester) async {
      // Un banner del mismo ancho compite con el buscador, que es la entrada al flujo
      // principal. Angosto y centrado se distingue como contenido de un tercero.
      await pumpAt(tester, const Size(402, 874));
      expectNoLayoutError(tester, 'publicidad');

      final card = tester.getRect(find.byType(SearchStopCard));
      final ad = tester.getRect(find.byType(AdSlotCard));

      expect(ad.top, greaterThanOrEqualTo(card.bottom));
      expect(ad.width, lessThan(card.width));
      // Centrado respecto a la tarjeta, no pegado a un lado.
      expect(ad.center.dx, closeTo(card.center.dx, 1));
    });

    testWidgets('no tapa la hoja ni se sale en pantalla chica', (tester) async {
      for (final size in [
        const Size(320, 568),
        const Size(360, 640),
        const Size(430, 932),
      ]) {
        await pumpAt(tester, size);
        expectNoLayoutError(tester, 'publicidad en ${size.width}');

        final ad = tester.getRect(find.byType(AdSlotCard));
        final sheet = tester.getRect(find.byType(TripSheet));
        expect(ad.left, greaterThanOrEqualTo(0));
        expect(ad.right, lessThanOrEqualTo(size.width));
        expect(ad.bottom, lessThan(sheet.top));
      }
    });

    testWidgets('aguanta tipografia al doble', (tester) async {
      await pumpAt(tester, const Size(360, 640), textScale: 2.0);
      expectNoLayoutError(tester, 'publicidad con texto grande');
    });

    testWidgets('responde al toque sin disparar el buscador', (tester) async {
      var ad = 0;
      var search = 0;
      await pumpAt(
        tester,
        const Size(402, 874),
        onAd: () => ad++,
        onSearchStop: () => search++,
      );

      await tester.tap(find.byType(AdSlotCard));
      await tester.pump();
      expect(ad, 1);
      expect(search, 0, reason: 'el anuncio no debe abrir el flujo de camion');
    });
  });

  group('la entrada de pago: MTAPP Plus', () {
    testWidgets('vive sobre la hoja, por la izquierda', (tester) async {
      // Es el hueco que quedaba libre del mapa. Pegado a la hoja y no al fondo de la pantalla,
      // para que no se lo trague cuando la hoja crece con el texto grande.
      await pumpAt(tester, const Size(402, 874));
      expectNoLayoutError(tester, 'boton de pago');

      final button = tester.getRect(find.byType(MapPillButton));
      final sheet = tester.getRect(find.byType(TripSheet));
      final card = tester.getRect(find.byType(SearchStopCard));

      expect(button.bottom, lessThanOrEqualTo(sheet.top));
      expect(button.top, greaterThan(card.bottom));
      expect(button.left, closeTo(gutterFor(402), 1));
      expect(button.right, lessThanOrEqualTo(402));
    });

    testWidgets('es uno solo y dice "MTAPP Plus"', (tester) async {
      // Las tres funciones de pago son el mismo dato mirado desde tres lados; dos botones
      // separados las vendian como productos que no se conocen entre si.
      var plus = 0;
      await pumpAt(tester, const Size(402, 874), onPlus: () => plus++);
      expectNoLayoutError(tester, 'toque del boton de pago');

      expect(find.byType(MapPillButton), findsOneWidget);
      expect(find.text('MTAPP Plus'), findsOneWidget);

      await tester.tap(find.byType(MapPillButton));
      await tester.pump();
      expect(plus, 1);
    });

    testWidgets('con tipografia al doble no se sale de la pantalla', (
      tester,
    ) async {
      await pumpAt(tester, const Size(360, 640), textScale: 2.0);
      expectNoLayoutError(tester, 'boton de pago con texto grande');

      final button = tester.getRect(find.byType(MapPillButton));
      final sheet = tester.getRect(find.byType(TripSheet));
      expect(button.bottom, lessThanOrEqualTo(sheet.top));
      expect(button.top, greaterThanOrEqualTo(0));
      expect(button.right, lessThanOrEqualTo(360));
    });
  });

  group('el diseno de Figma: mapa arriba, opciones en la hoja', () {
    testWidgets('el mapa va de fondo, a pantalla completa', (tester) async {
      await pumpAt(tester, const Size(402, 874));
      expectNoLayoutError(tester, 'mapa de fondo');

      expect(find.byType(AppMap), findsOneWidget);
      final map = tester.getRect(find.byType(AppMap));
      expect(map.width, closeTo(402, 1));
      expect(map.height, closeTo(874, 1));
    });

    testWidgets('la hoja no se come el mapa', (tester) async {
      await pumpAt(tester, const Size(402, 874));
      expectNoLayoutError(tester, 'alto de la hoja');

      // El Figma le da 212 de 874 (24%) a dos opciones; aquí van cuatro y apretadas, así que
      // crece — pero el mapa tiene que seguir siendo lo que más se ve.
      final sheet = tester.getRect(find.byType(TripSheet));
      expect(sheet.height / 874, lessThan(0.4));
      expect(sheet.bottom, closeTo(874, 1));
    });

    testWidgets('con tipografia al doble sigue sin taparlo todo', (
      tester,
    ) async {
      await pumpAt(tester, const Size(360, 640), textScale: 2.0);
      expectNoLayoutError(tester, 'hoja con texto grande');

      // La hoja se topa y su contenido rueda por dentro, en vez de crecer sin freno. En una
      // pantalla corta el tope es mayor —las cuatro opciones ocupan un alto fijo, que ahí es
      // una fracción más grande— pero nunca pasa de la mitad.
      final sheet = tester.getRect(find.byType(TripSheet));
      expect(sheet.height / 640, lessThanOrEqualTo(0.52));
      expect(find.byType(SingleChildScrollView), findsOneWidget);
    });

    testWidgets('las cuatro opciones caben sin tener que rodar la hoja', (
      tester,
    ) async {
      // La cuarta —el teleférico— es la que se salía: una opción que hay que descubrir
      // arrastrando es una opción que nadie encuentra.
      for (final size in [
        const Size(402, 874),
        const Size(360, 640),
        const Size(320, 568),
        const Size(430, 932),
      ]) {
        await pumpAt(tester, size);
        expectNoLayoutError(
          tester,
          'cuatro opciones en ${size.width}x${size.height}',
        );

        final last = tester.getRect(find.byType(TravelOptionTile).last);
        expect(
          last.bottom,
          lessThanOrEqualTo(size.height),
          reason: 'la última opción se sale en ${size.width}x${size.height}',
        );
      }
    });

    testWidgets('la tarjeta de buscar flota sobre el mapa, no en la hoja', (
      tester,
    ) async {
      await pumpAt(tester, const Size(402, 874));
      expectNoLayoutError(tester, 'tarjeta de busqueda');

      final card = tester.getRect(find.byType(SearchStopCard));
      final sheet = tester.getRect(find.byType(TripSheet));
      // Arriba del todo, como en el diseño, y sin tocar la hoja.
      expect(card.top, lessThan(874 * 0.3));
      expect(card.bottom, lessThan(sheet.top));
    });
  });
}
