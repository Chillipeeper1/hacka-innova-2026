/// Red de teleférico y armado del viaje.
///
/// **Las líneas y estaciones son inventadas.** El teleférico de Morelia no está en operación y
/// no hay un trazado público que se pueda usar aquí, así que este archivo trae dos líneas
/// simuladas ancladas a los puntos de referencia de la demo. Sirven para enseñar cómo se
/// sentiría el modo, no para decir por dónde va a pasar.
///
/// TODO(teleférico): sustituir [moreliaCableLines] por el trazado real cuando exista, y quitar
/// el aviso de datos simulados de la pantalla.
library;

import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import 'walk_route.dart' show walkingSpeedKmh;

const Distance _distance = Distance();

/// Velocidad de la cabina.
///
/// 20 km/h es lo que da una góndola urbana: lenta comparada con un coche, pero sin altos, sin
/// tráfico y en línea recta sobre todo lo demás. Ahí está su ventaja, no en la velocidad punta.
const double cableCarSpeedKmh = 20;

/// Lo más lejos que se acepta caminar para alcanzar una estación.
///
/// Más allá, el teleférico deja de ser una opción y ofrecerlo sería hacer perder el tiempo.
const double maxWalkToStationMeters = 2500;

/// Tramos por debajo de esto no se dibujan ni se cuentan.
///
/// Cuando ya se está parado en la estación, un tramo a pie de tres metros solo ensucia el mapa
/// y el resumen.
const double negligibleLegMeters = 5;

/// Cómo se recorre un tramo del viaje.
enum CableLegMode { walk, cable }

class CableStation {
  const CableStation({required this.name, required this.location});

  final String name;
  final LatLng location;
}

class CableLine {
  const CableLine({
    required this.name,
    required this.colorHex,
    required this.stations,
  });

  final String name;
  final String colorHex;
  final List<CableStation> stations;
}

/// Red simulada de teleférico.
///
/// Dos líneas separadas y sin transbordo entre ellas: encadenar líneas es un problema distinto
/// —y una decisión de producto— que este mockup no necesita para enseñar el modo. Están puestas
/// lejos una de otra a propósito, para que elegir entre ellas signifique algo.
const List<CableLine> moreliaCableLines = [
  CableLine(
    name: 'Línea 1 · Poniente – Acueducto',
    colorHex: '#7B2FF7',
    stations: [
      CableStation(
        name: 'Estación Poniente',
        location: LatLng(19.7035, -101.2010),
      ),
      CableStation(
        name: 'Estación Ventura Puente',
        location: LatLng(19.7020, -101.1930),
      ),
      CableStation(
        name: 'Estación Centro',
        location: LatLng(19.7008, -101.1846),
      ),
      CableStation(
        name: 'Estación Acueducto',
        location: LatLng(19.6976, -101.1790),
      ),
    ],
  ),
  CableLine(
    name: 'Línea 2 · Bosque – Sur',
    colorHex: '#F2600C',
    stations: [
      CableStation(
        name: 'Estación Bosque',
        location: LatLng(19.6917, -101.1770),
      ),
      CableStation(
        name: 'Estación Camelinas',
        location: LatLng(19.6870, -101.1790),
      ),
      CableStation(name: 'Estación Sur', location: LatLng(19.6800, -101.1830)),
    ],
  ),
];

/// Un tramo continuo del viaje, todo a pie o todo en cabina.
class CableLeg {
  const CableLeg({
    required this.mode,
    required this.points,
    required this.meters,
  });

  final CableLegMode mode;
  final List<LatLng> points;
  final double meters;

  /// Metros por minuto de este tramo. Es lo que hace que el tiempo estimado no mienta: dos
  /// tramos del mismo largo no tardan lo mismo si uno se camina y el otro se vuela.
  double get metersPerMinute =>
      (mode == CableLegMode.cable ? cableCarSpeedKmh : walkingSpeedKmh) *
      1000 /
      60;
}

/// El viaje en teleférico ya resuelto: por dónde se sube, por dónde se baja y qué hay entre
/// medias.
class CableCarPlan {
  const CableCarPlan({
    required this.line,
    required this.boarding,
    required this.alighting,
    required this.legs,
    required this.metersToBoarding,
    required this.metersFromAlightingToDestination,
  });

  final CableLine line;

  /// La estación más cercana a donde está el usuario.
  final CableStation boarding;

  /// La estación que lo deja más cerca de su destino.
  final CableStation alighting;

  final List<CableLeg> legs;

  /// Lo que camina para alcanzar la estación de subida.
  final double metersToBoarding;

