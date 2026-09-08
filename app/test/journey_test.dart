import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:maas_morelia/data/journey.dart';

import 'support/fakes.dart';

/// La lectura del viaje multimodal que arma el servidor.
///
/// Se prueba contra una respuesta **real** de `GET /journeys`, no contra un JSON escrito a
/// mano: lo que puede romperse aquí es que el servidor mande algo distinto a lo que la app
/// espera, y un fixture inventado no detectaría eso nunca.
void main() {
  List<Journey> parse() {
    final body = jsonDecode(journeysPayload) as Map<String, dynamic>;
    return (body['alternatives'] as List<dynamic>)
        .map((json) => Journey.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  group('Journey lee la respuesta del servidor', () {
    test('trae las alternativas con su etiqueta', () {
      final journeys = parse();

      expect(journeys, hasLength(2));
      // Y de paso: los acentos sobreviven el viaje por el cable.
      expect(journeys.first.label, 'Más rápida');
      expect(journeys[1].label, 'Sin bicicleta');
    });

    test('la primera es la más rápida', () {
      final journeys = parse();

      expect(
        journeys.first.totalMinutes,
        lessThanOrEqualTo(journeys[1].totalMinutes),
      );
      expect(journeys.first.roundedMinutes, 5);
    });

    test('los kilómetros del servidor se leen como metros', () {
      // El servidor habla en km y la app en metros; equivocarse aquí da errores de mil veces.
      final fastest = parse().first;

      expect(fastest.totalMeters, closeTo(1274, 1));
      expect(fastest.legs.first.meters, closeTo(1274, 1));
    });

    test('reconoce los modos de cada tramo', () {
      final journeys = parse();

      expect(journeys.first.modes, [JourneyMode.bike]);
      expect(
        journeys[1].modes,
        containsAll([JourneyMode.walk, JourneyMode.bus]),
      );
    });

    test('cuenta solo los tramos que hay que tomar', () {
      // Las caminatas de conexión no son "un transbordo más": el pasajero no se sube a nada.
      final sinBici = parse()[1];

      expect(sinBici.legs.length, greaterThan(1));
      expect(sinBici.rideCount, 1);
    });

    test('el nombre de la ruta manda sobre el del modo', () {
      final bus = parse()[1].legs.firstWhere(
        (leg) => leg.mode == JourneyMode.bus,
      );

      expect(bus.routeName, 'Ruta Centro - Bosque');
      expect(bus.title, 'Ruta Centro - Bosque');
    });

    test('un tramo a pie sin ruta se llama por su modo', () {
      final walk = parse()[1].legs.firstWhere(
        (leg) => leg.mode == JourneyMode.walk,
      );

      expect(walk.routeName, isNull);
      expect(walk.title, 'A pie');
    });

    test('un modo desconocido no tira la pantalla', () {
      // Si el servidor agrega un modo nuevo, la app debe seguir enseñando el viaje.
      final leg = JourneyLeg.fromJson({
        'mode': 'monorriel',
        'route_id': null,
        'route_name': null,
        'from': {'stop_id': null, 'name': null, 'lat': 19.7, 'lng': -101.18},
        'to': {'stop_id': null, 'name': null, 'lat': 19.69, 'lng': -101.17},
        'distance_km': 1.0,
        'eta_minutes': 4.0,
      });

      expect(leg.mode, JourneyMode.walk);
      expect(leg.minutes, 4.0);
    });

    test('el ritmo de cada tramo sale de sus propios números', () {
      final bus = parse()[1].legs.firstWhere(
        (leg) => leg.mode == JourneyMode.bus,
      );

      // 1.274 km en 8.1 min ≈ 157 m/min, que es la velocidad de camión del servidor. Si la
      // app supusiera la suya, el marcador y el reloj dejarían de coincidir.
      expect(bus.metersPerMinute, closeTo(157, 2));
    });

    test('el recorrido va del origen al destino sin repetir puntos', () {
      final sinBici = parse()[1];
      final points = sinBici.points;

      expect(points.first, sinBici.legs.first.from.location);
      expect(points.last, sinBici.legs.last.to.location);
      // Los tramos comparten extremo; dibujarlo dos veces engordaría la línea en cada empalme.
      for (var i = 0; i < points.length - 1; i++) {
        expect(points[i], isNot(points[i + 1]));
      }
    });
  });
}
