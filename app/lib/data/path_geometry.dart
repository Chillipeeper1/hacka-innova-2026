/// Geometría de trazados, compartida por los modos que siguen una línea.
///
/// La bici y la caminata hacen lo mismo con distinta pinta: avanzar sobre una polilínea y
/// medir distancias contra ella. Tenerlo dos veces garantizaba que se separaran al primer
/// ajuste.
library;

import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

const Distance _distance = Distance();

/// Metros por grado de latitud. Constante en la práctica.
const double _metersPerLatDegree = 110540;

/// Metros por grado de longitud en el ecuador; se encoge con el coseno de la latitud.
const double _metersPerLngDegreeAtEquator = 111320;

/// Lee una polilínea del servidor: una lista de pares `[lat, lng]`.
///
/// Se manda así, y no como objetos, porque un trazado por calles trae decenas o cientos de
/// puntos por tramo y la forma de objeto multiplicaría el tamaño de la respuesta sin aportar
/// nada. El orden es el mismo que en el resto de la API.
///
/// Cualquier cosa que no encaje descarta el trazado **entero** en vez de dibujar la mitad:
/// quien lo llama tiene una recta con la que caer de pie, y media polilínea no se distingue
/// de una ruta real que se corta a mitad de camino.
List<LatLng> latLngListFromJson(Object? raw) {
  if (raw is! List) return const [];
  final points = <LatLng>[];
  for (final entry in raw) {
    if (entry is! List || entry.length < 2) return const [];
    final lat = entry[0];
    final lng = entry[1];
    if (lat is! num || lng is! num) return const [];
    points.add(LatLng(lat.toDouble(), lng.toDouble()));
  }
  return points;
}

LatLng lerpLatLng(LatLng a, LatLng b, double t) => LatLng(
  a.latitude + (b.latitude - a.latitude) * t,
  a.longitude + (b.longitude - a.longitude) * t,
);

/// Largo total de una polilínea.
double pathLengthMeters(List<LatLng> path) {
  var total = 0.0;
  for (var i = 0; i < path.length - 1; i++) {
    total += _distance(path[i], path[i + 1]);
  }
  return total;
}

/// El punto que queda a [meters] del inicio, siguiendo [path].
///
/// Es lo que mueve un marcador **sobre** el trazado en vez de en línea recta al destino: si el
/// recorrido se desvía, el marcador se desvía con él. Fuera de rango devuelve los extremos.
LatLng pointAlongPath(List<LatLng> path, double meters) {
  if (path.isEmpty) return const LatLng(0, 0);
  if (meters <= 0) return path.first;

  var left = meters;
  for (var i = 0; i < path.length - 1; i++) {
    final legMeters = _distance(path[i], path[i + 1]);
    if (left <= legMeters) {
      final fraction = legMeters == 0 ? 0.0 : left / legMeters;
      return lerpLatLng(path[i], path[i + 1], fraction);
    }
    left -= legMeters;
  }
  return path.last;
}

/// Lo que queda de [path] desde [from], para dibujar solo el camino pendiente.
///
/// Se ancla en el punto del trazado más cercano a [from] y devuelve de ahí al final,
/// empezando por la posición real: así la línea sale del pie del usuario y no de un vértice
/// que quedó unos metros atrás.
List<LatLng> remainingPath(List<LatLng> path, LatLng from) {
  if (path.length < 2) return [from, if (path.isNotEmpty) path.last];

  final closest = _closestIndex(path, from);

  // El vértice más cercano puede haber quedado justo atrás; se salta para no dibujar un
  // pequeño retroceso delante del usuario.
  final desde = closest + 1 < path.length ? closest + 1 : closest;
  return [from, ...path.sublist(desde)];
}

/// El pedazo de [path] que va de [from] a [to].
///
/// Lo usa el rastro del tramo ya recorrido: antes era una recta de la parada de subida a la
/// unidad, y como la línea de la ruta sigue las calles, el rastro cortaba manzanas por su
/// cuenta — el mismo desajuste que se veía en el icono, pero en la estela.
///
/// Los dos extremos son exactos —la parada y la unidad— y en medio van los vértices del
/// trazado que quedan entre ellos. La unidad puede ir en cualquiera de los dos sentidos (el
/// recorrido da la vuelta al llegar al final), así que el pedazo se recorta igual en ambos y
/// se devuelve siempre en el orden de [from] a [to].
///
/// Sin trazado —el teleférico, que va por el aire— devuelve la recta entre los dos, que ahí es
/// lo correcto.
List<LatLng> pathBetween(List<LatLng> path, LatLng from, LatLng to) {
  if (path.length < 2) return [from, to];

  final start = _closestIndex(path, from);
  final end = _closestIndex(path, to);
  if (start == end) return [from, to];

  // Se dejan fuera los dos vértices ancla: el de la unidad puede caer unos metros por delante
  // de ella, y dibujarlo haría que la estela se pasara de largo.
  final between = start < end
      ? path.sublist(start + 1, end)
      : path.sublist(end + 1, start).reversed.toList();

  return [from, ...between, to];
}

/// El vértice de [path] más cercano a [point].
int _closestIndex(List<LatLng> path, LatLng point) {
  var closest = 0;
  var best = double.infinity;
  for (var i = 0; i < path.length; i++) {
    final meters = _distance(point, path[i]);
    if (meters < best) {
      best = meters;
      closest = i;
    }
  }
  return closest;
}

/// Distancia de un punto al segmento `a`–`b`.
///
/// Proyecta a un plano local antes de medir. A escala de ciudad el error de tratar la Tierra
/// como plana es de centímetros, y a cambio el cálculo es aritmética simple en vez de
/// trigonometría esférica — que es lo que permite probar miles de segmentos contra las zonas
/// sin que se note.
double pointToSegmentMeters(LatLng point, LatLng a, LatLng b) {
  final referenceLat = (a.latitude + b.latitude) / 2 * math.pi / 180;
  final lngScale = _metersPerLngDegreeAtEquator * math.cos(referenceLat);

  double x(LatLng q) => q.longitude * lngScale;
  double y(LatLng q) => q.latitude * _metersPerLatDegree;

  final ax = x(a);
  final ay = y(a);
  final dx = x(b) - ax;
  final dy = y(b) - ay;
  final px = x(point) - ax;
  final py = y(point) - ay;

  final lengthSquared = dx * dx + dy * dy;
  // Segmento degenerado: los dos extremos son el mismo punto.
  if (lengthSquared == 0) return math.sqrt(px * px + py * py);

  final t = ((px * dx + py * dy) / lengthSquared).clamp(0.0, 1.0);
  final offsetX = px - t * dx;
  final offsetY = py - t * dy;
  return math.sqrt(offsetX * offsetX + offsetY * offsetY);
}

/// El punto que queda a [meters] de [center] en la dirección [bearingRadians].
///
/// El cero apunta al norte y crece hacia el este, como una brújula.
LatLng offsetBy(LatLng center, double meters, double bearingRadians) {
  final lngScale =
      _metersPerLngDegreeAtEquator * math.cos(center.latitude * math.pi / 180);

  return LatLng(
    center.latitude + meters * math.cos(bearingRadians) / _metersPerLatDegree,
    center.longitude + meters * math.sin(bearingRadians) / lngScale,
  );
}
