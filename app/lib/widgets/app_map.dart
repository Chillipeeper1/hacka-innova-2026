/// El mapa de la app, sobre Google Maps.
///
/// Todas las pantallas con mapa pasan por aquí. La razón no es solo evitar repetir: Google Maps
/// trae su propio tipo `LatLng`, que choca con el de `latlong2` que usa el resto del proyecto.
/// Encerrando el choque en este archivo, ninguna pantalla tiene que saber de la conversión.
///
/// Las pantallas describen **qué** quieren en el mapa —marcadores, líneas, áreas— con tipos
/// propios; esta capa los traduce. Eso también hace las pruebas legibles: se afirma sobre
/// "hay una etiqueta que dice Ruta por ciclovía", no sobre las tripas del motor de mapas.
library;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:latlong2/latlong.dart';

import '../morelia.dart';
import 'map_icons.dart';

// Las pantallas describen sus marcadores con estos tipos, así que les llegan por aquí en vez
// de obligarlas a importar también la capa que los rasteriza.
export 'map_icons.dart'
    show CircledSvgMapIcon, DotMapIcon, LabelMapIcon, MapIcon, SvgMapIcon;

/// Un marcador sobre el mapa.
class MapMarker {
  const MapMarker({
    required this.id,
    required this.point,
    required this.icon,
    this.semanticLabel,
  });

  final String id;
  final LatLng point;
  final MapIcon icon;

  /// Qué anuncia un lector de pantalla. Google Maps no expone los marcadores al árbol de
  /// accesibilidad, así que esto viaja aparte y las pantallas lo publican por su cuenta.
  final String? semanticLabel;
}

/// Una línea sobre el mapa: un trazado, un tramo recorrido, una ruta.
class MapLine {
  const MapLine({
    required this.id,
    required this.points,
    required this.color,
    this.width = 6,
  });

  final String id;
  final List<LatLng> points;
  final Color color;
  final double width;
}

/// Un área circular: la gente esperando en una parada, una zona no recomendada.
class MapArea {
  const MapArea({
    required this.id,
    required this.center,
    required this.radiusMeters,
    required this.fill,
    this.border,
    this.borderWidth = 0,
  });

  final String id;
  final LatLng center;
  final double radiusMeters;
  final Color fill;
  final Color? border;
  final double borderWidth;
}

class AppMap extends StatefulWidget {
  const AppMap({
    super.key,
    required this.initialCenter,
    this.initialZoom = 15,
    this.fitTo,
    this.markers = const [],
    this.lines = const [],
    this.areas = const [],
    this.onCameraMove,
    this.fitPadding = 60,
  });

  final LatLng initialCenter;
  final double initialZoom;

  /// Puntos que la cámara debe encuadrar al abrir. Si es `null`, se queda en [initialCenter].
  final List<LatLng>? fitTo;

  final List<MapMarker> markers;
  final List<MapLine> lines;
  final List<MapArea> areas;

  /// Se llama al mover la cámara, con el punto que queda al centro. Lo usa la pantalla de
  /// destino, donde el pin está clavado en el centro y lo que se mueve es el mapa.
  final ValueChanged<LatLng>? onCameraMove;

  final double fitPadding;

  @override
  State<AppMap> createState() => _AppMapState();
}

class _AppMapState extends State<AppMap> {
  gmaps.GoogleMapController? _controller;
  Map<String, gmaps.BitmapDescriptor> _icons = {};

  @override
  void initState() {
    super.initState();
    _loadIcons();
  }

  @override
  void didUpdateWidget(AppMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Los iconos se dibujan una vez y se guardan; solo hace falta redibujar si aparecieron
    // marcadores que no se habían visto (una etiqueta con texto nuevo, por ejemplo).
    final missing = widget.markers.any(
      (marker) => !_icons.containsKey(marker.icon.cacheKey),
    );
    if (missing) _loadIcons();
  }

