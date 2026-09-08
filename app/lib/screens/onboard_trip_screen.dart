import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../data/models.dart';
import '../data/trip_plan.dart';
import '../morelia.dart';
import '../theme.dart';
import '../widgets/trip_widgets.dart';

/// "En viaje": el pasajero va a bordo.
///
/// Implementa el diseño de Figma ("HACKA", nodos 43:799 y 45:879 — son la misma pantalla en
/// dos momentos del recorrido, con el trazado azul avanzando).
///
/// El aviso de bajada aparece solo a [alightingWarningMeters] de la parada: es lo que evita
/// que el pasajero tenga que ir mirando el teléfono todo el trayecto.
class OnboardTripScreen extends ConsumerWidget {
  const OnboardTripScreen({
    super.key,
    this.onMenu,
    this.onProfile,
    this.onArrived,
    this.onCancel,
  });

  final VoidCallback? onMenu;
  final VoidCallback? onProfile;

  /// Se llama al llegar a la parada de bajada.
  final VoidCallback? onArrived;

  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = ref.watch(tripPlanProvider);
    final option = plan.chosen;

    if (option == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('En viaje')),
        body: const Center(child: Text('No tienes un viaje en curso.')),
      );
    }

    final vehicle = ref.watch(tripVehicleProvider);
    final metersLeft = ref.watch(metersToAlightingProvider);
    final nearAlighting = ref.watch(nearAlightingProvider);

    // Al llegar a la parada de bajada el viaje termina solo; el pasajero no tiene que avisar.
    ref.listen(atAlightingProvider, (previous, arrived) {
      if (!arrived) return;
      Future.microtask(() {
        if (!context.mounted) return;
        if (ref.read(tripPlanProvider).stage != TripStage.onboard) return;
        ref.read(tripPlanProvider.notifier).markArrivedAtDestination();
        onArrived?.call();
      });
    });

    // ~15 km/h, la misma velocidad promedio con la que el servidor calcula sus ETA.
    final minutesLeft =
        metersLeft == null ? null : math.max(1, (metersLeft / 250).round());

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          _OnboardMap(option: option, vehicle: vehicle),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = math.min(constraints.maxWidth, maxContentWidth);
              final s = scaleFor(width);

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
                        MapInfoCard(
                          width: width,
                          lines: ['Vas hacia:', option.alightingStop.name],
                        ),
                        if (nearAlighting) ...[
                          SizedBox(height: 12 * s),
                          _AlightingWarning(
                            width: width,
                            stopName: option.alightingStop.name,
                            meters: metersLeft,
                          ),
                        ],
                      ],
                    ),
                  ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: TripSheet(
                      width: width,
                      maxHeight: constraints.maxHeight,
                      maxHeightFactor: 0.42,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'En viaje',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: AppFonts.headline,
                              fontFamilyFallback: AppFonts.headlineFallback,
                              fontSize: fluid(
                                width,
                                designSize: 24,
                                min: 19,
                                max: 27,
                              ),
                              fontWeight: FontWeight.w700,
                              color: Colors.black,
                            ),
                          ),
                          SizedBox(height: 16 * s),
                          InfoPill(
                            width: width,
                            label:
                                minutesLeft == null
                                    ? 'Calculando lo que falta...'
                                    : 'Llegada estimada: $minutesLeft min',
                            background:
                                minutesLeft == null
                                    ? AppColors.fieldStrong
                                    : AppColors.magenta,
                            foreground:
                                minutesLeft == null
                                    ? Colors.black
                                    : Colors.white,
                          ),
                          SizedBox(height: 10 * s),
                          Text(
                            plan.paymentMethod == PaymentMethod.card
                                ? 'Pagaste con tarjeta · ${option.route.name}'
                                : 'Pagaste con monedas · ${option.route.name}',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: fluid(
                                width,
                                designSize: 15,
                                min: 12,
                                max: 16,
                              ),
                              color: AppColors.muted,
                            ),
                          ),
                          SizedBox(height: 14 * s),
                          Center(
                            child: _CancelPill(width: width, onTap: onCancel),
                          ),
                        ],
                      ),
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

