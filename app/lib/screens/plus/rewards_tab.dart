import 'package:flutter/material.dart';

import '../../data/clock_format.dart';
import '../../data/plus_account.dart';
import '../../data/rewards.dart';
import '../../theme.dart';
import '../../widgets/plus_widgets.dart';

/// Las recompensas, como pestaña de MTAPP Plus.
///
/// Cincuenta centavos por cada combi que confirmes, hasta cinco pesos al día —diez abordajes—, a
/// la tarjeta con la que ya pagas. **Nada de esto abona de verdad**: ver `rewards.dart`.
///
/// La pestaña carga tres ideas, en este orden y por esta razón:
///
/// 1. **Cuánto llevas.** Cincuenta centavos sueltos no parecen gran cosa; el saldo acumulado y
///    la proyección al mes es lo que lo vuelve tangible.
/// 2. **Cuánto te falta hoy.** La barra del tope no está para frustrar: enseña que queda
///    margen, y de paso explica el límite sin un instructivo.
/// 3. **Por qué te pagamos.** El argumento honesto —tu confirmación es la señal de demanda que
///    hace útil al sistema— va escrito, no escondido. Quien lo entiende confirma más, y es la
///    parte del proyecto que un jurado necesita oír.
class RewardsTab extends StatelessWidget {
  const RewardsTab({super.key, required this.width, required this.account});

  final double width;
  final PlusAccount account;

  @override
  Widget build(BuildContext context) {
    final s = scaleFor(width);
    final wallet = account.rewards;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _BalanceCard(width: width, wallet: wallet),

        SizedBox(height: 16 * s),
        _TodayCard(width: width, wallet: wallet),

        SizedBox(height: 16 * s),
        _WhyCard(width: width),

        SizedBox(height: 20 * s),
        PlusSectionTitle(width: width, text: 'Tus últimos abonos'),
        for (final entry in wallet.entries) ...[
          SizedBox(height: 10 * s),
          _EntryCard(width: width, entry: entry),
        ],

        SizedBox(height: 14 * s),
        Text(
          'Los abonos salen de los abordajes que confirmaste — los mismos viajes que guardas '
          'en la pestaña de al lado.',
          style: TextStyle(
            fontSize: fluid(width, designSize: 13, min: 11, max: 14),
            color: AppColors.muted,
            height: 1.35,
          ),
        ),
      ],
    );
  }
}

