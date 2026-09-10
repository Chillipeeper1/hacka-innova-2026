/// Dónde cae un punto del mapa, dicho con palabras.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../data/providers.dart';
import '../theme.dart';

/// La dirección de calle de un punto, con sus dos estados intermedios resueltos.
///
/// Traducir coordenadas a dirección es una consulta de red, así que hay tres cosas que
/// enseñar y no una: la dirección cuando llega, un aviso mientras tanto, y las coordenadas
/// como respaldo si el servicio no contesta o no reconoce el punto. Está aquí y no repetido en
/// cada pantalla porque las tres decisiones tienen que verse igual en todas.
///
/// El respaldo son las coordenadas y no un hueco a propósito: el punto elegido sigue siendo
/// válido —se puede confirmar el viaje igual— y decir "no sé dónde es" sería falso.
class AddressText extends ConsumerWidget {
  const AddressText({
    super.key,
    required this.point,
    required this.style,
    this.searchingStyle,
    this.textAlign,
    this.maxLines = 1,
  });

  final LatLng point;
  final TextStyle style;

  /// Cómo se ve el aviso de búsqueda. Por omisión, [style] en gris.
  final TextStyle? searchingStyle;

  final TextAlign? textAlign;
  final int maxLines;

  /// Lo que se lee mientras el servicio contesta.
  static const String searchingLabel = 'Buscando dirección…';

  /// El respaldo: las coordenadas reales del punto.
  static String coordinates(LatLng point) =>
      '${point.latitude.toStringAsFixed(5)}, '
      '${point.longitude.toStringAsFixed(5)}';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resolved = ref.watch(addressProvider(point));

    // `addressAt` no lanza —quedarse sin dirección es un caso normal, no un fallo—, pero el
    // caso de error se trata igual de todos modos: coordenadas.
    final (text, searching) = switch (resolved) {
      AsyncData(value: final String address) => (address, false),
      AsyncData() || AsyncError() => (coordinates(point), false),
      _ => (searchingLabel, true),
    };

    return Text(
      text,
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      textAlign: textAlign,
      style: searching
          ? (searchingStyle ?? style.copyWith(color: AppColors.muted))
          : style,
    );
  }
}
