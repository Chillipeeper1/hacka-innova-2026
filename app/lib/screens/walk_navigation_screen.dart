import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:latlong2/latlong.dart';

import '../data/models.dart';
import '../data/providers.dart';
import '../data/trip_plan.dart';
import '../data/walk_route.dart';
import '../theme.dart';
import '../widgets/app_map.dart';
import '../widgets/stop_confirmation.dart';
import '../widgets/trip_widgets.dart';

/// Camino a pie hacia la parada elegida.
///
/// Implementa el diseño de Figma ("HACKA", nodo 32:504). Al llegar cerca de la parada aparece
/// la confirmación de abordaje (nodo 32:634) sobre el mapa, sin que el usuario tenga que
/// buscarla — que es justo el momento en que trae el teléfono en la mano.
///
/// El trazado es una línea recta al punto. Dibujar la ruta real por las calles necesitaría un
/// motor de ruteo peatonal, y `CLAUDE.md` deja eso explícitamente fuera de esta fase.
class WalkNavigationScreen extends ConsumerStatefulWidget {
  const WalkNavigationScreen({
    super.key,
    this.onMenu,
    this.onProfile,
    this.onBack,
    this.onBoarded,
  });

  final VoidCallback? onMenu;
  final VoidCallback? onProfile;
  final VoidCallback? onBack;

  /// Se llama cuando el abordaje quedó registrado en el servidor.
  final VoidCallback? onBoarded;

  @override
  ConsumerState<WalkNavigationScreen> createState() =>
      _WalkNavigationScreenState();
}

class _WalkNavigationScreenState extends ConsumerState<WalkNavigationScreen> {
  bool _submitting = false;
  String? _error;

  Future<void> _confirmBoarding(BoardingOption option) async {
    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final userId = await ref.read(demoUserIdProvider.future);
      final signal = await ref
          .read(apiClientProvider)
          .createBoardingSignal(
            userId: userId,
            stopId: option.boardingStop.id,
            routeId: option.route.id,
            intent: BoardingIntent.boarding,
          );

      ref.read(tripPlanProvider.notifier).markWaitingAtStop(signal.id);
      widget.onBoarded?.call();
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'No pudimos registrar tu abordaje. $error');
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final plan = ref.watch(tripPlanProvider);
    final option = plan.chosen;
    final position = ref.watch(userLocationProvider);
    final arrived = ref.watch(hasArrivedProvider);

    if (option == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Ir a la parada')),
        body: const Center(child: Text('No has elegido una parada.')),
      );
    }

    final remaining = const Distance()(position, option.boardingStop.location);
    final minutes = minutesOnFoot(remaining);
    final eta = ref.watch(stopEtaProvider(option.boardingStop.id));

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          _WalkMap(option: option, position: position),

          if (arrived) const ColoredBox(color: AppColors.modalScrim),

          LayoutBuilder(
            builder: (context, constraints) {
              final width = math.min(constraints.maxWidth, maxContentWidth);

              return Stack(
                children: [
                  MapTopControls(
                    width: width,
                    onMenu: widget.onMenu,
                    onProfile: widget.onProfile,
                    onBack: widget.onBack,
                    trailing: MapInfoCard(
                      width: width,
                      lines: [
                        arrived ? 'Vas hacia:' : 'Vas hacia la parada:',
                        option.boardingStop.name,
                      ],
                    ),
                  ),

                  Align(
                    alignment: Alignment.bottomCenter,
                    child: arrived
                        ? StopConfirmation(
                            width: width,
                            maxHeight: constraints.maxHeight,
                            option: option,
                            title: '¿Confirmar parada?',
                            actionLabel: 'Confirmar',
                            etaMinutes: eta.value?.etaMinutes,
                            busy: _submitting,
                            onConfirm: () => _confirmBoarding(option),
                          )
                        : _WalkSheet(
                            width: width,
                            maxHeight: constraints.maxHeight,
                            minutes: minutes,
                          ),
                  ),

                  if (_error != null)
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Material(
                          color: Colors.transparent,
                          child: Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFFB3261E),
                              fontSize: 13,
                            ),
                          ),
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

/// Mapa con la caminata: origen, trazado y parada destino.
class _WalkMap extends StatelessWidget {
  const _WalkMap({required this.option, required this.position});

  final BoardingOption option;
  final LatLng position;

  @override
  Widget build(BuildContext context) {
    return AppMap(
      initialCenter: position,
      initialZoom: 16,
      lines: [
        MapLine(
          id: 'caminata',
          points: [position, option.boardingStop.location],
          color: AppColors.walkPath,
          width: 8,
        ),
      ],
      markers: [
        MapMarker(
          id: 'parada',
          point: option.boardingStop.location,
          icon: const SvgMapIcon(
            'assets/icons/pin-dark.svg',
            width: 40,
            height: 46,
          ),
          semanticLabel: 'Parada ${option.boardingStop.name}',
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

/// Hoja de la caminata: tiempo estimado y el recorrido de un vistazo.
class _WalkSheet extends StatelessWidget {
  const _WalkSheet({
    required this.width,
    required this.maxHeight,
    required this.minutes,
  });

  final double width;
  final double maxHeight;
  final int minutes;

  @override
  Widget build(BuildContext context) {
    final s = scaleFor(width);

    return TripSheet(
      width: width,
      maxHeight: maxHeight,
      maxHeightFactor: 0.35,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InfoPill(width: width, label: 'Tiempo estimado: $minutes min'),
          SizedBox(height: 18 * s),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SvgPicture.asset(
                'assets/icons/walk.svg',
                width: 42 * s,
                height: 42 * s,
              ),
              Expanded(
                child: Center(
                  child: SvgPicture.asset(
                    'assets/icons/dots.svg',
                    width: 38 * s,
                    height: 38 * s,
                  ),
                ),
              ),
              SvgPicture.asset(
                'assets/icons/pin-dark.svg',
                width: 34 * s,
                height: 40 * s,
              ),
            ],
          ),
          SizedBox(height: 10 * s),
          Text(
            'Te faltan $minutes ${minutes == 1 ? 'minuto' : 'minutos'} a pie.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: fluid(width, designSize: 15, min: 13, max: 17),
              color: AppColors.muted,
            ),
          ),
        ],
      ),
    );
  }
}
