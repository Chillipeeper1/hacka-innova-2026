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
