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

En Android la clave sale del **mismo `.env`**: `android/app/build.gradle.kts` lo lee y la inyecta
en el manifest como `manifestPlaceholder`, porque `AndroidManifest.xml` sí está en git y no
puede llevarla escrita. Lo que no se hereda es el permiso: una clave restringida por referente
HTTP **no funciona en Android**. Hay que habilitar *Maps SDK for Android* en Google Cloud y
darle a la clave una restricción de aplicación Android — paquete `mx.maasmorelia.maas_morelia`
más la huella SHA-1 del keystore de debug. En iOS sigue sin cablear
(`ios/Runner/AppDelegate.swift`).

## Direcciones: Nominatim, llamado desde la app

La pantalla de destino enseña una dirección de calle —"Calle Antonio Alzate 805, Morelia"— y no
las coordenadas del pin. Quien las traduce es **Nominatim**, el buscador de OpenStreetMap, y la
app lo consulta **directo**, sin pasar por `server/`: el contrato de API de `CLAUDE.md` no tiene
un endpoint de geocodificación y agregarlo es trabajo del equipo de backend. Es el mismo trato
que ya tienen los mapas —un servicio externo que el cliente pide por su cuenta— y deja esta
pantalla funcionando aunque el backend esté apagado.

No hace falta clave ni configuración: funciona tal cual. Dos cosas que sí importan:

- **Una petición por segundo** es el tope que pide la política de uso del servicio público. Se
  respeta esperando a que el mapa se quede quieto (600 ms sin movimiento de cámara) y con un
  caché por punto redondeado a ~11 m, así que un arrastre entero cuesta una sola consulta.
- **Para producción hay que hospedar la instancia propia** y apuntar ahí con
  `--dart-define=NOMINATIM_URL=https://...`. El servicio público no está pensado para el tráfico
  de una app en la calle.

Si no contesta —sin red, servicio caído, o un punto que no reconoce— el campo cae a las
coordenadas del pin. El destino elegido sigue siendo válido y confirmarlo funciona igual.

El botón cuadrado de la esquina inferior derecha devuelve la cámara —y con ella el pin— a donde
está el pasajero. Esa ubicación sale de `userLocationProvider`, la **simulada** que ya usan el
planeador de viaje y el peatón que camina a la parada: no es GPS real, así que el botón se
comporta igual con o sin permisos concedidos. Ver el pendiente de abajo.

## Guion de demo: qué destino poner y qué parada agarrar

Con `demo-drive` a sus valores por omisión. Los números salen de medir el recorrido simulado
contra los providers de la app, no de estimar.

### Flujo de camión (Escenarios 2 a 7)

**Destino: el Acueducto — `19.6975, -101.1791`. Parada de subida: Fuente de las Tarascas.**

Es la combinación más robusta, por tres razones medidas:

| Parada de subida | Espera promedio | Peor caso | 95% bajo |
|---|---|---|---|
| **Fuente de las Tarascas** (ruta 1) | **18 s** | **84 s** | **75 s** |
| Catedral (ruta 1) | 55 s | 128 s | 118 s |
| Acueducto (ruta 1) | 47 s | 128 s | 122 s |
| Catedral o Bosque (ruta 2) | 74–86 s | 189 s | ~180 s |

Las Tarascas es la parada de **en medio** de la ruta 1, así que la unidad pasa por ahí dos veces
por ciclo — de ida y de vuelta. Las paradas de los extremos solo la ven una vez.

Además, subir ahí obliga a caminar 614 m, que son ~25 s de caminata simulada: ese rato es justo
el que se necesita para navegar las pantallas, así que se llega a la parada con la unidad
todavía en camino en vez de verla irse. Subiendo en la Catedral no hay caminata, la unidad está
ahí desde el arranque y solo se detiene 9 s — si se tarda uno en tocar, ya se fue.

El viaje dura 29 s y deja en el destino exacto. Para ver además el tramo final a pie y el aviso
de "te deja a 300 m", poner el destino 300 m al sur: `19.6948, -101.1791`.

### Viaje personalizado con transbordo (Escenario 8)

**Destino: Central de Autobuses — `19.687, -101.162`, y apagar la bici en el selector de modos.**

Es el único destino del seed que produce un transbordo real: camión de la Catedral al Bosque
Cuauhtémoc, y ahí teleférico hasta la Central. 19.1 min, que a 20x
(`journeyDemoSpeedFactor`) se recorren en ~57 s.

