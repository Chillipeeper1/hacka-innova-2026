import 'package:latlong2/latlong.dart';

/// Constantes geográficas de la Zona Metropolitana de Morelia.
class Morelia {
  const Morelia._();

  /// Centro histórico. Punto de arranque de la cámara del mapa.
  static const LatLng center = LatLng(19.7008, -101.1844);

  static const double defaultZoom = 15;
  static const double minZoom = 11;
  static const double maxZoom = 18;

  /// Límite de encuadre, para que la cámara no se vaya al otro lado del mundo de un
  /// arrastrón. El mockup solo tiene datos de esta zona.
  static const LatLng southWest = LatLng(19.60, -101.32);
  static const LatLng northEast = LatLng(19.80, -101.05);

  /// Teselas de OpenStreetMap.
  ///
  /// Sirven para desarrollo y demo. Los servidores comunitarios de OSM prohíben el uso masivo
  /// desde aplicaciones distribuidas: antes de publicar hay que apuntar a teselas propias o a
  /// un proveedor con contrato. Ver `documento-base-maas-morelia.md`, sección 3.
  static const String tileUrlTemplate =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  /// Atribución obligatoria: es la licencia de los datos, no un adorno.
  static const String tileAttribution = '© OpenStreetMap';

  static const String userAgentPackageName = 'mx.maasmorelia.maas_morelia';
}
