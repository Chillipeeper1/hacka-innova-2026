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
      expectClearOfZones(
        planWalkRoute(origin: catedral, destination: tarascas),
      );
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

  group('remainingPath', () {
    // Lo que queda por andar de un trazado por calles. Sin esto la pantalla de "ir a la
    // parada" dibujaba una recta del pie del usuario a la parada, cruzando manzanas.
    const trazado = [
      LatLng(19.7008, -101.1844),
      LatLng(19.7005, -101.1830),
      LatLng(19.6996, -101.1829),
      LatLng(19.6989, -101.1789),
    ];

    test('arranca en la posición real, no en el vértice más cercano', () {
      const enElCamino = LatLng(19.7004, -101.1831);
      final resto = remainingPath(trazado, enElCamino);

      expect(resto.first, enElCamino);
      expect(resto.last, trazado.last);
    });

    test('deja atrás lo ya andado', () {
      final alPrincipio = remainingPath(trazado, trazado.first);
      final casiLlegando = remainingPath(trazado, trazado[2]);

      expect(casiLlegando.length, lessThan(alPrincipio.length));
      // Y nunca retrocede: ningún punto del resto queda antes del que ya se pasó.
      expect(casiLlegando.contains(trazado[1]), isFalse);
    });

    test('sin trazado devuelve la recta al destino', () {
      // El respaldo cuando el servidor no dio nada: exactamente lo que se dibujaba antes.
      const desde = LatLng(19.7008, -101.1844);
      const hasta = LatLng(19.6989, -101.1789);

      expect(remainingPath(const [hasta], desde), [desde, hasta]);
    });
  });

  group('pathBetween', () {
    // El tramo ya recorrido de la pantalla "en viaje". Antes era una recta de la parada de
    // subida a la unidad, y como la línea de la ruta sigue las calles, el rastro azul cortaba
    // manzanas por su cuenta.
    const trazado = [
      LatLng(19.7008, -101.1844),
      LatLng(19.7005, -101.1830),
      LatLng(19.6996, -101.1829),
      LatLng(19.6989, -101.1789),
    ];

    test('sigue el trazado entre los dos puntos, con extremos exactos', () {
      const parada = LatLng(19.7008, -101.1844);
      const unidad = LatLng(19.6994, -101.1820);

      final tramo = pathBetween(trazado, parada, unidad);

      expect(tramo.first, parada);
      expect(tramo.last, unidad);
      // Pasa por el vértice de en medio en vez de cortar en diagonal.
      expect(tramo.contains(trazado[1]), isTrue);
      expect(tramo.length, greaterThan(2));
    });

    test('no se lleva el trazado que queda por delante de la unidad', () {
      const parada = LatLng(19.7008, -101.1844);
      const unidad = LatLng(19.7005, -101.1830);

      final tramo = pathBetween(trazado, parada, unidad);

      expect(tramo.contains(trazado[2]), isFalse);
      expect(tramo.contains(trazado.last), isFalse);
    });

    test('sirve igual con la unidad yendo en sentido contrario', () {
      // El recorrido simulado da la vuelta al llegar al final, así que la unidad puede quedar
      // antes de la parada de subida sobre el trazado. El tramo se dibuja igual, de la parada
      // a la unidad.
      const parada = LatLng(19.6989, -101.1789);
      const unidad = LatLng(19.7005, -101.1830);

      final tramo = pathBetween(trazado, parada, unidad);

      expect(tramo.first, parada);
      expect(tramo.last, unidad);
      expect(tramo.contains(trazado[2]), isTrue);
    });

    test('sin trazado devuelve la recta, como antes', () {
      // El teleférico va por el aire y su `shape` viene vacío: ahí la recta es lo correcto.
      const parada = LatLng(19.7008, -101.1844);
      const unidad = LatLng(19.6989, -101.1789);

      expect(pathBetween(const [], parada, unidad), [parada, unidad]);
    });
  });

  group('ajuste a calles', () {
    // Un camino que esquiva una zona, y dos versiones "por calles" del mismo: una limpia y
    // otra que vuelve a meterse en la zona.
    final route = planWalkRoute(origin: catedral, destination: bosque);

    test('adopta el trazado por calles cuando sigue limpio', () {
      // Se simula el ajuste con el propio trazado más un punto: basta con que sea distinto y
      // no cruce nada para que se acepte.
      final road = [
        route.points.first,
        ...route.points.skip(1).take(route.points.length - 2),
        route.points.last,
      ];
      final ajustada = route.onRoads([...road, road.last], moreliaUnsafeZones);

      expect(ajustada.points.length, greaterThanOrEqualTo(route.points.length));
      expect(ajustada.crossesUnsafeZone, isFalse);
    });

    test('rechaza el trazado por calles si volviera a cruzar una zona', () {
      // La promesa de esta pantalla es no pasar por las zonas marcadas. Verse bonito no la
      // sustituye: si el ajuste ensucia el camino, se queda el de antes.
      expect(route.crossesUnsafeZone, isFalse);
      final recta = [catedral, bosque];
      expect(pathCrossesZones(recta, moreliaUnsafeZones), isTrue);

      final ajustada = route.onRoads(recta, moreliaUnsafeZones);

      expect(identical(ajustada, route), isTrue);
      expect(ajustada.points, route.points);
    });

    test('el rodeo se sigue midiendo contra la zona, no contra las calles', () {
      // Por calles cualquier camino es más largo que la recta. Si `extraMeters` se midiera
      // sobre el trazado ajustado, "rodea 300 m" pasaría a decir cifras sin relación con las
      // zonas marcadas.
      final antes = route.extraMeters;
      final largo = [
        for (var i = 0; i < route.points.length; i++) ...[
          route.points[i],
          if (i + 1 < route.points.length)
            lerpLatLng(route.points[i], route.points[i + 1], 0.5),
        ],
      ];
      final ajustada = route.onRoads(largo, moreliaUnsafeZones);

      expect(ajustada.extraMeters, closeTo(antes, 0.001));
      expect(ajustada.plannedMeters, closeTo(route.totalMeters, 0.001));
    });

    test('sin trazado del servidor se queda el propio', () {
      expect(
        identical(route.onRoads(const [], moreliaUnsafeZones), route),
        isTrue,
      );
    });
  });
}
