/// El viaje en bici.
///
/// Mucho más corto que el del camión: no hay parada que elegir, ni unidad que esperar, ni
/// pasaje que pagar. Se dice a dónde se va y se arranca. Por eso vive aparte de `trip_plan.dart`
/// en vez de agregarle etapas — meter la bici en la máquina de estados del camión obligaría a
/// preguntar "¿y esto aplica si va en bici?" en cada paso del flujo.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import 'bike_network.dart';
import 'providers.dart';
import 'trip_plan.dart' show userLocationProvider;

/// Se da por llegado a esta distancia del destino.
const double bikeArrivalMeters = 20;

/// Cuánto se acelera el recorrido respecto al tiempo real.
///
/// Un viaje de kilómetro y medio a 15 km/h dura seis minutos, que es una eternidad para
/// enseñar una pantalla. Con este factor se recorre en poco más de veinte segundos. **Solo
/// afecta la simulación**: el tiempo estimado que se muestra se calcula con la velocidad real,
/// igual que el simulador del camión corre a 150 km/h mientras la app dice los minutos de un
/// camión de verdad. En 1 el recorrido pasa a tiempo real.
const int bikeDemoSpeedFactor = 16;

/// Cada cuánto avanza el ciclista simulado. Corto para que el marcador se vea fluido: acompaña
/// al factor de arriba para que cada paso siga midiendo lo mismo en el mapa.
const Duration bikeTick = Duration(milliseconds: 250);

enum BikeStage {
  /// Sin viaje.
  idle,

  /// Pedaleando.
  riding,

  /// Llegó al destino.
  arrived,
}

class BikeTrip {
  const BikeTrip({
    this.stage = BikeStage.idle,
    this.destination,
    this.route,
    this.traveledMeters = 0,
  });

  final BikeStage stage;
  final LatLng? destination;
  final BikeRoute? route;

  /// Metros recorridos sobre el trazado.
  final double traveledMeters;

  bool get isActive => stage != BikeStage.idle;

  /// Dónde va el ciclista, siguiendo la línea trazada.
  LatLng? get position => route?.pointAt(traveledMeters);

  double get remainingMeters {
    final route = this.route;
    if (route == null) return 0;
    return math.max(0, route.totalMeters - traveledMeters);
  }

  /// Lo que falta, en minutos de bici.
  int get remainingMinutes => minutesByBike(remainingMeters);

  BikeTrip copyWith({
    BikeStage? stage,
    LatLng? destination,
    BikeRoute? route,
    double? traveledMeters,
  }) => BikeTrip(
    stage: stage ?? this.stage,
    destination: destination ?? this.destination,
    route: route ?? this.route,
    traveledMeters: traveledMeters ?? this.traveledMeters,
  );
}

class BikeTripController extends Notifier<BikeTrip> {
  Timer? _timer;

  @override
  BikeTrip build() {
    ref.onDispose(() => _timer?.cancel());
    return const BikeTrip();
  }

  /// Traza el recorrido desde donde está el usuario y arranca.
  ///
  /// Sale rodando de inmediato con el trazado propio y pide en paralelo el ajuste a calles.
  /// Esperar a la red antes de mover al ciclista dejaría la pantalla congelada por una línea
  /// más bonita; si no llega, se rueda con lo que ya había.
  Future<void> start(LatLng destination) async {
    final origin = ref.read(userLocationProvider);
    final route = planBikeRoute(origin: origin, destination: destination);

    state = BikeTrip(
      stage: BikeStage.riding,
      destination: destination,
      route: route,
    );

    _timer?.cancel();
    _timer = Timer.periodic(bikeTick, (_) => _advance());

    await _snapToRoads(route);
  }

  /// Ajusta a calles los tramos que van por calle.
  ///
  /// Los de ciclovía se quedan como están: ya llevan el trazado capturado de la
  /// infraestructura real, y cambiarlo por calles de coche sería perder precisión, no ganarla.
  Future<void> _snapToRoads(BikeRoute route) async {
    final api = ref.read(apiClientProvider);

    try {
      final ajustados = await Future.wait([
        for (final segment in route.segments)
          if (segment.onLane || segment.points.length < 2)
            Future.value(segment)
          else
            api
                .fetchWalkPath(
                  from: segment.points.first,
                  to: segment.points.last,
                  via: segment.points.sublist(1, segment.points.length - 1),
                )
                .then(segment.onRoads),
      ]);

      final cambio = ajustados.indexed.any(
        (e) => !identical(e.$2, route.segments[e.$1]),
      );
      // Pudo terminarse o cancelarse mientras las peticiones volaban.
      if (cambio && identical(state.route, route)) {
        state = state.copyWith(route: route.withSegments(ajustados));
      }
    } catch (_) {
      // Sin ajuste se rueda el trazado propio. No es motivo para romper el viaje.
    }
  }

  /// Termina el viaje a medias.
  void cancel() => reset();

  void reset() {
    _timer?.cancel();
    _timer = null;
    state = const BikeTrip();
  }

  void _advance() {
    final route = state.route;
    if (route == null || state.stage != BikeStage.riding) return;

    final metersPerTick =
        bikeSpeedKmh *
        1000 /
        3600 *
        bikeDemoSpeedFactor *
        (bikeTick.inMilliseconds / 1000);

    final traveled = state.traveledMeters + metersPerTick;

    if (route.totalMeters - traveled <= bikeArrivalMeters) {
      _timer?.cancel();
      _timer = null;
      state = state.copyWith(
        stage: BikeStage.arrived,
        traveledMeters: route.totalMeters,
      );
      return;
    }

    state = state.copyWith(traveledMeters: traveled);
  }
}

final bikeTripProvider = NotifierProvider<BikeTripController, BikeTrip>(
  BikeTripController.new,
);
