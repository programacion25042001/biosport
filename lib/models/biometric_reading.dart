/// Una lectura de los sensores: frecuencia cardiaca (bpm) y temperatura (°C).
class BiometricReading {
  final int heartRate;
  final double temperature;
  final DateTime timestamp;

  const BiometricReading({
    required this.heartRate,
    required this.temperature,
    required this.timestamp,
  });
}
