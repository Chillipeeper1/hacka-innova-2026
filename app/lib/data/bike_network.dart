/// Red de ciclovías y trazado de rutas en bici.
///
/// **Los datos de ciclovías son inventados.** No existe todavía una capa verificada de la
/// infraestructura ciclista de Morelia, así que este archivo trae una red simulada anclada a
/// los mismos puntos de referencia que usa el resto de la demo (Catedral, Tarascas, Acueducto,
/// Bosque Cuauhtémoc). Sirve para enseñar el comportamiento —el trazado se desvía para ir por
/// ciclovía— pero no para orientar a nadie en la calle.
///
/// TODO(ciclovías): sustituir [moreliaBikeLanes] por datos reales. Dos fuentes posibles: la
/// capa de infraestructura ciclista del IMPLAN Morelia, o las vías con etiqueta `highway=cycleway`
/// / `cycleway=*` de OpenStreetMap. Al hacerlo, quitar también el aviso de datos simulados de
/// la pantalla del viaje.
library;

import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

const Distance _distance = Distance();

/// Velocidad con la que se convierte distancia en tiempo.
///
/// 15 km/h es lo que promedia una bici urbana **incluyendo** altos, cruces y semáforos; en
/// movimiento va más rápido, pero el número que le importa a quien pregunta "¿en cuánto llego?"
/// es el de puerta a puerta. Coincide con la velocidad del camión ([averageBusSpeedKmh] en
/// `trip_plan.dart`) y no es un error: en tráfico urbano se parecen mucho. La bici gana por otro
/// lado — no hay que caminar a la parada ni esperar la unidad.
const double bikeSpeedKmh = 15;

/// Cuánto peor se considera pedalear sobre calle abierta que sobre ciclovía.
///
/// Es la perilla que hace que el trazado "priorice ciclovías": el algoritmo compara costos, no
/// metros, y un metro de calle cuesta [streetPenalty] metros de ciclovía. Con 1.7, un rodeo que
/// alargue el recorrido hasta un 70% se acepta con tal de ir por infraestructura ciclista;
/// más allá de eso, el rodeo deja de compensar y se va derecho.
const double streetPenalty = 1.7;

/// Dos vértices de ciclovías distintas a menos de esto son el mismo cruce.
///
/// Sin esto la red sería un montón de tramos sueltos y nunca se encadenarían dos ciclovías en
/// un mismo viaje.
const double laneJoinMeters = 80;

/// Minutos que toma recorrer [meters] en bici.
///
/// Nunca devuelve cero, por la misma razón que en el camión: "llegas en 0 min" se lee como que
/// ya pasó.
int minutesByBike(double meters) {
  final minutes = meters / (bikeSpeedKmh * 1000 / 60);
  return math.max(1, minutes.round());
}

/// Un tramo de infraestructura ciclista.
class BikeLane {
  const BikeLane({required this.name, required this.points});

  final String name;
  final List<LatLng> points;
}

/// Red simulada de ciclovías de Morelia.
///
/// Los nombres son de avenidas reales para que el mapa se lea, pero **el trazado no está
/// verificado**: que aquí aparezca una ciclovía no significa que exista. Los extremos coinciden
/// a propósito con los puntos de referencia del seed del backend, para que los tres tramos se
/// encadenen y el recorrido de demo cruce toda la zona.
const List<BikeLane> moreliaBikeLanes = [
  BikeLane(
    name: 'Ciclovía Av. Madero',
    points: [
      LatLng(19.7014, -101.1925),
      LatLng(19.7011, -101.1880),
      LatLng(19.7008, -101.1846),
      LatLng(19.7000, -101.1815),
      LatLng(19.6992, -101.1792),
    ],
  ),
  BikeLane(
    name: 'Ciclovía Calzada Fray Antonio',
    points: [
      LatLng(19.6992, -101.1792),
      LatLng(19.6984, -101.1790),
      LatLng(19.6975, -101.1791),
    ],
  ),
  BikeLane(
    name: 'Ciclovía Av. Acueducto',
    points: [
      LatLng(19.6975, -101.1791),
      LatLng(19.6958, -101.1784),
      LatLng(19.6940, -101.1777),
      LatLng(19.6922, -101.1772),
      LatLng(19.6917, -101.1770),
    ],
  ),
];

/// Un tramo continuo del recorrido, todo por ciclovía o todo por calle.
class BikeSegment {
  const BikeSegment({
    required this.points,
    required this.onLane,
    required this.meters,
    this.laneName,
  });

  final List<LatLng> points;

  /// Si este tramo va sobre infraestructura ciclista.
  final bool onLane;

  final double meters;

  /// Nombre de la ciclovía, cuando [onLane].
  final String? laneName;
}

