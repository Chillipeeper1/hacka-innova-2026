import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:maas_morelia/data/panic_alert.dart';
import 'package:maas_morelia/data/providers.dart';
import 'package:maas_morelia/data/trip_plan.dart';
import 'package:maas_morelia/screens/home_screen.dart';
import 'package:maas_morelia/screens/onboard_trip_screen.dart';
import 'package:maas_morelia/theme.dart';
import 'package:maas_morelia/widgets/panic_button.dart';

import 'support/fakes.dart';

/// El botón de pánico durante el viaje.
///
/// Lo que se prueba es el gesto, no el envío: en el mockup no sale nada del teléfono. Que la
/// alerta se dispare **solo** al sostener los tres segundos es la parte que importa — un
/// botón de pánico que se activa con un roce en la bolsa se vuelve ruido y deja de servir.
void main() {
  const trip = 'Ruta Centro - Acueducto, hacia el Acueducto';

  Future<ProviderContainer> pumpButton(
    WidgetTester tester, {
    Size size = const Size(402, 874),
    double textScale = 1.0,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: buildAppTheme(),
          home: MediaQuery(
            data: MediaQueryData(
              size: size,
              textScaler: TextScaler.linear(textScale),
            ),
            child: const Scaffold(
              body: Center(child: PanicButton(width: 402, trip: trip)),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    return container;
  }

  /// Sostiene el botón el tiempo que se le pida y suelta.
  Future<void> hold(WidgetTester tester, Duration duration) async {
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(PanicButton)),
    );
    await tester.pump();
    await tester.pump(duration);
    await gesture.up();
    await tester.pumpAndSettle();
  }

  group('PanicButton', () {
    testWidgets('soltar antes de tiempo no manda nada', (tester) async {
      final container = await pumpButton(tester);

      await hold(tester, panicHoldDuration - const Duration(milliseconds: 500));

      expect(container.read(panicAlertProvider), isNull);
      expect(find.text('Alerta enviada'), findsNothing);
    });

    testWidgets('sostenerlo manda la alerta con el viaje en curso', (
      tester,
    ) async {
      final container = await pumpButton(tester);

      await hold(tester, panicHoldDuration + const Duration(milliseconds: 200));

      expect(container.read(panicAlertProvider)?.trip, trip);
      expect(find.text('Alerta enviada'), findsOneWidget);
      // La hoja dice qué se compartió: una alerta que no lo dice es una en la que no se
      // confía, ni de quien la manda ni de quien la recibe.
      expect(find.textContaining('Ruta Centro - Acueducto'), findsWidgets);
    });

    testWidgets('un toque corto explica el gesto en vez de dispararlo', (
      tester,
    ) async {
      final container = await pumpButton(tester);

      await tester.tap(find.byType(PanicButton));
      await tester.pumpAndSettle();

      expect(container.read(panicAlertProvider), isNull);
      expect(find.textContaining('Mantén presionado'), findsWidgets);
    });

    testWidgets('la falsa alarma cancela la alerta', (tester) async {
      final container = await pumpButton(tester);
      await hold(tester, panicHoldDuration + const Duration(milliseconds: 200));

      await tester.tap(find.text('Fue una falsa alarma'));
      await tester.pumpAndSettle();

      expect(container.read(panicAlertProvider), isNull);
    });

    testWidgets('con la alerta activa el botón lo dice', (tester) async {
      final container = await pumpButton(tester);
      await hold(tester, panicHoldDuration + const Duration(milliseconds: 200));

      await tester.tap(find.text('Entendido'));
      await tester.pumpAndSettle();

      expect(container.read(panicAlertProvider), isNotNull);
      expect(find.text('Activa'), findsOneWidget);
    });

    testWidgets('con la tipografía al doble sigue cabiendo', (tester) async {
      await pumpButton(tester, size: const Size(320, 640), textScale: 2.0);

      expect(tester.takeException(), isNull);
    });
  });

  group('en el viaje', () {
    testWidgets('la pantalla a bordo lo trae', (tester) async {
      tester.view.physicalSize = const Size(402, 874);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final realtime = FakeRealtimeClient();
      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(FakeApi().build()),
          realtimeClientProvider.overrideWithValue(realtime),
        ],
      );
      addTearDown(container.dispose);
      await container.read(routesProvider.future);

      final notifier = container.read(tripPlanProvider.notifier);
      notifier.setDestination(const LatLng(19.6920, -101.1772));
      notifier.choose(container.read(tripPlanProvider).options.first);
      notifier.startWalking();
      notifier.markWaitingAtStop(101);
      notifier.markOnboard(method: PaymentMethod.coins);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: buildAppTheme(),
            home: const OnboardTripScreen(),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(PanicButton), findsOneWidget);
    });

    testWidgets('el inicio no lo trae: no hay viaje que reportar', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(402, 874);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiClientProvider.overrideWithValue(FakeApi().build()),
            realtimeClientProvider.overrideWithValue(FakeRealtimeClient()),
          ],
          child: MaterialApp(theme: buildAppTheme(), home: const HomeScreen()),
        ),
      );
      await tester.pump();

      expect(find.byType(PanicButton), findsNothing);
    });
  });
}
