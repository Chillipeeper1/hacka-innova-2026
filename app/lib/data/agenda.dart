/// La agenda semanal de rutas: el plan que la app "aprende" de los viajes del pasajero.
///
/// **Esto no entrena ni consulta ningún modelo.** Es la demostración visual de la
/// funcionalidad de pago: la semana de abajo es un dato fijo, escrito a mano, sobre los mismos
/// puntos de Morelia que trae el seed del servidor (`server/src/data/seed-routes.json`). Sigue
/// la regla de `CLAUDE.md` —"cualquier predicción mostrada puede ser un valor fijo o una regla
/// simple"— y por eso vive en un solo archivo y no repartida por la pantalla: el día que exista
/// un motor de verdad, lo único que cambia es de dónde sale [demoAgendaWeek].
///
/// Que sea fijo no significa que pueda decir cualquier cosa. Los tiempos y los modos son
/// coherentes con lo que la app calcula en el resto de las pantallas —velocidades fijas por
/// modo, tramos a pie cortos para llegar a la parada— para que la demo no enseñe un viaje que
/// el motor real contradiga en la pantalla siguiente.
library;

import 'journey.dart';

// Las horas y duraciones se escriben igual aquí que en el regreso seguro, así que el formato
// vive en su propio archivo. Se reexporta para que quien ya importaba la agenda no se entere.
export 'clock_format.dart';

/// Un tramo del viaje planeado: con qué se recorre y cuánto dura.
class AgendaLeg {
  const AgendaLeg({
    required this.mode,
    required this.label,
    required this.minutes,
  });

  final JourneyMode mode;

  /// Qué se toma: el nombre de la ruta, o hacia dónde se camina.
  final String label;

  final int minutes;
}

/// El atajo que la agenda propone para un viaje.
///
/// Es lo que distingue a la agenda de un itinerario cualquiera: no dice solo cómo llegar, dice
/// qué hacer distinto de lo que el pasajero ya hace.
class AgendaShortcut {
  const AgendaShortcut({required this.label, required this.savedMinutes});

  final String label;

  /// Minutos que ahorra contra la costumbre del pasajero.
  final int savedMinutes;
}

/// Un viaje planeado: a qué hora salir, cuánto tarda y por dónde.
class AgendaPlan {
  const AgendaPlan({
    required this.title,
    required this.departureMinutes,
    required this.durationMinutes,
    required this.legs,
    required this.confidence,
    required this.learnedFrom,
    this.shortcut,
    this.note,
  });

  /// Origen y destino en una línea: "Casa → Trabajo".
  final String title;

  /// Hora de salida óptima, en minutos desde la medianoche.
  final int departureMinutes;

  final int durationMinutes;

  final List<AgendaLeg> legs;

  /// Qué tan segura está la agenda de este plan, de 0 a 100.
  ///
  /// Se enseña porque una recomendación sin margen se lee como una promesa: un 68 % le dice al
  /// pasajero que ese viaje todavía es una corazonada, y un 92 % que no.
  final int confidence;

  /// De cuántos viajes suyos salió. Sin esto, la agenda parece adivinación.
  final int learnedFrom;

  final AgendaShortcut? shortcut;

  /// Aviso puntual del día: un tianguis, una obra, una costumbre propia.
  final String? note;

  /// Hora de llegada, que es lo que en realidad importa cuando hay que estar a las 8:00.
  int get arrivalMinutes => departureMinutes + durationMinutes;

  /// A dónde va: la mitad derecha del título. Lo usa el viaje acompañado, que nombra el
  /// destino solo y no el par origen-destino.
  String get destination {
    final parts = title.split('→');
    return parts.length > 1 ? parts.last.trim() : title.trim();
  }
}

/// Un día de la semana con sus viajes.
class AgendaDay {
  const AgendaDay({
    required this.name,
    required this.initial,
    required this.plans,
    this.restLabel,
  });

  final String name;

  /// La letra del selector de arriba.
  final String initial;

  final List<AgendaPlan> plans;

  /// Qué decir cuando no hay viajes. Un día vacío sin explicación se lee como una falla.
  final String? restLabel;

  bool get isRest => plans.isEmpty;

  /// Lo que dura el día completo puerta a puerta, para el resumen del encabezado.
  int get totalMinutes =>
      plans.fold(0, (sum, plan) => sum + plan.durationMinutes);
}

/// La semana completa.
class AgendaWeek {
  const AgendaWeek({
    required this.days,
    required this.learnedFromTrips,
    required this.savedMinutes,
    required this.updatedLabel,
  });

  final List<AgendaDay> days;

  /// Cuántos viajes suyos hay detrás de toda la agenda.
  final int learnedFromTrips;

  /// Minutos que la semana planeada ahorra contra la costumbre del pasajero.
  final int savedMinutes;

  /// Cuándo se rehizo la agenda, ya en palabras: "hoy a las 5:00 a.m.".
  final String updatedLabel;

