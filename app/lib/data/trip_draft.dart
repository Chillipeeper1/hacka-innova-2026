/// Viaje que el pasajero está armando.
///
/// El orden importa: primero se declara **a dónde va**, y solo después se confirma el
/// abordaje. Una confirmación suelta ("alguien espera en la parada 3") dice mucho menos que un
/// par origen-destino: con el destino se sabe qué tramo del corredor va a ocupar, en qué
/// parada debería bajarse, y se puede estimar la carga real de la ruta y no solo la fila en un
/// punto.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import 'models.dart';
import 'providers.dart';

/// Distancia máxima entre el punto que el usuario eligió y una parada del catálogo para
/// considerar que esa parada lo deja en su destino.
///
/// Con solo dos rutas sembradas, un radio grande haría que cualquier punto de Morelia
/// "tuviera ruta" y la demo mentiría. Mejor decir que no hay servicio.
const double maxWalkToDestinationMeters = 1200;

/// Hasta dónde dos paradas del catálogo se consideran el mismo lugar físico.
const double samePlaceMeters = 40;

const Distance _distance = Distance();

/// Estado del viaje antes de abordar.
class TripDraft {
  const TripDraft({
    this.destination,
    this.destinationStop,
    this.route,
    this.metersFromDestination,
  });

  /// Punto que el usuario eligió en el mapa.
  final LatLng? destination;

  /// Parada del catálogo donde tendría que bajarse.
  final Stop? destinationStop;

  /// Ruta que sirve ese destino.
  final TransitRoute? route;

  /// Cuánto tendría que caminar desde la parada de bajada hasta su destino.
  final double? metersFromDestination;

  bool get hasDestination => destination != null;

  /// Hay destino, pero ninguna ruta del catálogo llega cerca.
  bool get isUnreachable => hasDestination && destinationStop == null;

  /// Listo para abordar: se sabe a dónde va y por qué ruta.
  bool get isRoutable => destinationStop != null && route != null;

  /// La parada **de la ruta del viaje** por la que se aborda al tocar [stop], o `null` si esa
  /// parada no sirve para llegar al destino.
  ///
  /// No basta comparar ids: el catálogo repite la misma parada física en cada ruta que pasa
  /// por ahí — "Catedral de Morelia" existe con id 1 en la ruta 1 y con id 4 en la ruta 2. Al
  /// usuario parado en la banqueta le da igual cuál marcador tocó, así que se acepta la
  /// coincidencia por cercanía y se manda al servidor el id que corresponde a la ruta que
  /// realmente va a viajar.
  Stop? boardingStopFor(Stop stop) {
    final target = destinationStop;
    final serving = route;
    if (target == null || serving == null) return null;

    for (final candidate in serving.stops) {
      if (candidate.id == target.id) continue;
      final isSamePlace =
          candidate.id == stop.id ||
          _distance(candidate.location, stop.location) <= samePlaceMeters;
      if (isSamePlace) return candidate;
    }
    return null;
  }

  /// Si esta parada sirve para abordar hacia el destino.
  bool canBoardAt(Stop stop) => boardingStopFor(stop) != null;
}

class TripDraftController extends Notifier<TripDraft> {
  @override
  TripDraft build() => const TripDraft();

  /// Registra el destino y resuelve por dónde llegar.
  ///
  /// Busca la parada más cercana al punto elegido y la ruta que la sirve. Es deliberadamente
  /// simple: el mockup tiene dos rutas y ningún motor de ruteo — el documento base deja el
  /// ruteo multimodal real para la versión de producción.
  void setDestination(LatLng point) {
    final routes = ref.read(routesProvider).value ?? const <TransitRoute>[];

    Stop? nearest;
    TransitRoute? servingRoute;
    var nearestMeters = double.infinity;

    for (final route in routes) {
      for (final stop in route.stops) {
        final meters = _distance(point, stop.location);
        if (meters < nearestMeters) {
          nearestMeters = meters;
          nearest = stop;
          servingRoute = route;
        }
      }
    }

    final reachable = nearest != null && nearestMeters <= maxWalkToDestinationMeters;

    state = TripDraft(
      destination: point,
      destinationStop: reachable ? nearest : null,
      route: reachable ? servingRoute : null,
      metersFromDestination: reachable ? nearestMeters : null,
    );
  }

  void clear() => state = const TripDraft();
}

final tripDraftProvider = NotifierProvider<TripDraftController, TripDraft>(
  TripDraftController.new,
);
