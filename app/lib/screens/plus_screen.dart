import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/plus_account.dart';
import '../data/safe_trip.dart';
import '../theme.dart';
import '../widgets/branding.dart';
import '../widgets/inputs.dart';
import '../widgets/map_chrome.dart';
import '../widgets/plus_widgets.dart';
import 'plus/agenda_tab.dart';
import 'plus/guardians_tab.dart';
import 'plus/rewards_tab.dart';
import 'plus/trip_log_tab.dart';

/// MTAPP Plus: todo lo que se paga, en una sola pantalla.
///
/// **Es una demostración visual con datos fijos.** Nada aquí entrena un modelo, manda un
/// mensaje ni guarda un historial: ver `agenda.dart`, `safe_trip.dart` y `plus_account.dart`.
///
/// Las tres pestañas no son tres productos empaquetados juntos — son **el mismo dato mirado
/// desde tres lados**, y esta pantalla existe para que eso se note:
///
/// - **Mis viajes** es la materia prima: el historial respaldado.
/// - **Agenda** es lo que ese historial enseñó, con el mismo número de viajes detrás.
/// - **Guardianes** acompaña un viaje que sale de la agenda, con la hora que la agenda calculó.
/// - **Recompensas** es el otro lado del mismo abordaje: cada confirmación que llena el
///   historial abona cincuenta centavos a la tarjeta.
///
/// Por eso el estado de los guardianes vive **aquí** y no dentro de su pestaña: la agenda
/// también los nombra, en la tarjeta del viaje que va acompañado, y prender o apagar a alguien
/// tiene que verse en las dos al mismo tiempo. Si cada pestaña llevara su copia, la demo
/// enseñaría dos verdades distintas según dónde estuviera parado el dedo.
class PlusScreen extends StatefulWidget {
  const PlusScreen({
    super.key,
    this.account = demoPlusAccount,
    this.onMenu,
    this.onProfile,
    this.onBack,
  });

  /// Parámetro y no constante leída adentro, para que el día que haya servidor detrás la
  /// pantalla no tenga que cambiar.
  final PlusAccount account;

  final VoidCallback? onMenu;
  final VoidCallback? onProfile;
  final VoidCallback? onBack;

  @override
  State<PlusScreen> createState() => _PlusScreenState();
}

class _PlusScreenState extends State<PlusScreen> {
  int _tab = 0;

  /// Qué guardianes están prendidos. Compartido entre pestañas — ver la nota de la clase.
  late final Set<String> _active = {
    for (final guardian in widget.account.guardians)
      if (guardian.active) guardian.name,
  };

  /// El estado del viaje acompañado. Lo mueve el botón de simular, que es lo que hace
  /// demostrable la función.
  GuardedTripStatus _status = GuardedTripStatus.onTheWay;

  static const List<String> _labels = [
    'Agenda',
    'Guardianes',
    'Mis viajes',
    'Recompensas',
  ];

  /// Lo que vende cada pestaña, para que la hoja del plan hable de lo que se está mirando y no
  /// de un paquete genérico.
  static const List<String> _pitch = [
    'Tu agenda de rutas de la semana, rehecha cada madrugada.',
    'Guardianes que reciben un aviso automático si algo sale mal.',
    'Tus viajes guardados para siempre, y descargables en PDF.',
    '50 centavos de vuelta en tu tarjeta por cada combi que confirmes.',
  ];

