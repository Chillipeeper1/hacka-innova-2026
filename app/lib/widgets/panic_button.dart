/// El botón de pánico que acompaña al viaje.
///
/// Un círculo rojo que hay que **sostener tres segundos**: el anillo se llena mientras el dedo
/// está encima y se vacía al soltarlo antes. Nada de diálogos de confirmación — meter una
/// pantalla que leer entre "necesito ayuda" y pedirla es exactamente lo que no debe pasar—, y
/// nada de un toque suelto, que en el fondo de una bolsa manda alertas que nadie pidió.
///
/// La alerta que dispara vive en `data/panic_alert.dart` y **es una demostración**: no sale
/// nada del teléfono. Las dos hojas de esta pantalla lo dicen en voz alta, con el mismo
/// criterio del resto del mockup.
///
/// Va en las pantallas de viaje y en ninguna más. Fuera de un viaje la alerta no tendría qué
/// contar: sin ruta, sin unidad y sin hora de llegada, "algo me pasó" no le sirve a quien lo
/// recibe.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/clock_format.dart';
import '../data/panic_alert.dart';
import '../theme.dart';
import 'inputs.dart';

class PanicButton extends ConsumerStatefulWidget {
  const PanicButton({super.key, required this.width, required this.trip});

  final double width;

  /// En qué viaje va quien lo toca, en una línea. Es lo que viaja dentro de la alerta, así
  /// que cada pantalla escribe la suya: la del camión nombra ruta y parada de bajada, la de
  /// bici dice que va en bici. Ver [PanicAlert.trip].
  final String trip;

  @override
  ConsumerState<PanicButton> createState() => _PanicButtonState();
}

