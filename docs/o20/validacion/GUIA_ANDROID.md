# Guía: validar Kora en un teléfono Android físico (Windows + Android Studio)

**Estado: pendiente de ejecución por el usuario.** No tengo un teléfono disponible, así que no hay ninguna prueba física hecha. Lo que sí se ejecutó (Backend real, app real en Chromium, pruebas automatizadas) está en `docs/validacion_android/INFORME_VALIDACION_MOBILE.md`.

Esta guía usa la versión de **depuración** de la rama **`generation`** de MobileApp (desde el merge de la PR #24, `76dcf340908a61fba0314b6705352759cafc0b2f`). Incluye O20 (PR #19), el historial de adaptaciones comprensible (P2, PR #21) y los resultados pendientes guardados en el teléfono (P1, PR #22). Se prueba contra un **Backend local** (`Fitsense-Real/Backend`, rama `generation`, validado en `77b9df3`) y **una copia de la base**, nunca contra producción. No genera APK de producción ni despliega nada.

## 0. Requisitos

| | |
|---|---|
| Windows 10/11 con Git y PowerShell | |
| Android Studio con Android SDK Platform-Tools (incluye `adb`) | Settings → Languages & Frameworks → Android SDK → SDK Tools |
| Flutter **3.50.1**, la versión de CI (`.github/workflows`) | `flutter --version` |
| Java 21 y PostgreSQL (con `pg_dump`, `pg_restore` y `createdb`) | Para el Backend local y la copia de la base |
| Teléfono Android con «Depuración por USB» | Ajustes → Acerca del teléfono → toca 7 veces «Número de compilación» → Opciones de desarrollador → Depuración por USB |
| Cable USB de datos (opción A) | |

## 1. Actualizar el código local (rama `generation`) e instalar dependencias

```powershell
cd C:\ruta\a\MobileApp
git status
```

Si `git status` muestra cambios tuyos, guárdalos antes con `git stash`.

```powershell
git fetch origin generation
git checkout generation
git pull --ff-only origin generation
git log --oneline -3
flutter pub get
flutter doctor
```

- En `git log` debe aparecer `Merge PR #24: guía Android verificable…` (`76dcf34`) o un commit posterior de `generation`.
- `flutter doctor` debe mostrar Flutter, Android toolchain y Android Studio sin errores en rojo.

## 2. Backend local seguro para la prueba

### 2.1 Lo que hace el Backend por su cuenta (comprobado en `77b9df3`)

El Backend escribe en la base **aunque el teléfono solo lea**. Ninguna de estas tareas tiene una propiedad para desactivarla (`@EnableScheduling` es global):

| Tarea | Cuándo | Qué cambia |
|---|---|---|
| `WeeklyCycleScheduler` | Cada hora; actúa el **lunes a las 03:00 hora local** de cada participante | Cierra la semana, adapta y **publica un plan nuevo** (con la IA apagada, lo genera el motor de reglas) |
| `OverdueWorkoutScheduler` | A los **:30** de cada hora | Los entrenamientos `SCHEDULED` cuyo `expires_at` ya pasó pasan a `SKIPPED` |
| `StaleSessionScheduler` | A los **:35** de cada hora | Las sesiones `IN_PROGRESS` de más de 6 h pasan a `ABANDONED` |
| Inicio de sesión | En cada login | `users.last_login_at` y `users.updated_at` del usuario que entra |

Además, `application.properties` del Backend trae **por defecto la URL y el usuario de la base remota**. Si arrancas el jar sin `--spring.datasource.url`, se conecta a ella; esas tareas se ejecutan allí y **Flyway la migraría** si estuviera atrasada.

**Consecuencias para el usuario 48 (participante del estudio):**

- **Usa una copia de la base (§2.2)** para toda la prueba. Así ninguna tarea programada ni ningún login toca la base real.
- La semana vigente del dataset cambia sola cada día: a los :30, los entrenamientos ya vencidos pasan a `SKIPPED`. Es el comportamiento normal del Backend, no una alteración de la demo.
- **El lunes 30/11/2026 a las 03:00 (Lima)**, cualquier Backend conectado a la base real cerrará la semana del usuario 48 y publicará un 5.º plan. Haz la copia y la prueba **antes**. Si hay un Backend desplegado sobre esa base, ese cierre ocurrirá allí de todos modos; no depende de la prueba.
- No pulses «Generar plan», no omitas sesiones y no cambies `is_study_participant`.

### 2.2 Copia de la base (recomendado)

`pg_dump` solo lee la base de origen:

```powershell
pg_dump -h HOST_DE_TU_BASE -U TU_USUARIO -d TU_BASE -Fc -f kora_demo.dump
createdb -h localhost -U postgres kora_demo_copia
pg_restore -h localhost -U postgres -d kora_demo_copia --no-owner --no-privileges kora_demo.dump
```

Ejecuta el script del §5.1 sobre la **copia** y, si quieres, también sobre la base real; es de solo lectura.

### 2.3 Arrancar el Backend con la IA y el push apagados

En la carpeta del Backend (`generation`), compílalo si hace falta (`mvnw.cmd -DskipTests package`) y arráncalo **siempre con la URL de la copia**:

```powershell
Remove-Item Env:REPLICATE_API_TOKEN, Env:OPENAI_API_KEY, Env:FITSENSE_FIREBASE_CREDENTIALS_BASE64, Env:FITSENSE_FIREBASE_CREDENTIALS_FILE -ErrorAction SilentlyContinue
$env:FITSENSE_AI_ENABLED = "false"
$env:FITSENSE_PUSH_ENABLED = "false"
java -jar target\fitsense-backend-0.0.1-SNAPSHOT.jar `
  --server.port=8080 `
  --spring.datasource.url=jdbc:postgresql://localhost:5432/kora_demo_copia `
  --spring.datasource.username=postgres `
  --spring.datasource.password=TU_CLAVE_LOCAL_DE_POSTGRES `
  --authorization.jwt.secret=UNA_CLAVE_LOCAL_DE_AL_MENOS_32_CARACTERES `
  --fitsense.ai.enabled=false --fitsense.ai.api-token= --fitsense.push.enabled=false
```

- La IA solo se usa si `fitsense.ai.enabled=true` **y** hay token (`ReplicateProperties.isUsable()`). Con los dos apagados no hay llamadas a Replicate. En la validación se comprobó con `strace` que el Backend no abre ninguna conexión externa, ni siquiera al generar 25 planes sintéticos.
- No escribas claves reales en el comando ni en archivos del repositorio.

**Comprueba en la consola del Backend** que aparecen estas líneas:

- `Successfully validated … migrations` y `No migration necessary` (en la copia no se migra nada);
- `… operacion <= 1800 s (IA apagada)`;
- `Notificaciones push apagadas (fitsense.push.enabled=false): no se envia nada.`

Si ves `IA encendida` o una migración aplicada, **detén el Backend** y revisa el comando.

Comprueba que responde:

```powershell
curl.exe -s -o NUL -w "%{http_code}" http://localhost:8080/api/v1/catalog/body-parts
```

Un `401` (sin token) o un `200` significa que está arriba.

## 3. Conectar el teléfono por ADB

```powershell
adb devices
```

1. Acepta en el teléfono el aviso «¿Permitir depuración por USB?».
2. El teléfono debe aparecer como `device`, no como `unauthorized`.

**En el teléfono, `localhost` y `127.0.0.1` son el propio teléfono, no el PC.** Solo apuntan al PC cuando `adb reverse` está activo (opciones A y B). **No uses `10.0.2.2`:** esa dirección solo funciona en el emulador.

### Opción A (recomendada): USB y `adb reverse`

```powershell
adb reverse tcp:8080 tcp:8080
adb reverse --list
```

Así, `127.0.0.1:8080` del teléfono es el `localhost:8080` de tu PC. Vuelve a ejecutarlo cada vez que reconectes el cable o reinicies `adb`.

**URL para Kora:** `http://127.0.0.1:8080/api/v1`

### Opción B: ADB inalámbrico (Android 11 o superior, sin cable)

1. Pon el teléfono y el PC en la misma red Wi-Fi.
2. En el teléfono: Opciones de desarrollador → **Depuración inalámbrica** → actívala → **Vincular dispositivo con código de vinculación**. Anota la IP, el puerto de vinculación y el código.
3. En el PC, vincula:

   ```powershell
   adb pair IP_DEL_TELEFONO:PUERTO_DE_VINCULACION
   ```

   Escribe el código de 6 dígitos cuando lo pida.
4. Conecta con el puerto que muestra la pantalla «Depuración inalámbrica», que es distinto del de vinculación:

   ```powershell
   adb connect IP_DEL_TELEFONO:PUERTO
   adb devices
   ```

5. Activa el túnel al Backend:

   ```powershell
   adb reverse tcp:8080 tcp:8080
   adb reverse --list
   ```

**URL para Kora:** `http://127.0.0.1:8080/api/v1`. Si `adb reverse` falla por la conexión inalámbrica, usa la opción C.

### Opción C: Wi-Fi directo, sin ADB para la red

1. Pon el teléfono y el PC en la misma red.
2. Averigua la IP **real** del PC con `ipconfig`, en el adaptador Wi-Fi.
3. Abre el puerto en el cortafuegos:

   ```powershell
   New-NetFirewallRule -DisplayName "Kora backend 8080" -Direction Inbound -LocalPort 8080 -Protocol TCP -Action Allow
   ```

4. Comprueba que el Backend escucha en todas las interfaces y no solo en `127.0.0.1`:

   ```powershell
   netstat -ano | findstr :8080
   ```

   Debe aparecer `0.0.0.0:8080` o `[::]:8080` en estado `LISTENING`. Es lo normal: el Backend no define `server.address`. Si solo aparece `127.0.0.1:8080`, el teléfono no llegará.

**URL para Kora:** `http://IP_DEL_PC:8080/api/v1`

### 3.1 Comprobar que el teléfono llega al Backend (antes de abrir Kora)

En el **navegador del teléfono** (Chrome), abre la URL que vas a usar añadiendo `/catalog/body-parts`:

- con `adb reverse` (opciones A y B): `http://127.0.0.1:8080/api/v1/catalog/body-parts`;
- por Wi-Fi directo (opción C): `http://IP_DEL_PC:8080/api/v1/catalog/body-parts`.

**Resultado esperado:** una respuesta JSON del Backend. Sin sesión, lo normal es un `401` en JSON con «Se requiere un token valido.»: también vale, porque responde el Backend.

Si el navegador dice «No se puede acceder a este sitio», el teléfono no llega al Backend:

- revisa `adb reverse --list` (opciones A y B);
- revisa la IP, el cortafuegos y `netstat` (opción C).

No abras Kora hasta que esto funcione.

## 4. Ejecutar Kora en el teléfono (debug)

### Firebase y el usuario 48

Tras el login, la app registra el teléfono para push con `PUT /users/me/push-devices`. Lo hace si la compilación tiene `android/app/google-services.json` y el usuario permitió las notificaciones, y **eso escribe en la base para esa cuenta**.

- **Con el usuario 48:** compila **sin** `google-services.json` (la app funciona igual, sin push) o, si ya lo tienes, **deniega el permiso de notificaciones** cuando Android lo pida. Así no se registra nada.
- **Firebase (S14) solo con la cuenta sintética.** Para incorporarlo, sigue `docs/push/INCORPORAR_CONFIGURACION_FIREBASE.md`. Nunca envíes notificaciones a usuarios reales.

### Desde Android Studio

1. **Abre el proyecto:** File → Open → la carpeta `MobileApp`. Instala los plugins **Flutter** y **Dart** si los pide.
2. **Configura Flutter:** Settings → Languages & Frameworks → Flutter → Flutter SDK path, apuntando a tu Flutter 3.50.1.
3. **Elige el teléfono:** en la barra superior, en el selector de dispositivos. Debe aparecer igual que en `adb devices`.
4. **Pasa la URL del Backend:** Run → Edit Configurations… → `main.dart` → **Additional run args**:

   ```
   --dart-define=API_BASE_URL=http://127.0.0.1:8080/api/v1
   ```

   En la opción C, usa `http://IP_DEL_PC:8080/api/v1`.
5. **Ejecuta:** Run ▶ (Mayús+F10), en modo **debug**. Los mensajes de la app salen en la pestaña **Run**; los del sistema, en **Logcat**.

### O desde PowerShell

```powershell
flutter devices
flutter run -d ID_DEL_TELEFONO --dart-define=API_BASE_URL=http://127.0.0.1:8080/api/v1
```

- El modo debug permite HTTP local (`android/app/src/debug/AndroidManifest.xml`).
- **No uses `--release`:** la versión publicada rechaza HTTP y direcciones locales, a propósito. Por eso se prueba en debug.

## 5. Qué revisar con el usuario Demo Kora (F01–F09, solo lectura)

### 5.1 Antes: comprobar que el dataset sigue intacto (solo lectura)

Hazlo antes de abrir la app. En DBeaver o pgAdmin, sobre la copia (y, si quieres, sobre la base real), ejecuta **`docs/o20/validacion/usuario48_verificacion_solo_lectura.sql`**:

- Va entero dentro de `BEGIN TRANSACTION READ ONLY … ROLLBACK`: PostgreSQL rechaza cualquier escritura.
- Usa las tablas y columnas reales del Backend (V65).
- No lee contraseñas ni cambia la participación ni el dataset.

| N.º | Comprobación | Esperado |
|---|---|---|
| 1 | Usuario | `user_id = 48`, ACTIVE |
| 2 | Participación (solo se lee) | `is_study_participant = true`. **No la cambies** |
| 3 | Planes | **Exactamente 4**: 3 COMPLETED y 1 ACTIVE, `con_ia = 0` |
| 4 | Sesiones | 14: 13 COMPLETED y 1 PARTIAL. Entrenamientos de W-3: 3 COMPLETED, 1 PARTIAL y 1 SKIPPED |
| 5 | Adaptaciones | 3 filas: ADAPT_LOCALIZED/RESPALDO (sustitución), NO_CHANGE/SIN_ORDEN y NO_CHANGE/SIN_ORDEN con `progressed_sessions` (progresión). `ai_calls = 0` |
| 6 | Métricas | 3 semanas: 67,81 %, 100 % y 100 % |
| 7 | Exclusión del 1025 | DOLOR_IDENTIFICADO, ACTIVA |
| 8 | Perfil | GAIN_MUSCLE, INTERMEDIATE, GYM, 5 días, 60 min, 176 cm, 74 kg |

- **La semana vigente sí cambia con los días.** En la consulta 4, los entrenamientos de la semana vigente pasan de `SCHEDULED` a `SKIPPED` a medida que vencen. Eso es normal (§2.1).
- **Si la consulta 3 devuelve más de 4 planes** o aparece una adaptación nueva, se ejecutó un cierre semanal. No sigas, no modifiques nada y avísame.
- **Si todo coincide,** la prueba con el usuario 48 puede empezar.

### 5.2 En la app

Inicia sesión con `usuario.demo.kora@example.com` y su contraseña.

**No pulses** «Registrar ejercicio», «Omitir entrenamiento», «Ya no me duele», «Responder» ni «Generar plan».

Las fechas son las de la copia validada (semana vigente del 23/11/2026).

| ID | Pantalla / acción | Resultado esperado |
|---|---|---|
| F01 | Inicio de sesión | Entra a Inicio: «Hola, Usuario». Sin avisos de seguridad pendientes |
| F02 | Perfil → «Cuenta» | Nombre y correo; «Ganar masa muscular (usuario de demostracion de Kora)», 176 cm, 74 kg, 5 días · 60 min |
| F03 | Rutinas | Los 5 entrenamientos de la semana vigente (Empuje, Traccion, Piernas, Tren superior, Tren inferior; el dataset escribe «Traccion» sin tilde), con ejercicios y duración. Ninguno con «No disponible por ahora» |
| F04 | Perfil → Historial de planes | 4 semanas: 23/11 «Vigente · 5 días · Progresión»; 16/11 «Completado · 5 días · Sin cambios»; 09/11 «Completado · 5 días · Sustitución por seguridad»; 02/11 «Completado · 5 días» |
| F05 | Historial de planes → «Semana del 02/11/2026» | 5 entrenamientos: 3 «Completado», 1 «Parcial» y 1 «Omitido» |
| F06 | Inicio y Progreso | «Tu progreso»: 100 %, 5/5, semana del 16/11. En el selector de semana: 16/11 100 %; 09/11 100 %; 02/11 67,8 % (3/5) |
| F07 | Progreso → «Historial de adaptaciones» | Tres tarjetas, sin códigos: 23/11 «Tu rutina avanzó un paso»; 16/11 «Tu rutina se mantiene igual»; 09/11 «Se sustituyó un ejercicio por seguridad», con «Sesión revisada: jueves 05/11 (Tren superior)». **En ningún sitio debe aparecer `ADAPT_LOCALIZED` ni otro código** |
| F08 | Perfil → Ejercicios excluidos por dolor; y Rutinas | «Aperturas de pecho sentado con palanca. Lo marcaste con dolor · 05/11/2026». No aparece en ninguna rutina vigente |
| F09 | Manda la app a segundo plano 1 minuto y vuelve; después ciérrala del todo y ábrela | Al volver, la rutina y las exclusiones se recargan sin errores. Al reabrir, la sesión se mantiene y se ve lo mismo |

Capturas de referencia hechas con la app real contra el Backend real y la copia local: `docs/validacion_android/evidencia/capturas/F*.png`.

## 6. Qué probar con una cuenta sintética (S01–S15, escribe: nunca con el usuario 48)

1. Regístrala desde la app, con el consentimiento al estudio, en la **copia** (o en otra base de pruebas).
2. Completa el perfil y genera el primer plan. Con la IA apagada lo genera el motor de reglas.

| ID | Acción | Resultado esperado |
|---|---|---|
| S01 | Abre un entrenamiento → «Comenzar entrenamiento» → «Registrar ejercicio» → «Lo completé» → Guardar | «Guardado: …» con las cantidades del plan. Al registrar todos y «Finalizar sesión», queda guardada con un registro por ejercicio |
| S02 (D-M1) | En un ejercicio por tiempo, «Lo hice parcialmente» con menos de lo prescrito (por ejemplo, 2 series y 150 s), con un motivo. Luego, en otro, «Lo completé» en uno de 3 × 120 s | El parcial se guarda tal cual (2 series, 150 s, parcial). El completo guarda el total (360 s), no el de una serie. Un parcial con la prescripción completa pide usar «Lo completé» |
| S03 | **Modo avión** y registra un ejercicio permitido | «No pudimos confirmar con el servidor que tu rutina sigue vigente…». El ejercicio queda «Pendiente de enviar». No se envía |
| S04 (P1) | Con ese pendiente, **cierra Kora del todo** (deslízala fuera de recientes) y ábrela con el modo avión quitado | Reaparece «Pendiente de enviar» y **no se envía solo** |
| S05 | Pulsa «Reintentar envío» | Kora confirma antes la rutina vigente y lo envía una sola vez; el aviso desaparece |
| S06 | Con un pendiente (modo avión), omite por dolor, desde otro dispositivo o con la API, otra rutina que contenga **ese mismo ejercicio** | Al volver, el ejercicio aparece «No disponible por ahora» |
| S07 | Quita el modo avión y pulsa «Reintentar envío» | El resultado **no se envía**: «Retenido: no se enviará» en «Resultados retenidos: no se enviarán». «Descartar» lo quita sin enviarlo |
| S08 | Mientras se envía un resultado, activa el modo avión; luego desactívalo y pulsa «Reintentar envío» | «Se perdió la conexión…». Al reintentar, Kora consulta antes la sesión: si ya había llegado, no lo repite; nunca hay registros duplicados |
| S09 | Con un pendiente guardado, cierra sesión y entra con **otra cuenta**. Después vuelve a la primera | La otra cuenta no ve nada. La primera, dentro de 48 h, lo recupera |
| S10 | Datos locales dañados | Solo con pruebas automatizadas (`test/pending_results_persistence_test.dart`, caso F). No se fuerza en el teléfono |
| S11 | Caducidad de 48 h | Con reloj simulado en las pruebas automatizadas. En el teléfono, opcional: un pendiente de hace más de 48 h no reaparece |
| S12 | Con la app abierta, restablece la contraseña de la cuenta sintética desde otro dispositivo («¿Olvidaste la clave?»; si arrancaste el Backend con `--fitsense.password-reset.delivery=dev-log`, el código sale en su consola). Vuelve a la app y cambia de pestaña | 401: la app vuelve a «Iniciar sesión» con «Tu sesión expiró. Vuelve a iniciar sesión.». Un ejercicio bloqueado solo admite «No lo hice» (el Backend respondería 422) |
| S13 | Repite S04, pero antes de reabrir omite por dolor, desde otro dispositivo, una rutina con ese mismo ejercicio | Al reabrir: «Retenido: no se enviará», con el ejercicio bloqueado |
| S14 (Firebase) | Con `google-services.json` y la cuenta sintética: concede el permiso de notificaciones | El teléfono queda registrado (en el Backend, una fila en `push_devices` para esa cuenta). Si deniegas el permiso, no se registra nada |
| S15 | Navega por Inicio, Rutinas, Progreso, Historial de planes y la pantalla de generación del primer plan | Todo se muestra sin errores. La generación usa el motor de reglas (sin IA) |

## 7. Lista de comprobación final

| Comprobación | Cuenta | ¿Escribe? | IDs |
|---|---|---|---|
| Inicio de sesión, perfil, rutina, historial, adherencia | Usuario 48 (copia) | Solo el login (`last_login_at`) | F01–F06 |
| Adaptaciones P2 y exclusión O20 | Usuario 48 (copia) | No | F07, F08 |
| Recarga al volver del segundo plano | Usuario 48 (copia) | No | F09 |
| Registro completo y parcial (D-M1) | Sintética | **Sí** | S01, S02 |
| Pendientes y reintento (P1) | Sintética | **Sí** | S03–S05, S13 |
| Seguridad O20 | Sintética | **Sí** | S06, S07, S13 |
| Respuesta perdida | Sintética | **Sí** | S08 |
| Cambio de cuenta | Sintética | **Sí** | S09 |
| 401 / 422 | Sintética | **Sí** | S12 |
| Firebase | Sintética | **Sí** | S14 |
| Generación e historial | Sintética | **Sí** | S15 |

**Con el usuario 48** no se registra, no se omite, no se reactiva y no se genera nada.

**El resultado de la prueba física queda PENDIENTE** hasta que se ejecute en tu teléfono.

## 8. Registros y evidencia si algo falla

```powershell
New-Item -ItemType Directory -Force evidencia-android | Out-Null
adb logcat -c
```

Reproduce el fallo y después:

```powershell
adb logcat -d > evidencia-android\logcat.txt
adb exec-out screencap -p > evidencia-android\captura.png
adb shell getprop ro.product.model
adb shell getprop ro.build.version.release
```

Para un vídeo de hasta 3 minutos, ejecuta lo siguiente y detenlo con Ctrl+C:

```powershell
adb shell screenrecord /sdcard/kora.mp4
```

Luego cópialo al PC:

```powershell
adb pull /sdcard/kora.mp4 evidencia-android\
```

Copia también los errores en rojo de la consola de `flutter run` y las últimas líneas de la consola del Backend.

Envíame:

- la matriz de `docs/validacion_android/INFORME_VALIDACION_MOBILE.md` (F01–F09 y S01–S15) con APROBADO, FALLIDO o BLOQUEADO en la columna «Android físico»;
- las capturas y `logcat.txt` de lo que falle;
- el modelo del teléfono y la versión de Android.
