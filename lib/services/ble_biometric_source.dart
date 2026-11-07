import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/biometric_reading.dart';
import 'biometric_source.dart';

/// Recibe lecturas del ESP32 por Bluetooth Low Energy (notificaciones).
///
/// Formato del dato (texto UTF-8): "<fc>,<temperatura>"  → p. ej. "78,36.7".
/// Una FC de 0 significa "sin dedo en el sensor".
/// Los UUID deben coincidir con los del firmware (firmware/esp32_biosport.ino).
class BleBiometricSource implements BiometricSource {
  static final Guid serviceUuid = Guid('4fafc201-1fb5-459e-8fcc-c5c9c331914b');
  static final Guid characteristicUuid =
      Guid('beb5483e-36e1-4688-b7f5-ea07361b26a8');

  final _readings = StreamController<BiometricReading>.broadcast();
  final _status = StreamController<ConnectionInfo>.broadcast();

  BluetoothDevice? _device;
  StreamSubscription<List<ScanResult>>? _scanSub;
  StreamSubscription<BluetoothConnectionState>? _connSub;
  StreamSubscription<List<int>>? _valueSub;
  bool _busy = false;

  @override
  Stream<BiometricReading> get readings => _readings.stream;

  @override
  Stream<ConnectionInfo> get status => _status.stream;

  void _emit(SourceStatus status, [String? message]) {
    if (!_status.isClosed) _status.add(ConnectionInfo(status, message));
  }

  @override
  Future<void> connect() async {
    if (_busy) return;
    _busy = true;
    try {
      _emit(SourceStatus.buscando);

      if (!await _requestPermissions()) {
        _emit(SourceStatus.error, 'Faltan permisos de Bluetooth.');
        return;
      }

      final adapter = await FlutterBluePlus.adapterState
          .where((s) => s != BluetoothAdapterState.unknown)
          .first
          .timeout(
            const Duration(seconds: 3),
            onTimeout: () => BluetoothAdapterState.unknown,
          );
      if (adapter != BluetoothAdapterState.on) {
        _emit(SourceStatus.error, 'Activa el Bluetooth del teléfono.');
        return;
      }

      final device = await _scan();
      if (device == null) {
        _emit(SourceStatus.error,
            'No se encontró BioSport-ESP32. ¿Está encendido y cerca?');
        return;
      }

      await device.connect(timeout: const Duration(seconds: 15));
      _device = device;

      await _connSub?.cancel();
      _connSub = device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          _emit(SourceStatus.desconectado, 'Conexión perdida.');
        }
      });

      final services = await device.discoverServices();
      final service = services.firstWhere((s) => s.uuid == serviceUuid);
      final characteristic = service.characteristics
          .firstWhere((c) => c.uuid == characteristicUuid);

      await _valueSub?.cancel();
      _valueSub = characteristic.onValueReceived.listen(_onData);
      await characteristic.setNotifyValue(true);

      _emit(SourceStatus.conectado);
    } catch (e) {
      _emit(SourceStatus.error, 'No se pudo conectar: $e');
    } finally {
      _busy = false;
    }
  }

  Future<bool> _requestPermissions() async {
    if (!Platform.isAndroid) return true; // iOS pregunta al usar Bluetooth.
    final result = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();
    final btOk = (result[Permission.bluetoothScan]?.isGranted ?? false) &&
        (result[Permission.bluetoothConnect]?.isGranted ?? false);
    final locOk = result[Permission.locationWhenInUse]?.isGranted ?? false;
    return btOk || locOk; // Android 12+: permisos BT; Android ≤11: ubicación.
  }

  Future<BluetoothDevice?> _scan() async {
    final found = Completer<BluetoothDevice?>();
    await _scanSub?.cancel();
    _scanSub = FlutterBluePlus.scanResults.listen((results) {
      for (final r in results) {
        if (!found.isCompleted) found.complete(r.device);
      }
    });

    FlutterBluePlus.startScan(
      withServices: [serviceUuid],
      timeout: const Duration(seconds: 10),
    ).catchError((Object _) {});

    final device = await found.future
        .timeout(const Duration(seconds: 12), onTimeout: () => null);

    await FlutterBluePlus.stopScan();
    await _scanSub?.cancel();
    _scanSub = null;
    return device;
  }

  void _onData(List<int> data) {
    final parts = String.fromCharCodes(data).trim().split(',');
    if (parts.length < 2) return;
    final heartRate = int.tryParse(parts[0].trim());
    final temperature = double.tryParse(parts[1].trim());
    if (heartRate == null || temperature == null) return;

    _readings.add(
      BiometricReading(
        heartRate: heartRate,
        temperature: temperature,
        timestamp: DateTime.now(),
      ),
    );
  }

  @override
  Future<void> disconnect() async {
    await _valueSub?.cancel();
    _valueSub = null;
    await _connSub?.cancel();
    _connSub = null;
    try {
      await _device?.disconnect();
    } catch (_) {}
    _device = null;
    _emit(SourceStatus.desconectado);
  }

  @override
  void dispose() {
    _scanSub?.cancel();
    _valueSub?.cancel();
    _connSub?.cancel();
    _device?.disconnect().catchError((Object _) {});
    _readings.close();
    _status.close();
  }
}
