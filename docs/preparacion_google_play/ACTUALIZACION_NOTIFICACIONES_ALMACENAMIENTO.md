# Actualización de `flutter_local_notifications` y `flutter_secure_storage`

Rama `claude/deps-notificaciones-almacenamiento`, desde `generation` `fb01dd5`. PR independiente: solo cambia estas
dependencias y lo que su API obliga a tocar.

## Resumen

| Paquete | Antes | Después | Última publicada | Decisión |
|---|---|---|---|---|
| `flutter_local_notifications` | 19.5.0 | **23.0.3** | 23.0.3 | Actualizado |
| `timezone` | 0.10.1 | **0.11.2** | 0.11.2 | Lo exige `flutter_local_notifications` 21+ |
| `flutter_secure_storage` | 9.2.4 | **10.3.4** (`^10.3.4`, nunca 11) | 11.2.0 | Actualizado **solo a 10.x**. La 11 queda bloqueada a propósito (ver abajo) |

## `flutter_secure_storage`: por qué 10.x y no 11

Este almacenamiento guarda la sesión (`access_token`), el progreso del recorrido, los recordatorios, los favoritos y
los datos locales de la cuenta. Perderlo obligaría a todos a volver a iniciar sesión y repetir el recorrido.

- **11.0.0**, según su CHANGELOG: *«Any data saved using deprecated algorithms or features will be unusable after
  this upgrade. If you used a version prior to v10, upgrade to v10 first so existing data is migrated.»*
  Kora 9.2.4 guarda con los algoritmos que la 11 eliminó (RSA/ECB/PKCS1 y AES/CBC/PKCS7). **Pasar directo de la 9 a
  la 11 borraría la sesión de todos.**
- **10.x** detecta los datos de la 9.2.4 (no tienen marcas de algoritmo), los lee con los algoritmos antiguos y los
  vuelve a cifrar con los nuevos (RSA-OAEP y AES-GCM) la primera vez que se accede a ellos. Esto lo hace
  `migrateOnAlgorithmChange`, activo por defecto. Código revisado: `StorageCipherFactory.java` de la 10.3.x.
- **Mínimo 10.3.4:** la 10.3.2 y la 10.3.4 corrigen pérdidas de datos al migrar desde la 9.2.4:
  - la clave AES-GCM de la 9 se buscaba con un nombre con errata;
  - se intentaba migrar en una instalación nueva;
  - una carrera entre varias instancias podía borrar la clave antigua.
- **Una sola configuración:** `lib/core/storage/secure_storage.dart` define `appSecureStorage`, que usan todos los
  sitios de la app (antes había 5 `const FlutterSecureStorage()` sueltos). Lleva
  `AndroidOptions(migrateWithBackup: true)`: guarda una copia hasta que la migración termina, así que un cierre a
  mitad no pierde la sesión.
- **`resetOnError` queda activado,** como es por defecto en la 10. Si la Keystore del teléfono está dañada y no hay
  forma de descifrar, el almacenamiento se vacía en vez de bloquear la app. En el peor caso, el usuario vuelve a
  iniciar sesión: sus datos de entrenamiento están en el backend, no en el teléfono.
- **Cuándo pasar a la 11:** solo cuando todas las instalaciones de evaluadores hayan abierto al menos una vez una
  versión con la 10. Con Firebase App Distribution, cuando cada evaluador haya instalado y abierto el APK de esta PR.
  Después, `checkUpgradeStatus()` (11.1+) permite comprobar que no se perdió nada.
- **Web:** la 10 exige un contexto seguro (`https` o `localhost`). La app web solo se usa para pruebas E2E en
  `localhost`. Si el formato web cambiara, solo obligaría a iniciar sesión otra vez en el navegador.

## `flutter_local_notifications` 19 → 23

