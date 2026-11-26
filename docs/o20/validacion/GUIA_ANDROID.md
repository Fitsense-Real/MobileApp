# Guía: probar O20 en un teléfono Android físico (Windows + Android Studio)

**Estado: pendiente de ejecución por el usuario.** No tengo un teléfono disponible, así que no hay ninguna prueba física hecha.

Esta guía usa la versión de depuración de la rama **`generation`**, que desde el merge de la PR #22 (`d7bbc1a5b5296b06243207c8feb98b3de1187452`) incluye O20 (PR #19), el historial de adaptaciones comprensible (P2, PR #21) y los resultados pendientes guardados en el teléfono (P1, PR #22), contra **tu Backend de pruebas**, nunca contra producción. No genera APK de producción ni despliega nada.

## 0. Requisitos

| | |
|---|---|
| Windows 10/11 con Git y PowerShell | |
| Android Studio con Android SDK Platform-Tools (incluye `adb`) | Settings → Languages & Frameworks → Android SDK → SDK Tools |
| Flutter **3.50.1**, la versión de CI (`.github/workflows`) | `flutter --version` |
| Teléfono Android con «Depuración por USB» | Ajustes → Acerca del teléfono → toca 7 veces «Número de compilación» → Opciones de desarrollador → Depuración por USB |
| Cable USB de datos | |
| Backend `generation` con #83 y #84 (migración V65) y la base donde está el usuario Demo Kora | Ver §2 |

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

- En `git log` debe aparecer `Merge PR #22: P1, resultados pendientes…` (`d7bbc1a`) o un commit posterior de `generation`.
- `flutter doctor` debe mostrar Flutter, Android toolchain y Android Studio sin errores en rojo.

## 2. Backend local sin IA

En tu PC, arranca el Backend con la IA apagada. Así no se gastan créditos y no se generan planes con IA:

```powershell
$env:FITSENSE_AI_ENABLED = "false"
Remove-Item Env:REPLICATE_API_TOKEN, Env:OPENAI_API_KEY -ErrorAction SilentlyContinue
java -jar target\fitsense-backend-0.0.1-SNAPSHOT.jar --server.port=8080
```

Añade tus parámetros habituales de base de datos.

Comprueba que responde:

```powershell
curl.exe -s -o NUL -w "%{http_code}" http://localhost:8080/api/v1/catalog/body-parts
```

Un `401` o un `200` significa que está arriba.

**Usuario 48 (participante del estudio):**

- **No pruebes de lunes de 02:30 a 04:00 (hora de Lima).** A las 03:00 el cierre semanal procesa a los participantes y podría generar un plan nuevo.
- **No pulses** «Generar plan».
- **No omitas sesiones** con esa cuenta.
- **No cambies** `is_study_participant`.

## 3. Conectar el teléfono por ADB

```powershell
adb devices
```

1. Acepta en el teléfono el aviso «¿Permitir depuración por USB?».
2. El teléfono debe aparecer como `device`, no como `unauthorized`.

### Opción A (recomendada): `adb reverse` por el cable

```powershell
adb reverse tcp:8080 tcp:8080
adb reverse --list
```

Así, `127.0.0.1:8080` del teléfono es el `localhost:8080` de tu PC.

Vuelve a ejecutarlo cada vez que reconectes el cable o reinicies `adb`.

### Opción B: por Wi-Fi

Si no puedes usar `adb reverse`:

1. Pon el teléfono y el PC en la misma red.
2. Averigua la IP del PC con `ipconfig`.
3. Abre el puerto en el cortafuegos:

   ```powershell
   New-NetFirewallRule -DisplayName "Kora backend 8080" -Direction Inbound -LocalPort 8080 -Protocol TCP -Action Allow
   ```

4. Comprueba que el Backend escucha en todas las interfaces, no solo en `127.0.0.1`:

   ```powershell
   netstat -ano | findstr :8080
   ```

   Debe aparecer `0.0.0.0:8080` o `[::]:8080` en estado `LISTENING`. Es lo normal en Spring Boot si no se configuró `server.address`. Si solo aparece `127.0.0.1:8080`, el teléfono no llegará por Wi-Fi.
5. En el §4 usa `http://IP_DEL_PC:8080/api/v1`, con la IP **real** que muestra `ipconfig` en el adaptador Wi-Fi.

**En el teléfono, `localhost` y `127.0.0.1` son el propio teléfono, no el PC.** Solo apuntan al PC cuando `adb reverse` está activo (opciones A y C).

