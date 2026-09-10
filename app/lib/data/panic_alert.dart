/// El botón de pánico: la alerta que el pasajero dispara con la mano.
///
/// **Demostración visual con datos fijos, igual que el resto de `data/`.** Nada de esto manda
/// un mensaje, marca un teléfono ni avisa a nadie: lo único que ocurre de verdad es que la
/// app cambia de estado y lo enseña. El día que haya servidor detrás, lo que cambia es el
/// cuerpo de [PanicAlertController.fire] — un `POST`; el gesto, la hoja y los textos siguen
/// igual. **No hay endpoint de pánico en el contrato** (`CLAUDE.md`), así que agregarlo es una
/// conversación con el equipo de backend, no un detalle de esta pantalla.
///
/// Dos decisiones del modelo que no son cosméticas:
///
/// - **Va gratis y solo durante el viaje.** Gratis por lo que ya dice `safe_trip.dart`; solo
///   durante el viaje porque fuera de uno la alerta no tendría qué contar — sin ruta, sin
///   unidad y sin hora de llegada, "algo me pasó" no le sirve a quien lo recibe.
/// - **Se dispara sosteniendo, no tocando.** Tres segundos ([panicHoldDuration]) con el dedo
///   encima. Un toque suelto en la bolsa mandaría alertas falsas, y a la tercera nadie vuelve
///   a hacerle caso; un diálogo de confirmación mete una pantalla que leer en el peor momento
///   posible. Sostener resuelve las dos cosas con el mismo gesto.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'safe_trip.dart';

export 'safe_trip.dart' show Guardian, panicButtonIsFree;

/// Cuánto hay que sostener el botón para que salga la alerta. Ver la nota de arriba.
const Duration panicHoldDuration = Duration(seconds: 3);

/// El número de emergencia al que llegaría la alerta donde exista el enlace con el C5.
///
/// "Donde exista" es literal: el enlace con el C5 es un acuerdo que hoy no está firmado, y la
/// interfaz no debe prometer lo contrario. Ver [panicRecipients].
const String emergencyNumber = '911';

/// Una alerta de pánico en curso.
class PanicAlert {
  const PanicAlert({required this.trip, required this.firedAt});

  /// En qué viaje iba cuando la disparó, tal como lo describe la pantalla desde la que se
  /// mandó: "Ruta Centro - Acueducto, hacia el Acueducto", "A pie hacia tu destino".
  ///
  /// Es el dato que hace útil el aviso. Sin él queda "algo me pasó", que no le dice a nadie
  /// dónde buscar.
  final String trip;

  final DateTime firedAt;
}

/// La alerta activa, o `null` si no hay ninguna.
///
/// Vive en un provider y no en la pantalla porque el viaje cambia de pantalla —de esperar la
/// unidad a ir a bordo— y la alerta no debería apagarse al pasar de una a otra. Solo la apaga
/// el pasajero, diciendo que fue falsa alarma.
class PanicAlertController extends Notifier<PanicAlert?> {
  @override
  PanicAlert? build() => null;

  void fire(String trip) =>
      state = PanicAlert(trip: trip, firedAt: DateTime.now());

  /// Falsa alarma: se apaga. En el sistema real esto también avisaría a quien ya se enteró —
  /// una alerta que se cancela en silencio deja a los contactos esperando.
  void cancel() => state = null;
}

final panicAlertProvider = NotifierProvider<PanicAlertController, PanicAlert?>(
  PanicAlertController.new,
);

/// Qué se comparte al disparar la alerta.
///
/// Se enumera en la hoja a propósito, con el mismo criterio que [demoAlertPayload]: quien la
/// manda tiene derecho a saber qué acaba de salir de su teléfono.
List<String> panicAlertPayload(String trip) => [
  'Tu ubicación en este momento, y a dónde te vas moviendo',
  trip,
  'La hora a la que pediste ayuda',
];

/// Quién recibe la alerta.
///
/// Los mismos contactos de la pestaña de guardianes, pero por otra razón: aquí no se cobra
/// nada. Lo de pago es que el sistema avise **solo** cuando algo sale mal; que el pasajero
/// pida ayuda con su propia mano es gratis y no lleva etiqueta de plan.
List<Guardian> get panicRecipients =>
    demoGuardians.where((guardian) => guardian.active).toList();
