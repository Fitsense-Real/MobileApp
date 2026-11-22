#!/bin/bash
# Matriz de protecciones release/AAB (pe.fit.kora + Firebase) e inspección de APK.
cd /home/user/MobileApp
S=/tmp/claude-0/-home-user/7a9522d3-2797-5dcc-8e36-7b70b17e272d/scratchpad
export PATH=$S/sdk350/flutter/bin:$PATH
GS=android/app/google-services.json
trap 'rm -f $GS' EXIT
[[ -f $GS ]] && { echo "ya existe $GS; no se toca"; exit 1; }
OK='--dart-define=ACCOUNT_DELETION_ENABLED=true --dart-define=ACCOUNT_DELETION_WEB_URL=https://kora.example.test/eliminar --dart-define=PRIVACY_POLICY_URL=https://kora.example.test/privacidad --dart-define=API_BASE_URL=https://backend.example.test/api/v1 -Pkora.testBackendUrl=true'
run() { local name="$1"; shift; echo "### $name"; "$@" > $S/rel.out 2>&1; local c=$?; grep -E "^ - |bloqueada|Built " $S/rel.out | sed 's/^/   /'; echo "   salida $c"; }
AAPT=/opt/android-sdk/build-tools/36.0.0/aapt
ZA=/opt/android-sdk/build-tools/36.0.0/zipalign
inspect() { echo "### Inspección $1"; $AAPT dump badging $1 | grep -E "^package|sdkVersion|targetSdkVersion" | sed 's/^/   /'
  $AAPT dump resources $1 | grep -c "spec resource .*drawable/ic_stat_kora" | sed 's/^/   drawable ic_stat_kora en la tabla de recursos: /'
  $AAPT dump xmltree $1 AndroidManifest.xml | grep -A1 -E "default_notification_(icon|channel_id)" | grep -E "value|resource" | sed 's/^/   /'
  $ZA -c -P 16 4 $1 >/dev/null && echo "   zipalign 16 KB: ok" || echo "   zipalign 16 KB: FALLA"; }

jdk() { (cd android && ./gradlew --stop >/dev/null 2>&1); flutter config --jdk-dir=$1 >/dev/null 2>&1; echo "--- JDK: $1"; }
jdk /usr/lib/jvm/java-17-openjdk-amd64
run "APK release de prueba con JDK 17 (mensaje claro en lugar del fallo de lint)" flutter build apk --release --target-platform android-arm64 --dart-define=API_BASE_URL=https://backend.example.test/api/v1 -Pkora.testBackendUrl=true
jdk /usr/lib/jvm/java-21-openjdk-amd64
run "AAB sin google-services.json (identificador por defecto pe.fit.kora)" flutter build appbundle --release $OK
run "AAB con -Pkora.applicationId=com.example.fitsense_mobile" flutter build appbundle --release $OK -Pkora.applicationId=com.example.fitsense_mobile
run "AAB con -Pkora.applicationId=pe.otro.kora" flutter build appbundle --release $OK -Pkora.applicationId=pe.otro.kora
sed 's/"pe.fit.kora"/"pe.otro.kora"/' $S/fcm-ficticio/google-services.json > $GS
run "AAB con google-services.json FICTICIO de otra app (pe.otro.kora)" flutter build appbundle --release $OK
cp $S/fcm-ficticio/google-services.json $GS
run "AAB con google-services.json FICTICIO de pe.fit.kora (solo debe faltar la firma)" flutter build appbundle --release $OK
run "APK debug con google-services.json FICTICIO" flutter build apk --debug --target-platform android-arm64
unzip -p build/app/outputs/flutter-apk/app-debug.apk resources.arsc | strings | grep -cE "kora-ficticio-prueba-local" | sed 's/^/   recursos de Firebase generados (project_id ficticio): /'
rm -f $GS
run "APK debug sin google-services.json" flutter build apk --debug --target-platform android-arm64
inspect build/app/outputs/flutter-apk/app-debug.apk
run "APK release de prueba (backend.example.test + -Pkora.testBackendUrl=true)" flutter build apk --release --target-platform android-arm64 --dart-define=API_BASE_URL=https://backend.example.test/api/v1 -Pkora.testBackendUrl=true
inspect build/app/outputs/flutter-apk/app-release.apk
$AAPT dump xmltree build/app/outputs/flutter-apk/app-release.apk AndroidManifest.xml | grep -ciE "debuggable" | sed 's/^/   debuggable en release: /'
echo "### git status de google-services.json"; git status --short -- $GS; ls $GS 2>&1 | sed 's/^/   /'
jdk /usr/lib/jvm/java-17-openjdk-amd64
