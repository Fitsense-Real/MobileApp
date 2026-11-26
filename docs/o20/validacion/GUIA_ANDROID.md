# Guía: probar O20 en un teléfono Android físico (Windows + Android Studio)

**Estado: pendiente de ejecución por el usuario.** No tengo un teléfono disponible, así que no hay ninguna prueba física hecha.

Esta guía usa la versión de depuración de la PR #19 contra **tu Backend de pruebas**, nunca contra producción. No genera APK de producción ni despliega nada.

## 0. Requisitos

| | |
|---|---|
| Windows 10/11 con Git y PowerShell | |
| Android Studio con Android SDK Platform-Tools (incluye `adb`) | Settings → Languages & Frameworks → Android SDK → SDK Tools |
| Flutter **3.50.1**, la versión de CI (`.github/workflows`) | `flutter --version` |
| Teléfono Android con «Depuración por USB» | Ajustes → Acerca del teléfono → toca 7 veces «Número de compilación» → Opciones de desarrollador → Depuración por USB |
| Cable USB de datos | |
| Backend `generation` con #83 y #84 (migración V65) y la base donde está el usuario Demo Kora | Ver §2 |

## 1. Actualizar la rama de la PR #19

```powershell
cd C:\ruta\a\MobileApp
git fetch origin claude/o20-exclusiones-dolor
git checkout claude/o20-exclusiones-dolor
git pull --ff-only origin claude/o20-exclusiones-dolor
git log --oneline -3
flutter pub get
```

El primer commit de `git log` debe ser el último de la PR; compáralo con GitHub.

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

4. En el §4 usa `http://IP_DEL_PC:8080/api/v1`.

**No uses `10.0.2.2`:** esa dirección solo funciona en el emulador, nunca en un teléfono físico.

## 4. Ejecutar Kora en el teléfono

```powershell
flutter devices
flutter run -d ID_DEL_TELEFONO --dart-define=API_BASE_URL=http://127.0.0.1:8080/api/v1
```

En la opción B, la URL es `http://IP_DEL_PC:8080/api/v1`.

- El modo debug permite HTTP local (`android/app/src/debug/AndroidManifest.xml`).
- **Push:** sin `android/app/google-services.json` la app compila, pero sin notificaciones push. Para probarlas, incorpora los archivos según `docs/push/INCORPORAR_CONFIGURACION_FIREBASE.md`.

## 5. Qué revisar con el usuario Demo Kora (solo mirar)

Inicia sesión con `usuario.demo.kora@example.com` y su contraseña.

| N.º | Pantalla / acción | Resultado esperado |
|---|---|---|
| D1 | Inicio | «Hola, Usuario». «Tu progreso»: 100 %, 5/5, semana del 16/11. «Rutinas para hoy» con el entrenamiento del día. Sin avisos de seguridad pendientes |
| D2 | Rutinas | Los 5 entrenamientos de la semana vigente (Empuje, Traccion, Piernas, Tren superior, Tren inferior; el dataset escribe «Traccion» sin tilde). Ninguno con «No disponible por ahora» |
| D3 | Progreso → selector de semana | 16/11: 100 %, 5/5, «Sin ajustes registrados». 09/11: 100 %, «Plan adaptado a ti» (la sustitución por dolor). 02/11: 67,8 %, 3/5 |
| D4 | Progreso → «Resumen de ajustes» | El ajuste del 23/11 (progresión) y el del 09/11 (sustitución) |
| D5 | Perfil → Historial de planes | 4 semanas: 23/11 vigente; 16/11, 09/11 y 02/11 completadas |
| D6 | Perfil → Ejercicios excluidos por dolor | «Te dolieron: Aperturas de pecho sentado con palanca. Lo marcaste con dolor · 05/11/2026». **No pulses «Ya no me duele»** |
| D7 | Manda la app a segundo plano 1 minuto y vuelve | La rutina y las exclusiones se vuelven a cargar, sin errores |
| D8 | Cierra la app del todo y ábrela | La sesión se mantiene y se ve lo mismo |

Capturas de referencia, hechas con las respuestas reales de una copia local de la demo: `capturas/D1…D5`.

## 6. Qué probar con una cuenta sintética nueva (acciones)

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

## 7. Registros y evidencia si algo falla

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

- la tabla del §5 y del §6 con OK o FALLA en cada fila;
- las capturas y `logcat.txt` de lo que falle;
- el modelo del teléfono y la versión de Android.
