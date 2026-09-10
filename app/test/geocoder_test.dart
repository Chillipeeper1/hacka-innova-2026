/// Cómo se convierte una respuesta de Nominatim en la dirección que se lee en pantalla.
///
/// Los payloads están copiados de respuestas reales del servicio para puntos de Morelia, no
/// escritos a mano: lo que hay que probar es lo que OSM devuelve de verdad en esta ciudad
/// —calles con número, casi nunca colonia, y nombres de lugar larguísimos— y no un ejemplo
/// ideal de la documentación.
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:maas_morelia/data/geocoder.dart';

Map<String, dynamic> _parse(String json) =>
    jsonDecode(json) as Map<String, dynamic>;

/// Sobre la Calle Antonio Alzate, cerca de Catedral.
const String alzatePayload = '''
{"place_id":312272236,"osm_type":"node","osm_id":11196257135,
 "lat":"19.7007813","lon":"-101.1837720","category":"amenity",
 "name":"Instituto de la Mujer Moreliana para la Igualdad Sustantiva",
 "display_name":"Instituto de la Mujer Moreliana para la Igualdad Sustantiva, 805, Calle Antonio Alzate, Morelia, Michoacán, 58000, México",
 "address":{"amenity":"Instituto de la Mujer Moreliana para la Igualdad Sustantiva",
   "house_number":"805","road":"Calle Antonio Alzate","city":"Morelia","county":"Morelia",
   "state":"Michoacán","postcode":"58000","country":"México","country_code":"mx"}}''';

/// Sobre la Calzada Ventura Puente, junto al Acueducto. Sin número de casa.
const String venturaPuentePayload = '''
{"place_id":312684627,"osm_type":"way","osm_id":400855116,
 "lat":"19.6977412","lon":"-101.1789884","category":"tourism",
 "name":"Museo de Historia Natural \\"Manuel Martínez Solórzano\\"",
 "display_name":"Museo de Historia Natural \\"Manuel Martínez Solórzano\\", Calzada Ventura Puente, Morelia, Michoacán, 58020, México",
 "address":{"tourism":"Museo de Historia Natural \\"Manuel Martínez Solórzano\\"",
   "road":"Calzada Ventura Puente","city":"Morelia","county":"Morelia",
   "state":"Michoacán","postcode":"58020","country":"México","country_code":"mx"}}''';

void main() {
  group('formatNominatimAddress', () {
    test('arma calle con número y localidad', () {
      expect(
        formatNominatimAddress(_parse(alzatePayload)),
        'Calle Antonio Alzate 805, Morelia',
      );
    });

    test('omite el número cuando la respuesta no lo trae', () {
      expect(
        formatNominatimAddress(_parse(venturaPuentePayload)),
        'Calzada Ventura Puente, Morelia',
      );
    });

    test('prefiere la colonia a la ciudad como segunda pieza', () {
      final address = _parse(alzatePayload);
      (address['address'] as Map<String, dynamic>)['neighbourhood'] =
          'Centro Histórico';

      expect(
        formatNominatimAddress(address),
        'Calle Antonio Alzate 805, Centro Histórico',
      );
    });

    test('sin calle usa el nombre del lugar: parques, plazas, explanadas', () {
      expect(
        formatNominatimAddress(
          _parse(
            '''
{"name":"Bosque Cuauhtémoc",
 "display_name":"Bosque Cuauhtémoc, Morelia, Michoacán, México",
 "address":{"leisure":"Bosque Cuauhtémoc","city":"Morelia","country":"México"}}''',
          ),
        ),
        'Bosque Cuauhtémoc, Morelia',
      );
    });

    test('no repite la pieza cuando calle y zona son lo mismo', () {
      expect(
        formatNominatimAddress(
          _parse('{"name":"Charo","address":{"village":"Charo"}}'),
        ),
        'Charo',
      );
    });

    test('sin domicilio desmenuzado recorta el display_name', () {
      expect(
        formatNominatimAddress(
          _parse('{"display_name":"Tarímbaro, Michoacán, 58880, México"}'),
        ),
        'Tarímbaro, Michoacán',
      );
    });

    test('devuelve null cuando no hay nada que enseñar', () {
      // `{"error":"Unable to geocode"}`: pasa en medio del lago o del campo. Quien llama lo
      // traduce a las coordenadas del pin.
      expect(
        formatNominatimAddress(_parse('{"error":"Unable to geocode"}')),
        isNull,
      );
    });
  });
}
