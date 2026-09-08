/// Andamiaje compartido por las pantallas de acceso.
///
/// Registro e inicio de sesión son el mismo diseño con distinto número de campos: mismo botón
/// de regreso, misma marca arriba a la derecha, mismo título con su enlace al lado, misma
/// píldora magenta y los mismos accesos sociales. Se define una vez para que las dos no se
/// separen en cuanto alguien ajuste un espaciado.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';
import 'branding.dart';
import 'inputs.dart';

/// Construye los campos del formulario con el ancho ya resuelto.
typedef AuthFieldsBuilder = List<Widget> Function(double width, double scale);

/// Construye el enlace que acompaña al título.
typedef AuthPromptBuilder = Widget Function(double width);

class AuthFormScaffold extends StatelessWidget {
  const AuthFormScaffold({
    super.key,
    required this.formKey,
    required this.title,
    required this.promptBuilder,
    required this.fieldsBuilder,
    required this.ctaLabel,
    required this.onSubmit,
    this.titleDesignSize = 36,
    this.onBack,
    this.onGoogle,
    this.onApple,
  });

  final GlobalKey<FormState> formKey;
  final String title;

  /// El diseño usa 36 px en registro y 32 px en inicio de sesión.
  final double titleDesignSize;

  final AuthPromptBuilder promptBuilder;
  final AuthFieldsBuilder fieldsBuilder;
  final String ctaLabel;
  final VoidCallback onSubmit;
  final VoidCallback? onBack;
  final VoidCallback? onGoogle;
  final VoidCallback? onApple;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = math.min(constraints.maxWidth, maxContentWidth);
            final s = scaleFor(width);
            final gutter = gutterFor(width);
            final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

            return Center(
              child: SizedBox(
                width: width,
                child: SingleChildScrollView(
                  // El teclado tapa los campos de abajo; el desplazamiento se ajusta solo.
                  padding: EdgeInsets.fromLTRB(
                    gutter,
                    14 * s,
                    gutter,
                    40 * s + bottomInset,
                  ),
                  child: Form(
                    key: formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Header(width: width, onBack: onBack),
                        SizedBox(height: 27 * s),
                        _TitleRow(
                          width: width,
                          title: title,
                          designSize: titleDesignSize,
                          prompt: promptBuilder(width),
                        ),
                        SizedBox(height: 34 * s),
                        ...fieldsBuilder(width, s),
                        SizedBox(height: 52 * s),
                        PrimaryPillButton(
                          label: ctaLabel,
                          width: width,
                          onPressed: onSubmit,
                        ),
                        SizedBox(height: 34 * s),
                        Center(
                          child: SocialSignInRow(
                            width: width,
                            onGoogle: onGoogle,
                            onApple: onApple,
                          ),
                        ),
                      ],
                    ),
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

/// Botón de regreso y marca, en extremos opuestos.
class _Header extends StatelessWidget {
  const _Header({required this.width, this.onBack});

  final double width;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final s = scaleFor(width);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        CircleIconButton(
          asset: 'assets/icons/chevron-left.svg',
          label: 'Regresar',
          diameter: 68 * s,
          background: AppColors.mint,
          iconRatio: 0.47,
          onTap: onBack ?? () => Navigator.maybePop(context),
        ),
        MtappWordmark(width: width, color: Colors.black),
      ],
    );
  }
}

/// Título con el enlace a la otra pantalla de acceso al lado.
///
/// Va en un [Wrap] y no en un [Row]: en pantallas angostas —o con tipografía grande por
/// accesibilidad— el enlace baja a su propio renglón en vez de comprimirse hasta romperse.
class _TitleRow extends StatelessWidget {
  const _TitleRow({
    required this.width,
    required this.title,
    required this.designSize,
    required this.prompt,
  });

  final double width;
  final String title;
  final double designSize;
  final Widget prompt;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 4,
        children: [
          Text(
            title,
            style: TextStyle(
              fontFamily: AppFonts.headline,
              fontFamilyFallback: AppFonts.headlineFallback,
              fontSize: fluid(
                width,
                designSize: designSize,
                min: designSize * 0.75,
                max: designSize * 1.12,
              ),
              fontWeight: FontWeight.w700,
              color: Colors.black,
              height: 1.1,
            ),
          ),
          prompt,
        ],
      ),
    );
  }
}
