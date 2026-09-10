import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/trip_plan.dart';
import '../morelia.dart';
import '../theme.dart';
import '../widgets/app_map.dart';
import '../widgets/trip_widgets.dart';

/// Elegir por qué parada subirse.
///
/// Implementa el diseño de Figma ("HACKA", nodo 32:392). Llega aquí después de declarar el
/// destino, y lista las opciones ordenadas por qué tan cerca del destino te dejan — que es lo
/// que de verdad importa, porque caminar de más al final, ya pagado el pasaje, se tolera mucho
/// peor que caminar de más al principio.
///
/// El mapa pinta un área de color alrededor de cada parada según cuánta gente declaró que
/// espera ahí: ámbar si está concurrida, verde si está despejada.
class StopPickerScreen extends ConsumerWidget {
  const StopPickerScreen({
    super.key,
    this.onMenu,
    this.onProfile,
    this.onBack,
    this.onChoose,
  });

  final VoidCallback? onMenu;
  final VoidCallback? onProfile;
  final VoidCallback? onBack;
  final void Function(BoardingOption option)? onChoose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = ref.watch(tripPlanProvider);
    final options = plan.options;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          _PickerMap(options: options, destination: plan.destination),
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
                    onBack: onBack ?? () => Navigator.maybePop(context),
                  ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: TripSheet(
                      width: width,
                      maxHeight: constraints.maxHeight,
                      maxHeightFactor: 0.5,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Paradas de bus cerca de ti',
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
                          if (options.isEmpty)
                            _EmptyState(width: width)
                          else
                            for (var i = 0; i < options.length; i++) ...[
                              if (i > 0)
                                const Divider(
                                  height: 1,
                                  color: AppColors.surfaceGrey,
                                ),
                              StopListTile(
                                width: width,
                                title: options[i].boardingStop.name,
                                waitingCount: options[i].waitingCount,
                                busy: options[i].isBusy,
                                subtitle: _subtitleFor(options[i]),
                                badge: ServiceBadge(
                                  width: width,
                                  mode: options[i].route.mode,
                                  color: colorFromHex(
                                    options[i].route.colorHex,
                                  ),
                                ),
                                onTap: () => onChoose?.call(options[i]),
                              ),
                            ],
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

  /// Qué tan lejos del destino te deja esta opción, y cuánto caminas para tomarla.
  ///
  /// Es la información que el usuario necesita para decidir, y la que el diseño no muestra: la
  /// lista sola no distingue una parada que te deja en la puerta de otra que te deja a un
  /// kilómetro.
  String _subtitleFor(BoardingOption option) {
    final drop = option.metersFromAlightingToDestination.round();
    final walk = option.metersToBoardingStop.round();
    final dropLabel = option.dropsClose
        ? 'Te deja a $drop m de tu destino'
        : 'Te deja a $drop m — algo lejos';
    return '$dropLabel · caminas $walk m hasta aquí';
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Text(
        'Ninguna de las rutas del catálogo te deja cerca de ese destino. '
        'Prueba con un punto más cercano al centro.',
        style: TextStyle(
          fontSize: fluid(width, designSize: 15, min: 13, max: 17),
          color: AppColors.muted,
        ),
      ),
    );
  }
}

/// Mapa con las áreas de aglomeración de cada parada candidata.
class _PickerMap extends StatelessWidget {
  const _PickerMap({required this.options, required this.destination});

  final List<BoardingOption> options;
  final dynamic destination;

  @override
  Widget build(BuildContext context) {
    return AppMap(
      initialCenter: options.isEmpty
          ? Morelia.center
          : options.first.boardingStop.location,
      initialZoom: 15,
      // El área crece con la gente que espera: de un vistazo se ve dónde hay fila.
      areas: [
        for (final option in options)
          MapArea(
            id: 'espera-${option.boardingStop.id}',
            center: option.boardingStop.location,
            radiusMeters: 70 + option.waitingCount * 6,
            fill:
                (option.isBusy
                        ? AppColors.crowdBusyArea
                        : AppColors.crowdFreeArea)
                    .withValues(alpha: option.isBusy ? 0.46 : 0.4),
          ),
      ],
      markers: [
        for (final option in options)
          MapMarker(
            id: 'parada-${option.boardingStop.id}',
            point: option.boardingStop.location,
            icon: DotMapIcon(
              fill: option.isBusy ? AppColors.crowdBusy : AppColors.crowdFree,
              diameter: 18,
              borderWidth: 2,
            ),
            semanticLabel: 'Parada ${option.boardingStop.name}',
          ),
      ],
    );
  }
}
