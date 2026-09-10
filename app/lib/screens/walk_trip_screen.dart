import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/walk_route.dart';
import '../data/nearby_ads.dart';
import '../data/walk_trip.dart';
import '../morelia.dart';
import '../theme.dart';
import '../widgets/app_map.dart';
import '../widgets/inputs.dart';
import '../widgets/panic_button.dart';
import '../widgets/sponsored_places.dart';
import '../widgets/trip_widgets.dart';

/// Viaje a pie, de punta a punta en una sola pantalla.
///
/// No hay diseño de Figma; sigue el patrón de las otras pantallas del viaje.
///
/// Las zonas marcadas se dibujan **siempre**, estorben o no al trazado. Enseñar solo las que se
/// rodearon dejaría creer que el resto del mapa fue revisado y salió limpio, que es justo lo
/// que estos datos no pueden sostener.
class WalkTripScreen extends ConsumerWidget {
  const WalkTripScreen({
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
    final trip = ref.watch(walkTripProvider);
    final route = trip.route;

    if (route == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('A pie')),
        body: const Center(child: Text('No tienes un viaje en curso.')),
      );
    }

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          _WalkTripMap(trip: trip, route: route),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = math.min(constraints.maxWidth, maxContentWidth);

              return Stack(
                children: [
                  MapTopControls(
                    width: width,
                    onMenu: onMenu,
                    onProfile: onProfile,
                    // La pantalla que ya rodea zonas marcadas es la que más necesita esto:
                    // rodearlas reduce el riesgo, no lo quita.
                    panic: PanicButton(
                      width: width,
                      trip: 'A pie, rumbo a su destino',
                    ),
                  ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: _WalkTripSheet(
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

/// Mapa con las zonas marcadas, el camino y quien camina.
class _WalkTripMap extends StatelessWidget {
  const _WalkTripMap({required this.trip, required this.route});

  final WalkTrip trip;
  final WalkRoute route;

  @override
  Widget build(BuildContext context) {
    final walker = trip.position;

    return AppMap(
      initialCenter: walker ?? Morelia.center,
      initialZoom: 15,
      // Encuadra el recorrido completo, para que el rodeo se entienda de un vistazo.
      fitTo: route.points,
      areas: [
        for (final (index, zone) in moreliaUnsafeZones.indexed)
          MapArea(
            id: 'zona-$index',
            center: zone.center,
            radiusMeters: zone.radiusMeters,
            fill: AppColors.unsafeZoneArea.withValues(alpha: 0.22),
            border: AppColors.unsafeZone.withValues(alpha: 0.75),
            borderWidth: 2,
          ),
      ],
      lines: [
        MapLine(
          id: 'camino',
          points: route.points,
          color: AppColors.walkPath,
          width: 7,
        ),
      ],
      markers: [
        // Al llegar, y solo al llegar: mientras el viaje sigue el mapa es para llegar.
        if (trip.stage == WalkStage.arrived && trip.destination != null)
          ...sponsoredMarkers(context, adsAround(trip.destination!)),
        for (final (index, zone) in moreliaUnsafeZones.indexed)
          MapMarker(
            id: 'etiqueta-zona-$index',
            point: zone.center,
            icon: LabelMapIcon(
              text: zone.reason,
              background: AppColors.unsafeZone,
              fontSize: 12,
            ),
            semanticLabel: 'Zona no recomendada: ${zone.reason}',
          ),
        if (trip.destination != null)
          MapMarker(
            id: 'destino',
            point: trip.destination!,
            icon: const SvgMapIcon('assets/icons/flag.svg'),
            semanticLabel: 'Tu destino',
          ),
        if (walker != null)
          MapMarker(
            id: 'peaton',
            point: walker,
            icon: const CircledSvgMapIcon(
              'assets/icons/walk.svg',
              border: AppColors.walkPath,
            ),
            semanticLabel: 'Vas aquí',
          ),
      ],
    );
  }
}

/// Hoja inferior: tiempo, qué se esquivó y la salida.
class _WalkTripSheet extends StatelessWidget {
  const _WalkTripSheet({
    required this.width,
    required this.maxHeight,
    required this.trip,
    required this.route,
    this.onFinished,
    this.onCancel,
  });

  final double width;
  final double maxHeight;
  final WalkTrip trip;
  final WalkRoute route;
  final VoidCallback? onFinished;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final s = scaleFor(width);
    final arrived = trip.stage == WalkStage.arrived;

    return TripSheet(
      width: width,
      maxHeight: maxHeight,
      maxHeightFactor: 0.58,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            arrived ? 'Llegaste' : 'A pie',
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
          SizedBox(height: 14 * s),
          if (trip.destination case final destination?) ...[
            TripDestinationLine.at(
              width: width,
              label: arrived ? 'Llegaste a' : 'Vas hacia',
              point: destination,
              asset: 'assets/icons/walk.svg',
            ),
            SizedBox(height: 14 * s),
          ],
          _SafetySummary(width: width, route: route),
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

/// Qué hizo el trazado con las zonas marcadas.
class _SafetySummary extends StatelessWidget {
  const _SafetySummary({required this.width, required this.route});

  final double width;
  final WalkRoute route;

  String _distanceLabel(double meters) => meters >= 1000
      ? '${(meters / 1000).toStringAsFixed(1)} km'
      : '${meters.round()} m';

  @override
  Widget build(BuildContext context) {
    final s = scaleFor(width);
    final zoneCount = route.zonesOnDirectPath.length;

    // Tres desenlaces distintos, y decir cuál es importa más que verse tranquilizador.
    final String headline;
    final String detail;
    final Color swatch;

    if (route.crossesUnsafeZone) {
      headline = 'Este camino cruza una zona no recomendada';
      detail =
          'No hay ruta que las evite. '
          '${_distanceLabel(route.totalMeters)} en total.';
      swatch = AppColors.unsafeZone;
    } else if (route.detoured) {
      final reasons = route.zonesOnDirectPath
          .map((zone) => zone.reason.toLowerCase())
          .join(' · ');
      headline = zoneCount == 1
          ? 'Camino seguro · rodea 1 zona'
          : 'Camino seguro · rodea $zoneCount zonas';
      detail =
          '$reasons. ${_distanceLabel(route.totalMeters)} en total, '
          '${_distanceLabel(route.extraMeters)} más que la línea recta.';
      swatch = AppColors.walkPath;
    } else {
      headline = 'Camino seguro · sin zonas marcadas de paso';
      detail = '${_distanceLabel(route.totalMeters)} en total.';
      swatch = AppColors.walkPath;
    }

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
                color: swatch,
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
        // TODO(seguridad): quitar este aviso cuando `moreliaUnsafeZones` traiga datos reales.
        Text(
          'Zonas simuladas para la demo.',
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
