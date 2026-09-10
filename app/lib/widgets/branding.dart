/// Piezas de marca compartidas entre pantallas.
///
/// Viven aquí y no dentro de cada pantalla porque el diseño las repite tal cual: la marca, los
/// accesos sociales y el enlace a iniciar sesión aparecen igual en la pantalla inicial y en la
/// de registro. Duplicarlas garantizaría que se separen a la primera corrección.
library;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme.dart';

/// Logo de MTAPP: el acueducto, el camión y el teleférico dentro de su aro.
///
/// Sustituye al antiguo texto "MTAPP", que decía lo mismo con menos: el logo ya trae el nombre
/// y "Movilidad Morelia" dibujados dentro.
///
/// **Por qué va dentro de un círculo blanco propio** en vez de pegar el archivo tal cual: el
/// original es un JPG sin transparencia —blanco hasta las esquinas—, así que sobre la fotografía
/// de la pantalla inicial se vería como un recuadro recortado a tijera. El círculo lo convierte
/// en una insignia; sobre el blanco de las pantallas de acceso desaparece y solo queda el
/// dibujo.
///
/// **Por qué no se recorta el archivo a un óvalo**, que sería lo obvio: la imagen no es cuadrada
/// (524x559) y el aro del logo llega casi hasta los bordes laterales, así que un `ClipOval` le
/// comería los costados. Se contiene dentro del círculo, con holgura, y el original queda
/// intacto.
class MtappLogo extends StatelessWidget {
  const MtappLogo({super.key, required this.diameter});

  /// Diámetro del círculo blanco. El dibujo ocupa algo menos, para no tocar el borde.
  final double diameter;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: 'MTAPP, Movilidad Morelia',
      child: Container(
        width: diameter,
        height: diameter,
        padding: EdgeInsets.all(diameter * 0.06),
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
        ),
        clipBehavior: Clip.antiAlias,
        child: Image.asset('assets/images/mtapp-logo.jpg', fit: BoxFit.contain),
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
    this.shadow,
    this.onTap,
  });

  final String asset;

  /// Etiqueta para lector de pantalla: un icono suelto no dice nada por sí mismo.
  final String label;

  final double diameter;
  final Color background;

  /// Proporción que ocupa el icono dentro del círculo.
  final double iconRatio;

  /// Solo cuando flota sobre el mapa; en fondo blanco no hace falta.
  final List<BoxShadow>? shadow;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: DecoratedBox(
        decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: shadow),
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
      ),
    );
  }
}