  /// El día que se abre primero: el primero que tenga viajes.
  int get firstBusyDay {
    final index = days.indexWhere((day) => !day.isRest);
    return index == -1 ? 0 : index;
  }
}

/// La semana de la demostración.
///
/// El pasajero de ejemplo vive por el Acueducto, trabaja en el centro y los sábados va al
/// mercado. Los lugares son los del seed —Catedral, Tarascas, Acueducto, Bosque Cuauhtémoc,
/// Central de Autobuses— para que lo que se lee aquí exista también en el mapa de la app.
const AgendaWeek demoAgendaWeek = AgendaWeek(
  learnedFromTrips: 47,
  savedMinutes: 74,
  updatedLabel: 'hoy a las 5:00 a.m.',
  days: [
    AgendaDay(
      name: 'Lunes',
      initial: 'L',
      plans: [
        AgendaPlan(
          title: 'Casa → Trabajo',
          departureMinutes: 435, // 7:15 a.m.
          durationMinutes: 28,
          confidence: 92,
          learnedFrom: 11,
          legs: [
            AgendaLeg(
              mode: JourneyMode.walk,
              label: 'A la parada del Acueducto',
              minutes: 6,
            ),
            AgendaLeg(
              mode: JourneyMode.combi,
              label: 'Ruta Centro - Acueducto',
              minutes: 17,
            ),
            AgendaLeg(
              mode: JourneyMode.walk,
              label: 'De Catedral a la oficina',
              minutes: 5,
            ),
          ],
          shortcut: AgendaShortcut(
            label:
                'Sube en Fuente de las Tarascas, no en el Acueducto: la combi pasa con lugar '
                'y te ahorras la espera larga.',
            savedMinutes: 6,
          ),
        ),
        AgendaPlan(
          title: 'Trabajo → Casa',
          departureMinutes: 1120, // 6:40 p.m.
          durationMinutes: 34,
          confidence: 84,
          learnedFrom: 9,
          legs: [
            AgendaLeg(
              mode: JourneyMode.walk,
              label: 'A la parada de Catedral',
              minutes: 5,
            ),
            AgendaLeg(
              mode: JourneyMode.combi,
              label: 'Ruta Centro - Acueducto',
              minutes: 23,
            ),
            AgendaLeg(
              mode: JourneyMode.walk,
              label: 'Del Acueducto a casa',
              minutes: 6,
            ),
          ],
          note:
              'A las 6:00 p.m. el centro va lleno. Saliendo 40 min después llegas casi a la '
              'misma hora y viajas sentado.',
        ),
      ],
    ),
    AgendaDay(
      name: 'Martes',
      initial: 'M',
      plans: [
        AgendaPlan(
          title: 'Casa → Trabajo',
          departureMinutes: 440, // 7:20 a.m.
          durationMinutes: 25,
          confidence: 88,
          learnedFrom: 10,
          legs: [
            AgendaLeg(
              mode: JourneyMode.bike,
              label: 'Por la ciclovía del Acueducto',
              minutes: 19,
            ),
            AgendaLeg(
              mode: JourneyMode.walk,
              label: 'De Tarascas a la oficina',
              minutes: 6,
            ),
          ],
          shortcut: AgendaShortcut(
            label:
                'Los martes sales sin prisa y no ha llovido ninguno de las últimas seis '
                'semanas: la bici le gana a la combi.',
            savedMinutes: 4,
          ),
        ),
        AgendaPlan(
          title: 'Trabajo → Casa',
          departureMinutes: 1090, // 6:10 p.m.
          durationMinutes: 22,
          confidence: 81,
          learnedFrom: 8,
          legs: [
            AgendaLeg(
              mode: JourneyMode.bike,
              label: 'De regreso por la ciclovía',
              minutes: 22,
            ),
          ],
        ),
      ],
    ),
    AgendaDay(
      name: 'Miércoles',
      initial: 'M',
      plans: [
        AgendaPlan(
          title: 'Casa → Trabajo',
          departureMinutes: 425, // 7:05 a.m.
          durationMinutes: 33,
          confidence: 90,
          learnedFrom: 11,
          legs: [
            AgendaLeg(
              mode: JourneyMode.walk,
              label: 'A la parada del Acueducto',
              minutes: 6,
            ),
            AgendaLeg(
              mode: JourneyMode.combi,
              label: 'Ruta Centro - Acueducto',
              minutes: 21,
            ),
            AgendaLeg(
              mode: JourneyMode.walk,
              label: 'Rodeando el tianguis de Madero',
              minutes: 6,
            ),
          ],
          note:
              'Miércoles de tianguis en Madero: sal 10 min antes, que el tramo a pie se '
              'alarga.',
        ),
        AgendaPlan(
          title: 'Trabajo → Bosque Cuauhtémoc',
          departureMinutes: 1065, // 5:45 p.m.
          durationMinutes: 19,
          confidence: 71,
          learnedFrom: 5,
          legs: [
            AgendaLeg(
              mode: JourneyMode.walk,
              label: 'A la parada de Catedral',
              minutes: 5,
            ),
            AgendaLeg(
              mode: JourneyMode.bus,
              label: 'Ruta Centro - Bosque',
              minutes: 14,
            ),
          ],
          shortcut: AgendaShortcut(
            label:
                'El camión de las 5:52 sale de Catedral casi vacío; el de las 6:10 ya viene '
                'lleno desde la primera parada.',
            savedMinutes: 5,
          ),
        ),
      ],
    ),
    AgendaDay(
      name: 'Jueves',
      initial: 'J',
      plans: [
        AgendaPlan(
          title: 'Casa → Trabajo',
          departureMinutes: 435, // 7:15 a.m.
          durationMinutes: 28,
          confidence: 89,
          learnedFrom: 10,
          legs: [
            AgendaLeg(
              mode: JourneyMode.walk,
              label: 'A la parada del Acueducto',
              minutes: 6,
            ),
            AgendaLeg(
              mode: JourneyMode.combi,
              label: 'Ruta Centro - Acueducto',
              minutes: 17,
            ),
            AgendaLeg(
              mode: JourneyMode.walk,
              label: 'De Catedral a la oficina',
              minutes: 5,
            ),
          ],
        ),
        AgendaPlan(
          title: 'Trabajo → Central de Autobuses',
          departureMinutes: 1145, // 7:05 p.m.
          durationMinutes: 31,
          confidence: 68,
          learnedFrom: 4,
          legs: [
            AgendaLeg(
              mode: JourneyMode.walk,
              label: 'A la parada de Catedral',
              minutes: 5,
            ),
            AgendaLeg(
              mode: JourneyMode.bus,
              label: 'Ruta Centro - Bosque',
              minutes: 14,
            ),
            AgendaLeg(
              mode: JourneyMode.cableCar,
              label: 'Teleférico a la Central',
              minutes: 12,
            ),
          ],
          shortcut: AgendaShortcut(
            label:
                'Transborda al teleférico en Bosque Cuauhtémoc en vez de seguir en camión: '
                'te saltas el rodeo por el libramiento.',
            savedMinutes: 13,
          ),
        ),
      ],
    ),
    AgendaDay(
      name: 'Viernes',
      initial: 'V',
      plans: [
        AgendaPlan(
          title: 'Casa → Trabajo',
          departureMinutes: 445, // 7:25 a.m.
          durationMinutes: 30,
          confidence: 86,
          learnedFrom: 10,
          legs: [
            AgendaLeg(
              mode: JourneyMode.walk,
              label: 'A la parada del Acueducto',
              minutes: 6,
            ),
            AgendaLeg(
              mode: JourneyMode.combi,
              label: 'Ruta Centro - Acueducto',
              minutes: 19,
            ),
            AgendaLeg(
              mode: JourneyMode.walk,
              label: 'De Catedral a la oficina',
              minutes: 5,
            ),
          ],
          note:
              'Los viernes sales 10 min más tarde que el resto de la semana. La agenda ya '
              'cuenta con eso.',
        ),
        AgendaPlan(
          title: 'Trabajo → Centro',
          departureMinutes: 1215, // 8:15 p.m.
          durationMinutes: 12,
          confidence: 64,
          learnedFrom: 3,
          legs: [
            AgendaLeg(
              mode: JourneyMode.walk,
              label: 'Por Madero hasta Tarascas',
              minutes: 12,
            ),
          ],
          shortcut: AgendaShortcut(
            label:
                'A esa hora Madero está cerrado al tráfico: caminando llegas antes que '
                'esperando la combi.',
            savedMinutes: 7,
          ),
        ),
      ],
    ),
    AgendaDay(
      name: 'Sábado',
      initial: 'S',
      plans: [
        AgendaPlan(
          title: 'Casa → Mercado Independencia',
          departureMinutes: 570, // 9:30 a.m.
          durationMinutes: 26,
          confidence: 77,
          learnedFrom: 6,
          legs: [
            AgendaLeg(
              mode: JourneyMode.walk,
              label: 'A la parada del Acueducto',
              minutes: 6,
            ),
            AgendaLeg(
              mode: JourneyMode.combi,
              label: 'Ruta Centro - Acueducto',
              minutes: 15,
            ),
            AgendaLeg(
              mode: JourneyMode.walk,
              label: 'De Catedral al mercado',
              minutes: 5,
            ),
          ],
          shortcut: AgendaShortcut(
            label:
                'Antes de las 10:00 la combi tarda 8 min menos que a mediodía, que es cuando '
                'tú sueles ir.',
            savedMinutes: 8,
          ),
        ),
      ],
    ),
    AgendaDay(
      name: 'Domingo',
      initial: 'D',
      plans: [],
      restLabel:
          'No tenemos salidas tuyas en domingo. Si sales, la agenda aprende y el próximo '
          'domingo ya aparece aquí.',
    ),
  ],
);
