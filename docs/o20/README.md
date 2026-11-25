# O20 en el Mobile: exclusiones por dolor y bloqueos de seguridad

Rama `claude/o20-exclusiones-dolor`, creada desde `generation` (`abe5e3d`). Backend de referencia: `generation` con la PR #84 (O20), compilado de `98276a9`.

El Backend decide qué se excluye, por qué y hasta cuándo. La app lee esa información, la explica sin códigos técnicos y no decide nada por su cuenta:

- ninguna exclusión desaparece porque cambie lo que se ve en pantalla;
- ninguna exclusión desaparece porque pasen dos semanas;
- tras cualquier acción, la app vuelve a leer el estado del Backend.

No cambia la generación, la progresión, la reincorporación, D-M1, Firebase ni la autenticación.

## Qué ve el usuario

| Dónde | Qué | Captura |
|---|---|---|
| **Rutina abierta** | El ejercicio bloqueado aparece como «No disponible por ahora», con el motivo y la indicación de que solo puede registrarse como no realizado. El resto de la rutina sigue como siempre. | `capturas/01-rutina-con-ejercicio-bloqueado.png` |
| **Registrar un ejercicio bloqueado** | Solo se puede marcar «No lo hice». Si el motivo es dolor, se muestra el aviso «Si te duele, detén este ejercicio…». | `capturas/02-registro-solo-como-no-realizado.png` |
| **Perfil → Exclusiones por dolor** | Las peticiones pendientes de confirmación, en tres grupos: «Te dolieron», «En una sesión con dolor (sin indicar cuál)» y «También evitamos, por ser el mismo movimiento». «Ya no me duele» aparece solo si el Backend lo permite (`canReactivate`). Abajo, el historial. | `capturas/03-perfil-exclusiones-por-dolor.png` |
| **Confirmación de dolor** | Pregunta qué ejercicio dolió y cuáles no tuvieron que ver (opcional). El ejercicio que dolió no puede marcarse como no relacionado. | `capturas/04-confirmacion-de-dolor.png` |
| **Resultado de la confirmación** | Qué vuelve a proponerse, qué no se levantó (con el motivo del Backend), qué sigue excluido y la nota del Backend. | `capturas/05-confirmacion-resultado.png` |
| **Inicio** | Kora pregunta activamente solo cuando el Backend lo pide (`confirmationRequired`, tras dos semanas con plan). Las peticiones anteriores aparecen solo en Perfil. También avisa si una adaptación fue NO_FACTIBLE. | `capturas/06-inicio-avisos-o20.png` |

Las capturas usan datos simulados con la forma exacta de las respuestas del Backend y nombres vistos en la prueba real. Se generan con:

```bash
KORA_CAPTURAS=docs/o20/capturas FLUTTER_ROOT=<sdk> flutter test test/screenshots/o20_capturas_test.dart
```

### Flujos

1. **Omitir una rutina por dolor** (`PAIN_OR_DISCOMFORT`):
   - la app vuelve a leer el plan, las exclusiones y las peticiones;
   - muestra «Gracias por avisar» con «Más tarde» / «Indicar ahora»;
   - «Indicar ahora» abre la confirmación.
2. **Confirmar el dolor**:
   - `POST …/{id}/identification` con `unrelatedExerciseIds`;
   - se muestra el resultado y, con éxito o con error, se vuelve a leer todo: exclusiones, peticiones, plan y adaptaciones.
   - Un 400, 422 o 404 se muestra tal cual y no se da nada por levantado.
3. **Registrar trabajo en un ejercicio bloqueado**:
   - la app no lo permite;
   - si el Backend responde 422 `SESION_BLOQUEADA_POR_SEGURIDAD` (por ejemplo, porque el bloqueo llegó con la rutina abierta), se explica, se relee el plan y la sesión, y se descartan los borradores con trabajo en ejercicios ahora bloqueados.
4. **Rutina abierta o app reabierta**: al abrir, la rutina vuelve a leer el plan actual en segundo plano.
   - Si la rutina ya no forma parte del plan, se avisa y no se puede editar.
   - Los registros vienen de la sesión del Backend, sin duplicados.
5. **Reactivación** («Ya no me duele»):
   - `POST …/{id}/reactivation`;
   - si el Backend la rechaza (422), se muestra el motivo y la exclusión sigue.
6. **Adaptación NO_FACTIBLE**: «Kora no ha podido adaptar esa parte del entrenamiento debido a las restricciones actuales.», más el `motivoTexto` del Backend. No se inventan sustitutos.

## Contratos del Backend usados (sin endpoints ni campos inventados)

