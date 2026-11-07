import 'dart:async';

import 'package:flutter/material.dart';

import '../models/athlete_status.dart';
import '../models/biometric_reading.dart';
import '../services/ble_biometric_source.dart';
import '../services/biometric_source.dart';
import '../services/simulated_biometric_source.dart';
import '../theme/app_theme.dart';
import '../widgets/live_chart.dart';
import '../widgets/metric_card.dart';
import '../widgets/status_card.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  static const int _maxPoints = 60;
  static const Duration _staleAfter = Duration(seconds: 5);

  late BiometricSource _source;
  StreamSubscription<BiometricReading>? _readingSub;
  StreamSubscription<ConnectionInfo>? _statusSub;
  Timer? _staleTimer;

  bool _simulate = false;
  int _age = 20;
  ConnectionInfo _connection = const ConnectionInfo(SourceStatus.desconectado);
  final List<BiometricReading> _history = [];
  BiometricReading? _last;

  @override
  void initState() {
    super.initState();
    _attachSource();
    // Si dejan de llegar datos, se marca la conexión como inactiva.
    _staleTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_last != null &&
          _connection.status == SourceStatus.conectado &&
          DateTime.now().difference(_last!.timestamp) > _staleAfter) {
        setState(() => _last = null);
      }
    });
  }

  void _attachSource() {
    _source = _simulate ? SimulatedBiometricSource() : BleBiometricSource();
    _readingSub = _source.readings.listen((r) {
      if (!mounted) return;
      setState(() {
        _last = r;
        _history.add(r);
        if (_history.length > _maxPoints) _history.removeAt(0);
      });
    });
    _statusSub = _source.status.listen((s) {
      if (!mounted) return;
      setState(() {
        _connection = s;
        if (s.status != SourceStatus.conectado) _last = null;
      });
    });
  }

  Future<void> _detachSource() async {
    await _readingSub?.cancel();
    await _statusSub?.cancel();
    await _source.disconnect();
    _source.dispose();
  }

  Future<void> _toggleSimulation(bool value) async {
    await _detachSource();
    setState(() {
      _simulate = value;
      _history.clear();
      _last = null;
      _connection = const ConnectionInfo(SourceStatus.desconectado);
    });
    _attachSource();
  }

  @override
  void dispose() {
    _staleTimer?.cancel();
    _readingSub?.cancel();
    _statusSub?.cancel();
    _source.dispose();
    super.dispose();
  }

  bool get _connected => _connection.status == SourceStatus.conectado;

  AthleteAssessment get _assessment {
    if (!_connected) return AthleteAssessment.sinConexion;
    final r = _last;
    if (r == null) return AthleteAssessment.esperando;
    return assessAthlete(
      heartRate: r.heartRate,
      temperature: r.temperature,
      age: _age,
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = _last;
    final hrText = (r == null || r.heartRate <= 0) ? '--' : '${r.heartRate}';
    final tempText = (r == null || r.temperature <= 0)
        ? '--'
        : r.temperature.toStringAsFixed(1);
    final maxHr = 220 - _age;

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.monitor_heart_outlined),
            SizedBox(width: 10),
            Text('BioSport'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Ajustes',
            icon: const Icon(Icons.tune),
            onPressed: _openSettings,
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            _ConnectionBar(
              info: _connection,
              simulated: _simulate,
              onConnect: _source.connect,
              onDisconnect: _source.disconnect,
            ),
            const SizedBox(height: 14),
            StatusCard(assessment: _assessment),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: MetricCard(
                    title: 'Frecuencia cardiaca',
                    value: hrText,
                    unit: 'bpm',
                    icon: Icons.favorite,
                    trailing: BeatingHeart(heartRate: r?.heartRate ?? 0),
                    footer: 'FC máx. estimada: $maxHr bpm',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: MetricCard(
                    title: 'Temperatura corporal',
                    value: tempText,
                    unit: '°C',
                    icon: Icons.thermostat,
                    footer: 'Rango normal: 36.0 – 37.5 °C',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            LiveChart(
              title: 'Frecuencia cardiaca en tiempo real',
              unit: 'bpm',
              data: _history,
              pick: (e) => e.heartRate.toDouble(),
              minY: 40,
              maxY: 200,
            ),
            const SizedBox(height: 14),
            LiveChart(
              title: 'Temperatura en tiempo real',
              unit: '°C',
              data: _history,
              pick: (e) => e.temperature,
              minY: 35,
              maxY: 39.5,
            ),
            const SizedBox(height: 14),
            const Text(
              'Los estados son una guía deportiva basada en la FC máxima '
              'estimada (220 − edad). No reemplazan una evaluación médica.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMuted, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  void _openSettings() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheet) => Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Ajustes',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeColor: AppColors.blue700,
                  title: const Text('Modo simulación'),
                  subtitle:
                      const Text('Datos de prueba sin necesidad del ESP32'),
                  value: _simulate,
                  onChanged: (v) async {
                    await _toggleSimulation(v);
                    setSheet(() {});
                  },
                ),
                const SizedBox(height: 8),
                Text('Edad del deportista: $_age años'),
                Slider(
                  value: _age.toDouble(),
                  min: 14,
                  max: 50,
                  divisions: 36,
                  label: '$_age',
                  activeColor: AppColors.blue700,
                  onChanged: (v) {
                    setState(() => _age = v.round());
                    setSheet(() {});
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ConnectionBar extends StatelessWidget {
  final ConnectionInfo info;
  final bool simulated;
  final Future<void> Function() onConnect;
  final Future<void> Function() onDisconnect;

  const _ConnectionBar({
    required this.info,
    required this.simulated,
    required this.onConnect,
    required this.onDisconnect,
  });

  @override
  Widget build(BuildContext context) {
    final connected = info.status == SourceStatus.conectado;
    final searching = info.status == SourceStatus.buscando;

    final String text;
    switch (info.status) {
      case SourceStatus.conectado:
        text = simulated ? 'Simulación activa' : 'Conectado a BioSport-ESP32';
      case SourceStatus.buscando:
        text = 'Buscando dispositivo…';
      case SourceStatus.error:
        text = info.message ?? 'Error de conexión';
      case SourceStatus.desconectado:
        text = info.message ?? 'Desconectado';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.blue100),
      ),
      child: Row(
        children: [
          Icon(
            connected ? Icons.bluetooth_connected : Icons.bluetooth,
            color: connected ? AppColors.blue700 : AppColors.textMuted,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppColors.textDark,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
          if (searching)
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            )
          else
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.blue700,
                visualDensity: VisualDensity.compact,
              ),
              onPressed: connected ? onDisconnect : onConnect,
              child: Text(connected ? 'Desconectar' : 'Conectar'),
            ),
        ],
      ),
    );
  }
}
