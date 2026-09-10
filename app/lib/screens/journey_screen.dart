import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:latlong2/latlong.dart';

import '../data/journey.dart';
import '../data/models.dart';
import '../data/providers.dart';
import '../data/journey_trip.dart';
import '../data/nearby_ads.dart';
import '../morelia.dart';
import '../theme.dart';
import '../widgets/app_map.dart';
import '../widgets/inputs.dart';
import '../widgets/panic_button.dart';
import '../widgets/sponsored_places.dart';
import '../widgets/trip_widgets.dart';

/// El viaje personalizado: el usuario elige los medios y el servidor arma el mejor recorrido
/// con esos.
///
/// El itinerario lo arma el servidor (`GET /journeys`), así que esta pantalla no decide nada
/// sobre la ruta — la enseña, la recorre, y deja cambiar los medios para volver a pedirla. Es
/// la única del viaje que espera a la red, y por eso la única con estado de carga.
///
/// Llega en dos tiempos: primero la propuesta quieta —el trazado en el mapa y el itinerario en
/// la hoja, con los chips de medios y las alternativas— y solo al tocar "Iniciar viaje" el
/// pasajero se pone en marcha. Antes arrancaba sola al recibir la respuesta, con lo que el
/// viaje ya iba corriendo mientras el usuario todavía estaba decidiendo con qué quería ir.
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
        title: 'Armando tu viaje',
        detail:
            'Estamos buscando la mejor combinación para llegar a tu destino.',
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

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          _JourneyMap(
            trip: trip,
            journey: journey,
            // Las paradas intermedias vienen de `/routes`: son las que la unidad sirve de
            // verdad entre subida y bajada, y sin ellas el trazado seria una recta que cruza
            // por donde el camión no pasa.
            routes: ref.watch(routesProvider).value ?? const [],
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = math.min(constraints.maxWidth, maxContentWidth);

              return Stack(
                children: [
                  MapTopControls(
                    width: width,
                    onMenu: onMenu,
                    onProfile: onProfile,
                    // Solo con el viaje en marcha: mientras se elige el itinerario todavía no
                    // hay viaje del que avisar, y el botón estorbaría a la elección.
                    panic: trip.stage == JourneyStage.traveling
                        ? PanicButton(width: width, trip: _panicTrip(trip))
                        : null,
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
                      onToggleMode: (mode) => ref
                          .read(journeyTripProvider.notifier)
                          .toggleMode(mode),
                      onStart: () =>
                          ref.read(journeyTripProvider.notifier).begin(),
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

/// En qué va el pasajero, para la alerta de pánico.
///
/// Es el único viaje con transbordos, así que lo que ubica no es el itinerario completo sino
/// **el tramo en curso**: la unidad en la que va ahora es la que habría que buscar, y decir
/// "iba de la Catedral al Bosque" mandaría a rastrear un viaje que ya cambió de vehículo.
String _panicTrip(JourneyTrip trip) {
  final leg = trip.currentLeg;
  if (leg == null) return 'En un viaje con transbordos, rumbo a su destino';

  final route = leg.routeName;
  final destination = leg.to.name;
  if (route != null) {
    return destination == null
        ? 'A bordo de $route'
        : 'A bordo de $route, hacia $destination';
  }
  return destination == null
      ? '${leg.mode.label}, rumbo a su destino'
      : '${leg.mode.label}, hacia $destination';
}

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
  const _JourneyMap({
    required this.trip,
    required this.journey,
    required this.routes,
  });

  final JourneyTrip trip;
  final Journey journey;
  final List<TransitRoute> routes;

  /// Los puntos por los que pasa un tramo.
  ///
  /// Lo normal es el trazado por calles que ya trae el servidor (`geometry`), que además pasa
  /// por las paradas intermedias de la ruta.
  ///
  /// Lo de abajo es el respaldo para cuando no viene —OSRM no contestó, o es el teleférico,
  /// que va por el aire—: seguir las paradas que la ruta sirve entre subida y bajada. Entre
  /// parada y parada queda recta, pero al menos la línea pasa por donde la unidad para.
  List<LatLng> _legPoints(JourneyLeg leg) {
    if (leg.geometry.isNotEmpty) return leg.geometry;

    final directo = [leg.from.location, leg.to.location];

    final routeId = leg.routeId;
    final fromId = leg.from.stopId;
    final toId = leg.to.stopId;
    if (routeId == null || fromId == null || toId == null) return directo;

    final route = routes.where((r) => r.id == routeId).firstOrNull;
    if (route == null) return directo;

    final desde = route.stops.indexWhere((stop) => stop.id == fromId);
    final hasta = route.stops.indexWhere((stop) => stop.id == toId);
    if (desde < 0 || hasta < 0) return directo;

    final paso = desde <= hasta ? 1 : -1;
    return [
      for (var i = desde; i != hasta + paso; i += paso) route.stops[i].location,
    ];
  }

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
              points: _legPoints(leg),
              color: journeyModeColor(leg.mode),
              width: leg.mode == JourneyMode.walk ? 6 : 8,
            ),
      ],
      markers: [
        // Al llegar, y solo al llegar: mientras el viaje sigue el mapa es para llegar.
        if (trip.stage == JourneyStage.arrived && trip.destination != null)
          ...sponsoredMarkers(context, adsAround(trip.destination!)),
        // Los transbordos: donde hay que bajarse de una cosa y subirse a otra, que es lo
        // único del itinerario que se puede hacer mal.
        for (final (index, leg) in journey.legs.indexed)
          if (index > 0 && leg.from.name != null)
            MapMarker(
              id: 'transbordo-$index',
              point: leg.from.location,
              icon: DotMapIcon(
                fill: Colors.white,
                border: journeyModeColor(leg.mode),
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
              journeyModeAsset(trip.currentLeg?.mode ?? JourneyMode.walk),
              border: journeyModeColor(
                trip.currentLeg?.mode ?? JourneyMode.walk,
              ),
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
    required this.onToggleMode,
    required this.onStart,
    this.onFinished,
    this.onCancel,
  });

  final double width;
  final double maxHeight;
  final JourneyTrip trip;
  final Journey journey;
  final ValueChanged<int> onSelect;
  final ValueChanged<JourneyMode> onToggleMode;
  final VoidCallback onStart;
  final VoidCallback? onFinished;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final s = scaleFor(width);
    final arrived = trip.stage == JourneyStage.arrived;
    final planned = trip.stage == JourneyStage.planned;
    final current = trip.currentLeg;

    // Los que de verdad se pintan abajo: los de duración o distancia cero no son un paso que
    // el pasajero tenga que dar, y contarlos infla el resumen.
    final legs = [
      for (final leg in journey.legs)
        if (leg.meters > 0 || leg.minutes > 0) leg,
    ];

    return TripSheet(
      width: width,
      maxHeight: maxHeight,
      maxHeightFactor: 0.66,
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
            // Propuesto todavía no es "llegas en": nada está corriendo. Se resume el plan —
            // cuánto dura y en cuántos pasos— y el reloj empieza al arrancar.
            label: switch (trip.stage) {
              JourneyStage.arrived => 'Viaje terminado',
              JourneyStage.planned =>
                '${journey.roundedMinutes} min · '
                    '${legs.length} ${legs.length == 1 ? 'tramo' : 'tramos'}',
              _ => 'Llegas en ${trip.roundedRemaining} min',
            },
            background: arrived ? AppColors.green : AppColors.magenta,
          ),
          SizedBox(height: 14 * s),
          // El final del último tramo es el destino del viaje entero. Los tramos de abajo
          // dicen cómo se llega; esto dice a dónde, que es lo que la tarjeta flotante decía
          // a medias —nombraba el tramo en curso, no el destino—.
          if (legs.lastOrNull?.to case final destination?)
            Padding(
              padding: EdgeInsets.only(bottom: 14 * s),
              child: destination.name == null
                  ? TripDestinationLine.at(
                      width: width,
                      label: arrived ? 'Llegaste a' : 'Vas hacia',
                      point: destination.location,
                    )
                  : TripDestinationLine.named(
                      width: width,
                      label: arrived ? 'Llegaste a' : 'Vas hacia',
                      name: destination.name!,
                      asset: 'assets/icons/pin-dark.svg',
                    ),
            ),
          if (journey.beyondNetwork) ...[
            _OutOfReachNotice(width: width, journey: journey),
            SizedBox(height: 14 * s),
          ],
          _ModePicker(
            width: width,
            selected: trip.modes,
            onToggle: onToggleMode,
          ),
          SizedBox(height: 12 * s),

          for (final leg in legs)
            _LegRow(
              width: width,
              leg: leg,
              // Quieto no hay tramo "en curso": resaltar el primero sugiere que ya va en él.
              active: !arrived && !planned && identical(leg, current),
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
          else if (planned) ...[
            PrimaryPillButton(
              label: 'Iniciar viaje',
              width: width,
              designHeight: 44,
              onPressed: onStart,
            ),
            SizedBox(height: 10 * s),
            Center(
              child: CancelPill(width: width, onTap: onCancel),
            ),
          ] else
            Center(
              child: CancelPill(width: width, onTap: onCancel),
            ),
        ],
      ),
    );
  }
}

