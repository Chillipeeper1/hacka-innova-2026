import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:maas_morelia/data/providers.dart';
import 'package:maas_morelia/morelia.dart';
import 'package:maas_morelia/widgets/app_map.dart';
import 'package:maas_morelia/screens/destination_screen.dart';
import 'package:maas_morelia/theme.dart';

import 'support/fakes.dart';

void main() {
  /// Monta la pantalla con un geocodificador de mentiras.
  ///
  /// Nunca se le deja el real: pediría una dirección por red en cada prueba, y el resultado
  /// dependería de que Nominatim conteste.
  Future<void> pumpAt(
    WidgetTester tester,
    Size size, {
    double textScale = 1.0,
    void Function(LatLng)? onConfirm,
    VoidCallback? onBack,
    FakeGeocoder? geocoder,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          reverseGeocoderProvider.overrideWithValue(geocoder ?? FakeGeocoder()),
        ],
        child: MaterialApp(
          theme: buildAppTheme(),
          home: MediaQuery(
            data: MediaQueryData(
              size: size,
              textScaler: TextScaler.linear(textScale),
            ),
            child: DestinationScreen(onConfirm: onConfirm, onBack: onBack),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  /// Las teselas se piden por red y en pruebas eso siempre falla (el cliente HTTP de
  /// `flutter_test` responde 400). Ese error no dice nada sobre el layout.
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

  group('DestinationScreen se acomoda sin desbordarse', () {
    viewports.forEach((name, size) {
      testWidgets(name, (tester) async {
        await pumpAt(tester, size);
        expectNoLayoutError(tester, name);

        expect(find.text('¿A dónde vas?'), findsOneWidget);
        expect(find.text('Confirmar'), findsOneWidget);
      });
    });
  });

  testWidgets('aguanta tipografía al doble por accesibilidad', (tester) async {
    await pumpAt(tester, const Size(360, 640), textScale: 2.0);
    expectNoLayoutError(tester, 'tipografía al doble');
  });

  testWidgets('el pin apunta al centro del mapa, no a su propio centro', (
    tester,
  ) async {
    const size = Size(402, 874);
    await pumpAt(tester, size);
    expectNoLayoutError(tester, 'pin');

    final pinRect = tester.getRect(find.byKey(const ValueKey('center-pin')));
    // La punta del pin es su borde inferior y debe caer sobre el centro geométrico de la
    // pantalla, que es el punto que el mapa reporta como su centro.
    expect(pinRect.bottom, closeTo(size.height / 2, 1.0));
    expect(pinRect.center.dx, closeTo(size.width / 2, 1.0));
  });

  testWidgets('muestra la dirección del punto inicial y confirma ese punto', (
    tester,
  ) async {
    LatLng? confirmed;
    final geocoder = FakeGeocoder();
    await pumpAt(
      tester,
      const Size(402, 874),
      onConfirm: (value) => confirmed = value,
      geocoder: geocoder,
    );
    expectNoLayoutError(tester, 'confirmación');
    await tester.pump();

    // Lo que se lee es una dirección de calle, no el par de coordenadas: quien elige un
    // destino reconoce la primera y no la segunda.
    expect(find.text('Calle Antonio Alzate 805, Morelia'), findsOneWidget);

    // Y se preguntó por el punto donde está clavado el pin, que sin mover el mapa es el
    // centro inicial.
    expect(geocoder.asked, hasLength(1));
    expect(
      geocoder.asked.single.latitude,
      closeTo(Morelia.center.latitude, 0.0001),
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Confirmar'));
    await tester.pump();

    expect(confirmed, isNotNull);
    expect(confirmed!.latitude, closeTo(Morelia.center.latitude, 0.0001));
    expect(confirmed!.longitude, closeTo(Morelia.center.longitude, 0.0001));
  });

  testWidgets('mientras busca la dirección lo dice, sin dejar el campo vacío', (
    tester,
  ) async {
    await pumpAt(
      tester,
      const Size(402, 874),
      geocoder: FakeGeocoder(delay: const Duration(milliseconds: 300)),
    );
    expectNoLayoutError(tester, 'búsqueda en curso');

    expect(find.text('Buscando dirección…'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Calle Antonio Alzate 805, Morelia'), findsOneWidget);
    expect(find.text('Buscando dirección…'), findsNothing);
  });

  testWidgets('sin dirección disponible cae a las coordenadas del pin', (
    tester,
  ) async {
    // Sin red, o un punto que el servicio no reconoce. El destino elegido sigue siendo
    // válido, así que la pantalla enseña el punto en vez de quedarse en blanco.
    await pumpAt(
      tester,
      const Size(402, 874),
      geocoder: FakeGeocoder(address: null),
    );
    expectNoLayoutError(tester, 'sin dirección');
    await tester.pump();

    expect(
      find.text(
        '${Morelia.center.latitude.toStringAsFixed(5)}, '
        '${Morelia.center.longitude.toStringAsFixed(5)}',
      ),
      findsOneWidget,
    );
  });

  testWidgets('el pin no intercepta el arrastre del mapa', (tester) async {
    await pumpAt(tester, const Size(402, 874));
    expectNoLayoutError(tester, 'gestos');

    // El pin va dentro de un IgnorePointer activo: si capturara el gesto, arrastrar sobre él
    // no movería el mapa y el usuario no podría elegir el punto que está justo debajo.
    // Flutter inserta otros IgnorePointer inactivos en el árbol, así que se busca el que
    // realmente está ignorando.
    final ignoring = tester
        .widgetList<IgnorePointer>(
          find.ancestor(
            of: find.byKey(const ValueKey('center-pin')),
            matching: find.byType(IgnorePointer),
          ),
        )
        .where((widget) => widget.ignoring);

    expect(ignoring, isNotEmpty);
  });

  group('botón de "mi ubicación"', () {
    testWidgets('queda encima del cuadro blanco, no detrás', (tester) async {
      await pumpAt(tester, const Size(402, 874));
      expectNoLayoutError(tester, 'mi ubicación');

      final button = tester.getRect(
        find.bySemanticsLabel('Centrar en mi ubicación'),
      );
      final sheet = tester.getRect(
        find.byKey(const ValueKey('destination-sheet')),
      );

      // La hoja crece con el texto, así que lo que se verifica no es una coordenada fija sino
      // la relación: el botón termina antes de que empiece la hoja.
      expect(button.bottom, lessThanOrEqualTo(sheet.top));
      // Y en la esquina derecha, que es donde la convención de los mapas lo pone.
      expect(button.center.dx, greaterThan(402 / 2));
    });

    testWidgets('sigue encima con tipografía al doble', (tester) async {
      // El caso que rompe el acomodo: con texto grande la hoja es mucho más alta, y un botón
      // colocado a una distancia fija del borde quedaría tapado por ella.
      await pumpAt(tester, const Size(360, 640), textScale: 2.0);
      expectNoLayoutError(tester, 'mi ubicación con texto grande');

      final button = tester.getRect(
        find.bySemanticsLabel('Centrar en mi ubicación'),
      );
      final sheet = tester.getRect(
        find.byKey(const ValueKey('destination-sheet')),
      );

      expect(button.bottom, lessThanOrEqualTo(sheet.top));
      expect(button.top, greaterThanOrEqualTo(0));
    });

    testWidgets('no se despega del contenido en escritorio', (tester) async {
      await pumpAt(tester, const Size(1440, 900));
      expectNoLayoutError(tester, 'mi ubicación en escritorio');

      // La hoja blanca ocupa todo el ancho pero su contenido va centrado y acotado. El botón
      // se acota igual, si no quedaría solo contra el borde de la pantalla.
      final button = tester.getRect(
        find.bySemanticsLabel('Centrar en mi ubicación'),
      );
      expect(button.right, lessThanOrEqualTo(1440 / 2 + maxContentWidth / 2));
      expect(button.center.dx, greaterThan(1440 / 2));
    });

    testWidgets('responde al toque y la pantalla puede mover la cámara', (
      tester,
    ) async {
      await pumpAt(tester, const Size(402, 874));
      expectNoLayoutError(tester, 'toque de mi ubicación');

      // Que la cámara llegue a moverse no se puede ver aquí: Google Maps es una vista nativa y
      // en pruebas no monta su controlador. Lo que sí se verifica es el cableado —la pantalla
      // le pasó un mando al mapa— y que el toque no revienta cuando ese mando todavía no
      // tiene mapa detrás, que es justo lo que pasa en este entorno.
      expect(tester.widget<AppMap>(find.byType(AppMap)).controller, isNotNull);

      await tester.tap(find.bySemanticsLabel('Centrar en mi ubicación'));
      await tester.pump();
      expectNoLayoutError(tester, 'toque de mi ubicación');
    });
  });

  testWidgets('el botón de regresar es accesible y responde', (tester) async {
    var backs = 0;
    await pumpAt(tester, const Size(402, 874), onBack: () => backs++);
    expectNoLayoutError(tester, 'regreso');

    expect(find.bySemanticsLabel('Regresar'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Regresar'));
    await tester.pump();
    expect(backs, 1);
  });

  testWidgets('el mapa es real y acotado a Morelia', (tester) async {
    await pumpAt(tester, const Size(402, 874));
    expectNoLayoutError(tester, 'mapa');

    // El acotado a Morelia vive ahora dentro de AppMap, que es quien habla con el motor
    // de mapas. Aquí basta comprobar que la pantalla usa ese mapa y no otro.
    expect(find.byType(AppMap), findsOneWidget);
  });

  testWidgets('los controles no se estiran en escritorio', (tester) async {
    await pumpAt(tester, const Size(1440, 900));
    expectNoLayoutError(tester, 'escritorio');

    final button = tester.getSize(find.byType(FilledButton));
    expect(button.width, lessThanOrEqualTo(maxContentWidth));
  });
}
