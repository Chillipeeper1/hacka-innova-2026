/// Piezas compartidas por las pantallas del viaje.
///
/// El diseño repite los mismos controles en cinco pantallas con mapa: menú, perfil, el círculo
/// verde de regreso y el renglón de parada con su indicador de gente. Se definen una vez para
/// que no se separen al primer ajuste.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:latlong2/latlong.dart';

import '../data/journey.dart';
import '../theme.dart';
import 'address_text.dart';
import 'branding.dart';
import 'map_chrome.dart';

/// Color de cada modo. El mismo criterio que en el resto de la app: azul lo que se camina,
/// verde la bici, y cada servicio con su color.
///
/// Vive aquí y no en una pantalla porque lo usan tanto la elección de medios como el
/// itinerario: el chip que el pasajero prendió y el tramo que le tocó recorrer tienen que
/// verse del mismo color, o no se reconocen como la misma cosa.
Color journeyModeColor(JourneyMode mode) => switch (mode) {
  JourneyMode.walk => AppColors.walkPath,
  JourneyMode.bike => AppColors.green,
  JourneyMode.bus => AppColors.magenta,
  JourneyMode.combi => AppColors.magentaDeep,
  JourneyMode.cableCar => const Color(0xFF7B2FF7),
};

/// La combi comparte icono con el camión: no hay trazo propio en el set del diseño.
String journeyModeAsset(JourneyMode mode) => switch (mode) {
  JourneyMode.walk => 'assets/icons/walk.svg',
  JourneyMode.bike => 'assets/icons/bicycle.svg',
  JourneyMode.bus || JourneyMode.combi => 'assets/icons/bus.svg',
  JourneyMode.cableCar => 'assets/icons/cable-car.svg',
};

/// Controles superiores comunes a todas las pantallas con mapa.
class MapTopControls extends StatelessWidget {
  const MapTopControls({
    super.key,
    required this.width,
    this.onMenu,
    this.onProfile,
    this.onBack,
    this.panic,
    this.trailing,
  });

  final double width;
  final VoidCallback? onMenu;
  final VoidCallback? onProfile;

  /// Si es `null`, no se dibuja el botón de regreso.
  final VoidCallback? onBack;

  /// El botón de pánico, en las pantallas que van dentro de un viaje.
  ///
  /// Va aquí y no flotando junto a la hoja inferior porque la hoja cambia de alto en cada
  /// pantalla —y en algunas cambia sola, al llegar la unidad— y un botón de emergencia no
  /// puede estar en un lugar distinto cada vez que se busca. Arriba a la derecha, espejo del
  /// círculo de regreso, está siempre en el mismo sitio.
  final Widget? panic;

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
                if (onBack != null || panic != null) ...[
                  SizedBox(height: 30 * s),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (onBack != null)
                        CircleIconButton(
                          asset: 'assets/icons/chevron-left.svg',
                          label: 'Regresar',
                          diameter: 68 * s,
                          background: AppColors.mint,
                          iconRatio: 0.47,
                          shadow: AppShadows.circleButton,
                          onTap: onBack,
                        ),
                      const Spacer(),
                      ?panic,
                    ],
                  ),
                ],
                if (trailing != null) ...[SizedBox(height: 26 * s), trailing!],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Renglón de "a dónde vas" dentro de la hoja blanca.
///
/// Esto vivía en una tarjeta flotante propia sobre el mapa, justo debajo de los controles de
/// arriba, y tapaba la parte del mapa por la que se va a pasar. Es información de referencia
/// —se consulta una vez y se olvida— así que su lugar es la hoja, donde ya se lee todo lo demás
/// del viaje: el tiempo, los tramos, el botón de terminar.
///
/// Hay dos formas de nombrar un destino y por eso hay dos constructores: las paradas y
/// estaciones del catálogo tienen nombre propio, y un punto suelto del mapa no — de ese se
/// enseña su dirección de calle.
class TripDestinationLine extends StatelessWidget {
  /// Un destino con nombre: una parada o estación.
  const TripDestinationLine.named({
    super.key,
    required this.width,
    required this.label,
    required this.name,
    this.asset = 'assets/icons/bus.svg',
    this.badge,
  }) : point = null;

  /// Un punto del mapa, del que se averigua la dirección (ver [AddressText]).
  const TripDestinationLine.at({
    super.key,
    required this.width,
    required this.label,
    required this.point,
    this.asset = 'assets/icons/pin-dark.svg',
    this.badge,
  }) : name = null;

