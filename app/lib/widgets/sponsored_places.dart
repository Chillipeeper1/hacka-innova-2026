/// Los negocios publicitados de la llegada, en pantalla.
///
/// Tres piezas para cinco pantallas: los pines del mapa ([sponsoredMarkers]), la tira de
/// tarjetas de la pantalla de calificar ([SponsoredStrip]) y la hoja que abre cualquiera de
/// las dos ([showSponsoredSheet]). Van juntas porque son la misma funcionalidad contada de dos
/// formas: si cada pantalla trajera su copia, al primer ajuste el mapa y el formulario
/// estarían anunciando cosas distintas.
///
/// De dónde salen los negocios y por qué son inventados: `data/nearby_ads.dart`.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/nearby_ads.dart';
import '../theme.dart';
import 'app_map.dart';
import 'inputs.dart';

/// Cuánto ha crecido la tipografía del sistema respecto a la normal, con tope.
///
/// La tira tiene alto fijo para no comerse la pantalla de calificar; sin esto, a doble tamaño
/// el texto no cabría en la tarjeta y reventaría por desbordamiento. El tope evita que una
/// configuración extrema deje la tira más alta que el teléfono.
double textGrowth(BuildContext context) =>
    MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.0);

/// Los pines de los negocios, listos para el mapa de una pantalla de llegada.
///
/// Cada uno lleva su nombre escrito encima: un pin anónimo no anuncia nada, y obligar a tocarlo
/// para saber de quién es desperdicia el único momento en que el anuncio sirve.
List<MapMarker> sponsoredMarkers(
  BuildContext context,
  List<SponsoredPlace> places,
) => [
  for (final (index, place) in places.indexed)
    MapMarker(
      id: 'negocio-$index',
      point: place.location,
      icon: LabelMapIcon(text: place.name, background: AppColors.sponsored),
      onTap: () => showSponsoredSheet(context, place),
      semanticLabel:
          'Publicidad: ${place.name}, ${place.category}, '
          'a ${place.meters.round()} metros',
    ),
];

/// La tira de negocios de la pantalla de calificar.
///
/// Horizontal y no una lista vertical: esa pantalla existe para calificar el viaje, y una
/// columna de anuncios empujaría las estrellas fuera de la vista. Así caben en el alto de una
/// tarjeta y el formulario sigue donde estaba.
class SponsoredStrip extends StatelessWidget {
  const SponsoredStrip({super.key, required this.width, required this.places});

  final double width;
  final List<SponsoredPlace> places;

  @override
  Widget build(BuildContext context) {
    if (places.isEmpty) return const SizedBox.shrink();
    final s = scaleFor(width);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Cerca de donde bajaste',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: AppFonts.button,
                  fontFamilyFallback: AppFonts.buttonFallback,
                  fontSize: fluid(width, designSize: 14, min: 12, max: 15),
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
              ),
            ),
            const SponsoredBadge(),
          ],
        ),
        SizedBox(height: 8 * s),
        SizedBox(
          // Alto fijo y corto: esta pantalla existe para calificar el viaje, y una tira alta
          // empuja el botón de confirmar fuera de la pantalla en un teléfono normal. Crece
          // con la tipografía del sistema —si no, a doble tamaño el texto no cabría— y como
          // la pantalla rueda, ahí sí puede permitírselo.
          height: math.max(78 * s, 78) * textGrowth(context),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: places.length,
            separatorBuilder: (context, _) => SizedBox(width: 10 * s),
            itemBuilder: (context, index) =>
                _SponsoredCard(width: width, place: places[index]),
          ),
        ),
      ],
    );
  }
}

/// Una tarjeta de la tira.
class _SponsoredCard extends StatelessWidget {
  const _SponsoredCard({required this.width, required this.place});

  final double width;
  final SponsoredPlace place;

  @override
  Widget build(BuildContext context) {
    final s = scaleFor(width);

    return SizedBox(
      width: math.max(190 * s, 180) * textGrowth(context),
      child: Material(
        color: AppColors.field,
        borderRadius: BorderRadius.circular(AppRadius.squareButton),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => showSponsoredSheet(context, place),
          child: Padding(
            padding: EdgeInsets.all(12 * s),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.storefront,
                      size: 16 * s,
                      color: AppColors.sponsored,
                    ),
                    SizedBox(width: 6 * s),
                    Expanded(
                      // El giro y la distancia en el mismo renglón: son la misma pregunta
                      // —"¿qué es y qué tan lejos?"— y separadas costaban una línea de alto
                      // que esta pantalla no tiene.
                      child: Text(
                        '${place.category} · a ${place.meters.round()} m',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: fluid(
                            width,
                            designSize: 12,
                            min: 11,
                            max: 13,
                          ),
                          color: AppColors.muted,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4 * s),
                Expanded(
                  child: Text(
                    place.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: AppFonts.button,
                      fontFamilyFallback: AppFonts.buttonFallback,
                      fontSize: fluid(width, designSize: 16, min: 13, max: 17),
                      fontWeight: FontWeight.w600,
                      height: 1.15,
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

/// La etiqueta que dice que ese espacio se paga.
class SponsoredBadge extends StatelessWidget {
  const SponsoredBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.sponsored.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: const Text(
        'Publicidad',
        style: TextStyle(
          fontFamily: AppFonts.button,
          fontFamilyFallback: AppFonts.buttonFallback,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
          color: Colors.black,
        ),
      ),
    );
  }
}

/// Qué ofrece el negocio, al tocar su pin o su tarjeta.
void showSponsoredSheet(BuildContext context, SponsoredPlace place) {
  final width = math.min(MediaQuery.sizeOf(context).width, maxContentWidth);
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
                    Expanded(
                      child: Text(
                        place.name,
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
                    SizedBox(width: 10 * s),
                    const SponsoredBadge(),
                  ],
                ),
                SizedBox(height: 6 * s),
                Text(
                  '${place.category} · a ${place.meters.round()} m de donde llegaste',
                  style: TextStyle(
                    fontSize: fluid(width, designSize: 15, min: 13, max: 16),
                    color: AppColors.muted,
                  ),
                ),
                SizedBox(height: 16 * s),
                Container(
                  padding: EdgeInsets.all(14 * s),
                  decoration: BoxDecoration(
                    color: AppColors.sponsored.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.squareButton),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.local_offer,
                        size: 20 * s,
                        color: AppColors.sponsored,
                      ),
                      SizedBox(width: 10 * s),
                      Expanded(
                        child: Text(
                          place.promo,
                          style: TextStyle(
                            fontSize: fluid(
                              width,
                              designSize: 16,
                              min: 13,
                              max: 17,
                            ),
                            height: 1.3,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16 * s),
                Text(
                  'Negocio de ejemplo: en este mockup los anuncios son inventados y no hay '
                  'nada que canjear. En la versión real este espacio lo compran comercios de '
                  'la zona a la que acabas de llegar.',
                  style: TextStyle(
                    fontSize: fluid(width, designSize: 14, min: 12, max: 15),
                    color: AppColors.muted,
                    height: 1.35,
                  ),
                ),
                SizedBox(height: 18 * s),
                PrimaryPillButton(
                  label: 'Cerrar',
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
