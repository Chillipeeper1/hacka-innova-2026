import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:maas_morelia/data/bike_trip.dart';
import 'package:maas_morelia/data/providers.dart';
import 'package:maas_morelia/data/walk_trip.dart';

import 'support/fakes.dart';

/// El ajuste a calles de los dos modos que se trazan en el cliente.
///
/// Bici y caminata calculaban su recorrido por su cuenta —esquivando zonas marcadas, buscando
/// ciclovías— y en el caso normal eso eran dos puntos: una recta que cruzaba manzanas. Aquí se
/// fija que ahora piden el trazado por calles, y que no romperse sin él sigue siendo posible.
void main() {
  const tarascas = LatLng(19.6989, -101.1789);

  ProviderContainer build({String? walkPath}) {
    final c = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWithValue(
          FakeApi(walkPathJson: walkPath ?? '{"path":[]}').build(),
        ),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  group('caminata', () {
    test('adopta el trazado por calles', () async {
      final c = build(walkPath: walkPathPayload);
      await c.read(walkTripProvider.notifier).start(tarascas);

      final route = c.read(walkTripProvider).route!;
      expect(route.points.length, greaterThan(2));
      c.read(walkTripProvider.notifier).reset();
    });

    test('sin trazado sigue con el suyo, y el viaje sigue en pie', () async {
      final c = build();
      await c.read(walkTripProvider.notifier).start(tarascas);

      final trip = c.read(walkTripProvider);
      expect(trip.stage, WalkStage.walking);
      expect(trip.route, isNotNull);
      c.read(walkTripProvider.notifier).reset();
    });

    test('manda los vértices del rodeo como puntos intermedios', () async {
      // Sin ellos, ajustar a calles deshace el desvío que esquiva la zona marcada.
      final fake = FakeApi(walkPathJson: walkPathPayload);
      final c = ProviderContainer(
        overrides: [apiClientProvider.overrideWithValue(fake.build())],
      );
      addTearDown(c.dispose);

      await c.read(walkTripProvider.notifier).start(tarascas);

      final pedido = fake.requests.lastWhere((r) => r.path == '/walk-path');
      expect(pedido.query['via'], isNotNull);
      expect(pedido.query['via'], contains(','));
      c.read(walkTripProvider.notifier).reset();
    });
  });

  group('bici', () {
    test('ajusta los tramos de calle y respeta los de ciclovía', () async {
      final c = build(walkPath: walkPathPayload);
      await c.read(bikeTripProvider.notifier).start(tarascas);

      final route = c.read(bikeTripProvider).route!;
      final calle = route.segments.where((s) => !s.onLane);
      final ciclovia = route.segments.where((s) => s.onLane);

      expect(calle, isNotEmpty);
      // Los de calle ya no son dos puntos.
      expect(calle.every((s) => s.points.length > 2), isTrue);
      // Los de ciclovía conservan su trazado real capturado: nadie les pidió calles de coche.
      expect(ciclovia.every((s) => s.points.length >= 2), isTrue);
      c.read(bikeTripProvider.notifier).reset();
    });

    test('los metros se recalculan sobre el trazado nuevo', () async {
      // Si no, el ciclista llega al destino con línea todavía por recorrer.
      final c = build(walkPath: walkPathPayload);
      await c.read(bikeTripProvider.notifier).start(tarascas);

      final route = c.read(bikeTripProvider).route!;
      final suma = route.segments.fold<double>(0, (a, s) => a + s.meters);

      expect(route.totalMeters, closeTo(suma, 0.001));
      c.read(bikeTripProvider.notifier).reset();
    });

    test('sin trazado sigue con el suyo', () async {
      final c = build();
      await c.read(bikeTripProvider.notifier).start(tarascas);

      expect(c.read(bikeTripProvider).stage, BikeStage.riding);
      expect(c.read(bikeTripProvider).route, isNotNull);
      c.read(bikeTripProvider.notifier).reset();
    });
  });
}
