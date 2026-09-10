import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../data/agenda.dart';
import '../../data/plus_account.dart';
import '../../theme.dart';
import '../../widgets/plus_widgets.dart';
import '../../widgets/trip_widgets.dart';

/// La agenda semanal de rutas, como pestaña de MTAPP Plus.
///
/// **Es una demostración visual, no un producto conectado.** No hay modelo entrenado ni
/// consulta a uno fundacional: la semana entera sale de [AgendaWeek], un dato fijo. Lo que
/// enseña es *cómo se sentiría* tener la agenda —a qué hora salir, cuánto vas a tardar, qué
/// atajo tomar y de dónde salió cada recomendación— para poder mostrarla y decidir si vale la
/// pena construirla de verdad.
///
/// Tres decisiones que sostienen la demo:
///
/// - **Cada recomendación dice de dónde viene.** "De tus 11 viajes parecidos" y un porcentaje
///   de confianza al lado. Una app que solo afirma "sal a las 7:15" pide fe; una que enseña su
///   margen se puede contradecir sin quedar en ridículo.
/// - **El atajo es el producto.** El itinerario ya lo dan las otras pantallas gratis. Lo que se
///   paga es la línea que dice qué hacer distinto de lo que uno ya hace.
/// - **El viaje acompañado se ve desde aquí.** El plan que va con guardianes lo dice en su
///   propia tarjeta, con los nombres de quién está pendiente. Es el mismo viaje que se abre en
///   la pestaña de al lado — ver [PlusAccount].
class AgendaTab extends StatefulWidget {
  const AgendaTab({
    super.key,
    required this.width,
    required this.account,
    required this.watchers,
  });

  final double width;
  final PlusAccount account;

  /// Los guardianes prendidos ahora mismo. Vienen de la pestaña de al lado: es el dato que
  /// hace que las dos se lean como una sola cosa.
  final List<String> watchers;

  @override
  State<AgendaTab> createState() => _AgendaTabState();
}

class _AgendaTabState extends State<AgendaTab> {
  /// Abre en el día del viaje acompañado: es el que la demo va a querer enseñar primero, y
  /// además nunca está vacío.
  late int _selected = widget.account.guardedDay;

  @override
  Widget build(BuildContext context) {
    final width = widget.width;
    final s = scaleFor(width);
    final week = widget.account.week;
    final day = week.days[_selected];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Aprendida de tus ${week.learnedFromTrips} viajes guardados. Actualizada '
          '${week.updatedLabel}.',
          style: TextStyle(
            fontSize: fluid(width, designSize: 15, min: 13, max: 17),
            color: AppColors.muted,
            height: 1.3,
          ),
        ),

        SizedBox(height: 18 * s),
        _WeekStrip(
          width: width,
          days: week.days,
          selected: _selected,
          onSelect: (index) => setState(() => _selected = index),
        ),

        SizedBox(height: 18 * s),
        _DayHeading(width: width, day: day),

        if (day.isRest) ...[
          SizedBox(height: 12 * s),
          _RestCard(width: width, day: day),
        ] else
          for (final (index, plan) in day.plans.indexed) ...[
            SizedBox(height: 12 * s),
            _PlanCard(
              width: width,
              plan: plan,
              // El plan que va acompañado lo dice aquí mismo, con quién está pendiente.
              watchers:
                  _selected == widget.account.guardedDay &&
                      index == widget.account.guardedPlan
                  ? widget.watchers
                  : const [],
            ),
          ],

        SizedBox(height: 20 * s),
        _WeekSummary(width: width, week: week),
      ],
    );
  }
}

/// Los siete días, como una fila de fichas.
///
/// Va en fila y no en pestañas de Material porque siete pestañas con texto no caben en un
/// teléfono chico. La inicial más el punto de "tiene viajes" alcanza para elegir.
class _WeekStrip extends StatelessWidget {
  const _WeekStrip({
    required this.width,
    required this.days,
    required this.selected,
    required this.onSelect,
  });

