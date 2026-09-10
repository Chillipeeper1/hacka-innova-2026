import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../data/panic_alert.dart';
import '../../data/plus_account.dart';
import '../../data/safe_trip.dart';
import '../../theme.dart';
import '../../widgets/plus_widgets.dart';

/// El viaje acompañado, como pestaña de MTAPP Plus.
///
/// Lo que se paga no es compartir la ubicación —eso ya es gratis en cualquier mensajero— sino
/// que el sistema vigile solo: la pestaña enumera qué dispara el aviso, y el botón de simular
/// existe para poder *enseñar* la alerta en la demo en vez de describirla. Un jurado que ve la
/// tarjeta ponerse en rojo entiende el producto en dos segundos.
///
/// El viaje no es un dato aparte: se deriva del plan de la agenda ([PlusAccount.guardedTrip]),
/// así que la hora a la que se avisa es la que la agenda calculó.
///
/// El botón de pánico va aquí marcado como **gratuito**. No es un descuido de modelo de
/// negocio: cobrar por un botón de pánico es la crítica más fácil que le pueden hacer al
/// proyecto frente a un jurado o a la autoridad. Ver la nota en `safe_trip.dart`.
class GuardiansTab extends StatelessWidget {
  const GuardiansTab({
    super.key,
    required this.width,
    required this.account,
    required this.active,
    required this.status,
    required this.onToggle,
    required this.onSimulate,
  });

  final double width;
  final PlusAccount account;

  /// Qué guardianes están prendidos. Lo lleva la pantalla y no esta pestaña, porque la agenda
  /// también los nombra.
  final Set<String> active;

  final GuardedTripStatus status;
  final ValueChanged<String> onToggle;
  final VoidCallback onSimulate;

  @override
  Widget build(BuildContext context) {
    final s = scaleFor(width);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PlusSectionTitle(width: width, text: 'Quién recibe el aviso'),
        SizedBox(height: 10 * s),
        PlusCard(
          width: width,
          child: Column(
            children: [
              for (final (index, guardian) in account.guardians.indexed) ...[
                if (index > 0)
                  const Divider(height: 1, color: AppColors.surfaceGrey),
                _GuardianRow(
                  width: width,
                  guardian: guardian,
                  on: active.contains(guardian.name),
                  onTap: () => onToggle(guardian.name),
                ),
              ],
            ],
          ),
        ),

        SizedBox(height: 20 * s),
        PlusSectionTitle(width: width, text: 'Tu viaje ahora'),
        SizedBox(height: 6 * s),
        // De dónde salió este viaje. Sin esta línea parece un viaje inventado por otra parte
        // de la app; con ella se entiende que las dos pestañas hablan del mismo.
        Text(
          'De tu agenda del ${account.guardedDayName.toLowerCase()}.',
          style: TextStyle(
            fontSize: fluid(width, designSize: 14, min: 12, max: 15),
            color: AppColors.muted,
          ),
        ),
        SizedBox(height: 10 * s),
        _TripCard(
          width: width,
          trip: account.guardedTrip,
          status: status,
          watching: active.toList(),
        ),

        SizedBox(height: 12 * s),
        // El botón que hace demostrable la función: sin él habría que describir la alerta con
        // palabras, y describirla no convence a nadie.
        _SimulateButton(width: width, status: status, onTap: onSimulate),

        SizedBox(height: 20 * s),
        _PanicCard(width: width),
      ],
    );
  }
}

/// Un guardián, prendido o apagado.
class _GuardianRow extends StatelessWidget {
  const _GuardianRow({
    required this.width,
    required this.guardian,
    required this.on,
    required this.onTap,
  });

  final double width;
  final Guardian guardian;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = scaleFor(width);

