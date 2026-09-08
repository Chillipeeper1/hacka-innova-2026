/// Iconos de marcador para Google Maps.
///
/// `flutter_map` aceptaba cualquier widget como marcador; Google Maps solo acepta **mapas de
/// bits**. Así que lo que antes era un `Container` con un SVG dentro hay que dibujarlo a un
/// lienzo y convertirlo en imagen.
///
/// Se dibuja directo sobre un [Canvas] en vez de renderizar un árbol de widgets fuera de
/// pantalla: un `SvgPicture` carga su archivo de forma asíncrona, y un render de una sola
/// pasada lo pintaría vacío. Cargando el SVG a mano primero, el dibujo es determinista.
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// A cuántos píxeles físicos por píxel lógico se rasteriza.
///
/// 3 es lo que pide una pantalla de teléfono moderna. Por debajo, los bordes redondeados y el
/// texto de las etiquetas se ven pixelados sobre el mapa.
const double markerPixelRatio = 3;

/// Qué dibujar en un marcador.
///
/// Es una descripción, no un widget: las pantallas dicen *qué* quieren y esta capa se encarga
/// de convertirlo en algo que Google Maps entienda. Así el resto del código no sabe que hay
/// mapas de bits de por medio.
sealed class MapIcon {
  const MapIcon();

  /// Clave de caché. Dos iconos iguales se dibujan una sola vez.
  String get cacheKey;
}

/// Un SVG de `assets/icons`, tal cual.
class SvgMapIcon extends MapIcon {
  const SvgMapIcon(this.asset, {this.width = 38, this.height = 42});

  final String asset;
  final double width;
  final double height;

  @override
  String get cacheKey => 'svg:$asset:$width:$height';
}

/// Un SVG dentro de un círculo blanco con borde de color.
///
/// Es la forma que ya usaban la unidad, el ciclista y la cabina: el círculo los despega del
/// mapa para que se distingan del trazado que tienen debajo.
class CircledSvgMapIcon extends MapIcon {
  const CircledSvgMapIcon(
    this.asset, {
    required this.border,
    this.diameter = 40,
  });

  final String asset;
  final Color border;
  final double diameter;

  @override
  String get cacheKey => 'circled:$asset:${border.toARGB32()}:$diameter';
}

/// Un punto de color con borde blanco: la posición del usuario, una parada.
class DotMapIcon extends MapIcon {
  const DotMapIcon({
    required this.fill,
    this.border = Colors.white,
    this.diameter = 22,
    this.borderWidth = 3,
  });

  final Color fill;
  final Color border;
  final double diameter;
  final double borderWidth;

  @override
  String get cacheKey =>
      'dot:${fill.toARGB32()}:${border.toARGB32()}:$diameter:$borderWidth';
}

/// Una etiqueta de texto pegada al mapa.
///
/// Es la que sostiene promesas del producto — "Ruta por ciclovía", "Tramo sin alumbrado",
/// "Subes: Estación Centro"—, así que tiene que seguir viéndose sobre el mapa y no esconderse
/// en un globo que haya que tocar.
class LabelMapIcon extends MapIcon {
  const LabelMapIcon({
    required this.text,
    required this.background,
    this.foreground = Colors.white,
    this.fontSize = 13,
  });

  final String text;
  final Color background;
  final Color foreground;
  final double fontSize;

  @override
  String get cacheKey =>
      'label:$text:${background.toARGB32()}:${foreground.toARGB32()}:$fontSize';
}

/// Convierte descripciones de icono en mapas de bits, una sola vez cada una.
class MapIconCache {
  MapIconCache._();

  static final MapIconCache instance = MapIconCache._();

  final Map<String, BitmapDescriptor> _cache = {};

  /// El icono ya listo, o `null` si todavía no se ha dibujado.
  BitmapDescriptor? peek(MapIcon icon) => _cache[icon.cacheKey];

  Future<BitmapDescriptor> resolve(MapIcon icon) async {
    final cached = _cache[icon.cacheKey];
    if (cached != null) return cached;

    final bitmap = await _draw(icon);
    _cache[icon.cacheKey] = bitmap;
    return bitmap;
  }

