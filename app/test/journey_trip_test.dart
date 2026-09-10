import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:maas_morelia/data/journey.dart';
import 'package:maas_morelia/data/journey_trip.dart';
import 'package:maas_morelia/data/providers.dart';

import 'support/fakes.dart';

/// El estado del viaje personalizado.
///
/// Lo que fija este archivo es el orden: primero los medios, después el destino, y el viaje en
/// marcha solo cuando el pasajero lo dice. Las dos veces que se rompió fue por saltarse un
/// eslabón — pedir el itinerario con los cuatro medios por omisión, y echarlo a andar nada más
/// llegar la respuesta.
void main() {
  const bosque = LatLng(19.6917, -101.1770);

  late FakeApi api;
  late ProviderContainer container;

  setUp(() {
    api = FakeApi();
    container = ProviderContainer(
      overrides: [apiClientProvider.overrideWithValue(api.build())],
    );
  });

  tearDown(() {
    container.read(journeyTripProvider.notifier).reset();
    container.dispose();
  });

  // Funciones y no getters: dentro del cuerpo de `main` Dart no admite declarar getters.
  JourneyTripController controller() =>
      container.read(journeyTripProvider.notifier);

  JourneyTrip trip() => container.read(journeyTripProvider);

  RecordedRequest lastJourneyRequest() =>
      api.requests.lastWhere((request) => request.path == '/journeys');

  test(
    'la primera petición ya sale con los medios que eligió el usuario',
    () async {
      // El bug: la app pedía el itinerario antes de preguntar nada, con los cuatro medios
      // prendidos. Quien no tiene bici recibía un viaje en bici.
      controller().setModes({JourneyMode.bus});
      expect(api.requests.where((r) => r.path == '/journeys'), isEmpty);

      await controller().start(bosque);

      expect(lastJourneyRequest().query['modes'], 'bus');
    },
  );

  test('elegir medios no le pide nada al servidor', () {
    controller().setModes({JourneyMode.bike, JourneyMode.combi});

    expect(api.requests, isEmpty);
    expect(trip().stage, JourneyStage.idle);
    expect(trip().modes, {JourneyMode.bike, JourneyMode.combi});
  });

  test('un filtro vacío se ignora: el servidor lo leería como "todos"', () {
    controller().setModes({JourneyMode.bus});
    controller().setModes({});

    expect(trip().modes, {JourneyMode.bus});
  });

  test('el itinerario llega propuesto, no en marcha', () async {
    await controller().start(bosque);

    expect(trip().stage, JourneyStage.planned);
    expect(trip().elapsedMinutes, 0);
    expect(trip().journey, isNotNull);
  });

  test('solo begin() lo pone en marcha', () async {
    await controller().start(bosque);
    controller().begin();

    expect(trip().stage, JourneyStage.traveling);
  });

  test('begin() no hace nada sobre un viaje que no está propuesto', () {
    controller().begin();

    expect(trip().stage, JourneyStage.idle);
  });

  test('cambiar de medios replantea y vuelve a la propuesta', () async {
    await controller().start(bosque);
    controller().begin();
    expect(trip().stage, JourneyStage.traveling);

    await controller().toggleMode(JourneyMode.bike);

    expect(trip().stage, JourneyStage.planned);
    expect(trip().modes, isNot(contains(JourneyMode.bike)));
    expect(lastJourneyRequest().query['modes'], isNot(contains('bike')));
  });

  test('el destino no borra los medios ya elegidos', () async {
    controller().setModes({JourneyMode.cableCar});
    await controller().start(bosque);

    expect(trip().modes, {JourneyMode.cableCar});
    expect(lastJourneyRequest().query['modes'], 'teleferico');
  });
}