/// Lo acumulado y a dónde va.
class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.width, required this.wallet});

  final double width;
  final RewardsWallet wallet;

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
            'En tu tarjeta',
            style: TextStyle(
              fontSize: fluid(width, designSize: 15, min: 13, max: 16),
              color: Colors.white,
            ),
          ),
          SizedBox(height: 4 * s),
          Text(
            formatPesos(wallet.balanceCents),
            style: TextStyle(
              fontFamily: AppFonts.headline,
              fontFamilyFallback: AppFonts.headlineFallback,
              fontSize: fluid(width, designSize: 38, min: 28, max: 42),
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 6 * s),
          Text(
            'Abonado a la tarjeta ${wallet.cardUid}, la misma con la que pagas. A tu ritmo, '
            'unos ${formatPesos(wallet.monthlyProjectionCents)} al mes.',
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

/// Lo de hoy contra el tope.
class _TodayCard extends StatelessWidget {
  const _TodayCard({required this.width, required this.wallet});

  final double width;
  final RewardsWallet wallet;

  @override
  Widget build(BuildContext context) {
    final s = scaleFor(width);

    return PlusCard(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Hoy llevas ${formatPesos(wallet.todayCents, withCurrency: false)}',
                  style: TextStyle(
                    fontFamily: AppFonts.button,
                    fontFamilyFallback: AppFonts.buttonFallback,
                    fontSize: fluid(width, designSize: 18, min: 15, max: 20),
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
              ),
              SizedBox(width: 8 * s),
              Text(
                'de ${formatPesos(rewardDailyCapCents)}',
                style: TextStyle(
                  fontSize: fluid(width, designSize: 14, min: 12, max: 15),
                  color: AppColors.muted,
                ),
              ),
            ],
          ),

          SizedBox(height: 10 * s),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: wallet.todayProgress,
              minHeight: 10 * s,
              backgroundColor: AppColors.surfaceGrey,
              valueColor: const AlwaysStoppedAnimation(AppColors.green),
            ),
          ),

          SizedBox(height: 10 * s),
          Text(
            wallet.cappedToday
                ? 'Llegaste al tope de hoy. Mañana vuelve a contar desde cero.'
                : 'Te quedan ${formatPesos(wallet.remainingTodayCents)} por juntar hoy: '
                      '${formatCents(rewardCentsPerBoarding)} por cada combi que confirmes.',
            style: TextStyle(
              fontSize: fluid(width, designSize: 14, min: 12, max: 15),
              color: Colors.black87,
              height: 1.35,
            ),
          ),
          SizedBox(height: 6 * s),
          Text(
            'El tope de ${formatPesos(rewardDailyCapCents)} —${wallet.boardingsToCap} '
            'abordajes— existe para que a nadie le convenga subirse y bajarse nada más por '
            'juntar centavos.',
            style: TextStyle(
              fontSize: fluid(width, designSize: 13, min: 11, max: 14),
              color: AppColors.muted,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

/// Por qué la app paga por confirmar.
class _WhyCard extends StatelessWidget {
  const _WhyCard({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    final s = scaleFor(width);

    return PlusCard(
      width: width,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.volunteer_activism,
            size: 20 * s,
            color: AppColors.magenta,
          ),
          SizedBox(width: 10 * s),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '¿Por qué te pagamos por subirte?',
                  style: TextStyle(
                    fontFamily: AppFonts.button,
                    fontFamilyFallback: AppFonts.buttonFallback,
                    fontSize: fluid(width, designSize: 15, min: 13, max: 17),
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
                SizedBox(height: 6 * s),
                Text(
                  'Cuando confirmas que subiste, el sistema sabe cuánta gente usa esa ruta a '
                  'esa hora. Ese dato es el que le sirve al municipio para mandar más '
                  'unidades donde faltan. Solo cuenta en combi: el camión y el teleférico ya '
                  'lo registran con la tarjeta.',
                  style: TextStyle(
                    fontSize: fluid(width, designSize: 14, min: 12, max: 15),
                    color: Colors.black87,
                    height: 1.35,
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

/// Un abordaje: lo que abonó, o por qué no abonó.
class _EntryCard extends StatelessWidget {
  const _EntryCard({required this.width, required this.entry});

  final double width;
  final RewardEntry entry;

  @override
  Widget build(BuildContext context) {
    final s = scaleFor(width);
    final earned = entry.earned;

    return PlusCard(
      width: width,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34 * s,
            height: 34 * s,
            decoration: BoxDecoration(
              color: (earned ? AppColors.green : AppColors.muted).withValues(
                alpha: 0.18,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Icon(
                earned ? Icons.add : Icons.remove,
                size: 18 * s,
                color: earned ? AppColors.green : AppColors.muted,
              ),
            ),
          ),
          SizedBox(width: 12 * s),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.route,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppFonts.button,
                    fontFamilyFallback: AppFonts.buttonFallback,
                    fontSize: fluid(width, designSize: 16, min: 13, max: 18),
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
                SizedBox(height: 4 * s),
                Text(
                  '${entry.dayLabel}, ${formatClock(entry.minutesOfDay)} · ${entry.unit}',
                  style: TextStyle(
                    fontSize: fluid(width, designSize: 13, min: 11, max: 14),
                    color: AppColors.muted,
                  ),
                ),
                if (entry.skippedReason case final String reason) ...[
                  SizedBox(height: 4 * s),
                  Text(
                    reason,
                    style: TextStyle(
                      fontSize: fluid(width, designSize: 13, min: 11, max: 14),
                      color: AppColors.muted,
                      height: 1.3,
                    ),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(width: 8 * s),
          Text(
            earned ? '+${formatCents(entry.cents)}' : '—',
            style: TextStyle(
              fontFamily: AppFonts.button,
              fontFamilyFallback: AppFonts.buttonFallback,
              fontSize: fluid(width, designSize: 17, min: 14, max: 19),
              fontWeight: FontWeight.w700,
              color: earned ? AppColors.green : AppColors.muted,
            ),
          ),
        ],
      ),
    );
  }
}
