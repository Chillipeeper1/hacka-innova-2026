import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/bike_trip.dart';
import 'data/trip_plan.dart';
import 'data/walk_trip.dart';
import 'screens/confirm_stop_screen.dart';
import 'screens/destination_screen.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/sign_in_screen.dart';
import 'screens/stop_picker_screen.dart';
import 'screens/bike_trip_screen.dart';
import 'screens/board_bus_screen.dart';
import 'screens/onboard_trip_screen.dart';
import 'screens/rating_screen.dart';
import 'screens/walk_navigation_screen.dart';
import 'screens/walk_trip_screen.dart';
import 'theme.dart';

void main() {
  runApp(const ProviderScope(child: MtappApp()));
}

class MtappApp extends StatelessWidget {
  const MtappApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MTAPP',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      locale: const Locale('es', 'MX'),
      supportedLocales: const [Locale('es', 'MX'), Locale('es')],
      // El selector de fecha del registro necesita las traducciones de Material para salir
      // en español.
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      initialRoute: AppRoutes.welcome,
      routes: {
        AppRoutes.welcome: (context) => const _WelcomeRoute(),
        AppRoutes.register: (context) => const _RegisterRoute(),
        AppRoutes.signIn: (context) => const _SignInRoute(),
        AppRoutes.home: (context) => const _HomeRoute(),
        AppRoutes.destination: (context) => const _DestinationRoute(),
        AppRoutes.stopPicker: (context) => const _StopPickerRoute(),
        AppRoutes.confirmStop: (context) => const _ConfirmStopRoute(),
        AppRoutes.walk: (context) => const _WalkRoute(),
        AppRoutes.boardBus: (context) => const _BoardBusRoute(),
        AppRoutes.trip: (context) => const _TripRoute(),
        AppRoutes.rating: (context) => const _RatingRoute(),
        AppRoutes.bikeDestination: (context) => const _BikeDestinationRoute(),
        AppRoutes.bikeTrip: (context) => const _BikeTripRoute(),
        AppRoutes.onFootDestination: (context) =>
            const _OnFootDestinationRoute(),
        AppRoutes.onFootTrip: (context) => const _OnFootTripRoute(),
      },
    );
  }
}

/// Las rutas siguen el orden del viaje: destino → parada → confirmación → caminata → a bordo.
class AppRoutes {
  const AppRoutes._();

  static const String welcome = '/';
  static const String register = '/registro';
  static const String signIn = '/entrar';
  static const String home = '/inicio';
  static const String destination = '/destino';
  static const String stopPicker = '/paradas';
  static const String confirmStop = '/confirmar-parada';
  static const String walk = '/ir-a-la-parada';
  static const String boardBus = '/esperar-camion';
  static const String trip = '/en-viaje';
  static const String rating = '/calificar';

  /// El viaje en bici es su propio carril: destino y a rodar. No pasa por paradas ni pagos, y
  /// por eso no reusa `/destino` — esa pantalla lleva al selector de paradas.
  static const String bikeDestination = '/destino-bici';
  static const String bikeTrip = '/en-bici';

  /// Caminar como viaje propio. No confundir con [walk], que es el tramo a pie **hacia una
  /// parada** dentro del viaje en camión.
  static const String onFootDestination = '/destino-a-pie';
  static const String onFootTrip = '/a-pie';
}

/// Marcador para las acciones que todavía no llevan a ningún lado.
void _pending(BuildContext context, String what) {
  ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text('$what: pendiente')));
}

class _WelcomeRoute extends StatelessWidget {
  const _WelcomeRoute();

  @override
  Widget build(BuildContext context) {
    return LoginScreen(
      onEnter: () => Navigator.pushNamed(context, AppRoutes.register),
      onSignIn: () => Navigator.pushNamed(context, AppRoutes.signIn),
      onGoogle: () => _pending(context, 'Acceso con Google'),
      onApple: () => _pending(context, 'Acceso con Apple'),
    );
  }
}

class _RegisterRoute extends StatelessWidget {
  const _RegisterRoute();

