/// Genera `web/maps-key.js` a partir de `.env`.
///
/// La clave de Google Maps tiene que acabar dentro de una etiqueta `<script>` del HTML, y
/// `web/index.html` sí está en git. Para no meter la clave en el repositorio, el HTML carga un
/// archivo aparte —ignorado por git— que este script escribe desde `.env`.
///
/// Uso, desde `app/`:
///
/// ```
/// cp .env.example .env      # y pon tu clave dentro
/// dart run tool/write_maps_key.dart
/// ```
library;

import 'dart:io';

const String _variable = 'GOOGLE_MAPS_API_KEY';

void main() {
  final env = File('.env');
  if (!env.existsSync()) {
    _fail(
      'No encuentro `.env`.\n'
      'Copia `.env.example` a `.env` y pon ahí tu clave de Google Maps.',
    );
  }

  // `.env.example` es una plantilla y **sí** entra a git. Una clave ahí acaba en el
  // repositorio en el siguiente commit, así que se avisa fuerte: es el error fácil de cometer,
  // porque es el archivo que uno abre primero.
  final example = File('.env.example');
  if (example.existsSync()) {
    final stray = _readKey(example);
    if (stray != null && stray.isNotEmpty) {
      _fail('''
Hay una clave dentro de `.env.example`, y ese archivo SÍ entra a git.

Muévela a `.env` (que está ignorado) y deja la plantilla con el valor vacío:

    GOOGLE_MAPS_API_KEY=

Si ya la subiste a git, revócala en Google Cloud y saca otra: quitarla de un commit
posterior no la borra del historial.''');
    }
  }

  final key = _readKey(env);
  if (key == null || key.isEmpty) {
    _fail(
      'En `.env` falta $_variable, o está vacía.\n'
      'Saca una clave de Google Cloud con la "Maps JavaScript API" habilitada.',
    );
  }

  // `libraries=drawing` no es opcional: sin esa biblioteca el SDK web no dibuja polilíneas,
  // círculos ni marcadores, que es prácticamente todo lo que la app pinta sobre el mapa.
  final url =
      'https://maps.googleapis.com/maps/api/js'
      '?key=$key&libraries=drawing';

  // Se inyecta con `document.write` a propósito. Es la única forma de que el navegador cargue
  // la API **antes** de seguir parseando: `google_maps_flutter_web` necesita que `google.maps`
  // exista al crear el primer mapa, y un `<script async>` no lo garantiza. Es el caso para el
  // que document.write sigue siendo correcto — un script síncrono durante el parseo inicial.
  final contents =
      '''
// GENERADO por `dart run tool/write_maps_key.dart` desde .env
// No lo edites a mano y no lo subas a git: lleva la clave dentro.
document.write(
  '<script src="$url"><\\/script>'
);
''';

  final output = File('web/maps-key.js');
  output.writeAsStringSync(contents);

  final masked = key.length <= 8
      ? '*' * key.length
      : '${key.substring(0, 4)}...${key.substring(key.length - 4)}';
  stdout.writeln('Escrito ${output.path} con la clave $masked');
}

String? _readKey(File env) {
  for (final line in env.readAsLinesSync()) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#')) continue;

    final separator = trimmed.indexOf('=');
    if (separator == -1) continue;
    if (trimmed.substring(0, separator).trim() != _variable) continue;

    // Se aceptan comillas alrededor del valor: es costumbre en los .env y sorprende que no.
    var value = trimmed.substring(separator + 1).trim();
    if (value.length >= 2 &&
        ((value.startsWith('"') && value.endsWith('"')) ||
            (value.startsWith("'") && value.endsWith("'")))) {
      value = value.substring(1, value.length - 1);
    }
    return value;
  }
  return null;
}

Never _fail(String message) {
  stderr.writeln(message);
  exit(1);
}
