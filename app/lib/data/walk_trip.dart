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

import 'providers.dart';
import 'trip_plan.dart' show userLocationProvider;
import 'walk_route.dart';

/// Se da por llegado a esta distancia del destino.
const double walkArrivalMeters = 15;

/// Cuánto se acelera el recorrido respecto al tiempo real.
///
/// Caminar un kilómetro son doce minutos, que no es una demo; con este factor son treinta
/// segundos. **Solo afecta la simulación**: el tiempo estimado en pantalla se calcula con la
/// velocidad real de una persona caminando. En 1 el recorrido pasa a tiempo real.
const int walkDemoSpeedFactor = 24;

/// Cada cuánto avanza el peatón simulado.
///
/// Va de la mano con el factor de arriba: al doblar la velocidad se parte el tick a la mitad,
/// así cada paso mide lo mismo en el mapa y solo ocurren más seguido. Subir la velocidad sin
/// tocar esto haría que el marcador saltara al doble y se viera a tirones.
const Duration walkTick = Duration(milliseconds: 250);

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
  ///
  /// Sale andando de inmediato con el trazado propio —el que esquiva las zonas marcadas— y
  /// pide en paralelo el ajuste a calles. Esperar a la red antes de mover al peatón dejaría la
  /// pantalla congelada por una línea más bonita; si no llega, se camina con lo que ya había.
  Future<void> start(LatLng destination) async {
    final origin = ref.read(userLocationProvider);
    final route = planWalkRoute(origin: origin, destination: destination);

    state = WalkTrip(
      stage: WalkStage.walking,
      destination: destination,
      route: route,
    );

    _timer?.cancel();
    _timer = Timer.periodic(walkTick, (_) => _advance());

    await _snapToRoads(route);
  }

  /// Reemplaza el trazado recto por el que va por calles.
  ///
  /// Los vértices del rodeo viajan como puntos intermedios: sin ellos, ajustar a calles
  /// deshace el desvío que costó calcular y el camino vuelve a cruzar la zona.
  Future<void> _snapToRoads(WalkRoute route) async {
    if (route.points.length < 2) return;

    try {
      final road = await ref
          .read(apiClientProvider)
          .fetchWalkPath(
            from: route.points.first,
            to: route.points.last,
            via: route.points.sublist(1, route.points.length - 1),
          );

      final ajustada = route.onRoads(road, moreliaUnsafeZones);
      // Pudo terminarse o cancelarse mientras la petición volaba.
      if (identical(state.route, route) && !identical(ajustada, route)) {
        state = state.copyWith(route: ajustada);
      }
    } catch (_) {
      // Sin ajuste se camina el trazado propio. No es motivo para romper el viaje.
    }
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
