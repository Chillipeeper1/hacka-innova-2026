import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../data/models.dart';
import '../data/providers.dart';
import '../data/trip_draft.dart';
import '../morelia.dart';
import '../theme.dart';
import '../widgets/map_chrome.dart';
import '../widgets/stop_sheet.dart';

/// Pantalla principal del pasajero.
///
/// Implementa el diseño de Figma ("HACKA", nodo 17:284) y cubre el Escenario 1 de
/// `CLAUDE.md`: el mapa con las rutas, sus paradas y la unidad en vivo.
///
/// El diseño usa una captura de pantalla de Google Maps como fondo. Aquí va un mapa de verdad
/// con `flutter_map` sobre teselas de OpenStreetMap, que es el stack que pide `CLAUDE.md`:
/// sobre una captura no se podrían pintar las rutas ni mover la unidad.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({
    super.key,
    this.onMenu,
    this.onProfile,
    this.onSearchStop,
    this.onTravelByBike,
    this.onTravelWalking,
  });

  final VoidCallback? onMenu;
  final VoidCallback? onProfile;
  final VoidCallback? onSearchStop;
  final VoidCallback? onTravelByBike;
  final VoidCallback? onTravelWalking;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trip = ref.watch(tripDraftProvider);

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          _MoreliaMap(onSetDestination: onSearchStop),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = math.min(constraints.maxWidth, maxContentWidth);
              final s = scaleFor(width);
              final gutter = gutterFor(width);

              return Stack(
                children: [
                  // Controles superiores. En pantallas anchas el mapa sigue a pantalla
                  // completa pero los controles se quedan centrados y a ancho de lectura.
                  Align(
                    alignment: Alignment.topCenter,
                    child: SafeArea(
                      bottom: false,
                      child: SizedBox(
                        width: width,
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            gutter,
                            12 * s,
                            gutter,
                            0,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  SquareIconButton(
                                    asset: 'assets/icons/menu.svg',
                                    label: 'Abrir menú',
                                    size: 61 * s,
                                    onTap: onMenu,
                                  ),
                                  SquareIconButton(
                                    asset: 'assets/icons/person.svg',
                                    label: 'Mi perfil',
                                    size: 61 * s,
                                    onTap: onProfile,
                                  ),
                                ],
                              ),
                              SizedBox(height: 30 * s),
                              SearchStopCard(
                                width: width,
                                // El buscador es también el estado del viaje: mientras no
                                // haya destino, es lo primero que hay que hacer.
                                label: switch (trip) {
                                  TripDraft(isRoutable: true) =>
                                    'Vas a ${trip.destinationStop!.name}',
                                  TripDraft(isUnreachable: true) =>
                                    'Sin ruta a ese destino',
                                  _ => '¿A dónde vas?',
                                },
                                onTap: onSearchStop,
                              ),
                              const _BackendStatusBanner(),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // La atribución va pegada encima de la hoja porque la hoja tapa la
                        // esquina inferior derecha, que es donde iría por convención.
                        _MapAttribution(width: width),
                        _TravelSheet(
                          width: width,
                          maxHeight: constraints.maxHeight,
                          onTravelByBike: onTravelByBike,
                          onTravelWalking: onTravelWalking,
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// El mapa, con las rutas, sus paradas y las unidades en vivo.
class _MoreliaMap extends ConsumerWidget {
  const _MoreliaMap({this.onSetDestination});

  final VoidCallback? onSetDestination;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routes = ref.watch(routesProvider).value ?? const <TransitRoute>[];
    final vehicles = ref.watch(vehiclePositionsProvider);
    final demand = ref.watch(demandProvider).value ?? const <int, int>{};
    final trip = ref.watch(tripDraftProvider);

    return FlutterMap(
      options: MapOptions(
        initialCenter: Morelia.center,
        initialZoom: Morelia.defaultZoom,
        minZoom: Morelia.minZoom,
        maxZoom: Morelia.maxZoom,
        // Sin esto, un arrastrón manda la cámara al otro lado del mundo, donde el mockup no
        // tiene nada que mostrar.
        cameraConstraint: CameraConstraint.containCenter(
          bounds: LatLngBounds(Morelia.southWest, Morelia.northEast),
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: Morelia.tileUrlTemplate,
          userAgentPackageName: Morelia.userAgentPackageName,
          maxZoom: Morelia.maxZoom,
        ),

        // El trazado une paradas consecutivas: el mockup no tiene geometría de calles, y el
        // motor de ruteo real es cosa de la versión de producción.
        PolylineLayer(
          polylines: [
            for (final route in routes)
              if (route.shape.length > 1)
                Polyline(
                  points: route.shape,
                  // Con destino elegido, la ruta que sirve se destaca y las demás se
                  // atenúan: el mapa deja de ser un catálogo y pasa a mostrar un viaje.
                  color: colorFromHex(route.colorHex).withValues(
                    alpha:
                        trip.route == null || trip.route!.id == route.id
                            ? 0.85
                            : 0.25,
                  ),
                  strokeWidth: trip.route?.id == route.id ? 6 : 5,
                ),
          ],
        ),

        MarkerLayer(
          markers: [
            for (final route in routes)
              for (final stop in route.stops)
                Marker(
                  point: stop.location,
                  width: 44,
                  height: 44,
                  child: _StopMarker(
                    stop: stop,
                    routeId: route.id,
                    color: colorFromHex(route.colorHex),
                    waiting: demand[stop.id] ?? 0,
                    isAlightingStop: trip.destinationStop?.id == stop.id,
                    onSetDestination: onSetDestination,
                  ),
                ),
          ],
        ),

        MarkerLayer(
          markers: [
            for (final vehicle in vehicles.values)
              Marker(
                point: vehicle.location,
                width: 40,
                height: 40,
                child: _VehicleMarker(
                  color: colorFromHex(
                    routes
                        .where((route) => route.id == vehicle.routeId)
                        .map((route) => route.colorHex)
                        .firstOrNull,
                  ),
                ),
              ),
          ],
        ),

        if (trip.destination != null)
          MarkerLayer(
            markers: [
              Marker(
                point: trip.destination!,
                width: 34,
                height: 34,
                child: const _DestinationMarker(),
              ),
            ],
          ),

        const MarkerLayer(markers: [_userLocationMarker]),
      ],
    );
  }

  /// Punto azul de "estás aquí".
  ///
  /// TODO(ubicación): hoy está fijo en el centro de Morelia. Cuando se conecte el GPS real
  /// debe seguir la posición del dispositivo — y pedir permiso antes, no después.
  static const Marker _userLocationMarker = Marker(
    point: Morelia.center,
    width: 22,
    height: 22,
    child: _UserLocationDot(),
  );
}

/// Parada tocable. Al tocarla se abre la hoja con el ETA y la confirmación de abordaje.
class _StopMarker extends StatelessWidget {
  const _StopMarker({
    required this.stop,
    required this.routeId,
    required this.color,
    required this.waiting,
    this.isAlightingStop = false,
    this.onSetDestination,
  });

  final Stop stop;
  final int routeId;
  final Color color;
  final int waiting;

  /// La parada donde el viaje termina; se marca distinto para no confundirla con una de
  /// abordaje.
  final bool isAlightingStop;

  final VoidCallback? onSetDestination;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label:
          isAlightingStop
              ? 'Parada de bajada ${stop.name}'
              : 'Parada ${stop.name}',
      child: GestureDetector(
        onTap: () async {
          final boarded = await StopSheet.show(
            context,
            stop: stop,
            routeId: routeId,
            onSetDestination: onSetDestination,
          );
          if (boarded == true && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Te esperamos en ${stop.name}')),
            );
          }
        },
        child: Center(
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Container(
                width: isAlightingStop ? 28 : 22,
                height: isAlightingStop ? 28 : 22,
                decoration: BoxDecoration(
                  color: isAlightingStop ? AppColors.magentaDeep : color,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x33000000),
                      blurRadius: 3,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
              ),
              // Insignia con el conteo de gente esperando: es la señal de demanda del
              // proyecto, visible en el mismo mapa y no solo en el panel institucional.
              if (waiting > 0)
                Positioned(
                  top: -4,
                  right: -8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.magenta,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: Text(
                      '$waiting',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Unidad en movimiento.
class _VehicleMarker extends StatelessWidget {
  const _VehicleMarker({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      // `container: true`: sin él la etiqueta no llega a formar un nodo propio y el lector de
      // pantalla no anuncia la unidad.
      container: true,
      label: 'Unidad en ruta',
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: color, width: 3),
          boxShadow: const [
            BoxShadow(
              color: Color(0x40000000),
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(7),
          child: SvgPicture.asset('assets/icons/bus.svg'),
        ),
      ),
    );
  }
}

class _UserLocationDot extends StatelessWidget {
  const _UserLocationDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2E7DF6),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
    );
  }
}

/// Aviso de que el backend no responde.
///
/// Sin él, un servidor apagado se ve idéntico a un mapa sin unidades circulando, y en una
/// demo eso se confunde con que la app está rota.
class _BackendStatusBanner extends ConsumerWidget {
  const _BackendStatusBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routes = ref.watch(routesProvider);
    final connected = ref.watch(realtimeConnectedProvider).value;

    final hasProblem = routes.hasError || connected == false;
    if (!hasProblem) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.squareButton),
          boxShadow: AppShadows.squareButton,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              const Icon(
                Icons.cloud_off,
                size: 18,
                color: AppColors.magentaDeep,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  routes.hasError
                      ? 'Sin conexión con el servidor. Revisa que `server/` esté corriendo.'
                      : 'Se perdió el tiempo real. Reintentando...',
                  style: const TextStyle(fontSize: 13, color: Colors.black87),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Hoja inferior con las opciones de viaje.
class _TravelSheet extends StatelessWidget {
  const _TravelSheet({
    required this.width,
    required this.maxHeight,
    this.onTravelByBike,
    this.onTravelWalking,
  });

  final double width;
  final double maxHeight;
  final VoidCallback? onTravelByBike;
  final VoidCallback? onTravelWalking;

  @override
  Widget build(BuildContext context) {
    final s = scaleFor(width);
    final gutter = gutterFor(width);
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.sheet),
        ),
        boxShadow: AppShadows.sheet,
      ),
      child: ConstrainedBox(
        // Con tipografía grande los renglones crecen; la hoja no debe comerse el mapa
        // completo, así que a partir de la mitad de la pantalla se desplaza por dentro.
        constraints: BoxConstraints(maxHeight: maxHeight * 0.55),
        child: SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: maxContentWidth),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  gutter,
                  22 * s,
                  gutter,
                  20 * s + bottomInset,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TravelOptionTile(
                      asset: 'assets/icons/bicycle.svg',
                      label: 'Viajar en bici...',
                      width: width,
                      iconDesignSize: 49,
                      onTap: onTravelByBike,
                    ),
                    const Divider(height: 1, color: AppColors.surfaceGrey),
                    TravelOptionTile(
                      asset: 'assets/icons/walk.svg',
                      label: 'Viajar caminando...',
                      width: width,
                      iconDesignSize: 41,
                      onTap: onTravelWalking,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Atribución de OpenStreetMap.
///
/// Es requisito de la licencia de los datos, no un adorno. No se usa
/// `SimpleAttributionWidget` de flutter_map porque antepone su propio "© " —dejando
/// "© © OpenStreetMap"— y su fila no puede encoger, así que desborda en pantallas angostas.
class _MapAttribution extends StatelessWidget {
  const _MapAttribution({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    final gutter = gutterFor(width);

    return SizedBox(
      width: width,
      child: Padding(
        padding: EdgeInsets.fromLTRB(gutter, 0, gutter, 8),
        child: Align(
          alignment: Alignment.centerRight,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.82),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              child: Text(
                Morelia.tileAttribution,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, color: Colors.black87),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Punto exacto que el usuario eligió como destino.
///
/// Va aparte de la parada de bajada: son cosas distintas, y ver ambas explica de un vistazo
/// cuánto hay que caminar al bajarse.
class _DestinationMarker extends StatelessWidget {
  const _DestinationMarker();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'Tu destino',
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.magentaDeep, width: 3),
          boxShadow: const [
            BoxShadow(
              color: Color(0x40000000),
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: const Icon(
          Icons.flag,
          size: 16,
          color: AppColors.magentaDeep,
        ),
      ),
    );
  }
}
