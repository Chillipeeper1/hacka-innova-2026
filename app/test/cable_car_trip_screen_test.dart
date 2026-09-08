import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:maas_morelia/data/cable_car_trip.dart';
import 'package:maas_morelia/screens/cable_car_trip_screen.dart';
import 'package:maas_morelia/theme.dart';

/// La pantalla del viaje en teleférico.
///
/// El usuario arranca en la Catedral (posición por defecto del mockup), a unos metros de la
/// Estación Centro de la Línea 1.
void main() {
  const acueducto = LatLng(19.6975, -101.1791);

  /// A 50 m: subir y bajar serían la misma estación, así que el teleférico no sirve.
  const roundTheCorner = LatLng(19.7012, -101.1844);

  late ProviderContainer container;

  setUp(() => container = ProviderContainer());

  /// Apaga el timer del viaje simulado.
  ///
  /// Va en el cuerpo de la prueba y no en un `tearDown` porque `flutter_test` revisa que no
  /// queden timers pendientes **antes** de correr los teardowns.
  void stopTrip() => container.read(cableCarTripProvider.notifier).reset();

  Future<void> pumpAt(
    WidgetTester tester,
    Size size, {
    LatLng destination = acueducto,
    double textScale = 1.0,
    VoidCallback? onFinished,
    VoidCallback? onCancel,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    container.read(cableCarTripProvider.notifier).start(destination);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: buildAppTheme(),
          home: MediaQuery(
            data: MediaQueryData(
              size: size,
              textScaler: TextScaler.linear(textScale),
            ),
            child: CableCarTripScreen(
              onFinished: onFinished,
              onCancel: onCancel,
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

  group('CableCarTripScreen se acomoda sin desbordarse', () {
    viewports.forEach((name, size) {
      testWidgets(name, (tester) async {
        await pumpAt(tester, size);
        expectNoLayoutError(tester, name);

        expect(find.textContaining('Tiempo estimado:'), findsOneWidget);
        stopTrip();
      });
    });
  });

  testWidgets('aguanta tipografía al doble por accesibilidad', (tester) async {
    await pumpAt(tester, const Size(360, 640), textScale: 2.0);
    expectNoLayoutError(tester, 'tipografía al doble');
    stopTrip();
  });

  testWidgets('dice en qué estación se sube y por qué', (tester) async {
    await pumpAt(tester, const Size(402, 874));
    expectNoLayoutError(tester, 'estación de subida');

    expect(find.text('Subes en Estación Centro'), findsOneWidget);
    expect(
      find.textContaining('La estación más cercana a ti'),
      findsOneWidget,
    );
    stopTrip();
  });

  testWidgets('dice en qué estación se baja y qué tan cerca deja', (
    tester,
  ) async {
    await pumpAt(tester, const Size(402, 874));
    expectNoLayoutError(tester, 'estación de bajada');

    expect(find.text('Bajas en Estación Acueducto'), findsOneWidget);
    expect(find.textContaining('La que te deja más cerca'), findsOneWidget);
    stopTrip();
  });

  testWidgets('el título sigue el tramo en el que se va', (tester) async {
    await pumpAt(tester, const Size(402, 874));
    expectNoLayoutError(tester, 'tramo inicial');

    // Arranca caminando a la estación...
    expect(find.text('Caminando a la estación'), findsOneWidget);

    // ...y al subirse, lo dice.
    await tester.pump(const Duration(seconds: 3));
    expectNoLayoutError(tester, 'tramo en cabina');
    expect(find.text('En el teleférico'), findsOneWidget);
    stopTrip();
  });

  testWidgets('avisa que las estaciones son simuladas', (tester) async {
    await pumpAt(tester, const Size(402, 874));
    expectNoLayoutError(tester, 'aviso de datos simulados');

    expect(find.textContaining('simuladas'), findsOneWidget);
    stopTrip();
  });

  testWidgets('enseña al pasajero y su destino en el mapa', (tester) async {
    await pumpAt(tester, const Size(402, 874));
    expectNoLayoutError(tester, 'marcadores');

    expect(find.bySemanticsLabel('Vas aquí'), findsOneWidget);
    expect(find.bySemanticsLabel('Tu destino'), findsOneWidget);
    stopTrip();
  });

  testWidgets('cuando ninguna línea sirve, lo dice', (tester) async {
    // Mandar a una pantalla vacía —o inventar una estación lejana— haría caminar para nada.
    await pumpAt(
      tester,
      const Size(402, 874),
      destination: roundTheCorner,
      onFinished: () {},
    );
    expectNoLayoutError(tester, 'sin servicio');

    expect(find.text('Sin ruta en teleférico'), findsOneWidget);
    expect(find.text('Volver'), findsOneWidget);
    expect(find.textContaining('Tiempo estimado:'), findsNothing);
  });

  testWidgets('al llegar ofrece terminar', (tester) async {
    var finished = false;
    await pumpAt(
      tester,
      const Size(402, 874),
      onFinished: () => finished = true,
    );
    expectNoLayoutError(tester, 'llegada');

    await tester.pump(const Duration(seconds: 20));
    expectNoLayoutError(tester, 'llegada');

    expect(find.text('Llegaste'), findsOneWidget);
    expect(find.text('cancelar'), findsNothing);

    await tester.tap(find.text('Terminar'));
    await tester.pump();
    expect(finished, isTrue);
  });

  testWidgets('se puede abandonar el viaje a medias', (tester) async {
    var cancelled = false;
    await pumpAt(
      tester,
      const Size(402, 874),
      onCancel: () => cancelled = true,
    );
    expectNoLayoutError(tester, 'cancelar');

    await tester.tap(find.text('cancelar'));
    await tester.pump();
    expect(cancelled, isTrue);
    stopTrip();
  });
}