  @override
  Widget build(BuildContext context) {
    return RegisterScreen(
      // Reemplaza en vez de apilar: ir y venir entre registro e inicio de sesión no debe
      // dejar una pila de pantallas por las que el usuario tenga que regresar una por una.
      onSignIn: () => Navigator.pushReplacementNamed(context, AppRoutes.signIn),
      // Al darse de alta se entra al mapa y se limpia la pila: regresar a un formulario ya
      // resuelto no tiene sentido.
      onSubmit: (_) => Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.home,
        (route) => false,
      ),
      onGoogle: () => _pending(context, 'Acceso con Google'),
      onApple: () => _pending(context, 'Acceso con Apple'),
    );
  }
}

class _SignInRoute extends StatelessWidget {
  const _SignInRoute();

  @override
  Widget build(BuildContext context) {
    return SignInScreen(
      onRegister: () =>
          Navigator.pushReplacementNamed(context, AppRoutes.register),
      onSubmit: (_) => Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.home,
        (route) => false,
      ),
      onGoogle: () => _pending(context, 'Acceso con Google'),
      onApple: () => _pending(context, 'Acceso con Apple'),
    );
  }
}

class _HomeRoute extends ConsumerWidget {
  const _HomeRoute();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return HomeScreen(
      onMenu: () => _pending(context, 'Menú'),
      onProfile: () => _pending(context, 'Perfil'),
      onSearchStop: () {
        // Cada viaje empieza de cero: si quedaba uno a medias, se descarta al pedir destino.
        ref.read(tripPlanProvider.notifier).reset();
        Navigator.pushNamed(context, AppRoutes.destination);
      },
      onTravelByBike: () {
        ref.read(bikeTripProvider.notifier).reset();
        Navigator.pushNamed(context, AppRoutes.bikeDestination);
      },
      onTravelWalking: () {
        ref.read(walkTripProvider.notifier).reset();
        Navigator.pushNamed(context, AppRoutes.onFootDestination);
      },
      // El teleférico está en el selector de modo del Escenario 1, pero su flujo todavía no
      // existe: no hay líneas, estaciones ni horarios en el seed. Aparece como opción y avisa
      // que falta, en vez de llevar a una pantalla vacía.
      onTravelByCableCar: () => _pending(context, 'Viaje en teleférico'),
    );
  }
}

/// Paso 1: a dónde va.
class _DestinationRoute extends ConsumerWidget {
  const _DestinationRoute();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DestinationScreen(
      onMenu: () => _pending(context, 'Menú'),
      onProfile: () => _pending(context, 'Perfil'),
      onConfirm: (destination) {
        ref.read(tripPlanProvider.notifier).setDestination(destination);
        Navigator.pushReplacementNamed(context, AppRoutes.stopPicker);
      },
    );
  }
}

/// Paso 2: por qué parada subirse.
class _StopPickerRoute extends ConsumerWidget {
  const _StopPickerRoute();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return StopPickerScreen(
      onMenu: () => _pending(context, 'Menú'),
      onProfile: () => _pending(context, 'Perfil'),
      onBack: () =>
          Navigator.pushReplacementNamed(context, AppRoutes.destination),
      onChoose: (option) {
        ref.read(tripPlanProvider.notifier).choose(option);
        Navigator.pushNamed(context, AppRoutes.confirmStop);
      },
    );
  }
}

/// Paso 3: revisar la elección antes de caminar.
class _ConfirmStopRoute extends ConsumerWidget {
  const _ConfirmStopRoute();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ConfirmStopScreen(
      onMenu: () => _pending(context, 'Menú'),
      onProfile: () => _pending(context, 'Perfil'),
      onConfirm: () {
        ref.read(tripPlanProvider.notifier).startWalking();
        Navigator.pushReplacementNamed(context, AppRoutes.walk);
      },
    );
  }
}

/// Paso 4: caminar, y al llegar confirmar el abordaje.
class _WalkRoute extends StatelessWidget {
  const _WalkRoute();

