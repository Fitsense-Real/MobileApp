# Auditoría Android release (estado antes de corregir, 19/11/2026)

Base auditada: rama `claude/mobile-final-validation` (Fitsense-Real/MobileApp#3, `17ef213`), que
contiene #1 (Kapi) y #2 (tour). `generation` del Mobile sigue en `4291c6b`: #1, #2 y #3 están
abiertas y sin fusionar. Flutter 3.32.8, AGP 8.7.3, Gradle 8.12, Kotlin 2.1.0.

## Evidencia del APK release original (`flutter build apk --release`)

| Comprobación | Resultado original | Problema |
|---|---|---|
| `aapt dump permissions` | `RECEIVE_BOOT_COMPLETED`, `VIBRATE`, `POST_NOTIFICATIONS` | **Falta `INTERNET`**: solo estaba en `src/debug` y `src/profile` |
| `aapt dump badging` | `targetSdkVersion:'35'`, `compileSdkVersion='35'` | Play exige 36 desde el 31/08/2026 |
| `aapt dump badging` | `package: name='com.example.fitsense_mobile'` | Identificador de ejemplo |
| `apksigner verify --print-certs` | `CN=Android Debug` | Firma de prueba de la plantilla |
| `ApiConstants.baseUrl` | sin `API_BASE_URL`: `http://10.0.2.2:8080/api/v1` en Android, también en release | Release apuntaría al emulador |
| `kora_auth_form.dart` | «G GOOGLE» y «● APPLE» con `onPressed: null` y «Acceso social próximamente» | Funciones inexistentes visibles |
| Perfil | solo «Retirarme del estudio» (`POST /users/me/withdraw`, no borra datos) | No hay eliminación de cuenta |
| `main.dart` | `ProviderObserver` con `debugPrint` de cada provider y de cada error con su traza | `debugPrint` también escribe en logcat en release |

## Revisión por áreas

| Área | Estado encontrado |
|---|---|
| Manifiestos | `main`: sin `INTERNET`, sin `enableOnBackInvokedCallback`. `debug`: `INTERNET` y `usesCleartextTraffic=true`. `profile`: `INTERNET` |
| Temas | `LaunchTheme` y `NormalTheme`, sin `windowOptOutEdgeToEdgeEnforcement` ni colores de barras fijos |
| Gradle | `compileSdk`/`targetSdk` de Flutter (35); `signingConfig = debug` en release; NDK 27 |
| `.gitignore` de Android | ya ignora `key.properties`, `*.jks` y `*.keystore` |
| Firebase | no hay `google-services.json` ni dependencias de Firebase |
| Rutas | `go_router`; el tour y el resultado usan `PopScope(canPop: false)` |
| Cliente HTTP | Dio, timeouts de 20 s, sin `LogInterceptor`, `AuthInterceptor` con JWT y manejo global de 401 |
| Sesión | JWT en `FlutterSecureStorage`; datos locales por usuario: `kora_welcome_<id>`, `kora_reminders_<id>`, `kora_favorites_<id>` |
| Perfil | sección «Cuenta» (hoja inferior) con datos, estado del estudio y retiro |
| Pruebas | 142 pruebas Flutter en verde |
| CI | `.github/workflows/ci.yml` en #3 (analyze, test, web, APK debug); aún no corre porque no está en `generation` |
| Backend | `generation` (`a1ccf53`) **no tiene `DELETE /users/me`** ni otro endpoint de borrado; ninguna rama remota ni PR lo implementa todavía |

## Ya correcto antes de esta orden

- Páginas de 16 KB: las librerías de 64 bits están alineadas a 64 KB y el APK pasa `zipalign -P 16`.
- Recordatorios inexactos: no hace falta `SCHEDULE_EXACT_ALARM`.
- Icono propio (vector de Kora) y etiqueta «Kora».
- HTTP sin cifrar permitido solo en debug.

## Plan de PR (apiladas sobre #3, en este orden)

| PR | Rama | Contenido |
|---|---|---|
| D | `claude/play-d-social-cleanup` | quitar accesos sociales inactivos |
| A | `claude/play-a-android` | `INTERNET`, API 36 (AGP 8.9.1), borde a borde, gesto atrás |
| B | `claude/play-b-release` | URL HTTPS obligatoria en release, identificador configurable, firma propia, AAB, logs |
| C | `claude/play-c-account-deletion` | eliminación de cuenta en Perfil, separada del retiro |
