import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:maas_morelia/data/models.dart';
import 'package:maas_morelia/data/providers.dart';
import 'package:maas_morelia/data/trip_plan.dart';
import 'package:maas_morelia/screens/board_bus_screen.dart';
import 'package:maas_morelia/screens/onboard_trip_screen.dart';
import 'package:maas_morelia/screens/rating_screen.dart';
import 'package:maas_morelia/theme.dart';

import 'support/fakes.dart';

/// El tramo final del viaje: esperar la unidad, pagar, viajar y calificar.
void main() {
  const destinoBosque = LatLng(19.6920, -101.1772);

  late FakeRealtimeClient realtime;

  setUp(() => realtime = FakeRealtimeClient());

  /// Deja el viaje listo en la parada, con la señal ya declarada.
  Future<ProviderContainer> waitingAtStop({FakeApi? api}) async {
    final container = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWithValue((api ?? FakeApi()).build()),
        realtimeClientProvider.overrideWithValue(realtime),
      ],
    );
    addTearDown(container.dispose);
    await container.read(routesProvider.future);

    final notifier = container.read(tripPlanProvider.notifier);
    notifier.setDestination(destinoBosque);
    // La opción más lejana evita elegir la parada donde el usuario ya está.
    final option = container.read(tripPlanProvider).options.reduce(
      (a, b) => a.metersToBoardingStop > b.metersToBoardingStop ? a : b,
    );
    notifier.choose(option);
    notifier.startWalking();
    notifier.markWaitingAtStop(101);

    // Suscribe los providers derivados para que reaccionen al canal en vivo.
    addTearDown(container.listen(busIsArrivingProvider, (_, _) {}).close);
    addTearDown(container.listen(busDepartedStopProvider, (_, _) {}).close);
    addTearDown(container.listen(busVisitedStopProvider, (_, _) {}).close);
    return container;
  }

  Future<void> pump(
    WidgetTester tester,
    ProviderContainer container,
    Widget child, {
    Size size = const Size(402, 874),
    double textScale = 1.0,
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
            child: child,
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

  /// Coloca la unidad a [meters] metros de la parada de abordaje, sobre la línea al destino.
  void placeBus(ProviderContainer container, double meters) {
    final option = container.read(tripPlanProvider).chosen!;
    final stop = option.boardingStop.location;
    // ~1 grado de latitud = 111 km.
    final offset = meters / 111000;
    realtime.emitVehicle(
      VehiclePosition(
        vehicleId: option.route.id,
        lat: stop.latitude + offset,
        lng: stop.longitude,
      ),
    );
  }

  group('esperar y abordar', () {
    testWidgets('con la unidad lejos, muestra la espera y no pide pago', (
      tester,
    ) async {
      final container = await waitingAtStop();
      await pump(tester, container, const BoardBusScreen());
      placeBus(container, 800);
      await tester.pump(const Duration(milliseconds: 10));
      expectNoLayoutError(tester, 'espera');

      expect(find.text('Esperando la unidad'), findsOneWidget);
      expect(find.text('Paga con tu tarjeta RFID'), findsNothing);
      // En minutos, no en metros: a quien espera parado en la banqueta los metros no le
      // dicen nada.
      expect(find.textContaining('La unidad llega en'), findsOneWidget);
    });

    testWidgets('al acercarse la unidad pide el pago', (tester) async {
      // El momento importa: antes sería adelantarse, después el pasajero ya va subiendo con
      // el teléfono guardado.
      final container = await waitingAtStop();
      await pump(tester, container, const BoardBusScreen());

      placeBus(container, busApproachingMeters - 40);
      await tester.pump(const Duration(milliseconds: 10));
      expectNoLayoutError(tester, 'pago');

      expect(find.text('Paga con tu tarjeta RFID'), findsOneWidget);
      expect(find.text('Pasar tarjeta'), findsOneWidget);
      expect(find.textContaining('monedas'), findsOneWidget);
    });

    testWidgets('pasar la tarjeta registra el tap y sube al pasajero', (
      tester,
    ) async {
      final api = FakeApi();
      final container = await waitingAtStop(api: api);
      var boarded = 0;
      await pump(
        tester,
        container,
        BoardBusScreen(onBoarded: () => boarded++),
      );

      placeBus(container, busApproachingMeters - 40);
      await tester.pump(const Duration(milliseconds: 10));
      await tester.tap(find.text('Pasar tarjeta'));
      await tester.pumpAndSettle();
      expectNoLayoutError(tester, 'tap');

      final tap = api.requests.firstWhere((r) => r.path == '/card-taps');
      expect(tap.body!['card_uid'], demoCardUid);

      final plan = container.read(tripPlanProvider);
      expect(plan.stage, TripStage.onboard);
      expect(plan.paymentMethod, PaymentMethod.card);
      expect(boarded, 1);
    });

    testWidgets('el tap cierra la señal declarada para no inflar la demanda', (
      tester,
    ) async {
      // `POST /card-taps` crea su propia señal en vez de reutilizar la de la parada; si la
      // original se quedara en `waiting`, el panel institucional contaría gente que ya subió.
      final api = FakeApi();
      final container = await waitingAtStop(api: api);
      await pump(tester, container, const BoardBusScreen());

      placeBus(container, busApproachingMeters - 40);
      await tester.pump(const Duration(milliseconds: 10));
      await tester.tap(find.text('Pasar tarjeta'));
      await tester.pumpAndSettle();

      final patch = api.requests.firstWhere(
        (r) => r.method == 'PATCH' && r.path.startsWith('/boarding-signals/'),
      );
      expect(patch.path, '/boarding-signals/101');
      expect(patch.body!['status'], 'expired');
    });

    testWidgets('si la unidad arranca sin tap, se asume pago con monedas', (
      tester,
    ) async {
      final api = FakeApi();
      final container = await waitingAtStop(api: api);
      var boarded = 0;
      await pump(
        tester,
        container,
        BoardBusScreen(onBoarded: () => boarded++),
      );

      placeBus(container, busApproachingMeters - 40);
      await tester.pump(const Duration(milliseconds: 10));
      expect(find.text('Paga con tu tarjeta RFID'), findsOneWidget);

      // La unidad llega a la parada...
      placeBus(container, busAtStopMeters - 10);
      await tester.pump(const Duration(milliseconds: 10));

      // ...y arranca: el pasajero va arriba.
      placeBus(container, departedStopMeters + 40);
      await tester.pumpAndSettle();
      expectNoLayoutError(tester, 'monedas');

      final plan = container.read(tripPlanProvider);
      expect(plan.stage, TripStage.onboard);
      expect(plan.paymentMethod, PaymentMethod.coins);
      expect(boarded, 1);

      // La señal declarada pasa a 'boarded': el pasajero sí subió.
      final patch = api.requests.firstWhere(
        (r) => r.method == 'PATCH' && r.path == '/boarding-signals/101',
      );
      expect(patch.body!['status'], 'boarded');
      expect(
        api.requests.any((r) => r.path == '/card-taps'),
        isFalse,
        reason: 'pagó con monedas, no hubo tap',
      );
    });
  });

  group('en viaje', () {
    Future<ProviderContainer> onboard({FakeApi? api}) async {
      final container = await waitingAtStop(api: api);
      container
          .read(tripPlanProvider.notifier)
          .markOnboard(method: PaymentMethod.coins);
      addTearDown(container.listen(atAlightingProvider, (_, _) {}).close);
      return container;
    }

    /// Coloca la unidad a [meters] de la parada de bajada.
    void placeBusNearAlighting(ProviderContainer container, double meters) {
      final option = container.read(tripPlanProvider).chosen!;
      final stop = option.alightingStop.location;
      realtime.emitVehicle(
        VehiclePosition(
          vehicleId: option.route.id,
          lat: stop.latitude + meters / 111000,
          lng: stop.longitude,
        ),
      );
    }

    testWidgets('muestra "En viaje" y lo que falta', (tester) async {
      final container = await onboard();
      await pump(tester, container, const OnboardTripScreen());
      placeBusNearAlighting(container, 2000);
      await tester.pump(const Duration(milliseconds: 10));
      expectNoLayoutError(tester, 'en viaje');

      expect(find.text('En viaje'), findsOneWidget);
      expect(find.textContaining('Llegada estimada'), findsOneWidget);
      expect(find.textContaining('monedas'), findsOneWidget);
    });

    testWidgets('no avisa la bajada demasiado pronto', (tester) async {
      final container = await onboard();
      await pump(tester, container, const OnboardTripScreen());
      placeBusNearAlighting(container, alightingWarningMeters + 400);
      await tester.pump(const Duration(milliseconds: 10));
      expectNoLayoutError(tester, 'sin aviso');

      expect(find.text('Prepárate para bajar'), findsNothing);
    });

    testWidgets('avisa unos metros antes de la parada de bajada', (
      tester,
    ) async {
      // El aviso existe para dar tiempo de acercarse a la puerta.
      final container = await onboard();
      await pump(tester, container, const OnboardTripScreen());
      placeBusNearAlighting(container, alightingWarningMeters - 80);
      await tester.pump(const Duration(milliseconds: 10));
      expectNoLayoutError(tester, 'aviso');

      expect(find.text('Prepárate para bajar'), findsOneWidget);
      // El aviso nombra la parada de bajada del viaje, sea cual sea la opción elegida.
      final alighting =
          container.read(tripPlanProvider).chosen!.alightingStop.name;
      expect(find.textContaining(alighting), findsWidgets);
      expect(find.textContaining('min'), findsWidgets);
    });

    testWidgets('al llegar a la parada de bajada termina el viaje solo', (
      tester,
    ) async {
      final container = await onboard();
      var arrived = 0;
      await pump(
        tester,
        container,
        OnboardTripScreen(onArrived: () => arrived++),
      );

      placeBusNearAlighting(container, alightingRadiusMeters - 20);
      await tester.pumpAndSettle();
      expectNoLayoutError(tester, 'llegada');

      expect(arrived, 1);
      expect(container.read(tripPlanProvider).stage, TripStage.arrived);
    });
  });

  group('calificación', () {
    Future<ProviderContainer> arrived({FakeApi? api}) async {
      final container = await waitingAtStop(api: api);
      final notifier = container.read(tripPlanProvider.notifier);
      notifier.markOnboard(method: PaymentMethod.coins);
      notifier.markArrivedAtDestination();
      return container;
    }

    testWidgets('se puede omitir sin calificar', (tester) async {
      // El pasajero acaba de bajarse, muchas veces con prisa; obligarlo a calificar sería
      // castigarlo por terminar su viaje.
      final api = FakeApi();
      final container = await arrived(api: api);
      var finished = 0;
      await pump(
        tester,
        container,
        RatingScreen(onFinished: () => finished++),
      );

      await tester.tap(find.bySemanticsLabel('Omitir la calificación'));
      await tester.pumpAndSettle();

      expect(finished, 1);
      expect(
        api.requests.any((r) => r.path.contains('/rating')),
        isFalse,
        reason: 'omitir no debe mandar calificación',
      );
    });

    testWidgets('envía estrellas y comentario', (tester) async {
      final api = FakeApi();
      final container = await arrived(api: api);
      var finished = 0;
      await pump(
        tester,
        container,
        RatingScreen(onFinished: () => finished++),
      );

      await tester.tap(find.bySemanticsLabel('4 estrellas'));
      await tester.enterText(find.byType(TextField), 'Iba muy lleno');
      await tester.tap(find.text('Confirmar'));
      await tester.pumpAndSettle();

      final rating = api.requests.firstWhere(
        (r) => r.path.contains('/rating'),
      );
      expect(rating.path, '/trips/101/rating');
      expect(rating.body!['rating'], 4);
      expect(rating.body!['comment'], 'Iba muy lleno');
      expect(finished, 1);
    });

    testWidgets('califica antes de cerrar el viaje', (tester) async {
      // `POST /trips/:id/rating` exige que la señal siga en `boarded`; si se cerrara primero,
      // la calificación se perdería con un 404.
      final api = FakeApi();
      final container = await arrived(api: api);
      await pump(tester, container, const RatingScreen());

      await tester.tap(find.bySemanticsLabel('5 estrellas'));
      await tester.tap(find.text('Confirmar'));
      await tester.pumpAndSettle();

      final paths = api.requests.map((r) => '${r.method} ${r.path}').toList();
      expect(
        paths.indexOf('POST /trips/101/rating'),
        lessThan(paths.indexOf('PATCH /boarding-signals/101')),
      );
    });

    testWidgets('se acomoda sin desbordarse con tipografía al doble', (
      tester,
    ) async {
      final container = await arrived();
      await pump(
        tester,
        container,
        const RatingScreen(),
        size: const Size(360, 640),
        textScale: 2.0,
      );
      expectNoLayoutError(tester, 'tipografía al doble');
    });
  });
}
