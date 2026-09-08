/// El viaje a pie.
///
/// Mismo trato que la bici: se dice a dónde se va y se arranca. Vive aparte de `trip_plan.dart`
/// —la máquina de estados del camión— porque aquí no hay parada que elegir ni pasaje que pagar,
/// y aparte de `bike_trip.dart` porque lo que el trazado esquiva no es lo mismo que lo que
/// busca.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import 'trip_plan.dart' show userLocationProvider;
import 'walk_route.dart';

/// Se da por llegado a esta distancia del destino.
const double walkArrivalMeters = 15;

/// Cuánto se acelera el recorrido respecto al tiempo real.
///
/// Caminar un kilómetro son doce minutos, que no es una demo. **Solo afecta la simulación**: el
/// tiempo estimado en pantalla se calcula con la velocidad real de una persona caminando. En 1
/// el recorrido pasa a tiempo real.
const int walkDemoSpeedFactor = 12;

/// Cada cuánto avanza el peatón simulado.
const Duration walkTick = Duration(milliseconds: 500);

enum WalkStage {
  /// Sin viaje.
  idle,

  /// Caminando.
  walking,

  /// Llegó al destino.
  arrived,
}

class WalkTrip {
  const WalkTrip({
    this.stage = WalkStage.idle,
    this.destination,
    this.route,
    this.traveledMeters = 0,
  });

  final WalkStage stage;
  final LatLng? destination;
  final WalkRoute? route;

  /// Metros recorridos sobre el trazado.
  final double traveledMeters;

  bool get isActive => stage != WalkStage.idle;

  /// Dónde va quien camina, siguiendo la línea trazada.
  LatLng? get position => route?.pointAt(traveledMeters);

  double get remainingMeters {
    final route = this.route;
    if (route == null) return 0;
    return math.max(0, route.totalMeters - traveledMeters);
  }

  /// Lo que falta, en minutos de caminata.
  int get remainingMinutes => minutesOnFoot(remainingMeters);

  WalkTrip copyWith({
    WalkStage? stage,
    LatLng? destination,
    WalkRoute? route,
    double? traveledMeters,
  }) => WalkTrip(
    stage: stage ?? this.stage,
    destination: destination ?? this.destination,
    route: route ?? this.route,
    traveledMeters: traveledMeters ?? this.traveledMeters,
  );
}

class WalkTripController extends Notifier<WalkTrip> {
  Timer? _timer;

  @override
  WalkTrip build() {
    ref.onDispose(() => _timer?.cancel());
    return const WalkTrip();
  }

  /// Traza el camino desde donde está el usuario y arranca.
  void start(LatLng destination) {
    final origin = ref.read(userLocationProvider);
    final route = planWalkRoute(origin: origin, destination: destination);

    state = WalkTrip(
      stage: WalkStage.walking,
      destination: destination,
      route: route,
    );

    _timer?.cancel();
    _timer = Timer.periodic(walkTick, (_) => _advance());
  }

  void reset() {
    _timer?.cancel();
    _timer = null;
    state = const WalkTrip();
  }

  void _advance() {
    final route = state.route;
    if (route == null || state.stage != WalkStage.walking) return;

    final metersPerTick =
        walkingSpeedKmh *
        1000 /
        3600 *
        walkDemoSpeedFactor *
        (walkTick.inMilliseconds / 1000);

    final traveled = state.traveledMeters + metersPerTick;

    if (route.totalMeters - traveled <= walkArrivalMeters) {
      _timer?.cancel();
      _timer = null;
      state = state.copyWith(
        stage: WalkStage.arrived,
        traveledMeters: route.totalMeters,
      );
      return;
    }

    state = state.copyWith(traveledMeters: traveled);
  }
}

final walkTripProvider = NotifierProvider<WalkTripController, WalkTrip>(
  WalkTripController.new,
);