class _PanicButtonState extends ConsumerState<PanicButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _hold = AnimationController(
    vsync: this,
    duration: panicHoldDuration,
    // Al soltar antes de tiempo el anillo se vacía rápido: quien soltó ya se arrepintió, y
    // ver el gesto deshacerse en tres segundos más se siente a que la app no obedece.
    reverseDuration: const Duration(milliseconds: 200),
  )..addStatusListener(_onHoldStatus);

  /// La alerta salió en este mismo apretón.
  ///
  /// El dedo que se levanta después de sostener sigue siendo un toque para el detector de
  /// gestos; sin esto, encima de la hoja de "alerta enviada" se abriría la que explica cómo
  /// se usa el botón.
  bool _firedOnThisPress = false;

  @override
  void dispose() {
    _hold.dispose();
    super.dispose();
  }

  void _onHoldStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    // Fuera del callback de la animación: [_fire] regresa el anillo a cero, y hacerlo aquí
    // mismo sería reentrar en la notificación que lo está llamando.
    Future.microtask(_fire);
  }

  void _fire() {
    if (!mounted) return;
    _firedOnThisPress = true;
    _hold.value = 0;
    HapticFeedback.heavyImpact();
    ref.read(panicAlertProvider.notifier).fire(widget.trip);
    showPanicSentSheet(context, width: widget.width);
  }

  void _pressDown() {
    if (ref.read(panicAlertProvider) != null) return;
    _firedOnThisPress = false;
    // Confirma con el tacto que el gesto empezó: quien lo usa de verdad no está mirando la
    // pantalla.
    HapticFeedback.selectionClick();
    _hold.forward();
  }

  /// Sin condiciones: un toque suelto levanta el dedo antes del primer cuadro, con el anillo
  /// todavía en cero pero la animación ya corriendo. Preguntar por el valor dejaría ese caso
  /// avanzando solo hasta dispararse, que es justo lo que el gesto largo evita.
  void _pressUp() => _hold.reverse();

  void _tapped() {
    final alert = ref.read(panicAlertProvider);
    if (alert != null) {
      // Con una alerta en curso el botón sirve para lo contrario: apagarla.
      showPanicSentSheet(context, width: widget.width);
      return;
    }
    if (_firedOnThisPress) return;
    showPanicHelpSheet(context, width: widget.width);
  }

  @override
  Widget build(BuildContext context) {
    final active = ref.watch(panicAlertProvider) != null;
    final s = scaleFor(widget.width);
    final diameter = math.max<double>(68 * s, 60);

    return Semantics(
      button: true,
      label: active
          ? 'Alerta de pánico activa. Toca para ver qué se compartió o cancelarla.'
          : 'Botón de pánico. Mantén presionado tres segundos para pedir ayuda.',
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTapDown: (_) => _pressDown(),
            onTapUp: (_) => _pressUp(),
            onTapCancel: _pressUp,
            onTap: _tapped,
            child: DecoratedBox(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: AppShadows.circleButton,
              ),
              child: Container(
                width: diameter,
                height: diameter,
                decoration: const BoxDecoration(
                  color: AppColors.unsafeZone,
                  shape: BoxShape.circle,
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(
                      Icons.sos_rounded,
                      size: diameter * 0.52,
                      color: Colors.white,
                    ),
                    // El anillo que se llena mientras se sostiene: es lo que dice que el
                    // gesto va en camino y cuánto falta.
                    AnimatedBuilder(
                      animation: _hold,
                      builder: (context, child) => SizedBox.square(
                        dimension: diameter,
                        child: CircularProgressIndicator(
                          value: _hold.value,
                          strokeWidth: math.max<double>(5 * s, 4),
                          color: Colors.white,
                          backgroundColor: Colors.transparent,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (active) ...[
            SizedBox(height: 6 * s),
            _ActiveTag(width: widget.width),
          ],
        ],
      ),
    );
  }
}

/// Etiqueta de "hay una alerta en curso".
///
/// Sin esto, al volver de la hoja el botón se ve igual que antes de tocarlo y no hay forma de
/// saber si la alerta salió — que es justo lo que uno necesita saber en ese momento.
class _ActiveTag extends StatelessWidget {
  const _ActiveTag({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    final s = scaleFor(width);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10 * s, vertical: 3 * s),
      decoration: BoxDecoration(
        color: AppColors.unsafeZone,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        boxShadow: AppShadows.circleButton,
      ),
      child: Text(
        'Activa',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontFamily: AppFonts.button,
          fontFamilyFallback: AppFonts.buttonFallback,
          fontSize: fluid(width, designSize: 13, min: 11, max: 14),
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}

/// Cómo se usa el botón, para el toque que no llegó a sostenerse.
///
/// Un toque corto no manda la alerta, y sin explicación se leería como que el botón no sirve.
void showPanicHelpSheet(BuildContext context, {required double width}) {
  _showPanicSheet(
    context,
    width: width,
    title: 'Botón de pánico',
    build: (context) => [
      _PanicParagraph(
        width: width,
        text:
            'Mantén presionado ${panicHoldDuration.inSeconds} segundos y la alerta sale sola. '
            'Es a propósito: así un roce dentro de la bolsa no despierta a nadie de madrugada.',
      ),
      _PanicSection(width: width, title: 'A quién le llega'),
      ..._recipientLines(width),
      _PanicNote(
        width: width,
        text:
            'Incluido en el plan gratuito, siempre. Lo que cobra MTAPP Plus es que el sistema '
            'avise solo cuando algo sale mal, no que tú puedas pedir ayuda.',
      ),
    ],
  );
}

/// Qué acaba de salir del teléfono, y cómo desdecirse.
void showPanicSentSheet(BuildContext context, {required double width}) {
  _showPanicSheet(
    context,
    width: width,
    title: 'Alerta enviada',
    build: (context) => [
      Consumer(
        builder: (context, ref, _) {
          final alert = ref.watch(panicAlertProvider);
          if (alert == null) return const SizedBox.shrink();
          final minutes = alert.firedAt.hour * 60 + alert.firedAt.minute;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _PanicParagraph(
                width: width,
                text: 'Pediste ayuda a las ${formatClock(minutes)}.',
              ),
              _PanicSection(width: width, title: 'Qué compartiste'),
              for (final item in panicAlertPayload(alert.trip))
                _PanicBullet(width: width, text: item),
              _PanicSection(width: width, title: 'Quién lo recibió'),
              ..._recipientLines(width),
            ],
          );
        },
      ),
      _PanicNote(
        width: width,
        text:
            'En este mockup nada de esto sale del teléfono: la alerta se ve, no se manda. El '
            'enlace con el C5 tampoco existe todavía.',
      ),
      SizedBox(height: 6 * scaleFor(width)),
      Consumer(
        builder: (context, ref, _) => TextButton(
          onPressed: () {
            ref.read(panicAlertProvider.notifier).cancel();
            Navigator.pop(context);
          },
          style: TextButton.styleFrom(
            foregroundColor: AppColors.unsafeZone,
            minimumSize: Size.fromHeight(
              math.max<double>(48 * scaleFor(width), 48),
            ),
            shape: const StadiumBorder(),
          ),
          child: Text(
            'Fue una falsa alarma',
            style: TextStyle(
              fontFamily: AppFonts.button,
              fontFamilyFallback: AppFonts.buttonFallback,
              fontSize: fluid(width, designSize: 17, min: 14, max: 19),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    ],
  );
}

/// Los contactos que reciben la alerta, más el 911 con su salvedad.
List<Widget> _recipientLines(double width) => [
  for (final contact in panicRecipients)
    _PanicBullet(width: width, text: '${contact.name} · ${contact.relation}'),
  _PanicBullet(
    width: width,
    text: 'El $emergencyNumber, donde exista el enlace con el C5',
  ),
];

/// La hoja que comparten las dos: mismo alto, mismo cierre.
void _showPanicSheet(
  BuildContext context, {
  required double width,
  required String title,
  required List<Widget> Function(BuildContext) build,
}) {
  final s = scaleFor(width);
  final gutter = gutterFor(width);

  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.white,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppRadius.sheet),
      ),
    ),
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(gutter, 24 * s, gutter, 24 * s),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: maxContentWidth),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.sos_rounded,
                      size: 24 * s,
                      color: AppColors.unsafeZone,
                    ),
                    SizedBox(width: 10 * s),
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontFamily: AppFonts.headline,
                          fontFamilyFallback: AppFonts.headlineFallback,
                          fontSize: fluid(
                            width,
                            designSize: 26,
                            min: 20,
                            max: 30,
                          ),
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12 * s),
                ...build(context),
                SizedBox(height: 18 * s),
                PrimaryPillButton(
                  label: 'Entendido',
                  width: width,
                  designHeight: 52,
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _PanicParagraph extends StatelessWidget {
  const _PanicParagraph({required this.width, required this.text});

  final double width;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: fluid(width, designSize: 15, min: 13, max: 16),
        color: Colors.black87,
        height: 1.35,
      ),
    );
  }
}