  final double width;
  final List<AgendaDay> days;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final s = scaleFor(width);

    return Row(
      children: [
        for (final (index, day) in days.indexed) ...[
          if (index > 0) SizedBox(width: 6 * s),
          Expanded(
            child: _DayChip(
              width: width,
              day: day,
              on: index == selected,
              onTap: () => onSelect(index),
            ),
          ),
        ],
      ],
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({
    required this.width,
    required this.day,
    required this.on,
    required this.onTap,
  });

  final double width;
  final AgendaDay day;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = scaleFor(width);

    return Semantics(
      button: true,
      selected: on,
      // La inicial sola no dice nada en voz alta: dos "M" seguidas son martes y miércoles.
      label: day.name,
      child: ExcludeSemantics(
        child: Material(
          color: on ? AppColors.magenta : Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.squareButton),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 10 * s),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    day.initial,
                    style: TextStyle(
                      fontFamily: AppFonts.button,
                      fontFamilyFallback: AppFonts.buttonFallback,
                      fontSize: fluid(width, designSize: 17, min: 14, max: 19),
                      fontWeight: FontWeight.w700,
                      color: on ? Colors.white : Colors.black,
                    ),
                  ),
                  SizedBox(height: 6 * s),
                  // Punto lleno: ese día tiene viajes planeados. Hueco: día libre.
                  Container(
                    width: 6 * s,
                    height: 6 * s,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: day.isRest
                          ? (on
                                ? Colors.white.withValues(alpha: 0.45)
                                : AppColors.surfaceGrey)
                          : (on ? Colors.white : AppColors.green),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// El nombre del día y lo que suma: "Lunes · 2 salidas · 1 h 2 min en camino".
class _DayHeading extends StatelessWidget {
  const _DayHeading({required this.width, required this.day});

  final double width;
  final AgendaDay day;

  @override
  Widget build(BuildContext context) {
    final s = scaleFor(width);
    final trips = day.plans.length == 1 ? 'salida' : 'salidas';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          day.name,
          style: TextStyle(
            fontFamily: AppFonts.headline,
            fontFamilyFallback: AppFonts.headlineFallback,
            fontSize: fluid(width, designSize: 22, min: 18, max: 25),
            fontWeight: FontWeight.w700,
            color: Colors.black,
          ),
        ),
        if (!day.isRest) ...[
          SizedBox(height: 4 * s),
          Text(
            '${day.plans.length} $trips · ${formatDuration(day.totalMinutes)} '
            'en camino',
            style: TextStyle(
              fontFamily: AppFonts.button,
              fontFamilyFallback: AppFonts.buttonFallback,
              fontSize: fluid(width, designSize: 14, min: 12, max: 15),
              color: AppColors.muted,
            ),
          ),
        ],
      ],
    );
  }
}

/// Un día sin viajes.
class _RestCard extends StatelessWidget {
  const _RestCard({required this.width, required this.day});

  final double width;
  final AgendaDay day;

