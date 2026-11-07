# BioSport – Monitoreo biométrico en tiempo real (Flutter + ESP32)

App móvil en **azul y blanco** que muestra en tiempo real la **frecuencia cardiaca**, la **temperatura corporal** y el **estado actual del deportista**, recibiendo los datos de un **ESP32 por Bluetooth Low Energy (BLE)**.

## Qué incluye
- Tarjeta de **estado del deportista**: En reposo / Activo / Esfuerzo intenso / Alerta (según % de FC máxima = 220 − edad y temperatura ≥ 38 °C).
- Tarjetas de **FC (bpm)** con corazón animado y **temperatura (°C)**.
- **Gráficas en vivo** (últimos 60 datos) de FC y temperatura.
- Conexión BLE con un botón; reconexión y mensajes de error claros.
- **Modo simulación** (Ajustes) para probar la app sin el ESP32.
- Firmware del ESP32 listo en `firmware/esp32_biosport/`.

## 1. Preparar la app
Requisitos: Flutter 3.27+ y un teléfono físico (el BLE no funciona en emulador).

```bash
cd biosport_app
bash setup.sh      # genera android/ e ios/, agrega permisos Bluetooth y hace pub get
flutter run
```
Para probar solo la interfaz: abre **Ajustes (icono ⚙) → Modo simulación → Conectar**.

> Android: `minSdkVersion` debe ser 21 o mayor (el valor por defecto de Flutter ya lo cumple).

## 2. Armar el hardware
| Sensor | Pin del sensor | ESP32 |
|---|---|---|
| MAX30102 (FC) | VIN / GND / SDA / SCL | 3V3 / GND / GPIO21 / GPIO22 |
| DS18B20 (temperatura) | VCC / GND / DATA | 3V3 / GND / GPIO4 (+ resistencia 4.7 kΩ entre DATA y 3V3) |
| LM35 (alternativa) | VCC / GND / OUT | 5V / GND / GPIO34 (poner `USE_LM35 1` en el sketch) |

## 3. Cargar el firmware
1. Arduino IDE → instalar el paquete **esp32** (Espressif).
2. Instalar librerías: *SparkFun MAX3010x*, *OneWire*, *DallasTemperature*.
3. Abrir `firmware/esp32_biosport/esp32_biosport.ino`, placa **ESP32 Dev Module**, y subir.
4. En el Monitor Serie (115200) verás líneas como `78,36.7`.

## Protocolo BLE
- Nombre: `BioSport-ESP32`
- Servicio: `4fafc201-1fb5-459e-8fcc-c5c9c331914b`
- Característica (READ + NOTIFY): `beb5483e-36e1-4688-b7f5-ea07361b26a8`
- Dato cada 1 s en texto: `"<fc>,<temp>"`. `fc = 0` significa sin dedo en el sensor.

Los UUID están definidos en `lib/services/ble_biometric_source.dart` y en el `.ino`; si cambias uno, cambia el otro.

## Notas importantes
- La temperatura medida en **piel** (muñeca, axila) es menor que la corporal interna. Ajusta `TEMP_OFFSET_C` en el firmware comparando con un termómetro clínico.
- Los estados son una guía deportiva, **no un diagnóstico médico**.
- Pruebas de la lógica de estados: `flutter test`.

## Estructura
```
lib/
  main.dart
  theme/app_theme.dart              paleta azul/blanco
  models/                           lectura y evaluación del deportista
  services/                         BLE (ESP32) y simulador
  screens/dashboard_screen.dart     pantalla principal
  widgets/                          tarjetas y gráficas
firmware/esp32_biosport/            sketch Arduino
setup.sh                            genera plataformas y permisos
```
