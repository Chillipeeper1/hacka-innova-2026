import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Identidad visual de MTAPP, tomada del archivo de Figma "HACKA".
///
/// OJO — esto **no coincide** con la sección "Identidad visual" de `CLAUDE.md`, que describe
/// una paleta teal/ámbar/navy con títulos en serif. El diseño de Figma es una identidad
/// distinta: magenta, lima y verde, con tipografías display. Se implementa la de Figma porque
/// es el diseño vigente del equipo; conviene actualizar `CLAUDE.md` para que dejen de
/// contradecirse.
class AppColors {
  const AppColors._();

  /// CTA principal.
  static const Color magenta = Color(0xFFE244AE);

  /// Variante profunda del magenta (estado presionado).
  static const Color magentaDeep = Color(0xFFC42890);

  /// Acento del titular.
  static const Color lime = Color(0xFFCAFF94);

  /// Enlaces de acción.
  static const Color green = Color(0xFF56AC00);

  /// Texto secundario sobre superficie clara.
  static const Color muted = Color(0xFF8A8A8A);

  /// Fondo de los botones sociales circulares.
  static const Color surfaceGrey = Color(0xFFD9D9D9);

  /// Relleno de los campos de formulario.
  static const Color field = Color(0xFFEDEDED);

  /// Relleno del campo de dirección sobre el mapa: un gris apenas más marcado, porque va
  /// sobre una hoja blanca con mucha luz alrededor.
  static const Color fieldStrong = Color(0xFFE3E3E3);

  /// Texto de marcador dentro de un campo vacío: el mismo gris al 49%.
  static const Color placeholder = Color(0x7D8A8A8A);

  /// Botón circular de regreso.
  static const Color mint = Color(0xFFDCFFB8);

  /// Parada concurrida: mucha gente esperando.
  static const Color crowdBusy = Color(0xFFFFC400);
  static const Color crowdBusyArea = Color(0xFFFFB508);

  /// Parada despejada.
  static const Color crowdFree = Color(0xFF00FF4D);
  static const Color crowdFreeArea = Color(0xFF83FF08);

  /// Trazado de la caminata hacia la parada.
  static const Color walkPath = Color(0xFF0004FF);

  /// Velo sobre el mapa cuando se pide una confirmación.
  static const Color modalScrim = Color(0x8A000000); // negro al 54%

  static const Color sheet = Colors.white;

  /// Velo sobre la fotografía. Sin él, el texto blanco no alcanza contraste legible sobre la
  /// parte clara del cielo.
  static const Color scrim = Color(0x94000000); // negro al 58%
}

/// Familias tipográficas del diseño.
///
/// Los archivos de fuente no están en el repo, así que cada una va con una pila de respaldo y
/// el texto se ve con la tipografía del sistema. Para que quede idéntico al diseño hay que
/// colocar los .ttf/.otf en `assets/fonts/` y declararlos en `pubspec.yaml`; entonces estas
/// constantes empiezan a resolver solas, sin tocar las pantallas.
class AppFonts {
  const AppFonts._();

  /// Marca "MTAPP".
  static const String display = 'Nura';
  static const List<String> displayFallback = [
    'Futura',
    'Century Gothic',
    'Trebuchet MS',
  ];

  /// Titulares.
  static const String headline = 'Coolvetica';
  static const List<String> headlineFallback = [
    'Helvetica Neue',
    'Arial Black',
    'Roboto',
  ];

  /// Cuerpo de texto.
  static const String body = 'Satoshi';
  static const List<String> bodyFallback = ['Inter', 'Helvetica Neue', 'Roboto'];

  /// Etiquetas de botón.
  static const String button = 'League Spartan';
  static const List<String> buttonFallback = ['Inter', 'Roboto'];
}

class AppSpacing {
  const AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
}

class AppRadius {
  const AppRadius._();

  /// Radio superior de la hoja inferior.
  static const double sheet = 40;