/// El recorrido completo en bici, partido en tramos de ciclovía y de calle.
class BikeRoute {
  const BikeRoute({
    required this.segments,
    required this.totalMeters,
    required this.laneMeters,
  });

  final List<BikeSegment> segments;
  final double totalMeters;

  /// De los [totalMeters], cuántos van por ciclovía.
  final double laneMeters;

  double get streetMeters => math.max(0, totalMeters - laneMeters);

  /// Si el recorrido aprovecha alguna ciclovía.
  ///
  /// Cuando es `false` no hay que decir "ruta por ciclovía": sería mentira. Pasa cuando el
  /// destino queda lejos de la red y desviarse costaría más de lo que ahorra.
  bool get usesLane => laneMeters > 0;

  /// Qué proporción del viaje va protegida. Es el número que justifica el rodeo.
  double get laneShare => totalMeters <= 0 ? 0 : laneMeters / totalMeters;

  int get minutes => minutesByBike(totalMeters);

  /// Las ciclovías usadas, en el orden en que se recorren y sin repetir.
  List<String> get laneNames {
    final names = <String>[];
    for (final segment in segments) {
      final name = segment.laneName;
      if (segment.onLane && name != null && !names.contains(name)) {
        names.add(name);
      }
    }
    return names;
  }

  /// Todos los puntos del recorrido, de principio a fin.
  List<LatLng> get points {
    final all = <LatLng>[];
    for (final segment in segments) {
      for (final point in segment.points) {
        if (all.isEmpty || all.last != point) all.add(point);
      }
    }
    return all;
  }

  /// El punto que queda a [meters] del arranque, siguiendo el trazado.
  ///
  /// Es lo que mueve al ciclista sobre la línea en vez de en línea recta al destino: si el
  /// recorrido se desvía por una ciclovía, el marcador se desvía con él.
  LatLng pointAt(double meters) {
    final path = points;
    if (path.isEmpty) return const LatLng(0, 0);
    if (meters <= 0) return path.first;

    var left = meters;
    for (var i = 0; i < path.length - 1; i++) {
      final legMeters = _distance(path[i], path[i + 1]);
      if (left <= legMeters) {
        final fraction = legMeters == 0 ? 0.0 : left / legMeters;
        return _lerp(path[i], path[i + 1], fraction);
      }
      left -= legMeters;
    }
    return path.last;
  }

  /// Dónde colgar la etiqueta "ruta por ciclovía": a media altura del tramo protegido más
  /// largo, que es donde se entiende a qué línea se refiere.
  LatLng? get laneLabelAnchor {
    BikeSegment? longest;
    for (final segment in segments) {
      if (!segment.onLane) continue;
      if (longest == null || segment.meters > longest.meters) longest = segment;
    }
    if (longest == null) return null;

    var left = longest.meters / 2;
    for (var i = 0; i < longest.points.length - 1; i++) {
      final legMeters = _distance(longest.points[i], longest.points[i + 1]);
      if (left <= legMeters) {
        final fraction = legMeters == 0 ? 0.0 : left / legMeters;
        return _lerp(longest.points[i], longest.points[i + 1], fraction);
      }
      left -= legMeters;
    }
    return longest.points.last;
  }
}

LatLng _lerp(LatLng a, LatLng b, double t) => LatLng(
  a.latitude + (b.latitude - a.latitude) * t,
  a.longitude + (b.longitude - a.longitude) * t,
);

/// Arista del grafo de ruteo.
class _Edge {
  const _Edge({
    required this.to,
    required this.meters,
    required this.onLane,
    this.laneName,
  });

  final int to;
  final double meters;
  final bool onLane;
  final String? laneName;

  /// Lo que el algoritmo minimiza. Los metros de calle pesan más que los de ciclovía, y de ahí
  /// sale la preferencia por la infraestructura ciclista.
  double get cost => onLane ? meters : meters * streetPenalty;
}