### Opción C: ADB inalámbrico (Android 11 o superior, sin cable)

1. Pon el teléfono y el PC en la misma red Wi-Fi.
2. En el teléfono: Opciones de desarrollador → **Depuración inalámbrica** → actívala → **Vincular dispositivo con código de vinculación**. Anota la IP, el puerto de vinculación y el código.
3. En el PC, vincula y conecta:

   ```powershell
   adb pair IP_DEL_TELEFONO:PUERTO_DE_VINCULACION
   ```

   Escribe el código de 6 dígitos cuando lo pida. Después conecta con el puerto que muestra la pantalla «Depuración inalámbrica», que es distinto del de vinculación:

   ```powershell
   adb connect IP_DEL_TELEFONO:PUERTO
   adb devices
   ```

4. **Acceso al Backend:** `adb reverse` también funciona por la conexión inalámbrica, así que usa la URL de la opción A.

   ```powershell
   adb reverse tcp:8080 tcp:8080
   ```

   Si falla, usa la URL de la opción B.

**No uses `10.0.2.2`:** esa dirección solo funciona en el emulador, nunca en un teléfono físico.

### 3.1 Comprobar que el teléfono llega al Backend (antes de abrir Kora)

En el **navegador del teléfono** (Chrome), abre la dirección que usarás en el §4 añadiendo `/catalog/body-parts`:

- con `adb reverse` (opciones A y C): `http://127.0.0.1:8080/api/v1/catalog/body-parts`;
- por Wi-Fi (opción B): `http://IP_DEL_PC:8080/api/v1/catalog/body-parts`.

**Resultado esperado:** una respuesta JSON del Backend. Vale tanto una lista como un error `401` en JSON.

Si el navegador dice «No se puede acceder a este sitio», el teléfono no llega al Backend:

- revisa `adb reverse --list` (opciones A y C);
- revisa la IP, el cortafuegos y `netstat` (opción B).

No abras Kora hasta que esto funcione.

## 4. Ejecutar Kora en el teléfono

### Desde Android Studio

1. **Abre el proyecto:** File → Open → la carpeta `MobileApp`. Instala los plugins **Flutter** y **Dart** si los pide.
2. **Configura Flutter:** Settings → Languages & Frameworks → Flutter → Flutter SDK path, apuntando a tu Flutter 3.50.1.
3. **Elige el teléfono:** en la barra superior, en el selector de dispositivos, elige tu teléfono. Debe aparecer igual que en `adb devices`.
4. **Pasa la URL del Backend:** Run → Edit Configurations… → `main.dart` → **Additional run args**:

   ```
   --dart-define=API_BASE_URL=http://127.0.0.1:8080/api/v1
   ```

   Por Wi-Fi, usa `http://IP_DEL_PC:8080/api/v1`.
5. **Ejecuta:** Run ▶ (Mayús+F10), en modo debug. Los mensajes salen en la pestaña **Run**; los del sistema, en **Logcat**.

### O desde PowerShell

```powershell
flutter devices
flutter run -d ID_DEL_TELEFONO --dart-define=API_BASE_URL=http://127.0.0.1:8080/api/v1
```

En la opción B, la URL es `http://IP_DEL_PC:8080/api/v1`. En las opciones A y C, con `adb reverse`, es `http://127.0.0.1:8080/api/v1`.

- El modo debug permite HTTP local (`android/app/src/debug/AndroidManifest.xml`).
- **Push:** sin `android/app/google-services.json` la app compila, pero sin notificaciones push. Para probarlas, incorpora los archivos según `docs/push/INCORPORAR_CONFIGURACION_FIREBASE.md`.

## 5. Qué revisar con el usuario Demo Kora (solo lectura: no modifica nada)

### 5.1 Antes: comprobar que el dataset sigue intacto (solo lectura)

Hazlo antes de abrir la app. En DBeaver o pgAdmin, sobre tu base, ejecuta el script **`docs/o20/validacion/usuario48_verificacion_solo_lectura.sql`**:

- Va entero dentro de `BEGIN TRANSACTION READ ONLY … ROLLBACK`: PostgreSQL rechaza cualquier escritura.
- Usa las tablas y columnas reales del Backend (V65).
- No lee contraseñas.
- No cambia la participación ni el dataset.

Revisa cada resultado con lo esperado, que está anotado en el propio script:

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

- **Si la consulta 3 devuelve más de 4 planes** o aparece una adaptación nueva: un cierre automático alteró la demo. No sigas y avísame.
- **Si todo coincide,** la prueba con el usuario 48 puede empezar.