  /// Los CTA del diseño son píldoras completas.
  static const double pill = 999;

  /// Tarjeta flotante sobre el mapa.
  static const double floatingCard = 30;

  /// Botones cuadrados del mapa.
  static const double squareButton = 15;
}

/// Sombras del diseño.
///
/// Sobre el mapa todo flota: sin sombra, una tarjeta blanca sobre teselas claras se pierde. El
/// diseño las define con desplazamiento lateral, no centradas.
class AppShadows {
  const AppShadows._();

  static const Color _key = Color(0x40000000); // negro al 25%

  /// Tarjeta de búsqueda.
  static const List<BoxShadow> floatingCard = [
    BoxShadow(color: _key, offset: Offset(5, 4), blurRadius: 4),
  ];

  /// Botones cuadrados de la parte superior.
  static const List<BoxShadow> squareButton = [
    BoxShadow(color: _key, offset: Offset(4, 4), blurRadius: 4),
  ];

  /// Botón circular flotante sobre el mapa.
  static const List<BoxShadow> circleButton = [
    BoxShadow(color: _key, offset: Offset(3, 4), blurRadius: 4),
  ];

  /// Hoja inferior: la sombra va hacia arriba, contra el mapa.
  static const List<BoxShadow> sheet = [
    BoxShadow(color: _key, offset: Offset(0, -3), blurRadius: 4),
  ];
}

/// Escala tipográfica fluida.
///
/// El diseño viene de un lienzo de 402 px de ancho. En vez de fijar los tamaños en píxeles —
/// que en una tablet se ven diminutos y en un teléfono chico desbordan — cada tamaño se
/// expresa como proporción de ese lienzo y se acota entre un mínimo y un máximo legibles.
double fluid(
  double width, {
  required double designSize,
  required double min,
  required double max,
}) {
  return math.min(math.max(width * (designSize / designWidth), min), max);
}

/// Ancho del lienzo de Figma del que salen todas las proporciones.
const double designWidth = 402.0;

/// Factor de escala respecto al lienzo del diseño, acotado para que los espacios ni se
/// encojan ni se inflen de más.
double scaleFor(double width) => (width / designWidth).clamp(0.85, 1.25);

/// Margen lateral del contenido: 9.2% del ancho, como en el diseño (37 de 402).
double gutterFor(double width) => math.min(math.max(width * 0.092, 18), 44);

/// Ancho al que deja de crecer el contenido.
///
/// En tablet y web el fondo sigue a pantalla completa, pero el contenido se detiene aquí: una
/// línea o un campo de mil píxeles de ancho es incómodo de usar.
const double maxContentWidth = 520;

ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.magenta,
    primary: AppColors.magenta,
    onPrimary: Colors.white,
    secondary: AppColors.green,
    surface: Colors.white,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: Colors.white,
    fontFamily: AppFonts.body,
    fontFamilyFallback: AppFonts.bodyFallback,
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.magenta,
        foregroundColor: Colors.white,
        disabledBackgroundColor: AppColors.magenta.withValues(alpha: 0.5),
        shape: const StadiumBorder(),
        padding: EdgeInsets.zero,
        textStyle: const TextStyle(
          fontFamily: AppFonts.button,
          fontFamilyFallback: AppFonts.buttonFallback,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}

/// Convierte el `color_hex` que manda el backend a un [Color].
///
/// Tolera que venga con o sin `#` y con o sin canal alfa. Si el valor no se puede leer,
/// devuelve [fallback] en vez de reventar: un color mal escrito en la semilla no debe tumbar
/// el mapa completo.
Color colorFromHex(String? hex, {Color fallback = AppColors.green}) {
  if (hex == null) return fallback;
  var value = hex.trim().replaceFirst('#', '');
  if (value.length == 6) value = 'FF$value';
  if (value.length != 8) return fallback;
  final parsed = int.tryParse(value, radix: 16);
  return parsed == null ? fallback : Color(parsed);
}
