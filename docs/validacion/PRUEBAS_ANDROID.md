# Pruebas Android (fase 6)

## Resultado: compilado, NO ejecutado en Android

**Kora no se instaló ni se ejecutó en un teléfono ni en un emulador.** No hay dispositivo físico
accesible desde este entorno, y el emulador ya falló en la ORDEN 2: sin `/dev/kvm`, en emulación por
software, Android se cerró cuatro veces durante el arranque (`DeadSystemException`). Por indicación
de la orden **no se volvió a intentar**. La ejecución en Android real queda **pendiente de
validación** con la guía `GUIA_INSTALACION_APK.md`.

## Comprobaciones de compilación (16/11/2026, rama `claude/mobile-final-validation`)

| Comprobación | Resultado |
|---|---|
| Toolchain | `flutter doctor`: Android toolchain ✓ (SDK 35.0.0, build-tools 35, NDK 27.0.12077973, CMake 3.22.1) |
| Gradle / AGP / Kotlin | Gradle 8.12, AGP 8.7.3, Kotlin 2.1.0: compila sin errores. Solo aviso de terceros `source value 8 is obsolete` |
| Dependencias | `flutter pub get` sin conflictos; los plugins nativos (`flutter_secure_storage`, notificaciones locales, etc.) compilan con NDK 27 |
| `flutter build apk --debug` | ✓ |
| `flutter build apk --debug --split-per-abi --target-platform android-arm64` | ✓ 57 MB |
| `flutter build apk --release` | ✓ 29,3 MB, R8 sin errores. Firmado con la clave debug de la plantilla: no apto para Play |
| Manifiesto (`aapt dump badging`) | `com.example.fitsense_mobile`, versión 1.0.0 (1), minSdk 21, targetSdk 35, etiqueta «Kora» |
| Permisos | **Corrección (19/11/2026):** esta fila decía que el APK release declaraba `INTERNET`, pero se leyó del APK debug. El release **no** lo declaraba (solo los manifiestos de debug y profile), así que no podía conectarse al backend. Se corrige en la PR A de `docs/preparacion_google_play/` (`PERMISO_INTERNET.md`). El resto de permisos (`POST_NOTIFICATIONS`, `RECEIVE_BOOT_COMPLETED`, `VIBRATE`) sí estaba en el release |
| Recursos | los 6 SVG de Kapi están dentro del APK |
| Tráfico HTTP | `usesCleartextTraffic=true` **solo en el manifiesto de debug** (backend local); el release solo admite HTTPS |
| Dirección del backend | `API_BASE_URL` en compilación; por defecto `10.0.2.2:8080` en Android (emulador) y `localhost:8080` en web y escritorio |

## Artefactos

| Archivo | Uso |
|---|---|
| `kora-debug-telefono-usb-arm64.apk` | teléfono físico con `adb reverse` (entregado en el chat) |
| `kora-debug-telefono-usb.apk` | ídem, todas las arquitecturas |
| `kora-debug-emulador.apk` | emulador de Android Studio |
| `kora-release-sin-firma-definitiva.apk` | solo comprobación de compilación |

Los APK no se versionan ni se publicaron en ningún canal externo. Sus SHA-256 están en
`GUIA_INSTALACION_APK.md`. El CI propuesto compila el APK debug en cada PR.

## Pendiente en un teléfono real

1. Instalar y abrir.
2. Registro, perfil, tour, espera y plan contra el backend local.
3. Cerrar y reabrir durante el tour y durante la espera.
4. Modo avión.
5. TalkBack, fuente máxima y «Quitar animaciones».
6. Permiso de notificaciones de Android 13+ al activar recordatorios.

iOS: sin macOS no se puede compilar ni probar.
