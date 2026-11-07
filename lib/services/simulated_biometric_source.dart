import 'dart:async';
import 'dart:math';

import '../models/biometric_reading.dart';
import 'biometric_source.dart';

/// Genera datos de prueba que recorren reposo → esfuerzo → alerta,
/// para poder probar la interfaz sin el ESP32.
class SimulatedBiometricSource implements BiometricSource {
  final _readings = StreamController<BiometricReading>.broadcast();
  final _status = StreamController<ConnectionInfo>.broadcast();
  final _random = Random();

  Timer? _timer;
  double _phase = 0;
  double _heartRate = 72;
  double _temperature = 36.5;

  @override
  Stream<BiometricReading> get readings => _readings.stream;

  @override
  Stream<ConnectionInfo> get status => _status.stream;

  @override
  Future<void> connect() async {
    _timer?.cancel();
    _status.add(const ConnectionInfo(SourceStatus.conectado));
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    _phase += 0.12;
    final targetHr = 110 + 55 * sin(_phase); // 55..165 bpm
    _heartRate += (targetHr - _heartRate) * 0.35 + (_random.nextDouble() - 0.5) * 3;
    _heartRate = _heartRate.clamp(50.0, 190.0);

    final targetTemp = 36.5 + (_heartRate - 60) / 100 * 1.5;
    _temperature += (targetTemp - _temperature) * 0.05 +
        (_random.nextDouble() - 0.5) * 0.04;

    _readings.add(
      BiometricReading(
        heartRate: _heartRate.round(),
        temperature: _temperature,
        timestamp: DateTime.now(),
      ),
    );
  }

  @override
  Future<void> disconnect() async {
    _timer?.cancel();
    _timer = null;
    if (!_status.isClosed) {
      _status.add(const ConnectionInfo(SourceStatus.desconectado));
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _readings.close();
    _status.close();
  }
}