  Future<void> _loadIcons() async {
    final resolved = await MapIconCache.instance.resolveAll(
      widget.markers.map((marker) => marker.icon),
    );
    if (!mounted) return;
    setState(() => _icons = {..._icons, ...resolved});
  }

  gmaps.LatLng _toGoogle(LatLng point) =>
      gmaps.LatLng(point.latitude, point.longitude);

  Future<void> _fitCamera() async {
    final points = widget.fitTo;
    final controller = _controller;
    if (points == null || points.length < 2 || controller == null) return;

    var south = points.first.latitude;
    var north = points.first.latitude;
    var west = points.first.longitude;
    var east = points.first.longitude;
    for (final point in points) {
      south = point.latitude < south ? point.latitude : south;
      north = point.latitude > north ? point.latitude : north;
      west = point.longitude < west ? point.longitude : west;
      east = point.longitude > east ? point.longitude : east;
    }

    await controller.moveCamera(
      gmaps.CameraUpdate.newLatLngBounds(
        gmaps.LatLngBounds(
          southwest: gmaps.LatLng(south, west),
          northeast: gmaps.LatLng(north, east),
        ),
        widget.fitPadding,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _map(),
        // Google Maps dibuja sus marcadores en un lienzo propio, invisible para un lector de
        // pantalla. Estos nodos de 1 px devuelven esa información: sin ellos, cambiar de motor
        // de mapas habría costado en silencio toda la accesibilidad que ya tenían.
        for (final marker in widget.markers)
          if (marker.semanticLabel case final label?)
            Positioned(
              left: 0,
              top: 0,
              child: Semantics(
                container: true,
                label: label,
                child: const SizedBox(width: 1, height: 1),
              ),
            ),
      ],
    );
  }

  Widget _map() {
    return gmaps.GoogleMap(
      initialCameraPosition: gmaps.CameraPosition(
        target: _toGoogle(widget.initialCenter),
        zoom: widget.initialZoom,
      ),
      minMaxZoomPreference: const gmaps.MinMaxZoomPreference(
        Morelia.minZoom,
        Morelia.maxZoom,
      ),
      // Sin esto, un arrastrón manda la cámara al otro lado del mundo, donde el mockup no tiene
      // nada que mostrar.
      cameraTargetBounds: gmaps.CameraTargetBounds(
        gmaps.LatLngBounds(
          southwest: _toGoogle(Morelia.southWest),
          northeast: _toGoogle(Morelia.northEast),
        ),
      ),
      // El botón de "mi ubicación" pediría permiso de GPS, y en el mockup la posición es
      // simulada: pedirlo prometería algo que no se usa.
      myLocationEnabled: false,
      myLocationButtonEnabled: false,
      mapToolbarEnabled: false,
      zoomControlsEnabled: false,
      markers: {
        for (final marker in widget.markers)
          if (_icons[marker.icon.cacheKey] case final icon?)
            gmaps.Marker(
              markerId: gmaps.MarkerId(marker.id),
              position: _toGoogle(marker.point),
              icon: icon,
            ),
      },
      polylines: {
        for (final line in widget.lines)
          gmaps.Polyline(
            polylineId: gmaps.PolylineId(line.id),
            points: line.points.map(_toGoogle).toList(),
            color: line.color,
            width: line.width.round(),
          ),
      },
      circles: {
        for (final area in widget.areas)
          gmaps.Circle(
            circleId: gmaps.CircleId(area.id),
            center: _toGoogle(area.center),
            radius: area.radiusMeters,
            fillColor: area.fill,
            strokeColor: area.border ?? Colors.transparent,
            strokeWidth: area.borderWidth.round(),
          ),
      },
      onMapCreated: (controller) {
        _controller = controller;
        _fitCamera();
      },
      onCameraMove: (position) {
        widget.onCameraMove?.call(
          LatLng(position.target.latitude, position.target.longitude),
        );
      },
    );
  }
}
