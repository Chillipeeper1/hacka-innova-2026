/// Negocios publicitados alrededor del destino, al terminar el viaje.
///
/// **Demostración con datos fijos**, como el resto de `data/`. No hay servidor de anuncios ni
/// inventario que consultar: el catálogo de abajo vive en el teléfono y [adsAround] lo coloca
/// alrededor del punto al que se llegó. El día que exista el endpoint, lo único que cambia es
/// de dónde sale la lista — la pantalla, los pines y la hoja siguen igual.
///
/// Por qué existe: la publicidad es ingreso secundario del modelo de negocio (`documento-base`,
/// §7.2, con tope y sin ser el núcleo del financiamiento), y **el momento de llegar es el único
/// en el que un anuncio le sirve a quien lo ve**: acaba de bajarse ahí, está a pie y todavía no
/// decide a dónde entra. Un banner en el mapa mientras planea su viaje sería ruido; esto es la
/// diferencia entre vender espacio y vender contexto.
///
/// Tres decisiones que no son de forma:
///
/// - **Los negocios son inventados.** Poner el nombre de un negocio real de Morelia en la demo
///   lo anunciaría sin que se haya enterado, y frente al municipio eso se nota. Misma regla que
///   ya sigue el espacio publicitario del inicio (`AdSlotCard` en `widgets/map_chrome.dart`).
/// - **Van marcados como publicidad**, en el pin y en la hoja. Un anuncio que se disfraza de
///   recomendación del sistema es lo que hace que la gente deje de creerle a las dos cosas.
/// - **La selección es determinista**: el mismo destino da siempre los mismos negocios en los
///   mismos lugares. Se enseña en vivo, y unos pines que bailan entre el ensayo y la
///   presentación convierten la demo en una sorpresa.
library;

import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import 'path_geometry.dart';

/// Cuántos negocios se enseñan al llegar.
///
/// Cuatro: con menos no se lee como una red de comercios y con más el mapa se tapa justo
/// encima del destino, que es lo que el pasajero está mirando.
const int adsPerArrival = 4;

/// Lo más cerca que se coloca un negocio del destino.
///
/// No cero: un pin encima del destino esconde el punto al que se acaba de llegar.
const double adsMinMeters = 80;

/// Lo más lejos. Más allá deja de ser "aquí a la vuelta" y el anuncio pierde su gracia.
const double adsMaxMeters = 250;

/// Un negocio que paga por aparecer.
class SponsoredPlace {
  const SponsoredPlace({
    required this.name,
    required this.category,
    required this.promo,
    required this.location,
    required this.meters,
  });

  final String name;

  /// El giro: "Cafetería", "Farmacia". Sin esto el pin es un nombre suelto que no dice si vale
  /// la pena caminar hasta allá.
  final String category;

  /// Lo que ofrece a quien llega con la app. Es el argumento de venta del espacio: el comercio
  /// no paga por aparecer, paga por que entren.
  final String promo;

  final LatLng location;

  /// A cuántos metros del destino quedó.
  final double meters;
}

/// El catálogo de la demostración. Negocios **inventados**; ver la nota de arriba.
const List<({String name, String category, String promo})> demoSponsors = [
  (
    name: 'Café de la Cantera',
    category: 'Cafetería',
    promo: '2x1 en café de olla enseñando tu viaje de hoy',
  ),
  (
    name: 'Panadería La Espiga',
    category: 'Panadería',
    promo: 'Concha gratis con tu compra de \$50',
  ),
  (
    name: 'Taquería El Semáforo',
    category: 'Comida',
    promo: 'Orden de 5 tacos al precio de 4, hasta las 6 p.m.',
  ),
  (
    name: 'Farmacia Providencia',
    category: 'Farmacia',
    promo: '15% en genéricos para usuarios de MTAPP',
  ),
  (
    name: 'Papelería El Punto',
    category: 'Papelería',
    promo: 'Copias a mitad de precio antes del mediodía',
  ),
  (
    name: 'Gimnasio Impulso',
    category: 'Gimnasio',
    promo: 'Semana de prueba sin costo',
  ),
  (
    name: 'Lavandería Burbuja',
    category: 'Lavandería',
    promo: '3 kg gratis en tu primer servicio',
  ),
  (
    name: 'Nevería El Portal',
    category: 'Nieves y helados',
    promo: 'Bola extra presentando tu llegada en la app',
  ),
];

/// Los negocios que se enseñan al llegar a [destination].
///
/// Determinista: la semilla sale de las propias coordenadas, así que el mismo destino devuelve
/// siempre lo mismo —hasta el metro— y destinos distintos devuelven listas distintas. Ver la
/// nota de arriba.
List<SponsoredPlace> adsAround(
  LatLng destination, {
  int count = adsPerArrival,
}) {
  final seed =
      (destination.latitude * 1e5).round() ^
      (destination.longitude * 1e5).round();
  final random = math.Random(seed);

  final catalog = [...demoSponsors]..shuffle(random);
  final chosen = catalog.take(math.min(count, catalog.length)).toList();

  // Los rumbos se reparten en rebanadas iguales con un empujón al azar dentro de la suya: al
  // azar puro los cuatro pines caen del mismo lado más veces de las que uno esperaría, y el
  // mapa se ve desbalanceado sin que haya un motivo.
  final slice = 2 * math.pi / chosen.length;

  return [
    for (final (index, sponsor) in chosen.indexed)
      () {
        final bearing = slice * index + random.nextDouble() * slice;
        final meters =
            adsMinMeters + random.nextDouble() * (adsMaxMeters - adsMinMeters);
        return SponsoredPlace(
          name: sponsor.name,
          category: sponsor.category,
          promo: sponsor.promo,
          location: offsetBy(destination, meters, bearing),
          meters: meters,
        );
      }(),
  ];
}
