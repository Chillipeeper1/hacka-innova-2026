import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import 'journey.dart';
import 'path_geometry.dart';
import 'models.dart';

/// Cliente REST de `server/`.
///
/// Endpoints en `server/README.md`. Todos los nombres y formas de payload salen de ahí: el
/// `CLAUDE.md` del proyecto pide no inventar rutas ni eventos distintos sin avisar.
class ApiClient {
  ApiClient({required this.baseUrl, http.Client? httpClient})
    : _http = httpClient ?? http.Client();

  /// Dónde vive el backend.
  ///
  /// Se inyecta con `--dart-define=API_BASE_URL=...` porque cambia según dónde corra la app:
  /// `localhost` en web y escritorio, `10.0.2.2` desde el emulador de Android, y la IP de la
  /// máquina en un teléfono físico.
  static const String defaultBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:3001',
  );

  final String baseUrl;
  final http.Client _http;

  void dispose() => _http.close();

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  Future<List<TransitRoute>> fetchRoutes() async {
    final response = await _http.get(_uri('/routes'));
    final body = _decodeList(response, 'GET /routes');
    return body
        .map((e) => TransitRoute.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Crea el usuario de la demo.
  ///
  /// `CLAUDE.md` descarta autenticación robusta en esta fase: basta un nombre. Devuelve el id
  /// que después acompaña a cada señal de abordaje.
  Future<int> createUser({
    required String name,
    String role = 'passenger',
  }) async {
    final response = await _http.post(
      _uri('/users'),
      headers: _jsonHeaders,
      body: jsonEncode({'name': name, 'role': role}),
    );
    final body = _decodeMap(response, 'POST /users');
    return (body['id'] as num).toInt();
  }

  Future<List<DemandCount>> fetchDemand() async {
    final response = await _http.get(_uri('/demand/stops'));
    final body = _decodeList(response, 'GET /demand/stops');
    return body
        .map((e) => DemandCount.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// ETA de la próxima unidad a una parada.
  ///
  /// El servidor responde 404 si la ruta de esa parada todavía no tiene unidad asignada; eso
  /// se traduce a `null` porque para la interfaz es "aún no sabemos", no un fallo.
  Future<StopEta?> fetchStopEta(int stopId) async {
    final response = await _http.get(_uri('/stops/$stopId/eta'));
    if (response.statusCode == 404) return null;
    final body = _decodeMap(response, 'GET /stops/$stopId/eta');
    return StopEta.fromJson(body);
  }

  /// Pide las formas de llegar de un punto a otro, combinando modos y transbordos.
  ///
  /// El ruteo lo hace el servidor: el cliente no recalcula ni reordena. Devuelve las
  /// alternativas en el orden en que llegan, y la primera es la más rápida.
  ///
  /// [modes] restringe los modos permitidos; vacío o nulo significa "todos".
  Future<List<Journey>> fetchJourneys({
    required LatLng origin,
    required LatLng destination,
    List<JourneyMode>? modes,
  }) async {
    final query = <String, String>{
      'origin_lat': '${origin.latitude}',
      'origin_lng': '${origin.longitude}',
      'destination_lat': '${destination.latitude}',
      'destination_lng': '${destination.longitude}',
      if (modes != null && modes.isNotEmpty)
        'modes': modes.map((mode) => mode.wireValue).join(','),
    };

    final response = await _http.get(
      Uri.parse('$baseUrl/journeys').replace(queryParameters: query),
    );
    final body = _decodeMap(response, 'GET /journeys');
    return (body['alternatives'] as List<dynamic>)
        .map((json) => Journey.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// El trazado a pie por calles entre dos puntos.
  ///
  /// [via] son puntos por los que el camino tiene que pasar: los vértices de un rodeo que ya
  /// esquiva una zona marcada, los extremos de una ciclovía. Sin ellos, ajustar a calles
  /// deshace el desvío que costó calcular.
  ///
  /// Vacío cuando el servidor no lo tiene (sin OSRM): quien llama se queda con su trazado.
  Future<List<LatLng>> fetchWalkPath({
    required LatLng from,
    required LatLng to,
    List<LatLng> via = const [],
  }) async {
    final response = await _http.get(
      Uri.parse('$baseUrl/walk-path').replace(
        queryParameters: {
          'from_lat': '${from.latitude}',
          'from_lng': '${from.longitude}',
          'to_lat': '${to.latitude}',
          'to_lng': '${to.longitude}',
          if (via.isNotEmpty)
            'via': via.map((p) => '${p.latitude},${p.longitude}').join(';'),
        },
      ),
    );
    final body = _decodeMap(response, 'GET /walk-path');
    return latLngListFromJson(body['path']);
  }

  /// Declara la intención del pasajero — el diferenciador del proyecto.
  ///
  /// El destino viaja con la señal cuando se conoce: es lo que deja al panel institucional ver
  /// no solo dónde sube la gente, sino hacia dónde va. Se manda la parada de bajada **y** el
  /// punto exacto, porque la parada es una aproximación al lugar al que el pasajero realmente
  /// quiere llegar, y la diferencia entre las dos es justamente lo que hay que medir para
  /// saber si la red le sirve.
  Future<BoardingSignal> createBoardingSignal({
    required int userId,
    required int stopId,
    required int routeId,
    required BoardingIntent intent,
    int? destinationStopId,
    double? destinationLat,
    double? destinationLng,
  }) async {
    final response = await _http.post(
      _uri('/boarding-signals'),
      headers: _jsonHeaders,
      body: jsonEncode({
        'user_id': userId,
        'stop_id': stopId,
        'route_id': routeId,
        'intent': intent.wireValue,
        'destination_stop_id': ?destinationStopId,
        'destination_lat': ?destinationLat,
        'destination_lng': ?destinationLng,
      }),
    );
    final body = _decodeMap(response, 'POST /boarding-signals');
    return BoardingSignal.fromJson(body);
  }

  /// Registra un tap de tarjeta de movilidad (Escenario 6).
  ///
  /// Con [boardingSignalId] el servidor **reutiliza** la señal que el pasajero ya declaró en la
  /// parada y la marca `boarded`. Sin él se comporta como el atajo que describe `CLAUDE.md` —el
  /// tap salta directo a "abordado"— y crea una señal nueva sin parada asociada.
  ///
  /// Devuelve el `boarding_signal_id` del viaje: el mismo que se le pasó, o el que creó.
  Future<int> createCardTap({
    required String cardUid,
    required int vehicleId,
    int? boardingSignalId,
  }) async {
    final response = await _http.post(
      _uri('/card-taps'),
      headers: _jsonHeaders,
      body: jsonEncode({
        'card_uid': cardUid,
        'vehicle_id': vehicleId,
        'boarding_signal_id': ?boardingSignalId,
      }),
    );
    final body = _decodeMap(response, 'POST /card-taps');
    return (body['boarding_signal_id'] as num).toInt();
  }

  /// Califica un viaje (Escenario 7).
  ///
  /// El servidor exige que la señal siga en estado `boarded`, así que hay que calificar
  /// **antes** de marcarla como `alighted`.
  Future<void> rateTrip({
    required int boardingSignalId,
    required int rating,
    String? comment,
  }) async {
    final response = await _http.post(
      _uri('/trips/$boardingSignalId/rating'),
      headers: _jsonHeaders,
      body: jsonEncode({
        'rating': rating,
        if (comment != null && comment.trim().isNotEmpty)
          'comment': comment.trim(),
      }),
    );
    _decodeMap(response, 'POST /trips/$boardingSignalId/rating');
  }

  /// Cambia el estado de una señal: `boarded`, `alighted` o `expired`.
  Future<void> updateBoardingSignal({
    required int signalId,
    required String status,
  }) async {
    final response = await _http.patch(
      _uri('/boarding-signals/$signalId'),
      headers: _jsonHeaders,
      body: jsonEncode({'status': status}),
    );
    _decodeMap(response, 'PATCH /boarding-signals/$signalId');
  }

  static const Map<String, String> _jsonHeaders = {
    'Content-Type': 'application/json',
  };

  List<dynamic> _decodeList(http.Response response, String what) {
    _ensureOk(response, what);
    return jsonDecode(response.body) as List<dynamic>;
  }

  Map<String, dynamic> _decodeMap(http.Response response, String what) {
    _ensureOk(response, what);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  void _ensureOk(http.Response response, String what) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    throw ApiException(
      what: what,
      statusCode: response.statusCode,
      // El servidor responde `{ error: "..." }` en los casos de validación.
      message: _errorMessage(response.body),
    );
  }

  String? _errorMessage(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded['error'] as String?;
    } catch (_) {
      // Cuerpo no-JSON: no hay nada útil que extraer.
    }
    return null;
  }
}

class ApiException implements Exception {
  const ApiException({
    required this.what,
    required this.statusCode,
    this.message,
  });

  final String what;
  final int statusCode;
  final String? message;

  @override
  String toString() =>
      'ApiException($what → $statusCode${message == null ? '' : ': $message'})';
}
