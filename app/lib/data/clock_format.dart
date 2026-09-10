/// Cómo se escriben horas y duraciones en la interfaz.
///
/// Vive aparte porque lo comparten las dos funcionalidades de pago —la agenda semanal y el
/// regreso seguro— y una hora escrita de dos formas distintas en la misma app se nota.
library;

/// Reloj de 12 horas, como se lee la hora en Morelia.
///
/// `intl` sabría hacerlo con la configuración regional, pero para una hora suelta sin fecha
/// alrededor esto es una línea y no arrastra un formateador por pantalla.
String formatClock(int minutesOfDay) {
  final hour24 = (minutesOfDay ~/ 60) % 24;
  final minute = minutesOfDay % 60;
  final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
  final suffix = hour24 < 12 ? 'a.m.' : 'p.m.';
  return '$hour12:${minute.toString().padLeft(2, '0')} $suffix';
}

/// Una duración en palabras: "28 min", "1 h 14 min".
String formatDuration(int minutes) {
  if (minutes < 60) return '$minutes min';
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  return rest == 0 ? '$hours h' : '$hours h $rest min';
}
