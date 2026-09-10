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
///
/// Y la única que llega en dos tiempos: propuesta quieta primero, en marcha solo cuando el
/// pasajero lo dice. Varias pruebas arrancan el viaje a mano por eso.
void main() {
  const bosque = LatLng(19.6917, -101.1770);

  late ProviderContainer container;

  ProviderContainer build({FakeApi? api}) => ProviderContainer(
    overrides: [
      apiClientProvider.overrideWithValue((api ?? FakeApi()).build()),
      reverseGeocoderProvider.overrideWithValue(FakeGeocoder()),
    ],
  );

  /// Echa a andar el viaje propuesto, como si se hubiera tocado "Iniciar viaje".
  void beginTrip() => container.read(journeyTripProvider.notifier).begin();

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

        expect(find.text('Iniciar viaje'), findsOneWidget);

        beginTrip();
        await tester.pump();
        expectNoLayoutError(tester, '$name en marcha');
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

    expect(find.text('Armando tu viaje'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpAndSettle();
    stopTrip();
  });

  testWidgets('enseña la alternativa más rápida y su tiempo', (tester) async {
    await pumpAt(tester, const Size(402, 874));
    expectNoLayoutError(tester, 'más rápida');

    expect(find.text('Más rápida'), findsOneWidget);
    // Propuesta: cuánto dura y en cuántos pasos. El reloj de llegada todavía no aplica.
    expect(find.text('5 min · 1 tramo'), findsOneWidget);

    beginTrip();
    await tester.pump();
    expect(find.text('Llegas en 5 min'), findsOneWidget);
    stopTrip();
  });

  testWidgets('no arranca solo: el itinerario llega propuesto, no en marcha', (
    tester,
  ) async {
    // El bug que esto cubre: el viaje se ponía en progreso en cuanto contestaba el servidor,
    // o sea antes de que el usuario dijera con qué medios acepta ir. Los cuatro medios por
    // omisión decidían el viaje por él.
    await pumpAt(tester, const Size(402, 874));
    expectNoLayoutError(tester, 'propuesta');

    expect(container.read(journeyTripProvider).stage, JourneyStage.planned);
    expect(find.text('Iniciar viaje'), findsOneWidget);
    expect(find.textContaining('Llegas en'), findsNothing);

    // Y sigue quieto por más que pase el tiempo: sin timer, nada avanza.
    await tester.pump(const Duration(seconds: 10));
    expect(container.read(journeyTripProvider).elapsedMinutes, 0);
    expect(container.read(journeyTripProvider).stage, JourneyStage.planned);
  });

  testWidgets('arranca al tocar "Iniciar viaje"', (tester) async {
    await pumpAt(tester, const Size(402, 874));
    expectNoLayoutError(tester, 'arranque');

    await tester.tap(find.text('Iniciar viaje'));
    await tester.pump(const Duration(seconds: 3));
    expectNoLayoutError(tester, 'arranque');

    expect(container.read(journeyTripProvider).stage, JourneyStage.traveling);
    expect(container.read(journeyTripProvider).elapsedMinutes, greaterThan(0));
    expect(find.text('Iniciar viaje'), findsNothing);
    stopTrip();
    await tester.pump();
  });

  testWidgets('cambiar de medios devuelve el viaje a la propuesta', (
    tester,
  ) async {
    // Un itinerario distinto es un viaje distinto: seguir corriendo sobre el nuevo sin que
    // nadie lo haya aprobado es el mismo problema, un paso después.
    await pumpAt(tester, const Size(402, 874));
    beginTrip();
    await tester.pump(const Duration(seconds: 3));
    expect(container.read(journeyTripProvider).stage, JourneyStage.traveling);

    // El teleférico, porque su etiqueta solo aparece en el chip: la bici también titula el
    // tramo del itinerario y `find.text` encontraría dos.
    await tester.tap(find.text('En teleférico'));
    await tester.pumpAndSettle();
    expectNoLayoutError(tester, 'cambio de medios');

    expect(container.read(journeyTripProvider).stage, JourneyStage.planned);
    expect(container.read(journeyTripProvider).elapsedMinutes, 0);
    expect(find.text('Iniciar viaje'), findsOneWidget);
  });

  testWidgets('cambiar de alternativa en la propuesta no la echa a andar', (
    tester,
  ) async {
    await pumpAt(tester, const Size(402, 874));

    await tester.tap(find.textContaining('Sin bicicleta'));
    await tester.pumpAndSettle();
    expectNoLayoutError(tester, 'alternativa en propuesta');

    expect(container.read(journeyTripProvider).stage, JourneyStage.planned);
    expect(find.text('Iniciar viaje'), findsOneWidget);
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
    beginTrip();
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

    beginTrip();
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

    beginTrip();
    await tester.pump();
    await tester.tap(find.text('cancelar'));
    await tester.pump();
    expect(cancelled, isTrue);
    stopTrip();
  });

  group('destino fuera de lo que alcanza la red', () {
    // El motor siempre devuelve un viaje —el peor caso es caminar todo— y con un destino al que
    // ninguna ruta se acerca eso son 5 minutos en bici y dos horas a pie. La pantalla lo
    // enseñaba como un itinerario cualquiera.
    testWidgets('lo dice antes del itinerario', (tester) async {
      await pumpAt(
        tester,
        const Size(402, 874),
        api: FakeApi(journeysJson: journeysBeyondNetworkPayload),
      );
      expectNoLayoutError(tester, 'fuera de la red');

      expect(find.text('Ninguna ruta llega hasta allá'), findsOneWidget);
      // Con la distancia real del tramo a pie, para que se entienda por qué.
      expect(find.textContaining('9.1 km a pie'), findsOneWidget);

      // El viaje se sigue enseñando: el punto es válido y los números son del servidor
      // (126.7 min redondeados).
      expect(find.textContaining('127 min'), findsOneWidget);
      stopTrip();
    });

    testWidgets('no sale en un viaje normal', (tester) async {
      await pumpAt(tester, const Size(402, 874));
      expectNoLayoutError(tester, 'viaje normal');

      expect(find.text('Ninguna ruta llega hasta allá'), findsNothing);
      stopTrip();
    });
  });
}
