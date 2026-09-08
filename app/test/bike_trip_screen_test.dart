import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:maas_morelia/data/bike_trip.dart';
import 'package:maas_morelia/widgets/app_map.dart';
import 'package:maas_morelia/screens/bike_trip_screen.dart';
import 'package:maas_morelia/theme.dart';

/// La pantalla del viaje en bici.
///
/// El usuario arranca en la Catedral (posición por defecto del mockup), que cae sobre la
/// ciclovía de Madero — así que el caso normal aquí es un viaje protegido.
void main() {
  const tarascas = LatLng(19.6989, -101.1789);

  /// 300 m al norte del centro: ninguna ciclovía va para allá.
  const northOfCentro = LatLng(19.7035, -101.1844);

  /// A la vuelta de la esquina: llega en el primer avance.
  const roundTheCorner = LatLng(19.7008, -101.1841);

  late ProviderContainer container;

  setUp(() => container = ProviderContainer());

  /// Apaga el timer del ciclista simulado.
  ///
  /// Va en el cuerpo de la prueba y no en un `tearDown` porque `flutter_test` revisa que no
  /// queden timers pendientes **antes** de correr los teardowns.
  void stopRiding() => container.read(bikeTripProvider.notifier).reset();

  Future<void> pumpAt(
    WidgetTester tester,
    Size size, {
    LatLng destination = tarascas,
    double textScale = 1.0,
    VoidCallback? onFinished,
    VoidCallback? onCancel,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    container.read(bikeTripProvider.notifier).start(destination);

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
            child: BikeTripScreen(onFinished: onFinished, onCancel: onCancel),
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

  group('BikeTripScreen se acomoda sin desbordarse', () {
    viewports.forEach((name, size) {
      testWidgets(name, (tester) async {
        await pumpAt(tester, size);
        expectNoLayoutError(tester, name);

        expect(find.text('En bici'), findsOneWidget);
        expect(find.textContaining('Tiempo estimado:'), findsOneWidget);
        stopRiding();
      });
    });
  });

  testWidgets('aguanta tipografía al doble por accesibilidad', (tester) async {
    await pumpAt(tester, const Size(360, 640), textScale: 2.0);
    expectNoLayoutError(tester, 'tipografía al doble');
    stopRiding();
  });

  testWidgets('la línea trazada dice que va por ciclovía', (tester) async {
    await pumpAt(tester, const Size(402, 874));
    expectNoLayoutError(tester, 'etiqueta de ciclovía');

    // Pegada a la línea, sobre el mapa: es la línea la que tiene que explicarse sola.
    // Google Maps dibuja los marcadores como imagen, así que se afirma sobre lo que la
    // pantalla le pide al mapa, no sobre un widget de texto que ya no existe.
    final map = tester.widget<AppMap>(find.byType(AppMap));
    final etiquetas = map.markers
        .map((marker) => marker.icon)
        .whereType<LabelMapIcon>()
        .map((icon) => icon.text);
    expect(etiquetas, contains('Ruta por ciclovía'));

    // Y en la hoja, con el nombre de la ciclovía que se está usando.
    expect(
      find.textContaining('Ruta por ciclovía · Ciclovía Av. Madero'),
      findsOneWidget,
    );
    stopRiding();
  });

  testWidgets('el tiempo estimado sale de la velocidad de la bici', (
    tester,
  ) async {
    await pumpAt(tester, const Size(402, 874));
    expectNoLayoutError(tester, 'tiempo estimado');

    final trip = container.read(bikeTripProvider);
    expect(
      find.text('Tiempo estimado: ${trip.remainingMinutes} min'),
      findsOneWidget,
    );
    stopRiding();
  });

  testWidgets('no dice "por ciclovía" cuando no la hay', (tester) async {
    // Prometer infraestructura que el trazado no usa sería peor que no ofrecer el modo.
    await pumpAt(tester, const Size(402, 874), destination: northOfCentro);
    expectNoLayoutError(tester, 'sin ciclovía');

    expect(find.text('Ruta por ciclovía'), findsNothing);
    expect(find.textContaining('Ruta directa'), findsOneWidget);
    stopRiding();
  });

  testWidgets('avisa que las ciclovías son simuladas', (tester) async {
    // El dato es inventado; quien vea la demo tiene que saberlo.
    await pumpAt(tester, const Size(402, 874));
    expectNoLayoutError(tester, 'aviso de datos simulados');

    expect(find.textContaining('simuladas'), findsOneWidget);
    stopRiding();
  });

  testWidgets('enseña al ciclista y su destino en el mapa', (tester) async {
    await pumpAt(tester, const Size(402, 874));
    expectNoLayoutError(tester, 'marcadores');

    expect(find.bySemanticsLabel('Vas aquí'), findsOneWidget);
    expect(find.bySemanticsLabel('Tu destino'), findsOneWidget);
    stopRiding();
  });

  testWidgets('al llegar ofrece terminar y vuelve al inicio', (tester) async {
    var finished = false;
    await pumpAt(
      tester,
      const Size(402, 874),
      destination: roundTheCorner,
      onFinished: () => finished = true,
    );
    expectNoLayoutError(tester, 'llegada');

    await tester.pump(const Duration(milliseconds: 600));
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
    stopRiding();
  });
}
