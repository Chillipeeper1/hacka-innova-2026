import 'dart:math' as math;

import 'package:flutter/foundation.dart' show ValueListenable;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:latlong2/latlong.dart';

import '../morelia.dart';
import '../theme.dart';
import '../widgets/branding.dart';
import '../widgets/inputs.dart';
import '../widgets/map_chrome.dart';

/// Selección del destino sobre el mapa.
///
/// Implementa el diseño de Figma ("HACKA", nodo 32:663).
///
/// El diseño dice "arrastra el pin", pero aquí el pin queda fijo en el centro y lo que se
/// mueve es el mapa. Es la convención de todas las apps de mapas por una razón práctica: el
/// dedo que arrastra el pin lo tapa justo cuando hay que ver dónde cae, y en pantalla chica no
/// queda espacio para maniobrar. Desde el punto de vista de quien lo usa el gesto se siente
/// igual — el pin se mueve respecto al mapa — y el punto elegido siempre está a la vista.
class DestinationScreen extends StatefulWidget {
  const DestinationScreen({
    super.key,
    this.initialCenter = Morelia.center,
    this.onBack,
    this.onMenu,
    this.onProfile,
    this.onConfirm,
  });

  final LatLng initialCenter;
  final VoidCallback? onBack;
  final VoidCallback? onMenu;
  final VoidCallback? onProfile;

  /// Recibe el punto elegido cuando se confirma.
  final void Function(LatLng destination)? onConfirm;

  @override
  State<DestinationScreen> createState() => _DestinationScreenState();
}

class _DestinationScreenState extends State<DestinationScreen> {
  /// El punto bajo el pin.
  ///
  /// Va en un [ValueNotifier] y no en el estado del widget porque `onPositionChanged` dispara
  /// en cada cuadro del arrastre: con `setState` se reconstruiría el mapa completo docenas de
  /// veces por segundo. Así solo se repinta la etiqueta de la dirección.
  late final ValueNotifier<LatLng> _picked = ValueNotifier(
    widget.initialCenter,
  );

  @override
  void dispose() {
    _picked.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: widget.initialCenter,
              initialZoom: 16,
              minZoom: Morelia.minZoom,
              maxZoom: Morelia.maxZoom,
              cameraConstraint: CameraConstraint.containCenter(
                bounds: LatLngBounds(Morelia.southWest, Morelia.northEast),
              ),
              onPositionChanged: (camera, _) => _picked.value = camera.center,
            ),
            children: [
              TileLayer(
                urlTemplate: Morelia.tileUrlTemplate,
                userAgentPackageName: Morelia.userAgentPackageName,
                maxZoom: Morelia.maxZoom,
              ),
            ],
          ),

          LayoutBuilder(
            builder: (context, constraints) {
              final width = math.min(constraints.maxWidth, maxContentWidth);
              final s = scaleFor(width);
              final gutter = gutterFor(width);

              return Stack(
                children: [
                  _CenterPin(size: 69 * s),

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
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  SquareIconButton(
                                    asset: 'assets/icons/menu.svg',
                                    label: 'Abrir menú',
                                    size: 61 * s,
                                    onTap: widget.onMenu,
                                  ),
                                  SquareIconButton(
                                    asset: 'assets/icons/person.svg',
                                    label: 'Mi perfil',
                                    size: 61 * s,
                                    onTap: widget.onProfile,
                                  ),
                                ],
                              ),
                              SizedBox(height: 36 * s),
                              CircleIconButton(
                                asset: 'assets/icons/chevron-left.svg',
                                label: 'Regresar',
                                diameter: 68 * s,
                                background: AppColors.mint,
                                iconRatio: 0.47,
                                shadow: AppShadows.circleButton,
                                onTap:
                                    widget.onBack ??
                                    () => Navigator.maybePop(context),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  Align(
                    alignment: Alignment.bottomCenter,
                    child: _DestinationSheet(
                      width: width,
                      maxHeight: constraints.maxHeight,
                      picked: _picked,
                      onConfirm:
                          () => widget.onConfirm?.call(_picked.value),
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

/// El pin, clavado en el centro geométrico de la pantalla.
///
/// Se desplaza hacia arriba la mitad de su alto para que la **punta** —y no su centro— caiga
/// exactamente sobre el punto que el mapa reporta como centro. Sin ese ajuste el pin señalaría
/// unos metros más al norte de lo que el usuario cree estar eligiendo.
class _CenterPin extends StatelessWidget {
  const _CenterPin({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: Transform.translate(
          offset: Offset(0, -size / 2),
          child: SvgPicture.asset(
            'assets/icons/pin.svg',
            key: const ValueKey('center-pin'),
            width: size,
            height: size,
          ),
        ),
      ),
    );
  }
}

/// Hoja inferior: título, instrucción, dirección elegida y confirmación.
class _DestinationSheet extends StatelessWidget {
  const _DestinationSheet({
    required this.width,
    required this.maxHeight,
    required this.picked,
    required this.onConfirm,
  });

  final double width;
  final double maxHeight;
  final ValueListenable<LatLng> picked;
  final VoidCallback onConfirm;

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
        constraints: BoxConstraints(maxHeight: maxHeight * 0.6),
        child: SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: maxContentWidth),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  gutter,
                  26 * s,
                  gutter,
                  24 * s + bottomInset,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '¿A dónde vas?',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: AppFonts.headline,
                        fontFamilyFallback: AppFonts.headlineFallback,
                        fontSize: fluid(
                          width,
                          designSize: 24,
                          min: 19,
                          max: 27,
                        ),
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    ),
                    SizedBox(height: 14 * s),
                    Text(
                      'Arrastra el mapa para confirmar tu ubicación',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: AppFonts.button,
                        fontFamilyFallback: AppFonts.buttonFallback,
                        fontSize: fluid(
                          width,
                          designSize: 20,
                          min: 15,
                          max: 22,
                        ),
                        height: 1.25,
                        color: Colors.black,
                      ),
                    ),
                    SizedBox(height: 22 * s),
                    _PickedLocationField(width: width, picked: picked),
                    SizedBox(height: 22 * s),
                    PrimaryPillButton(
                      label: 'Confirmar',
                      width: width,
                      designHeight: 44,
                      onPressed: onConfirm,
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

/// Píldora gris que muestra el punto elegido.
class _PickedLocationField extends StatelessWidget {
  const _PickedLocationField({required this.width, required this.picked});

  final double width;
  final ValueListenable<LatLng> picked;

  /// TODO(geocodificación): el diseño muestra una dirección de calle. Convertir coordenadas en
  /// calle y colonia necesita un geocodificador inverso (Nominatim de OSM, por ejemplo), que es
  /// un servicio externo — según `CLAUDE.md` hay que acordarlo antes de agregarlo. Mientras
  /// tanto se muestran las coordenadas reales del pin en vez de una dirección inventada.
  String _format(LatLng point) =>
      '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}';

  @override
  Widget build(BuildContext context) {
    final s = scaleFor(width);

    return Container(
      height: math.max(44 * s, 44),
      padding: EdgeInsets.symmetric(horizontal: 28 * s),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.fieldStrong,
        borderRadius: BorderRadius.circular(AppRadius.floatingCard),
      ),
      child: ValueListenableBuilder<LatLng>(
        valueListenable: picked,
        builder: (context, point, _) {
          return Text(
            _format(point),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppFonts.button,
              fontFamilyFallback: AppFonts.buttonFallback,
              fontSize: fluid(width, designSize: 24, min: 15, max: 24),
              color: Colors.black,
            ),
          );
        },
      ),
    );
  }
}
