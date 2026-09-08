/// Dobles de prueba para la capa de datos.
///
/// El `MockClient` usa el `ApiClient` real, así que las pruebas también ejercitan el parseo
/// del JSON tal como lo manda `server/` — los payloads de abajo están copiados de respuestas
/// reales del servidor corriendo, no inventados.
library;

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:maas_morelia/data/api_client.dart';
import 'package:maas_morelia/data/models.dart';
import 'package:maas_morelia/data/realtime_client.dart';

/// Respuesta real de `GET /routes` con los datos semilla.
const String routesPayload = '''
[
  {"id":1,"name":"Ruta Centro - Acueducto","mode":"combi","color_hex":"#0E5E56",
   "stops":[
     {"id":1,"name":"Catedral de Morelia","lat":19.7008,"lng":-101.1844,"sequence":1},
     {"id":2,"name":"Fuente de las Tarascas","lat":19.6989,"lng":-101.1789,"sequence":2},
     {"id":3,"name":"Acueducto de Morelia","lat":19.6975,"lng":-101.1791,"sequence":3}]},
  {"id":2,"name":"Ruta Centro - Bosque","mode":"bus","color_hex":"#D19B3D",
   "stops":[
     {"id":4,"name":"Catedral de Morelia","lat":19.7008,"lng":-101.1844,"sequence":1},
     {"id":5,"name":"Bosque Cuauhtémoc","lat":19.6917,"lng":-101.177,"sequence":2}]}
]''';

/// Registra las peticiones que recibe, para poder afirmar sobre ellas.
class RecordedRequest {
  const RecordedRequest({required this.method, required this.path, this.body});

  final String method;
  final String path;
  final Map<String, dynamic>? body;
}

/// Construye un [ApiClient] que responde en memoria.
class FakeApi {
  FakeApi({
    this.routesJson = routesPayload,
    this.demandJson = '[]',
    this.etaJson,
    this.etaStatusCode = 200,
    this.boardingStatusCode = 201,
    this.ratingStatusCode = 201,
  });

  final String routesJson;
  final String demandJson;

  /// `null` simula que la unidad todavía no reporta posición.
  final String? etaJson;

  final int etaStatusCode;
  final int boardingStatusCode;
  final int ratingStatusCode;

  final List<RecordedRequest> requests = [];

  ApiClient build() {
    return ApiClient(
      baseUrl: 'http://test.local',
      httpClient: MockClient((request) async {
        final path = request.url.path;
        requests.add(
          RecordedRequest(
            method: request.method,
            path: path,
            body:
                request.body.isEmpty
                    ? null
                    : jsonDecode(request.body) as Map<String, dynamic>,
          ),
        );

        if (path == '/routes') return http.Response(routesJson, 200);
        if (path == '/demand/stops') return http.Response(demandJson, 200);
        if (path == '/users') {
          return http.Response(
            '{"id":7,"name":"Pasajero Demo","role":"passenger"}',
            201,
          );
        }
        if (path.endsWith('/eta')) {
          if (etaStatusCode != 200) {
            return http.Response('{"error":"sin unidad"}', etaStatusCode);
          }
          return http.Response(
            etaJson ??
                '{"stop_id":1,"route_id":1,"vehicle_id":1,'
                    '"distance_km":null,"eta_minutes":null}',
            200,
          );
        }
        if (path == '/card-taps') {
          // El endpoint real crea su propia señal de abordaje; el doble devuelve un id
          // distinto al declarado en la parada, que es justo lo que hay que manejar.
          return http.Response(
            '{"id":9,"card_uid":"DEMO-0001","vehicle_id":1,'
            '"boarding_signal_id":202}',
            201,
          );
        }
        if (path.endsWith('/rating')) {
          if (ratingStatusCode != 201) {
            return http.Response('{"error":"no hay viaje"}', ratingStatusCode);
          }
          return http.Response('{"id":3,"boarding_signal_id":101}', 201);
        }
        if (request.method == 'PATCH' &&
            path.startsWith('/boarding-signals/')) {
          return http.Response('{"id":101,"status":"ok"}', 200);
        }
        if (path == '/boarding-signals') {
          if (boardingStatusCode != 201) {
            return http.Response('{"error":"datos inválidos"}', boardingStatusCode);
          }
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({
              'id': 42,
              'user_id': body['user_id'],
              'stop_id': body['stop_id'],
              'route_id': body['route_id'],
              'intent': body['intent'],
              'status':
                  body['intent'] == 'boarding' ? 'waiting' : 'expired',
            }),
            201,
          );
        }

        return http.Response('{"error":"ruta no simulada: $path"}', 404);
      }),
    );
  }
}

/// Canal en vivo controlable desde la prueba.
///
/// No abre socket: expone los mismos flujos que [RealtimeClient] y deja empujar eventos a
/// mano, para poder verificar qué hace la interfaz cuando llega una posición o un cambio de
/// demanda.
class FakeRealtimeClient extends RealtimeClient {
  FakeRealtimeClient() : super(baseUrl: 'http://test.local');

  final _vehicles = StreamController<VehiclePosition>.broadcast();
  final _demand = StreamController<DemandCount>.broadcast();
  final _connected = StreamController<bool>.broadcast();

  @override
  Stream<VehiclePosition> get vehiclePositions => _vehicles.stream;

  @override
  Stream<DemandCount> get demandUpdates => _demand.stream;

  @override
  Stream<bool> get connectionState => _connected.stream;

  @override
  void connect() {
    // Sin socket real.
  }

  void emitVehicle(VehiclePosition position) => _vehicles.add(position);

  void emitDemand(DemandCount count) => _demand.add(count);

  void emitConnection({required bool connected}) => _connected.add(connected);

  @override
  Future<void> dispose() async {
    await _vehicles.close();
    await _demand.close();
    await _connected.close();
  }
}
