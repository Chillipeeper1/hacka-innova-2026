/// Controles que flotan sobre el mapa de la pantalla principal.
library;

import 'dart:math' as math;

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
            padding: EdgeInsets.symmetric(horizontal: 30 * s, vertical: 24 * s),
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

/// Espacio publicitario, debajo de la tarjeta de búsqueda.
///
/// La publicidad está contemplada en el modelo de negocio del proyecto —`documento-base`, §7.2:
/// ingreso secundario con tope, nunca el núcleo del financiamiento— así que el mockup reserva
/// el lugar donde iría en vez de descubrirlo cuando ya no quepa.
///
/// **Más angosto que la tarjeta blanca de arriba, a propósito.** Un banner del mismo ancho se
/// lee como parte de la app y compite con el buscador, que es la entrada al flujo principal.
/// Angosto y centrado se distingue como lo que es: contenido de un tercero, no un control.
///
/// El contenido es un marcador, no un anuncio: inventar un negocio de Morelia para llenar el
/// hueco pondría el nombre de alguien real en una demo sin que se haya enterado.
class AdSlotCard extends StatelessWidget {
  const AdSlotCard({super.key, required this.width, this.onTap});

  final double width;
  final VoidCallback? onTap;

  /// Qué proporción del ancho del contenido ocupa. Ver la nota de arriba.
  static const double widthFactor = 0.76;

  @override
  Widget build(BuildContext context) {
    final s = scaleFor(width);

    // El centrado lo pone quien la coloca, no ella: así el widget mide lo que mide la caja
    // gris y no el hueco entero, que es lo que se espera al medirla.
    return SizedBox(
      width: width * widthFactor,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.squareButton),
          boxShadow: AppShadows.squareButton,
        ),
        child: Material(
          color: AppColors.surfaceGrey,
          borderRadius: BorderRadius.circular(AppRadius.squareButton),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 14 * s,
                vertical: 12 * s,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.campaign_outlined,
                    size: 20 * s,
                    color: AppColors.muted,
                  ),
                  SizedBox(width: 10 * s),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Publicidad',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: AppFonts.button,
                            fontFamilyFallback: AppFonts.buttonFallback,
                            fontSize: fluid(
                              width,
                              designSize: 11,
                              min: 10,
                              max: 12,
                            ),
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                            color: AppColors.muted,
                          ),
                        ),
                        Text(
                          'Espacio disponible',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: AppFonts.button,
                            fontFamilyFallback: AppFonts.buttonFallback,
                            fontSize: fluid(
                              width,
                              designSize: 15,
                              min: 12,
                              max: 16,
                            ),
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Píldora magenta flotante sobre el mapa: las entradas a las funcionalidades de pago.
///
/// Van sobre el mapa, pegadas al borde superior de la hoja blanca y por la izquierda — el hueco
/// que quedaba libre entre los controles de arriba y las opciones de viaje. No son modos de
/// transporte, son pantallas aparte, y por eso no son renglones más de la hoja: se distinguen
/// por forma y por color.
///
/// Magenta, no verde menta como los cuadrados de arriba: son lo de pago, y el magenta es el
/// color con el que la app marca lo que quiere que se toque.
///
/// Hay dos constructores porque el set del diseño no cubre todo: la agenda tiene su calendario
/// en `assets/icons/` y la seguridad no tiene escudo, así que esa usa el de Material. El icono
/// se tiñe de blanco en los dos casos para que se lea sobre el magenta.
class MapPillButton extends StatelessWidget {
  /// Con un icono del set del diseño.
  const MapPillButton.asset({
    super.key,
    required this.width,
    required this.label,
    required String this.asset,
    this.onTap,
  }) : icon = null;

  /// Con un icono de Material, para lo que el set no trae.
  const MapPillButton.icon({
    super.key,
    required this.width,
    required this.label,
    required IconData this.icon,
    this.onTap,
  }) : asset = null;

  final double width;
  final String label;
  final VoidCallback? onTap;

  /// Uno de los dos es nulo, según el constructor.
  final String? asset;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final s = scaleFor(width);
    final iconSize = math.max<double>(20 * s, 20);

    // Nunca más ancha que la columna de contenido. Con la tipografía al doble la etiqueta sola
    // mide más que la pantalla, y sin este tope la píldora se sale en vez de recortarse.
    final maxPillWidth = width - 2 * gutterFor(width);

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: math.max(maxPillWidth, 0)),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          boxShadow: AppShadows.floatingCard,
        ),
        child: Material(
          color: AppColors.magenta,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 18 * s,
                // Nunca por debajo del objetivo táctil mínimo, aunque el diseño encoja.
                vertical: math.max<double>(11 * s, 11),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (asset case final String path)
                    SvgPicture.asset(
                      path,
                      width: iconSize,
                      height: iconSize,
                      colorFilter: const ColorFilter.mode(
                        Colors.white,
                        BlendMode.srcIn,
                      ),
                    )
                  else
                    Icon(icon, size: iconSize, color: Colors.white),
                  SizedBox(width: 10 * s),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: AppFonts.button,
                        fontFamilyFallback: AppFonts.buttonFallback,
                        fontSize: fluid(
                          width,
                          designSize: 20,
                          min: 15,
                          max: 22,
                        ),
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
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
    this.dense = false,
    this.onTap,
  });

  final String asset;
  final String label;
  final double width;

  /// El diseño no usa el mismo tamaño para todos: la bicicleta mide 49 px y la figura
  /// caminando 41.
  final double iconDesignSize;

  /// Renglón apretado.
  ///
  /// El Figma lista **dos** opciones en la hoja del inicio y les da aire de sobra. La app
  /// tiene cuatro, y con el espaciado del diseño la hoja se comería casi la mitad del mapa.
  /// Apretarlas es lo que deja las cuatro dentro sin tapar lo que hay debajo.
  final bool dense;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final s = scaleFor(width);
    final iconSize = iconDesignSize * (dense ? 0.74 : 1) * s;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: (dense ? 8 : 14) * s),
          child: Row(
            children: [
              SizedBox.square(
                // Ancho fijo para los iconos aunque midan distinto: así el texto de los
                // renglones arranca alineado.
                dimension: (dense ? 40 : 52) * s,
                child: Center(
                  child: SvgPicture.asset(
                    asset,
                    width: iconSize,
                    height: iconSize,
                  ),
                ),
              ),
              SizedBox(width: (dense ? 14 : 20) * s),
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppFonts.button,
                    fontFamilyFallback: AppFonts.buttonFallback,
                    fontSize: fluid(
                      width,
                      designSize: dense ? 20 : 24,
                      min: dense ? 15 : 17,
                      max: dense ? 22 : 26,
                    ),
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
                  width: (dense ? 24 : 30) * s,
                  height: (dense ? 24 : 30) * s,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
