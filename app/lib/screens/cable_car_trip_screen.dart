import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:latlong2/latlong.dart';

import '../data/cable_car_network.dart';
import '../data/cable_car_trip.dart';
import '../morelia.dart';
import '../theme.dart';
import '../widgets/inputs.dart';
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

    final arrived = trip.stage == CableStage.arrived;

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
                    trailing: MapInfoCard(
                      width: width,
                      asset: 'assets/icons/cable-car.svg',
                      lines: [
                        arrived ? 'Llegaste a:' : 'Vas hacia:',
                        _formatPoint(trip.destination),
                      ],
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

String _formatPoint(LatLng? point) {
  if (point == null) return 'tu destino';
  return '${point.latitude.toStringAsFixed(5)}, '
      '${point.longitude.toStringAsFixed(5)}';
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

    return FlutterMap(
      options: MapOptions(
        initialCenter: rider ?? Morelia.center,
        initialZoom: 14,
        minZoom: Morelia.minZoom,
        maxZoom: Morelia.maxZoom,
        initialCameraFit: CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(plan.points),
          padding: const EdgeInsets.fromLTRB(48, 190, 48, 280),
        ),
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
            // La línea completa, tenue: sitúa el viaje dentro de la red en vez de dejarlo
            // flotando entre dos puntos.
            Polyline(
              points: [
                for (final station in plan.line.stations) station.location,
              ],
              color: lineColor.withValues(alpha: 0.28),
              strokeWidth: 5,
            ),
            for (final leg in plan.legs)
              Polyline(
                points: leg.points,
                color: leg.mode == CableLegMode.cable
                    ? lineColor
                    : AppColors.walkPath,
                strokeWidth: leg.mode == CableLegMode.cable ? 8 : 6,
              ),
          ],
        ),
        MarkerLayer(
          markers: [
            for (final station in plan.line.stations)
              Marker(
                point: station.location,
                width: 18,
                height: 18,
                child: _StationDot(color: lineColor),
              ),
            Marker(
              point: plan.boarding.location,
              width: 190,
              height: 34,
              child: _StationBadge(
                label: 'Subes: ${plan.boarding.name}',
                color: lineColor,
              ),
            ),
            Marker(
              point: plan.alighting.location,
              width: 190,
              height: 34,
              child: _StationBadge(
                label: 'Bajas: ${plan.alighting.name}',
                color: lineColor,
              ),
            ),
            if (trip.destination != null)
              Marker(
                point: trip.destination!,
                width: 38,
                height: 40,
                child: Semantics(
                  container: true,
                  label: 'Tu destino',
                  child: SvgPicture.asset('assets/icons/flag.svg'),
                ),
              ),
            if (rider != null)
              Marker(
                point: rider,
                width: 40,
                height: 40,
                child: _RiderMarker(color: lineColor),
              ),
          ],
        ),
      ],
    );
  }
}

class _StationDot extends StatelessWidget {
  const _StationDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 3),
      ),
    );
  }
}

/// Etiqueta de una de las dos estaciones elegidas.
///
/// Sin `Semantics` encima: el texto visible ya es la etiqueta. En [FittedBox] porque un
/// marcador tiene tamaño fijo en píxeles del mapa.
class _StationBadge extends StatelessWidget {
  const _StationBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(AppRadius.floatingCard),
            boxShadow: AppShadows.floatingCard,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RiderMarker extends StatelessWidget {
  const _RiderMarker({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'Vas aquí',
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
          child: SvgPicture.asset('assets/icons/cable-car.svg'),
        ),
      ),
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
      maxHeightFactor: 0.55,
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
