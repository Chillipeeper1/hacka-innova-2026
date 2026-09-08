import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maas_morelia/screens/register_screen.dart';
import 'package:maas_morelia/theme.dart';
import 'package:maas_morelia/widgets/inputs.dart';

void main() {
  Future<void> pumpAt(
    WidgetTester tester,
    Size size, {
    double textScale = 1.0,
    void Function(RegistrationDraft)? onSubmit,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        locale: const Locale('es', 'MX'),
        supportedLocales: const [Locale('es', 'MX'), Locale('es')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: MediaQuery(
          data: MediaQueryData(
            size: size,
            textScaler: TextScaler.linear(textScale),
          ),
          child: RegisterScreen(onSubmit: onSubmit),
        ),
      ),
    );
    await tester.pump();
  }

  const viewports = <String, Size>{
    'iPhone SE (pantalla chica)': Size(320, 568),
    'Android compacto': Size(360, 640),
    'lienzo del diseño': Size(402, 874),
    'iPhone Pro Max': Size(430, 932),
    'tablet vertical': Size(768, 1024),
    'tablet horizontal': Size(1024, 768),
    'escritorio / web': Size(1440, 900),
    'con teclado abierto': Size(402, 380),
  };

  group('RegisterScreen se acomoda sin desbordarse', () {
    viewports.forEach((name, size) {
      testWidgets(name, (tester) async {
        await pumpAt(tester, size);

        expect(tester.takeException(), isNull, reason: 'desbordamiento en $name');
        expect(find.text('Registrarse'), findsWidgets);
      });
    });
  });

  testWidgets('aguanta tipografía al doble por accesibilidad', (tester) async {
    await pumpAt(tester, const Size(360, 640), textScale: 2.0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('muestra los cinco campos del diseño', (tester) async {
    await pumpAt(tester, const Size(402, 874));

    for (final label in const [
      'Nombre completo',
      'Correo',
      'Fecha de nacimiento',
      'Contraseña',
      'Confirmar contraseña',
    ]) {
      expect(find.text(label), findsOneWidget, reason: 'falta "$label"');
    }
  });

  testWidgets('no envía con el formulario vacío', (tester) async {
    var submissions = 0;
    await pumpAt(
      tester,
      const Size(402, 874),
      onSubmit: (_) => submissions++,
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Registrarse'));
    await tester.pumpAndSettle();

    expect(submissions, 0);
    expect(find.text('Escribe tu nombre completo'), findsOneWidget);
    expect(find.text('Escribe un correo válido'), findsOneWidget);
  });

  testWidgets('rechaza contraseñas que no coinciden', (tester) async {
    var submissions = 0;
    await pumpAt(
      tester,
      const Size(402, 1400), // alto suficiente para no tener que desplazar
      onSubmit: (_) => submissions++,
    );

    await tester.enterText(find.byType(TextFormField).at(0), 'Ana López');
    await tester.enterText(find.byType(TextFormField).at(1), 'ana@ejemplo.mx');
    await tester.enterText(find.byType(TextFormField).at(2), 'contrasena1');
    await tester.enterText(find.byType(TextFormField).at(3), 'otracosa99');

    await tester.tap(find.widgetWithText(FilledButton, 'Registrarse'));
    await tester.pumpAndSettle();

    expect(submissions, 0);
    expect(find.text('Las contraseñas no coinciden'), findsOneWidget);
  });

  testWidgets('entrega los datos cuando todo es válido', (tester) async {
    RegistrationDraft? received;
    await pumpAt(
      tester,
      const Size(402, 1400),
      onSubmit: (draft) => received = draft,
    );

    await tester.enterText(find.byType(TextFormField).at(0), 'Ana López');
    await tester.enterText(find.byType(TextFormField).at(1), 'ana@ejemplo.mx');
    await tester.enterText(find.byType(TextFormField).at(2), 'contrasena1');
    await tester.enterText(find.byType(TextFormField).at(3), 'contrasena1');

    await tester.tap(find.widgetWithText(FilledButton, 'Registrarse'));
    await tester.pumpAndSettle();

    expect(received, isNotNull);
    expect(received!.fullName, 'Ana López');
    expect(received!.email, 'ana@ejemplo.mx');
  });

  testWidgets('el ojo revela y vuelve a ocultar la contraseña', (tester) async {
    await pumpAt(tester, const Size(402, 1400));

    final passwordField = find.byType(PillPasswordField).first;
    EditableText editable() =>
        tester.widget<EditableText>(find.descendant(
          of: passwordField,
          matching: find.byType(EditableText),
        ));

    expect(editable().obscureText, isTrue);

    await tester.tap(
      find.descendant(of: passwordField, matching: find.byType(IconButton)),
    );
    await tester.pump();

    expect(editable().obscureText, isFalse);
  });

  testWidgets('la fecha de nacimiento abre el selector', (tester) async {
    await pumpAt(tester, const Size(402, 1400));

    await tester.tap(find.byType(PillDateField));
    await tester.pumpAndSettle();

    expect(find.text('Fecha de nacimiento'), findsWidgets);
    expect(find.byType(DatePickerDialog), findsOneWidget);
  });

  testWidgets('el contenido no se estira más allá del tope de lectura', (
    tester,
  ) async {
    await pumpAt(tester, const Size(1440, 900));

    final button = tester.getSize(find.byType(FilledButton));
    expect(button.width, lessThanOrEqualTo(maxContentWidth));
  });
}