/// Aviso de que el destino queda fuera de lo que la red alcanza.
///
/// El motor siempre devuelve un viaje —el peor caso es caminar todo el trayecto— y sin decir
/// nada eso se leía como un itinerario normal: "5 min en bici" seguido de dos horas a pie. El
/// viaje se sigue enseñando, porque el punto elegido es válido y los números son reales, pero
/// encabezado por lo que de verdad está pasando: ninguna ruta del catálogo se acerca.
class _OutOfReachNotice extends StatelessWidget {
  const _OutOfReachNotice({required this.width, required this.journey});

  final double width;
  final Journey journey;

  String get _walk {
    final km = journey.longestWalkMeters / 1000;
    return km >= 10 ? '${km.round()} km' : '${km.toStringAsFixed(1)} km';
  }

  @override
  Widget build(BuildContext context) {
    final s = scaleFor(width);

    return Semantics(
      container: true,
      liveRegion: true,
      label: 'Ninguna ruta llega hasta tu destino: te tocarian $_walk a pie',
      excludeSemantics: true,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.crowdBusy.withValues(alpha: 0.22),
          borderRadius: BorderRadius.circular(AppRadius.floatingCard),
        ),
        padding: EdgeInsets.symmetric(horizontal: 16 * s, vertical: 12 * s),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.directions_walk, size: 22 * s, color: Colors.black),
            SizedBox(width: 12 * s),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ninguna ruta llega hasta allá',
                    style: TextStyle(
                      fontFamily: AppFonts.button,
                      fontFamilyFallback: AppFonts.buttonFallback,
                      fontSize: fluid(width, designSize: 17, min: 14, max: 18),
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                  SizedBox(height: 3 * s),
                  Text(
                    'El viaje de abajo te deja $_walk a pie de un tirón. '
                    'Prueba un destino más cerca de una ruta.',
                    style: TextStyle(
                      fontSize: fluid(width, designSize: 14, min: 12, max: 15),
                      height: 1.25,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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
    final color = journeyModeColor(leg.mode);

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 5 * s),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SvgPicture.asset(
            journeyModeAsset(leg.mode),
            width: 22 * s,
            height: 22 * s,
          ),
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

/// Con qué medios acepta ir el usuario.
///
/// La pregunta ya se hizo un paso antes, en `TravelModesScreen`: esto es la corrección, para
/// quien ve el itinerario y decide que hoy sí toma el camión. Se enseña arriba del desglose
/// porque cambiarla cambia el itinerario entero, no solo lo reordena — y por eso devuelve el
/// viaje a la propuesta en vez de seguir corriendo sobre uno distinto.
class _ModePicker extends StatelessWidget {
  const _ModePicker({
    required this.width,
    required this.selected,
    required this.onToggle,
  });

  final double width;
  final Set<JourneyMode> selected;
  final ValueChanged<JourneyMode> onToggle;

  @override
  Widget build(BuildContext context) {
    final s = scaleFor(width);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Medios que aceptas',
          style: TextStyle(
            fontSize: fluid(width, designSize: 13, min: 11, max: 14),
            color: AppColors.muted,
          ),
        ),
        SizedBox(height: 8 * s),
        Wrap(
          spacing: 8 * s,
          runSpacing: 8 * s,
          children: [
            for (final mode in JourneyMode.selectable)
              _ModeChip(
                width: width,
                mode: mode,
                on: selected.contains(mode),
                onTap: () => onToggle(mode),
              ),
          ],
        ),
      ],
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.width,
    required this.mode,
    required this.on,
    required this.onTap,
  });

