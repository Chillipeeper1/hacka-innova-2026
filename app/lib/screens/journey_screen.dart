import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../data/journey.dart';
import '../data/journey_trip.dart';
import '../morelia.dart';
import '../theme.dart';
import '../widgets/app_map.dart';
import '../widgets/inputs.dart';
import '../widgets/trip_widgets.dart';

/// El viaje más rápido: varios modos encadenados para llegar antes.
///
/// El itinerario lo arma el servidor (`GET /journeys`), así que esta pantalla no decide nada
/// sobre la ruta — la enseña, la recorre y deja cambiar de alternativa. Es la única del viaje
/// que espera a la red, y por eso es la única con estado de carga.
class JourneyScreen extends ConsumerWidget {
  const JourneyScreen({
    super.key,
    this.onMenu,
    this.onProfile,
    this.onFinished,
    this.onCancel,
  });

  final VoidCallback? onMenu;
  final VoidCallback? onProfile;
  final VoidCallback? onFinished;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trip = ref.watch(journeyTripProvider);

    if (trip.stage == JourneyStage.loading) {
      return const _JourneyMessage(
        title: 'Buscando la ruta más rápida',
        detail: 'Estamos combinando camión, teleférico y caminata.',
        busy: true,
      );
    }

    if (trip.stage == JourneyStage.failed) {
      return _JourneyMessage(
        title: 'No pudimos armar el viaje',
        detail: trip.error ?? 'Inténtalo de nuevo.',
        onBack: onFinished ?? onCancel,
      );
    }

