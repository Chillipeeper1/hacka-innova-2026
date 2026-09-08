import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:maas_morelia/data/path_geometry.dart';
import 'package:maas_morelia/data/walk_route.dart';

/// El camino a pie y su promesa: **no pasar por las zonas marcadas**.
///
/// La prueba que más importa no es que el trazado se desvíe, sino que el resultado esté
/// limpio: ningún tramo del camino final puede cruzar una zona. Un rodeo que se ve bonito y
/// aun así roza el borde no sirve de nada.
void main() {
  const distance = Distance();

  const catedral = LatLng(19.7008, -101.1844);
  const tarascas = LatLng(19.6989, -101.1789);
  const bosque = LatLng(19.6917, -101.1770);

  /// Al oeste del centro: no hay zonas marcadas para ese lado.
  const westOfCentro = LatLng(19.7010, -101.1900);

  /// Ningún tramo del camino cruza una zona.
  void expectClearOfZones(WalkRoute route) {
    for (var i = 0; i < route.points.length - 1; i++) {
      final a = route.points[i];
      final b = route.points[i + 1];
      for (final zone in moreliaUnsafeZones) {
        if (zone.contains(a) || zone.contains(b)) continue;
        expect(
          pointToSegmentMeters(zone.center, a, b),
          greaterThanOrEqualTo(zone.radiusMeters),
          reason:
              'el tramo $i cruza la zona "${zone.reason}"; '
              'el rodeo no sirvió de nada',
        );
      }
    }
  }

  group('planWalkRoute esquiva las zonas marcadas', () {
    test('rodea cuando la línea recta cruzaría una zona', () {
      final route = planWalkRoute(origin: catedral, destination: tarascas);

      expect(route.zonesOnDirectPath, isNotEmpty);
      expect(route.crossesUnsafeZone, isFalse);
      expect(route.detoured, isTrue);
      expect(route.totalMeters, greaterThan(route.directMeters));
      expect(route.points.length, greaterThan(2));
    });

    test('el camino resultante no toca ninguna zona', () {
      expectClearOfZones(planWalkRoute(origin: catedral, destination: tarascas));
      expectClearOfZones(planWalkRoute(origin: catedral, destination: bosque));
    });

    test('el rodeo se mantiene razonable', () {
      // Esquivar no puede salir a cualquier precio: un camino tres veces más largo deja de ser
      // una recomendación y se vuelve un estorbo.
      final route = planWalkRoute(origin: catedral, destination: bosque);

      expect(route.totalMeters, lessThan(route.directMeters * 1.6));
    });

    test('sin zonas de por medio se va derecho', () {
      final route = planWalkRoute(origin: catedral, destination: westOfCentro);

      expect(route.zonesOnDirectPath, isEmpty);
      expect(route.detoured, isFalse);
      expect(route.crossesUnsafeZone, isFalse);
      expect(route.points, hasLength(2));
      expect(route.totalMeters, closeTo(distance(catedral, westOfCentro), 1));
    });

    test('sin zonas configuradas traza la línea directa', () {
      final route = planWalkRoute(
        origin: catedral,
        destination: tarascas,
        zones: const [],
      );

      expect(route.points, hasLength(2));
      expect(route.crossesUnsafeZone, isFalse);
    });

    test('avisa cuando el destino cae dentro de una zona', () {
      // No se puede prometer un camino limpio hacia un punto que está adentro. Decirlo es más
      // útil que trazar un rodeo que termina entrando igual.
      final route = planWalkRoute(
        origin: catedral,
        destination: moreliaUnsafeZones.first.center,
      );

      expect(route.crossesUnsafeZone, isTrue);
      expect(route.detoured, isFalse);
      expect(route.zonesOnDirectPath, contains(moreliaUnsafeZones.first));
    });

    test('reporta qué zonas habría cruzado la línea recta', () {
      final route = planWalkRoute(origin: catedral, destination: bosque);

      expect(route.zonesOnDirectPath.length, greaterThanOrEqualTo(2));
      expect(
        route.zonesOnDirectPath.map((zone) => zone.reason),
        contains('Tramo sin alumbrado'),
      );
    });
  });

  group('el recorrido se puede seguir punto por punto', () {
    test('empieza en el origen y termina en el destino', () {
      final route = planWalkRoute(origin: catedral, destination: bosque);

      expect(distance(route.pointAt(0), catedral), lessThan(1));
      expect(
        distance(route.pointAt(route.totalMeters + 500), bosque),
        lessThan(1),
      );
    });

    test('el extra del rodeo es la diferencia con la recta', () {
      final route = planWalkRoute(origin: catedral, destination: tarascas);

      expect(
        route.extraMeters,
        closeTo(route.totalMeters - route.directMeters, 0.001),
      );
      expect(route.extraMeters, greaterThan(0));
    });
  });

  group('el tiempo sale de la velocidad de caminata', () {
    test('1 km a 5 km/h son 12 minutos', () {
      expect(minutesOnFoot(1000), 12);
    });

    test('nunca dice cero minutos', () {
      expect(minutesOnFoot(0), 1);
      expect(minutesOnFoot(20), 1);
    });
  });
}
