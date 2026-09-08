import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maas_morelia/screens/sign_in_screen.dart';
import 'package:maas_morelia/theme.dart';
import 'package:maas_morelia/widgets/inputs.dart';

void main() {
  Future<void> pumpAt(
    WidgetTester tester,
    Size size, {
    double textScale = 1.0,
    void Function(SignInCredentials)? onSubmit,
    VoidCallback? onRegister,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: MediaQuery(
          data: MediaQueryData(
            size: size,
            textScaler: TextScaler.linear(textScale),
          ),
          child: SignInScreen(onSubmit: onSubmit, onRegister: onRegister),
        ),
      ),
    );
    await tester.pump();
  }

  const viewports = <String, Size>{
    'iPhone SE (pantalla chica)': Size(320, 568),
    'Android compacto': Size(360, 640),
    'lienzo del diseño': Size(402, 874),
    'tablet vertical': Size(768, 1024),
    'tablet horizontal': Size(1024, 768),
    'escritorio / web': Size(1440, 900),
    'con teclado abierto': Size(402, 380),
  };

  group('SignInScreen se acomoda sin desbordarse', () {
    viewports.forEach((name, size) {
      testWidgets(name, (tester) async {
        await pumpAt(tester, size);
        expect(tester.takeException(), isNull, reason: 'desbordamiento en $name');
        expect(find.text('Iniciar sesión'), findsOneWidget);
      });
    });
  });

  testWidgets('aguanta tipografía al doble por accesibilidad', (tester) async {
    await pumpAt(tester, const Size(360, 640), textScale: 2.0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('muestra solo los dos campos del diseño', (tester) async {
    await pumpAt(tester, const Size(402, 874));

    expect(find.text('Correo'), findsOneWidget);
    expect(find.text('Contraseña'), findsOneWidget);
    // Los campos exclusivos del registro no deben aparecer aquí.
    expect(find.text('Nombre completo'), findsNothing);
    expect(find.text('Confirmar contraseña'), findsNothing);
    expect(find.byType(PillDateField), findsNothing);
  });

  testWidgets('ofrece ir al registro, no a iniciar sesión', (tester) async {
    var toRegister = 0;
    await pumpAt(
      tester,
      const Size(402, 874),
      onRegister: () => toRegister++,
    );

    expect(find.textContaining('¿No tienes cuenta?'), findsOneWidget);

    await tester.tap(find.textContaining('¿No tienes cuenta?'));
    await tester.pump();
    expect(toRegister, 1);
  });

  testWidgets('no entra con el formulario vacío', (tester) async {
    var submissions = 0;
    await pumpAt(
      tester,
      const Size(402, 874),
      onSubmit: (_) => submissions++,
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Entrar'));
    await tester.pumpAndSettle();

    expect(submissions, 0);
    expect(find.text('Escribe un correo válido'), findsOneWidget);
    expect(find.text('Escribe tu contraseña'), findsOneWidget);
  });

  testWidgets('entrega las credenciales cuando son válidas', (tester) async {
    SignInCredentials? received;
    await pumpAt(
      tester,
      const Size(402, 874),
      onSubmit: (value) => received = value,
    );

    await tester.enterText(find.byType(TextFormField).at(0), 'ana@ejemplo.mx');
    await tester.enterText(find.byType(TextFormField).at(1), 'contrasena1');

    await tester.tap(find.widgetWithText(FilledButton, 'Entrar'));
    await tester.pumpAndSettle();

    expect(received, isNotNull);
    expect(received!.email, 'ana@ejemplo.mx');
    expect(received!.password, 'contrasena1');
  });

  testWidgets('no exige longitud mínima al entrar', (tester) async {
    // La fortaleza se valida al registrarse. Rechazar aquí una contraseña corta impediría
    // entrar a quien la creó antes de esa regla.
    SignInCredentials? received;
    await pumpAt(
      tester,
      const Size(402, 874),
      onSubmit: (value) => received = value,
    );

    await tester.enterText(find.byType(TextFormField).at(0), 'ana@ejemplo.mx');
    await tester.enterText(find.byType(TextFormField).at(1), 'abc');

    await tester.tap(find.widgetWithText(FilledButton, 'Entrar'));
    await tester.pumpAndSettle();

    expect(received?.password, 'abc');
  });

  testWidgets('el contenido no se estira más allá del tope de lectura', (
    tester,
  ) async {
    await pumpAt(tester, const Size(1440, 900));

    final button = tester.getSize(find.byType(FilledButton));
    expect(button.width, lessThanOrEqualTo(maxContentWidth));
  });
}
