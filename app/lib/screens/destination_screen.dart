import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show ValueListenable;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:latlong2/latlong.dart';

import '../data/trip_plan.dart' show userLocationProvider;
import '../morelia.dart';
import '../theme.dart';
import '../widgets/address_text.dart';
import '../widgets/app_map.dart';
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
class DestinationScreen extends ConsumerStatefulWidget {
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
  ConsumerState<DestinationScreen> createState() => _DestinationScreenState();
}

class _DestinationScreenState extends ConsumerState<DestinationScreen> {
  /// Con esto la pantalla mueve la cámara sin esperar un gesto: es lo que necesita el botón
  /// de "mi ubicación".
  final AppMapController _map = AppMapController();

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

  /// Devuelve la cámara —y con ella el pin— a donde está el pasajero.
  ///
  /// La ubicación sale de `userLocationProvider`, que en este mockup es simulada: la misma que
  /// ya usan el planeador de viaje y el peatón que camina a la parada. No es GPS real, así que
  /// el botón se comporta igual con o sin permisos concedidos. Cuando se cablee el GPS, esto
  /// no cambia: seguirá siendo el mismo provider el que diga dónde está el usuario.
  ///
  /// Mover la cámara dispara `onCameraMove`, así que el pin y la dirección de la hoja se
  /// actualizan solos — no hay que tocarlos aquí.
  void _centerOnUser() {
    _map.centerOn(ref.read(userLocationProvider), zoom: 16);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          AppMap(
            initialCenter: widget.initialCenter,
            initialZoom: 16,
            controller: _map,
            onCameraMove: (center) => _picked.value = center,
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
                    // El botón va en la misma columna que la hoja y no suelto sobre el mapa:
                    // la hoja crece con el texto —y con la tipografía grande de
                    // accesibilidad— así que "encima de la hoja" solo se sostiene si es ella
                    // quien lo empuja hacia arriba.
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Acotado al ancho de lectura, igual que los controles de arriba:
                        // en escritorio la hoja blanca ocupa toda la pantalla pero su
                        // contenido va centrado, y un botón pegado al borde real se vería
                        // suelto. Así cae justo bajo el de "Mi perfil".
                        SizedBox(
                          width: width,
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(
                              gutter,
                              0,
                              gutter,
                              14 * s,
                            ),
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: SquareIconButton(
                                asset: 'assets/icons/my-location.svg',
                                label: 'Centrar en mi ubicación',
                                size: 61 * s,
                                onTap: _centerOnUser,
                              ),
                            ),
                          ),
                        ),
                        _DestinationSheet(
                          width: width,
                          maxHeight: constraints.maxHeight,
                          picked: _picked,
                          onConfirm: () =>
                              widget.onConfirm?.call(_picked.value),
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
      key: const ValueKey('destination-sheet'),
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

/// Píldora gris con la dirección del punto elegido.
///
/// Enseña una dirección de calle, no las coordenadas: quien elige un destino reconoce "Av.
/// Madero Poniente, Centro", no un par de números. Traducir el punto a dirección es una
/// consulta de red a un servicio externo (ver [ReverseGeocoder]), así que hay tres cosas que
/// resolver aquí — cuándo preguntar, qué enseñar mientras tanto, y qué hacer si no contesta.
class _PickedLocationField extends ConsumerStatefulWidget {
  const _PickedLocationField({required this.width, required this.picked});

  final double width;
  final ValueListenable<LatLng> picked;

  @override
  ConsumerState<_PickedLocationField> createState() =>
      _PickedLocationFieldState();
}

class _PickedLocationFieldState extends ConsumerState<_PickedLocationField> {
  /// Cuánto tiene que llevar quieto el mapa antes de preguntar la dirección.
  ///
  /// La cámara reporta su centro en cada cuadro del arrastre; sin esta pausa se mandaría una
  /// petición por cuadro a un servicio que pide no pasar de una por segundo. Esperar a que el
  /// dedo se detenga convierte un arrastre entero en una sola consulta.
  static const Duration settleDelay = Duration(milliseconds: 600);

  Timer? _settle;

  /// El último punto donde el mapa se quedó quieto: por el que se pregunta la dirección.
  late LatLng _settled = widget.picked.value;

  /// El mapa se está moviendo. Lo que se enseñaba ya no corresponde al pin, y todavía no hay
  /// nada que preguntar.
  bool _moving = false;

  @override
  void initState() {
    super.initState();
    widget.picked.addListener(_onPickedChanged);
  }

  @override
  void dispose() {
    _settle?.cancel();
    widget.picked.removeListener(_onPickedChanged);
    super.dispose();
  }

  void _onPickedChanged() {
    final point = widget.picked.value;
    if (!_moving) setState(() => _moving = true);

    _settle?.cancel();
    _settle = Timer(settleDelay, () {
      if (!mounted) return;
      setState(() {
        _settled = point;
        _moving = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = scaleFor(widget.width);

    final style = TextStyle(
      fontFamily: AppFonts.button,
      fontFamilyFallback: AppFonts.buttonFallback,
      fontSize: fluid(widget.width, designSize: 24, min: 15, max: 24),
      color: Colors.black,
    );

    return Container(
      height: math.max(44 * s, 44),
      padding: EdgeInsets.symmetric(horizontal: 28 * s),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.fieldStrong,
        borderRadius: BorderRadius.circular(AppRadius.floatingCard),
      ),
      child: Semantics(
        container: true,
        // Que el lector de pantalla cante la dirección cuando llega, sin que haya que volver a
        // enfocar el campo.
        liveRegion: true,
        child: _moving
            ? Text(
                AddressText.searchingLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: style.copyWith(color: AppColors.muted),
              )
            : AddressText(
                point: _settled,
                style: style,
                textAlign: TextAlign.center,
              ),
      ),
    );
  }
}
