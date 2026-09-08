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

## Propuesta pendiente: el destino no se guarda

El flujo ya exige declarar el destino antes de abordar, pero **`POST /boarding-signals` no
tiene dónde recibirlo**: su cuerpo es `{user_id, stop_id, route_id, intent}`. Hoy el destino
solo vive en el cliente, donde sirve para elegir ruta y parada de bajada, y se pierde al
cerrar la app.

Sin persistirlo, la señal sigue diciendo "alguien espera en la parada 3" y no "alguien va de la
parada 3 a la 5". La diferencia importa para el panel institucional: con pares origen-destino se
puede estimar la carga por tramo del corredor, no solo la fila en un punto.

Cambio mínimo propuesto (**no implementado** — `CLAUDE.md` pide no inventar rutas ni campos sin
acordarlo):

```
POST /boarding-signals
{ user_id, stop_id, route_id, intent,
  destination_stop_id,        // parada de bajada declarada
  destination_lat,            // punto exacto que eligió el usuario,
  destination_lng }           // por si no coincide con la parada
```

Y en `boarding_signals`, tres columnas opcionales con los mismos nombres. Es aditivo: los
clientes que no manden esos campos siguen funcionando igual.

## Otra brecha de contrato: `/card-taps` duplica la señal

`POST /card-taps` **crea su propia señal de abordaje** con `stop_id` nulo, en vez de reutilizar
la que el pasajero ya declaró en la parada. `CLAUDE.md` describe el tap como un atajo que
"salta directo a abordado, sin pasar por voy a abordar", así que no contempla que exista una
declaración previa — pero en este flujo siempre existe.

Mientras tanto, la app cierra la señal declarada como `expired` al pasar la tarjeta, para que
el panel institucional no siga contando a alguien que ya subió. Es un parche: `expired`
significa "no abordó", que es justo lo contrario de lo que pasó.

Cambio propuesto (**no implementado**): que `/card-taps` acepte un `boarding_signal_id`
opcional y, cuando venga, marque esa señal como `boarded` en vez de crear otra.

**Y un detalle de operación:** `POST /trips/:id/rating` exige que la señal siga en `boarded`,
pero `TRIP_DURATION_MS` (20 s por defecto) la pasa sola a `alighted`. En una demo real el viaje
dura más que eso y la calificación fallaría. Correr el servidor con
`TRIP_DURATION_MS=600000` mientras se demuestra.

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
