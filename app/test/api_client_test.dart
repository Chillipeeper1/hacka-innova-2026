import 'package:flutter_test/flutter_test.dart';
import 'package:maas_morelia/data/api_client.dart';
import 'package:maas_morelia/data/models.dart';

import 'support/fakes.dart';

/// Verifica que el cliente lee el contrato de `server/` tal como el servidor lo emite.
///
/// Los payloads salen de respuestas reales del servidor corriendo (`GET /routes`,
/// `GET /stops/:id/eta`, `POST /boarding-signals`), no de una lectura del README.
void main() {
  group('GET /routes', () {
    test('lee rutas, paradas y color', () async {
      final api = FakeApi().build();
      final routes = await api.fetchRoutes();

      expect(routes, hasLength(2));
      expect(routes.first.name, 'Ruta Centro - Acueducto');
      expect(routes.first.mode, 'combi');
      expect(routes.first.colorHex, '#0E5E56');
      expect(routes.first.stops, hasLength(3));
      expect(routes.first.stops.first.name, 'Catedral de Morelia');
      expect(routes.first.stops.first.location.latitude, 19.7008);
    });

    test('el trazado une las paradas en orden', () async {
      final api = FakeApi().build();
      final routes = await api.fetchRoutes();

      final shape = routes.first.shape;
      expect(shape, hasLength(3));
      expect(shape.first.latitude, 19.7008);
      expect(shape.last.latitude, 19.6975);
    });
  });

  group('GET /stops/:id/eta', () {
    test('acepta que no haya estimación todavía', () async {
      // El servidor responde con los campos en null mientras la unidad no reporte posición.
      final api = FakeApi().build();
      final eta = await api.fetchStopEta(1);

      expect(eta, isNotNull);
      expect(eta!.hasEstimate, isFalse);
      expect(eta.etaMinutes, isNull);
      expect(eta.vehicleId, 1);
    });

    test('lee la estimación cuando existe', () async {
      final api = FakeApi(
        etaJson:
            '{"stop_id":2,"route_id":1,"vehicle_id":1,'
            '"distance_km":0.573,"eta_minutes":2.3}',
      ).build();
      final eta = await api.fetchStopEta(2);

      expect(eta!.hasEstimate, isTrue);
      expect(eta.etaMinutes, closeTo(2.3, 0.001));
      expect(eta.distanceKm, closeTo(0.573, 0.001));
    });

    test('un 404 se traduce a "aún no sabemos", no a un error', () async {
      // El servidor devuelve 404 si la ruta no tiene unidad asignada. Para la interfaz eso
      // es ausencia de dato, no un fallo que deba interrumpir nada.
      final api = FakeApi(etaStatusCode: 404).build();
      expect(await api.fetchStopEta(99), isNull);
    });
  });

  group('POST /card-taps', () {
    test('reutiliza la señal declarada cuando se le pasa', () async {
      final fake = FakeApi();

      final signalId = await fake.build().createCardTap(
        cardUid: 'DEMO-0001',
        vehicleId: 1,
        boardingSignalId: 101,
      );

      expect(fake.requests.last.body!['boarding_signal_id'], 101);
      // El servidor devuelve la misma señal, no una nueva: el viaje es uno solo.
      expect(signalId, 101);
    });

    test('sin señal declarada el servidor crea una', () async {
      final fake = FakeApi();

      final signalId = await fake.build().createCardTap(
        cardUid: 'DEMO-0001',
        vehicleId: 1,
      );

      expect(
        fake.requests.last.body!.containsKey('boarding_signal_id'),
        isFalse,
      );
      expect(signalId, 202);
    });
  });

  group('POST /boarding-signals', () {
    test('"voy a abordar" crea la señal en espera', () async {
      final fake = FakeApi();
      final api = fake.build();

      final signal = await api.createBoardingSignal(
        userId: 7,
        stopId: 1,
        routeId: 1,
        intent: BoardingIntent.boarding,
      );

      expect(signal.status, 'waiting');
      expect(signal.isWaiting, isTrue);

      final sent = fake.requests.last;
      expect(sent.method, 'POST');
      expect(sent.path, '/boarding-signals');
      // Los nombres viajan en snake_case, como espera el servidor.
      expect(sent.body, {
        'user_id': 7,
        'stop_id': 1,
        'route_id': 1,
        'intent': 'boarding',
      });
    });

    test('el destino declarado viaja con la señal', () async {
      // Sin esto el destino se queda en el teléfono y el panel institucional solo puede ver
      // dónde sube la gente, nunca hacia dónde va.
      final fake = FakeApi();
      final api = fake.build();

      await api.createBoardingSignal(
        userId: 7,
        stopId: 1,
        routeId: 1,
        intent: BoardingIntent.boarding,
        destinationStopId: 3,
        destinationLat: 19.6975,
        destinationLng: -101.1791,
      );

      final sent = fake.requests.last;
      expect(sent.body!['destination_stop_id'], 3);
      expect(sent.body!['destination_lat'], 19.6975);
      expect(sent.body!['destination_lng'], -101.1791);
    });

    test('sin destino no se mandan los campos vacíos', () async {
      // Mandar `null` explícito y omitir el campo no son lo mismo para quien lea la tabla
      // después: uno dice "no se supo", el otro no dice nada.
      final fake = FakeApi();
      await fake.build().createBoardingSignal(
        userId: 7,
        stopId: 1,
        routeId: 1,
        intent: BoardingIntent.boarding,
      );

      expect(
        fake.requests.last.body!.containsKey('destination_stop_id'),
        isFalse,
      );
      expect(fake.requests.last.body!.containsKey('destination_lat'), isFalse);
    });

    test('"solo paso" no genera demanda', () async {
      final api = FakeApi().build();
      final signal = await api.createBoardingSignal(
        userId: 7,
        stopId: 1,
        routeId: 1,
        intent: BoardingIntent.passing,
      );

      expect(signal.status, 'expired');
      expect(signal.isWaiting, isFalse);
    });

    test(
      'un rechazo del servidor llega como ApiException con su mensaje',
      () async {
        final api = FakeApi(boardingStatusCode: 400).build();

        expect(
          () => api.createBoardingSignal(
            userId: 0,
            stopId: 1,
            routeId: 1,
            intent: BoardingIntent.boarding,
          ),
          throwsA(
            isA<ApiException>()
                .having((e) => e.statusCode, 'statusCode', 400)
                .having((e) => e.message, 'message', 'datos inválidos'),
          ),
        );
      },
    );
  });

  group('eventos del canal en vivo', () {
    test('vehicle:position se lee con vehicle_id como route_id', () {
      // Brecha conocida del contrato: no hay endpoint para resolver la ruta de una unidad, y
      // el seed inserta una por ruta en el mismo orden.
      final position = VehiclePosition.fromJson(const {
        'vehicle_id': 2,
        'lat': 19.6917,
        'lng': -101.177,
        'recorded_at': '2026-09-08T08:40:00.000Z',
      });

      expect(position.vehicleId, 2);
      expect(position.routeId, 2);
      expect(position.location.longitude, -101.177);
      expect(position.recordedAt, isNotNull);
    });

    test('demand:update se lee con su conteo', () {
      final count = DemandCount.fromJson(const {
        'stop_id': 1,
        'waiting_count': 3,
      });

      expect(count.stopId, 1);
      expect(count.waitingCount, 3);
    });
  });
}
