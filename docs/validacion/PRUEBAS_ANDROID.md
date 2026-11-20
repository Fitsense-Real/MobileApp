# Pruebas Android (ORDEN 2, fase 5)

## Qué se hizo y qué no

| Comprobación | Resultado |
|---|---|
| Android SDK | Instalado en este entorno (plataforma 35, build-tools 35.0.0, NDK 27.0.12077973, CMake 3.22.1) |
| `flutter doctor` | Android toolchain ✓ (SDK 35.0.0) |
| `flutter build apk --debug` | **Compila** (5 min). `aapt`: paquete `com.example.fitsense_mobile`, minSdk 21, targetSdk 35, etiqueta «Kora», permisos INTERNET, POST_NOTIFICATIONS, RECEIVE_BOOT_COMPLETED, VIBRATE; los 6 SVG de Kapi dentro del APK |
| `flutter build apk --release` | **Compila** (29,3 MB, R8 sin errores). Firmado con la clave debug de la plantilla: no sirve para Play |
| Emulador | **No se pudo ejecutar.** El entorno no tiene `/dev/kvm`. Se intentó un emulador API 30 x86_64 sin aceleración (`-accel off`, emulación por software): el sistema llegó a arrancar `system_server` y `systemui`, pero el watchdog de Android lo mató por lentitud (`DeadSystemException: The system died`) y no completó el arranque (`sys.boot_completed` nunca llegó a 1) |
| Dispositivo físico | No hay ninguno conectado |
| iOS | **No compilado ni probado**: requiere macOS y Xcode |

**La app NO se probó en Android.** Lo verificado es que compila (debug y release) con el SDK y el
NDK que exige el proyecto. El comportamiento se validó en web contra el backend real; el código
del tour y de la generación es el mismo en Android, pero no está comprobado en un dispositivo.

## Cómo probarlo en Android Studio (pasos exactos)

1. **Backend local** (rama `claude/async-first-plan-generation`), con PostgreSQL local y sin
   Replicate:
   ```powershell
   $env:DB_PASSWORD="<clave local>"; $env:JWT_SECRET="<32+ caracteres>"; $env:FITSENSE_AI_ENABLED="false"
   .\mvnw spring-boot:run "-Dspring-boot.run.arguments=--spring.datasource.url=jdbc:postgresql://localhost:5432/fitsense_local --spring.datasource.username=postgres"
   ```
   Nunca contra la base de producción.
2. **Emulador**: Android Studio → Device Manager → *Create device* → Pixel 6 → imagen **API 34
   x86_64** (Google APIs) → Finish → ▶. En Windows, habilitar la virtualización (Hyper-V/WHPX)
   para que tenga aceleración.
3. **App**: abrir la carpeta `MobileApp`, rama `claude/welcome-tour`, y ejecutar:
   ```powershell
   .\tmp\flutter-sdk\bin\flutter.bat run
   ```
   En el emulador, la app usa `http://10.0.2.2:8080/api/v1` (el `localhost` del PC). Con un teléfono
   físico, añadir `--dart-define=API_BASE_URL=http://IP_DEL_PC:8080/api/v1`.
4. **Recorrido a comprobar** (cada punto corresponde a un caso de PRUEBAS_GENERACION_ASINCRONA.md):
   1. Crear una cuenta, completar el perfil y pulsar «Generar mi plan»: el tour aparece de
      inmediato.
   2. Recorrer los 10 pasos; en el paso 3, tocar la pestaña «Rutinas» real.
   3. En el paso 5, cerrar la app desde Recientes y volver a abrirla: continúa en el paso 5.
   4. Activar el modo avión en la pantalla de resultado: «Seguimos intentando», con Kapi. Al
      quitarlo, aparece el plan.
   5. «Ver mi plan» lleva al inicio con el plan real; abrir un entreno desde Rutinas.
   6. Perfil → «Ver recorrido de Kora»: repaso sin textos de rutina en preparación.
   7. Accesibilidad: Ajustes → Pantalla → Tamaño de fuente al máximo; TalkBack activado (solo
      debe leer la tarjeta de Kapi); «Quitar animaciones».
5. **Generación lenta o fallida sin Replicate**: el arnés `docs/validacion/e2e/EscenariosE2E.java`
   permite simular demoras y fallos del lado del servidor según el correo (`+d90`, `+fallo1`,
   `+nofactible`). Ver `docs/validacion/e2e/README.md`.

## Avisos de compilación (no bloquean)

- `source value 8 is obsolete` de un plugin de terceros al compilar Java; no afecta.
- La compilación descarga CMake 3.22.1 la primera vez.
