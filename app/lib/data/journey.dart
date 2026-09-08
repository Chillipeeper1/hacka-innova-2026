/// Viajes multimodales que arma el servidor (`GET /journeys`).
///
/// A diferencia de la bici, la caminata y el teleférico —que el cliente traza por su cuenta
/// porque dependen de datos que solo viven aquí (ciclovías, zonas no recomendadas)— esto lo
/// resuelve el backend: combina caminata, bici, combi, bus y teleférico con transbordos reales
/// sobre el grafo de paradas. El cliente no recalcula nada, solo lo enseña y lo recorre.
library;

import 'package:latlong2/latlong.dart';

/// Cómo se recorre un tramo.
enum JourneyMode {
  walk('walk', 'A pie'),
  bike('bike', 'En bici'),
  bus('bus', 'En camión'),
  combi('combi', 'En combi'),
  cableCar('teleferico', 'En teleférico');

  const JourneyMode(this.wireValue, this.label);

  /// Cómo lo nombra el servidor.
  final String wireValue;

  /// Cómo se le dice al pasajero.
  final String label;

  /// Modos que se pueden pedir en el filtro `modes`. La caminata no está: no es una elección,
  /// es lo que une los demás tramos.
  static const List<JourneyMode> selectable = [bike, combi, bus, cableCar];

  static JourneyMode fromWire(String value) => values.firstWhere(
    (mode) => mode.wireValue == value,
    // Un modo que esta versión de la app no conoce se enseña como caminata en vez de tirar la
    // pantalla: el viaje sigue siendo utilizable aunque el nombre del tramo quede pobre.
    orElse: () => JourneyMode.walk,
  );
}

/// Un extremo de tramo: puede ser una parada con nombre o un punto suelto.
class JourneyPlace {
  const JourneyPlace({required this.location, this.stopId, this.name});

  final LatLng location;

  /// `null` cuando el punto no es una parada — el origen del usuario, su destino final.
  final int? stopId;
  final String? name;

  factory JourneyPlace.fromJson(Map<String, dynamic> json) => JourneyPlace(
    location: LatLng(
      (json['lat'] as num).toDouble(),
      (json['lng'] as num).toDouble(),
    ),
    stopId: (json['stop_id'] as num?)?.toInt(),
    name: json['name'] as String?,
  );
}

class JourneyLeg {
  const JourneyLeg({
    required this.mode,
    required this.from,
    required this.to,
    required this.meters,
    required this.minutes,
    this.routeId,
    this.routeName,
  });

  final JourneyMode mode;
  final JourneyPlace from;
  final JourneyPlace to;
  final double meters;
  final double minutes;

  final int? routeId;
  final String? routeName;

  /// Ritmo real de este tramo, según el propio servidor.
  ///
  /// Se deriva de sus números en vez de suponer una velocidad por modo: si el backend ajusta
  /// las suyas, el recorrido simulado se ajusta con él y la app no empieza a contradecirlo.
  double get metersPerMinute => minutes <= 0 ? meters : meters / minutes;

  /// Qué enseñar como título del tramo.
  String get title => routeName ?? mode.label;

  factory JourneyLeg.fromJson(Map<String, dynamic> json) => JourneyLeg(
    mode: JourneyMode.fromWire(json['mode'] as String),
    from: JourneyPlace.fromJson(json['from'] as Map<String, dynamic>),
    to: JourneyPlace.fromJson(json['to'] as Map<String, dynamic>),
    meters: ((json['distance_km'] as num).toDouble()) * 1000,
    minutes: (json['eta_minutes'] as num).toDouble(),
    routeId: (json['route_id'] as num?)?.toInt(),
    routeName: json['route_name'] as String?,
  );
}

/// Una forma completa de llegar, con su etiqueta.
class Journey {
  const Journey({
    required this.label,
    required this.legs,
    required this.totalMeters,
    required this.totalMinutes,
  });

  /// Cómo la llama el servidor: "Más rápida", "Sin bicicleta", "Con menos transbordos".
  final String label;

  final List<JourneyLeg> legs;
  final double totalMeters;
  final double totalMinutes;

  int get roundedMinutes => totalMinutes < 1 ? 1 : totalMinutes.round();

  /// Tramos que no son caminata: los que de verdad hay que tomar.
  int get rideCount => legs.where((leg) => leg.mode != JourneyMode.walk).length;

  /// Modos distintos que usa, en orden y sin repetir. Es el resumen de un vistazo.
  List<JourneyMode> get modes {
    final seen = <JourneyMode>[];
    for (final leg in legs) {
      if (!seen.contains(leg.mode)) seen.add(leg.mode);
    }
    return seen;
  }

  /// Todos los puntos del viaje, de principio a fin.
  List<LatLng> get points {
    final all = <LatLng>[];
    for (final leg in legs) {
      for (final point in [leg.from.location, leg.to.location]) {
        if (all.isEmpty || all.last != point) all.add(point);
      }
    }
    return all;
  }

  factory Journey.fromJson(Map<String, dynamic> json) => Journey(
    label: json['label'] as String,
    legs: (json['legs'] as List<dynamic>)
        .map((leg) => JourneyLeg.fromJson(leg as Map<String, dynamic>))
        .toList(),
    totalMeters: ((json['total_distance_km'] as num).toDouble()) * 1000,
    totalMinutes: (json['total_eta_minutes'] as num).toDouble(),
  );
}
