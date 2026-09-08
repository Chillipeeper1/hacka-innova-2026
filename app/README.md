# app/ — Pasajero y conductor (Flutter)

App móvil del mockup. Corre en Android, iOS y web.

```
flutter pub get
flutter run              # dispositivo o emulador
flutter run -d chrome    # lo más rápido para iterar la UI
flutter analyze
flutter test
```

## Qué hay hoy

Cinco pantallas, implementadas desde el archivo de Figma **HACKA**:

| Pantalla | Archivo | Nodo de Figma |
|---|---|---|
| Inicial | `lib/screens/login_screen.dart` | `47:1014` |
| Registro | `lib/screens/register_screen.dart` | `47:1030` |
| Iniciar sesión | `lib/screens/sign_in_screen.dart` | `47:1064` |
| Mapa | `lib/screens/home_screen.dart` | `17:284` |
| Elegir destino | `lib/screens/destination_screen.dart` | `32:663` |
| Elegir parada | `lib/screens/stop_picker_screen.dart` | `32:392` |
| Confirmar parada | `lib/screens/confirm_stop_screen.dart` | `32:634` |
| Ir a la parada | `lib/screens/walk_navigation_screen.dart` | `32:504` |
| En viaje | `lib/screens/onboard_trip_screen.dart` | `43:799`, `45:879` |
| Calificación | `lib/screens/rating_screen.dart` | `45:930` |

`lib/screens/board_bus_screen.dart` (esperar la unidad y pagar) no tiene diseño de Figma
todavía; está armada con los mismos componentes que el resto.

## El flujo del viaje

```
Inicio (mapa limpio)
  └─ ¿A dónde vas?        destination_screen   arrastra el mapa, confirma el punto
     └─ Paradas cerca      stop_picker_screen   opciones ordenadas por qué tan cerca te dejan
        └─ ¿Confirmar?     confirm_stop_screen  revisa distancia al destino y ETA
           └─ Ir a pie     walk_navigation      al llegar aparece la confirmación de abordaje
              └─ Esperar    board_bus_screen     el camión se acerca; pagar con tarjeta o monedas
                 └─ A bordo onboard_trip_screen  avisa unos metros antes de la bajada
                    └─ Fin  rating_screen        comentario y estrellas, omitible
```

### Cómo se detecta que el pasajero subió

Cuando la unidad queda a menos de `busApproachingMeters` aparece "Paga con tu tarjeta RFID".
Desde ahí hay dos caminos:

- **Tarjeta**: el tap va a `POST /card-taps`.
- **Monedas**: el pasajero no toca nada. La pantalla se quita sola cuando la unidad **estuvo**
  en la parada y luego se alejó más de `departedStopMeters`. La memoria de "estuvo aquí" es
  necesaria: sin ella no se distingue una unidad que viene llegando de una que ya se fue,
  porque en ambos casos está lejos.

En producción esto se resolvería comparando la velocidad del dispositivo con la de la unidad;
`CLAUDE.md` descarta la detección por sensores en esta fase.

El mapa de inicio arranca **sin rutas ni paradas**: mostrar el catálogo completo satura y no
ayuda a decidir. Las paradas pertinentes son las que llevan a donde el usuario va, y eso no se
sabe hasta que lo dice.

El estado del viaje vive en `lib/data/trip_plan.dart`. `buildOptions()` es la pieza que decide
qué se ofrece: para cada ruta toma **la parada que deja más cerca del destino** y ordena las
opciones por esa distancia, con la caminata hasta el abordaje como desempate. Caminar de más al
principio se tolera mucho mejor que quedar lejos al final, con el pasaje ya pagado.

Se navegan entre sí (`lib/main.dart`). El mapa **ya habla con `server/`**: dibuja las rutas y
paradas del catálogo, sigue la unidad en vivo por WebSocket y registra la confirmación de
abordaje. Los formularios de acceso siguen siendo maqueta — validan y entregan los datos por
callback, sin crear cuentas.

