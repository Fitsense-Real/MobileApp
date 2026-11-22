# Prueba pendiente en Android físico y emulador (Windows)

**Estado:** pendiente. La hará el propietario en Windows.

El código bajo prueba es `generation` desde `c895dc6`. Incluye las PR #1–#11, #14 y #15:
- Flutter 3.50.1 / Dart 3.14.0;
- `material_ui`, `go_router` 18, sin `fl_chart`;
- AGP 9.3.1, Gradle 9.5.0, Kotlin 2.4.20, NDK 28.2;
- compileSdk y targetSdk 36, minSdk 24;
- ícono adaptativo y de notificación de Kora (#14);
- recorrido que no se pierde y textos de Kapi (#15).

La actualización de dependencias (PR #13, compileSdk 37) se prueba aparte, siguiendo
`PRUEBA_ACTUALIZACION_SAMSUNG.md` (en la rama de la PR #13).

En la nube no hay KVM, así que todo lo validado hasta ahora son pruebas automáticas, compilaciones y E2E web
contra el backend local. **Que un APK compile no prueba que funcione en un teléfono.**


## 1. Preparación

1. **Backend local** (`Fitsense-Real/Backend`, `generation` `5977d28`) en el PC, puerto 8080, perfil `local-dev`.
   Ese perfil apaga la IA, así que **no usa Replicate**: el motor de reglas genera el plan. Usa PostgreSQL en Docker con
   credenciales solo de desarrollo, que vienen en el propio repositorio. Requisitos: **JDK 21** y **Docker Desktop**.
   En PowerShell, desde la carpeta del backend:

   ```
   docker compose -f docker-compose.local.yml up -d
   ```

   ```
   $env:SPRING_PROFILES_ACTIVE = "local-dev"; .\mvnw.cmd spring-boot:run
   ```

   Cuando aparezca `Started FitsenseApplication`, comprueba que responde. Debe dar `401`, porque falta la sesión:

   ```
   curl.exe -s -o NUL -w "%{http_code}" http://localhost:8080/api/v1/users/me
   ```

   Si Windows pregunta por el firewall para Java, permite solo **redes privadas**.
2. **SDK:** Flutter 3.50.1, Android Studio con el SDK 36 (y el 37 para la PR #13), JDK 17 o 21 para Gradle, y
   `adb` en el `PATH` (`%LOCALAPPDATA%\Android\Sdk\platform-tools`).
3. **APK debug.** Para el emulador:

   ```
   flutter build apk --debug --dart-define=ALLOW_INSECURE_API=true --dart-define=ACCOUNT_DELETION_ENABLED=true
   ```

   Sin `API_BASE_URL`, la app usa en debug `http://10.0.2.2:8080/api/v1`, que es el PC visto desde el emulador.

   Para el teléfono por USB:

   ```
   flutter build apk --debug --dart-define=API_BASE_URL=http://localhost:8080/api/v1 --dart-define=ALLOW_INSECURE_API=true --dart-define=ACCOUNT_DELETION_ENABLED=true
   ```

   ```
   adb reverse tcp:8080 tcp:8080
   ```

   Repite el `adb reverse` cada vez que reconectes el cable.
4. **Instalar:**

   ```
   adb install -r build\app\outputs\flutter-apk\app-debug.apk
   ```

5. **Si algo falla, guarda la evidencia:**

   ```
   adb logcat -d -s flutter > kora-flutter.txt
   ```

   ```
   adb exec-out screencap -p > kora.png
   ```

## 2. Dispositivos sugeridos

| Dispositivo | Por qué |
|---|---|
| Emulador API 36 (Android 16) | Borde a borde obligatorio y gesto atrás predictivo |
| Emulador API 24 o 26 | minSdk 24 tras la migración a AGP 9 |
| Teléfono físico (Android 13–16) | Rendimiento real de las animaciones, teclado y almacenamiento seguro |

## 3. Lista de comprobación

### Generación de 30 s y Kapi (PR #11 y #15)
- [ ] Tras «Generar mi plan», la pantalla dice **«Generando...»** y sigue visible unos **30 s**, aunque el backend
      termine antes.
- [ ] La barra avanza de forma continua durante los 30 s y la app no se bloquea.
- [ ] Kapi cambia de mensaje cada ~5 s sin repetir. Al tocarlo, da un saltito y cambia de mensaje. Ningún mensaje
      habla de generar, el plan, el servidor, la IA ni tiempos de espera.
- [ ] Con «Quitar animaciones» activado en Accesibilidad, Kapi queda quieto y la barra igual llega a los 30 s.
- [ ] A los 30 s pasa al recorrido de bienvenida.
- [ ] **Cierra la app** (desde recientes) a los ~10 s de «Generando» y ábrela otra vez: debe aparecer el **recorrido de
      Kapi**, no el inicio (#15).
- [ ] El primer mensaje del recorrido da la bienvenida («¡Qué alegría tenerte aquí!…») y **no** habla de preparar el
      plan.
- [ ] Al terminar el recorrido, un usuario nuevo ve «¡Tu primera rutina está lista!».
- [ ] **Sin red durante la generación** (modo avión a los 10 s): a los 30 s aparece «Tu plan sigue en camino» con el
      aviso de conexión y «Continuar». Al volver la red, el resultado llega.
- [ ] Si se manda la app a segundo plano y vuelve antes de los 30 s, no se cuelga ni repite la solicitud.
- [ ] Con texto grande (Ajustes, Tamaño de fuente al máximo) y pantalla pequeña, nada queda cortado.

### Onboarding
- [ ] «Peso corporal» viene **marcado** en Casa, Gimnasio y Ambos.
- [ ] Se puede **desmarcar** en el selector o con la ✕ del chip. Al cambiar de lugar no vuelve a marcarse.
- [ ] Desmarcado, no se guarda. En la base: `SELECT equipment_codes FROM user_profiles ...` sin `body weight`.
- [ ] En el paso 5 **no** aparece «Ejercicios a evitar». Los interruptores de movimientos y las notas siguen.
- [ ] El calendario de fecha de nacimiento sale en español y se rechazan menores de 18.

### Recorrido, plan y navegación (PR #10: `material_ui`, `go_router` 18)
- [ ] Recorrido de Kapi completo, con «Atrás» y el **gesto atrás** del sistema paso a paso. En el primer paso, la app
      sale sin perder el progreso.
- [ ] «Ver mi plan», luego Inicio, Rutinas, Progreso y Perfil. Las pestañas y el botón atrás navegan bien.
- [ ] Sesión en vivo: cronómetro y registro «Lo completé / parcialmente / No lo hice» con motivo.
- [ ] El efecto de toque (ink) se ve en los menús del Perfil y en los interruptores.
- [ ] Borde a borde (API 35/36): nada queda bajo la barra de estado ni la de navegación, también con el teclado abierto.

### Sesión, recordatorios y cuenta (sin actualizar `flutter_local_notifications` ni `flutter_secure_storage`)
- [ ] Cerrar y abrir la app conserva la sesión.
- [ ] Actualizar sobre una instalación anterior (`adb install -r`) conserva la sesión.
- [ ] Recordatorios: pide el permiso de notificaciones (Android 13+) y la notificación llega a la hora fijada.
- [ ] La notificación muestra la **silueta de Kora** en la barra de estado, no el logo de Flutter ni un cuadrado
      blanco (#14).
- [ ] El ícono del lanzador es el de Kora: adaptativo en Android 8+ y monocromo con los íconos temáticos de Android
      13+ (#14).
- [ ] Con TalkBack, la tarjeta de un ejercicio lee el nombre, las series, las repeticiones y el descanso, **sin**
      anunciar «imagen» (#15).
- [ ] «Eliminar mi cuenta»: 200, 202 y 403/429. En el teléfono, el 429 muestra los minutos de `Retry-After`.
- [ ] Cerrar sesión lleva al inicio de sesión.

### Release (opcional, sin publicar)
- [ ] `flutter build apk --release` sin `API_BASE_URL` sigue **bloqueado**. Ver `VALIDACION_ANDROID.md`; la matriz
      completa se volvió a comprobar en la nube sobre la PR #10.

## 4. Cómo reportar

Para cada casilla, indica ✓ o ✗, el dispositivo y la versión de Android. Para cada ✗, adjunta `kora-flutter.txt` y
una captura. Con eso se abre una PR de corrección aparte, sin mezclarla con las actualizaciones de dependencias.
