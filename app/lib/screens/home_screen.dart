import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/providers.dart';
import '../data/trip_plan.dart';
import '../morelia.dart';
import '../theme.dart';
import '../widgets/map_chrome.dart';
import '../widgets/trip_widgets.dart';

/// Pantalla principal del pasajero.
///
/// Implementa el diseño de Figma ("HACKA", nodo 17:284).
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
                          onTap: onSearchStop,
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

/// El mapa, sin capas de datos.
///
/// Solo la posición del usuario. Las rutas y paradas aparecen más adelante en el flujo, cuando
/// ya se sabe cuáles son pertinentes.
class _MoreliaMap extends ConsumerWidget {
  const _MoreliaMap();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final position = ref.watch(userLocationProvider);

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
        MarkerLayer(
          markers: [
            Marker(
              point: position,
              width: 22,
              height: 22,
              child: const _UserLocationDot(),
            ),
          ],
        ),
      ],
    );
  }
}

class _UserLocationDot extends StatelessWidget {
  const _UserLocationDot();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'Tu posición',
      child: Container(
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
      ),
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
    this.onTravelByBike,
    this.onTravelWalking,
  });

  final double width;
  final double maxHeight;
  final VoidCallback? onTravelByBike;
  final VoidCallback? onTravelWalking;

  @override
  Widget build(BuildContext context) {
    return TripSheet(
      width: width,
      maxHeight: maxHeight,
      maxHeightFactor: 0.55,
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
