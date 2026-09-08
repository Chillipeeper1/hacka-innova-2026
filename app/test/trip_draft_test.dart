import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:maas_morelia/data/models.dart';
import 'package:maas_morelia/data/providers.dart';
import 'package:maas_morelia/data/trip_draft.dart';

import 'support/fakes.dart';

/// El destino se declara antes de abordar.
///
/// Sin él, la señal solo dice que alguien espera en un punto; con origen y destino se sabe qué
/// tramo del corredor se va a ocupar y en qué parada debería bajarse.
void main() {
  Future<ProviderContainer> containerWithRoutes() async {
    final container = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWithValue(FakeApi().build()),
        realtimeClientProvider.overrideWithValue(FakeRealtimeClient()),
      ],
    );
    addTearDown(container.dispose);
    // El borrador resuelve la ruta contra el catálogo, así que hay que tenerlo cargado.
    await container.read(routesProvider.future);
    return container;
  }

  test('arranca sin destino', () async {
    final container = await containerWithRoutes();
    final trip = container.read(tripDraftProvider);

    expect(trip.hasDestination, isFalse);
    expect(trip.isRoutable, isFalse);
  });

  test('resuelve la parada de bajada y la ruta que la sirve', () async {
    final container = await containerWithRoutes();

    // Un punto junto al Bosque Cuauhtémoc, que solo está en la ruta 2.
    container
        .read(tripDraftProvider.notifier)
        .setDestination(const LatLng(19.6920, -101.1772));

    final trip = container.read(tripDraftProvider);
    expect(trip.isRoutable, isTrue);
    expect(trip.destinationStop!.name, 'Bosque Cuauhtémoc');
    expect(trip.route!.id, 2);
    expect(trip.metersFromDestination, lessThan(100));
  });

  test('un destino lejos de toda ruta se marca como inalcanzable', () async {
    final container = await containerWithRoutes();

    // Al norte de la ciudad, fuera del alcance de las dos rutas sembradas. Decirlo es mejor
    // que fingir que cualquier punto de Morelia tiene servicio.
    container
        .read(tripDraftProvider.notifier)
        .setDestination(const LatLng(19.7600, -101.2600));

    final trip = container.read(tripDraftProvider);
    expect(trip.hasDestination, isTrue);
    expect(trip.isUnreachable, isTrue);
    expect(trip.isRoutable, isFalse);
  });

  group('elegir dónde abordar', () {
    late TripDraft trip;

    setUp(() async {
      final container = await containerWithRoutes();
      container
          .read(tripDraftProvider.notifier)
          .setDestination(const LatLng(19.6920, -101.1772));
      trip = container.read(tripDraftProvider);
    });

    test('acepta una parada de la ruta del viaje', () {
      const catedralRuta2 = Stop(
        id: 4,
        name: 'Catedral de Morelia',
        lat: 19.7008,
        lng: -101.1844,
        sequence: 1,
      );

      expect(trip.canBoardAt(catedralRuta2), isTrue);
      expect(trip.boardingStopFor(catedralRuta2)!.id, 4);
    });

    test('acepta el marcador de otra ruta si es la misma parada física', () {
      // El catálogo repite "Catedral de Morelia": id 1 en la ruta 1, id 4 en la ruta 2. Al
      // usuario parado en la banqueta le da igual cuál tocó, pero al servidor hay que
      // mandarle el id de la ruta que realmente va a viajar.
      const catedralRuta1 = Stop(
        id: 1,
        name: 'Catedral de Morelia',
        lat: 19.7008,
        lng: -101.1844,
        sequence: 1,
      );

      expect(trip.canBoardAt(catedralRuta1), isTrue);
      expect(
        trip.boardingStopFor(catedralRuta1)!.id,
        4,
        reason: 'debe mandar el id de la parada en la ruta 2',
      );
    });

    test('rechaza una parada que no lleva al destino', () {
      const acueducto = Stop(
        id: 3,
        name: 'Acueducto de Morelia',
        lat: 19.6975,
        lng: -101.1791,
        sequence: 3,
      );

      expect(trip.canBoardAt(acueducto), isFalse);
    });

    test('rechaza abordar en la propia parada de bajada', () {
      expect(trip.canBoardAt(trip.destinationStop!), isFalse);
    });
  });

  test('se puede limpiar el destino', () async {
    final container = await containerWithRoutes();
    final notifier = container.read(tripDraftProvider.notifier);

    notifier.setDestination(const LatLng(19.6920, -101.1772));
    expect(container.read(tripDraftProvider).hasDestination, isTrue);

    notifier.clear();
    expect(container.read(tripDraftProvider).hasDestination, isFalse);
  });
}
