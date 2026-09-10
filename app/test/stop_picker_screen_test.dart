import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:maas_morelia/data/providers.dart';
import 'package:maas_morelia/data/trip_plan.dart';
import 'package:maas_morelia/screens/stop_picker_screen.dart';
import 'package:maas_morelia/theme.dart';
import 'package:maas_morelia/widgets/trip_widgets.dart';

import 'support/fakes.dart';

/// Pantalla del nodo 32:392: "Paradas de bus cerca de ti".
void main() {
  const destinoBosque = LatLng(19.6920, -101.1772);

  Future<ProviderContainer> containerConDestino({
    FakeApi? api,
    LatLng destination = destinoBosque,
  }) async {
    final container = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWithValue((api ?? FakeApi()).build()),
        realtimeClientProvider.overrideWithValue(FakeRealtimeClient()),
      ],
    );
    addTearDown(container.dispose);
    await container.read(routesProvider.future);
    // El conteo de demanda alimenta el indicador de gente.
    await container.read(demandProvider.future);
    container.read(tripPlanProvider.notifier).setDestination(destination);
    return container;
  }

  Future<void> pump(
    WidgetTester tester,
    ProviderContainer container, {
    Size size = const Size(402, 874),
    double textScale = 1.0,
    void Function(BoardingOption)? onChoose,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

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
            child: StopPickerScreen(onChoose: onChoose),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 10));
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
    'lienzo del diseño': Size(402, 874),
    'tablet horizontal': Size(1024, 768),
    'escritorio / web': Size(1440, 900),
  };

  group('se acomoda sin desbordarse', () {
    viewports.forEach((name, size) {
      testWidgets(name, (tester) async {
        final container = await containerConDestino();
        await pump(tester, container, size: size);
        expectNoLayoutError(tester, name);

        expect(find.text('Paradas de bus cerca de ti'), findsOneWidget);
      });
    });
  });

  testWidgets('aguanta tipografía al doble', (tester) async {
    final container = await containerConDestino();
    await pump(tester, container, size: const Size(360, 640), textScale: 2.0);
    expectNoLayoutError(tester, 'tipografía al doble');
  });

  testWidgets('lista las paradas candidatas con su gente esperando', (
    tester,
  ) async {
    final container = await containerConDestino(
      api: FakeApi(demandJson: '[{"stop_id":4,"waiting_count":12}]'),
    );
    await pump(tester, container);
    expectNoLayoutError(tester, 'lista');

    expect(find.byType(StopListTile), findsWidgets);
    expect(find.textContaining('12 personas aprox.'), findsOneWidget);
  });

  testWidgets('dice qué tan cerca del destino deja cada opción', (
    tester,
  ) async {
    // El diseño solo muestra el nombre y la gente; sin la distancia, la lista no permite
    // distinguir una parada que deja en la puerta de otra que deja a un kilómetro.
    final container = await containerConDestino();
    await pump(tester, container);
    expectNoLayoutError(tester, 'distancias');

    expect(find.textContaining('Te deja a'), findsWidgets);
    expect(find.textContaining('caminas'), findsWidgets);
  });

  testWidgets('la primera opción es la que deja más cerca del destino', (
    tester,
  ) async {
    final container = await containerConDestino();
    final options = container.read(tripPlanProvider).options;

    await pump(tester, container);
    expectNoLayoutError(tester, 'orden');

    final tiles = tester.widgetList<StopListTile>(find.byType(StopListTile));
    expect(tiles.first.title, options.first.boardingStop.name);
    expect(options.first.alightingStop.name, 'Bosque Cuauhtémoc');
  });

  testWidgets('elegir una opción la entrega al flujo', (tester) async {
    BoardingOption? chosen;
    final container = await containerConDestino();
    await pump(tester, container, onChoose: (option) => chosen = option);
    expectNoLayoutError(tester, 'elección');

    await tester.tap(find.byType(StopListTile).first);
    await tester.pump();

    expect(chosen, isNotNull);
    expect(chosen!.route.id, 2, reason: 'la ruta que llega al Bosque');
  });

  testWidgets('un destino sin cobertura lo dice en vez de listar vacío', (
    tester,
  ) async {
    final container = await containerConDestino(
      destination: const LatLng(19.7600, -101.2600),
    );
    await pump(tester, container);
    expectNoLayoutError(tester, 'sin cobertura');

    expect(find.byType(StopListTile), findsNothing);
    expect(
      find.textContaining('Ninguna de las rutas del catálogo'),
      findsOneWidget,
    );
  });

  group('etiqueta de servicio', () {
    testWidgets('distingue una combi de un camión', (tester) async {
      final container = await containerConDestino();
      await pump(tester, container);

      // El seed tiene la ruta 1 como combi y la 2 como camión, y para este destino la app
      // ofrece paradas de las dos. Lo que se prueba no es que haya etiqueta, sino que
      // **distinga**: sin esto las dos paradas se ven idénticas y no hay cómo saber qué llega.
      final options = container.read(tripPlanProvider).options;
      expect(
        options.map((o) => o.route.mode).toSet(),
        containsAll(['combi', 'bus']),
      );

      expect(find.text('Combi'), findsWidgets);
      expect(find.text('Camión'), findsWidgets);
    });

    testWidgets('la etiqueta usa el color de su ruta', (tester) async {
      final container = await containerConDestino();
      await pump(tester, container);

      final badges = tester.widgetList<ServiceBadge>(find.byType(ServiceBadge));
      expect(badges, isNotEmpty);
      // Cada etiqueta lleva el color de la ruta a la que pertenece, no uno genérico.
      final combi = badges.firstWhere((b) => b.mode == 'combi');
      final bus = badges.firstWhere((b) => b.mode == 'bus');
      expect(combi.color, isNot(bus.color));
    });

    testWidgets('un modo desconocido no inventa etiqueta', (tester) async {
      // `JourneyMode.fromWire` cae a "a pie" ante un modo que no conoce, y eso pegado a la
      // parada de un camión sería peor que no poner nada.
      final container = await containerConDestino(
        api: FakeApi(
          routesJson: routesPayload.replaceFirst(
            '"mode":"combi"',
            '"mode":"tranvia"',
          ),
        ),
      );
      await pump(tester, container);

      expect(find.text('A pie'), findsNothing);
      expect(find.text('Camión'), findsWidgets);
    });
  });
}
