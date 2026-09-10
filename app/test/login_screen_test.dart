import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maas_morelia/screens/login_screen.dart';
import 'package:maas_morelia/theme.dart';
import 'package:maas_morelia/widgets/branding.dart';

/// Verifica que la pantalla inicial aguante los tamaños reales en los que va a correr.
///
/// El diseño de Figma viene de un lienzo fijo de 402x874. Estas pruebas existen para que esa
/// medida no se cuele como supuesto: si alguien vuelve a meter un tamaño en píxeles duros, el
/// caso de teléfono chico o el de tipografía grande truena aquí y no en la demo.
void main() {
  Future<void> pumpAt(
    WidgetTester tester,
    Size size, {
    double textScale = 1.0,
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
          child: const LoginScreen(),
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
    'muy corto (teclado abierto)': Size(402, 480),
  };

  group('LoginScreen se acomoda sin desbordarse', () {
    viewports.forEach((name, size) {
      testWidgets(name, (tester) async {
        await pumpAt(tester, size);

        // Un RenderFlex desbordado se reporta como excepción: si la hay, el layout rompió.
        expect(
          tester.takeException(),
          isNull,
          reason: 'desbordamiento en $name',
        );

        expect(find.byType(MtappLogo), findsOneWidget);
        expect(find.text('Entrar'), findsOneWidget);
        expect(find.text('Sigue tu camión en tiempo real'), findsOneWidget);
      });
    });
  });

  testWidgets('aguanta tipografía al doble por accesibilidad', (tester) async {
    await pumpAt(tester, const Size(360, 640), textScale: 2.0);
    expect(tester.takeException(), isNull);
    expect(find.text('Entrar'), findsOneWidget);
  });

  testWidgets('el contenido no se estira más allá del tope de lectura', (
    tester,
  ) async {
    await pumpAt(tester, const Size(1440, 900));

    final button = tester.getSize(find.byType(FilledButton));
    // Sin tope, en escritorio el botón mediría más de mil píxeles de ancho.
    expect(button.width, lessThanOrEqualTo(maxContentWidth));
  });

  testWidgets('en pantalla corta el contenido se desplaza en vez de romperse', (
    tester,
  ) async {
    await pumpAt(tester, const Size(402, 420));
    expect(tester.takeException(), isNull);
    expect(find.byType(SingleChildScrollView), findsOneWidget);
  });

  testWidgets('los botones sociales quedan accesibles por lector de pantalla', (
    tester,
  ) async {
    await pumpAt(tester, const Size(402, 874));

    expect(find.bySemanticsLabel('Continuar con Google'), findsOneWidget);
    expect(find.bySemanticsLabel('Continuar con Apple'), findsOneWidget);
  });
}