Con la bici encendida gana "Más rápida" = bici directa, 11.2 min sin transbordos. Sirve para
enseñar la comparación entre alternativas, pero no el transbordo.

### Qué evitar

- **Destinos al oeste o al sur del centro.** El seed solo tiene rutas hacia el este/noreste, así
  que ahí no hay transporte y sale el aviso de "Ninguna ruta llega hasta allá". Es correcto,
  pero no demuestra nada.
- **Charo Centro** (`19.7386, -101.1041`). Funciona, pero son 40.6 min de viaje.

## Correrlo con el backend

```
# terminal 1
cd ../server && npm install && npm run dev

# terminal 2 — el conductor simulado, para ver la unidad acercarse
cd ../server && npm run demo-drive

# terminal 3
cd ../app && flutter run -d chrome --web-port=8080
```

**Ojo con cuál de los dos simuladores se corre.** `npm run demo-drive` emite una posición cada
100 ms interpolando sobre el tramo, y al llegar al final da la vuelta: la unidad se ve avanzar.
`npm run simulate` hace otra cosa a propósito —lo dice `server/README.md`—: emite las
coordenadas de una parada cada 3 segundos y vuelve a empezar con `index % stops.length`. En el
mapa eso es la unidad teletransportándose entre paradas, con un salto **hacia atrás** de 665 m
al cerrar el ciclo en la Ruta Centro - Acueducto, y un ida y vuelta de 1274 m cada 3 segundos en
la Ruta Centro - Bosque, que solo tiene dos paradas. Se ve como si el icono del camión estuviera
roto, y no lo está: la app dibuja exactamente la posición que recibe. `simulate` sirve para
probar rápido que el evento llega; para ver el mapa, `demo-drive`.

**Si el icono salta y `demo-drive` es el que corre**, casi seguro el proceso lleva horas vivo
mientras el servidor se reinició varias veces (`tsx watch` reinicia a cada cambio de archivo).
Los dos simuladores registraban su bucle dentro de `socket.on("connect")`, que se vuelve a
disparar en **cada reconexión**: cada reinicio del servidor dejaba un conductor más recorriendo
la misma ruta con su propio avance, todos emitiendo para el mismo `vehicle_id`. Ya está
corregido —el bucle se apaga al desconectar— pero un proceso viejo sigue con los conductores que
acumuló: ciérralo y vuelve a abrirlo. Para comprobarlo, la unidad debe reportar **2 posiciones
por segundo**; si son 8 o 24, hay 4 o 12 conductores encima.

**La unidad recorre la línea que dibuja la app**, no una recta entre paradas. `demo-drive` pide
el trazado al mismo `GET /routes` que consume el cliente y avanza sobre esa polilínea. Antes
interpolaba en recta de parada a parada, y como la línea del mapa sigue las calles, el camión se
veía cruzando manzanas por fuera de su propia ruta: hasta 143 m fuera en la Ruta Centro -
Acueducto, 415 m en la Centro - Bosque y 1033 m en la Salida a Charo, que es la que más rodea.
El teleférico sigue en recta entre estaciones, que es lo correcto: va por el aire y su `shape`
viene vacío.

**Cuánto tarda la demo.** La tabla de abajo está **medida con los valores de entonces** (45
km/h, 9 s detenido en cada parada) y el destino junto al Acueducto. Hoy `demo-drive` viene a
600 km/h y 5 s por parada —calibrado para presentar contra reloj, ver el comentario del script—
así que los tiempos de trayecto salen unas trece veces más cortos y cada parada intermedia
suma 5 s en vez de 9. Lo que la tabla sigue diciendo es lo que importa: **la diferencia entre
las tres opciones**, que no cambia al mover la velocidad.

| Opción | Pide la tarjeta a los | Dura el viaje |
|---|---|---|
| Subir en **Catedral**, bajar en Acueducto (665 m) | 0 s — la unidad arranca ahí | 75 s |
| Subir en Fuente de las Tarascas, bajar en Acueducto (157 m) | 46 s | 29 s |
| Subir en Bosque Cuauhtémoc, bajar en Catedral (1274 m) | ~90 s | ~100 s |

Para enseñar el flujo completo conviene la primera. Las otras dos se sienten rotas por dos
motivos que no son un fallo de la app: la ventana de pago no aparece hasta que la unidad está a
150 m de la parada (`busApproachingMeters`), y el viaje termina solo en cuanto la unidad entra
en los 60 m de la parada de bajada (`alightingRadiusMeters`) — con tramos de 157 m eso pasa
enseguida. `SPEED_KMH` y `DWELL_MS` de `demo-drive` mueven ambos tiempos: `SPEED_KMH=150
DWELL_MS=9000 npm run demo-drive` devuelve el ritmo anterior si hace falta más aire para
explicar.

