# Backend local

La app se alinea con la rama `generation` de Fitsense-Real/Backend (esquema
V44). `main` del backend está desactualizado (V24) y no sirve de referencia.

La app usa `http://10.0.2.2:8080/api/v1` en el emulador Android y
`http://localhost:8080/api/v1` en web/escritorio. En Android debug se permite
HTTP local; no se cambió la política de tráfico de la versión release.
Un teléfono físico requiere la IP LAN del equipo y el servidor accesible
en esa red:

```powershell
.\tmp\flutter-sdk\bin\flutter.bat run --dart-define=API_BASE_URL=http://IP_DEL_PC:8080/api/v1
```

En web, el backend debe permitir el origen del navegador mediante CORS.

## Contratos verificados con OpenAPI local

- `POST /auth/register`: nombres, apellidos, email, contraseña, zona horaria IANA
  y consentimiento explícito. Devuelve usuario, sin token; luego se solicita login.
- `POST /auth/login`: email y contraseña. Devuelve JWT plano y userId.
- JWT guardado con FlutterSecureStorage. El interceptor añade `Authorization:
  Bearer ...` a las siguientes llamadas. No se registran contraseñas, JWT ni
  datos de salud en logs HTTP.
- `GET /users/me`: recupera nombres completos del usuario autenticado.
- `GET /users/me/profile`: 404 conduce al formulario inicial. Otros errores no
  se interpretan como ausencia de perfil.
- `POST /users/me/profile`: crea perfil; `PUT` actualiza uno existente.
- `GET /catalog/equipment-types`: alimenta el selector con code, nameEs y
  requiresGym. El selector tiene búsqueda y confirmación, filtra gimnasio en
  HOME y admite peso corporal sin selección.

## Perfil

Cinco pasos: objetivo; perfil físico; semana y duración; equipamiento;
permisos de movimiento. El cumpleaños se elige con un calendario en español
que no permite hoy ni fechas futuras. `daysPerWeek` se calcula con los días
marcados; no hay un desplegable adicional de sesiones. Se valida fecha real anterior a hoy,
estatura 120–250, pesos 30–300, duración entera 15–180, 1–7 sesiones y
suficientes días distintos (lunes=1, domingo=7). No se inventa una edad mínima.
Objetivo obligatorio y notas opcionales: máximo 500 caracteres.
Solo se envían los campos de `CreateUserProfileResource`, incluidos los cinco
permisos de movimiento de V25 (`allowHighImpact`, `allowFloorExercises`,
`allowKneelingExercises`, `allowHangingExercises`, `allowOverheadExercises`;
true = permitido). El paso 5 además ofrece un buscador del catálogo
(`GET /catalog/exercises?search=`) que llena `blockedExerciseIds`.

El perfil es de solo lectura después del primer plan: en `generation`,
`PUT /users/me/profile` responde 422 a partir de ese momento y el perfil se
mantiene durante todo el estudio. Perfil → Cuenta muestra los datos y los
movimientos excluidos.

El consentimiento al estudio está desmarcado inicialmente; nunca se deduce
de pulsar el botón de registro. La zona horaria inicial es America/Lima y
puede editarse.

Un plan ya existente se informa como 422 (`PlanAlreadyExistsException`); la
app lo reconcilia igual que un 409.

Tras guardar el perfil se consulta el plan actual y, si no existe, se llama
`POST /users/me/plan/generate` sin cuerpo, con Bearer JWT y hasta cinco minutos
de espera. La animación continúa hasta recibir la respuesta. Los errores
permiten reintentar conservando el perfil guardado. Se consulta el plan actual
en los reintentos y ante un 409 para reconciliar una creación anterior.
El inicio muestra el plan devuelto, incluso si corresponde a la semana próxima.
El inicio y Rutinas muestran los entrenamientos y ejercicios del plan del servidor.
Las métricas e intervenciones se consultan con GET /users/me/metrics/weekly y
GET /users/me/interventions, ordenadas desde la semana o ajuste más reciente.
Cada sección tiene estados de carga, error y vacío; los valores ausentes no se
presentan como cero. Se pueden actualizar deslizando hacia abajo o con Actualizar.
El plan se vuelve a consultar al regresar de una rutina; si es de la semana
próxima y current no lo devuelve, se recarga por su ID, sin conservar estados viejos.

