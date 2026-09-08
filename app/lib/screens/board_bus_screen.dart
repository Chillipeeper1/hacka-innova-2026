import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../data/providers.dart';
import '../data/trip_plan.dart';
import '../morelia.dart';
import '../theme.dart';
import '../widgets/trip_widgets.dart';

/// Esperar la unidad en la parada y subirse.
///
/// Tiene dos momentos, y el paso de uno a otro lo decide la posición de la unidad, no un botón:
///
/// 1. **Esperando** — el pasajero ve acercarse el camión y cuánto falta.
/// 2. **Pagando** — cuando la unidad está a menos de [busApproachingMeters], aparece
///    "Paga con tu tarjeta RFID". Si el pasajero pasa la tarjeta, se registra el tap. Si paga
///    con monedas no toca nada: la pantalla se quita sola en cuanto la unidad arranca y se
///    aleja de la parada, porque eso significa que ya va arriba.
///
/// No hay diseño de Figma para esta pantalla; está armada con los componentes del resto.
///
/// La detección de "pagó con monedas" es deliberadamente simple: se da por hecho que si la
/// unidad se fue y el pasajero había confirmado, subió. En producción se compararía la
/// velocidad del dispositivo con la de la unidad, pero `CLAUDE.md` descarta la detección por
/// sensores en esta fase.
class BoardBusScreen extends ConsumerStatefulWidget {
  const BoardBusScreen({
    super.key,
    this.onMenu,
    this.onProfile,
    this.onBoarded,
    this.onCancel,
  });

  final VoidCallback? onMenu;
  final VoidCallback? onProfile;
  final VoidCallback? onBoarded;
  final VoidCallback? onCancel;

  @override
  ConsumerState<BoardBusScreen> createState() => _BoardBusScreenState();
}

class _BoardBusScreenState extends ConsumerState<BoardBusScreen> {
  bool _submitting = false;
  String? _error;

  /// El pasajero pasó su tarjeta.
  Future<void> _payWithCard(int vehicleId) async {
    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final api = ref.read(apiClientProvider);
      final tapSignalId = await api.createCardTap(
        cardUid: demoCardUid,
        vehicleId: vehicleId,
      );

      // El tap crea su propia señal, así que la que se declaró en la parada dejaría de tener
      // sentido y seguiría contando como gente esperando. Se cierra para que el conteo de
      // demanda no quede inflado.
      final declared = ref.read(tripPlanProvider).boardingSignalId;
      if (declared != null && declared != tapSignalId) {
        await api.updateBoardingSignal(
          signalId: declared,
          status: 'expired',
        );
      }

      ref
          .read(tripPlanProvider.notifier)
          .markOnboard(method: PaymentMethod.card, signalId: tapSignalId);
      widget.onBoarded?.call();
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'No pudimos registrar tu tarjeta. $error');
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  /// La unidad arrancó sin que hubiera tap: pagó con monedas.
  Future<void> _boardWithCoins() async {
    final plan = ref.read(tripPlanProvider);
    final signalId = plan.boardingSignalId;
    if (signalId == null) return;

    try {
      await ref
          .read(apiClientProvider)
          .updateBoardingSignal(signalId: signalId, status: 'boarded');
    } catch (_) {
      // Que falle el cambio de estado no debe dejar al pasajero atorado en una pantalla de
      // pago mientras el camión ya avanza. El viaje sigue; el estado se corrige después.
    }

    if (!mounted) return;
    ref
        .read(tripPlanProvider.notifier)
        .markOnboard(method: PaymentMethod.coins);
    widget.onBoarded?.call();
  }

  @override
  Widget build(BuildContext context) {
    final plan = ref.watch(tripPlanProvider);
    final option = plan.chosen;

    if (option == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Abordar')),
        body: const Center(child: Text('No tienes un viaje en curso.')),
      );
    }

    final vehicle = ref.watch(tripVehicleProvider);
    final metersToStop = ref.watch(busDistanceToBoardingProvider);
    final arriving = ref.watch(busIsArrivingProvider);

    // Mientras el pasajero mira la pantalla de pago, la unidad puede arrancar. Eso es lo que
    // se interpreta como "pagó con monedas y ya va arriba".
    ref.listen(busDepartedStopProvider, (previous, departed) {
      if (!departed || _submitting) return;
      Future.microtask(() {
        if (!context.mounted || _submitting) return;
        final stage = ref.read(tripPlanProvider).stage;
        if (stage == TripStage.awaitingPayment ||
            stage == TripStage.waitingAtStop) {
          _boardWithCoins();
        }
      });
    });

    // Al acercarse la unidad, la pantalla pasa sola a pedir el pago.
    ref.listen(busIsArrivingProvider, (previous, isArriving) {
      if (!isArriving) return;
      Future.microtask(() {
        if (context.mounted) {
          ref.read(tripPlanProvider.notifier).markBusArrived();
        }
      });
    });

    final awaitingPayment =
        arriving || plan.stage == TripStage.awaitingPayment;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          _BoardingMap(option: option, vehicle: vehicle),
          if (awaitingPayment) const ColoredBox(color: AppColors.modalScrim),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = math.min(constraints.maxWidth, maxContentWidth);

