import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'screens/destination_screen.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/sign_in_screen.dart';
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
      },
    );
  }
}

class AppRoutes {
  const AppRoutes._();

  static const String welcome = '/';
  static const String register = '/registro';
  static const String signIn = '/entrar';
  static const String home = '/inicio';
  static const String destination = '/destino';
}

/// Marcador para las acciones que todavía no llevan a ningún lado.
void _pending(BuildContext context, String what) {
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text('$what: pendiente')));
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
      onSignIn:
          () => Navigator.pushReplacementNamed(context, AppRoutes.signIn),
      // Al darse de alta se entra al mapa y se limpia la pila: regresar a un formulario ya
      // resuelto no tiene sentido.
      onSubmit:
          (_) => Navigator.pushNamedAndRemoveUntil(
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
      onRegister:
          () => Navigator.pushReplacementNamed(context, AppRoutes.register),
      onSubmit:
          (_) => Navigator.pushNamedAndRemoveUntil(
            context,
            AppRoutes.home,
            (route) => false,
          ),
      onGoogle: () => _pending(context, 'Acceso con Google'),
      onApple: () => _pending(context, 'Acceso con Apple'),
    );
  }
}

class _HomeRoute extends StatelessWidget {
  const _HomeRoute();

  @override
  Widget build(BuildContext context) {
    return HomeScreen(
      onMenu: () => _pending(context, 'Menú'),
      onProfile: () => _pending(context, 'Perfil'),
      onSearchStop:
          () => Navigator.pushNamed(context, AppRoutes.destination),
      onTravelByBike: () => _pending(context, 'Viaje en bici'),
      onTravelWalking: () => _pending(context, 'Viaje caminando'),
    );
  }
}

class _DestinationRoute extends StatelessWidget {
  const _DestinationRoute();

  @override
  Widget build(BuildContext context) {
    return DestinationScreen(
      onMenu: () => _pending(context, 'Menú'),
      onProfile: () => _pending(context, 'Perfil'),
      // TODO(ruteo): al confirmar debe calcularse el viaje contra `server/`. Por ahora
      // regresa al mapa con el punto elegido.
      onConfirm: (destination) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Destino: ${destination.latitude.toStringAsFixed(5)}, '
              '${destination.longitude.toStringAsFixed(5)}',
            ),
          ),
        );
      },
    );
  }
}