La rutina permite recuperar la sesión actual, iniciar, guardar resultados por
ejercicio (PUT que reemplaza el resultado anterior), finalizar con esfuerzo
obligatorio, abandonar y omitir indicando la causa. El botón de ciclo semanal
en Progreso pide confirmación antes de POST /cycle/run-for-me y recarga los datos.
El registro retrospectivo por /report permite introducir resultados por ejercicio,
fecha/hora y esfuerzo, incluso para entrenamientos vencidos. Cada ejercicio ofrece
completado (cantidades prescritas), parcial (cantidades reales y motivo) o no
realizado (cantidades cero y motivo). Los GIF se resuelven desde gifPath y se
cargan sin JWT desde el repositorio público. Las rutinas se agrupan por fecha.
Perfil → Historial de planes usa `GET /users/me/plans` y abre cada versión
con `GET /users/me/plan/{id}`, incluidas las reemplazadas.
Cada ejercicio ofrece «Ver instrucciones» (`GET /catalog/exercises/{id}`).

Reglas de ejecución copiadas del backend (`workout_rules.dart`): solo se puede
comenzar en vivo un entrenamiento SCHEDULED/IN_PROGRESS antes de `expiresAt`.
El registro retrospectivo se permite salvo en COMPLETED, PARTIAL o REPLACED,
de modo que un SKIPPED por vencimiento todavía puede registrarse. En un
ejercicio DURATION, «Lo completé» envía series × segundos, que es el
denominador del backend; antes enviaba solo los segundos de una serie y el
servidor lo marcaba como parcial.
Las métricas se muestran con su fecha de
cálculo; no se inventan cálculos nuevos después de una sesión.

Recuperación de contraseña (`PasswordResetController`): «¿Olvidaste la clave?»
llama a `POST /auth/password-reset/request` con el correo y luego
`POST /auth/password-reset/confirm` con `{token, newPassword}`. El código es
un token de 43 caracteres, no un PIN. El backend todavía no envía correos:
solo lo escribe en el log con `fitsense.password-reset.delivery=dev-log`.

## Novedades de generation que usa la app

- Entrenamientos con `safetyBlocked`: se muestra `safetyBlockMessage` y no se
  puede iniciar. Un ejercicio con `safetyBlockReason` solo se registra como
  «No lo hice», en vivo o en el registro retrospectivo.
- Omitir por falta de tiempo pide, de forma opcional, `lackOfTimeContext`
  (IMPREVISTO, SIN_TIEMPO_ESE_DIA, MENOS_TIEMPO_HABITUAL + `availableMinutes`).
- Progreso muestra la cobertura de registro de V30 (`recordedWorkouts`,
  `registrationCoveragePct`, `observedAdherencePct`). La tarjeta «Adaptación»
  usa `GET /users/me/plan/adaptations` (`resultado`); sin ese dato, las
  intervenciones distintas de NONE.
- Rutinas muestra `GET /users/me/plan/limitations` cuando hay limitaciones.
- Perfil → Ejercicios excluidos por dolor (`GET /users/me/pain-exclusions`)
  permite pedir la reactivación con confirmación explícita.

## Sesión y estudio

El JWT dura 7 días: al abrir la app se valida con `GET /users/me` y, si es
válido, se entra sin pedir credenciales. Solo un 401 borra el token; un fallo
de red o un 5xx lo conserva. En Perfil → Cuenta se muestra la participación en
el estudio y, si corresponde, «Retirarme del estudio» (`POST /users/me/withdraw`).

