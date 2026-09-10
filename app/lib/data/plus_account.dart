/// La cuenta MTAPP Plus: un solo conjunto de datos, tres vistas.
///
/// Las dos funcionalidades de pago no son dos productos que casualmente se cobran juntos —
/// son el mismo dato mirado desde tres lados, y este archivo es lo que lo hace cierto en el
/// código y no solo en el discurso:
///
/// - **La caja negra es la materia prima.** Los viajes guardados son los mismos de los que la
///   agenda dice haber aprendido; por eso [learnedFromTrips] sale de la semana y se enseña
///   también en el historial, en vez de ser dos números que hay que recordar cuadrar.
/// - **El viaje acompañado es un plan de la agenda.** No es un viaje aparte: [guardedTrip] se
///   *deriva* de [plan] con [GuardedTrip.fromPlan], así que la hora a la que se avisa a los
///   guardianes es la que la agenda calculó. Si mañana cambia el plan, cambia la alerta sola.
///
/// Eso último arregla de paso una duplicación que tenía la versión anterior: el texto del
/// disparador decía "si a las 9:57 no has llegado" a mano, mientras la tarjeta calculaba esa
/// hora. Ahora la calcula una sola vez, en [GuardedTrip.fromPlan].
///
/// Sigue siendo una demostración con datos fijos: ver `agenda.dart` y `safe_trip.dart`.
library;

import 'agenda.dart';
import 'rewards.dart';
import 'safe_trip.dart';

/// Todo lo que el plan de pago sabe del pasajero.
class PlusAccount {
  const PlusAccount({
    required this.week,
    required this.guardians,
    required this.tripLog,
    required this.rewards,
    required this.guardedDay,
    required this.guardedPlan,
    required this.unit,
    this.toleranceMinutes = 15,
  });

  final AgendaWeek week;
  final List<Guardian> guardians;
  final List<TripRecord> tripLog;

  /// Los centavos que se abonan por confirmar un abordaje. Los abonos salen de los mismos
  /// abordajes que llenan [tripLog]: otra vista del mismo dato, no una función aparte.
  final RewardsWallet rewards;

  /// Qué salida de la agenda va acompañada ahora mismo, por índice y no por copia: así el
  /// viaje acompañado no puede desincronizarse del plan que se ve en la otra pestaña.
  final int guardedDay;
  final int guardedPlan;

  /// La unidad en la que va. Es lo único que el viaje acompañado sabe y la agenda no: la
  /// agenda planea rutas, no unidades concretas.
  final String unit;

  /// Margen antes de avisar. Sin margen, un semáforo largo dispara una alarma, y a la tercera
  /// falsa nadie vuelve a hacerle caso.
  final int toleranceMinutes;

  /// El plan de la agenda que va acompañado.
  AgendaPlan get plan => week.days[guardedDay].plans[guardedPlan];

  /// Qué día de la semana es ese plan, para poder nombrarlo en la pestaña de guardianes.
  String get guardedDayName => week.days[guardedDay].name;

  /// El viaje acompañado, derivado del plan. Ver la nota de arriba.
  GuardedTrip get guardedTrip => GuardedTrip.fromPlan(
    plan,
    unit: unit,
    toleranceMinutes: toleranceMinutes,
  );

  /// Cuántos viajes hay detrás de todo esto. El mismo número en la agenda y en el historial,
  /// porque son los mismos viajes.
  int get learnedFromTrips => week.learnedFromTrips;

  /// Cuántos del historial se ven con el plan gratuito.
  int get visibleTrips => tripLog.where((record) => !record.locked).length;
}

/// La cuenta de la demostración.
///
/// El viaje acompañado es el regreso del lunes —"Trabajo → Casa", 6:40 p.m.— que es justo el
/// plan que la agenda enseña en su primera pestaña. Verlos coincidir es el punto.
const PlusAccount demoPlusAccount = PlusAccount(
  week: demoAgendaWeek,
  guardians: demoGuardians,
  tripLog: demoTripLog,
  rewards: demoRewards,
  guardedDay: 0,
  guardedPlan: 1,
  unit: 'Unidad 142',
);
