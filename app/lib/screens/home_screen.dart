import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/providers.dart';
import '../data/trip_plan.dart';
import '../morelia.dart';
import '../theme.dart';
import '../widgets/app_map.dart';
import '../widgets/map_chrome.dart';
import '../widgets/trip_widgets.dart';

/// Pantalla principal del pasajero.
///
/// Implementa el diseño de Figma ("HACKA", nodo 17:284).
///
/// La tarjeta de arriba responde a "a dónde vas" con **el viaje más rápido**, que combina
/// modos y transbordos. La hoja de abajo es la anulación: para cuando el pasajero quiere ir en
/// bici aunque no sea lo más rápido. Ese es el reparto — arriba la recomendación, abajo la
/// elección — y por eso el camión vive en la hoja junto a los demás modos y no en la tarjeta.
///
/// El mapa arranca **limpio**: sin rutas ni paradas dibujadas. Mostrar todo el catálogo de
/// entrada satura la pantalla y no ayuda a decidir — las paradas que importan son las que
/// llevan a donde el usuario va, y eso no se sabe hasta que lo dice. El viaje empieza por el
/// destino; de ahí en adelante cada pantalla enseña solo lo que hace falta para el siguiente
/// paso.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({
    super.key,
    this.onMenu,
    this.onProfile,
    this.onFastestTrip,
    this.onTravelByBus,
    this.onTravelByBike,
    this.onTravelWalking,
    this.onTravelByCableCar,
  });

  final VoidCallback? onMenu;
  final VoidCallback? onProfile;

  /// La tarjeta de arriba: dime a dónde vas y te llevo por lo más rápido.
  final VoidCallback? onFastestTrip;

  final VoidCallback? onTravelByBus;
  final VoidCallback? onTravelByBike;
  final VoidCallback? onTravelWalking;
  final VoidCallback? onTravelByCableCar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const _MoreliaMap(),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = math.min(constraints.maxWidth, maxContentWidth);

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
                          label: '¿A dónde vas?',
                          onTap: onFastestTrip,
                        ),
                        const _BackendStatusBanner(),
                      ],
                    ),
                  ),

                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _TravelSheet(
                          width: width,
                          maxHeight: constraints.maxHeight,
                          onTravelByBus: onTravelByBus,
                          onTravelByBike: onTravelByBike,
                          onTravelWalking: onTravelWalking,
                          onTravelByCableCar: onTravelByCableCar,
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

/// El mapa, sin capas de datos.
///
/// Solo la posición del usuario. Las rutas y paradas aparecen más adelante en el flujo, cuando
/// ya se sabe cuáles son pertinentes.
class _MoreliaMap extends ConsumerWidget {
  const _MoreliaMap();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final position = ref.watch(userLocationProvider);

    return AppMap(
      initialCenter: Morelia.center,
      initialZoom: Morelia.defaultZoom,
      markers: [
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
/// Sin él, un servidor apagado se ve idéntico a un mapa sin novedades, y en una demo eso se
/// confunde con que la app está rota.
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
    this.onTravelByBus,
    this.onTravelByBike,
    this.onTravelWalking,
    this.onTravelByCableCar,
  });

  final double width;
  final double maxHeight;
  final VoidCallback? onTravelByBus;
  final VoidCallback? onTravelByBike;
  final VoidCallback? onTravelWalking;
  final VoidCallback? onTravelByCableCar;

  @override
  Widget build(BuildContext context) {
    return TripSheet(
      width: width,
      maxHeight: maxHeight,
      maxHeightFactor: 0.62,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TravelOptionTile(
            asset: 'assets/icons/bus.svg',
            label: 'Viajar en camión...',
            width: width,
            iconDesignSize: 40,
            onTap: onTravelByBus,
          ),
          const Divider(height: 1, color: AppColors.surfaceGrey),
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
          const Divider(height: 1, color: AppColors.surfaceGrey),
          TravelOptionTile(
            asset: 'assets/icons/cable-car.svg',
            label: 'Viajar en teleférico...',
            width: width,
            iconDesignSize: 44,
            onTap: onTravelByCableCar,
          ),
        ],
      ),
    );
  }
}
