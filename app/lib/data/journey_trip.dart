/// El viaje personalizado: el usuario elige con qué medios quiere ir y el servidor arma el
/// mejor recorrido con esos.
///
/// No es "el más rápido" a secas. Lo más rápido casi siempre sería la bici, y quien no tiene
/// bici no quiere verla; quien va cargado tampoco quiere caminar dos kilómetros aunque salga
/// antes. El mejor viaje es el mejor **dentro de lo que la persona está dispuesta a tomar**, y
/// por eso los medios son parte de la pregunta y no del resultado.
///
/// A diferencia de los otros modos, aquí el cliente no traza nada — el recorrido lo arma el
/// servidor. Por eso este viaje sí tiene estado de carga: hay una petición de red entre decir a
/// dónde vas y ver el itinerario.
///
/// Y por eso mismo tiene una etapa que los demás no tienen: [JourneyStage.planned]. El
/// itinerario llega antes de que el usuario haya dicho con qué medios acepta ir, así que se
/// enseña **quieto** — trazado en el mapa, marcador en el origen, reloj sin correr — hasta que
/// lo aprueba. Arrancar solo porque el servidor contestó pone el viaje en marcha con los cuatro
/// medios por omisión, que es justo la pregunta que este modo existe para hacer.
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
/// Más alto que en los otros modos porque un viaje con transbordos dura bastante más: a 40x,
/// ocho minutos de trayecto se recorren en doce segundos. **Solo afecta la simulación**; los
/// minutos en pantalla son los que dio el servidor.
const int journeyDemoSpeedFactor = 40;

/// Cada cuánto avanza el viaje simulado. Acompaña al factor de arriba: al doblar la velocidad
/// se parte el tick a la mitad, así cada paso mide lo mismo en el mapa.
const Duration journeyTick = Duration(milliseconds: 250);

enum JourneyStage {
  /// Sin viaje.
  idle,

  /// Pidiendo el itinerario al servidor.
  loading,

  /// Itinerario listo, pero quieto: el usuario todavía no dice que arranca.
  planned,

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
    this.modes = const {
      JourneyMode.bike,
      JourneyMode.combi,
      JourneyMode.bus,
      JourneyMode.cableCar,
    },
    this.elapsedMinutes = 0,
    this.error,
  });

  final JourneyStage stage;
  final LatLng? destination;

  /// Las opciones que devolvió el servidor. La primera es la más rápida.
  final List<Journey> alternatives;

  /// Cuál se está recorriendo.
  final int selected;

  /// Medios que el usuario acepta tomar. La caminata no está: no se elige, es lo que une los
  /// demás tramos y siempre puede hacer falta para llegar a una parada.
  final Set<JourneyMode> modes;

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
  ///
  /// Sobre el trazado del tramo, no en línea recta entre sus extremos: con la geometría por
  /// calles que trae el servidor, un marcador que cortara camino se despegaría visiblemente de
  /// su propia línea en cada curva.
  LatLng? get position {
    final journey = this.journey;
    if (journey == null || journey.legs.isEmpty) return null;

    var left = elapsedMinutes;
    for (final leg in journey.legs) {
      if (left < leg.minutes || leg == journey.legs.last) {
        final fraction = leg.minutes <= 0
            ? 1.0
            : (left / leg.minutes).clamp(0.0, 1.0);
        final path = leg.path;
        return pointAlongPath(path, pathLengthMeters(path) * fraction);
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
    Set<JourneyMode>? modes,
    double? elapsedMinutes,
    String? error,
  }) => JourneyTrip(
    stage: stage ?? this.stage,
    destination: destination ?? this.destination,
    alternatives: alternatives ?? this.alternatives,
    selected: selected ?? this.selected,
    modes: modes ?? this.modes,
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

  /// Fija los medios con los que se va a armar el viaje, antes de saber a dónde va.
  ///
  /// Es el primer paso del flujo, así que no planea nada: no hay destino todavía. Lo que hace
  /// es asegurar que la primera petición al servidor ya salga con lo que el pasajero eligió,
  /// en vez de con los cuatro medios por omisión.
  void setModes(Set<JourneyMode> modes) {
    if (modes.isEmpty) return;
    state = state.copyWith(modes: Set.unmodifiable(modes));
  }

  /// Pide el itinerario. Al llegar queda propuesto, no en marcha: arrancar lo decide el
  /// usuario con [begin], una vez que revisó los medios.
  Future<void> start(LatLng destination) async {
    // Conserva los medios: se eligieron un paso antes y son el filtro de esta petición.
    state = JourneyTrip(
      stage: JourneyStage.idle,
      destination: destination,
      modes: state.modes,
    );
    await _plan();
  }

  /// Enciende o apaga un medio y vuelve a planear con los que queden.
  ///
  /// No deja quitar el último: sin ningún medio el servidor entiende "todos" y devolvería justo
  /// lo contrario de lo que se pidió. Para ir solo a pie está el modo de caminata, que además
  /// esquiva las zonas marcadas.
  Future<void> toggleMode(JourneyMode mode) async {
    final modes = Set<JourneyMode>.from(state.modes);
    if (modes.contains(mode)) {
      if (modes.length == 1) return;
      modes.remove(mode);
    } else {
      modes.add(mode);
    }
    state = state.copyWith(modes: modes);
    await _plan();
  }

  Future<void> _plan() async {
    _timer?.cancel();
    _timer = null;

    final destination = state.destination;
    if (destination == null) return;

    final origin = ref.read(userLocationProvider);
    state = state.copyWith(
      stage: JourneyStage.loading,
      alternatives: const [],
      selected: 0,
      elapsedMinutes: 0,
    );

    try {
      final alternatives = await ref
          .read(apiClientProvider)
          .fetchJourneys(
            origin: origin,
            destination: destination,
            modes: state.modes.toList(),
          );

      if (alternatives.isEmpty) {
        state = state.copyWith(
          stage: JourneyStage.failed,
          error:
              'No encontramos forma de llegar con los medios que elegiste. '
              'Prueba agregando alguno.',
        );
        return;
      }

      state = state.copyWith(
        stage: JourneyStage.planned,
        alternatives: alternatives,
      );
    } catch (error) {
      state = state.copyWith(
        stage: JourneyStage.failed,
        error: 'No pudimos calcular el viaje. $error',
      );
    }
  }

  /// Da por buena la propuesta y echa a andar el recorrido.
  ///
  /// Es el único camino a [JourneyStage.traveling]: ni recibir el itinerario ni cambiar de
  /// alternativa mueven al pasajero por su cuenta.
  void begin() {
    if (state.stage != JourneyStage.planned || state.journey == null) return;
    state = state.copyWith(stage: JourneyStage.traveling, elapsedMinutes: 0);
    _startTicking();
  }

  /// Cambia de alternativa y vuelve a empezar el recorrido.
  ///
  /// Conserva la etapa: si ya iba en camino, sigue en camino por la nueva; si todavía la estaba
  /// revisando, sigue quieta esperando el visto bueno. Llegado el destino vuelve a proponerse,
  /// porque recorrer otra alternativa es empezar un viaje distinto.
  void select(int index) {
    if (index < 0 || index >= state.alternatives.length) return;

    final traveling = state.stage == JourneyStage.traveling;
    state = state.copyWith(
      stage: traveling ? JourneyStage.traveling : JourneyStage.planned,
      selected: index,
      elapsedMinutes: 0,
    );

    if (traveling) {
      _startTicking();
    } else {
      _timer?.cancel();
      _timer = null;
    }
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
