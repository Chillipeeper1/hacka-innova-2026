/// Viajes multimodales que arma el servidor (`GET /journeys`).
///
/// A diferencia de la bici, la caminata y el teleférico —que el cliente traza por su cuenta
/// porque dependen de datos que solo viven aquí (ciclovías, zonas no recomendadas)— esto lo
/// resuelve el backend: combina caminata, bici, combi, bus y teleférico con transbordos reales
/// sobre el grafo de paradas. El cliente no recalcula nada, solo lo enseña y lo recorre.
library;

import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import 'path_geometry.dart';

/// A partir de cuánto un tramo a pie deja de ser un tramo y pasa a ser una caminata que nadie
/// va a hacer.
///
/// El motor del servidor limita la bici a 6 km —"nadie pedalea distancias así para un viaje
/// cotidiano", dice `server/src/lib/speeds.ts`— pero a caminar no le pone tope. El resultado es
/// que todo lo que las rutas del seed no cubren vuelve como un tramo a pie de horas: un destino
/// a 10 km al sur del centro devuelve 5 minutos en bici y 122 caminando, y sin esto se enseñaba
/// como un itinerario cualquiera.
///
/// El número no es nuevo: es el mismo `maxWalkToBoardingMeters` con el que el flujo de camión
/// ya descarta las opciones que obliguen a caminar de más. Que las dos partes de la app midan
/// igual es justamente el punto.
const double maxJourneyWalkMeters = 2500;

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

  /// El nombre del servicio a secas, sin preposición: para etiquetas y chips.
  ///
  /// `label` dice "En combi" porque nombra un tramo del viaje; una etiqueta pegada a una parada
  /// dice "Combi", que es lo que ahí se lee bien.
  String get serviceLabel => switch (this) {
    JourneyMode.walk => 'A pie',
    JourneyMode.bike => 'Bici',
    JourneyMode.bus => 'Camión',
    JourneyMode.combi => 'Combi',
    JourneyMode.cableCar => 'Teleférico',
  };

  static JourneyMode fromWire(String value) => values.firstWhere(
    (mode) => mode.wireValue == value,
    // Un modo que esta versión de la app no conoce se enseña como caminata en vez de tirar la
    // pantalla: el viaje sigue siendo utilizable aunque el nombre del tramo quede pobre.
    orElse: () => JourneyMode.walk,
  );

  /// Como [fromWire], pero sin inventar: `null` si el servidor manda un modo desconocido.
  ///
  /// Lo usa quien prefiere no enseñar nada a enseñar algo falso — una etiqueta que dijera
  /// "A pie" sobre la parada de un camión sería peor que no tener etiqueta.
  static JourneyMode? tryFromWire(String value) {
    for (final mode in values) {
      if (mode.wireValue == value) return mode;
    }
    return null;
  }
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
    this.geometry = const [],
  });

  final JourneyMode mode;
  final JourneyPlace from;
  final JourneyPlace to;
  final double meters;
  final double minutes;

  final int? routeId;
  final String? routeName;

  /// Por dónde pasa el tramo, calle por calle, si el servidor lo trae.
  ///
  /// Puede venir vacío —OSRM no contestó, el tramo mide cero, o es el teleférico, que va por
  /// el aire y ahí la recta es el trazado correcto—. En ese caso se cae a la recta entre
  /// extremos, que es lo que se dibujaba antes.
  ///
  /// **No** mide [meters] ni [minutes]: esos siguen siendo los del motor, que elige con
  /// distancias en línea recta. El trazado real es más largo que la recta que lo generó.
  final List<LatLng> geometry;

  /// Los puntos con los que dibujar y recorrer este tramo. Nunca vacío.
  List<LatLng> get path =>
      geometry.isNotEmpty ? geometry : [from.location, to.location];

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
    geometry: latLngListFromJson(json['geometry']),
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

  /// El tramo a pie más largo del viaje.
  double get longestWalkMeters => legs
      .where((leg) => leg.mode == JourneyMode.walk)
      .fold(0, (worst, leg) => math.max(worst, leg.meters));

  /// El destino queda fuera de lo que la red alcanza.
  ///
  /// Se mira el tramo más largo y no la suma: dos caminatas de conexión de un kilómetro cada
  /// una son un viaje perfectamente normal, y una sola de nueve no lo es. Ver
  /// [maxJourneyWalkMeters].
  bool get beyondNetwork => longestWalkMeters > maxJourneyWalkMeters;

  /// Modos distintos que usa, en orden y sin repetir. Es el resumen de un vistazo.
  List<JourneyMode> get modes {
    final seen = <JourneyMode>[];
    for (final leg in legs) {
      if (!seen.contains(leg.mode)) seen.add(leg.mode);
    }
    return seen;
  }

  /// Todos los puntos del viaje, de principio a fin.
  ///
  /// Sigue el trazado real cuando lo hay: es lo que encuadra el mapa, y una ruta que se
  /// desvía puede salirse del rectángulo que forman los extremos de sus tramos.
  List<LatLng> get points {
    final all = <LatLng>[];
    for (final leg in legs) {
      for (final point in leg.path) {
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
