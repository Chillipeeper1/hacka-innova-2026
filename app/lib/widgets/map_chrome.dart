/// Controles que flotan sobre el mapa de la pantalla principal.
library;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme.dart';

/// Botón cuadrado verde de las esquinas superiores (menú y perfil).
class SquareIconButton extends StatelessWidget {
  const SquareIconButton({
    super.key,
    required this.asset,
    required this.label,
    required this.size,
    this.onTap,
  });

  final String asset;

  /// Etiqueta para lector de pantalla: un icono suelto no dice nada por sí mismo.
  final String label;

  final double size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.squareButton),
          boxShadow: AppShadows.squareButton,
        ),
        child: Material(
          color: AppColors.mint,
          borderRadius: BorderRadius.circular(AppRadius.squareButton),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: SizedBox.square(
              dimension: size,
              child: Center(
                child: SvgPicture.asset(
                  asset,
                  width: size * 0.475,
                  height: size * 0.475,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Tarjeta blanca de "Buscar parada...".
///
/// No es un campo de texto: en el diseño es un disparador que abre la búsqueda. Se implementa
/// como botón para que el lector de pantalla lo anuncie como tal y no como texto muerto.
class SearchStopCard extends StatelessWidget {
  const SearchStopCard({
    super.key,
    required this.width,
    this.label = 'Buscar parada...',
    this.onTap,
  });

  final double width;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final s = scaleFor(width);

    // Sin Semantics propio: el texto visible ya es la etiqueta y el InkWell aporta el rol de
    // botón. Los botones de icono suelto sí lo necesitan, porque no tienen texto que leer.
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.floatingCard),
        boxShadow: AppShadows.floatingCard,
      ),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.floatingCard),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 30 * s,
              vertical: 24 * s,
            ),
            child: Row(
              children: [
                SvgPicture.asset(
                  'assets/icons/bus.svg',
                  width: 34 * s,
                  height: 38 * s,
                ),
                SizedBox(width: 26 * s),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: AppFonts.button,
                      fontFamilyFallback: AppFonts.buttonFallback,
                      fontSize: fluid(width, designSize: 24, min: 17, max: 26),
                      color: Colors.black,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Renglón de la hoja inferior: icono, texto y flecha.
class TravelOptionTile extends StatelessWidget {
  const TravelOptionTile({
    super.key,
    required this.asset,
    required this.label,
    required this.width,
    this.iconDesignSize = 45,
    this.onTap,
  });

  final String asset;
  final String label;
  final double width;

  /// El diseño no usa el mismo tamaño para todos: la bicicleta mide 49 px y la figura
  /// caminando 41.
  final double iconDesignSize;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final s = scaleFor(width);
    final iconSize = iconDesignSize * s;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 14 * s),
          child: Row(
            children: [
              SizedBox.square(
                // Ancho fijo para los iconos aunque midan distinto: así el texto de los dos
                // renglones arranca alineado.
                dimension: 52 * s,
                child: Center(
                  child: SvgPicture.asset(
                    asset,
                    width: iconSize,
                    height: iconSize,
                  ),
                ),
              ),
              SizedBox(width: 20 * s),
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppFonts.button,
                    fontFamilyFallback: AppFonts.buttonFallback,
                    fontSize: fluid(width, designSize: 24, min: 17, max: 26),
                    color: Colors.black,
                  ),
                ),
              ),
              SizedBox(width: 12 * s),
              // El diseño reutiliza el chevron izquierdo girado; aquí se voltea en vez de
              // exportar un segundo archivo con el mismo trazo.
              Transform.flip(
                flipX: true,
                child: SvgPicture.asset(
                  'assets/icons/chevron-left.svg',
                  width: 30 * s,
                  height: 30 * s,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
