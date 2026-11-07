#!/usr/bin/env bash
# Genera las carpetas android/ e ios/ y añade los permisos Bluetooth necesarios.
# Uso:  cd biosport_app && bash setup.sh
set -euo pipefail

command -v flutter >/dev/null || { echo "Flutter no está instalado o no está en el PATH."; exit 1; }

flutter create --org pe.edu.uandina --project-name biosport_app --platforms android,ios .
rm -f test/widget_test.dart   # plantilla por defecto; usamos test/athlete_status_test.dart

python3 - <<'PY'
import re, pathlib

# ---- Android ----
p = pathlib.Path("android/app/src/main/AndroidManifest.xml")
if p.exists():
    s = p.read_text()
    if "BLUETOOTH_SCAN" not in s:
        perms = '''    <uses-feature android:name="android.hardware.bluetooth_le" android:required="true"/>
    <uses-permission android:name="android.permission.BLUETOOTH" android:maxSdkVersion="30"/>
    <uses-permission android:name="android.permission.BLUETOOTH_ADMIN" android:maxSdkVersion="30"/>
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" android:maxSdkVersion="30"/>
    <uses-permission android:name="android.permission.BLUETOOTH_SCAN" android:usesPermissionFlags="neverForLocation"/>
    <uses-permission android:name="android.permission.BLUETOOTH_CONNECT"/>
'''
        s = s.replace("<application", perms + "    <application", 1)
        p.write_text(s)
        print("AndroidManifest.xml actualizado")

# ---- iOS ----
p = pathlib.Path("ios/Runner/Info.plist")
if p.exists():
    s = p.read_text()
    if "NSBluetoothAlwaysUsageDescription" not in s:
        keys = '''	<key>NSBluetoothAlwaysUsageDescription</key>
	<string>BioSport usa Bluetooth para recibir los datos del sensor ESP32.</string>
'''
        s = s.replace("</dict>\n</plist>", keys + "</dict>\n</plist>")
        p.write_text(s)
        print("Info.plist actualizado")
PY

flutter pub get
echo "Listo. Ejecuta:  flutter run"
