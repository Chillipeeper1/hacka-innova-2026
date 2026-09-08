import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
      },
    );
  }
}

class AppRoutes {
  const AppRoutes._();

  static const String welcome = '/';
  static const String register = '/registro';
  static const String signIn = '/entrar';
}

/// TODO(navegación): al entrar o registrarse debe abrirse el mapa del pasajero; esa pantalla
/// es el Escenario 1 de CLAUDE.md y todavía no existe.
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
      onSubmit: (draft) => _pending(context, 'Alta de ${draft.fullName}'),
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
      onSubmit: (credentials) => _pending(context, 'Entrar como ${credentials.email}'),
      onGoogle: () => _pending(context, 'Acceso con Google'),
      onApple: () => _pending(context, 'Acceso con Apple'),
    );
  }
}
