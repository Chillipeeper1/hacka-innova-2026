import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../data/bike_network.dart';
import '../data/bike_trip.dart';
import '../morelia.dart';
import '../theme.dart';
import '../widgets/app_map.dart';
import '../widgets/inputs.dart';
import '../widgets/trip_widgets.dart';

/// Viaje en bici, de punta a punta en una sola pantalla.
///
/// No hay diseño de Figma para esta pantalla; sigue el patrón de las otras del viaje —mapa a
/// pantalla completa, controles arriba, hoja blanca abajo— para que no se sienta de otra app.
///
/// El trazado se dibuja en dos colores porque son dos cosas distintas: **verde** donde hay
/// ciclovía y **azul** donde toca compartir la calle. Pintarlo de un solo color escondería
/// justo lo que el modo promete.
class BikeTripScreen extends ConsumerWidget {
  const BikeTripScreen({
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
    final trip = ref.watch(bikeTripProvider);
    final route = trip.route;

    if (route == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('En bici')),
        body: const Center(child: Text('No tienes un viaje en curso.')),
      );
    }

    final arrived = trip.stage == BikeStage.arrived;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          _BikeMap(trip: trip, route: route),
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
                      asset: 'assets/icons/bicycle.svg',
                      lines: [
                        arrived ? 'Llegaste a:' : 'Vas hacia:',
                        _formatPoint(trip.destination),
                      ],
                    ),
                  ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: _BikeSheet(
                      width: width,
                      maxHeight: constraints.maxHeight,
                      trip: trip,
                      route: route,
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

/// Mapa con el recorrido, la etiqueta de la ciclovía y el ciclista.
class _BikeMap extends StatelessWidget {
  const _BikeMap({required this.trip, required this.route});

  final BikeTrip trip;
  final BikeRoute route;

  @override
  Widget build(BuildContext context) {
    final rider = trip.position;
    final laneAnchor = route.laneLabelAnchor;

    return AppMap(
      initialCenter: rider ?? Morelia.center,
      initialZoom: 15,
      // Encuadra el recorrido completo: lo que hay que entender de un vistazo es por dónde
      // va la línea, no dónde está la rueda delantera.
      fitTo: route.points,
      lines: [
        for (final (index, segment) in route.segments.indexed)
          MapLine(
            id: 'tramo-$index',
            points: segment.points,
            color: segment.onLane ? AppColors.green : AppColors.walkPath,
            width: segment.onLane ? 9 : 6,
          ),
      ],
      markers: [
        if (laneAnchor != null)
          MapMarker(
            id: 'etiqueta-ciclovia',
            point: laneAnchor,
            icon: const LabelMapIcon(
              text: 'Ruta por ciclovía',
              background: AppColors.green,
            ),
            semanticLabel: 'Ruta por ciclovía',
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
            id: 'ciclista',
            point: rider,
            icon: const CircledSvgMapIcon(
              'assets/icons/bicycle.svg',
              border: AppColors.green,
            ),
            semanticLabel: 'Vas aquí',
          ),
      ],
    );
  }
}

/// Hoja inferior: tiempo, resumen del trazado y la salida.
class _BikeSheet extends StatelessWidget {
  const _BikeSheet({
    required this.width,
    required this.maxHeight,
    required this.trip,
    required this.route,
    this.onFinished,
    this.onCancel,
  });

  final double width;
  final double maxHeight;
  final BikeTrip trip;
  final BikeRoute route;
  final VoidCallback? onFinished;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final s = scaleFor(width);
    final arrived = trip.stage == BikeStage.arrived;

    return TripSheet(
      width: width,
      maxHeight: maxHeight,
      maxHeightFactor: 0.46,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            arrived ? 'Llegaste' : 'En bici',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppFonts.headline,
              fontFamilyFallback: AppFonts.headlineFallback,
              fontSize: fluid(width, designSize: 24, min: 19, max: 27),
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
          SizedBox(height: 16 * s),
          InfoPill(
            width: width,
            label: arrived
                ? 'Viaje terminado'
                : 'Tiempo estimado: ${trip.remainingMinutes} min',
            background: arrived ? AppColors.green : AppColors.magenta,
          ),
          SizedBox(height: 12 * s),
          _RouteSummary(width: width, route: route),
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

/// Resumen del trazado: si va por ciclovía, por cuál, y cuánto del viaje va protegido.
class _RouteSummary extends StatelessWidget {
  const _RouteSummary({required this.width, required this.route});

  final double width;
  final BikeRoute route;

  String _distanceLabel(double meters) => meters >= 1000
      ? '${(meters / 1000).toStringAsFixed(1)} km'
      : '${meters.round()} m';

  @override
  Widget build(BuildContext context) {
    final s = scaleFor(width);

    // Sin ciclovía en el trazado no se puede decir "ruta por ciclovía": el modo prioriza la
    // infraestructura ciclista, pero cuando el destino queda lejos de la red, desviarse cuesta
    // más de lo que protege. Decirlo es más útil que fingir que siempre hay.
    final headline = route.usesLane
        ? 'Ruta por ciclovía · ${route.laneNames.join(' · ')}'
        : 'Ruta directa · no hay ciclovía de paso';

    final detail = route.usesLane
        ? '${_distanceLabel(route.totalMeters)} en total · '
              '${_distanceLabel(route.laneMeters)} por ciclovía '
              '(${(route.laneShare * 100).round()}%)'
        : '${_distanceLabel(route.totalMeters)} en total';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 14 * s,
              height: 14 * s,
              margin: EdgeInsets.only(top: 4 * s, right: 10 * s),
              decoration: BoxDecoration(
                color: route.usesLane ? AppColors.green : AppColors.walkPath,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            Expanded(
              child: Text(
                headline,
                style: TextStyle(
                  fontFamily: AppFonts.button,
                  fontFamilyFallback: AppFonts.buttonFallback,
                  fontSize: fluid(width, designSize: 16, min: 13, max: 18),
                  color: Colors.black,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 6 * s),
        Text(
          detail,
          style: TextStyle(
            fontSize: fluid(width, designSize: 14, min: 12, max: 15),
            color: AppColors.muted,
          ),
        ),
        SizedBox(height: 6 * s),
        // TODO(ciclovías): quitar este aviso cuando `moreliaBikeLanes` traiga datos reales.
        Text(
          'Ciclovías simuladas para la demo.',
          style: TextStyle(
            fontSize: fluid(width, designSize: 12, min: 11, max: 13),
            color: AppColors.muted,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }
}