  /// Lo que camina al bajarse. Es el número que decide si el viaje sirvió.
  final double metersFromAlightingToDestination;

  double get totalMeters => legs.fold(0, (sum, leg) => sum + leg.meters);

  List<LatLng> get points {
    final all = <LatLng>[];
    for (final leg in legs) {
      for (final point in leg.points) {
        if (all.isEmpty || all.last != point) all.add(point);
      }
    }
    return all;
  }

  /// Índice del tramo en el que se va tras recorrer [traveled] metros.
  int legIndexAt(double traveled) {
    var left = traveled;
    for (var i = 0; i < legs.length; i++) {
      if (left < legs[i].meters) return i;
      left -= legs[i].meters;
    }
    return legs.length - 1;
  }

  /// El tramo en el que se va tras recorrer [traveled] metros.
  CableLeg legAt(double traveled) => legs[legIndexAt(traveled)];

  /// Minutos que faltan desde [traveled], contando cada tramo a su velocidad.
  int remainingMinutesFrom(double traveled) {
    var left = traveled;
    var minutes = 0.0;

    for (final leg in legs) {
      if (left >= leg.meters) {
        left -= leg.meters;
        continue;
      }
      minutes += (leg.meters - left) / leg.metersPerMinute;
      left = 0;
    }

    // Nunca cero: "llegas en 0 min" se lee como que ya pasó.
    return math.max(1, minutes.round());
  }

  int get totalMinutes => remainingMinutesFrom(0);
}

/// Arma el viaje en teleférico de [origin] a [destination].
///
/// Para cada línea toma **la estación más cercana al usuario** y **la que deja más cerca del
/// destino**, y se queda con la línea donde la suma de esas dos caminatas es menor. Las dos
/// pesan igual: caminar de más al principio y caminar de más al final cuestan lo mismo cuando
/// el viaje de en medio es el mismo.
///
/// Devuelve `null` si ninguna línea sirve — porque no hay estación a distancia caminable, o
/// porque la mejor subida y la mejor bajada son la misma estación y el teleférico no llevaría a
/// ningún lado.
CableCarPlan? planCableCarTrip({
  required LatLng origin,
  required LatLng destination,
  List<CableLine> lines = moreliaCableLines,
}) {
  CableCarPlan? best;
  var bestScore = double.infinity;

  for (final line in lines) {
    if (line.stations.length < 2) continue;

    final boardingIndex = _nearestStationIndex(line, origin);
    final alightingIndex = _nearestStationIndex(line, destination);
    if (boardingIndex == alightingIndex) continue;

    final boarding = line.stations[boardingIndex];
    final alighting = line.stations[alightingIndex];

    final toBoarding = _distance(origin, boarding.location);
    if (toBoarding > maxWalkToStationMeters) continue;

    final fromAlighting = _distance(alighting.location, destination);
    final score = toBoarding + fromAlighting;
    if (score >= bestScore) continue;

    // La cabina para en todas las estaciones intermedias; el trazado las sigue.
    final ride = <LatLng>[];
    final step = boardingIndex < alightingIndex ? 1 : -1;
    for (var i = boardingIndex; i != alightingIndex + step; i += step) {
      ride.add(line.stations[i].location);
    }

    final legs = <CableLeg>[
      if (toBoarding > negligibleLegMeters)
        CableLeg(
          mode: CableLegMode.walk,
          points: [origin, boarding.location],
          meters: toBoarding,
        ),
      CableLeg(
        mode: CableLegMode.cable,
        points: ride,
        meters: _pathMeters(ride),
      ),
      if (fromAlighting > negligibleLegMeters)
        CableLeg(
          mode: CableLegMode.walk,
          points: [alighting.location, destination],
          meters: fromAlighting,
        ),
    ];

    bestScore = score;
    best = CableCarPlan(
      line: line,
      boarding: boarding,
      alighting: alighting,
      legs: legs,
      metersToBoarding: toBoarding,
      metersFromAlightingToDestination: fromAlighting,
    );
  }

  return best;
}

int _nearestStationIndex(CableLine line, LatLng point) {
  var nearest = 0;
  var nearestMeters = double.infinity;
  for (var i = 0; i < line.stations.length; i++) {
    final meters = _distance(line.stations[i].location, point);
    if (meters < nearestMeters) {
      nearestMeters = meters;
      nearest = i;
    }
  }
  return nearest;
}

double _pathMeters(List<LatLng> path) {
  var total = 0.0;
  for (var i = 0; i < path.length - 1; i++) {
    total += _distance(path[i], path[i + 1]);
  }
  return total;
}
