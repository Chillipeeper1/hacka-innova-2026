import 'dart:convert';

import 'package:http/http.dart' as http;

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

  /// Declara la intención del pasajero — el diferenciador del proyecto.
  Future<BoardingSignal> createBoardingSignal({
    required int userId,
    required int stopId,
    required int routeId,
    required BoardingIntent intent,
  }) async {
    final response = await _http.post(
      _uri('/boarding-signals'),
      headers: _jsonHeaders,
      body: jsonEncode({
        'user_id': userId,
        'stop_id': stopId,
        'route_id': routeId,
        'intent': intent.wireValue,
      }),
    );
    final body = _decodeMap(response, 'POST /boarding-signals');
    return BoardingSignal.fromJson(body);
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
  const ApiException({required this.what, required this.statusCode, this.message});

  final String what;
  final int statusCode;
  final String? message;

  @override
  String toString() =>
      'ApiException($what → $statusCode${message == null ? '' : ': $message'})';
}
