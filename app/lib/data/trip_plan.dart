/// El viaje, de punta a punta.
///
/// El orden del flujo es deliberado: **destino → parada de abordaje → caminata → abordaje**.
/// Cada paso agrega un dato que el siguiente necesita, y ninguno se puede saltar. Confirmar un
/// abordaje sin destino produciría una señal que solo dice "alguien espera aquí"; elegir parada
/// sin saber a dónde va sería adivinar.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import 'models.dart';
import 'providers.dart';

const Distance _distance = Distance();

/// Qué tan lejos puede dejar una parada de bajada respecto al destino para seguir siendo una
/// opción ofrecible.
///
/// El usuario pidió incluir tanto las que dejan encima como las que dejan "relativamente
/// cerca". Más allá de este radio, caminar deja de ser razonable y ofrecerlo sería ruido.
const double maxAlightingToDestinationMeters = 1500;

/// A partir de aquí una opción deja de considerarse "te deja cerca".
const double goodAlightingMeters = 500;

/// Cuánto se acepta caminar hasta la parada de abordaje.
const double maxWalkToBoardingMeters = 2500;

/// Radio dentro del cual se considera que el usuario ya llegó a la parada.
const double arrivalRadiusMeters = 45;

/// Dos paradas del catálogo a menos de esto son el mismo lugar físico.
const double samePlaceMeters = 40;

/// Umbral de gente esperando a partir del cual la parada se pinta como concurrida.
const int busyStopThreshold = 6;

/// Una forma de llegar al destino: dónde subirse, por qué ruta y dónde bajarse.
class BoardingOption {
  const BoardingOption({
    required this.boardingStop,
    required this.route,
    required this.alightingStop,
    required this.metersToBoardingStop,
    required this.metersFromAlightingToDestination,
    required this.waitingCount,
  });

  final Stop boardingStop;
  final TransitRoute route;
  final Stop alightingStop;

  /// Lo que el usuario camina para llegar a subirse.
  final double metersToBoardingStop;

  /// Lo que camina al bajarse. Es el número que decide si la opción sirve.
  final double metersFromAlightingToDestination;

  /// Gente que declaró que espera en la parada de abordaje.
  final int waitingCount;

  bool get isBusy => waitingCount >= busyStopThreshold;

  /// Deja al usuario prácticamente en su destino.
  bool get dropsClose => metersFromAlightingToDestination <= goodAlightingMeters;

  /// Criterio de orden.
  ///
  /// Manda qué tan cerca del destino te deja; a igualdad, se prefiere caminar menos para
  /// subirse. Caminar de más al principio se tolera mucho mejor que quedar lejos al final,
  /// cuando ya se pagó el pasaje.
  double get score =>
      metersFromAlightingToDestination + metersToBoardingStop * 0.35;
}

enum TripStage {
  /// Sin destino.
  idle,

  /// Ya se sabe a dónde va; falta elegir por dónde.
  destinationSet,

  /// Eligió opción; falta confirmarla.
  stopChosen,

  /// Caminando hacia la parada.
  walking,

  /// Ya confirmó que aborda.
  boarded,
}

class TripPlan {
  const TripPlan({
    this.stage = TripStage.idle,
    this.destination,
    this.options = const [],
    this.chosen,
    this.boardingSignalId,
  });

  final TripStage stage;

  /// Punto que el usuario eligió en el mapa.
  final LatLng? destination;

  /// Opciones ofrecidas, de la mejor a la peor.
  final List<BoardingOption> options;

  /// La que eligió.
  final BoardingOption? chosen;

  /// Id que devolvió `POST /boarding-signals`, para poder cerrarlo después.
  final int? boardingSignalId;

  bool get hasDestination => destination != null;

  /// Hay destino pero ninguna ruta del catálogo lo acerca lo suficiente.
  bool get isUnreachable => hasDestination && options.isEmpty;

  TripPlan copyWith({
    TripStage? stage,
    LatLng? destination,
    List<BoardingOption>? options,
    BoardingOption? chosen,
    int? boardingSignalId,
  }) => TripPlan(
    stage: stage ?? this.stage,
    destination: destination ?? this.destination,
    options: options ?? this.options,
    chosen: chosen ?? this.chosen,
    boardingSignalId: boardingSignalId ?? this.boardingSignalId,
  );
}

class TripPlanController extends Notifier<TripPlan> {
  @override
  TripPlan build() => const TripPlan();

  /// Paso 1: el usuario dice a dónde va, y se calculan las formas de llegar.
  void setDestination(LatLng destination) {
    final routes = ref.read(routesProvider).value ?? const <TransitRoute>[];
    final demand = ref.read(demandProvider).value ?? const <int, int>{};
    final origin = ref.read(userLocationProvider);

    final options = buildOptions(
      routes: routes,
      origin: origin,
      destination: destination,
      demand: demand,
    );

    state = TripPlan(
      stage: TripStage.destinationSet,
      destination: destination,
      options: options,
    );
  }

  /// Paso 2: elige una de las opciones ofrecidas.
  void choose(BoardingOption option) {
    state = state.copyWith(stage: TripStage.stopChosen, chosen: option);
  }

