import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../morelia.dart';
import '../theme.dart';
import '../widgets/map_chrome.dart';

/// Pantalla principal del pasajero.
///
/// Implementa el diseño de Figma ("HACKA", nodo 17:284) y es el Escenario 1 de `CLAUDE.md`:
/// el mapa con el selector de modo de transporte.
///
/// El diseño usa una captura de pantalla de Google Maps como fondo. Aquí va un mapa de verdad
/// con `flutter_map` sobre teselas de OpenStreetMap, que es el stack que pide `CLAUDE.md`:
/// incrustar la captura habría dado una imagen fija que no hace zoom, no se desplaza y no
/// puede recibir paradas ni unidades encima.
class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    this.onMenu,
    this.onProfile,
    this.onSearchStop,
    this.onTravelByBike,
    this.onTravelWalking,
  });

  final VoidCallback? onMenu;
  final VoidCallback? onProfile;
  final VoidCallback? onSearchStop;
  final VoidCallback? onTravelByBike;
  final VoidCallback? onTravelWalking;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const _MoreliaMap(),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = math.min(constraints.maxWidth, maxContentWidth);
              final s = scaleFor(width);
              final gutter = gutterFor(width);

              return Stack(
                children: [
                  // Controles superiores. En pantallas anchas el mapa sigue a pantalla
                  // completa pero los controles se quedan centrados y a ancho de lectura.
                  Align(
                    alignment: Alignment.topCenter,
                    child: SafeArea(
                      bottom: false,
                      child: SizedBox(
                        width: width,
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            gutter,
                            12 * s,
                            gutter,
                            0,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
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
                              SizedBox(height: 30 * s),
                              SearchStopCard(
                                width: width,
                                onTap: onSearchStop,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // La atribución va pegada encima de la hoja porque la hoja tapa la
                        // esquina inferior derecha, que es donde iría por convención.
                        _MapAttribution(width: width),
                        _TravelSheet(
                          width: width,
                          maxHeight: constraints.maxHeight,
                          onTravelByBike: onTravelByBike,
                          onTravelWalking: onTravelWalking,
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// El mapa.
class _MoreliaMap extends StatelessWidget {
  const _MoreliaMap();

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      options: MapOptions(
        initialCenter: Morelia.center,
        initialZoom: Morelia.defaultZoom,
        minZoom: Morelia.minZoom,
        maxZoom: Morelia.maxZoom,
        // Sin esto, un arrastrón manda la cámara al otro lado del mundo, donde el mockup no
        // tiene nada que mostrar.
        cameraConstraint: CameraConstraint.containCenter(
          bounds: LatLngBounds(Morelia.southWest, Morelia.northEast),
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: Morelia.tileUrlTemplate,
          userAgentPackageName: Morelia.userAgentPackageName,
          maxZoom: Morelia.maxZoom,
        ),
        const MarkerLayer(markers: [_userLocationMarker]),
      ],
    );
  }

  /// Punto azul de "estás aquí".
  ///
  /// TODO(ubicación): hoy está fijo en el centro de Morelia. Cuando se conecte el GPS real
  /// debe seguir la posición del dispositivo — y pedir permiso antes, no después.
  static const Marker _userLocationMarker = Marker(
    point: Morelia.center,
    width: 22,
    height: 22,
    child: _UserLocationDot(),
  );
}

class _UserLocationDot extends StatelessWidget {
  const _UserLocationDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2E7DF6),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: const [
          BoxShadow(color: Color(0x33000000), blurRadius: 4, offset: Offset(0, 1)),
        ],
      ),
    );
  }
}

/// Hoja inferior con las opciones de viaje.
class _TravelSheet extends StatelessWidget {
  const _TravelSheet({
    required this.width,
    required this.maxHeight,
    this.onTravelByBike,
    this.onTravelWalking,
  });

  final double width;
  final double maxHeight;
  final VoidCallback? onTravelByBike;
  final VoidCallback? onTravelWalking;

  @override
  Widget build(BuildContext context) {
    final s = scaleFor(width);
    final gutter = gutterFor(width);
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

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
        // Con tipografía grande los renglones crecen; la hoja no debe comerse el mapa
        // completo, así que a partir de la mitad de la pantalla se desplaza por dentro.
        constraints: BoxConstraints(maxHeight: maxHeight * 0.55),
        child: SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: maxContentWidth),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  gutter,
                  22 * s,
                  gutter,
                  20 * s + bottomInset,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TravelOptionTile(
                      asset: 'assets/icons/bicycle.svg',
                      label: 'Viajar en bici...',
                      width: width,
                      iconDesignSize: 49,
                      onTap: onTravelByBike,
                    ),
                    const Divider(height: 1, color: AppColors.surfaceGrey),
                    TravelOptionTile(
                      asset: 'assets/icons/walk.svg',
                      label: 'Viajar caminando...',
                      width: width,
                      iconDesignSize: 41,
                      onTap: onTravelWalking,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Atribución de OpenStreetMap.
///
/// Es requisito de la licencia de los datos, no un adorno. No se usa
/// `SimpleAttributionWidget` de flutter_map porque antepone su propio "© " —dejando
/// "© © OpenStreetMap"— y su fila no puede encoger, así que desborda en pantallas angostas.
class _MapAttribution extends StatelessWidget {
  const _MapAttribution({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    final gutter = gutterFor(width);

    return SizedBox(
      width: width,
      child: Padding(
        padding: EdgeInsets.fromLTRB(gutter, 0, gutter, 8),
        child: Align(
          alignment: Alignment.centerRight,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.82),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              child: Text(
                Morelia.tileAttribution,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, color: Colors.black87),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