Los errores muestran `message` y la lista `details` de `ApiErrorResource`.

## Prueba de servidor

Se creó la cuenta sintética `kora.test.1793199312@example.com` (userId 28), sin
participación en el estudio. Se verificaron registro, login, JWT, /users/me,
catálogo (31 equipos), POST/GET/PUT del perfil y rechazo sin token. El perfil
de prueba se dejó en el servidor; no se guardaron contraseña ni JWT en archivos.

Pruebas del cliente:

`test/backend_alignment_test.dart` compara cada llamada de la app con las
rutas de los controladores del backend y usa fixtures con los campos reales de
sus recursos.

```powershell
.\tmp\flutter-sdk\bin\flutter.bat test --no-pub test/backend_alignment_test.dart test/backend_contract_test.dart test/onboarding_flow_test.dart test/profile_edit_test.dart
.\tmp\flutter-sdk\bin\flutter.bat test --no-pub --concurrency=1 test/dashboard_live_test.dart test/account_setup_test.dart
```

## Datos de prueba de adherencia

`docs/sql/seed_adherencia_demo.sql` crea el usuario
`adherencia.demo@example.com` / `Kora2026!` con 7 semanas cerradas y la semana
actual en curso (fechas relativas a `CURRENT_DATE`). Las métricas se calculan
desde las sesiones insertadas con las reglas de `WeeklyMetricsCalculator`
(rama generation: promedio simple por entrenamiento, config activa) y hay una intervención por semana, como hace el backend.
Es idempotente: al volver a ejecutarlo recrea solo a ese usuario.

```bash
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f docs/sql/seed_adherencia_demo.sql
psql "$DATABASE_URL" -f docs/sql/verify_adherencia_demo.sql
```

`verify_adherencia_demo.sql` muestra, por pantalla de la app, lo que se debe
ver (Progreso, Resumen de ajustes, Historial de planes, semana actual) y
recalcula la adherencia semanal desde las sesiones para comprobarla.
`test/adherence_history_test.dart` valida la pestaña Progreso con esos mismos
datos exportados en `test/fixtures/adherencia_demo.json`.

## Recordatorios (notificaciones locales)

No dependen del backend: la app los calcula a partir del plan vigente con
`flutter_local_notifications` y los programa en el teléfono.

- Por cada entrenamiento SCHEDULED/IN_PROGRESS no bloqueado por seguridad:
  «Hoy toca: …» a la hora elegida (por defecto 08:00) y «Tu entrenamiento
  vence hoy» a las 20:00, antes del `expiresAt` de las 23:59.
- La hora se interpreta en la zona horaria del usuario (`timezone` de
  `/users/me`), la misma que usa el backend para las fechas del plan.
- Se reprograman cada vez que el plan se recarga: al registrar u omitir un
  entrenamiento, sus avisos desaparecen. Al cerrar sesión se cancelan todos.
- La primera vez que hay plan se pide el permiso (Android 13+ e iOS). Si se
  niega, quedan desactivados y se pueden activar en Perfil → Recordatorios.
- Plan de la semana siguiente: el backend lo genera el lunes aunque la app
  esté cerrada, y la app solo conoce el último plan que descargó. Por eso se
  programa «Tu plan de esta semana está listo» el lunes posterior al fin del
  plan y «Aún no revisas tu plan de esta semana» el miércoles, a la hora
  elegida. Al abrir la app se descarga el plan nuevo y se reemplazan todos
  los avisos, estos dos incluidos, así que la cadena no se corta. Tocar uno
  de estos avisos abre Inicio; tocar el de un entrenamiento abre Rutinas.
- Android usa alarmas inexactas (no requiere `SCHEDULE_EXACT_ALARM`) y
  reprograma tras reiniciar el teléfono. «Forzar detención» desde Ajustes o
  el ahorro de batería de algunos fabricantes pueden cancelar o retrasar los
  avisos hasta que se abra la app. En web y escritorio no hacen nada.