  /// Paso 3: confirma la opción y empieza a caminar.
  void startWalking() {
    if (state.chosen == null) return;
    state = state.copyWith(stage: TripStage.walking);
    ref.read(userLocationProvider.notifier).walkTo(state.chosen!.boardingStop.location);
  }

  /// Paso 4: confirmó que aborda.
  void markBoarded(int signalId) {
    state = state.copyWith(
      stage: TripStage.boarded,
      boardingSignalId: signalId,
    );
    ref.read(userLocationProvider.notifier).stop();
  }

  void reset() {
    ref.read(userLocationProvider.notifier).reset();
    state = const TripPlan();
  }
}

final tripPlanProvider = NotifierProvider<TripPlanController, TripPlan>(
  TripPlanController.new,
);

/// Arma las formas de llegar al destino.
///
/// Para cada ruta y cada parada de abordaje alcanzable a pie, elige **la mejor parada de
/// bajada de esa ruta** — la que deja más cerca del destino — y descarta la combinación si ni
/// así queda a una distancia caminable. Se expone aparte de la clase para poder probarla sin
/// levantar providers.
List<BoardingOption> buildOptions({
  required List<TransitRoute> routes,
  required LatLng origin,
  required LatLng destination,
  required Map<int, int> demand,
}) {
  final options = <BoardingOption>[];

  for (final route in routes) {
    // La mejor bajada de esta ruta para este destino.
    Stop? bestAlighting;
    var bestAlightingMeters = double.infinity;
    for (final stop in route.stops) {
      final meters = _distance(stop.location, destination);
      if (meters < bestAlightingMeters) {
        bestAlightingMeters = meters;
        bestAlighting = stop;
      }
    }

    if (bestAlighting == null ||
        bestAlightingMeters > maxAlightingToDestinationMeters) {
      continue;
    }

    for (final boarding in route.stops) {
      if (boarding.id == bestAlighting.id) continue;

      final walk = _distance(origin, boarding.location);
      if (walk > maxWalkToBoardingMeters) continue;

      options.add(
        BoardingOption(
          boardingStop: boarding,
          route: route,
          alightingStop: bestAlighting,
          metersToBoardingStop: walk,
          metersFromAlightingToDestination: bestAlightingMeters,
          waitingCount: demand[boarding.id] ?? 0,
        ),
      );
    }
  }

  options.sort((a, b) => a.score.compareTo(b.score));

  // El catálogo repite la misma parada física en cada ruta que pasa por ahí. Ofrecer dos
  // renglones idénticos confundiría, así que se queda la mejor de cada lugar.
  final deduped = <BoardingOption>[];
  for (final option in options) {
    final alreadyThere = deduped.any(
      (kept) =>
          _distance(
            kept.boardingStop.location,
            option.boardingStop.location,
          ) <=
          samePlaceMeters,
    );
    if (!alreadyThere) deduped.add(option);
  }

  return deduped;
}

/// Dónde está el usuario.
///
/// TODO(ubicación): hoy arranca en el centro de Morelia y se mueve por simulación. Cuando se
/// conecte el GPS real, esta clase pasa a escuchar al dispositivo — y hay que pedir permiso
/// antes, no después.
class UserLocationController extends Notifier<LatLng> {
  @override
  LatLng build() => const LatLng(19.7008, -101.1844);

  /// Camina hacia [target] a paso humano.
  ///
  /// El conductor de la demo también es simulado (`server/npm run simulate`), así que simular
  /// al peatón mantiene la demostración coherente: se ve llegar a la parada y dispara la
  /// confirmación de abordaje sola.
  void walkTo(LatLng target, {Duration step = const Duration(seconds: 1)}) {
    _timer?.cancel();
    _target = target;
    _timer = Timer.periodic(step, (_) => _advance());
    ref.onDispose(() => _timer?.cancel());
  }

  void stop() => _timer?.cancel();

  void reset() {
    _timer?.cancel();
    _target = null;
    state = const LatLng(19.7008, -101.1844);
  }

  Timer? _timer;
  LatLng? _target;

  void _advance() {
    final target = _target;
    if (target == null) return;

    final remaining = _distance(state, target);
    if (remaining <= arrivalRadiusMeters * 0.5) {
      state = target;
      _timer?.cancel();
      return;
    }

    // ~1.4 m/s, que es caminar normal.
    const stepMeters = 25.0;
    final fraction = (stepMeters / remaining).clamp(0.0, 1.0);
    state = LatLng(
      state.latitude + (target.latitude - state.latitude) * fraction,
      state.longitude + (target.longitude - state.longitude) * fraction,
    );
  }
}

final userLocationProvider = NotifierProvider<UserLocationController, LatLng>(
  UserLocationController.new,
);

/// Si el usuario ya está lo bastante cerca de la parada elegida para abordar.
final hasArrivedProvider = Provider<bool>((ref) {
  final plan = ref.watch(tripPlanProvider);
  final position = ref.watch(userLocationProvider);
  final target = plan.chosen?.boardingStop.location;

  if (target == null || plan.stage != TripStage.walking) return false;
  return _distance(position, target) <= arrivalRadiusMeters;
});