    return Semantics(
      button: true,
      selected: on,
      label: guardian.name,
      child: ExcludeSemantics(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 12 * s),
              child: Row(
                children: [
                  Container(
                    width: 38 * s,
                    height: 38 * s,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: on
                          ? AppColors.magenta.withValues(alpha: 0.18)
                          : AppColors.surfaceGrey,
                    ),
                    child: Center(
                      child: Text(
                        guardian.name.characters.first,
                        style: TextStyle(
                          fontFamily: AppFonts.button,
                          fontFamilyFallback: AppFonts.buttonFallback,
                          fontSize: fluid(
                            width,
                            designSize: 17,
                            min: 14,
                            max: 19,
                          ),
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12 * s),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          guardian.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: AppFonts.button,
                            fontFamilyFallback: AppFonts.buttonFallback,
                            fontSize: fluid(
                              width,
                              designSize: 17,
                              min: 14,
                              max: 19,
                            ),
                            color: Colors.black,
                          ),
                        ),
                        Text(
                          guardian.relation,
                          maxLines: 1,
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
                  SizedBox(width: 10 * s),
                  Icon(
                    on ? Icons.notifications_active : Icons.notifications_off,
                    size: 22 * s,
                    color: on ? AppColors.green : AppColors.muted,
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

/// El viaje acompañado: en camino, o en alerta.
class _TripCard extends StatelessWidget {
  const _TripCard({
    required this.width,
    required this.trip,
    required this.status,
    required this.watching,
  });

  final double width;
  final GuardedTrip trip;
  final GuardedTripStatus status;

  /// Los guardianes prendidos ahora mismo. Se nombran en la tarjeta porque "avisamos a alguien"
  /// no tranquiliza; "avisamos a Mamá y a Ana" sí.
  final List<String> watching;

  bool get _alerted => status == GuardedTripStatus.alerted;

  @override
  Widget build(BuildContext context) {
    final s = scaleFor(width);
    final accent = _alerted ? AppColors.unsafeZone : AppColors.green;

    return Container(
      padding: EdgeInsets.all(16 * s),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.floatingCard),
        boxShadow: AppShadows.floatingCard,
        // El borde es lo que hace legible el cambio de estado de un vistazo, incluso a
        // distancia en la proyección de una demo.
        border: Border.all(color: accent, width: _alerted ? 2 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _alerted ? Icons.warning_amber_rounded : Icons.navigation,
                size: 20 * s,
                color: accent,
              ),
              SizedBox(width: 8 * s),
              Expanded(
                child: Text(
                  _alerted
                      ? 'No llegaste a tiempo'
                      : 'En camino · ${trip.title}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppFonts.button,
                    fontFamilyFallback: AppFonts.buttonFallback,
                    fontSize: fluid(width, designSize: 18, min: 15, max: 20),
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: 12 * s),
          if (_alerted) ...[
            Text(
              watching.isEmpty
                  ? 'No tienes guardianes prendidos, así que no se avisó a nadie.'
                  : 'Avisamos a ${_join(watching)} a las '
                        '${formatClock(trip.alertAtMinutes)}.',
              style: TextStyle(
                fontSize: fluid(width, designSize: 15, min: 13, max: 16),
                color: Colors.black87,
                height: 1.35,
              ),
            ),
            SizedBox(height: 12 * s),
            PlusSectionTitle(width: width, text: 'Qué se compartió'),
            SizedBox(height: 6 * s),
            for (final item in demoAlertPayload) ...[
              _Bullet(width: width, text: item, color: AppColors.unsafeZone),
              SizedBox(height: 4 * s),
            ],
          ] else ...[
            Text(
              'Llegas ${formatClock(trip.arrivalMinutes)}',
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
              '${trip.destination} · ${trip.route} · ${trip.unit}',
              style: TextStyle(
                fontSize: fluid(width, designSize: 14, min: 12, max: 15),
                color: AppColors.muted,
                height: 1.3,
              ),
            ),

            SizedBox(height: 14 * s),
            PlusSectionTitle(width: width, text: 'Se avisa solo si'),
            SizedBox(height: 6 * s),
            for (final trigger in trip.triggers) ...[
              SizedBox(height: 6 * s),
              _TriggerRow(width: width, trigger: trigger),
            ],
          ],
        ],
      ),
    );
  }

  /// "Mamá", "Mamá y Ana", "Mamá, Ana y Luis" — como se dice en voz alta.
  static String _join(List<String> names) {
    if (names.length == 1) return names.single;
    final head = names.sublist(0, names.length - 1).join(', ');
    return '$head y ${names.last}';
  }
}

class _TriggerRow extends StatelessWidget {
  const _TriggerRow({required this.width, required this.trigger});

  final double width;
  final TripTrigger trigger;

  @override
  Widget build(BuildContext context) {
    final s = scaleFor(width);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(top: 3 * s),
          child: Icon(Icons.bolt, size: 17 * s, color: AppColors.green),
        ),
        SizedBox(width: 8 * s),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                trigger.label,
                style: TextStyle(
                  fontFamily: AppFonts.button,
                  fontFamilyFallback: AppFonts.buttonFallback,
                  fontSize: fluid(width, designSize: 14, min: 12, max: 15),
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
              ),
              Text(
                trigger.detail,
                style: TextStyle(
                  fontSize: fluid(width, designSize: 13, min: 11, max: 14),
                  color: AppColors.muted,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet({required this.width, required this.text, required this.color});

  final double width;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final s = scaleFor(width);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(top: 4 * s),
          child: Icon(Icons.check_circle, size: 16 * s, color: color),
        ),
        SizedBox(width: 8 * s),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: fluid(width, designSize: 14, min: 12, max: 15),
              color: Colors.black87,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}

/// El botón que provoca la alerta, para poder enseñarla.
class _SimulateButton extends StatelessWidget {
  const _SimulateButton({
    required this.width,
    required this.status,
    required this.onTap,
  });

  final double width;
  final GuardedTripStatus status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = scaleFor(width);
    final alerted = status == GuardedTripStatus.alerted;

    return SizedBox(
      height: math.max(46 * s, 46),
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(alerted ? Icons.refresh : Icons.play_arrow, size: 18 * s),
        label: Text(
          alerted ? 'Volver al viaje normal' : 'Simular que no llegué',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: AppFonts.button,
            fontFamilyFallback: AppFonts.buttonFallback,
            fontSize: fluid(width, designSize: 15, min: 12, max: 16),
            fontWeight: FontWeight.w600,
          ),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.black,
          side: const BorderSide(color: AppColors.surfaceGrey),
          shape: const StadiumBorder(),
        ),
      ),
    );
  }
}

/// El botón de pánico, marcado como gratuito.
class _PanicCard extends StatelessWidget {
  const _PanicCard({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    final value = width;
    final s = scaleFor(value);

    return PlusCard(
      width: value,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.sos, size: 22 * s, color: AppColors.unsafeZone),
              SizedBox(width: 8 * s),
              Expanded(
                child: Text(
                  'Botón de pánico',
                  style: TextStyle(
                    fontFamily: AppFonts.button,
                    fontFamilyFallback: AppFonts.buttonFallback,
                    fontSize: fluid(value, designSize: 17, min: 14, max: 19),
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
              ),
              if (panicButtonIsFree) const _FreeBadge(),
            ],
          ),
          SizedBox(height: 8 * s),
          Text(
            'Incluido en el plan gratuito, siempre. Durante cualquier viaje lo tienes arriba '
            'a la derecha: mantenlo presionado ${panicHoldDuration.inSeconds} segundos y manda '
            'tu ubicación, tu ruta y tu unidad a tus contactos y, donde exista el enlace con '
            'el C5, al 911.',
            style: TextStyle(
              fontSize: fluid(value, designSize: 14, min: 12, max: 15),
              color: AppColors.muted,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

/// Etiqueta de lo que no se cobra.
class _FreeBadge extends StatelessWidget {
  const _FreeBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.green.withValues(alpha: 0.20),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: const Text(
        'Gratis',
        style: TextStyle(
          fontFamily: AppFonts.button,
          fontFamilyFallback: AppFonts.buttonFallback,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Colors.black,
        ),
      ),
    );
  }
}