    final journey = trip.journey;
    if (journey == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Viaje más rápido')),
        body: const Center(child: Text('No tienes un viaje en curso.')),
      );
    }

    final arrived = trip.stage == JourneyStage.arrived;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          _JourneyMap(trip: trip, journey: journey),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = math.min(constraints.maxWidth, maxContentWidth);

              return Stack(
                children: [
                  MapTopControls(
                    width: width,
                    onMenu: onMenu,
                    onProfile: onProfile,
                    trailing: MapInfoCard(
                      width: width,
                      asset: _modeAsset(
                        trip.currentLeg?.mode ?? JourneyMode.walk,
                      ),
                      lines: [
                        arrived ? 'Llegaste a:' : 'Vas en:',
                        arrived
                            ? 'tu destino'
                            : (trip.currentLeg?.title ?? journey.label),
                      ],
                    ),
                  ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: _JourneySheet(
                      width: width,
                      maxHeight: constraints.maxHeight,
                      trip: trip,
                      journey: journey,
                      onSelect: (index) =>
                          ref.read(journeyTripProvider.notifier).select(index),
                      onFinished: onFinished,
                      onCancel: onCancel,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Color de cada modo. El mismo criterio que en el resto de la app: azul lo que se camina,
/// verde la bici, y cada servicio con su color.
Color _modeColor(JourneyMode mode) => switch (mode) {
  JourneyMode.walk => AppColors.walkPath,
  JourneyMode.bike => AppColors.green,
  JourneyMode.bus => AppColors.magenta,
  JourneyMode.combi => AppColors.magentaDeep,
  JourneyMode.cableCar => const Color(0xFF7B2FF7),
};

String _modeAsset(JourneyMode mode) => switch (mode) {
  JourneyMode.walk => 'assets/icons/walk.svg',
  JourneyMode.bike => 'assets/icons/bicycle.svg',
  JourneyMode.bus || JourneyMode.combi => 'assets/icons/bus.svg',
  JourneyMode.cableCar => 'assets/icons/cable-car.svg',
};

/// Pantalla de una sola cosa: cargando, o algo salió mal.
class _JourneyMessage extends StatelessWidget {
  const _JourneyMessage({
    required this.title,
    required this.detail,
    this.busy = false,
    this.onBack,
  });

  final String title;
  final String detail;
  final bool busy;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = math.min(constraints.maxWidth, maxContentWidth);
              final s = scaleFor(width);

              return SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: gutterFor(width),
                  vertical: 24 * s,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (busy)
                      const Center(child: CircularProgressIndicator())
                    else
                      Icon(
                        Icons.alt_route,
                        size: 56 * s,
                        color: AppColors.muted,
                      ),
                    SizedBox(height: 20 * s),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: AppFonts.headline,
                        fontFamilyFallback: AppFonts.headlineFallback,
                        fontSize: fluid(
                          width,
                          designSize: 24,
                          min: 19,
                          max: 27,
                        ),
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    ),
                    SizedBox(height: 12 * s),
                    Text(
                      detail,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: fluid(
                          width,
                          designSize: 15,
                          min: 13,
                          max: 17,
                        ),
                        color: AppColors.muted,
                        height: 1.35,
                      ),
                    ),
                    if (onBack != null) ...[
                      SizedBox(height: 24 * s),
                      PrimaryPillButton(
                        label: 'Volver',
                        width: width,
                        designHeight: 44,
                        onPressed: onBack,
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Mapa con cada tramo en el color de su modo.
class _JourneyMap extends StatelessWidget {
  const _JourneyMap({required this.trip, required this.journey});

  final JourneyTrip trip;
  final Journey journey;

  @override
  Widget build(BuildContext context) {
    final rider = trip.position;

    return AppMap(
      initialCenter: rider ?? Morelia.center,
      initialZoom: 14,
      fitTo: journey.points,
      lines: [
        for (final (index, leg) in journey.legs.indexed)
          if (leg.meters > 0)
            MapLine(
              id: 'tramo-$index',
              points: [leg.from.location, leg.to.location],
              color: _modeColor(leg.mode),
              width: leg.mode == JourneyMode.walk ? 6 : 8,
            ),
      ],
      markers: [
        // Los transbordos: donde hay que bajarse de una cosa y subirse a otra, que es lo
        // único del itinerario que se puede hacer mal.
        for (final (index, leg) in journey.legs.indexed)
          if (index > 0 && leg.from.name != null)
            MapMarker(
              id: 'transbordo-$index',
              point: leg.from.location,
              icon: DotMapIcon(
                fill: Colors.white,
                border: _modeColor(leg.mode),
                diameter: 18,
              ),
              semanticLabel: 'Transbordo en ${leg.from.name}',
            ),
        if (trip.destination != null)
          MapMarker(
            id: 'destino',
            point: trip.destination!,
            icon: const SvgMapIcon('assets/icons/flag.svg'),
            semanticLabel: 'Tu destino',
          ),
        if (rider != null)
          MapMarker(
            id: 'pasajero',
            point: rider,
            icon: CircledSvgMapIcon(
              _modeAsset(trip.currentLeg?.mode ?? JourneyMode.walk),
              border: _modeColor(trip.currentLeg?.mode ?? JourneyMode.walk),
            ),
            semanticLabel: 'Vas aquí',
          ),
      ],
    );
  }
}

/// Hoja inferior: el itinerario completo y las alternativas.
class _JourneySheet extends StatelessWidget {
  const _JourneySheet({
    required this.width,
    required this.maxHeight,
    required this.trip,
    required this.journey,
    required this.onSelect,
    this.onFinished,
    this.onCancel,
  });

  final double width;
  final double maxHeight;
  final JourneyTrip trip;
  final Journey journey;
  final ValueChanged<int> onSelect;
  final VoidCallback? onFinished;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final s = scaleFor(width);
    final arrived = trip.stage == JourneyStage.arrived;
    final current = trip.currentLeg;

    return TripSheet(
      width: width,
      maxHeight: maxHeight,
      maxHeightFactor: 0.58,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            arrived ? 'Llegaste' : journey.label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppFonts.headline,
              fontFamilyFallback: AppFonts.headlineFallback,
              fontSize: fluid(width, designSize: 24, min: 19, max: 27),
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
          SizedBox(height: 12 * s),
          InfoPill(
            width: width,
            label: arrived
                ? 'Viaje terminado'
                : 'Llegas en ${trip.roundedRemaining} min',
            background: arrived ? AppColors.green : AppColors.magenta,
          ),
          SizedBox(height: 12 * s),

          for (final leg in journey.legs)
            if (leg.meters > 0 || leg.minutes > 0)
              _LegRow(
                width: width,
                leg: leg,
                active: !arrived && identical(leg, current),
              ),

          if (trip.alternatives.length > 1) ...[
            SizedBox(height: 12 * s),
            _Alternatives(width: width, trip: trip, onSelect: onSelect),
          ],

          SizedBox(height: 16 * s),
          if (arrived)
            PrimaryPillButton(
              label: 'Terminar',
              width: width,
              designHeight: 44,
              onPressed: onFinished,
            )
          else
            Center(
              child: CancelPill(width: width, onTap: onCancel),
            ),
        ],
      ),
    );
  }
}

/// Un renglón del itinerario.
class _LegRow extends StatelessWidget {
  const _LegRow({required this.width, required this.leg, required this.active});

  final double width;
  final JourneyLeg leg;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final s = scaleFor(width);
    final color = _modeColor(leg.mode);

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 5 * s),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SvgPicture.asset(_modeAsset(leg.mode), width: 22 * s, height: 22 * s),
          SizedBox(width: 12 * s),
          Container(
            width: 4 * s,
            height: 26 * s,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          SizedBox(width: 12 * s),
          Expanded(
            child: Text(
              leg.to.name == null
                  ? leg.title
                  : '${leg.title} · hasta ${leg.to.name}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: AppFonts.button,
                fontFamilyFallback: AppFonts.buttonFallback,
                fontSize: fluid(width, designSize: 15, min: 12, max: 17),
                // El tramo en curso va en negro; los demás, apagados. Sin esto hay que leer
                // los cinco renglones para saber en cuál vas.
                color: active ? Colors.black : AppColors.muted,
                fontWeight: active ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ),
          SizedBox(width: 8 * s),
          Text(
            '${leg.minutes.round()} min',
            style: TextStyle(
              fontSize: fluid(width, designSize: 14, min: 12, max: 15),
              color: active ? Colors.black : AppColors.muted,
            ),
          ),
        ],
      ),
    );
  }
}

/// Las otras formas de llegar que devolvió el servidor.
class _Alternatives extends StatelessWidget {
  const _Alternatives({
    required this.width,
    required this.trip,
    required this.onSelect,
  });

  final double width;
  final JourneyTrip trip;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final s = scaleFor(width);

    return Wrap(
      spacing: 8 * s,
      runSpacing: 8 * s,
      children: [
        for (final (index, alternative) in trip.alternatives.indexed)
          _AlternativeChip(
            width: width,
            label: '${alternative.label} · ${alternative.roundedMinutes} min',
            selected: index == trip.selected,
            onTap: () => onSelect(index),
          ),
      ],
    );
  }
}

class _AlternativeChip extends StatelessWidget {
  const _AlternativeChip({
    required this.width,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final double width;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = scaleFor(width);

    return Material(
      color: selected ? AppColors.mint : AppColors.field,
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 14 * s, vertical: 9 * s),
          child: Text(
            label,
            style: TextStyle(
              fontSize: fluid(width, designSize: 13, min: 11, max: 14),
              fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
              color: Colors.black,
            ),
          ),
        ),
      ),
    );
  }
}