  @override
  Widget build(BuildContext context) {
    final account = widget.account;

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

                      SizedBox(height: 30 * s),
                      // El mismo círculo de regreso que el resto de la app.
                      Align(
                        alignment: Alignment.centerLeft,
                        child: CircleIconButton(
                          asset: 'assets/icons/chevron-left.svg',
                          label: 'Regresar',
                          diameter: 68 * s,
                          background: AppColors.mint,
                          iconRatio: 0.47,
                          onTap:
                              widget.onBack ??
                              () => Navigator.maybePop(context),
                        ),
                      ),

                      SizedBox(height: 22 * s),
                      _Header(width: width, account: account),

                      SizedBox(height: 18 * s),
                      _Tabs(
                        width: width,
                        labels: _labels,
                        selected: _tab,
                        onSelect: (index) => setState(() => _tab = index),
                      ),

                      SizedBox(height: 18 * s),
                      switch (_tab) {
                        0 => AgendaTab(
                          width: width,
                          account: account,
                          watchers: _active.toList(),
                        ),
                        1 => GuardiansTab(
                          width: width,
                          account: account,
                          active: _active,
                          status: _status,
                          onToggle: (name) => setState(() {
                            if (!_active.remove(name)) _active.add(name);
                          }),
                          onSimulate: () => setState(() {
                            _status = _status == GuardedTripStatus.onTheWay
                                ? GuardedTripStatus.alerted
                                : GuardedTripStatus.onTheWay;
                          }),
                        ),
                        2 => TripLogTab(width: width, account: account),
                        _ => RewardsTab(width: width, account: account),
                      },

                      SizedBox(height: 20 * s),
                      PrimaryPillButton(
                        label: 'Activar MTAPP Plus',
                        width: width,
                        designHeight: 56,
                        onPressed: () => showPlusSheet(
                          context,
                          width: width,
                          // Lo de la pestaña abierta primero: es lo que la persona está
                          // mirando, y por lo que llegó al botón.
                          bullets: [
                            _pitch[_tab],
                            for (final (index, line) in _pitch.indexed)
                              if (index != _tab) line,
                          ],
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

/// Encabezado: qué es esto y de cuántos viajes salió.
class _Header extends StatelessWidget {
  const _Header({required this.width, required this.account});

  final double width;
  final PlusAccount account;

  @override
  Widget build(BuildContext context) {
    final s = scaleFor(width);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PlusBadge(),
        SizedBox(height: 10 * s),
        Text(
          'MTAPP Plus',
          style: TextStyle(
            fontFamily: AppFonts.headline,
            fontFamilyFallback: AppFonts.headlineFallback,
            fontSize: fluid(width, designSize: 28, min: 22, max: 32),
            fontWeight: FontWeight.w700,
            color: Colors.black,
          ),
        ),
        SizedBox(height: 8 * s),
        Text(
          'Tu agenda de rutas y tu regreso seguro, sobre los mismos '
          '${account.learnedFromTrips} viajes tuyos.',
          style: TextStyle(
            fontSize: fluid(width, designSize: 15, min: 13, max: 17),
            color: AppColors.muted,
            height: 1.3,
          ),
        ),
      ],
    );
  }
}

/// Las pestañas.
///
/// Van como píldoras propias y no como `TabBar` de Material porque el resto de la app no usa
/// Material tal cual: los chips de la agenda y estas pestañas comparten forma a propósito.
///
/// Y van en [Wrap] y no en una fila de anchos iguales: con cuatro pestañas, repartir el ancho
/// en cuatro deja "Recompensas" recortada a "Recompen..." en cualquier teléfono. Aquí cada
/// píldora mide lo que mide su texto y las que no caben bajan de renglón — se lee entero
/// siempre, a costa de que la fila no quede justificada. Desplazarlas de lado tampoco servía:
/// una pestaña que hay que descubrir arrastrando es una pestaña que nadie encuentra, y esa es
/// la razón por la que la última no puede quedar fuera de la vista.
class _Tabs extends StatelessWidget {
  const _Tabs({
    required this.width,
    required this.labels,
    required this.selected,
    required this.onSelect,
  });

  final double width;
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final s = scaleFor(width);

    return Wrap(
      spacing: 6 * s,
      runSpacing: 6 * s,
      children: [
        for (final (index, label) in labels.indexed)
          Semantics(
            button: true,
            selected: index == selected,
            child: Material(
              color: index == selected ? AppColors.magenta : Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.pill),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => onSelect(index),
                child: ConstrainedBox(
                  // Tope al ancho de la columna: con la tipografía al doble una sola etiqueta
                  // mide más que la pantalla, y sin esto la píldora se sale en vez de
                  // recortarse.
                  constraints: BoxConstraints(
                    maxWidth: math.max(width - 2 * gutterFor(width), 0),
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 14 * s,
                      vertical: 12 * s,
                    ),
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: AppFonts.button,
                        fontFamilyFallback: AppFonts.buttonFallback,
                        fontSize: fluid(
                          width,
                          designSize: 15,
                          min: 12,
                          max: 17,
                        ),
                        fontWeight: FontWeight.w700,
                        color: index == selected ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
