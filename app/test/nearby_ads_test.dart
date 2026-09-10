import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:maas_morelia/data/nearby_ads.dart';

/// Los negocios publicitados que aparecen al llegar al destino.
///
/// Lo que se prueba es que **siempre haya** y que **no cambien**: la funcionalidad se enseña en
/// vivo, y unos pines que salgan en distintos lugares en cada corrida convierten el ensayo en
/// algo distinto a la presentación.
void main() {
  const distance = Distance();
  const acueducto = LatLng(19.6975, -101.1791);
  const bosque = LatLng(19.6917, -101.1770);

  test('cualquier destino trae negocios alrededor', () {
    expect(adsAround(acueducto), hasLength(4));
    expect(adsAround(bosque), hasLength(4));
  });

  test('el mismo destino da siempre los mismos negocios en el mismo lugar', () {
    final first = adsAround(acueducto);
    final second = adsAround(acueducto);

    expect(second.map((place) => place.name), first.map((place) => place.name));
    expect(
      second.map((place) => place.location),
      first.map((place) => place.location),
    );
  });

  test('destinos distintos no traen la misma lista', () {
    expect(
      adsAround(bosque).map((place) => place.name),
      isNot(adsAround(acueducto).map((place) => place.name)),
    );
  });

  test('caen a distancia de caminata del destino', () {
    for (final place in adsAround(acueducto)) {
      final meters = distance(acueducto, place.location);
      expect(meters, greaterThanOrEqualTo(adsMinMeters));
      expect(meters, lessThanOrEqualTo(adsMaxMeters));
      // Lo que la tarjeta enseña es esa misma distancia, no un número aparte.
      expect(place.meters, closeTo(meters, 1));
    }
  });

  test('no se repite un negocio en la misma llegada', () {
    final names = adsAround(acueducto).map((place) => place.name).toSet();
    expect(names, hasLength(4));
  });

  test('cada uno trae qué es y qué ofrece', () {
    for (final place in adsAround(acueducto)) {
      expect(place.category, isNotEmpty);
      expect(place.promo, isNotEmpty);
    }
  });
}
