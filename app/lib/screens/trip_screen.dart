import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../data/models.dart';
import '../data/providers.dart';
import '../data/trip_plan.dart';
import '../morelia.dart';
import '../theme.dart';
import '../widgets/trip_widgets.dart';

/// El viaje en curso: la ruta completa y dónde viene la unidad.
///
/// No tiene diseño de Figma todavía; está armada con los mismos componentes que el resto.
///
/// Incluye el botón de "Ya me bajé", que cierra la señal con `PATCH /boarding-signals/:id`.
/// Sin eso el servidor la libera solo tras un tiempo simulado y el viaje nunca registra su
/// duración real — que es justamente el dato que hoy no existe para las rutas de Morelia.
class TripScreen extends ConsumerStatefulWidget {
  const TripScreen({
    super.key,
    this.onMenu,
    this.onProfile,
    this.onFinished,
  });

  final VoidCallback? onMenu;
  final VoidCallback? onProfile;

  /// Se llama cuando el viaje quedó cerrado.
  final VoidCallback? onFinished;

  @override
  ConsumerState<TripScreen> createState() => _TripScreenState();
}

class _TripScreenState extends ConsumerState<TripScreen> {
  bool _submitting = false;
  String? _error;

  Future<void> _alight(int signalId) async {
    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await ref
          .read(apiClientProvider)
          .updateBoardingSignal(signalId: signalId, status: 'alighted');
      ref.read(tripPlanProvider.notifier).reset();
      widget.onFinished?.call();
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'No pudimos cerrar el viaje. $error');
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final plan = ref.watch(tripPlanProvider);
    final option = plan.chosen;

    if (option == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Tu viaje')),
        body: const Center(child: Text('No tienes un viaje en curso.')),
      );
    }

    final vehicles = ref.watch(vehiclePositionsProvider);
    final vehicle = vehicles[option.route.id];
    final eta = ref.watch(stopEtaProvider(option.boardingStop.id));

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          _TripMap(option: option, vehicle: vehicle),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = math.min(constraints.maxWidth, maxContentWidth);
              final s = scaleFor(width);

              return Stack(
                children: [
                  MapTopControls(
                    width: width,
                    onMenu: widget.onMenu,
                    onProfile: widget.onProfile,
                    trailing: MapInfoCard(
                      width: width,
                      lines: ['Vas hacia:', option.alightingStop.name],
                    ),
                  ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: TripSheet(
                      width: width,
                      maxHeight: constraints.maxHeight,
                      maxHeightFactor: 0.5,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          InfoPill(
                            width: width,
                            label:
                                vehicle == null
                                    ? 'La unidad aún no reporta posición'
                                    : eta.value?.etaMinutes == null
                                    ? 'Unidad en ruta'
                                    : 'Llega en ${eta.value!.etaMinutes!.round()} min',
                            background:
                                vehicle == null
                                    ? AppColors.fieldStrong
                                    : AppColors.magenta,
                            foreground:
                                vehicle == null ? Colors.black : Colors.white,
                          ),
                          SizedBox(height: 16 * s),
                          Text(
                            'Vas en la ${option.route.name}',
                            style: TextStyle(
                              fontFamily: AppFonts.button,
                              fontFamilyFallback: AppFonts.buttonFallback,
                              fontSize: fluid(
                                width,
                                designSize: 20,
                                min: 15,
                                max: 22,
                              ),
                              color: Colors.black,
                            ),
                          ),
                          SizedBox(height: 6 * s),
                          Text(
                            'Bájate en ${option.alightingStop.name} — de ahí caminas '
                            '${option.metersFromAlightingToDestination.round()} m.',
                            style: TextStyle(
                              fontSize: fluid(
                                width,
                                designSize: 15,
                                min: 13,
                                max: 17,
                              ),
                              color: AppColors.muted,
                            ),
                          ),
                          if (_error != null) ...[
                            SizedBox(height: 10 * s),
                            Text(
                              _error!,
                              style: const TextStyle(
                                color: Color(0xFFB3261E),
                                fontSize: 13,
                              ),
                            ),
                          ],
                          SizedBox(height: 18 * s),
                          SizedBox(
                            height: math.max(48 * s, 48),
                            child: OutlinedButton(
                              onPressed:
                                  _submitting || plan.boardingSignalId == null
                                      ? null
                                      : () => _alight(plan.boardingSignalId!),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.black,
                                side: const BorderSide(
                                  color: AppColors.surfaceGrey,
                                  width: 1.5,
                                ),
                                shape: const StadiumBorder(),
                              ),
                              child: Text(
                                _submitting ? 'Cerrando...' : 'Ya me bajé',
                                style: TextStyle(
                                  fontFamily: AppFonts.button,
                                  fontFamilyFallback: AppFonts.buttonFallback,
                                  fontSize: fluid(
                                    width,
                                    designSize: 20,
                                    min: 16,
                                    max: 22,
                                  ),
                                ),
                              ),
                            ),
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

/// Mapa del viaje: la ruta completa, sus paradas y la unidad.
class _TripMap extends StatelessWidget {
  const _TripMap({required this.option, required this.vehicle});

  final BoardingOption option;
  final VehiclePosition? vehicle;

  @override
  Widget build(BuildContext context) {
    final routeColor = colorFromHex(option.route.colorHex);

    return FlutterMap(
      options: MapOptions(
        initialCenter: option.boardingStop.location,
        initialZoom: 14.5,
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
              color: routeColor.withValues(alpha: 0.85),
              strokeWidth: 6,
            ),
          ],
        ),
        MarkerLayer(
          markers: [
            for (final stop in option.route.stops)
              Marker(
                point: stop.location,
                width: 20,
                height: 20,
                child: Container(
                  decoration: BoxDecoration(
                    color: routeColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2.5),
                  ),
                ),
              ),
            Marker(
              point: option.boardingStop.location,
              width: 38,
              height: 44,
              child: Semantics(
                container: true,
                label: 'Subes en ${option.boardingStop.name}',
                child: SvgPicture.asset('assets/icons/pin-dark.svg'),
              ),
            ),
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
                  label: 'Unidad en ruta',
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
