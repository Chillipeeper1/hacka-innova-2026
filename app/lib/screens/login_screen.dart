import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets/branding.dart';
import '../widgets/inputs.dart';

/// Pantalla inicial de MTAPP.
///
/// Implementa el diseño de Figma ("HACKA", nodo 47:1014) como layout fluido en vez de copiar
/// sus coordenadas absolutas: el lienzo original mide 402x874, y traducir eso literalmente
/// rompería en cualquier teléfono que no midiera exactamente eso. Las proporciones del diseño
/// se conservan; las medidas se derivan del ancho real y se acotan a rangos legibles.
class LoginScreen extends StatelessWidget {
  const LoginScreen({
    super.key,
    this.onEnter,
    this.onSignIn,
    this.onGoogle,
    this.onApple,
  });

  final VoidCallback? onEnter;
  final VoidCallback? onSignIn;
  final VoidCallback? onGoogle;
  final VoidCallback? onApple;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const _Backdrop(),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = math.min(constraints.maxWidth, maxContentWidth);

              return SingleChildScrollView(
                child: ConstrainedBox(
                  // El contenido ocupa al menos la pantalla completa, para que la hoja quede
                  // pegada abajo; si no cabe — pantalla chica, horizontal, o tipografía
                  // grande por accesibilidad — crece y se desplaza en vez de desbordarse.
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: Column(
                      children: [
                        SafeArea(
                          bottom: false,
                          child: Padding(
                            padding: EdgeInsets.only(top: 20 * scaleFor(width)),
                            child: MtappLogo(
                              diameter: fluid(
                                width,
                                designSize: 96,
                                min: 72,
                                max: 112,
                              ),
                            ),
                          ),
                        ),
                        const Spacer(flex: 5),
                        _Hero(width: width),
                        const Spacer(flex: 6),
                        _AuthSheet(
                          width: width,
                          onEnter: onEnter,
                          onSignIn: onSignIn,
                          onGoogle: onGoogle,
                          onApple: onApple,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Margen del bloque de texto sobre la fotografía.
///
/// Es más generoso que el del resto de la app (14% contra 9%): el titular necesita aire para
/// no competir con la imagen de fondo.
double _heroGutter(double width) => math.min(math.max(width * 0.142, 20), 56);

/// Fotografía de fondo con su velo.
class _Backdrop extends StatelessWidget {
  const _Backdrop();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/images/login-morelia.png'),
          fit: BoxFit.cover,
          // El encuadre importante (catedral y camión) vive en el centro-abajo de la foto.
          alignment: Alignment(0, 0.15),
        ),
      ),
      child: ColoredBox(color: AppColors.scrim),
    );
  }
}

/// Titular y frase de apoyo.
class _Hero extends StatelessWidget {
  const _Hero({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: _heroGutter(width)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            const TextSpan(
              children: [
                TextSpan(text: 'Transporte de Morelia'),
                TextSpan(
                  text: ' - En una sola app',
                  style: TextStyle(color: AppColors.lime),
                ),
              ],
            ),
            style: TextStyle(
              fontFamily: AppFonts.headline,
              fontFamilyFallback: AppFonts.headlineFallback,
              fontSize: fluid(width, designSize: 48, min: 32, max: 54),
              height: 1.08,
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 18 * scaleFor(width)),
          Text(
            'Sigue tu camión en tiempo real',
            style: TextStyle(
              fontFamily: AppFonts.body,
              fontFamilyFallback: AppFonts.bodyFallback,
              fontSize: fluid(width, designSize: 20, min: 15, max: 23),
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

/// Hoja inferior con el CTA y las opciones de acceso.
class _AuthSheet extends StatelessWidget {
  const _AuthSheet({
    required this.width,
    this.onEnter,
    this.onSignIn,
    this.onGoogle,
    this.onApple,
  });

  final double width;
  final VoidCallback? onEnter;
  final VoidCallback? onSignIn;
  final VoidCallback? onGoogle;
  final VoidCallback? onApple;

  @override
  Widget build(BuildContext context) {
    final s = scaleFor(width);
    // Deja libre la barra de gestos: la hoja llega hasta el borde, su contenido no.
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.sheet,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.sheet),
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: maxContentWidth),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              _heroGutter(width) * 0.75,
              44 * s,
              _heroGutter(width) * 0.75,
              36 * s + bottomInset,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                PrimaryPillButton(
                  label: 'Entrar',
                  width: width,
                  onPressed: onEnter,
                ),
                SizedBox(height: 22 * s),
                AuthPrompt.signIn(width: width, onTap: onSignIn),
                SizedBox(height: 30 * s),
                SocialSignInRow(
                  width: width,
                  onGoogle: onGoogle,
                  onApple: onApple,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
