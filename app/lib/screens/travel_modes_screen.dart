import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../data/journey.dart';
import '../theme.dart';
import '../widgets/inputs.dart';
import '../widgets/map_chrome.dart';
import '../widgets/trip_widgets.dart';

/// Primer paso del viaje personalizado: con qué está dispuesto a moverse el pasajero.
///
/// Va **antes** del destino y antes de cualquier petición al servidor. Es la pregunta que
/// define este modo: pedir el itinerario primero y dejar los medios como ajuste posterior
/// significa que la app ya eligió por el usuario —con los cuatro medios prendidos— y que lo
/// primero que ve es un viaje en bici que quizá no tiene.
///
/// La elección viene en dos partes porque son dos preguntas distintas:
///
/// - **Por tu cuenta**: bici o caminando, y son excluyentes. Caminar nunca se puede apagar
///   —es lo que une los demás tramos y siempre hace falta para llegar a una parada—, así que
///   "caminando" no es un medio extra que se prende: es decir que no hay bici. Contra el
///   servidor esto es exactamente `bike` dentro o fuera de `modes`.
/// - **Transporte colectivo**: combi, camión y teleférico, que sí se combinan libremente.
class TravelModesScreen extends StatefulWidget {
  const TravelModesScreen({
    super.key,
    this.initialModes = const {
      JourneyMode.bike,
      JourneyMode.combi,
      JourneyMode.bus,
      JourneyMode.cableCar,
    },
    this.onMenu,
    this.onProfile,
    this.onBack,
    this.onConfirm,
  });

  final Set<JourneyMode> initialModes;
  final VoidCallback? onMenu;
  final VoidCallback? onProfile;
  final VoidCallback? onBack;

  /// Entrega los medios elegidos. Nunca llega vacío: el botón no se habilita sin nada.
  final void Function(Set<JourneyMode> modes)? onConfirm;

  @override
  State<TravelModesScreen> createState() => _TravelModesScreenState();
}

/// Los medios de transporte que se combinan entre sí, en el orden en que se enseñan.
///
/// Con su nombre propio: en el itinerario los modos se leen "En combi", "En camión", que es
/// como se nombra un tramo del viaje. Aquí no se está recorriendo nada todavía, se está
/// marcando una lista.
const List<({JourneyMode mode, String label, String detail})> _transitModes = [
  (mode: JourneyMode.combi, label: 'Combi', detail: 'Rutas de combi'),
  (mode: JourneyMode.bus, label: 'Camión', detail: 'Morebús y rutas troncales'),
  (
    mode: JourneyMode.cableCar,
    label: 'Teleférico',
    detail: 'Donde ya hay estación',
  ),
];

class _TravelModesScreenState extends State<TravelModesScreen> {
  late bool _byBike = widget.initialModes.contains(JourneyMode.bike);
  late final Set<JourneyMode> _transit = {
    for (final option in _transitModes)
      if (widget.initialModes.contains(option.mode)) option.mode,
  };

  Set<JourneyMode> get _chosen => {if (_byBike) JourneyMode.bike, ..._transit};

  /// Solo a pie y sin nada más no es un viaje que este modo pueda armar: el servidor
  /// devolvería la caminata completa, que es justo lo que hace "Viajar caminando" —y esa sí
  /// esquiva las zonas marcadas. Sin medios el filtro además se manda vacío, y el servidor lo
  /// entiende como "todos": lo contrario de lo que se pidió.
  bool get _walkingOnly => !_byBike && _transit.isEmpty;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.field,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = math.min(constraints.maxWidth, maxContentWidth);
            final s = scaleFor(width);
            final gutter = gutterFor(width);