/// Aviso anticipado de bajada.
///
/// Sale unos metros antes para que dé tiempo de acercarse a la puerta, que es la única razón
/// por la que este aviso existe.
class _AlightingWarning extends StatelessWidget {
  const _AlightingWarning({
    required this.width,
    required this.stopName,
    required this.meters,
  });

  final double width;
  final String stopName;
  final double? meters;

  @override
  Widget build(BuildContext context) {
    final s = scaleFor(width);

    return Semantics(
      container: true,
      liveRegion: true,
      label: 'Prepárate para bajar en $stopName',
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.floatingCard),
          boxShadow: AppShadows.floatingCard,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.mint,
            borderRadius: BorderRadius.circular(AppRadius.floatingCard),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: 20 * s,
            vertical: 16 * s,
          ),
          child: Row(
            children: [
              Icon(Icons.notifications_active, size: 26 * s),
              SizedBox(width: 14 * s),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Prepárate para bajar',
                      style: TextStyle(
                        fontFamily: AppFonts.button,
                        fontFamilyFallback: AppFonts.buttonFallback,
                        fontSize: fluid(
                          width,
                          designSize: 20,
                          min: 15,
                          max: 22,
                        ),
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                    Text(
                      meters == null
                          ? stopName
                          : '$stopName · a ${meters!.round()} m',
                      style: TextStyle(
                        fontSize: fluid(
                          width,
                          designSize: 15,
                          min: 12,
                          max: 16,
                        ),
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CancelPill extends StatelessWidget {
  const _CancelPill({required this.width, this.onTap});

  final double width;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final s = scaleFor(width);

    return SizedBox(
      width: 178 * s,
      height: math.max(44 * s, 44),
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          backgroundColor: AppColors.surfaceGrey,
          foregroundColor: Colors.black,
          shape: const StadiumBorder(),
        ),
        child: Text(
          'cancelar',
          style: TextStyle(
            fontFamily: AppFonts.button,
            fontFamilyFallback: AppFonts.buttonFallback,
            fontSize: fluid(width, designSize: 24, min: 16, max: 24),
          ),
        ),
      ),
    );
  }
}

/// Mapa del trayecto: lo recorrido en azul, lo que falta en el color de la ruta.
class _OnboardMap extends StatelessWidget {
  const _OnboardMap({required this.option, required this.vehicle});

  final BoardingOption option;
  final VehiclePosition? vehicle;

  @override
  Widget build(BuildContext context) {
    final routeColor = colorFromHex(option.route.colorHex);

    return FlutterMap(
      options: MapOptions(
        initialCenter: vehicle?.location ?? option.boardingStop.location,
        initialZoom: 15.5,
        minZoom: Morelia.minZoom,
        maxZoom: Morelia.maxZoom,
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
        PolylineLayer(
          polylines: [
            Polyline(
              points: option.route.shape,
              color: routeColor.withValues(alpha: 0.7),
              strokeWidth: 6,
            ),
            // El tramo ya recorrido, en el azul del diseño.
            if (vehicle != null)
              Polyline(
                points: [option.boardingStop.location, vehicle!.location],
                color: AppColors.walkPath,
                strokeWidth: 8,
              ),
          ],
        ),
        MarkerLayer(
          markers: [
            Marker(
              point: option.alightingStop.location,
              width: 38,
              height: 40,
              child: Semantics(
                container: true,
                label: 'Bajas en ${option.alightingStop.name}',
                child: SvgPicture.asset('assets/icons/flag.svg'),
              ),
            ),
            if (vehicle != null)
              Marker(
                point: vehicle!.location,
                width: 40,
                height: 40,
                child: Semantics(
                  container: true,
                  label: 'Vas aquí',
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: routeColor, width: 3),
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
                ),
              ),
          ],
        ),
      ],
    );
  }
}
