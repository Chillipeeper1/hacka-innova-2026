import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../data/cable_car_network.dart';
import '../data/nearby_ads.dart';
import '../data/cable_car_trip.dart';
import '../morelia.dart';
import '../theme.dart';
import '../widgets/app_map.dart';
import '../widgets/inputs.dart';
import '../widgets/panic_button.dart';
import '../widgets/sponsored_places.dart';
import '../widgets/trip_widgets.dart';

/// Viaje en teleférico.
///
/// No hay diseño de Figma; sigue el patrón de las otras pantallas del viaje.
///
/// La hoja enseña **las dos estaciones y sus distancias**, no solo el nombre de la línea. Son
/// las dos preguntas que se hace quien va a subir —"¿qué tan lejos está?" y "¿qué tan cerca me
/// deja?"— y son justo lo que el sistema decidió por él.
class CableCarTripScreen extends ConsumerWidget {
  const CableCarTripScreen({
    super.key,
    this.onMenu,
    this.onProfile,
    this.onFinished,
    this.onCancel,
  });

  final VoidCallback? onMenu;
  final VoidCallback? onProfile;

  /// Se llama al terminar el viaje, ya sea porque llegó o porque lo abandonó.
  final VoidCallback? onFinished;

  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trip = ref.watch(cableCarTripProvider);

    if (trip.stage == CableStage.unreachable) {
      return _NoServiceScreen(onBack: onFinished ?? onCancel);
    }

