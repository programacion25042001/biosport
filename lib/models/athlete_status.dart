import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

enum AthleteState {
  sinConexion,
  esperando,
  sinSenal,
  reposo,
  activo,
  intenso,
  alerta,
}

/// Resultado de evaluar las lecturas: estado, mensaje, icono y color.
class AthleteAssessment {
  final AthleteState state;
  final String label;
  final String message;
  final IconData icon;
  final Color color;

  const AthleteAssessment({
    required this.state,
    required this.label,
    required this.message,
    required this.icon,
    required this.color,
  });

  static const AthleteAssessment sinConexion = AthleteAssessment(
    state: AthleteState.sinConexion,
    label: 'Sin conexión',
    message: 'Conecta el ESP32 para ver el estado del deportista.',
    icon: Icons.bluetooth_disabled,
    color: AppColors.textMuted,
  );

  static const AthleteAssessment esperando = AthleteAssessment(
    state: AthleteState.esperando,
    label: 'Esperando datos',
    message: 'Conectado. Recibiendo la primera lectura…',
    icon: Icons.hourglass_empty,
    color: AppColors.blue500,
  );

  static const AthleteAssessment sinSenal = AthleteAssessment(
    state: AthleteState.sinSenal,
    label: 'Sin señal cardiaca',
    message: 'Coloca el dedo (o la banda) sobre el sensor MAX30102.',
    icon: Icons.touch_app,
    color: AppColors.textMuted,
  );
}

/// Evalúa el estado del deportista a partir de FC, temperatura y edad.
///
/// Es una heurística deportiva (zonas de FC sobre la FC máxima estimada
/// 220 − edad), no un diagnóstico médico.
AthleteAssessment assessAthlete({
  required int heartRate,
  required double temperature,
  required int age,
}) {
  if (heartRate <= 0) return AthleteAssessment.sinSenal;

  final maxHr = 220 - age;
  final pct = heartRate / maxHr;
  final pctText = (pct * 100).round();

  if (temperature >= 38.0) {
    return AthleteAssessment(
      state: AthleteState.alerta,
      label: 'Alerta: temperatura alta',
      message:
          'Temperatura de ${temperature.toStringAsFixed(1)} °C. Reduce el esfuerzo, hidrátate y descansa.',
      icon: Icons.warning_amber_rounded,
      color: AppColors.danger,
    );
  }
  if (pct >= 0.90) {
    return AthleteAssessment(
      state: AthleteState.alerta,
      label: 'Alerta: esfuerzo máximo',
      message:
          'FC al $pctText % de la máxima. Riesgo de fatiga: baja la intensidad.',
      icon: Icons.warning_amber_rounded,
      color: AppColors.danger,
    );
  }
  if (pct >= 0.75) {
    return AthleteAssessment(
      state: AthleteState.intenso,
      label: 'Esfuerzo intenso',
      message: 'FC al $pctText % de la máxima. Zona de alto rendimiento.',
      icon: Icons.local_fire_department,
      color: AppColors.warning,
    );
  }
  if (pct >= 0.50) {
    return AthleteAssessment(
      state: AthleteState.activo,
      label: 'Activo',
      message: 'FC al $pctText % de la máxima. Esfuerzo moderado y estable.',
      icon: Icons.directions_run,
      color: AppColors.blue700,
    );
  }
  return AthleteAssessment(
    state: AthleteState.reposo,
    label: 'En reposo',
    message: 'FC al $pctText % de la máxima. Condición estable.',
    icon: Icons.self_improvement,
    color: AppColors.blue500,
  );
}
