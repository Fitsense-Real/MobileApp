#!/bin/bash
# Matriz de protecciones release/AAB de Google Play (android/app/build.gradle.kts).
cd /home/user/MobileApp
export PATH=/tmp/claude-0/-home-user/7a9522d3-2797-5dcc-8e36-7b70b17e272d/scratchpad/sdk350/flutter/bin:$PATH
OK='--dart-define=ACCOUNT_DELETION_ENABLED=true --dart-define=ACCOUNT_DELETION_WEB_URL=https://kora.example.test/eliminar --dart-define=PRIVACY_POLICY_URL=https://kora.example.test/privacidad'
run() { local name="$1"; shift; echo "### $name"; "$@" > /tmp/rel.out 2>&1; local c=$?; grep -E "^ - |bloqueada|Built " /tmp/rel.out | sed 's/^/   /'; echo "salida $c"; }
run "APK release sin API_BASE_URL" flutter build apk --release
run "APK release con http://localhost:8080/api/v1" flutter build apk --release --dart-define=API_BASE_URL=http://localhost:8080/api/v1
run "APK release con https://10.0.2.2:8080/api/v1 (emulador)" flutter build apk --release --dart-define=API_BASE_URL=https://10.0.2.2:8080/api/v1
run "APK release con https://192.168.1.20/api/v1 (IP privada)" flutter build apk --release --dart-define=API_BASE_URL=https://192.168.1.20/api/v1
run "APK release con https://backend.example.test/api/v1 sin bandera de prueba" flutter build apk --release --dart-define=API_BASE_URL=https://backend.example.test/api/v1
run "AAB sin configuración" flutter build appbundle --release
run "AAB con URL de prueba, eliminación y páginas, sin firma ni identificador" flutter build appbundle --release --dart-define=API_BASE_URL=https://backend.example.test/api/v1 $OK -Pkora.testBackendUrl=true
run "APK release de prueba permitido (backend.example.test + -Pkora.testBackendUrl=true)" flutter build apk --release --target-platform android-arm64 --dart-define=API_BASE_URL=https://backend.example.test/api/v1 -Pkora.testBackendUrl=true
APK=build/app/outputs/flutter-apk/app-release.apk
AAPT=$(ls /opt/android-sdk/build-tools/*/aapt 2>/dev/null $ANDROID_HOME/build-tools/*/aapt 2>/dev/null | tail -1)
echo "### Inspección del APK release de prueba ($AAPT)"
$AAPT dump badging $APK | grep -E "^package|sdkVersion|targetSdkVersion" | sed 's/^/   /'
$AAPT dump permissions $APK | grep -i internet | sed 's/^/   /'
$AAPT dump xmltree $APK AndroidManifest.xml | grep -iE "debuggable|usesCleartextTraffic|enableOnBackInvokedCallback" | sed 's/^/   /'
unzip -p $APK lib/arm64-v8a/libapp.so | strings | grep -cE "localhost:8080|10\.0\.2\.2|storePassword|BEGIN PRIVATE KEY" | sed 's/^/   coincidencias sensibles en libapp.so: /'
