import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maas_morelia/data/plus_account.dart';
import 'package:maas_morelia/data/rewards.dart';
import 'package:maas_morelia/data/safe_trip.dart';
import 'package:maas_morelia/screens/plus_screen.dart';
import 'package:maas_morelia/theme.dart';

void main() {
  Future<void> pumpAt(
    WidgetTester tester,
    Size size, {
    double textScale = 1.0,
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
          child: PlusScreen(onBack: onBack),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> openTab(WidgetTester tester, String label) async {
    await tester.tap(find.text(label));
    await tester.pump();
  }

  /// Los controles de más abajo quedan fuera de la vista en un teléfono: hay que rodar la
  /// pantalla hasta ellos antes de tocarlos, igual que haría una persona.
  Future<void> tapText(WidgetTester tester, String label) async {
    await tester.ensureVisible(find.text(label));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label));
    await tester.pump();
  }

  const account = demoPlusAccount;

  const viewports = <String, Size>{
    'iPhone SE (pantalla chica)': Size(320, 568),
    'Android compacto': Size(360, 640),
    'lienzo del diseño': Size(402, 874),
    'iPhone Pro Max': Size(430, 932),
    'tablet vertical': Size(768, 1024),
    'escritorio / web': Size(1440, 900),
  };

  group('PlusScreen se acomoda sin desbordarse', () {
    viewports.forEach((name, size) {
      testWidgets(name, (tester) async {
        await pumpAt(tester, size);
        expect(tester.takeException(), isNull, reason: 'desbordó en $name');
        expect(find.text('MTAPP Plus'), findsWidgets);

        // Las cuatro pestañas tienen que caber, no solo la primera.
        for (final tab in ['Guardianes', 'Mis viajes', 'Recompensas']) {
          await openTab(tester, tab);
          expect(
            tester.takeException(),
            isNull,
            reason: '$tab desbordó en $name',
          );
        }
      });
    });
  });

  testWidgets('aguanta tipografía al doble por accesibilidad', (tester) async {
    await pumpAt(tester, const Size(320, 568), textScale: 2.0);
    expect(tester.takeException(), isNull);

    for (final tab in ['Guardianes', 'Mis viajes', 'Recompensas']) {
      await openTab(tester, tab);
      expect(tester.takeException(), isNull, reason: '$tab con texto grande');
    }
  });

  group('las tres pestañas son el mismo dato', () {
    testWidgets('el viaje acompañado sale del plan de la agenda', (
      tester,
    ) async {
      // El vínculo que hace que esto sea un producto y no dos: la hora a la que se avisa a los
      // guardianes es la que la agenda calculó, no un dato escrito aparte.
      expect(account.guardedTrip.arrivalMinutes, account.plan.arrivalMinutes);
      expect(account.guardedTrip.title, account.plan.title);

      await pumpAt(tester, const Size(402, 874));

      // La agenda enseña ese plan...
      expect(find.text(account.plan.title), findsOneWidget);
      expect(
        find.text('Sal ${formatClock(account.plan.departureMinutes)}'),
        findsOneWidget,
      );

      // ...y los guardianes enseñan el mismo, con la llegada que calculó la agenda.
      await openTab(tester, 'Guardianes');
      expect(
        find.text('Llegas ${formatClock(account.plan.arrivalMinutes)}'),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          'De tu agenda del ${account.guardedDayName.toLowerCase()}',
        ),
        findsOneWidget,
      );
    });

    testWidgets('el aviso usa la hora que calculó la agenda', (tester) async {
      // El texto del disparador se genera del plan. Antes estaba escrito a mano y podía
      // contradecir a la tarjeta que calculaba la misma hora.
      await pumpAt(tester, const Size(402, 874));
      await openTab(tester, 'Guardianes');

      final alertAt = formatClock(account.guardedTrip.alertAtMinutes);
      expect(
        find.textContaining('Si a las $alertAt no has llegado'),
        findsOneWidget,
      );
    });

    testWidgets('el historial dice que es lo que enseñó a la agenda', (
      tester,
    ) async {
      await pumpAt(tester, const Size(402, 874));

      // El mismo número en las dos pestañas, porque son los mismos viajes.
      expect(
        find.textContaining(
          'Aprendida de tus ${account.learnedFromTrips} viajes',
        ),
        findsOneWidget,
      );

      await openTab(tester, 'Mis viajes');
      expect(
        find.textContaining(
          'los ${account.learnedFromTrips} viajes con los que armamos',
        ),
        findsOneWidget,
      );
    });

    testWidgets('apagar un guardián se nota también en la agenda', (
      tester,
    ) async {
      // La prueba del vínculo en vivo: el estado vive en la pantalla, no en la pestaña, así
      // que las dos tienen que contar lo mismo.
      await pumpAt(tester, const Size(402, 874));

      expect(find.textContaining('Mamá y Ana lo están viendo'), findsOneWidget);

      await openTab(tester, 'Guardianes');
      await tester.tap(find.bySemanticsLabel('Ana'));
      await tester.pump();

      await openTab(tester, 'Agenda');
      expect(find.textContaining('Mamá lo están viendo'), findsOneWidget);
      expect(find.textContaining('Mamá y Ana'), findsNothing);
    });
  });

  group('agenda', () {
    testWidgets('enseña hora de salida, duración y atajo', (tester) async {
      await pumpAt(tester, const Size(402, 874));

      final plan = account.week.days.first.plans.first;
      expect(find.text('Sal ${formatClock(plan.departureMinutes)}'), findsOne);
      expect(
        find.textContaining('${plan.durationMinutes} min en camino'),
        findsOneWidget,
      );
      expect(find.textContaining('Atajo · ahorras'), findsWidgets);
      expect(find.text(formatDuration(account.week.savedMinutes)), findsOne);
    });

    testWidgets('cada recomendación dice de dónde salió', (tester) async {
      await pumpAt(tester, const Size(402, 874));

      final plan = account.week.days.first.plans.first;
      expect(
        find.text('Aprendido de tus ${plan.learnedFrom} viajes parecidos'),
        findsOneWidget,
      );
      expect(find.text('${plan.confidence} % seguro'), findsOneWidget);
    });

    testWidgets('cambiar de día cambia los viajes', (tester) async {
      await pumpAt(tester, const Size(402, 874));

      expect(find.text('Trabajo → Casa'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Jueves'));
      await tester.pump();

      expect(find.text('Trabajo → Central de Autobuses'), findsOneWidget);
      expect(find.text('Trabajo → Casa'), findsNothing);
    });

    testWidgets('un día sin viajes explica por qué está vacío', (tester) async {
      // Un domingo en blanco sin texto se lee como una falla de la app, no como un día libre.
      await pumpAt(tester, const Size(402, 874));

      await tester.tap(find.bySemanticsLabel('Domingo'));
      await tester.pump();

      expect(find.textContaining('No tenemos salidas tuyas'), findsOneWidget);
      expect(find.textContaining('Sal '), findsNothing);
    });
  });

  group('guardianes', () {
    testWidgets('dice quién recibe el aviso y qué lo dispara', (tester) async {
      // Lo que se paga no es compartir ubicación: es que el sistema vigile solo. Si la
      // pantalla no enumera qué dispara el aviso, la función no se distingue de un enlace
      // de WhatsApp.
      await pumpAt(tester, const Size(402, 874));
      await openTab(tester, 'Guardianes');

      for (final guardian in account.guardians) {
        expect(find.text(guardian.name), findsOneWidget);
      }
      for (final trigger in account.guardedTrip.triggers) {
        expect(find.text(trigger.label), findsOneWidget);
      }
    });

    testWidgets('la alerta se puede enseñar, no solo describir', (
      tester,
    ) async {
      // El botón de simular existe para la demo: una tarjeta que se pone en rojo frente a un
      // jurado vale más que un párrafo explicando qué pasaría.
      await pumpAt(tester, const Size(402, 874));
      await openTab(tester, 'Guardianes');

      expect(find.textContaining('En camino'), findsOneWidget);
      expect(find.text('No llegaste a tiempo'), findsNothing);

      await tapText(tester, 'Simular que no llegué');

      expect(find.text('No llegaste a tiempo'), findsOneWidget);
      expect(find.textContaining('Avisamos a Mamá y Ana'), findsOneWidget);
      expect(find.text(demoAlertPayload.first), findsOneWidget);

      // Y se puede reiniciar: si no, la demo sirve una sola vez por sesión.
      await tapText(tester, 'Volver al viaje normal');
      expect(find.text('No llegaste a tiempo'), findsNothing);
    });

    testWidgets('apagar un guardián lo saca del aviso', (tester) async {
      await pumpAt(tester, const Size(402, 874));
      await openTab(tester, 'Guardianes');

      await tester.tap(find.bySemanticsLabel('Ana'));
      await tester.pump();
      await tapText(tester, 'Simular que no llegué');

      expect(find.textContaining('Avisamos a Mamá a las'), findsOneWidget);
      expect(find.textContaining('Avisamos a Mamá y Ana'), findsNothing);
    });

    testWidgets('el botón de pánico se marca como gratuito', (tester) async {
      // Cobrar por un botón de pánico es la crítica más fácil que le pueden hacer al
      // proyecto. Que la pantalla lo diga es una decisión de producto, no un detalle.
      await pumpAt(tester, const Size(402, 874));
      await openTab(tester, 'Guardianes');

      expect(find.text('Botón de pánico'), findsOneWidget);
      expect(find.text('Gratis'), findsOneWidget);
      expect(
        find.textContaining('Incluido en el plan gratuito'),
        findsOneWidget,
      );
    });
  });

  group('mis viajes: la caja negra', () {
    testWidgets('los recientes se ven y los viejos van con candado', (
      tester,
    ) async {
      // El muro de pago no se explica, se ve.
      await pumpAt(tester, const Size(402, 874));
      await openTab(tester, 'Mis viajes');

      final locked = account.tripLog.where((r) => r.locked).length;

      expect(find.textContaining('disponible con Plus'), findsNWidgets(locked));
      expect(
        find.text(
          'Ves ${account.visibleTrips} de ${account.tripLog.length} viajes',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining('El plan gratuito guarda $freeRetentionDays días'),
        findsOneWidget,
      );
      // Con Plus no hay tope: no es "más meses", es que no se borran.
      expect(plusKeepsForever, isTrue);
      expect(find.textContaining('se guardan para siempre'), findsOneWidget);
    });

    testWidgets('exportar avisa que no está conectado', (tester) async {
      await pumpAt(tester, const Size(402, 874));
      await openTab(tester, 'Mis viajes');

      await tapText(tester, 'Exportar PDF');
      expect(find.textContaining('no está conectada'), findsOneWidget);
    });
  });

  group('recompensas', () {
    testWidgets('enseña el saldo, el ritmo y a qué tarjeta va', (tester) async {
      // Cincuenta centavos sueltos no parecen gran cosa: el saldo acumulado y la proyección
      // al mes son lo que vuelve tangible el incentivo.
      await pumpAt(tester, const Size(402, 874));
      await openTab(tester, 'Recompensas');

      final wallet = account.rewards;
      expect(find.text(formatPesos(wallet.balanceCents)), findsOneWidget);
      expect(find.textContaining(wallet.cardUid), findsOneWidget);
      expect(
        find.textContaining(formatPesos(wallet.monthlyProjectionCents)),
        findsOneWidget,
      );
    });

    testWidgets('enseña el tope diario y para qué está', (tester) async {
      await pumpAt(tester, const Size(402, 874));
      await openTab(tester, 'Recompensas');

      expect(
        find.text(
          'Hoy llevas ${formatPesos(account.rewards.todayCents, withCurrency: false)}',
        ),
        findsOneWidget,
      );
      expect(
        find.text('de ${formatPesos(rewardDailyCapCents)}'),
        findsOneWidget,
      );
      // El tope no se enseña como castigo: se explica por qué existe.
      expect(
        find.textContaining('subirse y bajarse nada más por juntar centavos'),
        findsOneWidget,
      );
    });

    testWidgets('un abordaje que no abona explica por qué', (tester) async {
      // La regla "solo combi" se enseña con un renglón que no pagó, no con un instructivo.
      await pumpAt(tester, const Size(402, 874));
      await openTab(tester, 'Recompensas');

      final skipped = account.rewards.entries.firstWhere((e) => !e.earned);
      expect(find.text(skipped.skippedReason!), findsOneWidget);

      final earned = account.rewards.entries.where((e) => e.earned).length;
      expect(
        find.text('+${formatCents(rewardCentsPerBoarding)}'),
        findsNWidgets(earned),
      );
    });

    testWidgets('dice por qué la app paga por confirmar', (tester) async {
      // Es el argumento que cierra el círculo del proyecto: la confirmación es la señal de
      // demanda que le sirve al municipio. Esconderlo desperdicia la mejor parte del pitch.
      await pumpAt(tester, const Size(402, 874));
      await openTab(tester, 'Recompensas');

      expect(find.text('¿Por qué te pagamos por subirte?'), findsOneWidget);
      expect(
        find.textContaining('mandar más unidades donde faltan'),
        findsOneWidget,
      );
    });

    testWidgets('las cuentas cuadran', (tester) async {
      // Si el saldo, el ritmo y el tope no son coherentes entre sí, la demo se cae en la
      // primera pregunta del jurado.
      expect(account.rewards.todayCents % rewardCentsPerBoarding, 0);
      expect(
        account.rewards.remainingTodayCents,
        rewardDailyCapCents - 3 * rewardCentsPerBoarding,
      );
      expect(account.rewards.boardingsToCap, 10);
      expect(account.rewards.cappedToday, isFalse);
      // Lo de hoy en la lista suma lo que dice el resumen de hoy.
      final today = account.rewards.entries
          .where((e) => e.dayLabel == 'Hoy')
          .fold(0, (sum, e) => sum + e.cents);
      expect(today, account.rewards.todayCents);
    });
  });

  testWidgets('la hoja del plan habla de la pestaña abierta', (tester) async {
    // Un mismo botón para tres funciones: si la hoja vendiera siempre lo mismo, dos de cada
    // tres veces hablaría de algo que la persona no estaba mirando.
    await pumpAt(tester, const Size(402, 874));
    await openTab(tester, 'Mis viajes');

    await tapText(tester, 'Activar MTAPP Plus');
    await tester.pumpAndSettle();

    expect(find.textContaining('El cobro no está conectado'), findsOneWidget);
    final bullets = find.textContaining('guardados para siempre');
    expect(bullets, findsOneWidget);
    expect(
      tester.getRect(bullets).top,
      lessThan(
        tester.getRect(find.textContaining('agenda de rutas de la semana')).top,
      ),
      reason: 'lo de la pestaña abierta va primero',
    );
  });

  testWidgets(
    'el regreso es el circulo de arriba, como en el resto de la app',
    (tester) async {
      var back = 0;
      await pumpAt(tester, const Size(402, 874), onBack: () => back++);

      final button = tester.getRect(find.bySemanticsLabel('Regresar'));
      final title = tester.getRect(find.text('MTAPP Plus').first);
      expect(button.top, lessThan(title.top));
      expect(button.left, lessThan(402 / 2));

      await tester.tap(find.bySemanticsLabel('Regresar'));
      await tester.pump();
      expect(back, 1);
    },
  );
}
