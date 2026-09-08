import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models.dart';
import '../data/providers.dart';
import '../theme.dart';
import 'inputs.dart';

/// Hoja de una parada: cuánto falta para la unidad y la confirmación de abordaje.
///
/// Es el Escenario 2 de `CLAUDE.md` y el diferenciador del proyecto: la respuesta del pasajero
/// —"voy a abordar" o "solo paso"— es lo que genera la señal de demanda que el panel
/// institucional agrega, sin depender de GPS en las unidades.
///
/// No hay diseño de Figma para esta hoja todavía; está armada con los componentes que ya usan
/// las demás pantallas para que no desentone.
class StopSheet extends ConsumerStatefulWidget {
  const StopSheet({super.key, required this.stop, required this.routeId});

  final Stop stop;
  final int routeId;

  /// Abre la hoja y devuelve `true` si se registró una intención de abordar.
  static Future<bool?> show(
    BuildContext context, {
    required Stop stop,
    required int routeId,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StopSheet(stop: stop, routeId: routeId),
    );
  }

  @override
  ConsumerState<StopSheet> createState() => _StopSheetState();
}

class _StopSheetState extends ConsumerState<StopSheet> {
  bool _submitting = false;
  String? _error;

  Future<void> _declare(BoardingIntent intent) async {
    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final userId = await ref.read(demoUserIdProvider.future);
      await ref
          .read(apiClientProvider)
          .createBoardingSignal(
            userId: userId,
            stopId: widget.stop.id,
            routeId: widget.routeId,
            intent: intent,
          );

      // El servidor emite `demand:update` y el conteo llega por el canal en vivo, así que no
      // hace falta volver a pedirlo por REST.
      if (mounted) Navigator.of(context).pop(intent == BoardingIntent.boarding);
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'No pudimos registrar tu respuesta. $error');
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = math.min(
      MediaQuery.sizeOf(context).width,
      maxContentWidth,
    );
    final s = scaleFor(width);
    final gutter = gutterFor(width);
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    final eta = ref.watch(stopEtaProvider(widget.stop.id));
    final waiting =
        ref.watch(demandProvider).value?[widget.stop.id] ?? 0;

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.sheet),
        ),
        boxShadow: AppShadows.sheet,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: maxContentWidth),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  gutter,
                  22 * s,
                  gutter,
                  24 * s + bottomInset,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 5,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceGrey,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                    SizedBox(height: 18 * s),
                    Text(
                      widget.stop.name,
                      style: TextStyle(
                        fontFamily: AppFonts.headline,
                        fontFamilyFallback: AppFonts.headlineFallback,
                        fontSize: fluid(width, designSize: 26, min: 20, max: 29),
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    ),
                    SizedBox(height: 12 * s),
                    _EtaLine(eta: eta, width: width),
                    SizedBox(height: 8 * s),
                    _WaitingLine(count: waiting, width: width),
                    if (_error != null) ...[
                      SizedBox(height: 12 * s),
                      Text(
                        _error!,
                        style: TextStyle(
                          fontSize: fluid(
                            width,
                            designSize: 14,
                            min: 12,
                            max: 15,
                          ),
                          color: const Color(0xFFB3261E),
                        ),
                      ),
                    ],
                    SizedBox(height: 24 * s),
                    Text(
                      '¿Vas a abordar aquí?',
                      style: TextStyle(
                        fontFamily: AppFonts.button,
                        fontFamilyFallback: AppFonts.buttonFallback,
                        fontSize: fluid(width, designSize: 20, min: 16, max: 22),
                        color: Colors.black,
                      ),
                    ),
                    SizedBox(height: 14 * s),
                    PrimaryPillButton(
                      label: 'Voy a abordar',
                      width: width,
                      designHeight: 52,
                      onPressed:
                          _submitting
                              ? null
                              : () => _declare(BoardingIntent.boarding),
                    ),
                    SizedBox(height: 10 * s),
                    SizedBox(
                      height: math.max(52 * s, 48),
                      child: OutlinedButton(
                        onPressed:
                            _submitting
                                ? null
                                : () => _declare(BoardingIntent.passing),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.black,
                          side: const BorderSide(
                            color: AppColors.surfaceGrey,
                            width: 1.5,
                          ),
                          shape: const StadiumBorder(),
                        ),
                        child: Text(
                          'Solo paso',
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
                    SizedBox(height: 12 * s),
                    Text(
                      'Tu respuesta ayuda a saber dónde hacen falta más unidades.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: fluid(width, designSize: 13, min: 11, max: 14),
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Cuánto falta para que llegue la unidad.
class _EtaLine extends StatelessWidget {
  const _EtaLine({required this.eta, required this.width});

  final AsyncValue<StopEta?> eta;
  final double width;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontFamily: AppFonts.button,
      fontFamilyFallback: AppFonts.buttonFallback,
      fontSize: fluid(width, designSize: 20, min: 16, max: 22),
      color: Colors.black,
    );

    return eta.when(
      loading: () => Text('Calculando tiempo de llegada...', style: style),
      error:
          (_, _) =>
              Text('No pudimos calcular el tiempo de llegada', style: style),
      data: (value) {
        // Sin posición de la unidad no hay estimación posible, y eso es lo normal antes de
        // que el conductor arranque. Decirlo es mejor que mostrar un cero engañoso.
        if (value == null || !value.hasEstimate) {
          return Text('La unidad aún no reporta su posición', style: style);
        }

        final minutes = value.etaMinutes!;
        final label =
            minutes < 1
                ? 'Llega en menos de un minuto'
                : 'Llega en ${minutes.round()} min';
        final distance = value.distanceKm;

        return Text(
          distance == null
              ? label
              : '$label · a ${distance.toStringAsFixed(1)} km',
          style: style.copyWith(
            color: AppColors.green,
            fontWeight: FontWeight.w600,
          ),
        );
      },
    );
  }
}

/// Cuánta gente declaró que espera aquí.
class _WaitingLine extends StatelessWidget {
  const _WaitingLine({required this.count, required this.width});

  final int count;
  final double width;

  @override
  Widget build(BuildContext context) {
    final label = switch (count) {
      0 => 'Nadie ha dicho que espera aquí',
      1 => '1 persona esperando aquí',
      _ => '$count personas esperando aquí',
    };

    return Text(
      label,
      style: TextStyle(
        fontSize: fluid(width, designSize: 15, min: 13, max: 17),
        color: AppColors.muted,
      ),
    );
  }
}
