/// Zonas no recomendadas y el trazado que las rodea.
///
/// **Los datos de zonas son inventados.** No hay una capa de incidencia o de percepción de
/// seguridad para Morelia que se pueda usar aquí, así que este archivo trae zonas simuladas
/// colocadas sobre el corredor de la demo para que el rodeo se vea. Sirven para enseñar el
/// comportamiento, no para orientar a nadie.
///
/// Las zonas se describen por **motivo** —alumbrado, obra, reportes— y nunca por colonia o
/// barrio. Marcar una zona de una ciudad real como peligrosa y ponerle nombre propio no es un
/// detalle de diseño: estigmatiza a quien vive ahí, y en un mockup que se enseña a jurados y
/// autoridades el daño sería real aunque el dato sea falso.
///
/// TODO(seguridad): sustituir [moreliaUnsafeZones] por datos reales, y con ellos acordar cómo
/// se muestran. Fuentes posibles: incidencia del Secretariado Ejecutivo (SESNSP), reportes
/// ciudadanos del propio sistema, o el inventario de alumbrado público del municipio. Al
/// hacerlo, quitar el aviso de datos simulados de la pantalla.
library;

import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import 'path_geometry.dart';

const Distance _distance = Distance();

/// Velocidad a la que se convierte distancia en tiempo.
///
/// 5 km/h es paso de caminata normal — los mismos ~1.4 m/s que ya usaba la pantalla de ir a la
/// parada.
const double walkingSpeedKmh = 5;

/// Cuánto se separa el rodeo del borde de una zona.
///
/// Pegar el camino al filo de la zona cumpliría la regla y no serviría de nada: quien camina no
/// ve una circunferencia, ve una esquina. Un 25% de margen lo aleja lo suficiente para que el
/// rodeo se sienta como un rodeo.
const double zoneClearanceFactor = 1.25;

/// Cuántos puntos de paso se colocan alrededor de cada zona.
///
/// Con 12 el rodeo queda razonablemente pegado al contorno sin volver el grafo pesado.
const int waypointsPerZone = 12;

/// Minutos que toma recorrer [meters] a pie.
///
/// Nunca devuelve cero: "llegas en 0 min" se lee como que ya pasó.
int minutesOnFoot(double meters) {
  final minutes = meters / (walkingSpeedKmh * 1000 / 60);
  return math.max(1, minutes.round());
}

/// Una zona por la que no se recomienda pasar caminando.
class UnsafeZone {
  const UnsafeZone({
    required this.reason,
    required this.center,
    required this.radiusMeters,
  });

  /// Por qué no se recomienda. Es lo que se le enseña a quien camina: un color rojo sin motivo
  /// solo produce miedo, y el motivo es lo que deja decidir por cuenta propia.
  final String reason;

  final LatLng center;
  final double radiusMeters;

  bool contains(LatLng point) => _distance(center, point) <= radiusMeters;
}

/// Zonas simuladas sobre el corredor de la demo.
///
/// Colocadas a propósito entre la Catedral y los destinos habituales, para que el trazado tenga
/// algo que rodear. La tercera queda fuera del camino: no todas las zonas del mapa estorban, y
/// verlo así deja claro que el rodeo responde al trazado y no al capricho.
const List<UnsafeZone> moreliaUnsafeZones = [
  UnsafeZone(
    reason: 'Tramo sin alumbrado',
    center: LatLng(19.6998, -101.1815),
    radiusMeters: 200,
  ),
  UnsafeZone(
    reason: 'Reportes de incidentes',
    center: LatLng(19.6958, -101.1795),
    radiusMeters: 150,
  ),
  UnsafeZone(
    reason: 'Obra sin banqueta',
    center: LatLng(19.6935, -101.1755),
    radiusMeters: 140,
  ),
];

/// El camino a pie, con lo que se supo de las zonas al trazarlo.
class WalkRoute {
  const WalkRoute({
    required this.points,
    required this.totalMeters,
    required this.directMeters,
    required this.zonesOnDirectPath,
    required this.crossesUnsafeZone,
    required this.plannedMeters,
  });

  final List<LatLng> points;
  final double totalMeters;

  /// Lo que medía el camino antes de ajustarlo a las calles.
  ///
  /// Existe para que el rodeo se siga midiendo contra lo que costó **esquivar la zona**, y no
  /// contra el zigzag normal de las manzanas: por calles cualquier camino es más largo que la
  /// recta, y sin esto "rodea 300 m" pasaría a decir cifras que no tienen que ver con las
  /// zonas. Sin ajuste a calles vale lo mismo que [totalMeters].
  final double plannedMeters;

  /// Lo que habría medido irse en línea recta. Es la referencia del rodeo.
  final double directMeters;

  /// Zonas que la línea recta habría atravesado.
  final List<UnsafeZone> zonesOnDirectPath;

  /// El trazado final todavía cruza una zona.
  ///
  /// Pasa cuando no hay manera de evitarlas — el destino está dentro de una, por ejemplo. Se
  /// avisa en vez de fingir que el camino es seguro.
  final bool crossesUnsafeZone;

  /// El trazado se desvió para esquivar algo.
  bool get detoured => zonesOnDirectPath.isNotEmpty && !crossesUnsafeZone;

  /// Cuánto costó el rodeo. Es el precio de la seguridad, y conviene enseñarlo.
  double get extraMeters => math.max(0, plannedMeters - directMeters);

  int get minutes => minutesOnFoot(totalMeters);

  LatLng pointAt(double meters) => pointAlongPath(points, meters);

