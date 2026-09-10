/// Cableado de datos con Riverpod.
///
/// Las pantallas no construyen clientes ni conocen URLs: piden estos providers. Cambiar de
/// backend real a uno de prueba es sobreescribir `apiClientProvider` y `realtimeClientProvider`
/// en un `ProviderScope`, que es justo lo que hacen las pruebas.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import 'api_client.dart';
import 'geocoder.dart';
import 'models.dart';
import 'realtime_client.dart';

final apiClientProvider = Provider<ApiClient>((ref) {
  final client = ApiClient(baseUrl: ApiClient.defaultBaseUrl);
  ref.onDispose(client.dispose);
  return client;
});

/// Quién traduce un punto del mapa a una dirección.
///
/// Va aparte de `apiClientProvider` porque no es el backend del proyecto: hoy es Nominatim,
/// consultado directo desde la app. Las pruebas lo sustituyen por un doble para no salir a la
/// red, que es la razón de que la pantalla lo pida por aquí y no lo construya.
final reverseGeocoderProvider = Provider<ReverseGeocoder>((ref) {
  final geocoder = NominatimGeocoder();
  ref.onDispose(geocoder.dispose);
  return geocoder;
});

/// La dirección de un punto del mapa, o `null` si no se pudo averiguar.
///
/// Está indexado por el punto: dos pantallas que preguntan por el mismo destino comparten la
/// respuesta en vez de consultar dos veces. `LatLng` compara por valor, así que la clave
/// funciona sin envolverlo en nada.
final addressProvider = FutureProvider.family<String?, LatLng>((ref, point) {
  return ref.watch(reverseGeocoderProvider).addressAt(point);
});

final realtimeClientProvider = Provider<RealtimeClient>((ref) {
  final client = RealtimeClient(baseUrl: RealtimeClient.defaultBaseUrl);
  client.connect();
  ref.onDispose(client.dispose);
  return client;
});

/// Rutas y paradas del catálogo. Cambian poco, así que se piden una vez.
final routesProvider = FutureProvider<List<TransitRoute>>((ref) {
  return ref.watch(apiClientProvider).fetchRoutes();
});

/// Todas las paradas, indexadas por id, para resolver la que se toca en el mapa.
final stopsByIdProvider = Provider<Map<int, Stop>>((ref) {
  final routes = ref.watch(routesProvider).value ?? const <TransitRoute>[];
  return {
    for (final route in routes)
      for (final stop in route.stops) stop.id: stop,
  };
});

/// A qué ruta pertenece cada parada.
final routeIdByStopProvider = Provider<Map<int, int>>((ref) {
  final routes = ref.watch(routesProvider).value ?? const <TransitRoute>[];
  return {
    for (final route in routes)
      for (final stop in route.stops) stop.id: route.id,
  };
});

/// Usuario de la demo.
///
/// `CLAUDE.md` descarta autenticación robusta en esta fase, así que se crea uno al vuelo la
/// primera vez que hace falta y se reutiliza mientras viva la app. Las pantallas de registro e
/// inicio de sesión son maqueta: todavía no producen este id.
final demoUserIdProvider = FutureProvider<int>((ref) {
  return ref
      .watch(apiClientProvider)
      .createUser(name: 'Pasajero Demo', role: 'passenger');
});

/// Posiciones vivas de las unidades, indexadas por `vehicle_id`.
///
/// Acumula en un mapa en vez de reemplazar una lista: el servidor emite una unidad a la vez,
/// y reemplazar haría desaparecer del mapa a las que no se movieron en ese instante.
class VehiclePositionsController extends Notifier<Map<int, VehiclePosition>> {
  @override
  Map<int, VehiclePosition> build() {
    final subscription = ref
        .watch(realtimeClientProvider)
        .vehiclePositions
        .listen((position) {
          state = {...state, position.vehicleId: position};
        });
    ref.onDispose(subscription.cancel);
    return const {};
  }
}

final vehiclePositionsProvider =
    NotifierProvider<VehiclePositionsController, Map<int, VehiclePosition>>(
      VehiclePositionsController.new,
    );

/// Cuánta gente espera en cada parada.
///
/// Arranca con el conteo actual por REST y a partir de ahí sigue los eventos `demand:update`,
/// que es lo mismo que consume el panel institucional.
class DemandController extends AsyncNotifier<Map<int, int>> {
  @override
  Future<Map<int, int>> build() async {
    final subscription = ref.watch(realtimeClientProvider).demandUpdates.listen(
      (update) {
        final current = state.value;
        if (current == null) return;
        state = AsyncData({...current, update.stopId: update.waitingCount});
      },
    );
    ref.onDispose(subscription.cancel);

    final counts = await ref.watch(apiClientProvider).fetchDemand();
    return {for (final count in counts) count.stopId: count.waitingCount};
  }
}

final demandProvider = AsyncNotifierProvider<DemandController, Map<int, int>>(
  DemandController.new,
);

/// ETA de una parada concreta. Se recalcula al abrir su hoja.
final stopEtaProvider = FutureProvider.family<StopEta?, int>((ref, stopId) {
  return ref.watch(apiClientProvider).fetchStopEta(stopId);
});

/// Si el canal en vivo está conectado.
///
/// Alimenta el aviso de "sin conexión con el servidor": sin él, un backend apagado se ve
/// igual que un mapa sin unidades circulando.
final realtimeConnectedProvider = StreamProvider<bool>((ref) {
  return ref.watch(realtimeClientProvider).connectionState;
});
