# Pruebas: identificador `pe.fit.kora` y notificaciones push

## 1. Verificado en el entorno de compilación (Linux, sin teléfono)

Evidencia completa: matriz `rel-matrix-fcm` (salida en la descripción de la PR).

| Comprobación | Resultado |
|---|---|
| `flutter analyze` (reglas estrictas, sin desactivar ninguna) | ✓ sin problemas |
| `flutter test` | ✓ **270** pruebas, de las que 16 son nuevas: eventos, rutas, controlador push con dobles, repositorio de dispositivos e identificador Android |
| APK debug: `aapt dump badging` | ✓ `package: name='pe.fit.kora'` |
| APK release de prueba (`backend.example.test` + `-Pkora.testBackendUrl=true`) | ✓ con **JDK 21**: `pe.fit.kora`, compileSdk 37, targetSdk 36, minSdk 24, no depurable, `ic_stat_kora` incluido, alineación de 16 KB |
| APK release con **JDK 17** | Bloqueado por el guardián con un mensaje claro. Android lint (`lintVitalAnalyzeRelease`, sin omitir) falla al analizar `firebase_core` con JDK 17 (`List.removeLast` es API de JDK 21). **Las compilaciones release y el AAB se hacen con JDK 21**, el de Android Studio. El APK debug y el CI siguen con 17 |
| Manifiesto | ✓ ícono `ic_stat_kora` y canal `kora_avisos` para los mensajes FCM en segundo plano |
| Sin `google-services.json` | ✓ el APK compila y la app arranca sin push. Así lo hacen el CI y la web |
| Con un `google-services.json` **ficticio** de `pe.fit.kora`, solo local y borrado después | ✓ el plugin de Google Services genera los recursos de Firebase. El AAB solo queda bloqueado por la firma |
| `flutter build web` | ✓ (Firebase Messaging no se inicializa fuera de Android) |

### Protecciones de Google Play: AAB

Ningún caso se firmó ni se subió.

| Caso | Bloqueado por |
|---|---|
| Sin `google-services.json` | Falta firma + falta `google-services.json` |
| `-Pkora.applicationId=com.example.fitsense_mobile` | Falta firma + identificador de ejemplo + falta `google-services.json` |
| `-Pkora.applicationId=pe.otro.kora` | Falta firma + distinto del aprobado + falta `google-services.json` |
| `google-services.json` de otra app (`pe.otro.kora`) | Falta firma + «no contiene la app Android pe.fit.kora» |
| `google-services.json` de `pe.fit.kora` | Solo falta la firma (`key.properties`): ninguna clave real se creó ni se versionó |

Siguen activas, sin cambios, las protecciones anteriores:
- HTTPS obligatorio;
- sin hosts locales ni IP privadas;
- bandera explícita para el backend de prueba;
- eliminación de cuenta;
- páginas públicas.

### Lo que **no** se pudo verificar aquí

| Pendiente | Por qué |
|---|---|
| Que Firebase reconozca la app y entregue mensajes | Hace falta el `google-services.json` **real** de `kora-fitpe`, que está solo en tu PC (ver `INCORPORAR_CONFIGURACION_FIREBASE.md`). No hay ningún dato de `kora-fitpe` en esta PR |
| Recepción de push en un teléfono o emulador | Este entorno no tiene teléfono ni aceleración para el emulador. Necesita la sección 2 |
| Envío desde el backend | El backend no tiene el endpoint ni el envío, y esta PR no lo modifica (ver `CONTRATO_PUSH_BACKEND.md`) |
| Disponibilidad de `pe.fit.kora` en Play | Solo Play Console lo confirma, al crear la app |

## 2. Prueba en el teléfono o el emulador (Windows, PowerShell)

**Requisitos:**
- **JDK 21** para compilaciones release o AAB. Compruébalo con `flutter doctor -v`, en la línea «Java version». Si
  muestra 17, ejecuta `flutter config --jdk-dir="C:\Program Files\Android\Android Studio\jbr"`;
- los tres archivos de FlutterFire incorporados en la rama (`INCORPORAR_CONFIGURACION_FIREBASE.md`);
- backend local con `adb reverse tcp:8080 tcp:8080`, como en `PRUEBA_ANDROID_WINDOWS_PENDIENTE.md`;
- **en emulador**, una imagen **con Google Play** o **Google APIs** («Google Play» en el Device Manager). Sin Google
  Play Services, FCM no funciona: el token no llega y aparece `SERVICE_NOT_AVAILABLE` en el log.

### 2.1 Instalar `pe.fit.kora`

1. Compila la versión de depuración:

   ```
   flutter build apk --debug
   ```

2. Instálala:

   ```
   adb install -r build\app\outputs\flutter-apk\app-debug.apk
   ```

