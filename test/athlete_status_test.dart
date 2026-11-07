import 'package:biosport_app/models/athlete_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('assessAthlete (edad 20 → FC máx 200)', () {
    AthleteState state(int hr, double temp) =>
        assessAthlete(heartRate: hr, temperature: temp, age: 20).state;

    test('FC 0 = sin señal', () {
      expect(state(0, 36.5), AthleteState.sinSenal);
    });
    test('FC baja = reposo', () {
      expect(state(70, 36.5), AthleteState.reposo);
    });
    test('FC moderada = activo', () {
      expect(state(120, 36.8), AthleteState.activo);
    });
    test('FC alta = intenso', () {
      expect(state(160, 37.2), AthleteState.intenso);
    });
    test('FC >= 90 % = alerta', () {
      expect(state(185, 37.2), AthleteState.alerta);
    });
    test('temperatura >= 38 = alerta aunque la FC sea baja', () {
      expect(state(70, 38.2), AthleteState.alerta);
    });
  });
}
