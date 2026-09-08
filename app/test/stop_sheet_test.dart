import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:maas_morelia/data/models.dart';
import 'package:maas_morelia/data/providers.dart';
import 'package:maas_morelia/data/trip_draft.dart';
import 'package:maas_morelia/theme.dart';
import 'package:maas_morelia/widgets/stop_sheet.dart';

import 'support/fakes.dart';

/// Escenario 2 de `CLAUDE.md`: el pasajero ve el ETA y confirma si va a abordar.
///
/// El destino se declara **antes** de abordar. Una confirmación suelta solo dice que alguien
/// espera en un punto; con origen y destino se sabe qué tramo del corredor se va a ocupar.
void main() {
  /// La parada de la Catedral tal como la publica la ruta 1.
  const catedralRuta1 = Stop(
    id: 1,
    name: 'Catedral de Morelia',
    lat: 19.7008,
    lng: -101.1844,
    sequence: 1,
  );

  /// Junto al Bosque Cuauhtémoc, que solo sirve la ruta 2.
  const destinoBosque = LatLng(19.6920, -101.1772);

  Future<ProviderContainer> makeContainer({FakeApi? api}) async {
    final container = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWithValue((api ?? FakeApi()).build()),
        realtimeClientProvider.overrideWithValue(FakeRealtimeClient()),
      ],
    );
    addTearDown(container.dispose);
    await container.read(routesProvider.future);
    return container;
  }

  /// Abre la hoja y entrega el resultado por [onResult].
  ///
  /// No devuelve el Future de `StopSheet.show`: esperarlo fuera dejaría dos APIs guardadas de
  /// `WidgetTester` solapadas.
  Future<void> openSheet(
    WidgetTester tester, {
    required ProviderContainer container,
    Stop stop = catedralRuta1,
    void Function(bool?)? onResult,
    VoidCallback? onSetDestination,
  }) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: buildAppTheme(),
          home: Scaffold(
            body: Builder(
              builder:
                  (context) => Center(
                    child: ElevatedButton(
                      onPressed: () async {
                        // Primero abrir, luego avisar: con `onResult?.call(await ...)` Dart
                        // corta la expresión completa si el callback es null.
                        final result = await StopSheet.show(
                          context,
                          stop: stop,
                          routeId: 1,
                          onSetDestination: onSetDestination,
                        );
                        onResult?.call(result);
                      },
                      child: const Text('abrir'),
                    ),
                  ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
  }

  group('sin destino declarado', () {
    testWidgets('no deja abordar y pide el destino primero', (tester) async {
      final container = await makeContainer();
      await openSheet(tester, container: container);

      expect(find.text('Primero dinos a dónde vas'), findsOneWidget);
      expect(find.text('Voy a abordar'), findsNothing);
      expect(find.text('Solo paso'), findsNothing);
      expect(find.text('¿A dónde vas?'), findsOneWidget);
    });

    testWidgets('el ETA se muestra igual: verlo no requiere destino', (
      tester,
    ) async {
      final container = await makeContainer(
        api: FakeApi(
          etaJson:
              '{"stop_id":1,"route_id":1,"vehicle_id":1,'
              '"distance_km":0.573,"eta_minutes":2.3}',
        ),
      );
      await openSheet(tester, container: container);

      expect(find.textContaining('Llega en 2 min'), findsOneWidget);
    });

    testWidgets('"¿A dónde vas?" cierra la hoja y abre el selector', (
      tester,
    ) async {
      var opened = 0;
      final container = await makeContainer();
      await openSheet(
        tester,
        container: container,
        onSetDestination: () => opened++,
      );

      await tester.tap(find.text('¿A dónde vas?'));
      await tester.pumpAndSettle();

      expect(opened, 1);
      expect(find.byType(StopSheet), findsNothing);
    });
  });

  group('con destino declarado', () {
    Future<ProviderContainer> containerConDestino({FakeApi? api}) async {
      final container = await makeContainer(api: api);
      container.read(tripDraftProvider.notifier).setDestination(destinoBosque);
      return container;
    }

    testWidgets('muestra qué ruta toma y dónde se baja', (tester) async {
      final container = await containerConDestino();
      await openSheet(tester, container: container);

      expect(find.textContaining('Ruta Centro - Bosque'), findsOneWidget);
      expect(find.textContaining('Bosque Cuauhtémoc'), findsOneWidget);
      expect(find.textContaining('caminas'), findsOneWidget);
      expect(find.text('Voy a abordar'), findsOneWidget);
    });

    testWidgets('manda la parada y la ruta del viaje, no las del marcador', (
      tester,
    ) async {
      // Se tocó el marcador de la Catedral que publica la ruta 1 (stop 1), pero el viaje va
      // por la ruta 2, donde esa misma parada física es la 4. Al servidor tiene que llegar la
      // ruta que realmente se va a viajar.
      final api = FakeApi();
      final container = await containerConDestino(api: api);
      await openSheet(tester, container: container);

      await tester.tap(find.text('Voy a abordar'));
      await tester.pumpAndSettle();

      final sent = api.requests.where((r) => r.path == '/boarding-signals');
      expect(sent.single.body, {
        'user_id': 7,
        'stop_id': 4,
        'route_id': 2,
        'intent': 'boarding',
      });
    });

    testWidgets('"solo paso" también viaja con el contexto del viaje', (
      tester,
    ) async {
      final api = FakeApi();
      final container = await containerConDestino(api: api);
      final results = <bool?>[];
      await openSheet(tester, container: container, onResult: results.add);

      await tester.tap(find.text('Solo paso'));
      await tester.pumpAndSettle();

      final sent = api.requests.where((r) => r.path == '/boarding-signals');
      expect(sent.single.body!['intent'], 'passing');
      expect(sent.single.body!['route_id'], 2);
      expect(results.single, isFalse);
    });

    testWidgets('avisa si la parada tocada no lleva al destino', (
      tester,
    ) async {
      const acueducto = Stop(
        id: 3,
        name: 'Acueducto de Morelia',
        lat: 19.6975,
        lng: -101.1791,
        sequence: 3,
      );

      final container = await containerConDestino();
      await openSheet(tester, container: container, stop: acueducto);

      expect(find.text('Esta parada no va hacia tu destino'), findsOneWidget);
      expect(find.text('Voy a abordar'), findsNothing);
    });

    testWidgets('si el servidor rechaza, lo dice y no cierra', (tester) async {
      final container = await containerConDestino(
        api: FakeApi(boardingStatusCode: 400),
      );
      await openSheet(tester, container: container);

      await tester.tap(find.text('Voy a abordar'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('No pudimos registrar tu respuesta'),
        findsOneWidget,
      );
      expect(find.text('Voy a abordar'), findsOneWidget);
    });
  });

  testWidgets('un destino sin ruta cercana lo dice en vez de dejar abordar', (
    tester,
  ) async {
    final container = await makeContainer();
    container
        .read(tripDraftProvider.notifier)
        .setDestination(const LatLng(19.7600, -101.2600));

    await openSheet(tester, container: container);

    expect(find.text('Ninguna ruta llega cerca de ese destino'), findsOneWidget);
    expect(find.text('Voy a abordar'), findsNothing);
    expect(find.text('Cambiar destino'), findsOneWidget);
  });

  testWidgets('muestra el conteo de gente esperando', (tester) async {
    final container = await makeContainer(
      api: FakeApi(demandJson: '[{"stop_id":1,"waiting_count":4}]'),
    );
    await openSheet(tester, container: container);

    expect(find.text('4 personas esperando aquí'), findsOneWidget);
  });
}
