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

Las tres pantallas de acceso, implementadas desde el archivo de Figma **HACKA**:

| Pantalla | Archivo | Nodo de Figma |
|---|---|---|
| Inicial | `lib/screens/login_screen.dart` | `47:1014` |
| Registro | `lib/screens/register_screen.dart` | `47:1030` |
| Iniciar sesión | `lib/screens/sign_in_screen.dart` | `47:1064` |

Se navegan entre sí (`lib/main.dart`), pero **todavía no hablan con el backend**: los
formularios validan y entregan los datos por callback, sin llamar a `server/`.

## Estructura

```
lib/
├── main.dart                    rutas y navegación entre las tres pantallas
├── theme.dart                   paleta, tipografías, escala fluida
├── screens/                     una por pantalla del diseño
└── widgets/
    ├── branding.dart            marca, enlace entre pantallas, botones circulares
    ├── inputs.dart              campos píldora, contraseña con ojo, fecha, CTA
    └── auth_scaffold.dart       andamiaje común de registro e inicio de sesión
assets/
├── images/login-morelia.png     fondo de la pantalla inicial
└── icons/                       google, apple, chevron, calendario, ojo
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

## Pendientes conocidos

- **Tipografías.** El diseño usa Coolvetica, Nura, Satoshi y League Spartan. Los archivos no
  están en el repo, así que hay pilas de respaldo y se ve con la tipografía del sistema. Al
  colocar los `.ttf`/`.otf` en `assets/fonts/` y declararlos en `pubspec.yaml`, las constantes
  de `AppFonts` resuelven solas sin tocar las pantallas.
- **Conexión con `server/`.** Falta cablear los formularios y construir las pantallas de los
  Escenarios 1-3 de `CLAUDE.md` (mapa, confirmación de abordaje, modo conductor).
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
