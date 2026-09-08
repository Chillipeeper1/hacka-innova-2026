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

/// Distancia a la que se considera que la unidad ya está llegando a la parada.
///
/// Es el momento de pedir el pago: antes sería adelantarse, después el pasajero ya va subiendo
/// con el teléfono guardado.
const double busApproachingMeters = 150;

/// Distancia a la que se considera que la unidad ya está **en** la parada.
const double busAtStopMeters = 45;

/// Cuánto tiene que alejarse la unidad para dar por hecho que ya se fue con el pasajero.
///
/// Es la detección de "pagó con monedas". No basta con que la unidad esté lejos: tiene que
/// haber estado antes en la parada y luego alejarse — si no, mientras se acerca ya estaría
/// "yéndose", y el pago con monedas se dispararía en el mismo instante que aparece la pantalla
/// de pago. En producción se compararía la velocidad del dispositivo con la de la unidad, pero
/// `CLAUDE.md` descarta la detección por sensores en esta fase.
const double departedStopMeters = 120;

/// Aviso anticipado antes de la parada de bajada.
const double alightingWarningMeters = 300;

/// Se da por llegado el viaje a esta distancia de la parada de bajada.
const double alightingRadiusMeters = 60;

/// Tarjeta de movilidad del usuario demo, sembrada por el backend.
const String demoCardUid = 'DEMO-0001';

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

  /// En la parada, viendo acercarse la unidad.
  waitingAtStop,

  /// La unidad ya llegó: toca pagar, con tarjeta o con monedas.
  awaitingPayment,

  /// A bordo, viajando.
  onboard,

  /// Llegó a su parada de bajada; falta calificar.
  arrived,
}

/// Cómo pagó el pasaje.
enum PaymentMethod {
  /// Tap de tarjeta de movilidad vinculada al teléfono.
  card,

  /// Monedas al conductor; el sistema lo infiere del movimiento.
  coins,
}

class TripPlan {
  const TripPlan({
    this.stage = TripStage.idle,
    this.destination,
    this.options = const [],
    this.chosen,
    this.boardingSignalId,
    this.paymentMethod,
  });

  final TripStage stage;

  /// Punto que el usuario eligió en el mapa.
  final LatLng? destination;

  /// Opciones ofrecidas, de la mejor a la peor.
  final List<BoardingOption> options;

  /// La que eligió.
  final BoardingOption? chosen;

  /// Id de la señal que representa este viaje: la que se califica y se cierra.
  final int? boardingSignalId;

  /// Cómo pagó, una vez a bordo.
  final PaymentMethod? paymentMethod;

  bool get hasDestination => destination != null;

  /// Hay destino pero ninguna ruta del catálogo lo acerca lo suficiente.
  bool get isUnreachable => hasDestination && options.isEmpty;

