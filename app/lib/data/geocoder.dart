/// Traducción de coordenadas a direcciones legibles (geocodificación inversa).
library;

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../morelia.dart';

/// Convierte un punto del mapa en una dirección que alguien pueda leer.
///
/// Es una interfaz y no una clase suelta porque la pantalla de destino no debe depender de
/// quién resuelve la dirección: en pruebas se sustituye por un doble, y el día que el equipo
/// de backend exponga su propio geocodificador basta con otra implementación.
abstract class ReverseGeocoder {
  /// La dirección de [point], o `null` si no se pudo averiguar.
  ///
  /// Nunca lanza: quedarse sin dirección no es un error que la interfaz deba manejar como
  /// falla, sino un caso normal —sin red, servicio caído, o un punto en medio del campo—
  /// que se resuelve enseñando las coordenadas.
  Future<String?> addressAt(LatLng point);
}

/// Geocodificador inverso sobre Nominatim, el servicio de búsqueda de OpenStreetMap.
///
/// Se llama **desde el cliente** y no a través de `server/`: el contrato de API que fija
/// `CLAUDE.md` no tiene un endpoint para esto y agregarlo es trabajo del equipo de backend.
/// Es el mismo trato que ya tienen las teselas del mapa —un servicio externo que la app
/// consulta por su cuenta— y deja la app funcionando aunque el backend esté apagado.
///
/// La política de uso de Nominatim pide no pasar de una petición por segundo e identificarse
/// con un `User-Agent` propio. Lo primero lo cumple quien llama, esperando a que el mapa se
/// quede quieto; lo segundo se hace aquí, junto con el caché que evita volver a preguntar por
/// un punto ya resuelto. Para producción hay que hospedar la instancia propia y apuntar
/// [baseUrl] ahí: el servicio público no está pensado para el tráfico de una app en la calle.
class NominatimGeocoder implements ReverseGeocoder {
  NominatimGeocoder({http.Client? httpClient, this.baseUrl = defaultBaseUrl})
    : _http = httpClient ?? http.Client();

  /// Se puede apuntar a una instancia propia con
  /// `--dart-define=NOMINATIM_URL=https://...`.
  static const String defaultBaseUrl = String.fromEnvironment(
    'NOMINATIM_URL',
    defaultValue: 'https://nominatim.openstreetmap.org',
  );

  /// Cuánto se espera al servicio antes de rendirse y enseñar las coordenadas.
  static const Duration timeout = Duration(seconds: 6);

  final String baseUrl;
  final http.Client _http;

  /// Direcciones ya resueltas, por punto redondeado.
  ///
  /// Guarda también los fallos (como `null`) a propósito: si el servicio no supo qué hay en
  /// ese punto, tampoco lo sabrá al siguiente arrastre que vuelva ahí.
  final Map<String, String?> _cache = {};

  void dispose() => _http.close();

  @override
  Future<String?> addressAt(LatLng point) async {
    final key = _cacheKey(point);
    if (_cache.containsKey(key)) return _cache[key];

    try {
      final response = await _http
          .get(
            Uri.parse('$baseUrl/reverse').replace(
              queryParameters: {
                'format': 'jsonv2',
                'lat': '${point.latitude}',
                'lon': '${point.longitude}',
                // 18 es el nivel de edificio: la calle con número, no la colonia entera.
                'zoom': '18',
                'addressdetails': '1',
              },
            ),
            headers: const {
              // Nominatim rechaza a quien no se identifica.
              'User-Agent': Morelia.userAgentPackageName,
              'Accept-Language': 'es',
            },
          )
          .timeout(timeout);

      if (response.statusCode != 200) return _remember(key, null);

      final body = jsonDecode(utf8.decode(response.bodyBytes));
      if (body is! Map<String, dynamic>) return _remember(key, null);

      return _remember(key, formatNominatimAddress(body));
    } on Object {
      // Sin red, DNS caído, JSON inesperado: todo termina igual, sin dirección. No se guarda
      // en el caché para que el siguiente intento vuelva a preguntar cuando haya red.
      return null;
    }
  }

  String? _remember(String key, String? address) {
    _cache[key] = address;
    return address;
  }

  /// Cuatro decimales son ~11 m: mover el pin dentro de esa distancia cae en la misma
  /// dirección, así que no vale la pena volver a preguntar.
  String _cacheKey(LatLng point) =>
      '${point.latitude.toStringAsFixed(4)},'
      '${point.longitude.toStringAsFixed(4)}';
}

/// Arma la dirección corta a partir de la respuesta de Nominatim.
///
/// La respuesta trae el domicilio desmenuzado (`road`, `house_number`, `neighbourhood`...) y
/// además un `display_name` con todo hasta el país. Ese último es demasiado largo para el
/// campo de una línea de la pantalla, así que se compone algo de dos piezas —la calle y la
/// colonia— y solo se cae al `display_name` recortado cuando no hay con qué armarlo.
///
/// Manda la **calle** y no el nombre del lugar aunque el punto caiga sobre uno, porque en
/// Morelia los nombres que devuelve OSM son largos ("Sistema Para El Desarrollo Integral De La
/// Familia (DIF Estatal)") y en una línea se cortan justo donde dejan de decir algo. El nombre
/// solo aparece cuando no hay calle: parques, plazas y explanadas, donde es lo único que hay.
///
/// Es una función suelta y pública para poder probarla con respuestas reales sin red de por
/// medio.
String? formatNominatimAddress(Map<String, dynamic> body) {
  String? text(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  final address = body['address'];
  if (address is! Map<String, dynamic>) {
    return _firstParts(body['display_name'], count: 2);
  }

  String? field(String key) => text(address[key]);

  final road = field('road');
  final number = field('house_number');
  final street = switch ((road, number)) {
    (final String r, final String n) => '$r $n',
    (final String r, null) => r,
    _ => null,
  };

  // Colonia si la hay; si no, la localidad. En el área metropolitana esa segunda pieza es la
  // que distingue una calle de Morelia de una de Charo o Tarímbaro.
  final area =
      field('neighbourhood') ??
      field('quarter') ??
      field('suburb') ??
      field('village') ??
      field('town') ??
      field('city');

  final primary = street ?? text(body['name']) ?? area;
  if (primary == null) return _firstParts(body['display_name'], count: 2);

  return area == null || area == primary ? primary : '$primary, $area';
}

/// Los primeros [count] tramos de un `display_name` separado por comas.
String? _firstParts(Object? displayName, {required int count}) {
  if (displayName is! String) return null;
  final parts = displayName
      .split(',')
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .take(count);
  return parts.isEmpty ? null : parts.join(', ');
}
