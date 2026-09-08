/// Piezas de marca compartidas entre pantallas.
///
/// Viven aquí y no dentro de cada pantalla porque el diseño las repite tal cual: la marca, los
/// accesos sociales y el enlace a iniciar sesión aparecen igual en la pantalla inicial y en la
/// de registro. Duplicarlas garantizaría que se separen a la primera corrección.
library;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme.dart';


/// Marca "MTAPP".
class MtappWordmark extends StatelessWidget {
  const MtappWordmark({super.key, required this.width, this.color});

  final double width;

  /// Blanco sobre la fotografía, negro sobre fondo claro.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Text(
      'MTAPP',
      style: TextStyle(
        fontFamily: AppFonts.display,
        fontFamilyFallback: AppFonts.displayFallback,
        fontSize: fluid(width, designSize: 24, min: 20, max: 30),
        color: color ?? Colors.white,
        letterSpacing: 1.5,
      ),
    );
  }
}

/// Enlace entre las dos pantallas de acceso.
///
/// El diseño lo usa en los dos sentidos — "¿Ya tienes cuenta?" en registro, "¿No tienes
/// cuenta?" en inicio de sesión — así que las variantes están como constructores con nombre en
/// vez de dejar el texto suelto en cada pantalla.
class AuthPrompt extends StatelessWidget {
  const AuthPrompt({
    super.key,
    required this.width,
    required this.question,
    required this.action,
    this.onTap,
    this.designSize = 15,
    this.textAlign = TextAlign.center,
  });

  /// Lleva a la pantalla de inicio de sesión.
  const AuthPrompt.signIn({
    super.key,
    required this.width,
    this.onTap,
    this.designSize = 15,
    this.textAlign = TextAlign.center,
  }) : question = '¿Ya tienes cuenta? ',
       action = 'Inicia sesión';

  /// Lleva a la pantalla de registro.
  const AuthPrompt.register({
    super.key,
    required this.width,
    this.onTap,
    this.designSize = 15,
    this.textAlign = TextAlign.center,
  }) : question = '¿No tienes cuenta? ',
       action = 'Regístrate';

  final double width;
  final String question;
  final String action;
  final VoidCallback? onTap;

  /// El diseño lo usa a 15 px en la pantalla inicial y a 12 px junto al título de los
  /// formularios.
  final double designSize;

  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        // Área táctil cómoda: el texto por sí solo es un blanco muy pequeño.
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(text: question),
              TextSpan(
                text: action,
                style: const TextStyle(
                  color: AppColors.green,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          textAlign: textAlign,
          style: TextStyle(
            fontFamily: AppFonts.body,
            fontFamilyFallback: AppFonts.bodyFallback,
            fontSize: fluid(
              width,
              designSize: designSize,
              min: designSize - 2,
              max: designSize + 2,
            ),
            // El diseño usa #8A8A8A. Sobre blanco queda en ~3.5:1, por debajo del 4.5:1 que
            // pide WCAG AA para texto de este tamaño.
            color: AppColors.muted,
          ),
        ),
      ),
    );
  }
}

/// Los dos accesos circulares de Google y Apple.
class SocialSignInRow extends StatelessWidget {
  const SocialSignInRow({
    super.key,
    required this.width,
    this.onGoogle,
    this.onApple,
  });

  final double width;
  final VoidCallback? onGoogle;
  final VoidCallback? onApple;

  @override
  Widget build(BuildContext context) {
    final s = scaleFor(width);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CircleIconButton(
          asset: 'assets/icons/google.svg',
          label: 'Continuar con Google',
          diameter: 50 * s,
          onTap: onGoogle,
        ),
        SizedBox(width: 35 * s),
        CircleIconButton(
          asset: 'assets/icons/apple.svg',
          label: 'Continuar con Apple',
          diameter: 50 * s,
          onTap: onApple,
        ),
      ],
    );
  }
}

/// Botón circular con un icono vectorial dentro.
///
/// Sirve tanto para los accesos sociales como para el regreso de la pantalla de registro; solo
/// cambian el color y el diámetro.
class CircleIconButton extends StatelessWidget {
  const CircleIconButton({
    super.key,
    required this.asset,
    required this.label,
    required this.diameter,
    this.background = AppColors.surfaceGrey,
    this.iconRatio = 0.48,
    this.onTap,
  });

  final String asset;

  /// Etiqueta para lector de pantalla: un icono suelto no dice nada por sí mismo.
  final String label;

  final double diameter;
  final Color background;

  /// Proporción que ocupa el icono dentro del círculo.
  final double iconRatio;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: background,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox.square(
            dimension: diameter,
            child: Center(
              child: SvgPicture.asset(
                asset,
                width: diameter * iconRatio,
                height: diameter * iconRatio,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
