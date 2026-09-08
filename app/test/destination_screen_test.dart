import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:maas_morelia/morelia.dart';
import 'package:maas_morelia/screens/destination_screen.dart';
import 'package:maas_morelia/theme.dart';

void main() {
  Future<void> pumpAt(
    WidgetTester tester,
    Size size, {
    double textScale = 1.0,
    void Function(LatLng)? onConfirm,
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
          child: DestinationScreen(onConfirm: onConfirm, onBack: onBack),
        ),
      ),
    );
    await tester.pump();
  }

  /// Las teselas se piden por red y en pruebas eso siempre falla (el cliente HTTP de
  /// `flutter_test` responde 400). Ese error no dice nada sobre el layout.
  void expectNoLayoutError(WidgetTester tester, String context) {
    final exception = tester.takeException();
    if (exception == null) return;
    final text = exception.toString();
    final isTileFailure =
        text.contains('HttpException') ||
        text.contains('400') ||
        text.contains('NetworkImage') ||
        text.contains('Failed to load');
    expect(
      isTileFailure,
      isTrue,
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

  group('DestinationScreen se acomoda sin desbordarse', () {
    viewports.forEach((name, size) {
      testWidgets(name, (tester) async {
        await pumpAt(tester, size);
        expectNoLayoutError(tester, name);

        expect(find.text('¿A dónde vas?'), findsOneWidget);
        expect(find.text('Confirmar'), findsOneWidget);
      });
    });
  });

  testWidgets('aguanta tipografía al doble por accesibilidad', (tester) async {
    await pumpAt(tester, const Size(360, 640), textScale: 2.0);
    expectNoLayoutError(tester, 'tipografía al doble');
  });

  testWidgets('el pin apunta al centro del mapa, no a su propio centro', (
    tester,
  ) async {
    const size = Size(402, 874);
    await pumpAt(tester, size);
    expectNoLayoutError(tester, 'pin');

    final pinRect = tester.getRect(find.byKey(const ValueKey('center-pin')));
    // La punta del pin es su borde inferior y debe caer sobre el centro geométrico de la
    // pantalla, que es el punto que el mapa reporta como su centro.
    expect(pinRect.bottom, closeTo(size.height / 2, 1.0));
    expect(pinRect.center.dx, closeTo(size.width / 2, 1.0));
  });

  testWidgets('muestra el punto inicial y confirma ese mismo punto', (
    tester,
  ) async {
    LatLng? confirmed;
    await pumpAt(
      tester,
      const Size(402, 874),
      onConfirm: (value) => confirmed = value,
    );
    expectNoLayoutError(tester, 'confirmación');

    // Sin mover el mapa, el punto elegido es el centro inicial.
    expect(
      find.text(
        '${Morelia.center.latitude.toStringAsFixed(5)}, '
        '${Morelia.center.longitude.toStringAsFixed(5)}',
      ),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Confirmar'));
    await tester.pump();

    expect(confirmed, isNotNull);
    expect(confirmed!.latitude, closeTo(Morelia.center.latitude, 0.0001));
    expect(confirmed!.longitude, closeTo(Morelia.center.longitude, 0.0001));
  });

  testWidgets('el pin no intercepta el arrastre del mapa', (tester) async {
    await pumpAt(tester, const Size(402, 874));
    expectNoLayoutError(tester, 'gestos');

    // El pin va dentro de un IgnorePointer activo: si capturara el gesto, arrastrar sobre él
    // no movería el mapa y el usuario no podría elegir el punto que está justo debajo.
    // Flutter inserta otros IgnorePointer inactivos en el árbol, así que se busca el que
    // realmente está ignorando.
    final ignoring = tester
        .widgetList<IgnorePointer>(
          find.ancestor(
            of: find.byKey(const ValueKey('center-pin')),
            matching: find.byType(IgnorePointer),
          ),
        )
        .where((widget) => widget.ignoring);

    expect(ignoring, isNotEmpty);
  });

  testWidgets('el botón de regresar es accesible y responde', (tester) async {
    var backs = 0;
    await pumpAt(tester, const Size(402, 874), onBack: () => backs++);
    expectNoLayoutError(tester, 'regreso');

    expect(find.bySemanticsLabel('Regresar'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Regresar'));
    await tester.pump();
    expect(backs, 1);
  });

  testWidgets('el mapa es real y acotado a Morelia', (tester) async {
    await pumpAt(tester, const Size(402, 874));
    expectNoLayoutError(tester, 'mapa');

    final map = tester.widget<FlutterMap>(find.byType(FlutterMap));
    expect(map.options.cameraConstraint, isA<ContainCameraCenter>());
  });

  testWidgets('los controles no se estiran en escritorio', (tester) async {
    await pumpAt(tester, const Size(1440, 900));
    expectNoLayoutError(tester, 'escritorio');

    final button = tester.getSize(find.byType(FilledButton));
    expect(button.width, lessThanOrEqualTo(maxContentWidth));
  });
}