## El viaje más rápido: quién rutea qué

La app tiene cinco entradas, y no todas se resuelven en el mismo sitio:

| Entrada | Quién la resuelve | Por qué |
|---|---|---|
| **A dónde vas** (tarjeta de arriba) | Servidor, `GET /journeys` | Combina modos y transbordos sobre el grafo de paradas |
| En camión | Cliente | Elige parada de subida y bajada con los datos de `/routes` |
| En bici | Cliente | Necesita la red de ciclovías, que solo vive aquí |
| Caminando | Cliente | Necesita las zonas no recomendadas, que solo viven aquí |
| En teleférico | Cliente | Estaciones simuladas del propio cliente |

El reparto de la pantalla de inicio sigue esa división: **arriba la recomendación** —dime a
dónde vas y te llevo por lo más rápido— y **abajo la elección**, para cuando alguien quiere ir
en bici aunque no sea lo más rápido. Por eso el camión bajó a la hoja con los demás modos en
vez de quedarse en la tarjeta.

El viaje más rápido es el único que espera a la red, así que es el único con estado de carga.
Su itinerario no se recalcula en el cliente: se enseña, se recorre y se puede cambiar de
alternativa entre las que devuelve el servidor.

## Mapas: hace falta una API key de Google

Los mapas son **Google Maps** (`google_maps_flutter`), no OpenStreetMap. Sin clave no carga
ninguno y salen en blanco; el resto de la app sigue funcionando.

La clave **no está en el repositorio**. Vive en `.env`, que está en `.gitignore`:

```bash
cd app
cp .env.example .env                  # y pon tu clave dentro
dart run tool/write_maps_key.dart     # genera web/maps-key.js
```

`web/index.html` sí está en git, así que no puede llevar la clave: carga `web/maps-key.js`, que
genera ese comando y también está ignorado. Si te saltas el paso, el navegador devuelve un 404
inofensivo y los mapas quedan vacíos.

El script inyecta la API con `libraries=drawing`. No es opcional: sin esa biblioteca el SDK web
no dibuja polilíneas, círculos ni marcadores, que es casi todo lo que la app pinta encima del
mapa.

La clave se saca de Google Cloud con la **Maps JavaScript API** habilitada, y con cuenta de
facturación activa (Google la exige incluso para el nivel gratuito).

Un matiz que conviene no malinterpretar: una clave de navegador es **pública por naturaleza**,
acaba dentro del HTML y se ve en el código fuente de la página. Tenerla fuera de git evita que
quede en el historial y que se la lleve quien clone el repo, pero lo que de verdad la protege es
**restringirla por referente HTTP** en la consola de Google Cloud — para la demo, `localhost:8080`.

Para Android hace falta además la clave en `android/app/src/main/AndroidManifest.xml`, y para
iOS en `ios/Runner/AppDelegate.swift`; hoy solo está cableado el lado web, que es donde corre la
demo.

## Correrlo con el backend

```
# terminal 1
cd ../server && npm install && npm run dev

# terminal 2 — el conductor simulado, para ver la unidad moverse
cd ../server && npm run simulate

# terminal 3
cd ../app && flutter run -d chrome
```

Con otra dirección de backend:

```
# emulador de Android
flutter run \
  --dart-define=API_BASE_URL=http://10.0.2.2:3001 \
  --dart-define=REALTIME_URL=http://10.0.2.2:3001
```

El panel institucional (`../dashboard/index.html`) lee el mismo servidor: al confirmar
"Voy a abordar" en la app, su contador sube en vivo.

## Estructura

