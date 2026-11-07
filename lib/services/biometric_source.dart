import '../models/biometric_reading.dart';

enum SourceStatus { desconectado, buscando, conectado, error }

class ConnectionInfo {
  final SourceStatus status;
  final String? message;

  const ConnectionInfo(this.status, [this.message]);
}

/// Origen de datos biométricos: ESP32 por BLE o simulador.
abstract class BiometricSource {
  Stream<BiometricReading> get readings;
  Stream<ConnectionInfo> get status;

  Future<void> connect();
  Future<void> disconnect();
  void dispose();
}
