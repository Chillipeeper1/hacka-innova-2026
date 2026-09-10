import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/bike_trip.dart';
import 'data/cable_car_trip.dart';
import 'data/journey_trip.dart';
import 'data/trip_plan.dart';
import 'data/walk_trip.dart';
import 'screens/plus_screen.dart';
import 'screens/confirm_stop_screen.dart';
import 'screens/destination_screen.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/sign_in_screen.dart';
import 'screens/stop_picker_screen.dart';
import 'screens/travel_modes_screen.dart';
import 'screens/bike_trip_screen.dart';
import 'screens/cable_car_trip_screen.dart';
import 'screens/journey_screen.dart';
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
        AppRoutes.plus: (context) => const _PlusRoute(),
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
        AppRoutes.cableCarDestination: (context) =>
            const _CableCarDestinationRoute(),
        AppRoutes.cableCarTrip: (context) => const _CableCarTripRoute(),
        AppRoutes.customModes: (context) => const _CustomModesRoute(),
        AppRoutes.customDestination: (context) =>
            const _CustomDestinationRoute(),
        AppRoutes.customTrip: (context) => const _CustomTripRoute(),
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

  /// MTAPP Plus: agenda, guardianes y caja negra en una sola pantalla. Cuelga del inicio y no
  /// de un flujo de viaje — no lleva a ningún lado, se consulta y se regresa.
  static const String plus = '/plus';
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

  static const String cableCarDestination = '/destino-telef';
  static const String cableCarTrip = '/en-telef';

  /// El viaje personalizado: el único donde el usuario elige los medios, y el único cuyo
  /// itinerario lo arma el servidor en vez del cliente.
  ///
  /// Los medios van **primero**, antes del destino: son el filtro con el que se pide el
  /// itinerario, y preguntarlos después obliga a armar uno con los cuatro y a corregirlo.
  static const String customModes = '/medios-personalizado';
  static const String customDestination = '/destino-personalizado';
  static const String customTrip = '/viaje-personalizado';
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
      onPlus: () => Navigator.pushNamed(context, AppRoutes.plus),
      onAd: () => _pending(context, 'Publicidad'),
      onCustomTrip: () {
        ref.read(journeyTripProvider.notifier).reset();
        Navigator.pushNamed(context, AppRoutes.customModes);
      },
      onTravelByBike: () {
        ref.read(bikeTripProvider.notifier).reset();
        Navigator.pushNamed(context, AppRoutes.bikeDestination);
      },
      onTravelWalking: () {
        ref.read(walkTripProvider.notifier).reset();
        Navigator.pushNamed(context, AppRoutes.onFootDestination);
      },
      onTravelByCableCar: () {
        ref.read(cableCarTripProvider.notifier).reset();
        Navigator.pushNamed(context, AppRoutes.cableCarDestination);
      },
    );
  }
}

/// MTAPP Plus: todo lo que se paga, en una pantalla.
///
/// Se apila sobre el inicio en vez de reemplazarlo: no es un paso de ningún viaje, es una
/// consulta de la que se regresa a lo que se estaba haciendo.
class _PlusRoute extends StatelessWidget {
  const _PlusRoute();

  @override
  Widget build(BuildContext context) {
    return PlusScreen(
      onMenu: () => _pending(context, 'Menú'),
      onProfile: () => _pending(context, 'Perfil'),
      onBack: () => Navigator.pop(context),
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

/// Teleférico, paso 1: a dónde va.
class _CableCarDestinationRoute extends ConsumerWidget {
  const _CableCarDestinationRoute();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DestinationScreen(
      onMenu: () => _pending(context, 'Menú'),
      onProfile: () => _pending(context, 'Perfil'),
      onConfirm: (destination) {
        ref.read(cableCarTripProvider.notifier).start(destination);
        Navigator.pushReplacementNamed(context, AppRoutes.cableCarTrip);
      },
    );
  }
}

/// Teleférico, paso 2: el viaje. Las estaciones las elige el sistema, no el usuario: son
/// siempre la más cercana a él y la que lo deja más cerca, así que no hay nada que preguntar.
class _CableCarTripRoute extends ConsumerWidget {
  const _CableCarTripRoute();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void finish() {
      ref.read(cableCarTripProvider.notifier).reset();
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.home,
        (route) => false,
      );
    }

    return CableCarTripScreen(
      onMenu: () => _pending(context, 'Menú'),
      onProfile: () => _pending(context, 'Perfil'),
      onFinished: finish,
      onCancel: finish,
    );
  }
}

/// Personalizado, paso 1: con qué se quiere mover.
///
/// Antes de esto no se le pide nada al servidor. Con `modes` en la mano, la primera respuesta
/// ya es el viaje que el pasajero pidió y no uno que haya que corregir.
class _CustomModesRoute extends ConsumerWidget {
  const _CustomModesRoute();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return TravelModesScreen(
      initialModes: ref.read(journeyTripProvider).modes,
      onMenu: () => _pending(context, 'Menú'),
      onProfile: () => _pending(context, 'Perfil'),
      onBack: () => Navigator.pop(context),
      onConfirm: (modes) {
        ref.read(journeyTripProvider.notifier).setModes(modes);
        // Sin reemplazar: volver atrás desde el destino tiene que devolver a los medios, que
        // es lo que se cambia cuando el viaje propuesto no sirve.
        Navigator.pushNamed(context, AppRoutes.customDestination);
      },
    );
  }
}

/// Personalizado, paso 2: a dónde va.
class _CustomDestinationRoute extends ConsumerWidget {
  const _CustomDestinationRoute();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DestinationScreen(
      onMenu: () => _pending(context, 'Menú'),
      onProfile: () => _pending(context, 'Perfil'),
      onConfirm: (destination) {
        // No se espera al servidor para navegar: la pantalla del viaje tiene su propio estado
        // de carga, y quedarse en la de destino sin señal de nada se siente a app colgada.
        ref.read(journeyTripProvider.notifier).start(destination);
        Navigator.pushReplacementNamed(context, AppRoutes.customTrip);
      },
    );
  }
}

/// Personalizado, paso 3: el itinerario, que arma el servidor con los medios elegidos.
class _CustomTripRoute extends ConsumerWidget {
  const _CustomTripRoute();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void finish() {
      ref.read(journeyTripProvider.notifier).reset();
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.home,
        (route) => false,
      );
    }

    return JourneyScreen(
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
