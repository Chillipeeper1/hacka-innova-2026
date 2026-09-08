import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../data/providers.dart';
import '../data/trip_plan.dart';
import '../theme.dart';
import '../widgets/inputs.dart';

/// Fin del viaje: comentario y calificación.
///
/// Implementa el diseño de Figma ("HACKA", nodo 45:930). Es el Escenario 7 de `CLAUDE.md`.
///
/// **Se puede omitir.** El pasajero acaba de bajarse del camión, muchas veces con prisa;
/// obligarlo a calificar para poder seguir usando la app sería castigarlo por terminar su
/// viaje. El botón de arriba a la izquierda sale sin calificar.
///
/// El orden de las llamadas importa: `POST /trips/:id/rating` exige que la señal siga en estado
/// `boarded`, así que se califica **antes** de cerrarla como `alighted`.
class RatingScreen extends ConsumerStatefulWidget {
  const RatingScreen({super.key, this.onFinished});

  /// Se llama al terminar, tanto si calificó como si lo omitió.
  final VoidCallback? onFinished;

  @override
  ConsumerState<RatingScreen> createState() => _RatingScreenState();
}

class _RatingScreenState extends ConsumerState<RatingScreen> {
  final _comment = TextEditingController();
  int _rating = 0;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  /// Cierra el viaje. [rating] en cero significa que lo omitió.
  Future<void> _finish({required bool withRating}) async {
    setState(() {
      _submitting = true;
      _error = null;
    });

    final api = ref.read(apiClientProvider);
    final signalId = ref.read(tripPlanProvider).boardingSignalId;

    try {
      if (withRating && _rating > 0 && signalId != null) {
        await api.rateTrip(
          boardingSignalId: signalId,
          rating: _rating,
          comment: _comment.text,
        );
      }

      // Cerrar el viaje va después de calificar, y su fallo no debe atorar al pasajero: ya se
      // bajó, y el servidor libera la señal solo tras un tiempo de todos modos.
      if (signalId != null) {
        try {
          await api.updateBoardingSignal(
            signalId: signalId,
            status: 'alighted',
          );
        } catch (_) {
          // Sin consecuencia para el usuario.
        }
      }

      ref.read(tripPlanProvider.notifier).reset();
      widget.onFinished?.call();
    } catch (error) {
      if (mounted) {
        setState(
          () =>
              _error =
                  'No pudimos guardar tu calificación. Puedes omitirla. $error',
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = math.min(constraints.maxWidth, maxContentWidth);
            final s = scaleFor(width);
            final gutter = gutterFor(width);

            return Center(
              child: SizedBox(
                width: width,
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    gutter,
                    14 * s,
                    gutter,
                    28 * s + MediaQuery.viewPaddingOf(context).bottom,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: _SkipButton(
                          width: width,
                          onTap:
                              _submitting
                                  ? null
                                  : () => _finish(withRating: false),
                        ),
                      ),
                      SizedBox(height: 28 * s),
                      Text(
                        '¡Listo! Has llegado a tu destino',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: AppFonts.headline,
                          fontFamilyFallback: AppFonts.headlineFallback,
                          fontSize: fluid(
                            width,
                            designSize: 36,
                            min: 26,
                            max: 40,
                          ),
                          fontWeight: FontWeight.w700,
                          height: 1.1,
                          color: Colors.black,
                        ),
                      ),
                      SizedBox(height: 34 * s),
                      Text(
                        '¿Tienes algún comentario, queja o sugerencia? Escríbenos',
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
                      SizedBox(height: 14 * s),
                      _CommentBox(width: width, controller: _comment),
                      SizedBox(height: 26 * s),
                      Text(
                        'Califícanos',
                        textAlign: TextAlign.center,
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
                      SizedBox(height: 12 * s),
                      _Stars(
                        width: width,
                        value: _rating,
                        onChanged:
                            (value) => setState(() => _rating = value),
                      ),
                      if (_error != null) ...[
                        SizedBox(height: 14 * s),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFFB3261E),
                            fontSize: 13,
                          ),
                        ),
                      ],
                      SizedBox(height: 30 * s),
                      PrimaryPillButton(
                        label: _submitting ? 'Enviando...' : 'Confirmar',
                        width: width,
                        designHeight: 44,
                        // Sin estrellas no hay nada que enviar; el botón cierra igual, que es
                        // lo mismo que omitir.
                        onPressed:
                            _submitting
                                ? null
                                : () => _finish(withRating: _rating > 0),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Botón verde de la esquina: salir sin calificar.
class _SkipButton extends StatelessWidget {
  const _SkipButton({required this.width, this.onTap});

  final double width;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final s = scaleFor(width);

    return Semantics(
      button: true,
      label: 'Omitir la calificación',
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: AppShadows.circleButton,
        ),
        child: Material(
          color: AppColors.mint,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: SizedBox.square(
              dimension: 68 * s,
              child: Center(
                child: SvgPicture.asset(
                  'assets/icons/chevron-left.svg',
                  width: 32 * s,
                  height: 32 * s,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Caja de comentario libre.
class _CommentBox extends StatelessWidget {
  const _CommentBox({required this.width, required this.controller});

  final double width;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final s = scaleFor(width);
    final fontSize = fluid(width, designSize: 15, min: 13, max: 17);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20 * s, vertical: 14 * s),
      decoration: BoxDecoration(
        color: AppColors.surfaceGrey,
        borderRadius: BorderRadius.circular(AppRadius.floatingCard),
      ),
      child: TextField(
        controller: controller,
        maxLines: 6,
        minLines: 4,
        textCapitalization: TextCapitalization.sentences,
        style: TextStyle(fontSize: fontSize, color: Colors.black),
        decoration: InputDecoration(
          hintText: 'Escribe algo...',
          hintStyle: TextStyle(
            fontSize: fontSize,
            color: const Color(0xFFAFAFAF),
          ),
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.zero,
        ),
      ),
    );
  }
}

/// Las cinco estrellas.
class _Stars extends StatelessWidget {
  const _Stars({
    required this.width,
    required this.value,
    required this.onChanged,
  });

  final double width;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final s = scaleFor(width);
    final size = 40 * s;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var star = 1; star <= 5; star++)
          Semantics(
            button: true,
            label: '$star ${star == 1 ? 'estrella' : 'estrellas'}',
            selected: value >= star,
            child: InkResponse(
              onTap: () => onChanged(star),
              radius: size * 0.7,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 3 * s),
                child: Opacity(
                  // Las estrellas sin elegir van atenuadas: el diseño las dibuja todas
                  // negras, y así no se distingue la calificación dada.
                  opacity: value >= star ? 1 : 0.22,
                  child: SvgPicture.asset(
                    'assets/icons/star.svg',
                    width: size,
                    height: size,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
