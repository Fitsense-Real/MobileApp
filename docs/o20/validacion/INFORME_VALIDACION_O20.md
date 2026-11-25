# Validación final O20 en Flutter (PR #19)

**Contexto:**

| | |
|---|---|
| Rama | `claude/o20-exclusiones-dolor`, sobre `generation` `abe5e3d` (incluye las PR #17 y #18) |
| Backend de referencia | `generation` `98276a9`, con #84 (O20 + V65) y #83 (gpt-5-mini). Se ejecutó en local con la IA apagada |
| Bases aisladas | `fitsense_val` (cuentas sintéticas) y `fitsense_demo` (copia del dataset Demo Kora) |
| Recursos externos | No se usó Replicate ni OpenAI. No se hizo ningún despliegue. No se tocó ninguna base real |

**Conclusión: VALIDACIÓN INCOMPLETA** (ver §10).

- Todo lo que se pudo ejecutar está aprobado: los 12 escenarios en pruebas automáticas, los escenarios 1 y 4–12 completos contra el Backend real (el 9 y el 11 con dos cierres semanales reales), y los escenarios 2 y 3 en parte.
- Faltan cosas que este entorno no permite probar:
  - un teléfono Android físico;
  - el usuario 48 en tu base;
  - para los escenarios 2 y 3, ver una variante bloqueada dentro de una rutina abierta. El generador real no coloca variantes del mismo ejercicio en la misma semana;
  - `REACTIVACION_RECHAZADA_POR_SEGURIDAD`, que no se puede producir con flujos reales.

## 1. Verificaciones iniciales

| Verificación | Resultado |
|---|---|
| `generation` actualizado en Mobile y en Backend | Mobile `abe5e3d`; Backend `98276a9` |
| Mobile incluye las PR #17 y #18 | Sí: `a7516b2` y `abe5e3d` son ancestros de la rama, que tiene 0 commits por detrás de `generation` |
| Backend con O20, V65 y gpt-5-mini | Sí: `V65__dolor_identificacion_posterior.sql`, `PainExclusionController` con `/effective`, `/confirmation-requests` e `/identification`, y `fitsense.ai.model=gpt-5-mini`. Flyway aplicó las migraciones hasta la V65 en las dos bases |
| `ESPEC_MOBILE_EXCLUSIONES.md` | Revisada. Se usan solo sus campos y rutas. Los textos evitan «diagnóstico», «lesión» y «para siempre» (comprobado con grep) |
| PR #19: CI y conflictos | CI `verify` en verde y `mergeable_state=clean` en `c84e22c`. Los commits de esta validación se verifican en §8 |
| Archivos ajenos a O20 | Ninguno. Los 25 archivos de `c84e22c` y los de esta validación (§9) son de O20 o pruebas de O20 |

## 2. Los doce escenarios

**Columnas:**

- **Real:** contra el Backend local, con los repositorios reales de la app (`test/live/o20_validacion_live_test.dart` y `o20_dos_semanas_live_test.dart`).
- **Widget:** pantalla real de Flutter con respuestas que tienen la forma exacta del Backend (`test/pain_o20_test.dart`).
- **Evidencia:** está en `evidencia/` y `capturas/`.

| N.º | Escenario | Datos iniciales | Acción | Endpoint | Respuesta del Backend | Flutter | Real | Widget |
|---|---|---|---|---|---|---|---|---|
| 1 | Ejercicio bloqueado por dolor | Cuenta A (casa); sesión 37 omitida por dolor | Releer el plan | `GET /plan/current` | La prescripción 276, «Gancho de izquierda (boxeo)», llega con `safetyBlockReason=dolor_registrado` y `safetyBlocked=false` | «No disponible por ahora. Estaba en una sesión en la que reportaste dolor sin indicar qué ejercicio fue.» | **Aprobado** | Aprobado |
| 2 | Variante equivalente excluida | Cuenta eq2 (gimnasio): sesión omitida por dolor | Leer las exclusiones; reactivar la variante | `GET /effective`, `POST …/13/reactivation` | `EQUIVALENT 13 «Escaladores»`, de 1054 «Escalador», `VARIANTE_MISMO_EJERCICIO`, provisional, `canReactivate=false`. Reactivar → 404 | «Es una variante de «Escalador», de la sesión en la que reportaste dolor, mientras confirmamos qué te dolió.» No hay botón de reactivar | **Aprobado (parcial):** en 10 cuentas, ninguna rutina abierta repetía una variante | Aprobado, incluido el bloqueo en rutina |
| 3 | Precaución por ángulo | Cuenta eq0 (gimnasio) | Igual que el 2 | Igual que el 2 | `PRECAUTION 899 «Flexión de escápula en banco inclinado»`, de 1138, `PRECAUCION_OTRO_ANGULO`. Reactivar → 404 | «Es el mismo movimiento que «Flexión de escápula», con otro ángulo o apoyo, mientras confirmamos qué te dolió.» | **Aprobado (parcial),** igual que el 2 | Aprobado |
| 4 | Sesión con permitidos y bloqueados | Cuenta A, entrenamiento 38 | Registrar el bloqueado completo, parcial y no realizado; luego los permitidos; finalizar | `PUT /sessions/2/exercises/{pe}`, `POST …/finish` | Completo → 422 `SESION_BLOQUEADA_POR_SEGURIDAD`; parcial (1×3) → 422; no realizado → 200; permitidos → 200; finalizar → `PARTIAL` 75 %, con 8 registros, uno por ejercicio | Para el bloqueado solo se ofrece «No lo hice»; el resto se registra normal | **Aprobado** | Aprobado |
| 5 | Dolor sin ejercicio identificado | Cuenta A, plan de la semana del 30/11 | Omitir por dolor | `POST /workouts/37/skip`, `GET /confirmation-requests` | La sesión 37 aparece con 8 ejercicios, `confirmationRequired=false`; en `/effective`, 8 DIRECT sin confirmar | «Gracias por avisar», con «Más tarde» / «Indicar ahora» | **Aprobado** | Aprobado |
| 6 | Identificación posterior | Cuenta A, petición de la sesión 37 | «Fue este»: 507 | `POST /pain-exclusions/507/identification` | 200; 507 queda `confirmed=true` y `canIdentify=false` | «Lo marcaste con dolor.» y el resumen de la confirmación | **Aprobado** | Aprobado |
| 7 | Ejercicios no relacionados | Cuenta A | Marcar 1118 y 1179 como no relacionados | Igual que el 6 | Cuerpo enviado: `{"confirmPain":true,"plannedWorkoutId":37,"unrelatedExerciseIds":[1118,1179]}`. Levantados `[1118, 1179]`; siguen excluidos `[853, 973, 1066, 1075, 1097]` | «Vuelven a poder proponerse» y «Siguen sin proponerse» | **Aprobado** | Aprobado |
| 8 | Respuestas 422 | Cuenta A | Trabajo en un bloqueado (en vivo y retroactivo); el identificado también como no relacionado; un no relacionado de otra sesión; identificar dos veces | `PUT /sessions/…`, `POST /workouts/38/report`, `…/identification` | 422 `SESION_BLOQUEADA_POR_SEGURIDAD` (en vivo y retroactivo; nada queda registrado); 422 «no puede ser a la vez no relacionado»; 422 «no esta pendiente de confirmar en esa sesion»; 404 al repetir | Explica el problema sin códigos y relee el plan y la sesión. La app rechaza antes de enviar las respuestas inválidas | **Aprobado** | Aprobado |
| 9 | Exclusión provisional tras dos semanas | Cuenta s9 (gimnasio): sesión 49 del 30/11 omitida por dolor (7 ejercicios, 12 exclusiones) | Dos cierres semanales reales (07/12 y 14/12) | `GET /confirmation-requests`, `/effective`, `/plan/current` | Tras 1 semana con plan: `confirmationRequired=false`. Tras 2 semanas: `true`, con 7 DIRECT `confirmationRequired=true`. Siguen las 12 exclusiones y los planes del 07/12 y del 14/12 no prescriben ninguna | Inicio: «¿Recuerdas qué ejercicio te dolió el 30/11/2026?». Perfil: la petición resaltada y todo sigue excluido (capturas R5 y R6) | **Aprobado** | Aprobado |
| 10 | Reactivación autorizada | Cuenta A, 507 confirmado | «Ya no me duele»; también sin confirmación explícita y sobre un derivado | `POST …/507/reactivation` | 200 (`candidatoHoy=true`); sale de `/effective` junto con sus derivados. Sin confirmación (`confirmNoPain=false`) → 422; derivado → 404; sigue excluido | El botón aparece solo si `canReactivate`; tras la respuesta se relee todo | **Aprobado.** El rechazo `REACTIVACION_RECHAZADA_POR_SEGURIDAD` solo se probó con widget (§10) | Aprobado (autorizada y rechazada) |
| 11 | Adaptación `NO_FACTIBLE` | Cuenta A tras los escenarios 1–10 | Cierre semanal real del 07/12 | `GET /plan/adaptations`, `/plan/current` | `resultado=NO_FACTIBLE_POR_SEGURIDAD`, `estado=NO_FACTIBLE`, `motivoTexto` «No pudimos preparar una alternativa segura para la sesión en la que registraste molestias.»; `/plan/current` → 404 | «Kora no ha podido adaptar esa parte del entrenamiento debido a las restricciones actuales. No vuelve a proponer lo que te dolió ni lo sustituye por algo que no sea seguro. No pudimos preparar…» (captura R7). No se inventa un sustituto | **Aprobado** | Aprobado |
| 12 | Cerrar y volver a abrir | Cuenta A tras los escenarios 1–8 | Nuevo inicio de sesión (Dio y repositorios nuevos) | `/effective`, `/plan/current`, `/plans` | Las mismas 9 exclusiones; el entrenamiento 38 sigue `PARTIAL`; las 2 prescripciones abiertas siguen bloqueadas | Al reabrir, la rutina se relee y los registros vienen del Backend, sin duplicados | **Aprobado** | Aprobado |

## 3. Escenarios 9 y 11: dos cierres semanales reales

**Cómo pasaron las semanas.** Se reinició el Backend de `fitsense_val` con su reloj adelantado (libfaketime, solo en ese proceso):

1. lunes 07/12, 07:27:30 UTC;
2. lunes 14/12, 07:27:30 UTC.

En cada arranque, las tareas programadas reales hicieron lo mismo que en producción:

- la de vencimiento (:30) cerró 33 entrenamientos vencidos;
- a las 08:00 UTC (03:00 en Lima), `WeeklyCycleScheduler` cerró la semana de los 18 participantes sintéticos con el motor de reglas (IA apagada).

No se escribió nada a mano en la base.

**Escenario 9** (`evidencia/backend-real-cierre1-07dic.txt` y `backend-real-cierre2-14dic.txt`):

- **Antes:** sesión 49 del 30/11 omitida por dolor; `confirmationRequired=false`; 12 exclusiones (7 directas y 5 derivadas).
- **Tras el cierre del 07/12** (una semana con plan después del dolor): `confirmationRequired=false`. Siguen las 12 y el plan nuevo `27` no prescribe ninguna.
- **Tras el cierre del 14/12** (dos semanas): `confirmationRequired=true` en la petición y en las 7 directas. Siguen las 12 y el plan `43` no prescribe ninguna. **Nada se desbloqueó por el paso del tiempo.**
- **En la app:** la tarjeta de Inicio aparece solo con `confirmationRequired=true` (captura R5).
- **Derivadas:** los planes del 14/12 de las cuentas con equivalentes y precauciones (899 PRECAUTION; 13 y 957 EQUIVALENT) no prescriben ninguna de ellas (`evidencia/backend-real-derivadas-plan-nuevo.txt`).

**Escenario 11** (`evidencia/backend-real-no-factible.txt`, `cierre1-intentos-adaptacion.txt` y `cierres-resumen-intentos.txt`):

- El cierre del 07/12 dejó 9 intentos `NO_FACTIBLE`:
  - 3 `DOLOR_SIN_RESOLUCION_SEGURA`, entre ellos la cuenta A;
  - 6 `SEMANA_NO_VALIDA`.
- La API devolvió a la cuenta A `NO_FACTIBLE_POR_SEGURIDAD` con `motivoTexto`, y la app lo explicó sin códigos.
- El Backend no publicó semana (404) y la app no inventó una: el aviso de Inicio es la captura R7.
- **Cuenta s11** (todas sus sesiones omitidas por dolor): el intento fue `NO_FACTIBLE`, pero la API lo publica como `REGENERACION_SEGURA_REGLAS`, porque la regeneración segura inmediata ya había publicado su semana. La app no lo muestra como no factible: sigue lo que dice el Backend.

## 4. Mobile no puede saltarse O20

| N.º | Comprobación | Cómo se demostró | Resultado |
|---|---|---|---|
| 1 | Un bloqueado no se marca como completado | Widget: solo se ofrece «No lo hice». Real: completo → 422 | Aprobado |
| 2 | No se registra parcialmente si el Backend lo prohíbe | Real: parcial (1 serie, 3 repeticiones) → 422. Widget: no se ofrece «Lo hice parcialmente» | Aprobado |
| 3 | Una rutina en caché no permite ejecutar lo bloqueado después | **Corrección C1.** La rutina se relee al volver del segundo plano. **Corrección C2.** El registro retroactivo relee el plan antes de enviar y descarta borradores con trabajo. Real: el envío retroactivo y el registro en vivo con trabajo → 422 | Aprobado, con regresiones nuevas |
| 4 | Tras reportar dolor se relee el plan vigente | Widget (escenario 5) y real (escenario 1) | Aprobado |
| 5 | Un 422 obliga a recuperar el estado | Widget (escenario 8): relee el plan y la sesión, y se ve el bloqueo. Real: los 422 de §2 | Aprobado |
| 6 | Las exclusiones no desaparecen al cerrar sesión, reiniciar o cambiar de pantalla | Widget nuevo: cerrar sesión y volver a entrar las relee del Backend y siguen ahí. Real: escenario 12. No hay caché local: todo es en memoria y se relee | Aprobado |
| 7 | Los equivalentes y las precauciones conservan su restricción | Real: escenarios 2 y 3, y en las rutinas abiertas toda prescripción derivada estaba bloqueada. Escenario 9: el plan nuevo no prescribe nada de `/effective` | Aprobado |
| 8 | No hay reactivaciones locales sin el Backend | La app solo llama a `/reactivation` y relee. Widget nuevo: sin botón en equivalentes, precauciones ni `canReactivate=false`. Real: derivado → 404; sin confirmación → 422 | Aprobado |
| 9 | Las confirmaciones inválidas se rechazan y se informa | `identificationProblem` antes de enviar; real: 422 y 404 (escenario 8) | Aprobado |
| 10 | Se conserva el historial | Real: el entrenamiento 38 sigue `PARTIAL` tras identificar, reactivar y volver a entrar. Demo: 4 planes con sus estados reales | Aprobado |

## 5. Usuario Demo Kora

- **Tu usuario 48 no se pudo verificar:** no tengo acceso a tu PostgreSQL ni a Railway.
- **Copia local:** cargué el dataset de `feature/dataset-demo-kora` (`19ba896`) en una base aislada:
  - registro por la API y scripts 01–05;
  - cuenta sin participación en el estudio, como exige su README; el script 01 aborta con una cuenta participante.
- **`06_VERIFICACION.sql`:** las 10 comprobaciones dan `ok = t` y la adherencia recalculada coincide en las 3 semanas (`evidencia/demo-06_verificacion.txt`).
- **Lectura solo con GET** (la prueba falla si la app envía otra cosa; `evidencia/demo-kora.txt`):
  - `/effective`: `DIRECT 1025 «Aperturas de pecho sentado con palanca»`, confirmado → «Lo marcaste con dolor.»;
  - plan vigente `910000003`, sin el 1025 y sin prescripciones bloqueadas;
  - `/plans`: 4 planes. W-3 queda con 3 completados, 1 parcial y 1 omitido; W-2 y W-1, completos;
  - `/plan/adaptations`: `REGENERACION_SEGURA_SUSTITUCION`, `SIN_ADAPTACION` y `PROGRESION_DEL_BACKEND`.
- **Captura:** `capturas/R1-demo-perfil-exclusion.png`.
- **No se hizo nada más con esta cuenta:** ni generación, ni cierre, ni registros, ni modificaciones.

**Para tu base**, comprueba antes de la demostración:

1. Ejecuta `06_VERIFICACION.sql` sobre el usuario 48: las 10 filas deben dar `ok = t`.
2. Pídele `GET /users/me/pain-exclusions/effective`: debe salir solo el 1025, confirmado.
3. **Discrepancia:** dices que el usuario 48 participa en el estudio, pero el README del dataset exige registrarlo **sin** participación. Con participación, el cierre semanal de los lunes podría generar otro plan (con coste) y alterar la demo. Comprueba `is_study_participant` (consulta 1 de 06).

## 6. Pruebas automáticas

- `flutter analyze`: sin problemas.
- `flutter test`: 374 aprobadas, 0 fallidas, 26 omitidas. Las omitidas son las de Backend real y capturas, que necesitan variables de entorno y se ejecutaron aparte (§2–§5).
- Nombres de las pruebas de seguridad: `evidencia/pruebas-seguridad-o20.txt`.
- **Pruebas de seguridad O20,** en `test/pain_o20_test.dart` (24 pruebas):
  - las 20 de los 12 escenarios;
  - 4 regresiones nuevas de esta validación:
    - volver del segundo plano relee la rutina;
    - el registro retroactivo preparado sobre una copia vieja no se envía;
    - cerrar sesión y volver a entrar relee las exclusiones;
    - sin reactivación para equivalentes, precauciones ni `canReactivate=false`.
- **Las dos correcciones se comprobaron a la inversa:** sin ellas, las dos regresiones correspondientes fallan.

## 7. Firebase, D-M1 y generación

Resultados por grupo en `evidencia/regresiones-firebase-dm1-generacion.txt`.

| Grupo | Archivos | Resultado |
|---|---|---|
| **Firebase y sesión:** registro del dispositivo, permisos, notificaciones, sesiones autenticadas, desvinculación al cerrar sesión (`DELETE` con el FID antes de `unregister`) | `push_notifications`, `push_permission`, `push_early_registration`, `push_first_plan_prompt`, `session_expiry`, `auth_social_cleanup`, `android_identifier` | 94 aprobadas, 0 fallidas |
| **D-M1:** sesiones completas y parciales, duración por tiempo (3×120 s = 360 s; parcial de 150 s), un parcial igual al 100 % pide «Lo completé», cronómetro y minutos activos | `timed_exercise_results`, `exercise_results`, `session_timer` | 28 aprobadas, 0 fallidas |
| **Generación y adaptación:** plan vigente, historial, generación asíncrona, resultados de adaptación, `NO_FACTIBLE` | `first_plan_generation`, `generation_screen`, `plan_week_label`, `dashboard_live`, `backend_alignment`, `backend_contract`, `adherence_history` | 104 aprobadas, 0 fallidas |

- **Generación real:** en el Backend real, las cuentas sintéticas generaron su primer plan con `POST /users/me/plan/generation` (motor de reglas) y el plan se leyó una sola vez por cuenta.
- **D-M1 en real:** la sesión del escenario 4 terminó `PARTIAL` 75 %, con un registro por ejercicio.
- **Sin cambios:** O20 no toca Firebase, la autenticación, la generación ni la política de D-M1. La app no cambió ninguna regla del Backend.

## 8. Resultados finales

| Verificación | Resultado |
|---|---|
| `flutter analyze` | Sin problemas |
| `flutter test` | **374 aprobadas, 0 fallidas**, 26 omitidas |
| Pruebas de Backend real (`test/live/o20_validacion_live_test.dart`) | 4 de 4 aprobadas (escenarios 1–8, 10 y 12) |
| Dos cierres semanales reales (`test/live/o20_dos_semanas_live_test.dart`) | `prepare`, `check1` y `check2` aprobadas |
| Grabación de respuestas reales y capturas | Demo (solo GET), sintética, cuenta no factible y s9: aprobadas; 7 capturas |
| CI de GitHub | En la PR #19, sobre el último commit (ver el comentario de la PR) |

**Capturas con respuestas reales del Backend** (`capturas/`):

- R1: Demo Kora, Perfil;
- R2: rutina con un bloqueado;
- R3: confirmación;
- R4: Perfil con la petición;
- R5: Inicio a las dos semanas;
- R6: Perfil a las dos semanas;
- R7: Inicio con `NO_FACTIBLE`.

Los GIF de los ejercicios no cargan en las capturas porque las pruebas no tienen red.

## 9. Incidencias, correcciones, archivos y commits

**C1 · Rutina abierta tras volver del segundo plano.**

- **Problema:** ni Inicio ni una rutina abierta releían el plan al volver a la app sin cerrarla. Se veía un estado viejo. El Backend igual rechazaba el registro con 422.
- **Corrección:**
  - `lib/app/app.dart`: al volver a primer plano, `refreshPainSafety` relee el plan, las exclusiones, las peticiones y las adaptaciones;
  - `planned_workout_page.dart`: la rutina abierta se relee al volver.

**C2 · Registro retroactivo sobre una copia vieja.**

- **Problema:** los borradores con trabajo, preparados antes de un bloqueo, se enviaban y el Backend los rechazaba con 422.
- **Corrección:** `report()` relee el plan antes de enviar, con un límite de 8 s; si un borrador queda bloqueado, lo descarta y lo explica.

**Ajuste de pruebas por C2.** `test/exercise_results_test.dart` y `test/timed_exercise_results_test.dart` ahora simulan también el repositorio de planes, porque la página lo lee antes de enviar. No cambia ninguna expectativa.

## 10. Limitaciones y pendientes

1. **Android físico:** no hay dispositivo disponible. Guía en `GUIA_ANDROID.md`.
2. **Usuario 48:** solo se verificó una copia local del dataset (§5).
3. **Escenarios 2 y 3 dentro de una rutina abierta:** en 10 cuentas, el generador nunca puso una variante equivalente o una precaución en la misma semana que el ejercicio de origen.
   - Lo que sí es real: la lista, la explicación, que no se puede reactivar, y que donde una derivada aparece en una rutina abierta queda bloqueada (verificado en todas las cuentas).
   - El bloqueo dentro de la rutina se probó con widget.
   - En los cierres reales, los planes nuevos nunca las prescriben.
4. **`REACTIVACION_RECHAZADA_POR_SEGURIDAD`:** requiere que una restricción del perfil aparezca después del dolor, y el Backend no permite cambiar el perfil de un participante con plan (422).
   - Se probó con widget.
   - En real se probaron los otros rechazos: sin confirmación explícita y sobre un derivado.
5. **Reloj de los cierres (escenarios 9 y 11):** las semanas pasaron con el reloj del proceso del Backend adelantado (libfaketime). Los cierres los ejecutaron sus tareas programadas reales; no se escribió nada a mano en la base.
