/// El viaje en teleférico.
///
/// Tres tramos encadenados —caminar a la estación, volar, caminar al destino— recorridos como
/// una sola línea. Cada tramo avanza a su propia velocidad, que es lo que hace que el tiempo
/// estimado signifique algo: 500 m a pie y 500 m en cabina no tardan lo mismo.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import 'cable_car_network.dart';
import 'path_geometry.dart';
import 'trip_plan.dart' show userLocationProvider;

/// Se da por llegado a esta distancia del destino.
const double cableCarArrivalMeters = 15;

/// Cuánto se acelera el recorrido respecto al tiempo real.
///
/// Uno solo para los dos modos: si la caminata y la cabina se aceleraran distinto, la demo
/// mentiría sobre cuál es más rápido. **Solo afecta la simulación**; el tiempo estimado en
/// pantalla se calcula con las velocidades reales.
const int cableCarDemoSpeedFactor = 10;

/// Cada cuánto avanza el viaje simulado.
const Duration cableCarTick = Duration(milliseconds: 500);

enum CableStage {
  /// Sin viaje.
  idle,

  /// En camino.
  traveling,

  /// Llegó al destino.
  arrived,

  /// Hay destino, pero ninguna línea llega lo bastante cerca.
  unreachable,
}

class CableCarTrip {
  const CableCarTrip({
    this.stage = CableStage.idle,
    this.destination,
    this.plan,
    this.traveledMeters = 0,
  });

  final CableStage stage;
  final LatLng? destination;

  /// El viaje resuelto. `null` cuando no hay estación que sirva.
  final CableCarPlan? plan;

  final double traveledMeters;

  bool get isActive => stage != CableStage.idle;

  /// Dónde va el pasajero, siguiendo la línea trazada.
  LatLng? get position {
    final plan = this.plan;
    if (plan == null) return null;
    return pointAlongPath(plan.points, traveledMeters);
  }

  /// Si va a pie o en cabina en este momento.
  CableLegMode? get currentMode => plan?.legAt(traveledMeters).mode;

  double get remainingMeters {
    final plan = this.plan;
    if (plan == null) return 0;
    return math.max(0, plan.totalMeters - traveledMeters);
  }

  /// Lo que falta, contando cada tramo a su velocidad.
  int get remainingMinutes => plan?.remainingMinutesFrom(traveledMeters) ?? 0;

  CableCarTrip copyWith({
    CableStage? stage,
    LatLng? destination,
    CableCarPlan? plan,
    double? traveledMeters,
  }) => CableCarTrip(
    stage: stage ?? this.stage,
    destination: destination ?? this.destination,
    plan: plan ?? this.plan,
    traveledMeters: traveledMeters ?? this.traveledMeters,
  );
}

class CableCarTripController extends Notifier<CableCarTrip> {
  Timer? _timer;

  @override
  CableCarTrip build() {
    ref.onDispose(() => _timer?.cancel());
    return const CableCarTrip();
  }

  /// Resuelve el viaje desde donde está el usuario y arranca.
  void start(LatLng destination) {
    final origin = ref.read(userLocationProvider);
    final plan = planCableCarTrip(origin: origin, destination: destination);

    _timer?.cancel();
    _timer = null;

    if (plan == null) {
      state = CableCarTrip(
        stage: CableStage.unreachable,
        destination: destination,
      );
      return;
    }

    state = CableCarTrip(
      stage: CableStage.traveling,
      destination: destination,
      plan: plan,
    );
    _timer = Timer.periodic(cableCarTick, (_) => _advance());
  }

  void reset() {
    _timer?.cancel();
    _timer = null;
    state = const CableCarTrip();
  }

  void _advance() {
    final plan = state.plan;
    if (plan == null || state.stage != CableStage.traveling) return;

    final leg = plan.legAt(state.traveledMeters);
    final metersPerTick =
        leg.metersPerMinute /
        60 *
        cableCarDemoSpeedFactor *
        (cableCarTick.inMilliseconds / 1000);

    final traveled = state.traveledMeters + metersPerTick;

    if (plan.totalMeters - traveled <= cableCarArrivalMeters) {
      _timer?.cancel();
      _timer = null;
      state = state.copyWith(
        stage: CableStage.arrived,
        traveledMeters: plan.totalMeters,
      );
      return;
    }

    state = state.copyWith(traveledMeters: traveled);
  }
}

final cableCarTripProvider =
    NotifierProvider<CableCarTripController, CableCarTrip>(
      CableCarTripController.new,
    );