  @override
  Widget build(BuildContext context) {
    final s = scaleFor(width);

    return PlusCard(
      width: width,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.bedtime_outlined, size: 22 * s, color: AppColors.muted),
          SizedBox(width: 12 * s),
          Expanded(
            child: Text(
              day.restLabel ?? 'Sin viajes planeados.',
              style: TextStyle(
                fontSize: fluid(width, designSize: 15, min: 13, max: 16),
                color: AppColors.muted,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Un viaje planeado: la tarjeta que carga toda la demostración.
class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.width,
    required this.plan,
    this.watchers = const [],
  });

  final double width;
  final AgendaPlan plan;

  /// Quién está pendiente de este viaje. Vacío en los que no van acompañados.
  ///
  /// Es el vínculo con la pestaña de guardianes hecho visible: el mismo viaje, nombrando a la
  /// misma gente, sin tener que cambiar de pestaña para saberlo.
  final List<String> watchers;

  @override
  Widget build(BuildContext context) {
    final s = scaleFor(width);

    return PlusCard(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  plan.title,
                  style: TextStyle(
                    fontFamily: AppFonts.button,
                    fontFamilyFallback: AppFonts.buttonFallback,
                    fontSize: fluid(width, designSize: 19, min: 15, max: 21),
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
              ),
              SizedBox(width: 10 * s),
              // Flexible: con la tipografía al doble la píldora ya no cabe junto al título, y
              // recortarla es preferible a que se salga de la tarjeta.
              Flexible(
                child: _ConfidencePill(
                  width: width,
                  confidence: plan.confidence,
                ),
              ),
            ],
          ),

          SizedBox(height: 12 * s),
          // Lo primero que se lee: a qué hora salir. Es la pregunta que la agenda contesta.
          Text(
            'Sal ${formatClock(plan.departureMinutes)}',
            style: TextStyle(
              fontFamily: AppFonts.headline,
              fontFamilyFallback: AppFonts.headlineFallback,
              fontSize: fluid(width, designSize: 24, min: 19, max: 27),
              fontWeight: FontWeight.w700,
              color: AppColors.magenta,
            ),
          ),
          SizedBox(height: 4 * s),
          Text(
            '${formatDuration(plan.durationMinutes)} en camino · llegas '
            '${formatClock(plan.arrivalMinutes)}',
            style: TextStyle(
              fontSize: fluid(width, designSize: 15, min: 13, max: 16),
              color: Colors.black87,
            ),
          ),

          SizedBox(height: 14 * s),
          for (final (index, leg) in plan.legs.indexed) ...[
            if (index > 0) SizedBox(height: 8 * s),
            _LegRow(width: width, leg: leg),
          ],

          if (plan.shortcut case final shortcut?) ...[
            SizedBox(height: 14 * s),
            _ShortcutBox(width: width, shortcut: shortcut),
          ],

          if (plan.note case final String note) ...[
            SizedBox(height: 12 * s),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 17 * s, color: AppColors.muted),
                SizedBox(width: 8 * s),
                Expanded(
                  child: Text(
                    note,
                    style: TextStyle(
                      fontSize: fluid(width, designSize: 14, min: 12, max: 15),
                      color: AppColors.muted,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ],

          if (watchers.isNotEmpty) ...[
            SizedBox(height: 12 * s),
            Container(
              padding: EdgeInsets.all(10 * s),
              decoration: BoxDecoration(
                color: AppColors.magenta.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(AppRadius.squareButton),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.shield_outlined,
                    size: 17 * s,
                    color: AppColors.magenta,
                  ),
                  SizedBox(width: 8 * s),
                  Expanded(
                    child: Text(
                      'Va acompañado · ${watchers.join(' y ')} lo están viendo',
                      style: TextStyle(
                        fontFamily: AppFonts.button,
                        fontFamilyFallback: AppFonts.buttonFallback,
                        fontSize: fluid(
                          width,
                          designSize: 13,
                          min: 11,
                          max: 14,
                        ),
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          SizedBox(height: 12 * s),
          Divider(height: 1, color: AppColors.surfaceGrey),
          SizedBox(height: 10 * s),
          Text(
            'Aprendido de tus ${plan.learnedFrom} viajes parecidos',
            style: TextStyle(
              fontSize: fluid(width, designSize: 13, min: 11, max: 14),
              color: AppColors.muted,
            ),
          ),
        ],
      ),
    );
  }
}

/// Un tramo del plan: su modo, su color y cuánto dura.
class _LegRow extends StatelessWidget {
  const _LegRow({required this.width, required this.leg});

  final double width;
  final AgendaLeg leg;

  @override
  Widget build(BuildContext context) {
    final s = scaleFor(width);
    final color = journeyModeColor(leg.mode);

    return Row(
      children: [
        Container(
          width: 30 * s,
          height: 30 * s,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Center(
            child: SvgPicture.asset(
              journeyModeAsset(leg.mode),
              width: 16 * s,
              height: 16 * s,
            ),
          ),
        ),
        SizedBox(width: 10 * s),
        Expanded(
          child: Text(
            leg.label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: fluid(width, designSize: 14, min: 12, max: 15),
              color: Colors.black87,
            ),
          ),
        ),
        SizedBox(width: 8 * s),
        Text(
          '${leg.minutes} min',
          style: TextStyle(
            fontFamily: AppFonts.button,
            fontFamilyFallback: AppFonts.buttonFallback,
            fontSize: fluid(width, designSize: 14, min: 12, max: 15),
            fontWeight: FontWeight.w600,
            color: AppColors.muted,
          ),
        ),
      ],
    );
  }
}

/// El atajo: lo que de verdad se está vendiendo.
class _ShortcutBox extends StatelessWidget {
  const _ShortcutBox({required this.width, required this.shortcut});

  final double width;
  final AgendaShortcut shortcut;

  @override
  Widget build(BuildContext context) {
    final s = scaleFor(width);

    return Container(
      padding: EdgeInsets.all(12 * s),
      decoration: BoxDecoration(
        color: AppColors.mint,
        borderRadius: BorderRadius.circular(AppRadius.squareButton),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bolt, size: 18 * s, color: AppColors.green),
              SizedBox(width: 6 * s),
              Expanded(
                child: Text(
                  'Atajo · ahorras ${shortcut.savedMinutes} min',
                  style: TextStyle(
                    fontFamily: AppFonts.button,
                    fontFamilyFallback: AppFonts.buttonFallback,
                    fontSize: fluid(width, designSize: 14, min: 12, max: 15),
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 6 * s),
          Text(
            shortcut.label,
            style: TextStyle(
              fontSize: fluid(width, designSize: 14, min: 12, max: 15),
              color: Colors.black87,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

/// Qué tan segura está la agenda de un plan.
class _ConfidencePill extends StatelessWidget {
  const _ConfidencePill({required this.width, required this.confidence});

  final double width;
  final int confidence;

  @override
  Widget build(BuildContext context) {
    final s = scaleFor(width);
    // Verde cuando la costumbre está clara; ámbar cuando todavía son pocos viajes. El umbral
    // es el mismo criterio con el que se escribió el dato: por debajo de 75 es corazonada.
    final sure = confidence >= 75;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 9 * s, vertical: 4 * s),
      decoration: BoxDecoration(
        color: (sure ? AppColors.green : AppColors.crowdBusy).withValues(
          alpha: 0.20,
        ),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        '$confidence % seguro',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontFamily: AppFonts.button,
          fontFamilyFallback: AppFonts.buttonFallback,
          fontSize: fluid(width, designSize: 12, min: 10, max: 13),
          fontWeight: FontWeight.w700,
          color: Colors.black,
        ),
      ),
    );
  }
}

/// El cierre: lo que la semana entera ahorra.
class _WeekSummary extends StatelessWidget {
  const _WeekSummary({required this.width, required this.week});

  final double width;
  final AgendaWeek week;

  @override
  Widget build(BuildContext context) {
    final s = scaleFor(width);

    return Container(
      padding: EdgeInsets.all(18 * s),
      decoration: BoxDecoration(
        color: AppColors.magenta,
        borderRadius: BorderRadius.circular(AppRadius.sheet),
        boxShadow: AppShadows.floatingCard,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Esta semana te ahorras',
            style: TextStyle(
              fontSize: fluid(width, designSize: 15, min: 13, max: 16),
              color: Colors.white,
            ),
          ),
          SizedBox(height: 4 * s),
          Text(
            formatDuration(week.savedMinutes),
            style: TextStyle(
              fontFamily: AppFonts.headline,
              fontFamilyFallback: AppFonts.headlineFallback,
              fontSize: fluid(width, designSize: 34, min: 26, max: 38),
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 6 * s),
          Text(
            'contra las horas a las que sales hoy, siguiendo los atajos de tu agenda.',
            style: TextStyle(
              fontSize: fluid(width, designSize: 14, min: 12, max: 15),
              color: Colors.white,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}
