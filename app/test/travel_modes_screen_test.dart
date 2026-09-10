import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maas_morelia/data/journey.dart';
import 'package:maas_morelia/screens/travel_modes_screen.dart';
import 'package:maas_morelia/theme.dart';

/// El primer paso del viaje personalizado.
///
/// Existe para que la app no elija por el pasajero: antes de esta pantalla el viaje se armaba
/// con los cuatro medios prendidos y lo primero que se veía era un trayecto en bici que quizá
/// no tenía. Nada se le pide al servidor hasta que de aquí sale una respuesta.
void main() {
  Future<void> pumpAt(
    WidgetTester tester,
    Size size, {
    Set<JourneyMode> initialModes = const {
      JourneyMode.bike,
      JourneyMode.combi,
      JourneyMode.bus,
      JourneyMode.cableCar,
    },
    double textScale = 1.0,
    void Function(Set<JourneyMode>)? onConfirm,
    VoidCallback? onBack,
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
          child: TravelModesScreen(
            initialModes: initialModes,
            onConfirm: onConfirm,
            onBack: onBack,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Toca algo que puede haber quedado abajo del pliegue en pantalla chica.
  Future<void> tapAt(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
  }

  void expectNoLayoutError(WidgetTester tester, String context) {
    final exception = tester.takeException();
    expect(
      exception,
      isNull,
      reason: 'excepción de layout en $context: $exception',
    );
  }

  const viewports = <String, Size>{
    'iPhone SE (pantalla chica)': Size(320, 568),
    'Android compacto': Size(360, 640),
    'lienzo del diseño': Size(402, 874),
    'iPhone Pro Max': Size(430, 932),
    'tablet vertical': Size(768, 1024),
    'tablet horizontal': Size(1024, 768),
    'escritorio / web': Size(1440, 900),
  };

  group('TravelModesScreen se acomoda sin desbordarse', () {
    viewports.forEach((name, size) {
      testWidgets(name, (tester) async {
        await pumpAt(tester, size);
        expectNoLayoutError(tester, name);

        expect(find.text('Continuar'), findsOneWidget);
      });
    });
  });

  testWidgets('aguanta tipografía al doble por accesibilidad', (tester) async {
    await pumpAt(tester, const Size(360, 640), textScale: 2.0);
    expectNoLayoutError(tester, 'tipografía al doble');
  });

  testWidgets('pregunta los medios antes que nada', (tester) async {
    await pumpAt(tester, const Size(402, 874));

    expect(find.text('¿Con qué te quieres mover?'), findsOneWidget);
    // Las dos preguntas: cómo se mueve por su cuenta y qué transporte acepta.
    expect(find.text('En bici'), findsOneWidget);
    expect(find.text('Caminando'), findsOneWidget);
    expect(find.text('Combi'), findsOneWidget);
    expect(find.text('Camión'), findsOneWidget);
    expect(find.text('Teleférico'), findsOneWidget);
  });

  testWidgets('bici y caminando son excluyentes', (tester) async {
    Set<JourneyMode>? chosen;
    await pumpAt(
      tester,
      const Size(402, 874),
      onConfirm: (modes) => chosen = modes,
    );

    await tapAt(tester, find.text('Caminando'));
    await tester.pumpAndSettle();
    await tapAt(tester, find.text('Continuar'));
    expect(chosen, isNot(contains(JourneyMode.bike)));

    await tapAt(tester, find.text('En bici'));
    await tester.pumpAndSettle();
    await tapAt(tester, find.text('Continuar'));
    expect(chosen, contains(JourneyMode.bike));
  });

  testWidgets('el transporte se combina libremente', (tester) async {
    Set<JourneyMode>? chosen;
    await pumpAt(
      tester,
      const Size(402, 874),
      onConfirm: (modes) => chosen = modes,
    );

    await tapAt(tester, find.text('Combi'));
    await tapAt(tester, find.text('Teleférico'));
    await tester.pumpAndSettle();
    await tapAt(tester, find.text('Continuar'));

    expect(chosen, {JourneyMode.bike, JourneyMode.bus});
  });

  testWidgets('arranca con los medios que ya traía el viaje', (tester) async {
    // Volver a esta pantalla para corregir no debe borrar lo que ya se había elegido.
    Set<JourneyMode>? chosen;
    await pumpAt(
      tester,
      const Size(402, 874),
      initialModes: const {JourneyMode.bus},
      onConfirm: (modes) => chosen = modes,
    );

    await tapAt(tester, find.text('Continuar'));
    expect(chosen, {JourneyMode.bus});
  });

  testWidgets('solo caminando no es un viaje que este modo pueda armar', (
    tester,
  ) async {
    // Con el filtro vacío el servidor entiende "todos" y devolvería justo lo contrario de lo
    // que se pidió. Para ir solo a pie está "Viajar caminando".
    var confirmed = false;
    await pumpAt(
      tester,
      const Size(402, 874),
      initialModes: const {JourneyMode.bike},
      onConfirm: (_) => confirmed = true,
    );

    await tapAt(tester, find.text('Caminando'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Viajar caminando'), findsOneWidget);
    await tapAt(tester, find.text('Continuar'));
    await tester.pump();
    expect(confirmed, isFalse);
  });

  testWidgets('se puede regresar sin elegir', (tester) async {
    var back = false;
    await pumpAt(tester, const Size(402, 874), onBack: () => back = true);

    await tapAt(tester, find.text('regresar'));
    await tester.pump();
    expect(back, isTrue);
  });
}