```
lib/
├── main.dart                    rutas y navegación
├── theme.dart                   paleta, tipografías, escala fluida
├── morelia.dart                 centro, límites y teselas del mapa
├── data/
│   ├── models.dart              contrato de server/ traducido a Dart
│   ├── api_client.dart          REST
│   ├── realtime_client.dart     socket.io (vehicle:position, demand:update)
│   └── providers.dart           cableado con Riverpod
├── screens/                     una por pantalla del diseño
└── widgets/
    ├── branding.dart            marca, enlace entre pantallas, botones circulares
    ├── inputs.dart              campos píldora, contraseña con ojo, fecha, CTA
    ├── auth_scaffold.dart       andamiaje común de registro e inicio de sesión
    ├── map_chrome.dart          controles flotantes sobre el mapa
    └── stop_sheet.dart          ETA y confirmación de abordaje (Escenario 2)
assets/
├── images/login-morelia.png     fondo de la pantalla inicial
└── icons/                       google, apple, chevron, calendario, ojo, menú,
                                 perfil, camión, bici, caminata, pin
```

Los assets se exportaron de Figma y viven en el repo: las URLs que entrega Figma caducan a los
7 días, así que referenciarlas habría dejado la app rota sin aviso.

## Cómo está resuelto lo responsive

El diseño viene de un lienzo fijo de 402 px de ancho con todo en coordenadas absolutas.
Traducir eso literalmente rompe en cualquier pantalla distinta, así que **cada medida se
expresa como proporción de ese lienzo y se acota a un rango legible** — ver `fluid()`,
`scaleFor()` y `gutterFor()` en `theme.dart`. En pantallas anchas el contenido deja de crecer
a `maxContentWidth` (520 px); el fondo sigue a pantalla completa.

Las pruebas de `test/` montan cada pantalla en ocho tamaños reales —de iPhone SE a 1440×900—,
con tipografía al doble y con el teclado abierto, y fallan si algo desborda. Si vuelves a meter
un tamaño en píxeles duros, se entera ahí y no en la demo.

## Resuelto: el destino ya se guarda

`POST /boarding-signals` ahora acepta, opcionalmente, `destination_stop_id`,
`destination_lat` y `destination_lng`. Es aditivo — si el cliente no los
manda, se guardan como `NULL` y todo sigue igual.

**La app ya los manda.** Al confirmar el abordaje en la parada
(`walk_navigation_screen.dart`) viajan la parada de bajada y el punto exacto
que el usuario eligió en el mapa. Se mandan los dos a propósito: la parada es
una aproximación al lugar al que de verdad quiere llegar, y la diferencia
entre ambos es justo lo que hay que medir para saber si la red le sirve.

## Resuelto: `/card-taps` ya reutiliza la señal declarada

`POST /card-taps` ahora acepta un `boarding_signal_id` opcional: si viene,
marca **esa** señal como `boarded` (recalculando la demanda de su parada y
agendando la auto-liberación) en vez de crear una nueva sin parada asociada.
Sin ese campo se comporta exactamente como antes.

**La app ya lo usa.** `board_bus_screen.dart` manda el `boarding_signal_id`
declarado en la parada, y el parche que cerraba la señal como `expired`
desapareció. Aquel parche decía lo contrario de lo que había pasado —el
pasajero no se fue sin subir, subió— y dejaba el viaje partido en dos
registros. Ahora es uno solo de punta a punta, que además es el que se
califica.

**Detalle de operación ya resuelto**: `TRIP_DURATION_MS` default subió de
20s a 15 min, así que una demo normal ya no debería toparse con la
calificación fallando por auto-liberación prematura. Sigue siendo
configurable si hace falta más margen.

## Nuevo: teleférico real + recomendación de transbordos (`GET /journeys`)

`GET /routes` ahora incluye una tercera ruta (`mode: "teleferico"`, punto de
transbordo real con la ruta de bus en "Bosque Cuauhtémoc") y una cuarta,
larga (~9 km, `Ruta Salida a Charo`, combi), para poder probar recomendaciones
a distancias reales.