Las fechas concretas dependen de la semana en que se cargó el dataset.

### 5.2 En la app

Inicia sesión con `usuario.demo.kora@example.com` y su contraseña.

Las fechas de la tabla son las de la copia validada (semana vigente del 23/11/2026). Si cargaste el dataset otra semana, se desplazan igual.

| N.º | Pantalla / acción | Resultado esperado |
|---|---|---|
| D1 | Inicio | «Hola, Usuario». «Tu progreso»: 100 %, 5/5, semana del 16/11. «Rutinas para hoy» con el entrenamiento del día. Sin avisos de seguridad pendientes |
| D2 | Rutinas | Los 5 entrenamientos de la semana vigente (Empuje, Traccion, Piernas, Tren superior, Tren inferior; el dataset escribe «Traccion» sin tilde). Ninguno con «No disponible por ahora» |
| D3 | Progreso → selector de semana | 16/11: 100 %, 5/5, «Sin ajustes registrados». 09/11: 100 %, «Plan adaptado a ti» (la sustitución por dolor). 02/11: 67,8 %, 3/5 |
| D4 | Progreso → «Resumen de ajustes» | El ajuste del 23/11 (progresión) y el del 09/11 (sustitución) |
| D4b | Progreso → «Historial de adaptaciones» (P2) | Tres tarjetas, sin códigos: 23/11 «Tu rutina avanzó un paso»; 16/11 «Tu rutina se mantiene igual»; 09/11 «Se sustituyó un ejercicio por seguridad», con «Sesión revisada: jueves 05/11 (Tren superior)» |
| D5 | Perfil → Historial de planes | 4 semanas: 23/11 «Vigente · 5 días · Progresión»; 16/11 «Completado · 5 días · Sin cambios»; 09/11 «Completado · 5 días · Sustitución por seguridad»; 02/11 «Completado · 5 días». **En ningún sitio debe aparecer `ADAPT_LOCALIZED` ni otro código** |
| D6 | Perfil → Ejercicios excluidos por dolor | «Te dolieron: Aperturas de pecho sentado con palanca. Lo marcaste con dolor · 05/11/2026». **No pulses «Ya no me duele»** |
| D7 | Manda la app a segundo plano 1 minuto y vuelve | La rutina y las exclusiones se vuelven a cargar, sin errores |
| D8 | Cierra la app del todo y ábrela | La sesión se mantiene y se ve lo mismo |
| D9 | Perfil → Cuenta | «Ganar masa muscular (usuario de demostracion de Kora)», 176 cm, 74 kg, 5 días · 60 min |
| D10 | Perfil → Historial de planes → «Semana del 02/11/2026» | 5 entrenamientos: 3 «Completado», 1 «Parcial» y 1 «Omitido» |

Capturas de referencia, hechas con las respuestas reales de una copia local de la demo: `capturas/D1…D5`.

## 6. Qué probar con una cuenta sintética nueva (modifica registros: nunca con el usuario 48)

1. Regístrala desde la app, con el consentimiento al estudio, en la base de pruebas.
2. Completa el perfil y genera el primer plan. Con la IA apagada lo genera el motor de reglas.