`--web-port=8080` no es opcional: la clave de Maps esta restringida a ese
puerto (ver arriba) y `flutter run -d chrome` a secas elige uno al azar, con
lo que el mapa falla con `RefererNotAllowedMapError`.

Correrlo asi, en modo debug, tambien evita el service worker: un
`flutter build web` servido como estatico registra uno, y entonces los
cambios no se ven hasta desregistrarlo a mano en DevTools (Application ->
Service Workers -> Unregister) por mucho que se recompile.

Con otra dirección de backend:

```
# emulador de Android
flutter run \
  --dart-define=API_BASE_URL=http://10.0.2.2:3001 \
  --dart-define=REALTIME_URL=http://10.0.2.2:3001
```

## En un celular físico Android

```
powershell -ExecutionPolicy Bypass -File tool/run-device.ps1
```

El script busca la IP de esta máquina en la red local y la pasa por `--dart-define`. Es lo único
que distingue esta corrida de la de web: el celular no puede usar `localhost` —ese es él mismo—
ni `10.0.2.2`, que solo existe dentro del emulador. Si la detección elige la interfaz equivocada
(VPN, Docker, WSL), pásale la buena: `-HostIp 192.168.1.50`.

Del lado del celular: depuración USB activada en Opciones de desarrollador, cable conectado y
aceptar el diálogo *"¿Permitir depuración USB?"* que sale al enchufarlo. `flutter devices` tiene
que listarlo antes de intentar nada.

Tres cosas tienen que estar en su sitio, y fallan de formas distintas:

| Síntoma | Causa |
|---|---|
| El mapa sale en blanco, el resto funciona | La clave de Maps (ver arriba): falta habilitar el SDK de Android, o la restricción sigue siendo de referente HTTP |
| No cargan rutas ni paradas, lo demás pinta | El celular no alcanza el backend: otra Wi-Fi, o el firewall de Windows bloqueando el 3001 |
| La app ni siquiera abre | El dispositivo no está autorizado — `adb devices` lo muestra como `unauthorized` |

El backend ya escucha en todas las interfaces, así que no hay que tocarlo; la primera vez
Windows pregunta si deja entrar conexiones a Node y hay que decir que sí en la red privada.

Para **proyectar** el celular en una pantalla durante la demo, `scrcpy` lo espeja por USB sin
instalar nada en el teléfono.

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
│   ├── geocoder.dart            coordenadas → dirección (Nominatim)
│   └── providers.dart           cableado con Riverpod
├── screens/                     una por pantalla del diseño
└── widgets/
    ├── address_text.dart        la dirección de un punto, con su respaldo
    ├── branding.dart            marca, enlace entre pantallas, botones circulares
    ├── inputs.dart              campos píldora, contraseña con ojo, fecha, CTA
    ├── auth_scaffold.dart       andamiaje común de registro e inicio de sesión
    ├── map_chrome.dart          controles flotantes sobre el mapa
    └── stop_sheet.dart          ETA y confirmación de abordaje (Escenario 2)
assets/
├── images/login-morelia.png     fondo de la pantalla inicial
└── icons/                       google, apple, chevron, calendario, ojo, menú,
                                 perfil, camión, bici, caminata, pin, mi ubicación
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

**Dos velocidades, a propósito.** Lo que falta para que llegue la unidad se
cuenta con `etaSpeedKmh` (`trip_plan.dart`), que es la del conductor simulado
—600 km/h, misma que `DEMO_VEHICLE_SPEED_KMH` en `server/src/lib/speeds.ts` y
que `SPEED_KMH` en `demo-drive`—: el contador tiene que cuadrar con la unidad
que se ve avanzar en el mapa, y a 15 km/h anunciaría cinco minutos para algo
que llega en ocho segundos. Como casi siempre falta menos de un minuto, se
muestra en segundos (`formatEta`).

Los minutos del **itinerario** no pasan por ahí: los calcula el servidor con
la velocidad real por modo (`speedForMode`: 15 km/h combi/bus, 20 el
teleférico) y siguen siendo los de un camión de verdad, que es lo que el
producto promete. `averageBusSpeedKmh = 15` en `trip_plan.dart` queda como esa
referencia real —la que compara `bike_network.dart`—, no como el ETA.