              return Stack(
                children: [
                  MapTopControls(
                    width: width,
                    onMenu: widget.onMenu,
                    onProfile: widget.onProfile,
                    trailing: MapInfoCard(
                      width: width,
                      lines: ['Esperas en:', option.boardingStop.name],
                    ),
                  ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child:
                        awaitingPayment
                            ? _PaymentSheet(
                              width: width,
                              maxHeight: constraints.maxHeight,
                              busy: _submitting,
                              error: _error,
                              onTapCard:
                                  vehicle == null
                                      ? null
                                      : () => _payWithCard(vehicle.vehicleId),
                            )
                            : _WaitingSheet(
                              width: width,
                              maxHeight: constraints.maxHeight,
                              minutesToStop:
                                  metersToStop == null
                                      ? null
                                      : minutesForMeters(metersToStop),
                              onCancel: widget.onCancel,
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

/// Hoja mientras el camión viene en camino.
class _WaitingSheet extends StatelessWidget {
  const _WaitingSheet({
    required this.width,
    required this.maxHeight,
    required this.minutesToStop,
    this.onCancel,
  });

  final double width;
  final double maxHeight;

  /// Cuánto falta para que llegue la unidad. Se muestra en minutos: los metros no le dicen
  /// nada a quien espera parado en la banqueta.
  final int? minutesToStop;

  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final s = scaleFor(width);

    return TripSheet(
      width: width,
      maxHeight: maxHeight,
      maxHeightFactor: 0.4,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Esperando la unidad',
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
            // Sin posición de la unidad no hay distancia que mostrar, y eso es lo normal
            // antes de que el conductor arranque.
            label:
                minutesToStop == null
                    ? 'La unidad aún no reporta posición'
                    : 'La unidad llega en $minutesToStop min',
            background:
                minutesToStop == null
                    ? AppColors.fieldStrong
                    : AppColors.magenta,
            foreground: minutesToStop == null ? Colors.black : Colors.white,
          ),
          SizedBox(height: 14 * s),
          Text(
            'Cuando llegue te pediremos el pago.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: fluid(width, designSize: 15, min: 13, max: 17),
              color: AppColors.muted,
            ),
          ),
          SizedBox(height: 16 * s),
          Center(child: _CancelButton(width: width, onTap: onCancel)),
        ],
      ),
    );
  }
}

/// Hoja de pago: tarjeta o monedas.
class _PaymentSheet extends StatelessWidget {
  const _PaymentSheet({
    required this.width,
    required this.maxHeight,
    required this.busy,
    this.error,
    this.onTapCard,
  });

  final double width;
  final double maxHeight;
  final bool busy;
  final String? error;
  final VoidCallback? onTapCard;

  @override
  Widget build(BuildContext context) {
    final s = scaleFor(width);

    return TripSheet(
      width: width,
      maxHeight: maxHeight,
      maxHeightFactor: 0.55,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Paga con tu tarjeta RFID',
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
          Icon(
            Icons.contactless,
            size: 64 * s,
            color: AppColors.magenta,
          ),
          SizedBox(height: 14 * s),
          Text(
            'Acerca tu tarjeta al lector de la unidad.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppFonts.button,
              fontFamilyFallback: AppFonts.buttonFallback,
              fontSize: fluid(width, designSize: 20, min: 15, max: 22),
              color: Colors.black,
            ),
          ),
          SizedBox(height: 8 * s),
          Text(
            '¿Pagas con monedas? No hagas nada: en cuanto la unidad arranque, '
            'tu viaje empieza solo.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: fluid(width, designSize: 15, min: 12, max: 16),
              color: AppColors.muted,
            ),
          ),
          if (error != null) ...[
            SizedBox(height: 10 * s),
            Text(
              error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFFB3261E), fontSize: 13),
            ),
          ],
          SizedBox(height: 18 * s),
          SizedBox(
            height: math.max(48 * s, 48),
            child: FilledButton(
              onPressed: busy ? null : onTapCard,
              child:
                  busy
                      ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                      : Text(
                        'Pasar tarjeta',
                        style: TextStyle(
                          fontFamily: AppFonts.button,
                          fontFamilyFallback: AppFonts.buttonFallback,
                          fontSize: fluid(
                            width,
                            designSize: 24,
                            min: 17,
                            max: 25,
                          ),
                          color: Colors.white,
                        ),
                      ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Píldora gris de "cancelar", como en el diseño de viaje.
class _CancelButton extends StatelessWidget {
  const _CancelButton({required this.width, this.onTap});

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

/// Mapa con la parada y la unidad acercándose.
class _BoardingMap extends StatelessWidget {
  const _BoardingMap({required this.option, required this.vehicle});

  final BoardingOption option;
  final dynamic vehicle;

  @override
  Widget build(BuildContext context) {
    final routeColor = colorFromHex(option.route.colorHex);

    return FlutterMap(
      options: MapOptions(
        initialCenter: option.boardingStop.location,
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
              color: routeColor.withValues(alpha: 0.85),
              strokeWidth: 6,
            ),
          ],
        ),
        MarkerLayer(
          markers: [
            Marker(
              point: option.boardingStop.location,
              width: 38,
              height: 44,
              child: Semantics(
                container: true,
                label: 'Tu parada',
                child: SvgPicture.asset('assets/icons/pin-dark.svg'),
              ),
            ),
            if (vehicle != null)
              Marker(
                point: vehicle.location,
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
