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
import 'trip_plan.dart' show userLocationProvider;

/// Se da por llegado a esta distancia del destino.
const double bikeArrivalMeters = 20;

/// Cuánto se acelera el recorrido respecto al tiempo real.
///
/// Un viaje de kilómetro y medio a 15 km/h dura seis minutos, que es una eternidad para
/// enseñar una pantalla. Con este factor se recorre en menos de un minuto. **Solo afecta la
/// simulación**: el tiempo estimado que se muestra se calcula con la velocidad real, igual que
/// el simulador del camión corre a 45 km/h mientras la app dice los minutos de un camión de
/// verdad. En 1 el recorrido pasa a tiempo real.
const int bikeDemoSpeedFactor = 8;

/// Cada cuánto avanza el ciclista simulado. Corto para que el marcador se vea fluido.
const Duration bikeTick = Duration(milliseconds: 500);

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
  void start(LatLng destination) {
    final origin = ref.read(userLocationProvider);
    final route = planBikeRoute(origin: origin, destination: destination);

    state = BikeTrip(
      stage: BikeStage.riding,
      destination: destination,
      route: route,
    );

    _timer?.cancel();
    _timer = Timer.periodic(bikeTick, (_) => _advance());
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