/// Traza el recorrido en bici de [origin] a [destination] prefiriendo ciclovías.
///
/// Arma un grafo pequeño —origen, destino y los vértices de cada ciclovía— y corre Dijkstra
/// sobre el costo penalizado. El resultado siempre incluye la opción de irse derecho por calle,
/// así que si la red no ayuda, el trazado es la línea recta y [BikeRoute.usesLane] queda en
/// `false`.
///
/// No es ruteo por calles reales: los tramos fuera de ciclovía son líneas rectas, porque el
/// ruteo de verdad necesita un motor de calles y `CLAUDE.md` lo deja fuera de esta fase.
BikeRoute planBikeRoute({
  required LatLng origin,
  required LatLng destination,
  List<BikeLane> lanes = moreliaBikeLanes,
}) {
  // 0 = origen, 1 = destino, de ahí en adelante los vértices de las ciclovías.
  final nodes = <LatLng>[origin, destination];
  final nodeLane = <int>[-1, -1];
  for (var laneIndex = 0; laneIndex < lanes.length; laneIndex++) {
    for (final point in lanes[laneIndex].points) {
      nodes.add(point);
      nodeLane.add(laneIndex);
    }
  }

  final graph = List.generate(nodes.length, (_) => <_Edge>[]);
  void connect(int a, int b, {required bool onLane, String? laneName}) {
    final meters = _distance(nodes[a], nodes[b]);
    graph[a].add(
      _Edge(to: b, meters: meters, onLane: onLane, laneName: laneName),
    );
    graph[b].add(
      _Edge(to: a, meters: meters, onLane: onLane, laneName: laneName),
    );
  }

  // Irse derecho por calle siempre es una opción. Es la que gana cuando la red no queda de paso.
  connect(0, 1, onLane: false);

  // Entrar y salir de la red cuesta calle.
  for (var i = 2; i < nodes.length; i++) {
    connect(0, i, onLane: false);
    connect(1, i, onLane: false);
  }

  // Tramos de cada ciclovía.
  var cursor = 2;
  for (final lane in lanes) {
    for (var i = 0; i < lane.points.length - 1; i++) {
      connect(cursor + i, cursor + i + 1, onLane: true, laneName: lane.name);
    }
    cursor += lane.points.length;
  }

  // Cruces entre ciclovías distintas: donde casi se tocan, se puede pasar de una a otra sin
  // bajarse a la calle.
  for (var a = 2; a < nodes.length; a++) {
    for (var b = a + 1; b < nodes.length; b++) {
      if (nodeLane[a] == nodeLane[b]) continue;
      if (_distance(nodes[a], nodes[b]) > laneJoinMeters) continue;
      connect(a, b, onLane: true, laneName: lanes[nodeLane[a]].name);
    }
  }

  // Dijkstra. Con dos docenas de nodos, buscar el mínimo a mano sale más barato que armar una
  // cola de prioridad.
  final best = List<double>.filled(nodes.length, double.infinity);
  final cameFrom = List<_Edge?>.filled(nodes.length, null);
  final cameFromNode = List<int>.filled(nodes.length, -1);
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

    for (final edge in graph[current]) {
      final candidate = currentCost + edge.cost;
      if (candidate < best[edge.to]) {
        best[edge.to] = candidate;
        cameFrom[edge.to] = edge;
        cameFromNode[edge.to] = current;
      }
    }
  }

  // Reconstruir el camino de destino a origen.
  final path = <_Edge>[];
  final visited = <int>[1];
  var node = 1;
  while (node != 0) {
    final edge = cameFrom[node];
    if (edge == null) break;
    path.add(edge);
    node = cameFromNode[node];
    visited.add(node);
  }
  final orderedNodes = visited.reversed.toList();
  final orderedEdges = path.reversed.toList();

  if (orderedEdges.isEmpty || orderedNodes.first != 0) {
    // Sin camino (red vacía, por ejemplo): línea recta.
    final meters = _distance(origin, destination);
    return BikeRoute(
      segments: [
        BikeSegment(
          points: [origin, destination],
          onLane: false,
          meters: meters,
        ),
      ],
      totalMeters: meters,
      laneMeters: 0,
    );
  }

  // Unir aristas seguidas del mismo tipo en un solo tramo dibujable.
  final segments = <BikeSegment>[];
  var totalMeters = 0.0;
  var laneMeters = 0.0;

  var points = <LatLng>[nodes[orderedNodes.first]];
  var onLane = orderedEdges.first.onLane;
  var laneName = orderedEdges.first.laneName;
  var meters = 0.0;

  for (var i = 0; i < orderedEdges.length; i++) {
    final edge = orderedEdges[i];
    final sameKind = edge.onLane == onLane && edge.laneName == laneName;

    if (!sameKind) {
      segments.add(
        BikeSegment(
          points: points,
          onLane: onLane,
          meters: meters,
          laneName: laneName,
        ),
      );
      points = <LatLng>[points.last];
      onLane = edge.onLane;
      laneName = edge.laneName;
      meters = 0;
    }

    points.add(nodes[orderedNodes[i + 1]]);
    meters += edge.meters;
    totalMeters += edge.meters;
    if (edge.onLane) laneMeters += edge.meters;
  }

  segments.add(
    BikeSegment(
      points: points,
      onLane: onLane,
      meters: meters,
      laneName: laneName,
    ),
  );

  return BikeRoute(
    segments: segments,
    totalMeters: totalMeters,
    laneMeters: laneMeters,
  );
}
