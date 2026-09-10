import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:maas_morelia/data/bike_trip.dart';
import 'package:maas_morelia/data/nearby_ads.dart';
import 'package:maas_morelia/data/providers.dart';
import 'package:maas_morelia/data/trip_plan.dart';
import 'package:maas_morelia/screens/bike_trip_screen.dart';
import 'package:maas_morelia/screens/rating_screen.dart';
import 'package:maas_morelia/theme.dart';
import 'package:maas_morelia/widgets/app_map.dart';

import 'support/fakes.dart';

/// Los negocios publicitados al llegar, en las pantallas.
///
/// Se enseñan **al llegar y no antes**: mientras el viaje sigue, el mapa es para llegar, y unos
/// pines de publicidad encima del recorrido estorbarían justo a lo que el pasajero está
/// mirando.
void main() {
  /// A la vuelta de la esquina: el ciclista llega en el primer avance.
  const roundTheCorner = LatLng(19.7008, -101.1841);

  /// Lejos: el viaje sigue en curso mientras dura la prueba.
  const farAway = LatLng(19.6917, -101.1770);

  Future<void> pumpBike(
    WidgetTester tester,
    ProviderContainer container, {
    required LatLng destination,
  }) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    container.read(bikeTripProvider.notifier).start(destination);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: buildAppTheme(),
          home: const BikeTripScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 10));
  }

  ProviderContainer bikeContainer() {
    final container = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWithValue(FakeApi().build()),
        reverseGeocoderProvider.overrideWithValue(FakeGeocoder()),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  /// Los marcadores de publicidad que el mapa está dibujando.
  Iterable<MapMarker> adMarkers(WidgetTester tester) => tester
      .widget<AppMap>(find.byType(AppMap))
      .markers
      .where((marker) => marker.id.startsWith('negocio-'));

  group('en el mapa del viaje', () {
    testWidgets('al llegar aparecen los negocios de alrededor', (tester) async {
      final container = bikeContainer();
      await pumpBike(tester, container, destination: roundTheCorner);
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('Llegaste'), findsOneWidget);
      expect(adMarkers(tester), hasLength(adsPerArrival));

      // Con el nombre a la vista: un pin sin nombre no anuncia nada.
      final names = adsAround(roundTheCorner).map((place) => place.name);
      expect(
        adMarkers(tester).map((marker) => marker.semanticLabel),
        containsAll(names.map((name) => contains(name))),
      );

      container.read(bikeTripProvider.notifier).reset();
    });

    testWidgets('mientras el viaje sigue no hay ninguno', (tester) async {
      final container = bikeContainer();
      await pumpBike(tester, container, destination: farAway);

      expect(find.text('Llegaste'), findsNothing);
      expect(adMarkers(tester), isEmpty);

      container.read(bikeTripProvider.notifier).reset();
    });
  });

  group('al calificar el viaje en camión', () {
    Future<ProviderContainer> arrivedByBus() async {
      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(FakeApi().build()),
          realtimeClientProvider.overrideWithValue(FakeRealtimeClient()),
        ],
      );
      addTearDown(container.dispose);
      await container.read(routesProvider.future);

      final notifier = container.read(tripPlanProvider.notifier);
      notifier.setDestination(const LatLng(19.6920, -101.1772));
      notifier.choose(container.read(tripPlanProvider).options.first);
      notifier.startWalking();
      notifier.markWaitingAtStop(101);
      notifier.markOnboard(method: PaymentMethod.coins);
      notifier.markArrivedAtDestination();
      return container;
    }

    Future<void> pumpRating(
      WidgetTester tester,
      ProviderContainer container,
    ) async {
      tester.view.physicalSize = const Size(402, 874);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: buildAppTheme(),
            home: const RatingScreen(),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('los negocios salen como tarjetas', (tester) async {
      final container = await arrivedByBus();
      await pumpRating(tester, container);

      final destination = container.read(tripPlanProvider).destination!;
      final first = adsAround(destination).first;

      expect(find.text(first.name), findsOneWidget);
      // Marcado como lo que es: un anuncio disfrazado de recomendación del sistema es lo que
      // hace que se le deje de creer a las dos cosas.
      expect(find.textContaining('Publicidad'), findsWidgets);
    });

    testWidgets('tocar uno enseña su promoción', (tester) async {
      final container = await arrivedByBus();
      await pumpRating(tester, container);

      final destination = container.read(tripPlanProvider).destination!;
      final first = adsAround(destination).first;

      await tester.tap(find.text(first.name));
      await tester.pumpAndSettle();

      expect(find.text(first.promo), findsOneWidget);
      expect(find.textContaining(first.category), findsWidgets);
    });
  });
}
