/// Confirmación de la parada elegida.
///
/// Implementa el diseño de Figma ("HACKA", nodo 32:634) y se usa en **dos momentos** del
/// flujo, porque la información que hay que revisar es la misma:
///
/// 1. Al elegir la parada, antes de caminar — "¿Es esta la que quieres?".
/// 2. Al llegar a la parada, antes de abordar — "¿Confirmas que subes aquí?".
///
/// La diferencia es el título y lo que hace el botón; el contenido no cambia.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../data/trip_plan.dart';
import '../theme.dart';
import 'trip_widgets.dart';

class StopConfirmation extends StatelessWidget {
  const StopConfirmation({
    super.key,
    required this.width,
    required this.option,
    required this.title,
    required this.actionLabel,
    required this.onConfirm,
    this.maxHeight,
    this.etaMinutes,
    this.busy = false,
  });

  final double width;
  final BoardingOption option;
  final String title;
  final String actionLabel;
  final VoidCallback? onConfirm;
  final double? maxHeight;

  /// Minutos estimados hasta que llegue la unidad, si el servidor los pudo calcular.
  final double? etaMinutes;

  /// Envío en curso: evita dobles confirmaciones.
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final s = scaleFor(width);

    return TripSheet(
      width: width,
      maxHeight: maxHeight,
      maxHeightFactor: 0.72,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppFonts.headline,
              fontFamilyFallback: AppFonts.headlineFallback,
              fontSize: fluid(width, designSize: 24, min: 19, max: 27),
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
          SizedBox(height: 18 * s),
          InfoPill(
            width: width,
            // Sin posición de la unidad no hay estimación, y eso es lo normal antes de que el
            // conductor arranque. Decirlo es mejor que enseñar un número inventado.
            label:
                etaMinutes == null
                    ? 'Llegada estimada: sin datos aún'
                    : 'Llegada estimada: ${etaMinutes!.round()} min',
            background: AppColors.fieldStrong,
            foreground: Colors.black,
          ),
          SizedBox(height: 20 * s),

          _SectionLabel(width: width, text: 'Estás en'),
          StopListTile(
            width: width,
            title: option.boardingStop.name,
            waitingCount: option.waitingCount,
            busy: option.isBusy,
          ),

          SizedBox(height: 8 * s),
          _SectionLabel(width: width, text: 'Vas hacia'),
          _DestinationRow(width: width, option: option),

          SizedBox(height: 20 * s),
          SizedBox(
            width: double.infinity,
            height: math.max(48 * s, 48),
            child: FilledButton(
              onPressed: busy ? null : onConfirm,
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
                        actionLabel,
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

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.width, required this.text});

  final double width;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        text,
        style: TextStyle(
          fontSize: fluid(width, designSize: 15, min: 13, max: 17),
          color: AppColors.muted,
        ),
      ),
    );
  }
}

/// Dónde termina el viaje y cuánto se camina desde ahí.
///
/// La distancia es el dato que decide si la parada elegida sirve, así que va explícita y no
/// escondida en un mapa.
class _DestinationRow extends StatelessWidget {
  const _DestinationRow({required this.width, required this.option});

  final double width;
  final BoardingOption option;

  @override
  Widget build(BuildContext context) {
    final s = scaleFor(width);
    final meters = option.metersFromAlightingToDestination.round();

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 12 * s),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 46 * s,
            child: Center(
              child: SvgPicture.asset(
                'assets/icons/flag.svg',
                width: 32 * s,
                height: 36 * s,
              ),
            ),
          ),
          SizedBox(width: 12 * s),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  option.alightingStop.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppFonts.button,
                    fontFamilyFallback: AppFonts.buttonFallback,
                    fontSize: fluid(width, designSize: 24, min: 17, max: 25),
                    color: Colors.black,
                  ),
                ),
                SizedBox(height: 6 * s),
                Text(
                  option.dropsClose
                      ? 'Te deja a $meters m de tu destino'
                      : 'Te deja a $meters m — vas a caminar un poco',
                  style: TextStyle(
                    fontSize: fluid(width, designSize: 15, min: 12, max: 16),
                    color:
                        option.dropsClose
                            ? AppColors.green
                            : AppColors.magentaDeep,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 4 * s),
                Text(
                  'Por la ${option.route.name}',
                  style: TextStyle(
                    fontSize: fluid(width, designSize: 15, min: 12, max: 16),
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
