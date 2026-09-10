import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../data/plus_account.dart';
import '../../data/safe_trip.dart';
import '../../theme.dart';
import '../../widgets/plus_widgets.dart';
import '../../widgets/trip_widgets.dart';

/// La caja negra del viaje, como pestaña de MTAPP Plus.
///
/// El muro de pago no se explica, se ve: los viajes recientes están completos y los viejos
/// bloqueados con candado.
///
/// Y es el otro extremo del vínculo entre las dos funcionalidades: estos son los viajes de los
/// que la agenda dice haber aprendido, así que la pestaña lo dice con todas sus letras y con
/// el mismo número que enseña la agenda ([PlusAccount.learnedFromTrips]).
class TripLogTab extends StatelessWidget {
  const TripLogTab({super.key, required this.width, required this.account});

  final double width;
  final PlusAccount account;

  @override
  Widget build(BuildContext context) {
    final s = scaleFor(width);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _RetentionCard(
          width: width,
          visible: account.visibleTrips,
          total: account.tripLog.length,
        ),

        SizedBox(height: 16 * s),
        PlusCard(
          width: width,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.auto_awesome, size: 20 * s, color: AppColors.magenta),
              SizedBox(width: 10 * s),
              Expanded(
                child: Text(
                  'Estos son los ${account.learnedFromTrips} viajes con los que armamos tu '
                  'agenda. Es el mismo historial: lo que respaldamos es lo que aprende.',
                  style: TextStyle(
                    fontSize: fluid(width, designSize: 14, min: 12, max: 15),
                    color: Colors.black87,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ),

        SizedBox(height: 20 * s),
        PlusSectionTitle(width: width, text: 'Tus viajes guardados'),
        for (final record in account.tripLog) ...[
          SizedBox(height: 10 * s),
          _RecordCard(width: width, record: record),
        ],

        SizedBox(height: 16 * s),
        _ExportRow(width: width),
      ],
    );
  }
}

/// Cuánto historial guarda cada plan.
class _RetentionCard extends StatelessWidget {
  const _RetentionCard({
    required this.width,
    required this.visible,
    required this.total,
  });

  final double width;
  final int visible;
  final int total;

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
            'Ves $visible de $total viajes',
            style: TextStyle(
              fontFamily: AppFonts.headline,
              fontFamilyFallback: AppFonts.headlineFallback,
              fontSize: fluid(width, designSize: 26, min: 20, max: 30),
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 6 * s),
          Text(
            'El plan gratuito guarda $freeRetentionDays días. Con Plus se guardan para '
            'siempre, y puedes descargarlos cuando quieras.',
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

/// Un viaje del historial. Bloqueado si cayó fuera de los días del plan gratuito.
class _RecordCard extends StatelessWidget {
  const _RecordCard({required this.width, required this.record});

  final double width;
  final TripRecord record;

  @override
  Widget build(BuildContext context) {
    final s = scaleFor(width);

    if (record.locked) {
      return Opacity(
        opacity: 0.55,
        child: PlusCard(
          width: width,
          child: Row(
            children: [
              Icon(Icons.lock, size: 20 * s, color: AppColors.muted),
              SizedBox(width: 12 * s),
              Expanded(
                child: Text(
                  '${record.dayLabel} · disponible con Plus',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppFonts.button,
                    fontFamilyFallback: AppFonts.buttonFallback,
                    fontSize: fluid(width, designSize: 15, min: 12, max: 16),
                    color: AppColors.muted,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final color = journeyModeColor(record.mode);

    return PlusCard(
      width: width,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34 * s,
            height: 34 * s,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: SvgPicture.asset(
                journeyModeAsset(record.mode),
                width: 18 * s,
                height: 18 * s,
              ),
            ),
          ),
          SizedBox(width: 12 * s),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppFonts.button,
                    fontFamilyFallback: AppFonts.buttonFallback,
                    fontSize: fluid(width, designSize: 17, min: 14, max: 19),
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
                SizedBox(height: 4 * s),
                Text(
                  '${record.dayLabel}, ${formatClock(record.departureMinutes)} · '
                  '${formatDuration(record.durationMinutes)}',
                  style: TextStyle(
                    fontSize: fluid(width, designSize: 14, min: 12, max: 15),
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 2 * s),
                Text(
                  '${record.route} · ${record.unit}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: fluid(width, designSize: 13, min: 11, max: 14),
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Descargar el historial. En el mockup solo explica qué haría.
class _ExportRow extends StatelessWidget {
  const _ExportRow({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    final s = scaleFor(width);

    return SizedBox(
      height: math.max(46 * s, 46),
      child: OutlinedButton.icon(
        onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'En este mockup la exportación no está conectada: enseña el formato, no genera '
              'el archivo.',
            ),
          ),
        ),
        icon: Icon(Icons.description_outlined, size: 18 * s),
        label: Text(
          'Exportar PDF',
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
