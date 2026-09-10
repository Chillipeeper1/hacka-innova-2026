/// Recompensas: los centavos que se abonan a la tarjeta por confirmar un abordaje.
///
/// **Es una demostración con datos fijos**, como el resto de MTAPP Plus: aquí no se abona
/// nada a ninguna tarjeta real, ni existe la integración con el sistema de cobro de
/// Sedum/Morebús —`CLAUDE.md` la deja explícitamente fuera de esta fase—. Lo que se enseña es
/// la mecánica.
///
/// **Por qué la app le paga al pasajero por subirse.** No es un cupón de descuento disfrazado:
/// la confirmación de abordaje es *el* diferenciador del proyecto — es la señal de demanda que
/// alimenta el panel institucional, que es lo que sostiene el modelo de negocio. Sin
/// confirmaciones no hay dato que vender. Pagar cincuenta centavos por cada una es comprar
/// directamente lo único que el sistema necesita del pasajero, y por eso el argumento se dice
/// en la pantalla en vez de esconderlo: quien lo entiende confirma más.
///
/// **Por qué solo combi.** El camión y el teleférico ya cobran con la tarjeta de movilidad, así
/// que de ellos ya hay registro de abordaje sin pedirle nada a nadie. La combi es justo donde
/// el dato no existe y donde los concesionarios apenas se están sumando al sistema — es ahí
/// donde vale la pena pagar por la señal.
///
/// **Por qué hay tope diario.** Sin él, el incentivo se vuelve un juego: subirse y bajarse en
/// la misma esquina para juntar centavos ensucia exactamente el dato que se está tratando de
/// comprar. [rewardDailyCapCents] es la barrera, y está muy por encima del día de quien solo
/// se mueve: diez abordajes es un día entero subiéndose a combis a propósito.
library;

import 'dart:math' as math;

/// Lo que se abona por cada combi confirmada.
const int rewardCentsPerBoarding = 50;

/// Tope de lo que se puede juntar en un día, en centavos.
///
/// Cinco pesos son diez abordajes. Un día normal —ida y vuelta, dos combis— cabe cinco veces
/// dentro del tope, así que solo topa quien se sube de más. Es una barrera contra el abuso,
/// no una meta.
const int rewardDailyCapCents = 500;

/// Un abono —o un abordaje que no lo generó, y por qué.
class RewardEntry {
  const RewardEntry({
    required this.dayLabel,
    required this.minutesOfDay,
    required this.route,
    required this.unit,
    required this.cents,
    this.skippedReason,
  });

  /// Cuándo fue, en palabras: "Hoy", "Ayer".
  final String dayLabel;

  final int minutesOfDay;
  final String route;
  final String unit;

  /// Cuánto se abonó. Cero cuando el abordaje no aplicaba.
  final int cents;

  /// Por qué no se abonó, cuando no se abonó.
  ///
  /// Se enseña en vez de omitir el renglón: un abordaje que desaparece de la lista parece un
  /// error del sistema, y uno que explica por qué no pagó enseña la regla sin un instructivo.
  final String? skippedReason;

  bool get earned => cents > 0;
}

/// El monedero de recompensas del pasajero.
class RewardsWallet {
  const RewardsWallet({
    required this.cardUid,
    required this.balanceCents,
    required this.todayCents,
    required this.dailyAverageCents,
    required this.entries,
  });

  /// La tarjeta a la que se abona. El mismo identificador de ejemplo que el seed del servidor.
  final String cardUid;

  /// Lo acumulado que todavía no se gasta.
  final int balanceCents;

  /// Lo juntado hoy, contra [rewardDailyCapCents].
  final int todayCents;

  /// Lo que junta en un día normal. De aquí sale la proyección mensual, que es lo que hace
  /// tangible un abono de cincuenta centavos: suelto no parece gran cosa, al mes sí.
  final int dailyAverageCents;

  final List<RewardEntry> entries;

  int get remainingTodayCents => math.max(rewardDailyCapCents - todayCents, 0);

  bool get cappedToday => todayCents >= rewardDailyCapCents;

  double get todayProgress =>
      (todayCents / rewardDailyCapCents).clamp(0.0, 1.0);

  /// Lo que juntaría en un mes a su ritmo.
  int get monthlyProjectionCents => dailyAverageCents * 30;

  /// Cuántos abordajes de hoy alcanzan el tope, para poder decirlo en palabras.
  int get boardingsToCap => rewardDailyCapCents ~/ rewardCentsPerBoarding;
}

/// Una cantidad en pesos mexicanos: "$87.50 MXN".
///
/// El "MXN" no sobra: un "$5.00" a secas se lee como cinco dólares, y el tope diario —que son
/// cinco pesos— parecía veinte veces más grande de lo que es.
///
/// [withCurrency] lo apaga donde el marcador ya viene en el mismo renglón: "Hoy llevas $1.50"
/// junto a "de $5.00 MXN" se lee mejor que repetir "MXN" dos veces en una línea.
String formatPesos(int cents, {bool withCurrency = true}) =>
    '\$${(cents / 100).toStringAsFixed(2)}${withCurrency ? ' MXN' : ''}';

/// Una cantidad chica, como se dice de viva voz: "50¢".
String formatCents(int cents) => '$cents¢';

/// El monedero de la demostración.
///
/// El saldo cuadra con el ritmo: un peso al día —ida y vuelta en combi— durante unos tres
/// meses. Los abordajes son de las mismas rutas y unidades que aparecen en la caja negra — son
/// los mismos viajes, vistos desde el lado del abono.
///
/// Hoy lleva tres abordajes, lejos del tope a propósito: la barra tiene que verse avanzar y el
/// renglón de "te quedan" tiene que tener algo que decir. Un día ya topado no enseña ninguna de
/// las dos cosas.
const RewardsWallet demoRewards = RewardsWallet(
  cardUid: 'DEMO-0001',
  balanceCents: 8750,
  todayCents: 150,
  dailyAverageCents: 100,
  entries: [
    RewardEntry(
      dayLabel: 'Hoy',
      minutesOfDay: 1120, // 6:40 p.m.
      route: 'Ruta Centro - Acueducto',
      unit: 'Unidad 142',
      cents: rewardCentsPerBoarding,
    ),
    RewardEntry(
      dayLabel: 'Hoy',
      minutesOfDay: 820, // 1:40 p.m.
      route: 'Ruta Centro - Acueducto',
      unit: 'Unidad 233',
      cents: rewardCentsPerBoarding,
    ),
    RewardEntry(
      dayLabel: 'Hoy',
      minutesOfDay: 435, // 7:15 a.m.
      route: 'Ruta Centro - Acueducto',
      unit: 'Unidad 118',
      cents: rewardCentsPerBoarding,
    ),
    // El que enseña la regla sin explicarla: un camión no abona.
    RewardEntry(
      dayLabel: 'Ayer',
      minutesOfDay: 1065, // 5:45 p.m.
      route: 'Ruta Centro - Bosque',
      unit: 'Unidad 07',
      cents: 0,
      skippedReason: 'El camión ya registra tu abordaje con la tarjeta.',
    ),
    RewardEntry(
      dayLabel: 'Ayer',
      minutesOfDay: 435, // 7:15 a.m.
      route: 'Ruta Centro - Acueducto',
      unit: 'Unidad 118',
      cents: rewardCentsPerBoarding,
    ),
  ],
);
