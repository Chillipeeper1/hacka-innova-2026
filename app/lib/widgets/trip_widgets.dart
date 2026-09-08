/// Piezas compartidas por las pantallas del viaje.
///
/// El diseño repite los mismos controles en cinco pantallas con mapa: menú, perfil, el círculo
/// verde de regreso, la tarjeta blanca flotante y el renglón de parada con su indicador de
/// gente. Se definen una vez para que no se separen al primer ajuste.
library;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme.dart';
import 'branding.dart';
import 'map_chrome.dart';

/// Controles superiores comunes a todas las pantallas con mapa.
class MapTopControls extends StatelessWidget {
  const MapTopControls({
    super.key,
    required this.width,
    this.onMenu,
    this.onProfile,
    this.onBack,
    this.trailing,
  });

  final double width;
  final VoidCallback? onMenu;
  final VoidCallback? onProfile;

  /// Si es `null`, no se dibuja el botón de regreso.
  final VoidCallback? onBack;

  /// Contenido extra debajo de los controles: una tarjeta, un buscador.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final s = scaleFor(width);
    final gutter = gutterFor(width);

    return Align(
      alignment: Alignment.topCenter,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          width: width,
          child: Padding(
            padding: EdgeInsets.fromLTRB(gutter, 12 * s, gutter, 0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    SquareIconButton(
                      asset: 'assets/icons/menu.svg',
                      label: 'Abrir menú',
                      size: 61 * s,
                      onTap: onMenu,
                    ),
                    SquareIconButton(
                      asset: 'assets/icons/person.svg',
                      label: 'Mi perfil',
                      size: 61 * s,
                      onTap: onProfile,
                    ),
                  ],
                ),
                if (onBack != null) ...[
                  SizedBox(height: 30 * s),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: CircleIconButton(
                      asset: 'assets/icons/chevron-left.svg',
                      label: 'Regresar',
                      diameter: 68 * s,
                      background: AppColors.mint,
                      iconRatio: 0.47,
                      shadow: AppShadows.circleButton,
                      onTap: onBack,
                    ),
                  ),
                ],
                if (trailing != null) ...[
                  SizedBox(height: 26 * s),
                  trailing!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Tarjeta blanca flotante con el icono de camión y varias líneas.
///
/// Misma forma que la tarjeta de búsqueda, pero con contenido de varias líneas: el diseño la
/// usa para "Vas hacia la parada: ...".
class MapInfoCard extends StatelessWidget {
  const MapInfoCard({
    super.key,
    required this.width,
    required this.lines,
    this.asset = 'assets/icons/bus.svg',
  });

  final double width;
  final List<String> lines;
  final String asset;

  @override
  Widget build(BuildContext context) {
    final s = scaleFor(width);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.floatingCard),
        boxShadow: AppShadows.floatingCard,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.floatingCard),
        ),
        padding: EdgeInsets.symmetric(horizontal: 26 * s, vertical: 20 * s),
        child: Row(
          children: [
            SvgPicture.asset(asset, width: 34 * s, height: 38 * s),
            SizedBox(width: 22 * s),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final line in lines)
                    Text(
                      line,
                      style: TextStyle(
                        fontFamily: AppFonts.button,
                        fontFamilyFallback: AppFonts.buttonFallback,
                        fontSize: fluid(width, designSize: 24, min: 16, max: 25),
                        height: 1.18,
                        color: Colors.black,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Punto de color que indica qué tan llena está una parada.
class CrowdDot extends StatelessWidget {
  const CrowdDot({super.key, required this.busy, this.size = 20});

  final bool busy;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: busy ? AppColors.crowdBusy : AppColors.crowdFree,
        shape: BoxShape.circle,
      ),
    );
  }
}

/// Renglón de parada: pin, nombre y cuánta gente espera.
class StopListTile extends StatelessWidget {
  const StopListTile({
    super.key,
    required this.width,
    required this.title,
    required this.waitingCount,
    required this.busy,
    this.subtitle,
    this.asset = 'assets/icons/pin-dark.svg',
    this.onTap,
  });

  final double width;
  final String title;
  final int waitingCount;
  final bool busy;

  /// Segunda línea: en la lista de opciones dice qué tan cerca del destino deja.
  final String? subtitle;

  final String asset;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final s = scaleFor(width);
    final people = waitingCount == 1 ? 'persona' : 'personas';

    return Semantics(
      button: onTap != null,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 12 * s),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 46 * s,
                  child: Center(
                    child: SvgPicture.asset(
                      asset,
                      width: 32 * s,
                      height: 38 * s,
                    ),
                  ),
                ),
                SizedBox(width: 12 * s),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: AppFonts.button,
                          fontFamilyFallback: AppFonts.buttonFallback,
                          fontSize: fluid(
                            width,
                            designSize: 24,
                            min: 17,
                            max: 25,
                          ),
                          color: Colors.black,
                        ),
                      ),
                      SizedBox(height: 8 * s),
                      Row(
                        children: [
                          CrowdDot(busy: busy, size: 18 * s),
                          SizedBox(width: 10 * s),
                          Flexible(
                            child: Text(
                              '$waitingCount $people aprox.',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: fluid(
                                  width,
                                  designSize: 15,
                                  min: 12,
                                  max: 16,
                                ),
                                color: AppColors.muted,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (subtitle != null) ...[
                        SizedBox(height: 4 * s),
                        Text(
                          subtitle!,
                          style: TextStyle(
                            fontSize: fluid(
                              width,
                              designSize: 15,
                              min: 12,
                              max: 16,
                            ),
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ],
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

/// Hoja inferior blanca con esquinas redondeadas, del alto que necesite su contenido.
class TripSheet extends StatelessWidget {
  const TripSheet({
    super.key,
    required this.width,
    required this.child,
    this.maxHeightFactor = 0.55,
    this.maxHeight,
  });

  final double width;
  final Widget child;

  /// Proporción de la pantalla que la hoja no debe rebasar, para no tapar el mapa entero.
  final double maxHeightFactor;

  final double? maxHeight;

  @override
  Widget build(BuildContext context) {
    final s = scaleFor(width);
    final gutter = gutterFor(width);
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final limit =
        (maxHeight ?? MediaQuery.sizeOf(context).height) * maxHeightFactor;

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.sheet),
        ),
        boxShadow: AppShadows.sheet,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: limit),
        child: SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: maxContentWidth),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  gutter,
                  24 * s,
                  gutter,
                  22 * s + bottomInset,
                ),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Píldora informativa: el diseño la usa para el tiempo estimado.
class InfoPill extends StatelessWidget {
  const InfoPill({
    super.key,
    required this.width,
    required this.label,
    this.background = AppColors.magenta,
    this.foreground = Colors.white,
  });

  final double width;
  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    final s = scaleFor(width);

    return Container(
      width: double.infinity,
      height: 44 * s < 44 ? 44 : 44 * s,
      alignment: Alignment.center,
      padding: EdgeInsets.symmetric(horizontal: 16 * s),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.floatingCard),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontFamily: AppFonts.button,
          fontFamilyFallback: AppFonts.buttonFallback,
          fontSize: fluid(width, designSize: 24, min: 15, max: 24),
          color: foreground,
        ),
      ),
    );
  }
}