| Versión | Cambio que afecta a Kora | Qué se hizo |
|---|---|---|
| 20 | Parámetros posicionales pasan a nombrados en `initialize()` y `zonedSchedule()` | `reminder_scheduler.dart`: solo cambia la forma de la llamada |
| 21 | minSdk 24, compileSdk 36, `timezone` 0.11 | La app ya tenía minSdk 24; `timezone` → 0.11.2 |
| 22.3.3 | Corrige que los avisos repetidos no respetaban la hora tras el cambio de horario | Kora no usa repetidos, pero no hace daño |
| 23.0.0 | **compileSdk 37** y AGP 9.1.1 | `compileSdk = 37` en `android/app/build.gradle.kts`. **targetSdk sigue en 36**: compileSdk solo afecta a la compilación, no al comportamiento en el teléfono. La app ya usaba AGP 9.3.1 |
| 23.0.0 | Corrige un cierre al entregar un aviso programado por una versión anterior del plugin, sin icono, tras actualizar la app | Relevante para esta actualización. Kora además fija el ícono por defecto (`ic_stat_kora`, protegido del *shrinker* desde la PR #14) y reprograma todo al abrir la app |
| 23.0.2 | Deja de usar el método obsoleto `AlarmManagerCompat.setExact()` | Kora usa avisos inexactos (`inexactAllowWhileIdle`) y no pide `SCHEDULE_EXACT_ALARM` |

En el APK, los permisos (`INTERNET`, `RECEIVE_BOOT_COMPLETED`, `VIBRATE`, `POST_NOTIFICATIONS`) y los receptores
(`ScheduledNotificationReceiver`, `ScheduledNotificationBootReceiver`) son los mismos que antes.

## Pruebas automáticas añadidas

- **`test/reminder_channel_test.dart`** comprueba lo que la app envía al plugin nativo de Android:
  - `initialize` con el icono;
  - el permiso de Android 13+;
  - `zonedSchedule` con id, título, texto, *payload*, zona horaria `America/Lima`, hora local exacta, canal
    `workout_reminders` y modo `inexactAllowWhileIdle`;
  - el respaldo a `America/Lima` si la zona horaria no existe.

  **La misma prueba pasa con la 19.5.0 (`generation`) y con la 23.0.3:** lo que se envía a Android es idéntico.
- **`test/secure_storage_upgrade_test.dart`** comprueba que:
  - toda la app usa la configuración con migración y copia de seguridad;
  - el token, el recorrido y los recordatorios guardados por versiones anteriores, con las mismas claves y el mismo
    JSON, se leen igual;
  - otro usuario del mismo teléfono no los ve.

## Prueba obligatoria en Android antes de fusionar

La migración nativa del cifrado solo puede comprobarse en un teléfono o emulador. En esta nube no hay KVM. **Esta PR
no debe fusionarse hasta pasar esta prueba**, que forma parte de `PRUEBA_ANDROID_WINDOWS_PENDIENTE.md`.

1. **Con la versión anterior** (APK debug de `generation` `fb01dd5`):

   ```
   adb install kora-fb01dd5.apk
   ```

   - inicia sesión;
   - completa el recorrido;
   - activa los recordatorios a una hora próxima, por ejemplo dentro de 10 minutos;
   - marca una rutina como favorita;
   - cierra la app.
2. **Actualiza sin desinstalar**, con el APK de esta PR:

   ```
   adb install -r kora-deps.apk
   ```

3. **Comprueba:**
   - [ ] la app abre **con la sesión iniciada**, sin pedir el correo;
   - [ ] **no** vuelve a mostrar el recorrido;
   - [ ] la rutina favorita sigue marcada;
   - [ ] los recordatorios mantienen la hora configurada;
   - [ ] el recordatorio llega a la hora (también tras reiniciar el teléfono, gracias al `BootReceiver`);
   - [ ] cerrar sesión y volver a entrar funciona;
   - [ ] en `adb logcat -d -s FlutterSecureStorage flutter` no aparecen errores de migración.
4. **Repite el paso 1 en un emulador API 24** (minSdk) y en uno **API 36**.

Si algo falla, la PR no se fusiona: se guarda `logcat` y se revisa. Volver atrás es seguro antes de distribuirla, porque
nadie habrá migrado todavía.

## Riesgos que quedan

| Riesgo | Probabilidad | Mitigación |
|---|---|---|
| Keystore del fabricante con fallos al migrar | Baja | `migrateWithBackup` y `resetOnError`; en el peor caso, volver a iniciar sesión |
| Que un evaluador se salte la 10 y llegue a una futura 11 | Media, si no se controla | `^10.3.4` impide resolver la 11; la 11 solo entrará en una PR futura, cuando todos hayan abierto la 10 |
| El CI necesita la plataforma Android 37 | Baja | AGP la descarga si falta; se comprueba en el CI de la PR |
