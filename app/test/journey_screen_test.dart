import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:maas_morelia/data/journey_trip.dart';
import 'package:maas_morelia/data/providers.dart';
import 'package:maas_morelia/screens/journey_screen.dart';
import 'package:maas_morelia/theme.dart';

import 'support/fakes.dart';

/// La pantalla del viaje más rápido.
///
/// Es la única del viaje que espera a la red, así que lo primero que hay que verificar es que
/// diga que está esperando en vez de quedarse en blanco.
void main() {
  const bosque = LatLng(19.6917, -101.1770);

  late ProviderContainer container;

  ProviderContainer build({FakeApi? api}) => ProviderContainer(
    overrides: [
      apiClientProvider.overrideWithValue((api ?? FakeApi()).build()),
    ],
  );

  /// Apaga el timer del viaje simulado.
  ///
  /// Va en el cuerpo de la prueba porque `flutter_test` revisa que no queden timers pendientes
  /// **antes** de correr los teardowns.
  void stopTrip() => container.read(journeyTripProvider.notifier).reset();

  Future<void> pumpAt(
    WidgetTester tester,
    Size size, {
    FakeApi? api,
    double textScale = 1.0,
    bool settle = true,
    VoidCallback? onFinished,
    VoidCallback? onCancel,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    container = build(api: api);
    // Sin `await`: la pantalla tiene que servir mientras la peticion sigue en vuelo.
    container.read(journeyTripProvider.notifier).start(bosque);

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
            child: JourneyScreen(onFinished: onFinished, onCancel: onCancel),
          ),
        ),
      ),
    );
    if (settle) await tester.pumpAndSettle();
  }

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

  group('JourneyScreen se acomoda sin desbordarse', () {
    viewports.forEach((name, size) {
      testWidgets(name, (tester) async {
        await pumpAt(tester, size);
        expectNoLayoutError(tester, name);

        expect(find.textContaining('Llegas en'), findsOneWidget);
        stopTrip();
      });
    });
  });

  testWidgets('aguanta tipografía al doble por accesibilidad', (tester) async {
    await pumpAt(tester, const Size(360, 640), textScale: 2.0);
    expectNoLayoutError(tester, 'tipografía al doble');
    stopTrip();
  });

  testWidgets('mientras busca, lo dice', (tester) async {
    // Quedarse en blanco esperando a la red se siente a app colgada.
    await pumpAt(
      tester,
      const Size(402, 874),
      api: FakeApi(journeysDelay: const Duration(seconds: 1)),
      settle: false,
    );
    await tester.pump();
    expectNoLayoutError(tester, 'cargando');

    expect(find.text('Buscando la ruta más rápida'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpAndSettle();
    stopTrip();
  });

  testWidgets('enseña la alternativa más rápida y su tiempo', (tester) async {
    await pumpAt(tester, const Size(402, 874));
    expectNoLayoutError(tester, 'más rápida');

    expect(find.text('Más rápida'), findsOneWidget);
    expect(find.text('Llegas en 5 min'), findsOneWidget);
    stopTrip();
  });

  testWidgets('desglosa el itinerario tramo por tramo', (tester) async {
    // El valor de este modo no es el total, es saber qué hay que tomar y dónde cambiar.
    await pumpAt(tester, const Size(402, 874));
    expectNoLayoutError(tester, 'itinerario');

    container.read(journeyTripProvider.notifier).select(1);
    await tester.pumpAndSettle();

    expect(find.textContaining('Ruta Centro - Bosque'), findsWidgets);
    stopTrip();
  });

  testWidgets('deja cambiar de alternativa', (tester) async {
    await pumpAt(tester, const Size(402, 874));
    expectNoLayoutError(tester, 'alternativas');

    expect(find.textContaining('Sin bicicleta'), findsOneWidget);
    await tester.tap(find.textContaining('Sin bicicleta'));
    await tester.pumpAndSettle();
    expectNoLayoutError(tester, 'cambio de alternativa');

    expect(container.read(journeyTripProvider).selected, 1);
    stopTrip();
  });

  testWidgets('cambiar de alternativa reinicia el recorrido', (tester) async {
    // Seguir a mitad de camino de una ruta distinta no significa nada.
    await pumpAt(tester, const Size(402, 874));
    await tester.pump(const Duration(seconds: 3));
    expect(container.read(journeyTripProvider).elapsedMinutes, greaterThan(0));

    // Se lee el estado sin bombear: en cuanto pasa un frame el timer ya avanzó.
    container.read(journeyTripProvider.notifier).select(1);
    expect(container.read(journeyTripProvider).elapsedMinutes, 0);

    stopTrip();
    await tester.pump();
  });

  testWidgets('si el servidor no da un viaje, lo dice y ofrece volver', (
    tester,
  ) async {
    var back = false;
    await pumpAt(
      tester,
      const Size(402, 874),
      api: FakeApi(journeysJson: ''),
      onFinished: () => back = true,
    );
    expectNoLayoutError(tester, 'sin viaje');

    expect(find.text('No pudimos armar el viaje'), findsOneWidget);
    await tester.tap(find.text('Volver'));
    await tester.pump();
    expect(back, isTrue);
  });

  testWidgets('al llegar ofrece terminar', (tester) async {
    var finished = false;
    await pumpAt(
      tester,
      const Size(402, 874),
      onFinished: () => finished = true,
    );
    expectNoLayoutError(tester, 'llegada');

    await tester.pump(const Duration(seconds: 25));
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