  /// Dibuja varios y devuelve el mapa de los que quedaron listos.
  Future<Map<String, BitmapDescriptor>> resolveAll(
    Iterable<MapIcon> icons,
  ) async {
    final result = <String, BitmapDescriptor>{};
    for (final icon in icons) {
      result[icon.cacheKey] = await resolve(icon);
    }
    return result;
  }

  Future<BitmapDescriptor> _draw(MapIcon icon) async {
    return switch (icon) {
      SvgMapIcon() => _drawSvg(icon),
      CircledSvgMapIcon() => _drawCircledSvg(icon),
      DotMapIcon() => _drawDot(icon),
      LabelMapIcon() => _drawLabel(icon),
    };
  }

  Future<BitmapDescriptor> _drawSvg(SvgMapIcon icon) async {
    final picture = await vg.loadPicture(SvgAssetLoader(icon.asset), null);
    return _rasterize(Size(icon.width, icon.height), (canvas, size) {
      _paintPicture(canvas, picture, size);
    });
  }

  Future<BitmapDescriptor> _drawCircledSvg(CircledSvgMapIcon icon) async {
    final picture = await vg.loadPicture(SvgAssetLoader(icon.asset), null);
    final d = icon.diameter;

    return _rasterize(Size(d, d), (canvas, size) {
      final center = Offset(d / 2, d / 2);
      canvas.drawCircle(center, d / 2, Paint()..color = Colors.white);
      canvas.drawCircle(
        center,
        d / 2 - 1.5,
        Paint()
          ..color = icon.border
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );

      // El SVG va dentro del círculo, con aire para que el borde no lo muerda.
      const padding = 7.0;
      canvas.save();
      canvas.translate(padding, padding);
      _paintPicture(canvas, picture, Size(d - padding * 2, d - padding * 2));
      canvas.restore();
    });
  }

  Future<BitmapDescriptor> _drawDot(DotMapIcon icon) async {
    final d = icon.diameter;
    return _rasterize(Size(d, d), (canvas, size) {
      final center = Offset(d / 2, d / 2);
      canvas.drawCircle(center, d / 2, Paint()..color = icon.border);
      canvas.drawCircle(
        center,
        d / 2 - icon.borderWidth,
        Paint()..color = icon.fill,
      );
    });
  }

  Future<BitmapDescriptor> _drawLabel(LabelMapIcon icon) async {
    const horizontalPadding = 10.0;
    const verticalPadding = 5.0;
    const radius = 12.0;

    final painter = TextPainter(
      text: TextSpan(
        text: icon.text,
        style: TextStyle(
          color: icon.foreground,
          fontSize: icon.fontSize,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final size = Size(
      painter.width + horizontalPadding * 2,
      painter.height + verticalPadding * 2,
    );

    return _rasterize(size, (canvas, _) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          const Radius.circular(radius),
        ),
        Paint()..color = icon.background,
      );
      painter.paint(canvas, const Offset(horizontalPadding, verticalPadding));
    });
  }

  /// Pinta un SVG ya cargado ajustándolo a [size] sin deformarlo.
  void _paintPicture(Canvas canvas, PictureInfo picture, Size size) {
    final scale = math.min(
      size.width / picture.size.width,
      size.height / picture.size.height,
    );

    canvas.save();
    canvas.translate(
      (size.width - picture.size.width * scale) / 2,
      (size.height - picture.size.height * scale) / 2,
    );
    canvas.scale(scale);
    canvas.drawPicture(picture.picture);
    canvas.restore();
  }

  Future<BitmapDescriptor> _rasterize(
    Size size,
    void Function(Canvas canvas, Size size) paint,
  ) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    canvas.scale(markerPixelRatio);
    paint(canvas, size);

    final image = await recorder.endRecording().toImage(
      (size.width * markerPixelRatio).ceil(),
      (size.height * markerPixelRatio).ceil(),
    );
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();

    return BitmapDescriptor.bytes(
      bytes!.buffer.asUint8List(),
      imagePixelRatio: markerPixelRatio,
    );
  }
}
