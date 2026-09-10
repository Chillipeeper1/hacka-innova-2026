import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:maas_morelia/data/journey_trip.dart';
import 'package:maas_morelia/data/providers.dart';
import 'package:maas_morelia/screens/journey_screen.dart';
import 'package:maas_morelia/theme.dart';
import 'package:maas_morelia/widgets/app_map.dart';

import 'support/fakes.dart';

/// Lo último que se puede verificar de este lado: qué puntos le llegan al mapa.
///
/// Entre el JSON del servidor y la línea que ve el usuario solo hay dos cosas: el modelo, que
/// ya se prueba en `journey_test.dart`, y este paso. Si aquí llegan los puntos del trazado y
/// aun así se dibuja recto, el problema está en el motor de mapas, no en la app.
void main() {
  testWidgets('el mapa del viaje recibe el trazado por calles', (tester) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final container = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWithValue(
          FakeApi(journeysJson: journeysWithGeometryPayload).build(),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container
        .read(journeyTripProvider.notifier)
        .start(const LatLng(19.6975, -101.1791));

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(theme: buildAppTheme(), home: const JourneyScreen()),
      ),
    );
    await tester.pump();

    final mapa = tester.widget<AppMap>(find.byType(AppMap));
    final trazados = mapa.lines.where((l) => l.points.length > 2).toList();

    expect(
      trazados,
      isNotEmpty,
      reason:
          'ninguna línea del mapa tiene más de dos puntos: se están dibujando '
          'rectas aunque el servidor mandó geometría. Líneas recibidas: '
          '${mapa.lines.map((l) => '${l.id}=${l.points.length}pts').join(', ')}',
    );

    container.read(journeyTripProvider.notifier).reset();
  });
}