class _PanicSection extends StatelessWidget {
  const _PanicSection({required this.width, required this.title});

  final double width;
  final String title;

  @override
  Widget build(BuildContext context) {
    final s = scaleFor(width);

    return Padding(
      padding: EdgeInsets.only(top: 16 * s, bottom: 6 * s),
      child: Text(
        title,
        style: TextStyle(
          fontFamily: AppFonts.button,
          fontFamilyFallback: AppFonts.buttonFallback,
          fontSize: fluid(width, designSize: 16, min: 13, max: 18),
          fontWeight: FontWeight.w700,
          color: AppColors.muted,
        ),
      ),
    );
  }
}

class _PanicBullet extends StatelessWidget {
  const _PanicBullet({required this.width, required this.text});

  final double width;
  final String text;

  @override
  Widget build(BuildContext context) {
    final s = scaleFor(width);

    return Padding(
      padding: EdgeInsets.only(bottom: 6 * s),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(top: 5 * s),
            child: Icon(Icons.circle, size: 7 * s, color: AppColors.unsafeZone),
          ),
          SizedBox(width: 10 * s),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: fluid(width, designSize: 15, min: 13, max: 16),
                color: Colors.black87,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PanicNote extends StatelessWidget {
  const _PanicNote({required this.width, required this.text});

  final double width;
  final String text;

  @override
  Widget build(BuildContext context) {
    final s = scaleFor(width);

    return Padding(
      padding: EdgeInsets.only(top: 16 * s),
      child: Text(
        text,
        style: TextStyle(
          fontSize: fluid(width, designSize: 14, min: 12, max: 15),
          color: AppColors.muted,
          height: 1.35,
        ),
      ),
    );
  }
}
