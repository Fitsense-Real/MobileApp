#!/usr/bin/env bash
# Compila un APK beta de Kora firmado con TU clave de subida y, si tienes el Firebase CLI con sesión
# iniciada, lo distribuye por Firebase App Distribution. No contiene secretos y no publica en Google Play.
#
# Uso (desde la raíz del repositorio, en tu computadora):
#   KORA_API_BASE_URL=https://api.ejemplo.pe/api/v1 \
#   KORA_ACCOUNT_DELETION_WEB_URL=https://ejemplo.pe/eliminar-cuenta \
#   KORA_PRIVACY_POLICY_URL=https://ejemplo.pe/privacidad \
#   FIREBASE_APP_ID=1:000000000000:android:0000000000000000 \
#   KORA_TESTER_GROUPS=evaluadores \
#   tool/beta/distribuir_beta.sh notas.txt
#
# Ver docs/distribucion/DISTRIBUCION_BETA.md.
set -euo pipefail

NOTAS="${1:-}"
falta=()
[[ -f android/key.properties ]] || falta+=("android/key.properties (tu clave de subida; ver docs/preparacion_google_play/FIRMA_Y_AAB.md)")
[[ "${KORA_API_BASE_URL:-}" == https://* ]] || falta+=("KORA_API_BASE_URL con https:// (backend de pruebas o de producción, accesible desde internet)")
KORA_APPLICATION_ID="${KORA_APPLICATION_ID:-pe.fit.kora}"
[[ "$KORA_APPLICATION_ID" == "pe.fit.kora" ]] || falta+=("KORA_APPLICATION_ID debe ser el aprobado, pe.fit.kora (otro identificador sería otra app y los evaluadores perderían sus datos)")
[[ -f android/app/google-services.json ]] || falta+=("android/app/google-services.json (Firebase kora-fitpe, generado con FlutterFire; sin él no hay notificaciones push)")
[[ ! -f android/app/google-services.json ]] || grep -qE "\"package_name\"[[:space:]]*:[[:space:]]*\"${KORA_APPLICATION_ID//./\\.}\"" android/app/google-services.json || falta+=("google-services.json no contiene la app Android $KORA_APPLICATION_ID")
[[ "${KORA_ACCOUNT_DELETION_WEB_URL:-}" == https://* ]] || falta+=("KORA_ACCOUNT_DELETION_WEB_URL con https://")
[[ "${KORA_PRIVACY_POLICY_URL:-}" == https://* ]] || falta+=("KORA_PRIVACY_POLICY_URL con https://")
[[ -n "$NOTAS" && -f "$NOTAS" ]] || falta+=("archivo de notas de la versión (primer argumento; plantilla en tool/beta/notas_version_plantilla.txt)")
if (( ${#falta[@]} )); then
  printf 'No se compila la beta. Falta:\n'; printf ' - %s\n' "${falta[@]}"; exit 1
fi

version=$(grep -E '^version:' pubspec.yaml | awk '{print $2}')
echo "Versión de pubspec.yaml: $version (el número tras '+' debe ser mayor que el de la beta anterior)"

flutter build apk --release \
  --dart-define=API_BASE_URL="$KORA_API_BASE_URL" \
  --dart-define=ACCOUNT_DELETION_ENABLED=true \
  --dart-define=ACCOUNT_DELETION_WEB_URL="$KORA_ACCOUNT_DELETION_WEB_URL" \
  --dart-define=PRIVACY_POLICY_URL="$KORA_PRIVACY_POLICY_URL" \
  ${KORA_PASSWORD_RECOVERY_ENABLED:+--dart-define=PASSWORD_RECOVERY_ENABLED=true} \
  -Pkora.applicationId="$KORA_APPLICATION_ID"

apk=build/app/outputs/flutter-apk/app-release.apk
echo "APK: $apk"
sha256sum "$apk" 2>/dev/null || shasum -a 256 "$apk"

if [[ -z "${FIREBASE_APP_ID:-}" ]] || ! command -v firebase >/dev/null; then
  echo "Sin FIREBASE_APP_ID o sin Firebase CLI: sube el APK a mano en Firebase Console > App Distribution."
  exit 0
fi
firebase appdistribution:distribute "$apk" \
  --app "$FIREBASE_APP_ID" \
  --groups "${KORA_TESTER_GROUPS:-evaluadores}" \
  --release-notes-file "$NOTAS"
