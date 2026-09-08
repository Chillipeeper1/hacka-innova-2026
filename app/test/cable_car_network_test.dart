import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:maas_morelia/data/cable_car_network.dart';

/// El armado del viaje en teleférico.
///
/// Lo que se verifica es la promesa: **la estación más cercana a ti** para subir y **la que te
/// deja más cerca** para bajar — y que cuando ninguna sirve se diga, en vez de mandar a
/// caminar dos kilómetros para nada.
void main() {
  const distance = Distance();

  const catedral = LatLng(19.7008, -101.1844);
  const acueducto = LatLng(19.6975, -101.1791);
  const farSouth = LatLng(19.6800, -101.1830);

  /// La estación de la red que de verdad queda más cerca de un punto.
  CableStation nearestOf(CableLine line, LatLng point) => line.stations.reduce(
    (a, b) =>
        distance(a.location, point) <= distance(b.location, point) ? a : b,
  );

  group('planCableCarTrip elige las dos estaciones', () {
    test('sube en la más cercana al usuario', () {
      final plan = planCableCarTrip(origin: catedral, destination: acueducto)!;

      expect(plan.boarding.name, 'Estación Centro');
      expect(plan.boarding, nearestOf(plan.line, catedral));
      expect(plan.metersToBoarding, lessThan(50));
    });

    test('baja en la que deja más cerca del destino', () {
      final plan = planCableCarTrip(origin: catedral, destination: acueducto)!;

      expect(plan.alighting.name, 'Estación Acueducto');
      expect(plan.alighting, nearestOf(plan.line, acueducto));
      expect(plan.metersFromAlightingToDestination, lessThan(50));
    });

    test('cambia de línea cuando la otra deja más cerca', () {
      // Al sur, la Línea 1 obligaría a caminar casi dos kilómetros al bajarse; la Línea 2
      // deja en la puerta aunque haya que caminar más para subirse.
      final plan = planCableCarTrip(origin: catedral, destination: farSouth)!;

      expect(plan.line.name, contains('Línea 2'));
      expect(plan.alighting.name, 'Estación Sur');
    });

    test('la cabina para en las estaciones intermedias', () {
      final plan = planCableCarTrip(origin: catedral, destination: farSouth)!;
      final ride = plan.legs.firstWhere(
        (leg) => leg.mode == CableLegMode.cable,
      );

      // Bosque → Camelinas → Sur: el trazado sigue la línea, no vuela en recta.
      expect(ride.points, hasLength(3));
    });
  });

  group('planCableCarTrip avisa cuando no sirve', () {
    test('sin estación a distancia caminable', () {
      final plan = planCableCarTrip(
        origin: const LatLng(19.7800, -101.2500),
        destination: acueducto,
      );

      expect(plan, isNull);
    });

    test('cuando subir y bajar serían la misma estación', () {
      // Un viaje de 50 m: el teleférico no lleva a ningún lado.
      final plan = planCableCarTrip(
        origin: catedral,
        destination: const LatLng(19.7012, -101.1844),
      );

      expect(plan, isNull);
    });

    test('sin líneas configuradas', () {
      expect(
        planCableCarTrip(
          origin: catedral,
          destination: acueducto,
          lines: const [],
        ),
        isNull,
      );
    });
  });

  group('los tramos y el tiempo', () {
    test('arranca en el origen y termina en el destino', () {
      final plan = planCableCarTrip(origin: catedral, destination: acueducto)!;

      expect(distance(plan.points.first, catedral), lessThan(1));
      expect(distance(plan.points.last, acueducto), lessThan(1));
    });

    test('no dibuja el tramo a pie si ya estás en la estación', () {
      final plan = planCableCarTrip(
        origin: moreliaCableLines.first.stations[2].location,
        destination: acueducto,
      )!;

      expect(plan.legs.first.mode, CableLegMode.cable);
    });

    test('cada tramo cuenta a su velocidad', () {
      final plan = planCableCarTrip(origin: catedral, destination: farSouth)!;

      // El mismo recorrido a pie tardaría mucho más: si el tiempo ignorara el modo, la cabina
      // no se notaría.
      final asIfWalking = plan.totalMeters / (5 * 1000 / 60);
      expect(plan.totalMinutes, lessThan(asIfWalking));
    });

    test('el tramo actual cambia conforme se avanza', () {
      final plan = planCableCarTrip(origin: catedral, destination: acueducto)!;

      expect(plan.legIndexAt(0), 0);
      expect(plan.legAt(0).mode, CableLegMode.walk);
      expect(plan.legAt(plan.totalMeters - 1).mode, CableLegMode.walk);
      expect(plan.legAt(plan.totalMeters / 2).mode, CableLegMode.cable);
    });

    test('lo que falta baja conforme se avanza, y nunca llega a cero', () {
      final plan = planCableCarTrip(origin: catedral, destination: farSouth)!;

      expect(
        plan.remainingMinutesFrom(plan.totalMeters / 2),
        lessThan(plan.totalMinutes),
      );
      expect(plan.remainingMinutesFrom(plan.totalMeters), 1);
    });
  });
}
