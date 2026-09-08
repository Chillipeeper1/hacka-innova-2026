import 'dart:async';

import 'package:socket_io_client/socket_io_client.dart' as io;

import 'models.dart';

/// Canal en vivo con `server/`, sobre socket.io.
///
/// Solo escucha. Los dos eventos que el servidor emite están en `server/README.md`:
/// `vehicle:position` cada vez que el conductor avanza, y `demand:update` cada vez que cambia
/// una confirmación de abordaje. El evento de salida `driver:position` lo emite el conductor
/// simulado, que en este mockup es un script aparte.
class RealtimeClient {
  RealtimeClient({required this.baseUrl});

  static const String defaultBaseUrl = String.fromEnvironment(
    'REALTIME_URL',
    defaultValue: 'http://localhost:3001',
  );

  final String baseUrl;

  io.Socket? _socket;

  final _vehicles = StreamController<VehiclePosition>.broadcast();
  final _demand = StreamController<DemandCount>.broadcast();
  final _connected = StreamController<bool>.broadcast();

  Stream<VehiclePosition> get vehiclePositions => _vehicles.stream;
  Stream<DemandCount> get demandUpdates => _demand.stream;

  /// Para poder avisar en pantalla cuando el backend no está levantado, en vez de dejar el
  /// mapa vacío sin explicación.
  Stream<bool> get connectionState => _connected.stream;

  bool get isConnected => _socket?.connected ?? false;

  void connect() {
    if (_socket != null) return;

    final socket = io.io(
      baseUrl,
      io.OptionBuilder()
          // Directo a websocket: el sondeo largo previo agrega latencia y en web dispara
          // peticiones extra que no hacen falta.
          .setTransports(['websocket'])
          .enableReconnection()
          .build(),
    );

    socket.onConnect((_) => _emitConnection(true));
    socket.onDisconnect((_) => _emitConnection(false));
    socket.onConnectError((_) => _emitConnection(false));

    socket.on('vehicle:position', (data) {
      final parsed = _asMap(data);
      if (parsed == null) return;
      _addIfOpen(_vehicles, VehiclePosition.fromJson(parsed));
    });

    socket.on('demand:update', (data) {
      final parsed = _asMap(data);
      if (parsed == null) return;
      _addIfOpen(_demand, DemandCount.fromJson(parsed));
    });

    _socket = socket;
  }

  /// socket.io entrega `dynamic`; si el servidor cambiara la forma del evento, esto evita
  /// tumbar la app con un error de conversión.
  Map<String, dynamic>? _asMap(dynamic data) =>
      data is Map ? Map<String, dynamic>.from(data) : null;

  void _addIfOpen<T>(StreamController<T> controller, T value) {
    if (!controller.isClosed) controller.add(value);
  }

  void _emitConnection(bool value) => _addIfOpen(_connected, value);

  Future<void> dispose() async {
    _socket?.dispose();
    _socket = null;
    await _vehicles.close();
    await _demand.close();
    await _connected.close();
  }
}