  final double width;
  final JourneyMode mode;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = scaleFor(width);
    final color = journeyModeColor(mode);

    return ConstrainedBox(
      // Dentro de un Wrap el ancho es libre, así que sin tope el chip crece hasta desbordar
      // cuando el sistema pide tipografía grande. Con tope, el texto se acomoda en dos líneas.
      constraints: BoxConstraints(maxWidth: width),
      child: Semantics(
        container: true,
        selected: on,
        button: true,
        label: '${mode.label}, ${on ? 'incluido' : 'excluido'}',
        child: Material(
          color: on ? color.withValues(alpha: 0.14) : AppColors.field,
          shape: StadiumBorder(
            side: BorderSide(
              color: on ? color : AppColors.surfaceGrey,
              width: on ? 2 : 1,
            ),
          ),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: onTap,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 14 * s,
                vertical: 9 * s,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SvgPicture.asset(
                    journeyModeAsset(mode),
                    width: 18 * s,
                    height: 18 * s,
                  ),
                  SizedBox(width: 8 * s),
                  Flexible(
                    child: Text(
                      mode.label,
                      maxLines: 2,
                      style: TextStyle(
                        fontSize: fluid(
                          width,
                          designSize: 13,
                          min: 11,
                          max: 14,
                        ),
                        fontWeight: on ? FontWeight.w700 : FontWeight.w400,
                        color: on ? Colors.black : AppColors.muted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
