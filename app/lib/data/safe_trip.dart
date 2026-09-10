/// Regreso seguro: el viaje acompañado y la caja negra del viaje.
///
/// **Es la demostración visual de la segunda funcionalidad de pago, con datos fijos.** Nada de
/// esto manda un mensaje, guarda un historial ni contacta a nadie: la semana pasada no existe,
/// los guardianes son inventados y el "aviso" que se enseña nunca sale del teléfono. Misma
/// regla que la agenda —ver `agenda.dart`— y misma promesa: el día que haya servidor detrás,
/// lo único que cambia es de dónde salen [demoGuardians] y [demoTripLog].
///
/// Dos cosas que el modelo sí decide, y que no son cosméticas:
///
/// - **El botón de pánico no es de pago.** Va marcado como incluido en el plan gratuito
///   ([panicButtonIsFree]). Cobrar por un botón de pánico en una ciudad con problemas reales
///   de seguridad es la crítica más fácil que le pueden hacer al proyecto, y tendría razón.
///   Lo que se cobra es lo que va alrededor: la red de guardianes, el aviso automático y el
///   respaldo del viaje.
/// - **La caja negra se corta por tiempo, no por función.** El plan gratuito guarda
///   [freeRetentionDays] días y el de pago no borra ([plusKeepsForever]). El pasajero ve sus
///   viajes recientes completos y los viejos bloqueados: la diferencia se entiende sin leer
///   una tabla de precios.
library;

import 'agenda.dart';
import 'journey.dart';

export 'clock_format.dart';

/// El botón de pánico está incluido en el plan gratuito. Ver la nota de arriba.
const bool panicButtonIsFree = true;

/// Cuánto historial guarda el plan gratuito.
const int freeRetentionDays = 7;

/// El plan de pago no borra: los viajes se guardan mientras exista la cuenta.
///
/// Un tope en meses obliga al pasajero a calcular si el viaje que busca todavía existe, y a
/// enterarse de que no cuando ya lo necesita. "Para siempre" es una promesa más simple de
/// entender y más fácil de cumplir: guardar texto de un viaje no cuesta casi nada.
const bool plusKeepsForever = true;

/// Alguien que recibe el aviso si algo sale mal.
class Guardian {
  const Guardian({
    required this.name,
    required this.relation,
    required this.active,
  });

  final String name;

  /// Quién es: "Mamá", "Roomie". Sin esto la lista es un directorio, y lo que importa es a
  /// quién le va a sonar el teléfono a las 10 de la noche.
  final String relation;

  /// Apagado también es una elección legítima: no a todos se les avisa de todos los viajes.
  final bool active;
}

/// Una condición que dispara el aviso a los guardianes.
///
/// Se enumeran en la pantalla, y ese es el punto: lo que se paga no es compartir la ubicación
/// —eso ya es gratis en cualquier mensajero— sino que el sistema vigile solo. Nadie mira un
/// enlace en vivo durante cuarenta minutos.
class TripTrigger {
  const TripTrigger({required this.label, required this.detail});

  final String label;
  final String detail;
}

/// En qué va el viaje acompañado.
enum GuardedTripStatus {
  /// Todo normal: falta llegar.
  onTheWay,

  /// Se pasó el margen y ya se avisó. Es el estado que la demo sabe provocar.
  alerted,

  /// Llegó, y los guardianes ya lo saben sin que el pasajero hiciera nada.
  arrived,
}

/// El viaje que va acompañado ahora mismo.
class GuardedTrip {
  const GuardedTrip({
    required this.title,
    required this.destination,
    required this.departureMinutes,
    required this.arrivalMinutes,
    required this.toleranceMinutes,
    required this.route,
    required this.unit,
    required this.triggers,
  });

  /// "A casa", "Al trabajo".
  final String title;

  final String destination;

  final int departureMinutes;

  /// A qué hora se espera llegar.
  final int arrivalMinutes;

  /// Margen antes de avisar. Sin margen, cualquier semáforo largo dispara una alarma y a la
  /// tercera falsa nadie vuelve a hacerle caso.
  final int toleranceMinutes;

  final String route;

  /// La unidad en la que va. Es el dato que hace útil el aviso: sin él, "no llegó" no le sirve
  /// de nada a quien lo recibe.
  final String unit;

  final List<TripTrigger> triggers;

