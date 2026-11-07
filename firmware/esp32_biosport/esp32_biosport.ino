/*
 * BioSport – Firmware ESP32
 * Lee frecuencia cardiaca (MAX30102) y temperatura corporal (DS18B20 o LM35)
 * y los envía por BLE a la app Flutter cada 1 segundo.
 *
 * Formato enviado (texto UTF-8):  "<fc>,<temperatura>"   p. ej. "78,36.7"
 *   - fc = 0  → no hay dedo/piel sobre el MAX30102
 *   - temperatura = 0.0 → sensor de temperatura no disponible
 *
 * Librerías (Gestor de librerías de Arduino IDE):
 *   - SparkFun MAX3010x Pulse and Proximity Sensor Library
 *   - OneWire
 *   - DallasTemperature
 * Placa: "ESP32 Dev Module" (paquete esp32 de Espressif).
 *
 * Conexiones:
 *   MAX30102  VIN→3V3   GND→GND   SDA→GPIO21   SCL→GPIO22
 *   DS18B20   VCC→3V3   GND→GND   DATA→GPIO4  (+ resistencia 4.7 kΩ entre DATA y 3V3)
 *   LM35      VCC→5V    GND→GND   OUT→GPIO34  (solo si USE_LM35 = 1)
 */

#include <Wire.h>
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>
#include "MAX30105.h"
#include "heartRate.h"
#include <OneWire.h>
#include <DallasTemperature.h>

// ---------- Configuración ----------
#define USE_LM35        0      // 0 = DS18B20, 1 = LM35
#define ONE_WIRE_PIN    4
#define LM35_PIN        34
#define TEMP_OFFSET_C   0.0f   // Ajuste de calibración (el sensor en piel marca menos que la temp. interna)
#define FINGER_IR_MIN   50000  // Por debajo de este valor IR se considera "sin dedo"
#define SEND_PERIOD_MS  1000

// Deben coincidir con lib/services/ble_biometric_source.dart
#define DEVICE_NAME  "BioSport-ESP32"
#define SERVICE_UUID "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
#define CHAR_UUID    "beb5483e-36e1-4688-b7f5-ea07361b26a8"

// ---------- Estado ----------
MAX30105 particleSensor;
OneWire oneWire(ONE_WIRE_PIN);
DallasTemperature ds18b20(&oneWire);

BLEServer *server = nullptr;
BLECharacteristic *characteristic = nullptr;
volatile bool clientConnected = false;
bool wasConnected = false;

const byte RATE_SIZE = 4;
byte rates[RATE_SIZE];
byte rateSpot = 0;
long lastBeat = 0;
int beatsPerMinute = 0;
int beatAvg = 0;

float lastTemperature = 0.0f;
unsigned long lastSend = 0;
unsigned long lastTempRead = 0;

class ServerCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer *) override { clientConnected = true; }
  void onDisconnect(BLEServer *) override { clientConnected = false; }
};

void resetHeartRate() {
  for (byte i = 0; i < RATE_SIZE; i++) rates[i] = 0;
  rateSpot = 0;
  lastBeat = 0;
  beatAvg = 0;
}

void updateHeartRate() {
  long ir = particleSensor.getIR();

  if (ir < FINGER_IR_MIN) {  // sin dedo
    resetHeartRate();
    return;
  }

  if (checkForBeat(ir)) {
    long now = millis();
    long delta = now - lastBeat;
    lastBeat = now;
    if (delta <= 0) return;

    beatsPerMinute = 60 / (delta / 1000.0);
    if (beatsPerMinute > 20 && beatsPerMinute < 255) {
      rates[rateSpot++] = (byte)beatsPerMinute;
      rateSpot %= RATE_SIZE;

      int sum = 0, count = 0;
      for (byte i = 0; i < RATE_SIZE; i++) {
        if (rates[i] > 0) { sum += rates[i]; count++; }
      }
      beatAvg = count ? sum / count : 0;
    }
  }
}

void updateTemperature() {
#if USE_LM35
  // Promedio de varias muestras: el ADC del ESP32 es ruidoso. LM35 = 10 mV/°C.
  uint32_t mv = 0;
  for (int i = 0; i < 16; i++) mv += analogReadMilliVolts(LM35_PIN);
  float t = (mv / 16.0f) / 10.0f + TEMP_OFFSET_C;
  if (t > 20.0f && t < 45.0f) lastTemperature = t;
#else
  ds18b20.requestTemperatures();
  float t = ds18b20.getTempCByIndex(0);
  if (t != DEVICE_DISCONNECTED_C && t > 20.0f && t < 45.0f) {
    lastTemperature = t + TEMP_OFFSET_C;
  }
#endif
}

void setupBle() {
  BLEDevice::init(DEVICE_NAME);
  server = BLEDevice::createServer();
  server->setCallbacks(new ServerCallbacks());

  BLEService *service = server->createService(SERVICE_UUID);
  characteristic = service->createCharacteristic(
      CHAR_UUID, BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_NOTIFY);
  characteristic->addDescriptor(new BLE2902());
  service->start();

  BLEAdvertising *adv = BLEDevice::getAdvertising();
  adv->addServiceUUID(SERVICE_UUID);  // la app filtra por este UUID
  adv->setScanResponse(true);
  BLEDevice::startAdvertising();
}

void setup() {
  Serial.begin(115200);
  Wire.begin(21, 22);

  if (!particleSensor.begin(Wire, I2C_SPEED_FAST)) {
    Serial.println("MAX30102 no encontrado. Revisa SDA/SCL y alimentación.");
  } else {
    particleSensor.setup(0x1F, 4, 2, 400, 411, 4096);  // brillo, promedio, modo rojo+IR, etc.
    particleSensor.setPulseAmplitudeRed(0x0A);
    particleSensor.setPulseAmplitudeGreen(0);
  }

#if !USE_LM35
  ds18b20.begin();
  ds18b20.setWaitForConversion(true);
#endif

  setupBle();
  Serial.println("BioSport listo. Anunciando como " DEVICE_NAME);
}

void loop() {
  updateHeartRate();  // debe ejecutarse lo más seguido posible

  unsigned long now = millis();

  if (now - lastTempRead >= 2000) {  // la conversión del DS18B20 tarda ~750 ms
    lastTempRead = now;
    updateTemperature();
  }

  if (now - lastSend >= SEND_PERIOD_MS) {
    lastSend = now;
    char payload[24];
    snprintf(payload, sizeof(payload), "%d,%.1f", beatAvg, lastTemperature);
    Serial.println(payload);

    if (clientConnected) {
      characteristic->setValue((uint8_t *)payload, strlen(payload));
      characteristic->notify();
    }
  }

  // Reanudar anuncio BLE si el teléfono se desconecta
  if (!clientConnected && wasConnected) {
    delay(300);
    BLEDevice::startAdvertising();
  }
  wasConnected = clientConnected;
}
