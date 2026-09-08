/// El viaje multimodal: el que combina camión, teleférico y caminata para llegar antes.
///
/// A diferencia de los otros modos, aquí el cliente no traza nada — el recorrido lo arma el
/// servidor. Por eso este viaje sí tiene estado de carga: hay una petición de red entre decir a
/// dónde vas y ver el itinerario.
///
/// El avance se cuenta en **minutos**, no en metros. Cada tramo trae su propio tiempo desde el
/// servidor, y ese tiempo ya incorpora la velocidad del modo; medir en metros obligaría a
/// suponer velocidades por nuestra cuenta y la app acabaría contradiciendo al backend.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import 'journey.dart';
import 'path_geometry.dart';
import 'providers.dart';
import 'trip_plan.dart' show userLocationProvider;

/// Cuánto se acelera el recorrido respecto al tiempo real.
///
/// Más alto que en los otros modos porque un viaje con transbordos dura bastante más: a 20x,
/// ocho minutos de trayecto se recorren en veinticuatro segundos. **Solo afecta la
/// simulación**; los minutos en pantalla son los que dio el servidor.
const int journeyDemoSpeedFactor = 20;

/// Cada cuánto avanza el viaje simulado.
const Duration journeyTick = Duration(milliseconds: 500);

enum JourneyStage {
  /// Sin viaje.
  idle,

  /// Pidiendo el itinerario al servidor.
  loading,

  /// En camino.
  traveling,

  /// Llegó al destino.
  arrived,

  /// No se pudo armar un viaje.
  failed,
}

class JourneyTrip {
  const JourneyTrip({
    this.stage = JourneyStage.idle,
    this.destination,
    this.alternatives = const [],
    this.selected = 0,
    this.elapsedMinutes = 0,
    this.error,
  });

  final JourneyStage stage;
  final LatLng? destination;

  /// Las opciones que devolvió el servidor. La primera es la más rápida.
  final List<Journey> alternatives;

  /// Cuál se está recorriendo.
  final int selected;

  final double elapsedMinutes;

  /// Por qué no se pudo, cuando [stage] es [JourneyStage.failed].
  final String? error;

  Journey? get journey =>
      alternatives.isEmpty || selected >= alternatives.length
      ? null
      : alternatives[selected];

  /// El tramo en el que va ahora mismo.
  JourneyLeg? get currentLeg {
    final journey = this.journey;
    if (journey == null || journey.legs.isEmpty) return null;

    var left = elapsedMinutes;
    for (final leg in journey.legs) {
      if (left < leg.minutes) return leg;
      left -= leg.minutes;
    }
    return journey.legs.last;
  }

  /// Dónde va el pasajero, interpolando dentro del tramo actual.
  LatLng? get position {
    final journey = this.journey;
    if (journey == null || journey.legs.isEmpty) return null;

    var left = elapsedMinutes;
    for (final leg in journey.legs) {
      if (left < leg.minutes || leg == journey.legs.last) {
        final fraction = leg.minutes <= 0
            ? 1.0
            : (left / leg.minutes).clamp(0.0, 1.0);
        return lerpLatLng(leg.from.location, leg.to.location, fraction);
      }
      left -= leg.minutes;
    }
    return journey.legs.last.to.location;
  }

  double get remainingMinutes {
    final journey = this.journey;
    if (journey == null) return 0;
    final left = journey.totalMinutes - elapsedMinutes;
    return left < 0 ? 0 : left;
  }

  /// Lo que falta, redondeado y nunca a cero: "llegas en 0 min" se lee como que ya pasó.
  int get roundedRemaining =>
      remainingMinutes < 1 ? 1 : remainingMinutes.round();

  JourneyTrip copyWith({
    JourneyStage? stage,
    LatLng? destination,
    List<Journey>? alternatives,
    int? selected,
    double? elapsedMinutes,
    String? error,
  }) => JourneyTrip(
    stage: stage ?? this.stage,
    destination: destination ?? this.destination,
    alternatives: alternatives ?? this.alternatives,
    selected: selected ?? this.selected,
    elapsedMinutes: elapsedMinutes ?? this.elapsedMinutes,
    error: error ?? this.error,
  );
}

class JourneyTripController extends Notifier<JourneyTrip> {
  Timer? _timer;

  @override
  JourneyTrip build() {
    ref.onDispose(() => _timer?.cancel());
    return const JourneyTrip();
  }

  /// Pide el itinerario y arranca en cuanto llega.
  Future<void> start(LatLng destination) async {
    _timer?.cancel();
    _timer = null;

    final origin = ref.read(userLocationProvider);
    state = JourneyTrip(stage: JourneyStage.loading, destination: destination);

    try {
      final alternatives = await ref
          .read(apiClientProvider)
          .fetchJourneys(origin: origin, destination: destination);

      if (alternatives.isEmpty) {
        state = state.copyWith(
          stage: JourneyStage.failed,
          error: 'No encontramos ninguna forma de llegar.',
        );
        return;
      }

      state = state.copyWith(
        stage: JourneyStage.traveling,
        alternatives: alternatives,
      );
      _startTicking();
    } catch (error) {
      state = state.copyWith(
        stage: JourneyStage.failed,
        error: 'No pudimos calcular el viaje. $error',
      );
    }
  }

  /// Cambia de alternativa y vuelve a empezar el recorrido.
  void select(int index) {
    if (index < 0 || index >= state.alternatives.length) return;
    state = state.copyWith(
      stage: JourneyStage.traveling,
      selected: index,
      elapsedMinutes: 0,
    );
    _startTicking();
  }

  void reset() {
    _timer?.cancel();
    _timer = null;
    state = const JourneyTrip();
  }

  void _startTicking() {
    _timer?.cancel();
    _timer = Timer.periodic(journeyTick, (_) => _advance());
  }

  void _advance() {
    final journey = state.journey;
    if (journey == null || state.stage != JourneyStage.traveling) return;

    final minutesPerTick =
        journeyTick.inMilliseconds / 1000 / 60 * journeyDemoSpeedFactor;
    final elapsed = state.elapsedMinutes + minutesPerTick;

    if (elapsed >= journey.totalMinutes) {
      _timer?.cancel();
      _timer = null;
      state = state.copyWith(
        stage: JourneyStage.arrived,
        elapsedMinutes: journey.totalMinutes,
      );
      return;
    }

    state = state.copyWith(elapsedMinutes: elapsed);
  }
}

final journeyTripProvider =
    NotifierProvider<JourneyTripController, JourneyTrip>(
      JourneyTripController.new,
    );