| N.º | Acción | Resultado esperado |
|---|---|---|
| S1 | Abre un entrenamiento → «Omitir entrenamiento» → «Dolor o molestias» | «Gracias por avisar», con «Más tarde» / «Indicar ahora» |
| S2 | «Más tarde». Abre otro entrenamiento que repita algún ejercicio de la sesión omitida | Ese ejercicio: «No disponible por ahora», con la explicación sin códigos |
| S3 | «Registrar ejercicio» en el bloqueado | Solo «No lo hice»; nunca «Lo completé» ni «Lo hice parcialmente» |
| S4 | Comienza la sesión: el bloqueado como no realizado, los demás completados; finaliza | Sesión guardada con los permitidos |
| S5 | **Modo avión** y registra un ejercicio permitido | «No pudimos confirmar con el servidor que tu rutina sigue vigente…»; el ejercicio queda «Pendiente de enviar». No se envía |
| S6 | Quita el modo avión → «Reintentar envío» | Se envía una sola vez y el aviso desaparece |
| S7 | Perfil → Ejercicios excluidos por dolor → «Responder» | Elige el que dolió y marca 1 o 2 como no relacionados (el que dolió no se puede marcar). «Enviar» muestra qué vuelve y qué sigue excluido |
| S8 | Vuelve a la rutina | Los no relacionados ya no están bloqueados; los no nombrados, sí |
| S9 | Con una rutina abierta, manda la app a segundo plano, omite por dolor otra rutina desde otro dispositivo (o con la API) y vuelve | Al volver, la rutina se actualiza sola y muestra el bloqueo |
| S10 | Cierra sesión y vuelve a entrar | Las mismas exclusiones y bloqueos; la sesión de S4 sigue registrada |
| S11 (opcional) | Con un resultado «Pendiente de enviar» (S5), omite por dolor, desde otro dispositivo, otra rutina que contenga **ese mismo ejercicio**. Quita el modo avión y pulsa «Reintentar envío» | El resultado **no se envía**: pasa a «Resultados retenidos: no se enviarán» y el ejercicio aparece bloqueado. Solo puede registrarse como «No lo hice». «Descartar» lo quita |
| S12 | Mientras se envía un resultado, activa el modo avión; luego desactívalo y pulsa «Reintentar envío» | «Se perdió la conexión…». Al reintentar, Kora consulta antes la sesión: si el resultado ya había llegado, no lo repite; nunca hay registros duplicados |
| S13 | Con un resultado «Pendiente de enviar» (modo avión), **cierra Kora del todo** (deslízala fuera de recientes) y quita el modo avión. Abre Kora y la misma rutina | El resultado reaparece como «Pendiente de enviar» y **no se envía solo**. Pulsa «Reintentar envío»: se envía una vez y desaparece |
| S14 | Repite S13, pero antes de reabrir omite por dolor, desde otro dispositivo, una rutina con ese mismo ejercicio | Al reabrir: «Retenido: no se enviará», con el ejercicio bloqueado. «Descartar» lo quita |
| S15 | Con un pendiente guardado, cierra sesión y entra con **otra cuenta** | La otra cuenta no ve nada. Al volver a la primera cuenta, dentro de 48 h, el resultado reaparece |
| S16 (D-M1) | En un ejercicio por tiempo (por ejemplo, 3 × 120 s), «Lo completé» | Se guarda el total de la prescripción (360 s), no el de una serie |
| S17 (D-M1) | En otro ejercicio, «Lo hice parcialmente» con menos de lo prescrito (por ejemplo, 2 series y 150 s), con un motivo. Luego intenta un parcial con la prescripción completa | El primero se guarda tal cual (2 series, 150 s). El segundo pide usar «Lo completé»: un parcial nunca cuenta como completo |

## 7. Lista de comprobación final

| Comprobación | Cuenta | ¿Modifica registros? | Resultado esperado | Filas |
|---|---|---|---|---|
| Inicio de sesión | Usuario 48 | No | Entra a Inicio | D1 |
| Perfil | Usuario 48 | No | Datos del perfil visibles | D9 |
| Rutina vigente | Usuario 48 | No | 5 entrenamientos con sus ejercicios | D1, D2 |
| Historial | Usuario 48 | No | 4 planes (si el §5.1 dio 4); la semana del 02/11 con completados, parcial y omitido | D5, D10 |
| Adherencia | Usuario 48 | No | 67,8 % (3/5), 100 % y 100 %, coherente con el historial | D3 |
| Adaptaciones (P2) | Usuario 48 | No | Textos comprensibles, sin códigos | D4b, D5 |
| Exclusión (O20) | Usuario 48 | No | El 1025 aparece excluido y no figura en la rutina vigente | D6 |
| Registro (D-M1) | Sintética | **Sí** | Duraciones totales y parciales correctas | S16, S17 |
| Resultados pendientes (P1) | Sintética | **Sí** | Reaparece al reabrir y no se envía solo | S13 |
| Seguridad | Sintética | **Sí** | Nunca se envían resultados de ejercicios bloqueados | S3, S11, S14 |
| Cambio de cuenta | Sintética | **Sí** | Sin exposición de pendientes de otra cuenta | S15 |

**Las filas que modifican registros** (D-M1, P1, seguridad y cambio de cuenta) se hacen **solo con la cuenta sintética**. Con el usuario 48 no se registra, no se omite, no se reactiva y no se genera nada sin una autorización específica.

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

En la consola de `flutter run`, copia también los errores en rojo.

Envíame:

- la tabla del §7 (y las filas del §5 y del §6) con OK o FALLA en cada fila;
- las capturas y `logcat.txt` de lo que falle;
- el modelo del teléfono y la versión de Android.