  /// El mismo camino, ajustado a las calles reales.
  ///
  /// Rechaza el ajuste si el trazado por calles cruzara una zona que este camino sí esquivaba:
  /// la promesa de esta pantalla es no pasar por ellas, y eso pesa más que verse bonito. En
  /// ese caso se queda el trazado de antes, recto pero limpio.
  WalkRoute onRoads(List<LatLng> road, List<UnsafeZone> zones) {
    if (road.length < 2) return this;
    if (!crossesUnsafeZone && pathCrossesZones(road, zones)) return this;

    return WalkRoute(
      points: road,
      totalMeters: pathLengthMeters(road),
      directMeters: directMeters,
      zonesOnDirectPath: zonesOnDirectPath,
      crossesUnsafeZone: crossesUnsafeZone,
      plannedMeters: plannedMeters,
    );
  }
}

/// Si alguna parte de [path] entra en alguna de [zones].
///
/// Mismo criterio que usa el trazador al decidir por dónde puede pasar: se ignoran las zonas
/// que contienen un extremo del segmento, porque si el origen o el destino caen dentro de una,
/// lo útil es salir, no negarse a mover el pie.
bool pathCrossesZones(List<LatLng> path, List<UnsafeZone> zones) {
  for (var i = 0; i < path.length - 1; i++) {
    final a = path[i];
    final b = path[i + 1];
    for (final zone in zones) {
      if (zone.contains(a) || zone.contains(b)) continue;
      if (pointToSegmentMeters(zone.center, a, b) < zone.radiusMeters) {
        return true;
      }
    }
  }
  return false;
}

/// Traza un camino a pie de [origin] a [destination] esquivando las zonas marcadas.
///
/// Arma un grafo de visibilidad: los nodos son el origen, el destino y un anillo de puntos de
/// paso alrededor de cada zona; dos nodos se conectan solo si el segmento entre ellos no cruza
/// ninguna zona. Dijkstra sobre eso da el camino más corto de los que no pasan por donde no se
/// debe.
///
/// Los tramos son líneas rectas entre puntos de paso, no calles reales: el ruteo peatonal de
/// verdad necesita un motor de calles y `CLAUDE.md` lo deja fuera de esta fase.
WalkRoute planWalkRoute({
  required LatLng origin,
  required LatLng destination,
  List<UnsafeZone> zones = moreliaUnsafeZones,
}) {
  final directMeters = _distance(origin, destination);
  final onDirectPath = [
    for (final zone in zones)
      if (pointToSegmentMeters(zone.center, origin, destination) <
          zone.radiusMeters)
        zone,
  ];

  /// Si el segmento pasa por una zona.
  ///
  /// Se ignoran las zonas que ya contienen alguno de los extremos: cuando se arranca o se
  /// termina dentro de una, lo útil es salir, no negarse a mover el pie.
  bool blocked(LatLng a, LatLng b) {
    for (final zone in zones) {
      if (zone.contains(a) || zone.contains(b)) continue;
      if (pointToSegmentMeters(zone.center, a, b) < zone.radiusMeters) {
        return true;
      }
    }
    return false;
  }

  if (!blocked(origin, destination)) {
    return WalkRoute(
      points: [origin, destination],
      totalMeters: directMeters,
      plannedMeters: directMeters,
      directMeters: directMeters,
      zonesOnDirectPath: onDirectPath,
      crossesUnsafeZone: onDirectPath.isNotEmpty,
    );
  }

  // 0 = origen, 1 = destino, de ahí en adelante los puntos de paso.
  final nodes = <LatLng>[origin, destination];
  for (final zone in zones) {
    final ringRadius = zone.radiusMeters * zoneClearanceFactor;
    for (var i = 0; i < waypointsPerZone; i++) {
      final bearing = 2 * math.pi * i / waypointsPerZone;
      final waypoint = offsetBy(zone.center, ringRadius, bearing);
      // Un punto de paso metido en otra zona no sirve de nada.
      final insideAnother = zones.any(
        (other) => other != zone && other.contains(waypoint),
      );
      if (!insideAnother) nodes.add(waypoint);
    }
  }

  // Dijkstra con búsqueda lineal del mínimo: con unas decenas de nodos sale más barato que
  // mantener una cola de prioridad.
  final best = List<double>.filled(nodes.length, double.infinity);
  final cameFrom = List<int>.filled(nodes.length, -1);
  final settled = List<bool>.filled(nodes.length, false);
  best[0] = 0;

  while (true) {
    var current = -1;
    var currentCost = double.infinity;
    for (var i = 0; i < nodes.length; i++) {
      if (!settled[i] && best[i] < currentCost) {
        current = i;
        currentCost = best[i];
      }
    }
    if (current == -1 || current == 1) break;
    settled[current] = true;

    for (var next = 0; next < nodes.length; next++) {
      if (settled[next] || next == current) continue;
      if (blocked(nodes[current], nodes[next])) continue;

      final candidate = currentCost + _distance(nodes[current], nodes[next]);
      if (candidate < best[next]) {
        best[next] = candidate;
        cameFrom[next] = current;
      }
    }
  }

  if (cameFrom[1] == -1) {
    // Ninguna combinación de rodeos llega: no hay camino limpio. Se traza el directo y se dice.
    return WalkRoute(
      points: [origin, destination],
      totalMeters: directMeters,
      plannedMeters: directMeters,
      directMeters: directMeters,
      zonesOnDirectPath: onDirectPath,
      crossesUnsafeZone: true,
    );
  }

  final path = <LatLng>[];
  for (var node = 1; node != -1; node = cameFrom[node]) {
    path.add(nodes[node]);
    if (node == 0) break;
  }
  final points = path.reversed.toList();

  return WalkRoute(
    points: points,
    totalMeters: pathLengthMeters(points),
    plannedMeters: pathLengthMeters(points),
    directMeters: directMeters,
    zonesOnDirectPath: onDirectPath,
    crossesUnsafeZone: false,
  );
}
