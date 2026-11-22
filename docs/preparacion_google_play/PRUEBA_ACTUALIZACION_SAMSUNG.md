# Prueba de actualización de la PR #13 en el Samsung SM-A145M (Windows, PowerShell)

**Qué se valida:** instalar la versión **nueva** (PR #13) **encima** de la **anterior** (`generation`), sin desinstalar
ni borrar datos. Con eso se comprueba que:
- `flutter_secure_storage` 9.2.4 → 10.3.4 migra la sesión guardada;
- `flutter_local_notifications` 19 → 23 conserva o reprograma los recordatorios.

**No se fusiona la PR #13 hasta que esta prueba salga bien.**

## APK entregados

Los dos están firmados con **la misma clave** (debug del entorno de compilación), así que uno se instala encima del
otro.

| Archivo | Código | Identificador | versionCode | compileSdk / targetSdk | SHA-256 del APK |
|---|---|---|---|---|---|
| `kora-anterior-generation-40f5fcf.apk` | `generation` `40f5fcf` (PR #1–#12, #14–#16) | `com.example.fitsense_mobile` | **1** | 36 / 36 | `97b97f1f63e29cd26248454f2cd62a5c2e78dab160197ac8674baaa2418fe770` |
| `kora-nueva-pr13-5c403a9.apk` | PR #13 `5c403a9` (= lo anterior + dependencias) | `com.example.fitsense_mobile` | **2** | 37 / 36 | `b35f53dad5aa89e32c7b15736d701742aa66a3dcb1f0dc6b7beedd332f4b6fcb` |

- **Certificado de firma** (los dos): `CN=Android Debug`, SHA-256
  `6d61a307264b939e7ec4f6857bf2aaefc54b2ffc181d88532cdf1b93ef97315a`.
- **Compilación** (APK debug `arm64-v8a`, el procesador del SM-A145M):

  ```
  flutter build apk --debug --target-platform android-arm64 --build-number <1|2> --dart-define=API_BASE_URL=http://localhost:8080/api/v1 --dart-define=ALLOW_INSECURE_API=true --dart-define=ACCOUNT_DELETION_ENABLED=true
  ```

- **Backend:** los dos usan el backend local del PC a través del cable (`adb reverse`).
- **Debug y release:** el cifrado y la migración del almacenamiento son código nativo idéntico en debug y en release.
  La prueba vale para la migración que recibirán los usuarios.

## 0. Preparación (una vez)

1. **Backend local** en el PC, perfil `local-dev` (IA apagada, sin Replicate). Pasos en
   `PRUEBA_ANDROID_WINDOWS_PENDIENTE.md` §1. Déjalo corriendo.
2. **En el Samsung**, activa la depuración USB:
   1. Ajustes → Acerca del teléfono → Información de software → toca 7 veces «Número de compilación»;
   2. Ajustes → Opciones de desarrollador → «Depuración USB».
3. **Conecta el cable** y acepta la huella del PC en el teléfono. En PowerShell, en la carpeta donde guardaste los APK:

   ```
   cd $HOME\Downloads
   ```

   ```
   adb devices
   ```

   Debe aparecer el teléfono como `device`, no `unauthorized`.

4. **Comprueba la firma de los APK** (opcional). Si tienes las *build-tools* de Android, los dos deben dar el mismo
   SHA-256 `6d61a307…315a`:

   ```
   & "$env:LOCALAPPDATA\Android\Sdk\build-tools\36.0.0\apksigner.bat" verify --print-certs .\kora-anterior-generation-40f5fcf.apk
   ```

   ```
   & "$env:LOCALAPPDATA\Android\Sdk\build-tools\36.0.0\apksigner.bat" verify --print-certs .\kora-nueva-pr13-5c403a9.apk
   ```

## 1. Instalar la versión anterior

1. **¿Ya hay un Kora instalado?**

   ```
   adb shell pm list packages com.example.fitsense_mobile
   ```

   - Si **no** aparece nada, sigue al paso 2.
   - Si aparece, intenta el paso 2. Si `adb` responde `INSTALL_FAILED_UPDATE_INCOMPATIBLE` (otra firma, porque lo
     compilaste en tu PC) o `INSTALL_FAILED_VERSION_DOWNGRADE`, desinstálalo **una sola vez, ahora, antes de empezar**:

     ```
     adb uninstall com.example.fitsense_mobile
     ```

     Esto no invalida la prueba: la migración se comprueba entre el APK anterior y el nuevo de esta carpeta. Lo que
     **no** debe hacerse es desinstalar entre el paso 1 y el paso 3.
2. **Instala la versión anterior:**

   ```
   adb install -r .\kora-anterior-generation-40f5fcf.apk
   ```

3. **Conecta el teléfono al backend del PC.** Repítelo cada vez que reconectes el cable:

   ```
   adb reverse tcp:8080 tcp:8080
   ```

4. **Confirma la versión.** Debe decir `versionCode=1`:

   ```
   adb shell dumpsys package com.example.fitsense_mobile | Select-String "versionCode"
   ```

## 2. Preparar el estado con la versión anterior

1. **Abre Kora y crea una cuenta sintética.** Usa un correo inventado, por ejemplo `samsung1@prueba.local`, y una
   contraseña de prueba. **No uses tu correo ni una contraseña real.**
2. **Completa el perfil:**
   1. «Generar mi plan»;
   2. 30 s de «Generando» con Kapi;
   3. recorrido;
   4. «Ver mi plan».
3. **Cierra Kora** desde recientes, deslizándola. Ábrela otra vez: debe entrar **sin pedir el correo**.
4. **Activa los recordatorios.** En Perfil → Recordatorios:
   1. activa «Recordarme mis entrenamientos»;
   2. elige una hora;
   3. acepta el permiso de notificaciones de Android.
5. **Marca una rutina como favorita**: en Rutinas, menú «⋯» de una tarjeta → «Guardar en favoritos». Es
   opcional, pero también vive en el almacenamiento seguro.
6. **Guarda los avisos programados antes de actualizar:**

   ```
   adb shell dumpsys alarm | Select-String "com.example.fitsense_mobile" | Measure-Object | Select-Object Count
   ```

   ```
   adb shell dumpsys alarm > alarmas-antes.txt
   ```

   Hay un aviso por cada entrenamiento próximo, y otro a las 20:00 si está activo «Avisarme… si sigue pendiente». Si el
   recuento es 0, revisa que haya entrenamientos en los próximos días y que el permiso esté concedido.

Anota el nombre de la cuenta, la hora de los recordatorios y la rutina favorita.

## 3. Instalar la versión nueva **encima**

**No desinstales. No borres datos ni caché. No uses `-d`.**

1. **Instala encima.** Debe responder `Success`:

   ```
   adb install -r .\kora-nueva-pr13-5c403a9.apk
   ```

2. **Confirma la versión nueva.** Debe decir `versionCode=2`:

   ```
   adb shell dumpsys package com.example.fitsense_mobile | Select-String "versionCode"
   ```

## 4. Comprobar la migración

| # | Comprobación | Cómo | Esperado |
|---|---|---|---|
| 1 | **La sesión sigue abierta** | Abre Kora | Entra directo a «Hola, …», sin pedir el correo |
| 2 | **No repite el recorrido ni el perfil** | — | Inicio con tu plan |
| 3 | **Favorito conservado** | Rutinas, menú «⋯» de esa tarjeta | Ofrece «Quitar de favoritos» (sigue guardada) |
| 4 | **Preferencias de recordatorios conservadas** | Perfil → Recordatorios | Activado y con la misma hora |
| 5 | **Recordatorios reprogramados** (Kora los vuelve a programar al abrir con plan) | El comando de recuento del §2, paso 6 | El mismo número que antes, o el correspondiente a los entrenamientos que quedan |
| 6 | **Crear recordatorios nuevos** | Cambia la hora en Recordatorios y repite el comando de recuento | Siguen programados, con la hora nueva (`adb shell dumpsys alarm > alarmas-nueva-hora.txt`) |
| 7 | **Cancelar recordatorios** | Desactiva «Recordarme mis entrenamientos» y repite el comando | Recuento **0** |
| 8 | **Volver a activarlos** | Actívalos otra vez | Recuento > 0 |
| 9 | **Persistencia de la sesión** | Cierra Kora desde recientes y ábrela | Sigue con la sesión iniciada |
| 10 | **Tras reiniciar el teléfono** (opcional) | Reinicia, desbloquea y repite el #5 sin abrir Kora | Recuento > 0 (`BootReceiver`) |
| 11 | **Un aviso real** (opcional) | Si hay un entrenamiento hoy, pon la hora a 2–3 minutos y espera | Llega la notificación con la **silueta de Kora** |
| 12 | **Sin errores de migración** | `adb logcat -d -s FlutterSecureStorage flutter > kora-logcat.txt` | Sin `Exception`, `AEADBadTagException` ni `migration failed` |

Si el #1 falla (pide iniciar sesión), **la migración falló**. No sigas, guarda `kora-logcat.txt` y avisa: la PR #13 no
se fusiona.

## 5. Qué reportar

Para cada fila del §4, ✓ o ✗. Adjunta además:
- los archivos `alarmas-antes.txt`, `alarmas-nueva-hora.txt` y `kora-logcat.txt`;
- la versión de Android del teléfono (Ajustes → Acerca del teléfono → Información de software).

Con todo en ✓ puede autorizarse el merge de la PR #13.

## 6. Después (no forma parte de esta prueba)

- **Pasar a `flutter_secure_storage` 11:** solo en otra PR, cuando todas las instalaciones hayan abierto al menos una
  vez una versión con la 10 (`ACTUALIZACION_NOTIFICACIONES_ALMACENAMIENTO.md`).
- **Volver a la versión anterior:** si quisieras dejar el teléfono como estaba, Android no instala un versionCode menor
  encima. Habría que desinstalar, y eso borra los datos locales de Kora (no los del backend).