Además hay un endpoint nuevo, `GET /journeys`, con query params
`origin_lat, origin_lng, destination_lat, destination_lng` y opcionalmente
`modes` (coma-separado: `bike,combi,bus,teleferico` — modos *permitidos*;
caminar siempre está disponible). La respuesta es
`{ alternatives: [...] }` — sin `modes`, hasta 3 alternativas etiquetadas
("Más rápida", "Sin bicicleta", "Con menos transbordos"); con `modes`, una
sola respetando esa restricción. Esto es lo que efectivamente resuelve lo
que pidieron: transbordos reales entre modos, alternativas para elegir, y
la posibilidad de excluir un modo (ej. "no quiero bici") o forzar otros
(ej. "solo bus y caminata"). Detalle completo y ejemplo de respuesta en
`server/README.md`. Adoptarlo es su decisión — `buildOptions()` sigue
funcionando igual si no lo usan.

**Ojo con la demo**: la bici de `/journeys` es una línea recta simple (no
usa el trazado fino de `bike_network.dart`), con un límite de 6 km
(`MAX_BIKE_DISTANCE_KM`) más allá del cual deja de ofrecerse. Bajo ese
límite, le gana casi siempre al transporte colectivo con transbordo por los
tiempos fijos de espera — no es un bug, es lo que honestamente sale más
rápido a esa escala. Para que la demo luzca el transbordo en vez de la
bici, usen la ruta larga a Charo (o cualquier origen/destino a más de 6 km)
o pasen `modes` sin `bike`. Nota completa en `server/README.md`.

**Aviso de consistencia**: `averageBusSpeedKmh = 15` en `trip_plan.dart` ya
no es universal — el servidor ahora usa una velocidad por modo
(`speedForMode` en `server/src/lib/speeds.ts`): combi/bus siguen en 15 km/h,
pero teleférico va a 20 km/h. Si la app sigue usando el número fijo para
calcular el ETA de un tramo de teleférico, va a mostrar un tiempo distinto
al que calcula `/stops/:id/eta` o `/journeys` para ese mismo tramo.

## Pendientes conocidos

- **Tipografías.** El diseño usa Coolvetica, Nura, Satoshi y League Spartan. Los archivos no
  están en el repo, así que hay pilas de respaldo y se ve con la tipografía del sistema. Al
  colocar los `.ttf`/`.otf` en `assets/fonts/` y declararlos en `pubspec.yaml`, las constantes
  de `AppFonts` resuelven solas sin tocar las pantallas.
- **Registro e inicio de sesión no crean cuentas.** La señal de abordaje usa un usuario demo
  creado al vuelo (`POST /users`), como permite `CLAUDE.md` en esta fase.
- **Modo conductor (Escenario 3).** Hoy la unidad la mueve el script `server/npm run simulate`;
  falta la pantalla que emita `driver:position` desde el teléfono.
- **Reporte de incidencias.** `POST /incidents` existe en el contrato y la pantalla de
  calificación sería su lugar natural; todavía no se conecta.
- **`better-sqlite3` no compila en Node 24 sin Visual Studio Build Tools.** Es un problema de
  entorno del backend, no de la app; ver la nota en el commit que conectó el mapa.
- **Identidad visual.** La paleta de estas pantallas (magenta `#E244AE`, lima `#CAFF94`, verde
  `#56AC00`, marca "MTAPP") **no coincide** con la sección "Identidad visual" de `CLAUDE.md`,
  que describe teal/ámbar/navy con títulos en serif. Se siguió el Figma por ser el diseño
  vigente; conviene actualizar `CLAUDE.md` para que dejen de contradecirse.
- **Contraste.** El texto "¿Ya tienes cuenta?" usa el `#8A8A8A` del diseño, que sobre blanco
  queda en ~3.5:1 — por debajo del 4.5:1 que pide WCAG AA. Subirlo a `#6E6E6E` lo corrige sin
  que se note.

## Diferencias deliberadas contra el Figma

- El botón de la pantalla de registro dice **"Registrarse"**; en el diseño dice "Entrar",
  heredado de la pantalla inicial.
- El campo de correo de inicio de sesión usa el marcador **"Escribe tu correo..."**; en el
  diseño dice "Escribe tu nombre...", heredado del registro.
- Acentos y signos de apertura en los textos de interfaz.