  TripPlan copyWith({
    TripStage? stage,
    LatLng? destination,
    List<BoardingOption>? options,
    BoardingOption? chosen,
    int? boardingSignalId,
    PaymentMethod? paymentMethod,
  }) => TripPlan(
    stage: stage ?? this.stage,
    destination: destination ?? this.destination,
    options: options ?? this.options,
    chosen: chosen ?? this.chosen,
    boardingSignalId: boardingSignalId ?? this.boardingSignalId,
    paymentMethod: paymentMethod ?? this.paymentMethod,
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

  /// Paso 4: confirmó que abordará aquí. Se queda en la parada esperando la unidad.
  void markWaitingAtStop(int signalId) {
    state = state.copyWith(
      stage: TripStage.waitingAtStop,
      boardingSignalId: signalId,
    );
    ref.read(userLocationProvider.notifier).stop();
  }

  /// La unidad llegó a la parada: hay que pagar.
  void markBusArrived() {
    if (state.stage != TripStage.waitingAtStop) return;
    state = state.copyWith(stage: TripStage.awaitingPayment);
  }

  /// Paso 5: ya va a bordo.
  ///
  /// [signalId] cambia cuando se pagó con tarjeta, porque `POST /card-taps` crea su propia
  /// señal en vez de reutilizar la declarada en la parada.
  void markOnboard({required PaymentMethod method, int? signalId}) {
    state = state.copyWith(
      stage: TripStage.onboard,
      paymentMethod: method,
      boardingSignalId: signalId ?? state.boardingSignalId,
    );
  }

  /// Paso 6: llegó a su parada de bajada.
  void markArrivedAtDestination() {
    if (state.stage != TripStage.onboard) return;
    state = state.copyWith(stage: TripStage.arrived);
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

/// Dónde va la unidad del viaje, si ya reportó posición.
final tripVehicleProvider = Provider<VehiclePosition?>((ref) {
  final routeId = ref.watch(
    tripPlanProvider.select((plan) => plan.chosen?.route.id),
  );
  if (routeId == null) return null;
  return ref.watch(vehiclePositionsProvider)[routeId];
});

/// Metros entre la unidad y la parada donde el pasajero espera.
final busDistanceToBoardingProvider = Provider<double?>((ref) {
  final stop = ref.watch(
    tripPlanProvider.select((plan) => plan.chosen?.boardingStop),
  );
  final vehicle = ref.watch(tripVehicleProvider);
  if (stop == null || vehicle == null) return null;
  return _distance(vehicle.location, stop.location);
});

/// La unidad ya está llegando: momento de pedir el pago.
final busIsArrivingProvider = Provider<bool>((ref) {
  final meters = ref.watch(busDistanceToBoardingProvider);
  return meters != null && meters <= busApproachingMeters;
});

/// Si la unidad ya pasó por la parada.
///
/// Se recuerda: una vez que estuvo ahí, alejarse significa que se fue. Sin esta memoria no se
/// puede distinguir "viene llegando" de "ya se fue", porque en ambos casos está lejos.
class BusVisitedStopController extends Notifier<bool> {
  int? _forStopId;
  bool _visited = false;

  @override
  bool build() {
    // La memoria se olvida sola al cambiar de parada, sin que nadie tenga que reiniciarla:
    // hacerlo desde fuera encadenaba reconstrucciones en el mismo frame que el reinicio del
    // viaje, y Riverpod lo rechaza.
    final stopId = ref.watch(
      tripPlanProvider.select((plan) => plan.chosen?.boardingStop.id),
    );
    if (stopId != _forStopId) {
      _forStopId = stopId;
      _visited = false;
    }

    final meters = ref.watch(busDistanceToBoardingProvider);
    if (meters != null && meters <= busAtStopMeters) _visited = true;
    return _visited;
  }
}

final busVisitedStopProvider =
    NotifierProvider<BusVisitedStopController, bool>(
      BusVisitedStopController.new,
    );

/// La unidad ya se fue de la parada.
///
/// Es la señal de que el pasajero subió sin pasar tarjeta: pagó con monedas y va a bordo.
final busDepartedStopProvider = Provider<bool>((ref) {
  final visited = ref.watch(busVisitedStopProvider);
  final meters = ref.watch(busDistanceToBoardingProvider);
  return visited && meters != null && meters >= departedStopMeters;
});

/// Metros que faltan para la parada de bajada.
final metersToAlightingProvider = Provider<double?>((ref) {
  final stop = ref.watch(
    tripPlanProvider.select((plan) => plan.chosen?.alightingStop),
  );
  final vehicle = ref.watch(tripVehicleProvider);
  if (stop == null || vehicle == null) return null;
  return _distance(vehicle.location, stop.location);
});

/// Aviso anticipado: prepárate, que ya casi.
final nearAlightingProvider = Provider<bool>((ref) {
  final meters = ref.watch(metersToAlightingProvider);
  return meters != null && meters <= alightingWarningMeters;
});

/// Ya llegó a su parada de bajada.
final atAlightingProvider = Provider<bool>((ref) {
  final meters = ref.watch(metersToAlightingProvider);
  return meters != null && meters <= alightingRadiusMeters;
});
