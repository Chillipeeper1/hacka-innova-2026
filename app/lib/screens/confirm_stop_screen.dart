import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/providers.dart';
import '../data/trip_plan.dart';
import '../morelia.dart';
import '../theme.dart';
import '../widgets/stop_confirmation.dart';
import '../widgets/trip_widgets.dart';

/// Revisar la parada elegida antes de echarse a caminar.
///
/// Usa el diseño de Figma "HACKA" nodo 32:634. Lo que importa aquí es la línea de **qué tan
/// lejos de tu destino te deja**: es el dato con el que se decide si vale la pena esa opción, y
/// el que no se puede corregir una vez arriba del camión.
class ConfirmStopScreen extends ConsumerWidget {
  const ConfirmStopScreen({
    super.key,
    this.onMenu,
    this.onProfile,
    this.onBack,
    this.onConfirm,
  });

  final VoidCallback? onMenu;
  final VoidCallback? onProfile;
  final VoidCallback? onBack;
  final VoidCallback? onConfirm;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final option = ref.watch(tripPlanProvider).chosen;

    if (option == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Confirmar parada')),
        body: const Center(child: Text('No has elegido una parada.')),
      );
    }

    final eta = ref.watch(stopEtaProvider(option.boardingStop.id));

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          _ConfirmMap(option: option),

          // El velo del diseño: atenúa el mapa para que la atención quede en la decisión.
          const ColoredBox(color: AppColors.modalScrim),

          LayoutBuilder(
            builder: (context, constraints) {
              final width = math.min(constraints.maxWidth, maxContentWidth);

              return Stack(
                children: [
                  MapTopControls(
                    width: width,
                    onMenu: onMenu,
                    onProfile: onProfile,
                    onBack: onBack ?? () => Navigator.maybePop(context),
                    trailing: MapInfoCard(
                      width: width,
                      lines: [
                        'Vas hacia la parada:',
                        option.boardingStop.name,
                      ],
                    ),
                  ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: StopConfirmation(
                      width: width,
                      maxHeight: constraints.maxHeight,
                      option: option,
                      title: '¿Confirmar parada?',
                      actionLabel: 'Confirmar',
                      etaMinutes: eta.value?.etaMinutes,
                      onConfirm: onConfirm,
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

class _ConfirmMap extends StatelessWidget {
  const _ConfirmMap({required this.option});

  final BoardingOption option;

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      options: MapOptions(
        initialCenter: option.boardingStop.location,
        initialZoom: 15,
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
        CircleLayer(
          circles: [
            CircleMarker(
              point: option.boardingStop.location,
              radius: 70 + option.waitingCount * 6,
              useRadiusInMeter: true,
              color: (option.isBusy
                      ? AppColors.crowdBusyArea
                      : AppColors.crowdFreeArea)
                  .withValues(alpha: option.isBusy ? 0.46 : 0.4),
              borderStrokeWidth: 0,
            ),
          ],
        ),
      ],
    );
  }
}