  final double width;

  /// Qué relación hay con ese lugar: "Vas hacia", "Esperas en", "Llegaste a".
  final String label;

  final String asset;

  /// El nombre propio del destino, cuando lo tiene.
  final String? name;

  /// El punto del destino, cuando hay que averiguar su dirección. Uno de los dos es nulo.
  final LatLng? point;

  /// Etiqueta del servicio, al lado de la relación con el lugar. Ver [ServiceBadge].
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    final s = scaleFor(width);

    final valueStyle = TextStyle(
      fontFamily: AppFonts.button,
      fontFamilyFallback: AppFonts.buttonFallback,
      fontSize: fluid(width, designSize: 18, min: 14, max: 19),
      height: 1.2,
      color: Colors.black,
    );

    return Semantics(
      container: true,
      // El destino cambia solo cuando llega la dirección del servicio; que se anuncie sin
      // tener que volver a recorrer la hoja.
      liveRegion: point != null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SvgPicture.asset(asset, width: 26 * s, height: 30 * s),
          SizedBox(width: 14 * s),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: fluid(
                            width,
                            designSize: 14,
                            min: 12,
                            max: 15,
                          ),
                          color: AppColors.muted,
                        ),
                      ),
                    ),
                    if (badge case final badge?) ...[
                      SizedBox(width: 8 * s),
                      badge,
                    ],
                  ],
                ),
                SizedBox(height: 2 * s),
                if (name case final String value)
                  Text(
                    value,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: valueStyle,
                  )
                else
                  AddressText(point: point!, style: valueStyle, maxLines: 2),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Etiqueta del servicio que pasa por una parada: "Combi", "Camión", "Teleférico".
///
/// El icono no alcanza para distinguirlos —la combi y el camión comparten trazo, no hay uno
/// propio en el set del diseño— así que lo que distingue es el texto. Sin esto, dos paradas de
/// servicios distintos se ven idénticas y no hay forma de saber qué va a llegar.
///
/// El color sale de la ruta, al 22% de fondo con el texto en negro encima: usar el color de la
/// ruta como texto no funciona —el ámbar `#D19B3D` sobre blanco no llega ni a 3:1— y sobre un
/// tinte claro el negro sí se lee.
class ServiceBadge extends StatelessWidget {
  const ServiceBadge({
    super.key,
    required this.width,
    required this.mode,
    required this.color,
  });

  final double width;

  /// El `mode` de la ruta tal como lo manda el servidor: `combi`, `bus`, `teleferico`.
  final String mode;

  final Color color;

  @override
  Widget build(BuildContext context) {
    final service = JourneyMode.tryFromWire(mode);
    // Un modo que esta versión no conoce no se etiqueta: mejor sin etiqueta que con una falsa.
    if (service == null) return const SizedBox.shrink();

    final s = scaleFor(width);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 9 * s, vertical: 3 * s),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset(
            journeyModeAsset(service),
            width: 13 * s,
            height: 13 * s,
          ),
          SizedBox(width: 6 * s),
          Text(
            service.serviceLabel,
            style: TextStyle(
              fontSize: fluid(width, designSize: 13, min: 11, max: 14),
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
        ],
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
    this.badge,
    this.asset = 'assets/icons/pin-dark.svg',
    this.onTap,
  });

  final double width;
  final String title;
  final int waitingCount;
  final bool busy;

  /// Etiqueta del servicio que pasa por aquí, si se conoce. Ver [ServiceBadge].
  final Widget? badge;

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
                          if (badge case final badge?) ...[
                            badge,
                            SizedBox(width: 10 * s),
                          ],
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

/// Pildora gris de cancelar.
///
/// La comparten el viaje en camion y el viaje en bici: abandonar a medias se ve igual en los
/// dos, y tenerla dos veces haria que se despeguen al primer ajuste.
class CancelPill extends StatelessWidget {
  const CancelPill({
    super.key,
    required this.width,
    this.label = 'cancelar',
    this.onTap,
  });

  final double width;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final s = scaleFor(width);

    return SizedBox(
      width: 178 * s,
      height: math.max(44 * s, 44),
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          backgroundColor: AppColors.surfaceGrey,
          foregroundColor: Colors.black,
          shape: const StadiumBorder(),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: AppFonts.button,
            fontFamilyFallback: AppFonts.buttonFallback,
            fontSize: fluid(width, designSize: 24, min: 16, max: 24),
          ),
        ),
      ),
    );
  }
}