| Endpoint | Uso |
|---|---|
| `GET /users/me/pain-exclusions/effective` | Qué no se prescribe hoy y por qué. Campos: `origin` (DIRECT / EQUIVALENT / PRECAUTION), `confirmed`, `provisional`, `confirmationRequired`, `derivedFromExercise{Id,Name}`, `sourcePlannedWorkoutId`, `eventDate`, `canIdentify`, `canReactivate`. |
| `GET /users/me/pain-exclusions/confirmation-requests` | Sesiones con dolor sin identificar: `plannedWorkoutId`, `eventDate`, `confirmationRequired`, `exercises[{exerciseId, exerciseName}]`. |
| `POST /users/me/pain-exclusions/{exerciseId}/identification` | Cuerpo: `{confirmPain: true, plannedWorkoutId, unrelatedExerciseIds?}`. Respuesta: `exclusionesConfirmadas`, `identificadaEn`, `equivalentesExcluidos`, `noRelacionadosLevantados`, `noRelacionadosNoLevantados` (id → motivo), `otrosDeLaSesionSiguenExcluidos`, `nota`. |
| `POST /users/me/pain-exclusions/{exerciseId}/reactivation` | Sin cambios de contrato. Ahora se ofrece solo si `canReactivate`. |
| `GET /users/me/pain-exclusions` | El historial (ya existía). |
| `GET /users/me/plan/current` | Releído al abrir la rutina y tras el dolor. Por prescripción: `safetyBlockReason` (`dolor_registrado` y restricciones del perfil, unidas con `+`); por rutina: `safetyBlocked`. |
| `PUT /sessions/{sessionId}/exercises/{plannedExerciseId}` | Un 422 `SESION_BLOQUEADA_POR_SEGURIDAD` se explica y lleva a releer el plan y la sesión. |
| `GET /users/me/plan/adaptations` | `resultado` NO_FACTIBLE / NO_FACTIBLE_POR_SEGURIDAD y `motivoTexto`. |

## Pruebas

### Los 12 escenarios (`test/pain_o20_test.dart`, 20 pruebas)

| # | Escenario | Prueba |
|---|---|---|
| 1 | Ejercicio bloqueado por dolor | `1 · exercise blocked by pain` |
| 2 | Variante equivalente excluida (y la provisional nunca dice «te dolió») | `2 · equivalent variant excluded` y `2 · a provisional equivalent…` |
| 3 | Precaución por cambio de ángulo | `3 · precaution for a change of angle (provisional)` |
| 4 | Rutina con ejercicios bloqueados y permitidos | `4 · blocked and allowed in one session…` |
| 5 | Dolor sin ejercicio identificado | `5 · skipping for pain re-reads the plan and offers…` |
| 6 | Identificación posterior | `6 · later identification of the exercise that hurt` |
| 7 | Ejercicios no relacionados (y la validación previa) | `7 · the ones that had nothing to do with it…` y `7 · the same rule before sending…` |
| 8 | Error 422 (sesión y confirmación) | `8 · a 422 SESION_BLOQUEADA_POR_SEGURIDAD…` y `8 · a 422 from /identification…` |
| 9 | Exclusión vigente tras dos semanas | `9 · after two weeks the exclusion is still there…` y `an early request is listed in Perfil but not pushed on Inicio` |
| 10 | Reactivación autorizada / rechazada | `10 · reactivation the backend authorizes…` y `10 · a reactivation the backend refuses (422)…` |
| 11 | NO_FACTIBLE | `11 · adaptation NO_FACTIBLE…` |
| 12 | Recuperación al reabrir la app | `12 · reopening the app…` |

Además: lectura exacta de los contratos (`/effective`, `/confirmation-requests`, `/identification`) y combinación de dolor con restricciones del perfil. `test/backend_alignment_test.dart` cambia una expectativa a propósito: antes se mostraba el código crudo («No es seguro para ti: suelo»); ahora, «No disponible por ahora. No es compatible con lo que indicaste en tu perfil (trabajo en el suelo).».

### Backend real con datos sintéticos (`test/live/pain_o20_live_test.dart`)

Configuración:

- Backend `generation` (`98276a9`) en local;
- base aislada `fitsense_o20`, IA apagada (motor de reglas), sin push ni Internet (`evidencia/backend-local.sh`);
- dos cuentas sintéticas, una en casa y otra en gimnasio (`evidencia/cuenta-*.sh`).

La prueba usa los repositorios reales de la app. Salidas: `evidencia/backend-real-casa.txt` y `evidencia/backend-real-gimnasio.txt`.

Se comprobó:

- Omisión por dolor → todos los ejercicios de la sesión pasan a DIRECT sin confirmar. En gimnasio, además, 3 EQUIVALENT provisionales.
- `/confirmation-requests` lista la sesión con `confirmationRequired=false` recién omitida.
- Plan releído: las prescripciones con `dolor_registrado` son exactamente las de `/effective`, y `safetyBlocked` sigue en false: un ejercicio no bloquea la rutina entera.
- Registrar trabajo en un ejercicio bloqueado → 422 `SESION_BLOQUEADA_POR_SEGURIDAD`; registrarlo como no realizado → 200; un ejercicio permitido → 200.
- Identificar un ejercicio y marcarlo a la vez como no relacionado: la app lo impide, y el Backend responde 422.
- Identificar con un no relacionado → 200: se levanta solo ese y el resto sigue excluido. Repetir la identificación → 404.
- Reactivación → 200: el ejercicio y sus derivados salen de `/effective`.

```bash
KORA_LIVE_API_BASE_URL=http://localhost:8080/api/v1 KORA_LIVE_EMAIL_A=... KORA_LIVE_PASSWORD=... flutter test test/live/pain_o20_live_test.dart
```

## Pendientes y límites

- El dolor marcado en un ejercicio durante la sesión (`skipReason` PAIN) pasa a DIRECT confirmado (`DOLOR_IDENTIFICADO`) en el cierre semanal del Backend, no en el momento. La app muestra lo que el Backend devuelve en cada lectura.
- Sin prueba en dispositivo físico ni emulador en esta orden: solo pruebas de widgets y la prueba real contra el Backend local.
- La prueba real no llega a `confirmationRequired=true`, porque necesita dos semanas con plan. Ese caso está cubierto con datos simulados (escenario 9).
- En las capturas, el texto de los botones rellenos se dibuja con Poppins. En el dispositivo usa la fuente del sistema, porque el tema no la fija; esto no se cambió.