            return Center(
              child: SizedBox(
                width: width,
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(gutter, 12 * s, gutter, 28 * s),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
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

                      SizedBox(height: 26 * s),
                      Text(
                        '¿Con qué te quieres mover?',
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
                      SizedBox(height: 8 * s),
                      Text(
                        'Armamos el viaje solo con lo que elijas aquí.',
                        style: TextStyle(
                          fontSize: fluid(
                            width,
                            designSize: 15,
                            min: 13,
                            max: 17,
                          ),
                          color: AppColors.muted,
                          height: 1.3,
                        ),
                      ),

                      SizedBox(height: 22 * s),
                      _SectionTitle(width: width, text: 'Por tu cuenta'),
                      SizedBox(height: 10 * s),
                      _Card(
                        width: width,
                        children: [
                          _ModeRow(
                            width: width,
                            mode: JourneyMode.bike,
                            label: 'En bici',
                            detail: 'Por ciclovía donde haya',
                            on: _byBike,
                            exclusive: true,
                            onTap: () => setState(() => _byBike = true),
                          ),
                          const _CardDivider(),
                          _ModeRow(
                            width: width,
                            mode: JourneyMode.walk,
                            label: 'Caminando',
                            detail: 'Sin bici en ningún tramo',
                            on: !_byBike,
                            exclusive: true,
                            onTap: () => setState(() => _byBike = false),
                          ),
                        ],
                      ),

                      SizedBox(height: 22 * s),
                      _SectionTitle(
                        width: width,
                        text: 'Transporte que aceptas',
                      ),
                      SizedBox(height: 10 * s),
                      _Card(
                        width: width,
                        children: [
                          for (final (index, option)
                              in _transitModes.indexed) ...[
                            if (index > 0) const _CardDivider(),
                            _ModeRow(
                              width: width,
                              mode: option.mode,
                              label: option.label,
                              detail: option.detail,
                              on: _transit.contains(option.mode),
                              exclusive: false,
                              onTap: () => setState(() {
                                if (!_transit.remove(option.mode)) {
                                  _transit.add(option.mode);
                                }
                              }),
                            ),
                          ],
                        ],
                      ),

                      SizedBox(height: 24 * s),
                      PrimaryPillButton(
                        label: 'Continuar',
                        width: width,
                        designHeight: 56,
                        onPressed: _walkingOnly
                            ? null
                            : () => widget.onConfirm?.call(_chosen),
                      ),
                      if (_walkingOnly) ...[
                        SizedBox(height: 10 * s),
                        Text(
                          'Para ir solo caminando usa "Viajar caminando", que además '
                          'esquiva las zonas marcadas.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: fluid(
                              width,
                              designSize: 14,
                              min: 12,
                              max: 15,
                            ),
                            color: AppColors.muted,
                            height: 1.3,
                          ),
                        ),
                      ],
                      SizedBox(height: 14 * s),
                      Center(
                        child: CancelPill(
                          width: width,
                          label: 'regresar',
                          onTap: widget.onBack,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.width, required this.text});

  final double width;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontFamily: AppFonts.button,
        fontFamilyFallback: AppFonts.buttonFallback,
        fontSize: fluid(width, designSize: 16, min: 13, max: 18),
        fontWeight: FontWeight.w700,
        color: AppColors.muted,
      ),
    );
  }
}

/// La tarjeta blanca sobre el fondo del menú, igual que la lista de modos del inicio.
class _Card extends StatelessWidget {
  const _Card({required this.width, required this.children});

  final double width;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.sheet),
        boxShadow: AppShadows.floatingCard,
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 18 * scaleFor(width)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
  }
}

class _CardDivider extends StatelessWidget {
  const _CardDivider();

  @override
  Widget build(BuildContext context) =>
      const Divider(height: 1, color: AppColors.surfaceGrey);
}

/// Un medio, prendido o apagado.
///
/// El indicador de la derecha distingue las dos preguntas sin explicarlas: círculo para lo
/// excluyente —bici o caminando, una u otra— y cuadro para lo que se combina.
class _ModeRow extends StatelessWidget {
  const _ModeRow({
    required this.width,
    required this.mode,
    required this.label,
    required this.detail,
    required this.on,
    required this.exclusive,
    required this.onTap,
  });

  final double width;
  final JourneyMode mode;
  final String label;
  final String detail;
  final bool on;

  /// Excluyente: elegirlo apaga al otro, y volver a tocarlo no lo apaga.
  final bool exclusive;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = scaleFor(width);
    final color = journeyModeColor(mode);

    return Semantics(
      container: true,
      selected: on,
      inMutuallyExclusiveGroup: exclusive,
      button: true,
      label: '$label, ${on ? 'incluido' : 'excluido'}',
      child: ExcludeSemantics(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 14 * s),
              child: Row(
                children: [
                  SizedBox.square(
                    dimension: 44 * s,
                    child: Center(
                      child: SvgPicture.asset(
                        journeyModeAsset(mode),
                        width: 30 * s,
                        height: 30 * s,
                      ),
                    ),
                  ),
                  SizedBox(width: 16 * s),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          label,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: AppFonts.button,
                            fontFamilyFallback: AppFonts.buttonFallback,
                            fontSize: fluid(
                              width,
                              designSize: 20,
                              min: 15,
                              max: 22,
                            ),
                            fontWeight: on ? FontWeight.w700 : FontWeight.w400,
                            color: on ? Colors.black : AppColors.muted,
                          ),
                        ),
                        Text(
                          detail,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: fluid(
                              width,
                              designSize: 13,
                              min: 11,
                              max: 14,
                            ),
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 12 * s),
                  _Mark(size: 26 * s, on: on, round: exclusive, color: color),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Mark extends StatelessWidget {
  const _Mark({
    required this.size,
    required this.on,
    required this.round,
    required this.color,
  });

  final double size;
  final bool on;
  final bool round;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: on ? color : Colors.transparent,
        shape: round ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: round ? null : BorderRadius.circular(size * 0.28),
        border: Border.all(color: on ? color : AppColors.surfaceGrey, width: 2),
      ),
      child: on
          ? Icon(Icons.check, size: size * 0.66, color: Colors.white)
          : null,
    );
  }
}
