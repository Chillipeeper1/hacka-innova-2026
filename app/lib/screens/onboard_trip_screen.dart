import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models.dart';
import '../data/trip_plan.dart';
import '../theme.dart';
import '../widgets/app_map.dart';
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

    final minutesLeft = metersLeft == null
        ? null
        : minutesForMeters(metersLeft);

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
                            minutes: minutesLeft,
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
                            label: minutesLeft == null
                                ? 'Calculando lo que falta...'
                                : 'Llegada estimada: $minutesLeft min',
                            background: minutesLeft == null
                                ? AppColors.fieldStrong
                                : AppColors.magenta,
                            foreground: minutesLeft == null
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
                            child: CancelPill(width: width, onTap: onCancel),
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
    required this.minutes,
  });

  final double width;
  final String stopName;
  final int? minutes;

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
          padding: EdgeInsets.symmetric(horizontal: 20 * s, vertical: 16 * s),
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
                      minutes == null
                          ? stopName
                          : '$stopName · en $minutes min',
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

/// Mapa del trayecto: lo recorrido en azul, lo que falta en el color de la ruta.
class _OnboardMap extends StatelessWidget {
  const _OnboardMap({required this.option, required this.vehicle});

  final BoardingOption option;
  final VehiclePosition? vehicle;

  @override
  Widget build(BuildContext context) {
    final routeColor = colorFromHex(option.route.colorHex);

    return AppMap(
      initialCenter: vehicle?.location ?? option.boardingStop.location,
      initialZoom: 15.5,
      lines: [
        MapLine(
          id: 'ruta',
          points: option.route.shape,
          color: routeColor.withValues(alpha: 0.7),
        ),
        // El tramo ya recorrido, en el azul del diseño.
        if (vehicle != null)
          MapLine(
            id: 'recorrido',
            points: [option.boardingStop.location, vehicle!.location],
            color: AppColors.walkPath,
            width: 8,
          ),
      ],
      markers: [
        MapMarker(
          id: 'bajada',
          point: option.alightingStop.location,
          icon: const SvgMapIcon(
            'assets/icons/flag.svg',
            width: 38,
            height: 40,
          ),
          semanticLabel: 'Bajas en ${option.alightingStop.name}',
        ),
        if (vehicle != null)
          MapMarker(
            id: 'unidad',
            point: vehicle!.location,
            icon: CircledSvgMapIcon('assets/icons/bus.svg', border: routeColor),
            semanticLabel: 'Vas aquí',
          ),
      ],
    );
  }
}