  @override
  Widget build(BuildContext context) {
    return WalkNavigationScreen(
      onMenu: () => _pending(context, 'Menú'),
      onProfile: () => _pending(context, 'Perfil'),
      onBack: () =>
          Navigator.pushReplacementNamed(context, AppRoutes.stopPicker),
      onBoarded: () =>
          Navigator.pushReplacementNamed(context, AppRoutes.boardBus),
    );
  }
}

/// Paso 5: esperar la unidad en la parada y subirse (con tarjeta o con monedas).
class _BoardBusRoute extends StatelessWidget {
  const _BoardBusRoute();

  @override
  Widget build(BuildContext context) {
    return BoardBusScreen(
      onMenu: () => _pending(context, 'Menú'),
      onProfile: () => _pending(context, 'Perfil'),
      onBoarded: () => Navigator.pushReplacementNamed(context, AppRoutes.trip),
      onCancel: () => _cancelTrip(context),
    );
  }
}

/// Paso 6: a bordo.
class _TripRoute extends StatelessWidget {
  const _TripRoute();

  @override
  Widget build(BuildContext context) {
    return OnboardTripScreen(
      onMenu: () => _pending(context, 'Menú'),
      onProfile: () => _pending(context, 'Perfil'),
      onArrived: () =>
          Navigator.pushReplacementNamed(context, AppRoutes.rating),
      onCancel: () => _cancelTrip(context),
    );
  }
}

/// Paso 7: calificar, u omitirlo, y volver al inicio.
class _RatingRoute extends StatelessWidget {
  const _RatingRoute();

  @override
  Widget build(BuildContext context) {
    return RatingScreen(
      onFinished: () => Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.home,
        (route) => false,
      ),
    );
  }
}

/// Bici, paso 1: a dónde va. Misma pantalla de destino que el camión.
class _BikeDestinationRoute extends ConsumerWidget {
  const _BikeDestinationRoute();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DestinationScreen(
      onMenu: () => _pending(context, 'Menú'),
      onProfile: () => _pending(context, 'Perfil'),
      onConfirm: (destination) {
        ref.read(bikeTripProvider.notifier).start(destination);
        Navigator.pushReplacementNamed(context, AppRoutes.bikeTrip);
      },
    );
  }
}

/// Bici, paso 2: el viaje. No hay paso 3 — al llegar se vuelve al inicio.
///
/// A diferencia del camión no termina en la pantalla de calificación: ahí se califica el
/// servicio de transporte, y en bici no hay servicio que calificar.
class _BikeTripRoute extends ConsumerWidget {
  const _BikeTripRoute();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void finish() {
      ref.read(bikeTripProvider.notifier).reset();
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.home,
        (route) => false,
      );
    }

    return BikeTripScreen(
      onMenu: () => _pending(context, 'Menú'),
      onProfile: () => _pending(context, 'Perfil'),
      onFinished: finish,
      onCancel: finish,
    );
  }
}

/// A pie, paso 1: a dónde va.
class _OnFootDestinationRoute extends ConsumerWidget {
  const _OnFootDestinationRoute();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DestinationScreen(
      onMenu: () => _pending(context, 'Menú'),
      onProfile: () => _pending(context, 'Perfil'),
      onConfirm: (destination) {
        ref.read(walkTripProvider.notifier).start(destination);
        Navigator.pushReplacementNamed(context, AppRoutes.onFootTrip);
      },
    );
  }
}

/// A pie, paso 2: el camino, esquivando las zonas marcadas.
class _OnFootTripRoute extends ConsumerWidget {
  const _OnFootTripRoute();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void finish() {
      ref.read(walkTripProvider.notifier).reset();
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.home,
        (route) => false,
      );
    }

    return WalkTripScreen(
      onMenu: () => _pending(context, 'Menú'),
      onProfile: () => _pending(context, 'Perfil'),
      onFinished: finish,
      onCancel: finish,
    );
  }
}

/// Abandonar el viaje y volver al inicio.
void _cancelTrip(BuildContext context) {
  final container = ProviderScope.containerOf(context);
  container.read(tripPlanProvider.notifier).reset();
  Navigator.pushNamedAndRemoveUntil(context, AppRoutes.home, (route) => false);
}
