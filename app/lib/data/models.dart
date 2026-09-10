/// Modelos del contrato de `server/`.
///
/// El backend habla en `snake_case` con ids enteros; aquí se traduce a `camelCase` en el
/// borde y hacia adentro solo circulan estos tipos. El contrato está en `server/README.md` y
/// en la sección "Contrato de API y eventos" de `CLAUDE.md`.
library;

import 'package:latlong2/latlong.dart';

import 'path_geometry.dart';

/// Ruta de transporte con sus paradas.
class TransitRoute {
  const TransitRoute({
    required this.id,
    required this.name,
    required this.mode,
    required this.colorHex,
    required this.stops,
    this.roadShape = const [],
  });

  final int id;
  final String name;

  /// `combi` | `bus` en los datos semilla.
  final String mode;

  final String colorHex;
  final List<Stop> stops;

  /// Por dónde va la ruta calle por calle, si el servidor lo trae (`shape`).
  ///
  /// Puede venir vacío: sin OSRM, o el teleférico, que va por el aire y ahí unir estaciones
  /// con una recta es el trazado correcto.
  final List<LatLng> roadShape;

  /// Trazado de la ruta para dibujarla.
  ///
  /// El trazado por calles cuando lo hay; si no, las paradas en orden de secuencia, que es lo
  /// que se dibujaba antes de que el backend supiera pedirle la geometría a OSRM: recto entre
  /// parada y parada, cruzando manzanas por donde el camión no pasa.
  List<LatLng> get shape => roadShape.isNotEmpty
      ? roadShape
      : stops.map((stop) => stop.location).toList();

  factory TransitRoute.fromJson(Map<String, dynamic> json) => TransitRoute(
    id: json['id'] as int,
    name: json['name'] as String,
    mode: json['mode'] as String,
    colorHex: json['color_hex'] as String? ?? '#0E5E56',
    stops: (json['stops'] as List<dynamic>? ?? const [])
        .map((e) => Stop.fromJson(e as Map<String, dynamic>))
        .toList(),
    roadShape: latLngListFromJson(json['shape']),
  );
}

class Stop {
  const Stop({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    required this.sequence,
  });

  final int id;
  final String name;
  final double lat;
  final double lng;
  final int sequence;

  LatLng get location => LatLng(lat, lng);

  factory Stop.fromJson(Map<String, dynamic> json) => Stop(
    id: json['id'] as int,
    name: json['name'] as String,
    lat: (json['lat'] as num).toDouble(),
    lng: (json['lng'] as num).toDouble(),
    sequence: json['sequence'] as int? ?? 0,
  );
}

/// Posición de una unidad, recibida por el evento `vehicle:position`.
class VehiclePosition {
  const VehiclePosition({
    required this.vehicleId,
    required this.lat,
    required this.lng,
    this.recordedAt,
  });

  final int vehicleId;
  final double lat;
  final double lng;
  final DateTime? recordedAt;

  LatLng get location => LatLng(lat, lng);

  /// A qué ruta pertenece la unidad.
  ///
  /// El contrato no expone un endpoint para resolverlo. El seed inserta un vehículo por ruta
  /// en el mismo orden, así que `vehicle_id == route_id` — está documentado como brecha
  /// conocida en `server/README.md`. En cuanto haya más de una unidad por ruta esto deja de
  /// valer y hace falta pedirle al backend el dato.
  int get routeId => vehicleId;

  factory VehiclePosition.fromJson(Map<String, dynamic> json) =>
      VehiclePosition(
        vehicleId: (json['vehicle_id'] as num).toInt(),
        lat: (json['lat'] as num).toDouble(),
        lng: (json['lng'] as num).toDouble(),
        recordedAt: DateTime.tryParse(json['recorded_at'] as String? ?? ''),
      );
}

/// Respuesta de `GET /stops/:id/eta`.
///
/// [distanceKm] y [etaMinutes] llegan en `null` mientras la unidad de esa ruta no haya
/// reportado posición — es el estado normal antes de que arranque el conductor, no un error.
class StopEta {
  const StopEta({
    required this.stopId,
    required this.routeId,
    required this.vehicleId,
    this.distanceKm,
    this.etaMinutes,
  });

  final int stopId;
  final int routeId;
  final int vehicleId;
  final double? distanceKm;
  final double? etaMinutes;

  bool get hasEstimate => etaMinutes != null;

  factory StopEta.fromJson(Map<String, dynamic> json) => StopEta(
    stopId: (json['stop_id'] as num).toInt(),
    routeId: (json['route_id'] as num).toInt(),
    vehicleId: (json['vehicle_id'] as num).toInt(),
    distanceKm: (json['distance_km'] as num?)?.toDouble(),
    etaMinutes: (json['eta_minutes'] as num?)?.toDouble(),
  );
}

/// Intención declarada al tocar una parada.
enum BoardingIntent {
  /// "Voy a abordar" — cuenta como demanda en la parada.
  boarding('boarding'),

  /// "Solo paso" — no genera demanda; el servidor la marca `expired` de inmediato.
  passing('passing');

  const BoardingIntent(this.wireValue);

  final String wireValue;
}

/// Señal de abordaje creada por `POST /boarding-signals`.
class BoardingSignal {
  const BoardingSignal({
    required this.id,
    required this.userId,
    required this.routeId,
    required this.intent,
    required this.status,
    this.stopId,
  });

  final int id;
  final int userId;
  final int? stopId;
  final int routeId;
  final String intent;

  /// `waiting` | `boarded` | `alighted` | `expired`.
  final String status;

  bool get isWaiting => status == 'waiting';

  factory BoardingSignal.fromJson(Map<String, dynamic> json) => BoardingSignal(
    id: (json['id'] as num).toInt(),
    userId: (json['user_id'] as num).toInt(),
    stopId: (json['stop_id'] as num?)?.toInt(),
    routeId: (json['route_id'] as num).toInt(),
    intent: json['intent'] as String,
    status: json['status'] as String,
  );
}

/// Conteo agregado de gente esperando en una parada.
class DemandCount {
  const DemandCount({required this.stopId, required this.waitingCount});

  final int stopId;
  final int waitingCount;

  factory DemandCount.fromJson(Map<String, dynamic> json) => DemandCount(
    stopId: (json['stop_id'] as num).toInt(),
    waitingCount: (json['waiting_count'] as num).toInt(),
  );
}
