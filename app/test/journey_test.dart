import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:maas_morelia/data/journey.dart';
import 'package:maas_morelia/data/path_geometry.dart';

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

  group('Journey lee el trazado por calles', () {
    List<Journey> conGeometria() {
      final body =
          jsonDecode(journeysWithGeometryPayload) as Map<String, dynamic>;
      return (body['alternatives'] as List<dynamic>)
          .map((json) => Journey.fromJson(json as Map<String, dynamic>))
          .toList();
    }

    test('el tramo de transporte trae su trazado', () {
      final combi = conGeometria().first.legs.firstWhere(
        (leg) => leg.mode == JourneyMode.combi,
      );

      expect(combi.geometry.length, greaterThan(2));
      // Y cae donde debe: el trazado empieza y acaba en los extremos del tramo, no invertido.
      // Confundir [lat, lng] con [lng, lat] pondría la ruta en el océano Índico.
      expect(
        combi.geometry.first.latitude,
        closeTo(combi.from.location.latitude, 0.01),
      );
      expect(
        combi.geometry.first.longitude,
        closeTo(combi.from.location.longitude, 0.01),
      );
      expect(
        combi.geometry.last.latitude,
        closeTo(combi.to.location.latitude, 0.01),
      );
    });

    test('sigue calles: es más largo que la recta que lo generó', () {
      // Si fueran iguales, el trazado sería la propia recta y no habríamos ganado nada.
      final combi = conGeometria().first.legs.firstWhere(
        (leg) => leg.mode == JourneyMode.combi,
      );

      expect(pathLengthMeters(combi.geometry), greaterThan(combi.meters));
    });

    test('un tramo sin trazado se dibuja recto entre sus extremos', () {
      // Las conexiones a pie de longitud cero no traen geometría, y el teleférico tampoco:
      // va por el aire. `path` tiene que servir igual para dibujarlos.
      final aPie = conGeometria().first.legs.firstWhere(
        (leg) => leg.mode == JourneyMode.walk,
      );

      expect(aPie.geometry, isEmpty);
      expect(aPie.path, [aPie.from.location, aPie.to.location]);
    });

    test('el encuadre del mapa cubre el trazado, no solo los extremos', () {
      final viaje = conGeometria().first;
      final combi = viaje.legs.firstWhere(
        (leg) => leg.mode == JourneyMode.combi,
      );

      expect(viaje.points, containsAll(combi.geometry));
    });

    test('una respuesta sin `geometry` sigue leyéndose', () {
      // El campo es opcional: un servidor sin OSRM, o con OSRM caído, manda los tramos pelados.
      final sinGeometria = parse().first.legs.first;

      expect(sinGeometria.geometry, isEmpty);
      expect(sinGeometria.path, hasLength(2));
    });
  });

  group('viajes fuera de lo que cubre la red', () {
    // El motor del servidor limita la bici a 6 km pero a caminar no le pone tope, así que un
    // destino al que ninguna ruta se acerca vuelve como "unos minutos en transporte y el resto
    // a pie". Medido contra el servidor: 10 km al sur del centro devuelve 5 min en bici y
    // 122 min caminando, y eso se enseñaba como un itinerario normal.
    JourneyLeg leg(JourneyMode mode, double meters, double minutes) =>
        JourneyLeg(
          mode: mode,
          from: const JourneyPlace(location: LatLng(19.7008, -101.1844)),
          to: const JourneyPlace(location: LatLng(19.61, -101.1844)),
          meters: meters,
          minutes: minutes,
        );

    Journey journey(List<JourneyLeg> legs) => Journey(
      label: 'Tu selección',
      legs: legs,
      totalMeters: legs.fold(0, (sum, leg) => sum + leg.meters),
      totalMinutes: legs.fold(0, (sum, leg) => sum + leg.minutes),
    );

    test('un tramo a pie de kilómetros queda marcado', () {
      final imposible = journey([
        leg(JourneyMode.bike, 1274, 5.1),
        leg(JourneyMode.walk, 9118, 121.6),
      ]);

      expect(imposible.longestWalkMeters, 9118);
      expect(imposible.beyondNetwork, isTrue);
    });

    test('las caminatas de conexión normales no lo marcan', () {
      // Dos tramos a pie razonables suman más que el tope, y aun así el viaje es bueno: lo que
      // lo vuelve imposible es un tramo largo, no la suma de dos cortos.
      final normal = journey([
        leg(JourneyMode.walk, 1400, 18.7),
        leg(JourneyMode.combi, 9398, 40.6),
        leg(JourneyMode.walk, 1400, 18.7),
      ]);

      expect(normal.longestWalkMeters, 1400);
      expect(normal.beyondNetwork, isFalse);
    });

    test('un viaje sin caminata no puede quedar marcado', () {
      final directo = journey([leg(JourneyMode.combi, 9398, 40.6)]);

      expect(directo.longestWalkMeters, 0);
      expect(directo.beyondNetwork, isFalse);
    });
  });
}