3. Comprueba que el paquete es el aprobado:

   ```
   adb shell pm list packages pe.fit.kora
   ```

   Debe responder `package:pe.fit.kora`.

Si tenías la app antigua `com.example.fitsense_mobile`, seguirá instalada al lado: es otra app. Ver la transición en
`docs/preparacion_google_play/IDENTIFICADOR_APLICACION.md`.

### 2.2 Obtener el token de registro FCM

Solo en las compilaciones de **depuración**, Kora escribe el token en el log al iniciar sesión.

1. Abre Kora e inicia sesión.
2. Lee el log:

   ```
   adb logcat -d -s flutter | Select-String "FCM token"
   ```

   Verás `FCM token (backendNotReady): <token>`, porque el backend aún no tiene el endpoint. Eso es lo esperado y no es
   un error. Copia el token, que es largo. **No lo pegues en GitHub ni en chats**: identifica tu teléfono.

### 2.3 Enviar un mensaje de prueba desde la consola de Firebase

1. Abre Firebase Console → proyecto **`kora-fitpe`** → *Messaging* → *Crear tu primera campaña* → *Mensajes de Firebase
   Notifications*.
2. Escribe:
   - título: `Prueba Kora`;
   - texto: `Mensaje de prueba`.
3. En *Opciones adicionales* → *Datos personalizados*, añade la clave `type` con el valor `PLAN_ADAPTED`.
4. Pulsa *Enviar mensaje de prueba*, pega el token y envía.

**Comprueba:**

| # | Estado de la app | Esperado |
|---|---|---|
| 1 | **Abierta** en Inicio | Aparece el aviso con la silueta de Kora. Tocarlo abre Progreso |
| 2 | **En segundo plano** (botón Inicio de Android) | Llega el aviso del sistema con la silueta de Kora, en el canal «Avisos de Kora». Tocarlo abre Kora en Progreso |
| 3 | **Cerrada** (deslizada desde recientes) | Igual que el 2. Tocarlo abre Kora y luego Progreso |
| 4 | Repite con `type` = `WEEKLY_PLAN_READY`, `ACCOUNT_NOTICE` y `PLAN_GENERATED` | Abren Inicio, Perfil y «Preparación de cuenta» |
| 5 | Ajustes de Android → Apps → Kora → Notificaciones | Hay dos canales: «Recordatorios de entrenamiento» y «Avisos de Kora» |

**Limitaciones de Android, que no son errores de Kora:**
- **«Forzar detención» desde Ajustes:** Android no entrega FCM a una app detenida a la fuerza hasta que el usuario la
  vuelve a abrir. Deslizarla desde recientes no la detiene.
- **Ahorro de batería de Samsung:** si Kora está en «Apps en suspensión profunda», los avisos pueden retrasarse.
- **Sin permiso de notificaciones (Android 13+):** el token se obtiene igual, pero no se muestra ningún aviso.

### 2.4 Comprobar que el resto sigue funcionando

- [ ] Inicio de sesión y cierre de sesión. Al cerrar sesión, el log no muestra errores y el token se borra en el teléfono.
- [ ] Rutinas: lista y detalle.
- [ ] Favoritas: marcar, desmarcar, y que se conserven al cerrar y abrir la app.
- [ ] Recordatorios locales: activarlos, recibir uno a la hora fijada con la silueta de Kora, y que tocarlo abra la
      rutina del día.
- [ ] Sesión en vivo y registro, como en `PRUEBA_ANDROID_WINDOWS_PENDIENTE.md`.

### 2.5 Actualizar `pe.fit.kora` a `pe.fit.kora`

Es la versión real de la prueba de actualización, con el identificador nuevo.

1. Con la app instalada y la sesión iniciada (2.1), cambia `version: 1.0.0+1` a `1.0.0+2` en `pubspec.yaml`. **Solo en
   local, no lo subas.**
2. Compila otra vez:

   ```
   flutter build apk --debug
   ```

3. Instálala encima:

   ```
   adb install -r build\app\outputs\flutter-apk\app-debug.apk
   ```

4. Comprueba la versión. Debe mostrar `versionCode=2`:

   ```
   adb shell dumpsys package pe.fit.kora | Select-String "versionCode"
   ```

5. Comprueba que se conservan:
   - la sesión;
   - las favoritas;
   - los recordatorios;
   - el recorrido.

   El token FCM no cambia, y si cambia, se vuelve a registrar.
6. Deshaz el cambio de versión:

   ```
   git checkout -- pubspec.yaml
   ```

## 3. Qué hacer con el resultado

Anota en la PR qué casos pasaron. Si un caso falla, adjunta:
- el número del caso;
- el modelo del teléfono o la imagen del emulador;
- `adb logcat -d -s flutter FirebaseMessaging > kora-push.txt`, después de revisar que no contiene el token completo
  ni datos personales.