Si se baja la velocidad de la demo hay que bajarla en los tres lados o
volverán a contradecirse: `SPEED_KMH=150` en el servidor **y** en
`demo-drive`, y `--dart-define=ETA_SPEED_KMH=150` en la app.

## Pendientes conocidos

- **Tipografías.** El diseño usa Coolvetica, Nura, Satoshi y League Spartan. Los archivos no
  están en el repo, así que hay pilas de respaldo y se ve con la tipografía del sistema. Al
  colocar los `.ttf`/`.otf` en `assets/fonts/` y declararlos en `pubspec.yaml`, las constantes
  de `AppFonts` resuelven solas sin tocar las pantallas.
- **Registro e inicio de sesión no crean cuentas.** La señal de abordaje usa un usuario demo
  creado al vuelo (`POST /users`), como permite `CLAUDE.md` en esta fase.
- **La ubicación del pasajero es simulada.** `userLocationProvider` arranca fija en la Catedral
  y solo se mueve cuando la demo lo hace caminar a la parada. Cablear el GPS real es meter
  `geolocator`, los permisos de Android e iOS, y el aviso de privacidad conforme a LFPDPPP antes
  de recolectar ubicación — nada de eso está hoy. Lo que sí queda listo es el punto de entrada:
  todo lo que pregunta "dónde está el usuario" pasa por ese provider.
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

- **La tarjeta flotante de "Vas hacia la parada: ..."** que el Figma pone bajo los controles
  del mapa ya no existe. Tapaba justo el tramo de mapa por el que se va a pasar, y lo que decía
  es información de referencia —se consulta una vez, no se vigila—, así que vive en la hoja
  blanca de abajo, junto al tiempo y los tramos. Se quitó de las ocho pantallas que la usaban;
  en las dos que ya repetían el dato (`confirm_stop`, y `walk_navigation` al llegar) solo se
  borró. Las hojas crecieron un poco de alto para acomodarlo.
- **El inicio lista cuatro opciones de viaje, no dos.** El Figma (nodo `17:284`) pone "Viajar en
  bici..." y "Viajar caminando..." con aire de sobra en una hoja de 212 px de 874 (24%). La app
  tiene además el viaje personalizado y el teleférico, así que los renglones van apretados
  (`TravelOptionTile.dense`) y la hoja se topa: 39-40% en un teléfono normal, hasta 52% en uno
  corto, donde las mismas cuatro opciones ocupan una fracción mayor. Medido: las cuatro caben
  sin rodar la hoja en 320x568, 360x640, 402x874 y 430x932, y el mapa conserva entre 51% y 62%
  de la pantalla.
- **El mapa del inicio dibuja la red.** El diseño lo enseña como fondo; aquí además se pintan las
  cuatro rutas con su trazado por calles, sus paradas en el color de cada ruta y la posición del
  pasajero. Sin eso el mapa del inicio no responde a nada —fue la razón por la que en su momento
  se cambió por un menú plano sin mapa— y con eso se ve qué cubre el sistema antes de pedirle
  nada.
- El botón de **"mi ubicación"** de la pantalla de destino no está en el Figma. Se agregó
  porque elegir destino sin manera de volver a encuadrarse obliga a arrastrar el mapa a ciegas.
  Usa el mismo `SquareIconButton` verde que los controles de arriba; su icono (`my-location.svg`)
  se dibujó a mano al estilo de los exportados, no salió de Figma.
- **Las paradas llevan una etiqueta de servicio** ("Combi", "Camión", "Teleférico") que el
  Figma no tiene. Hacía falta porque la combi y el camión **comparten icono** —no hay un trazo
  propio en el set del diseño— así que sin texto dos paradas de servicios distintos se ven
  idénticas y no hay forma de saber qué va a llegar. Sale en las tres pantallas donde importa:
  elegir parada, confirmarla, y esperar la unidad. El color es el de la ruta al 22% de fondo con
  el texto en negro: usar el color de la ruta como texto no funciona —el ámbar `#D19B3D` sobre
  blanco da 2.5:1, por debajo del 4.5:1 de WCAG AA— y sobre un tinte claro el negro sí se lee.
- El botón de la pantalla de registro dice **"Registrarse"**; en el diseño dice "Entrar",
  heredado de la pantalla inicial.
- El campo de correo de inicio de sesión usa el marcador **"Escribe tu correo..."**; en el
  diseño dice "Escribe tu nombre...", heredado del registro.
- Acentos y signos de apertura en los textos de interfaz.
