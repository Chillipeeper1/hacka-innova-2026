import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maas_morelia/data/models.dart';
import 'package:maas_morelia/data/providers.dart';
import 'package:maas_morelia/theme.dart';
import 'package:maas_morelia/widgets/stop_sheet.dart';

import 'support/fakes.dart';

/// Escenario 2 de `CLAUDE.md`: el pasajero ve el ETA y confirma si va a abordar.
///
/// Es el diferenciador del proyecto — la señal de demanda no viene de GPS en las unidades
/// sino de esta respuesta — así que aquí se verifica que la intención sale con la forma exacta
/// que espera `POST /boarding-signals`.
void main() {
  const stop = Stop(
    id: 1,
    name: 'Catedral de Morelia',
    lat: 19.7008,
    lng: -101.1844,
    sequence: 1,
  );

  late FakeRealtimeClient realtime;

  setUp(() => realtime = FakeRealtimeClient());

  /// Abre la hoja y entrega el resultado por [onResult].
  ///
  /// No devuelve el Future de `StopSheet.show` porque esperar por él fuera de `openSheet`
  /// dejaría dos APIs guardadas de `WidgetTester` solapadas.
  Future<void> openSheet(
    WidgetTester tester, {
    FakeApi? api,
    void Function(bool?)? onResult,
  }) async {
    tester.view.physicalSize = const Size(402, 874);
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
          home: Scaffold(
            body: Builder(
              builder:
                  (context) => Center(
                    child: ElevatedButton(
                      onPressed: () async {
                        // Primero abrir, luego avisar: con `onResult?.call(await ...)` Dart
                        // corta la expresión completa cuando el callback es null y la hoja
                        // nunca llegaría a abrirse.
                        final result = await StopSheet.show(
                          context,
                          stop: stop,
                          routeId: 1,
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

  testWidgets('muestra la parada y que la unidad no reporta posición', (
    tester,
  ) async {
    // Los campos llegan en null mientras el conductor no arranca; decirlo es mejor que
    // mostrar un cero que se lee como "ya viene".
    await openSheet(tester);

    expect(find.text('Catedral de Morelia'), findsOneWidget);
    expect(find.text('La unidad aún no reporta su posición'), findsOneWidget);
    expect(find.text('¿Vas a abordar aquí?'), findsOneWidget);
  });

  testWidgets('muestra el tiempo estimado cuando el servidor lo calcula', (
    tester,
  ) async {
    await openSheet(
      tester,
      api: FakeApi(
        etaJson:
            '{"stop_id":1,"route_id":1,"vehicle_id":1,'
            '"distance_km":0.573,"eta_minutes":2.3}',
      ),
    );

    expect(find.textContaining('Llega en 2 min'), findsOneWidget);
    expect(find.textContaining('0.6 km'), findsOneWidget);
  });

  testWidgets('muestra el conteo de gente esperando', (tester) async {
    await openSheet(
      tester,
      api: FakeApi(demandJson: '[{"stop_id":1,"waiting_count":4}]'),
    );

    expect(find.text('4 personas esperando aquí'), findsOneWidget);
  });

  testWidgets('"voy a abordar" manda intent boarding y cierra en true', (
    tester,
  ) async {
    final api = FakeApi();
    final results = <bool?>[];
    await openSheet(tester, api: api, onResult: results.add);

    await tester.tap(find.text('Voy a abordar'));
    await tester.pumpAndSettle();

    final sent = api.requests.where((r) => r.path == '/boarding-signals');
    expect(sent, hasLength(1));
    expect(sent.single.body, {
      'user_id': 7,
      'stop_id': 1,
      'route_id': 1,
      'intent': 'boarding',
    });

    expect(results.single, isTrue);
  });

  testWidgets('"solo paso" manda intent passing y no cuenta como demanda', (
    tester,
  ) async {
    final api = FakeApi();
    final results = <bool?>[];
    await openSheet(tester, api: api, onResult: results.add);

    await tester.tap(find.text('Solo paso'));
    await tester.pumpAndSettle();

    final sent = api.requests.where((r) => r.path == '/boarding-signals');
    expect(sent.single.body!['intent'], 'passing');

    // Cierra igual, pero sin celebrar: no hubo intención de abordar.
    expect(results.single, isFalse);
  });

  testWidgets('crea el usuario demo antes de mandar la señal', (tester) async {
    // CLAUDE.md descarta autenticación en esta fase; la señal necesita un user_id de todos
    // modos, así que se crea uno al vuelo.
    final api = FakeApi();
    await openSheet(tester, api: api);

    await tester.tap(find.text('Voy a abordar'));
    await tester.pumpAndSettle();

    final paths = api.requests.map((r) => r.path).toList();
    expect(paths.indexOf('/users'), lessThan(paths.indexOf('/boarding-signals')));
  });

  testWidgets('si el servidor rechaza, lo dice y no cierra', (tester) async {
    final api = FakeApi(boardingStatusCode: 400);
    await openSheet(tester, api: api);

    await tester.tap(find.text('Voy a abordar'));
    await tester.pumpAndSettle();

    expect(find.textContaining('No pudimos registrar tu respuesta'), findsOneWidget);
    // La hoja sigue abierta para poder reintentar.
    expect(find.text('¿Vas a abordar aquí?'), findsOneWidget);
  });
}
