import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:maas_morelia/data/bike_network.dart';

/// El trazado en bici y su promesa: **priorizar ciclovías**.
///
/// Lo que se verifica aquí es que la preferencia sea real y no decorativa — que el trazado
/// acepte alargarse con tal de ir protegido— pero también que tenga límite, porque un rodeo
/// enorme por ir en ciclovía deja de ser un favor.
void main() {
  const distance = Distance();

  // Los mismos puntos de referencia que usa el resto de la demo.
  const catedral = LatLng(19.7008, -101.1844);
  const tarascas = LatLng(19.6989, -101.1789);
  const bosque = LatLng(19.6917, -101.1770);

  group('planBikeRoute prioriza la ciclovía', () {
    test('usa la ciclovía cuando queda de paso', () {
      final route = planBikeRoute(origin: catedral, destination: tarascas);

      expect(route.usesLane, isTrue);
      expect(route.laneNames, contains('Ciclovía Av. Madero'));
      // No es un tramito simbólico: casi todo el viaje va protegido.
      expect(route.laneShare, greaterThan(0.8));
    });

    test('acepta alargarse con tal de ir por ciclovía', () {
      // Arranca al norte de la ciclovía de Madero. Bajar a tomarla y volver a subir es más
      // largo en metros que irse derecho — y aun así debe preferirla, que es justamente lo
      // que significa "priorizar ciclovías".
      const origin = LatLng(19.7020, -101.1925);
      final route = planBikeRoute(origin: origin, destination: tarascas);

      expect(route.usesLane, isTrue);
      expect(
        route.totalMeters,
        greaterThan(distance(origin, tarascas)),
        reason: 'el trazado por ciclovía debería ser el rodeo, no el atajo',
      );
    });

    test('encadena varias ciclovías en un mismo viaje', () {
      // De la Catedral al Bosque hay que pasar por las tres: Madero, la Calzada y Acueducto.
      final route = planBikeRoute(origin: catedral, destination: bosque);

      expect(route.laneNames.length, greaterThanOrEqualTo(2));
      expect(route.laneNames, contains('Ciclovía Av. Acueducto'));
    });

    test('el rodeo tiene límite: sin ciclovía de paso se va derecho', () {
      // 300 m al norte de la Catedral. Ninguna ciclovía va hacia allá, así que desviarse solo
      // alargaría el viaje. Decir "ruta por ciclovía" aquí sería mentira.
      const northOfCentro = LatLng(19.7035, -101.1844);
      final route = planBikeRoute(origin: catedral, destination: northOfCentro);

      expect(route.usesLane, isFalse);
      expect(route.laneMeters, 0);
      expect(route.segments, hasLength(1));
      expect(route.totalMeters, closeTo(distance(catedral, northOfCentro), 1));
    });

    test('sin red de ciclovías traza la línea directa', () {
      final route = planBikeRoute(
        origin: catedral,
        destination: tarascas,
        lanes: const [],
      );

      expect(route.usesLane, isFalse);
      expect(route.totalMeters, closeTo(distance(catedral, tarascas), 1));
    });
  });

  group('el recorrido se puede seguir punto por punto', () {
    test('empieza en el origen y termina en el destino', () {
      final route = planBikeRoute(origin: catedral, destination: bosque);

      expect(distance(route.pointAt(0), catedral), lessThan(1));
      expect(
        distance(route.pointAt(route.totalMeters + 500), bosque),
        lessThan(1),
      );
    });

    test('a media ruta va sobre la línea, no en el aire', () {
      final route = planBikeRoute(origin: catedral, destination: bosque);
      final middle = route.pointAt(route.totalMeters / 2);

      // Debe caer cerca de alguno de los vértices del trazado; si el interpolador estuviera
      // mal, se saldría del corredor.
      final nearest = route.points
          .map((point) => distance(point, middle))
          .reduce((a, b) => a < b ? a : b);
      expect(nearest, lessThan(400));
    });

    test('la etiqueta se cuelga del tramo protegido más largo', () {
      final route = planBikeRoute(origin: catedral, destination: bosque);
      final anchor = route.laneLabelAnchor;

      expect(anchor, isNotNull);
      expect(distance(anchor!, catedral), greaterThan(0));
    });

    test('sin ciclovía no hay dónde colgar la etiqueta', () {
      final route = planBikeRoute(
        origin: catedral,
        destination: const LatLng(19.7035, -101.1844),
      );

      expect(route.laneLabelAnchor, isNull);
    });
  });

  group('el tiempo sale de la velocidad de la bici', () {
    test('2.5 km a 15 km/h son 10 minutos', () {
      expect(minutesByBike(2500), 10);
    });

    test('nunca dice cero minutos', () {
      // "Llegas en 0 min" se lee como que ya pasó.
      expect(minutesByBike(0), 1);
      expect(minutesByBike(30), 1);
    });
  });
}
