import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models.dart';
import '../data/providers.dart';
import '../data/trip_plan.dart' show userLocationProvider;
import '../morelia.dart';
import '../theme.dart';
import '../widgets/app_map.dart';
import '../widgets/map_chrome.dart';
import '../widgets/trip_widgets.dart';

/// Pantalla principal del pasajero: el mapa de la red, con las formas de viajar debajo.
///
/// Implementa el diseño de Figma ("HACKA", nodo 17:284): mapa a pantalla completa, los dos
/// botones verdes arriba, la tarjeta blanca de búsqueda flotando sobre él y una hoja blanca
/// abajo con las opciones de viaje.
///
/// Hubo un momento en que este inicio fue un menú plano sin mapa, y por una razón buena: el
/// mapa de entonces no tenía nada dibujado —ni rutas ni paradas— porque dependían de a dónde
/// fuera el usuario, así que ocupaba la pantalla entera sin responder a nada. Eso ya no aplica:
/// aquí se pinta el catálogo completo de `GET /routes` —las cuatro rutas con su trazado por
/// calles y sus paradas— más dónde está el pasajero, así que el mapa dice algo desde el primer
/// segundo y se puede recorrer.
///
/// Dos diferencias deliberadas contra el Figma, las dos por lo mismo —el diseño lista **dos**
/// opciones de viaje y la app tiene cuatro—: los renglones van apretados
/// ([TravelOptionTile.dense]) y la hoja se limita a poco más de un tercio de la pantalla, para
/// que el mapa siga siendo lo que más se ve.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({
    super.key,
    this.onMenu,
    this.onProfile,
    this.onSearchStop,
    this.onPlus,
    this.onAd,
    this.onCustomTrip,
    this.onTravelByBike,
    this.onTravelWalking,
    this.onTravelByCableCar,
  });

  final VoidCallback? onMenu;
  final VoidCallback? onProfile;

  /// La tarjeta de arriba. Es la entrada al viaje en camión desde el primer día del proyecto;
  /// moverla a otro sitio deja a quien ya la conoce sin su flujo.
  final VoidCallback? onSearchStop;

  /// MTAPP Plus: agenda, guardianes y caja negra (`PlusScreen`).
  ///
  /// Una sola entrada y no una por función: las tres son el mismo dato mirado desde tres
  /// lados, y dos botones separados las vendían como dos productos que no se conocen.
  final VoidCallback? onPlus;

  /// El espacio publicitario debajo del buscador (`AdSlotCard`).
  final VoidCallback? onAd;

  /// El viaje donde el usuario elige con qué medios quiere llegar.
  final VoidCallback? onCustomTrip;

  final VoidCallback? onTravelByBike;
  final VoidCallback? onTravelWalking;
  final VoidCallback? onTravelByCableCar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const _NetworkMap(),

          LayoutBuilder(
            builder: (context, constraints) {
              final width = math.min(constraints.maxWidth, maxContentWidth);
              final s = scaleFor(width);
              final gutter = gutterFor(width);

              return Stack(
                children: [
                  MapTopControls(
                    width: width,
                    onMenu: onMenu,
                    onProfile: onProfile,
                    trailing: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SearchStopCard(
                          width: width,
                          label: 'Paradas de bus disponibles',
                          onTap: onSearchStop,
                        ),
                        SizedBox(height: 12 * s),
                        Center(
                          child: AdSlotCard(width: width, onTap: onAd),
                        ),
                        const _BackendStatusBanner(),
                      ],
                    ),
                  ),

                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // La entrada de pago va aquí y no en la hoja porque no es un modo de
                        // transporte: es una pantalla aparte. Colgada del borde superior de la
                        // hoja —y no anclada al fondo del mapa— sigue a la hoja cuando esta
                        // crece con el texto grande, en vez de quedar tapada.
                        Center(
                          child: SizedBox(
                            width: width,
                            child: Padding(
                              padding: EdgeInsets.fromLTRB(
                                gutter,
                                0,
                                gutter,
                                14 * s,
                              ),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: MapPillButton.icon(
                                  width: width,
                                  label: 'MTAPP Plus',
                                  icon: Icons.workspace_premium,
                                  onTap: onPlus,
                                ),
                              ),
                            ),
                          ),
                        ),

                        TripSheet(
                          width: width,
                          maxHeight: constraints.maxHeight,
                          // El alto que necesitan las cuatro opciones no depende del alto de
                          // la pantalla sino del ancho, que es lo que fija la escala
                          // tipográfica. En un teléfono corto ese alto fijo es una fracción
                          // mayor, y con el 40% de una pantalla alta la última opción quedaba
                          // fuera y había que adivinar que la hoja rueda.
                          maxHeightFactor: constraints.maxHeight >= 780
                              ? 0.4
                              : 0.52,
                          child: _ModeMenu(
                            width: width,
                            onCustomTrip: onCustomTrip,
                            onTravelByBike: onTravelByBike,
                            onTravelWalking: onTravelWalking,
                            onTravelByCableCar: onTravelByCableCar,
                          ),
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

/// El mapa del inicio: toda la red, cuando todavía no hay viaje.
///
/// Dibuja las cuatro rutas con su trazado por calles y sus paradas, cada una en su color, más
/// dónde está el pasajero. Es lo que hace que el mapa del inicio valga la pena: se ve qué
/// cubre el sistema antes de pedirle nada.
class _NetworkMap extends ConsumerWidget {
  const _NetworkMap();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routes = ref.watch(routesProvider).value ?? const <TransitRoute>[];
    final position = ref.watch(userLocationProvider);

    return AppMap(
      initialCenter: Morelia.center,
      // Más abierto que en las pantallas de viaje: aquí lo que se enseña es la red entera y no
      // un recorrido.
      initialZoom: 13.5,
      lines: [
        for (final route in routes)
          MapLine(
            id: 'ruta-${route.id}',
            points: route.shape,
            color: colorFromHex(route.colorHex).withValues(alpha: 0.85),
          ),
      ],
      markers: [
        for (final route in routes)
          for (final stop in route.stops)
            MapMarker(
              id: 'parada-${stop.id}',
              point: stop.location,
              icon: DotMapIcon(fill: colorFromHex(route.colorHex)),
            ),
        MapMarker(
          id: 'usuario',
          point: position,
          icon: const DotMapIcon(fill: Color(0xFF2E7DF6)),
          semanticLabel: 'Tu posición',
        ),
      ],
    );
  }
}

/// Aviso de que el backend no responde.
///
/// Sin él, un servidor apagado se ve idéntico a una app sin novedades, y en una demo eso se
/// confunde con que está rota.
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

/// Las formas de viajar, dentro de la hoja blanca.
///
/// Sin tarjeta ni sombra propias: la hoja ya las pone. En el Figma cada renglón es icono, texto
/// y chevron, separados por una línea — [TravelOptionTile] es justo esa forma.
class _ModeMenu extends StatelessWidget {
  const _ModeMenu({
    required this.width,
    this.onCustomTrip,
    this.onTravelByBike,
    this.onTravelWalking,
    this.onTravelByCableCar,
  });

  final double width;
  final VoidCallback? onCustomTrip;
  final VoidCallback? onTravelByBike;
  final VoidCallback? onTravelWalking;
  final VoidCallback? onTravelByCableCar;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TravelOptionTile(
          asset: 'assets/icons/fastest.svg',
          label: 'Viaje personalizado...',
          width: width,
          iconDesignSize: 40,
          dense: true,
          onTap: onCustomTrip,
        ),
        const Divider(height: 1, color: AppColors.surfaceGrey),
        TravelOptionTile(
          asset: 'assets/icons/bicycle.svg',
          label: 'Viajar en bici...',
          width: width,
          iconDesignSize: 49,
          dense: true,
          onTap: onTravelByBike,
        ),
        const Divider(height: 1, color: AppColors.surfaceGrey),
        TravelOptionTile(
          asset: 'assets/icons/walk.svg',
          label: 'Viajar caminando...',
          width: width,
          iconDesignSize: 41,
          dense: true,
          onTap: onTravelWalking,
        ),
        const Divider(height: 1, color: AppColors.surfaceGrey),
        TravelOptionTile(
          asset: 'assets/icons/cable-car.svg',
          label: 'Viajar en teleférico...',
          width: width,
          iconDesignSize: 44,
          dense: true,
          onTap: onTravelByCableCar,
        ),
      ],
    );
  }
}
