import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:maas_morelia/data/walk_route.dart';
import 'package:maas_morelia/data/walk_trip.dart';
import 'package:maas_morelia/widgets/app_map.dart';
import 'package:maas_morelia/screens/walk_trip_screen.dart';
import 'package:maas_morelia/theme.dart';

/// La pantalla del viaje a pie.
///
/// El usuario arranca en la Catedral (posición por defecto del mockup). La línea recta hacia
/// las Tarascas cruza una zona marcada, así que el caso normal aquí es un rodeo.
void main() {
  const tarascas = LatLng(19.6989, -101.1789);

  /// Al oeste: sin zonas marcadas de por medio.
  const westOfCentro = LatLng(19.7010, -101.1900);

  /// A la vuelta de la esquina: llega en dos avances.
  const roundTheCorner = LatLng(19.7008, -101.18425);

  late ProviderContainer container;

  setUp(() => container = ProviderContainer());

  /// Apaga el timer del peatón simulado.
  ///
  /// Va en el cuerpo de la prueba y no en un `tearDown` porque `flutter_test` revisa que no
  /// queden timers pendientes **antes** de correr los teardowns.
  void stopWalking() => container.read(walkTripProvider.notifier).reset();

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

    container.read(walkTripProvider.notifier).start(destination);

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
            child: WalkTripScreen(onFinished: onFinished, onCancel: onCancel),
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

  group('WalkTripScreen se acomoda sin desbordarse', () {
    viewports.forEach((name, size) {
      testWidgets(name, (tester) async {
        await pumpAt(tester, size);
        expectNoLayoutError(tester, name);

        expect(find.text('A pie'), findsOneWidget);
        expect(find.textContaining('Tiempo estimado:'), findsOneWidget);
        stopWalking();
      });
    });
  });

  testWidgets('aguanta tipografía al doble por accesibilidad', (tester) async {
    await pumpAt(tester, const Size(360, 640), textScale: 2.0);
    expectNoLayoutError(tester, 'tipografía al doble');
    stopWalking();
  });

  testWidgets('dibuja todas las zonas marcadas, estorben o no', (tester) async {
    // Enseñar solo las que se rodearon dejaría creer que el resto del mapa se revisó y salió
    // limpio, que es justo lo que estos datos no pueden sostener.
    //
    // Se afirma sobre la capa y no sobre el texto porque el mapa descarta lo que cae fuera del
    // encuadre: una zona lejana está dibujada aunque no se alcance a ver.
    await pumpAt(tester, const Size(402, 874));
    expectNoLayoutError(tester, 'zonas');

    final map = tester.widget<AppMap>(find.byType(AppMap));
    expect(map.areas, hasLength(moreliaUnsafeZones.length));

    // Y cada una lleva su motivo escrito encima.
    final motivos = map.markers
        .map((marker) => marker.icon)
        .whereType<LabelMapIcon>()
        .map((icon) => icon.text);
    expect(motivos, contains('Tramo sin alumbrado'));
    stopWalking();
  });

  testWidgets('dice que rodeó y cuánto costó el rodeo', (tester) async {
    await pumpAt(tester, const Size(402, 874));
    expectNoLayoutError(tester, 'rodeo');

    expect(find.textContaining('Camino seguro · rodea'), findsOneWidget);
    expect(find.textContaining('más que la línea recta'), findsOneWidget);
    stopWalking();
  });

  testWidgets('sin zonas de paso lo dice, sin inventar un rodeo', (
    tester,
  ) async {
    await pumpAt(tester, const Size(402, 874), destination: westOfCentro);
    expectNoLayoutError(tester, 'sin zonas');

    expect(find.textContaining('sin zonas marcadas de paso'), findsOneWidget);
    expect(find.textContaining('más que la línea recta'), findsNothing);
    stopWalking();
  });

  testWidgets('avisa cuando no hay manera de evitar una zona', (tester) async {
    // Prometer un camino seguro hacia un punto que está dentro de una zona sería mentir.
    await pumpAt(
      tester,
      const Size(402, 874),
      destination: moreliaUnsafeZones.first.center,
    );
    expectNoLayoutError(tester, 'sin salida');

    expect(
      find.textContaining('cruza una zona no recomendada'),
      findsOneWidget,
    );
    expect(find.textContaining('Camino seguro'), findsNothing);
    stopWalking();
  });

  testWidgets('avisa que las zonas son simuladas', (tester) async {
    await pumpAt(tester, const Size(402, 874));
    expectNoLayoutError(tester, 'aviso de datos simulados');

    expect(find.textContaining('simuladas'), findsOneWidget);
    stopWalking();
  });

  testWidgets('enseña a quien camina y su destino', (tester) async {
    await pumpAt(tester, const Size(402, 874));
    expectNoLayoutError(tester, 'marcadores');

    expect(find.bySemanticsLabel('Vas aquí'), findsOneWidget);
    expect(find.bySemanticsLabel('Tu destino'), findsOneWidget);
    stopWalking();
  });

  testWidgets('al llegar ofrece terminar', (tester) async {
    var finished = false;
    await pumpAt(
      tester,
      const Size(402, 874),
      destination: roundTheCorner,
      onFinished: () => finished = true,
    );
    expectNoLayoutError(tester, 'llegada');

    await tester.pump(const Duration(milliseconds: 1200));
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
    stopWalking();
  });
}