  /// Deriva el viaje acompañado de un plan de la agenda.
  ///
  /// Es lo que ata las dos funcionalidades: la hora a la que se avisa a los guardianes es la
  /// que la agenda calculó para ese viaje, no un dato aparte que haya que mantener a mano. El
  /// texto del primer disparador se genera aquí por lo mismo — antes decía la hora escrita a
  /// mano y podía contradecir a la tarjeta que la calculaba.
  factory GuardedTrip.fromPlan(
    AgendaPlan plan, {
    required String unit,
    required int toleranceMinutes,
  }) {
    // El tramo que da nombre al viaje es el del transporte, no la caminata de conexión.
    final ride = plan.legs.firstWhere(
      (leg) => leg.mode != JourneyMode.walk,
      orElse: () => plan.legs.first,
    );
    final alertAt = plan.arrivalMinutes + toleranceMinutes;

    return GuardedTrip(
      title: plan.title,
      destination: plan.destination,
      departureMinutes: plan.departureMinutes,
      arrivalMinutes: plan.arrivalMinutes,
      toleranceMinutes: toleranceMinutes,
      route: ride.label,
      unit: unit,
      triggers: [
        TripTrigger(
          label: 'No llegas a tiempo',
          detail:
              'Si a las ${formatClock(alertAt)} no has llegado —lo que tu agenda calcula '
              'más $toleranceMinutes min de margen— se avisa solo.',
        ),
        const TripTrigger(
          label: 'Te bajas donde no era',
          detail:
              'Si te alejas de la ruta que haces siempre a esta hora, tus guardianes lo ven '
              'en el momento.',
        ),
        const TripTrigger(
          label: 'El viaje se detiene de más',
          detail: 'Más de 10 min sin avanzar fuera de una parada conocida.',
        ),
      ],
    );
  }

  /// La hora a la que se avisa si no ha llegado.
  int get alertAtMinutes => arrivalMinutes + toleranceMinutes;

  int get durationMinutes => arrivalMinutes - departureMinutes;
}

/// Un viaje guardado en la caja negra.
class TripRecord {
  const TripRecord({
    required this.dayLabel,
    required this.title,
    required this.route,
    required this.unit,
    required this.mode,
    required this.departureMinutes,
    required this.durationMinutes,
    this.locked = false,
  });

  /// Cuándo fue, ya en palabras: "Hoy", "Ayer", "Hace 12 días".
  final String dayLabel;

  final String title;
  final String route;
  final String unit;
  final JourneyMode mode;
  final int departureMinutes;
  final int durationMinutes;

  /// Fuera de los [freeRetentionDays] días del plan gratuito: se ve que existe, no se ve qué
  /// fue. Es el muro de pago hecho visible en vez de explicado.
  final bool locked;
}

/// Los guardianes de la demostración.
const List<Guardian> demoGuardians = [
  Guardian(name: 'Mamá', relation: 'Familia', active: true),
  Guardian(name: 'Ana', relation: 'Roomie', active: true),
  Guardian(name: 'Luis', relation: 'Hermano', active: false),
];

/// Lo que se manda cuando salta el aviso.
///
/// Se enumera en la pantalla a propósito: una alerta que no dice qué compartió es una alerta
/// en la que no se confía, y quien la recibe necesita saber qué tiene en la mano.
const List<String> demoAlertPayload = [
  'Tu última ubicación conocida',
  'La ruta y la unidad en la que ibas (Ruta Centro - Acueducto, unidad 142)',
  'A qué hora saliste y a qué hora debías llegar',
];

/// El historial de la caja negra.
///
/// **Son los mismos viajes de los que la agenda dice haber aprendido**: los tres visibles
/// espejan planes que la agenda enseña, con su ruta, su hora y su duración. Que cuadren es lo
/// que hace que las dos funcionalidades se lean como un producto y no como dos.
///
/// Los tres primeros caen dentro de los [freeRetentionDays] días del plan gratuito; el resto
/// va bloqueado. La mezcla es el argumento de venta: no hay que explicar la diferencia, se ve.
const List<TripRecord> demoTripLog = [
  TripRecord(
    dayLabel: 'Hoy',
    title: 'Casa → Trabajo',
    route: 'Ruta Centro - Acueducto',
    unit: 'Unidad 118',
    mode: JourneyMode.combi,
    departureMinutes:
        435, // 7:15 a.m., el mismo plan que la agenda enseña del lunes
    durationMinutes: 28,
  ),
  TripRecord(
    dayLabel: 'Ayer',
    title: 'Trabajo → Casa',
    route: 'Ruta Centro - Acueducto',
    unit: 'Unidad 142',
    mode: JourneyMode.combi,
    departureMinutes: 1120, // 6:40 p.m.
    durationMinutes: 34,
  ),
  TripRecord(
    dayLabel: 'Hace 4 días',
    title: 'Trabajo → Bosque Cuauhtémoc',
    route: 'Ruta Centro - Bosque',
    unit: 'Unidad 07',
    mode: JourneyMode.bus,
    departureMinutes: 1065, // 5:45 p.m.
    durationMinutes: 19,
  ),
  TripRecord(
    dayLabel: 'Hace 12 días',
    title: 'Viaje guardado',
    route: '',
    unit: '',
    mode: JourneyMode.combi,
    departureMinutes: 0,
    durationMinutes: 0,
    locked: true,
  ),
  TripRecord(
    dayLabel: 'Hace 1 mes',
    title: 'Viaje guardado',
    route: '',
    unit: '',
    mode: JourneyMode.bus,
    departureMinutes: 0,
    durationMinutes: 0,
    locked: true,
  ),
  TripRecord(
    dayLabel: 'Hace 3 meses',
    title: 'Viaje guardado',
    route: '',
    unit: '',
    mode: JourneyMode.cableCar,
    departureMinutes: 0,
    durationMinutes: 0,
    locked: true,
  ),
];