    final plan = trip.plan;
    if (plan == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Teleférico')),
        body: const Center(child: Text('No tienes un viaje en curso.')),
      );
    }

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          _CableCarMap(trip: trip, plan: plan),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = math.min(constraints.maxWidth, maxContentWidth);

              return Stack(
                children: [
                  MapTopControls(
                    width: width,
                    onMenu: onMenu,
                    onProfile: onProfile,
                    panic: PanicButton(
                      width: width,
                      trip:
                          '${plan.line.name}, hacia la estación '
                          '${plan.alighting.name}',
                    ),
                  ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: _CableCarSheet(
                      width: width,
                      maxHeight: constraints.maxHeight,
                      trip: trip,
                      plan: plan,
                      onFinished: onFinished,
                      onCancel: onCancel,
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

/// Cuando ninguna línea sirve.
///
/// Se dice, en vez de mandar a una pantalla vacía o inventar una estación lejana: el
/// teleférico cubre lo que cubre, y fingir lo contrario haría caminar dos kilómetros para nada.
class _NoServiceScreen extends StatelessWidget {
  const _NoServiceScreen({this.onBack});

  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = math.min(constraints.maxWidth, maxContentWidth);
              final s = scaleFor(width);

              return SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: gutterFor(width),
                  vertical: 24 * s,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SvgPicture.asset(
                      'assets/icons/cable-car.svg',
                      width: 64 * s,
                      height: 64 * s,
                    ),
                    SizedBox(height: 20 * s),
                    Text(
                      'Sin ruta en teleférico',
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
                    SizedBox(height: 12 * s),
                    Text(
                      'Ninguna línea te deja más cerca de tu destino, o no hay '
                      'estación a distancia caminable. Prueba en bici, '
                      'caminando o en camión.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: fluid(
                          width,
                          designSize: 15,
                          min: 13,
                          max: 17,
                        ),
                        color: AppColors.muted,
                        height: 1.35,
                      ),
                    ),
                    SizedBox(height: 24 * s),
                    PrimaryPillButton(
                      label: 'Volver',
                      width: width,
                      designHeight: 44,
                      onPressed: onBack,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Mapa con la línea completa, las dos estaciones elegidas y los tramos a pie.
class _CableCarMap extends StatelessWidget {
  const _CableCarMap({required this.trip, required this.plan});

  final CableCarTrip trip;
  final CableCarPlan plan;

  @override
  Widget build(BuildContext context) {
    final rider = trip.position;
    final lineColor = colorFromHex(plan.line.colorHex);

    return AppMap(
      initialCenter: rider ?? Morelia.center,
      initialZoom: 14,
      fitTo: plan.points,
      lines: [
        // La línea completa, tenue: sitúa el viaje dentro de la red en vez de dejarlo
        // flotando entre dos puntos.
        MapLine(
          id: 'linea',
          points: [for (final station in plan.line.stations) station.location],
          color: lineColor.withValues(alpha: 0.28),
          width: 5,
        ),
        for (final (index, leg) in plan.legs.indexed)
          MapLine(
            id: 'tramo-$index',
            points: leg.points,
            color: leg.mode == CableLegMode.cable
                ? lineColor
                : AppColors.walkPath,
            width: leg.mode == CableLegMode.cable ? 8 : 6,
          ),
      ],
      markers: [
        // Al llegar, y solo al llegar: mientras el viaje sigue el mapa es para llegar.
        if (trip.stage == CableStage.arrived && trip.destination != null)
          ...sponsoredMarkers(context, adsAround(trip.destination!)),
        for (final (index, station) in plan.line.stations.indexed)
          MapMarker(
            id: 'estacion-$index',
            point: station.location,
            icon: DotMapIcon(
              fill: Colors.white,
              border: lineColor,
              diameter: 18,
            ),
            semanticLabel: station.name,
          ),
        MapMarker(
          id: 'subida',
          point: plan.boarding.location,
          icon: LabelMapIcon(
            text: 'Subes: ${plan.boarding.name}',
            background: lineColor,
            fontSize: 12,
          ),
          semanticLabel: 'Subes en ${plan.boarding.name}',
        ),
        MapMarker(
          id: 'bajada',
          point: plan.alighting.location,
          icon: LabelMapIcon(
            text: 'Bajas: ${plan.alighting.name}',
            background: lineColor,
            fontSize: 12,
          ),
          semanticLabel: 'Bajas en ${plan.alighting.name}',
        ),
        if (trip.destination != null)
          MapMarker(
            id: 'destino',
            point: trip.destination!,
            icon: const SvgMapIcon('assets/icons/flag.svg'),
            semanticLabel: 'Tu destino',
          ),
        if (rider != null)
          MapMarker(
            id: 'pasajero',
            point: rider,
            icon: CircledSvgMapIcon(
              'assets/icons/cable-car.svg',
              border: lineColor,
            ),
            semanticLabel: 'Vas aquí',
          ),
      ],
    );
  }
}

/// Hoja inferior: en qué tramo va, cuánto falta y las dos estaciones.
class _CableCarSheet extends StatelessWidget {
  const _CableCarSheet({
    required this.width,
    required this.maxHeight,
    required this.trip,
    required this.plan,
    this.onFinished,
    this.onCancel,
  });

  final double width;
  final double maxHeight;
  final CableCarTrip trip;
  final CableCarPlan plan;
  final VoidCallback? onFinished;
  final VoidCallback? onCancel;

  String _phase() {
    if (trip.stage == CableStage.arrived) return 'Llegaste';

    final index = plan.legIndexAt(trip.traveledMeters);
    if (plan.legs[index].mode == CableLegMode.cable) return 'En el teleférico';
    return index == 0 ? 'Caminando a la estación' : 'Caminando a tu destino';
  }

  @override
  Widget build(BuildContext context) {
    final s = scaleFor(width);
    final arrived = trip.stage == CableStage.arrived;

    return TripSheet(
      width: width,
      maxHeight: maxHeight,
      maxHeightFactor: 0.72,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _phase(),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppFonts.headline,
              fontFamilyFallback: AppFonts.headlineFallback,
              fontSize: fluid(width, designSize: 24, min: 19, max: 27),
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
          SizedBox(height: 14 * s),
          InfoPill(
            width: width,
            label: arrived
                ? 'Viaje terminado'
                : 'Tiempo estimado: ${trip.remainingMinutes} min',
            background: arrived ? AppColors.green : AppColors.magenta,
          ),
          SizedBox(height: 14 * s),
          if (trip.destination case final destination?) ...[
            TripDestinationLine.at(
              width: width,
              label: arrived ? 'Llegaste a' : 'Vas hacia',
              point: destination,
              asset: 'assets/icons/cable-car.svg',
            ),
            SizedBox(height: 14 * s),
          ],
          _StationRow(
            width: width,
            color: colorFromHex(plan.line.colorHex),
            title: 'Subes en ${plan.boarding.name}',
            detail:
                'La estación más cercana a ti · '
                '${_distanceLabel(plan.metersToBoarding)} a pie',
          ),
          SizedBox(height: 10 * s),
          _StationRow(
            width: width,
            color: colorFromHex(plan.line.colorHex),
            title: 'Bajas en ${plan.alighting.name}',
            detail:
                'La que te deja más cerca · '
                '${_distanceLabel(plan.metersFromAlightingToDestination)} '
                'de tu destino',
          ),
          SizedBox(height: 10 * s),
          Text(
            '${plan.line.name} · estaciones simuladas para la demo.',
            style: TextStyle(
              fontSize: fluid(width, designSize: 12, min: 11, max: 13),
              color: AppColors.muted,
              fontStyle: FontStyle.italic,
            ),
          ),
          SizedBox(height: 16 * s),
          if (arrived)
            PrimaryPillButton(
              label: 'Terminar',
              width: width,
              designHeight: 44,
              onPressed: onFinished,
            )
          else
            Center(
              child: CancelPill(width: width, onTap: onCancel),
            ),
        ],
      ),
    );
  }
}

String _distanceLabel(double meters) => meters >= 1000
    ? '${(meters / 1000).toStringAsFixed(1)} km'
    : '${meters.round()} m';

/// Un renglón de estación: por qué se eligió y a qué distancia queda.
class _StationRow extends StatelessWidget {
  const _StationRow({
    required this.width,
    required this.color,
    required this.title,
    required this.detail,
  });

  final double width;
  final Color color;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final s = scaleFor(width);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 14 * s,
          height: 14 * s,
          margin: EdgeInsets.only(top: 4 * s, right: 10 * s),
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontFamily: AppFonts.button,
                  fontFamilyFallback: AppFonts.buttonFallback,
                  fontSize: fluid(width, designSize: 16, min: 13, max: 18),
                  color: Colors.black,
                ),
              ),
              Text(
                detail,
                style: TextStyle(
                  fontSize: fluid(width, designSize: 13, min: 11, max: 14),
                  color: AppColors.muted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
