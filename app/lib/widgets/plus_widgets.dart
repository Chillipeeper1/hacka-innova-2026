/// Piezas que comparten las pantallas de pago (MTAPP Plus).
///
/// La agenda semanal y el regreso seguro se ven iguales a propósito: la misma etiqueta, la
/// misma tarjeta blanca y la misma hoja que explica el plan. Si cada una trajera su copia, al
/// primer ajuste se despegarían y el plan de pago parecería dos productos distintos.
library;

import 'package:flutter/material.dart';

import '../theme.dart';
import 'inputs.dart';

/// La etiqueta que marca lo que es de pago.
class PlusBadge extends StatelessWidget {
  const PlusBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.magenta,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: const Text(
        'MTAPP Plus',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontFamily: AppFonts.button,
          fontFamilyFallback: AppFonts.buttonFallback,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
          color: Colors.white,
        ),
      ),
    );
  }
}

/// La tarjeta blanca sobre el fondo gris de las pantallas de pago.
class PlusCard extends StatelessWidget {
  const PlusCard({super.key, required this.width, required this.child});

  final double width;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final s = scaleFor(width);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.floatingCard),
        boxShadow: AppShadows.floatingCard,
      ),
      child: Padding(padding: EdgeInsets.all(16 * s), child: child),
    );
  }
}

/// Título de sección gris dentro de una pestaña de pago.
class PlusSectionTitle extends StatelessWidget {
  const PlusSectionTitle({super.key, required this.width, required this.text});

  final double width;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontFamily: AppFonts.button,
        fontFamilyFallback: AppFonts.buttonFallback,
        fontSize: fluid(width, designSize: 16, min: 13, max: 18),
        fontWeight: FontWeight.w700,
        color: AppColors.muted,
      ),
    );
  }
}

/// Qué incluye el plan, sin cobrar nada.
///
/// El mockup no lleva pasarela —`CLAUDE.md` deja fuera cualquier integración de pago— así que
/// el botón termina aquí: enseña la propuesta y se cierra. Un botón que no hiciera nada se
/// leería como que la demo está rota.
///
/// [bullets] cambia según desde dónde se abra: la agenda vende agendas y el regreso seguro
/// vende acompañamiento, y una hoja genérica no vendería ninguna de las dos.
void showPlusSheet(
  BuildContext context, {
  required double width,
  required List<String> bullets,
}) {
  final s = scaleFor(width);
  final gutter = gutterFor(width);

  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppRadius.sheet),
      ),
    ),
    builder: (context) => SafeArea(
      // Rueda por dentro: la hoja modal se topa en 9/16 de la pantalla, y con la tipografía
      // grande la lista de lo que incluye el plan no cabe en ese alto.
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(gutter, 24 * s, gutter, 24 * s),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'MTAPP Plus',
              style: TextStyle(
                fontFamily: AppFonts.headline,
                fontFamilyFallback: AppFonts.headlineFallback,
                fontSize: fluid(width, designSize: 26, min: 20, max: 30),
                fontWeight: FontWeight.w700,
                color: Colors.black,
              ),
            ),
            SizedBox(height: 12 * s),
            for (final item in bullets) ...[
              _PlusBullet(width: width, text: item),
              SizedBox(height: 8 * s),
            ],
            SizedBox(height: 12 * s),
            Text(
              'El cobro no está conectado en este mockup: lo que ves es una demostración con '
              'datos de ejemplo.',
              style: TextStyle(
                fontSize: fluid(width, designSize: 14, min: 12, max: 15),
                color: AppColors.muted,
                height: 1.35,
              ),
            ),
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
  );
}

class _PlusBullet extends StatelessWidget {
  const _PlusBullet({required this.width, required this.text});

  final double width;
  final String text;

  @override
  Widget build(BuildContext context) {
    final s = scaleFor(width);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(top: 4 * s),
          child: Icon(
            Icons.check_circle,
            size: 18 * s,
            color: AppColors.magenta,
          ),
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
    );
  }
}
