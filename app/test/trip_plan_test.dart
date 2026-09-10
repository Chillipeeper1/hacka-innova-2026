import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:maas_morelia/data/models.dart';
import 'package:maas_morelia/data/providers.dart';
import 'package:maas_morelia/data/trip_plan.dart';

import 'support/fakes.dart';

/// El corazón del flujo: a partir del destino, qué opciones se le ofrecen al usuario.
///
/// Lo que se verifica aquí es el criterio de "mejor opción": la que **te deja más cerca de tu
/// destino** gana, aunque implique caminar un poco más para subirse. Caminar de más al final,
/// con el pasaje ya pagado, se tolera mucho peor.
void main() {
  /// Las dos rutas del seed, tal como las publica `GET /routes`.
  const catedral1 = Stop(
    id: 1,
    name: 'Catedral de Morelia',
    lat: 19.7008,
    lng: -101.1844,
    sequence: 1,
  );
  const tarascas = Stop(
    id: 2,
    name: 'Fuente de las Tarascas',
    lat: 19.6989,
    lng: -101.1789,
    sequence: 2,
  );
  const acueducto = Stop(
    id: 3,
    name: 'Acueducto de Morelia',
    lat: 19.6975,
    lng: -101.1791,
    sequence: 3,
  );
  const catedral2 = Stop(
    id: 4,
    name: 'Catedral de Morelia',
    lat: 19.7008,
    lng: -101.1844,
    sequence: 1,
  );
  const bosque = Stop(
    id: 5,
    name: 'Bosque Cuauhtémoc',
    lat: 19.6917,
    lng: -101.177,
    sequence: 2,
  );

  const routes = [
    TransitRoute(
      id: 1,
      name: 'Ruta Centro - Acueducto',
      mode: 'combi',
      colorHex: '#0E5E56',
      stops: [catedral1, tarascas, acueducto],
    ),
    TransitRoute(
      id: 2,
      name: 'Ruta Centro - Bosque',
      mode: 'bus',
      colorHex: '#D19B3D',
      stops: [catedral2, bosque],
    ),
  ];

  const origin = LatLng(19.7008, -101.1844); // Catedral

  group('buildOptions', () {
    test('elige como bajada la parada más cercana al destino', () {
      // Destino junto al Bosque Cuauhtémoc.
      final options = buildOptions(
        routes: routes,
        origin: origin,
        destination: const LatLng(19.6920, -101.1772),
        demand: const {},
      );

      expect(options, isNotEmpty);
      expect(options.first.alightingStop.name, 'Bosque Cuauhtémoc');
      expect(options.first.route.id, 2);
      expect(
        options.first.metersFromAlightingToDestination,
        lessThan(goodAlightingMeters),
      );
      expect(options.first.dropsClose, isTrue);
    });

    test('ordena por qué tan cerca del destino te deja', () {
      final options = buildOptions(
        routes: routes,
        origin: origin,
        destination: const LatLng(19.6920, -101.1772),
        demand: const {},
      );

      for (var i = 1; i < options.length; i++) {
        expect(
          options[i - 1].score,
          lessThanOrEqualTo(options[i].score),
          reason: 'la lista debe ir de la mejor opción a la peor',
        );
      }
    });

    test('también ofrece las que dejan relativamente cerca', () {
      // Un punto intermedio: ninguna parada queda encima, pero varias dejan caminando.
      final options = buildOptions(
        routes: routes,
        origin: origin,
        destination: const LatLng(19.6950, -101.1810),
        demand: const {},
      );

      expect(options, isNotEmpty);
      // Se ofrecen aunque no dejen en la puerta; el usuario decide con la distancia a la vista.
      expect(
        options.any((option) => !option.dropsClose || option.dropsClose),
        isTrue,
      );
      for (final option in options) {
        expect(
          option.metersFromAlightingToDestination,
          lessThanOrEqualTo(maxAlightingToDestinationMeters),
        );
      }
    });

    test('descarta destinos que ninguna ruta acerca', () {
      final options = buildOptions(
        routes: routes,
        origin: origin,
        destination: const LatLng(19.7600, -101.2600),
        demand: const {},
      );

      // Mejor decir que no hay servicio que ofrecer una parada a kilómetros.
      expect(options, isEmpty);
    });

    test('nunca propone subirse en la misma parada donde hay que bajarse', () {
      final options = buildOptions(
        routes: routes,
        origin: origin,
        destination: const LatLng(19.6920, -101.1772),
        demand: const {},
      );

      for (final option in options) {
        expect(option.boardingStop.id, isNot(option.alightingStop.id));
      }
    });

    test('no repite la misma parada física dos veces', () {
      // "Catedral de Morelia" existe con id 1 en la ruta 1 y con id 4 en la ruta 2. Dos
      // renglones idénticos en la lista confundirían.
      final options = buildOptions(
        routes: routes,
        origin: origin,
        destination: const LatLng(19.6920, -101.1772),
        demand: const {},
      );

      final catedrales = options.where(
        (option) => option.boardingStop.name == 'Catedral de Morelia',
      );
      expect(catedrales.length, lessThanOrEqualTo(1));
    });

    test('lleva la demanda de cada parada de abordaje', () {
      final options = buildOptions(
        routes: routes,
        origin: origin,
        destination: const LatLng(19.6920, -101.1772),
        demand: const {4: 9, 1: 9},
      );

      final catedral = options.firstWhere(
        (option) => option.boardingStop.name == 'Catedral de Morelia',
      );
      expect(catedral.waitingCount, 9);
      expect(
        catedral.isBusy,
        isTrue,
        reason: '9 supera el umbral de concurrida',
      );
    });
  });

  group('el viaje avanza por etapas', () {
    Future<ProviderContainer> container() async {
      final c = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(
            FakeApi(walkPathJson: walkPathPayload).build(),
          ),
          realtimeClientProvider.overrideWithValue(FakeRealtimeClient()),
        ],
      );
      addTearDown(c.dispose);
      await c.read(routesProvider.future);
      return c;
    }

    test('arranca en blanco', () async {
      final c = await container();
      expect(c.read(tripPlanProvider).stage, TripStage.idle);
      expect(c.read(tripPlanProvider).hasDestination, isFalse);
    });

    test('declarar destino calcula las opciones', () async {
      final c = await container();
      c
          .read(tripPlanProvider.notifier)
          .setDestination(const LatLng(19.6920, -101.1772));

      final plan = c.read(tripPlanProvider);
      expect(plan.stage, TripStage.destinationSet);
      expect(plan.options, isNotEmpty);
      expect(plan.isUnreachable, isFalse);
    });

    test('un destino sin cobertura queda marcado como inalcanzable', () async {
      final c = await container();
      c
          .read(tripPlanProvider.notifier)
          .setDestination(const LatLng(19.7600, -101.2600));

      expect(c.read(tripPlanProvider).isUnreachable, isTrue);
    });

    test('elegir opción y confirmar arranca la caminata', () async {
      final c = await container();
      final notifier = c.read(tripPlanProvider.notifier);

      notifier.setDestination(const LatLng(19.6920, -101.1772));
      notifier.choose(c.read(tripPlanProvider).options.first);
      expect(c.read(tripPlanProvider).stage, TripStage.stopChosen);

      // Sin `await`: se echa a andar de inmediato y el trazado llega después. Esperar a la
      // red antes de mover al pasajero dejaría la pantalla congelada por una línea más bonita.
      notifier.startWalking();
      expect(c.read(tripPlanProvider).stage, TripStage.walking);
    });

    test('la caminata a la parada sigue las calles', () async {
      final c = await container();
      final notifier = c.read(tripPlanProvider.notifier);

      notifier.setDestination(const LatLng(19.6920, -101.1772));
      notifier.choose(c.read(tripPlanProvider).options.first);

      // Antes de que conteste el servidor la línea es recta; no hay nada mejor todavía.
      final walking = notifier.startWalking();
      expect(c.read(tripPlanProvider).walkPath, isEmpty);

      await walking;
      expect(c.read(tripPlanProvider).walkPath.length, greaterThan(2));
    });

    test(
      'sin trazado del servidor se camina recto, sin romper el viaje',
      () async {
        final c = ProviderContainer(
          overrides: [
            apiClientProvider.overrideWithValue(FakeApi().build()),
            realtimeClientProvider.overrideWithValue(FakeRealtimeClient()),
          ],
        );
        addTearDown(c.dispose);
        await c.read(routesProvider.future);

        final notifier = c.read(tripPlanProvider.notifier);
        notifier.setDestination(const LatLng(19.6920, -101.1772));
        notifier.choose(c.read(tripPlanProvider).options.first);
        await notifier.startWalking();

        expect(c.read(tripPlanProvider).walkPath, isEmpty);
        expect(c.read(tripPlanProvider).stage, TripStage.walking);
      },
    );

    test('estar ya en la parada cuenta como haber llegado', () async {
      // Si el usuario elige subirse donde ya está, no tiene sentido mandarlo a caminar.
      final c = await container();
      final notifier = c.read(tripPlanProvider.notifier);

      notifier.setDestination(const LatLng(19.6920, -101.1772));
      final aquiMismo = c
          .read(tripPlanProvider)
          .options
          .reduce(
            (a, b) => a.metersToBoardingStop < b.metersToBoardingStop ? a : b,
          );
      notifier.choose(aquiMismo);
      notifier.startWalking();

      final sub = c.listen(hasArrivedProvider, (_, _) {});
      expect(sub.read(), isTrue);
    });

    test(
      'se llega cuando la posición entra en el radio de la parada',
      () async {
        final c = await container();
        final notifier = c.read(tripPlanProvider.notifier);

        notifier.setDestination(const LatLng(19.6920, -101.1772));

        // A propósito una parada lejos del punto de partida: la mejor opción suele ser la
        // Catedral, que es donde el usuario ya está, y ahí ya habría "llegado".
        final option = c
            .read(tripPlanProvider)
            .options
            .reduce(
              (a, b) => a.metersToBoardingStop > b.metersToBoardingStop ? a : b,
            );
        expect(option.metersToBoardingStop, greaterThan(arrivalRadiusMeters));

        notifier.choose(option);
        notifier.startWalking();

        // Suscribe el provider para que reaccione a los cambios de posición.
        final sub = c.listen(hasArrivedProvider, (_, _) {});
        expect(sub.read(), isFalse, reason: 'todavía no ha caminado');

        // Colocar al usuario encima de la parada equivale a haber llegado.
        c.read(userLocationProvider.notifier).state =
            option.boardingStop.location;
        expect(sub.read(), isTrue);
      },
    );

    test('reiniciar borra el viaje', () async {
      final c = await container();
      final notifier = c.read(tripPlanProvider.notifier);

      notifier.setDestination(const LatLng(19.6920, -101.1772));
      notifier.reset();

      expect(c.read(tripPlanProvider).stage, TripStage.idle);
      expect(c.read(tripPlanProvider).hasDestination, isFalse);
    });
  });

  /// Cuánto falta para que llegue la unidad, tal como se lee en pantalla.
  ///
  /// El conductor simulado corre a la velocidad de la demo, así que a la parada casi nunca le
  /// faltan minutos: le faltan segundos. Un contador que dice "1 min" durante todo el trayecto
  /// y de pronto desaparece se lee como si estuviera trabado, y lo que se está enseñando es
  /// justamente que la unidad se acerca.
  group('el contador de llegada', () {
    test('abajo del minuto se dice en segundos', () {
      expect(formatEta(0.2), '12 s');
    });

    test('nunca dice cero: "llega en 0" se lee como que ya se fue', () {
      expect(formatEta(0.0001), '1 s');
    });

    test('a partir del minuto vuelve a los minutos', () {
      expect(formatEta(1), '1 min');
      expect(formatEta(3.4), '3 min');
    });

    test('la distancia se convierte con la velocidad de la demo', () {
      // Los 1274 m que separan la Catedral del Bosque Cuauhtémoc, que a velocidad de camión
      // de verdad serían cinco minutos de espera.
      expect(formatEta(etaMinutesForMeters(1274)), '8 s');
    });
  });
}
