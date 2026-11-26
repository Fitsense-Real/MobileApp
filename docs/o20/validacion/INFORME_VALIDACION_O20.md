# Validación final O20 en Flutter (PR #19): cierre de seguridad

**Contexto:**

| | |
|---|---|
| Rama | `claude/o20-exclusiones-dolor`, sobre `generation` `abe5e3d` (incluye las PR #17 y #18) |
| Backend de referencia | `generation` `98276a9`, con #84 (O20 + V65) y #83 (gpt-5-mini). Se ejecutó en local con la IA apagada |
| Bases aisladas | `fitsense_val`, `fitsense_val2` (cuentas sintéticas) y `fitsense_demo` (copia del dataset Demo Kora) |
| Recursos externos | No se usó Replicate ni OpenAI. No se hizo ningún despliegue. No se tocó ninguna base real |

**Resultado:**

- **Los 10 criterios de seguridad de la orden están aprobados (§9).** La evidencia viene de pruebas automáticas y del Backend real.
- **La prueba en un teléfono Android físico sigue pendiente** de ejecución por el usuario (§8), igual que la comprobación del usuario 48 en su base (§7).
- **Recomendación (§14):** la PR está lista para la revisión final. Conviene ejecutar antes la guía de Android.

## 1. Los doce escenarios

**Columnas:**

- **Real:** Backend local con los repositorios reales de la app.
- **Widget:** pantalla real de Flutter con respuestas que tienen la forma exacta del Backend, en muchos casos sus mensajes copiados literalmente.
- **Evidencia:** está en `evidencia/` y `capturas/`.

| N.º | Escenario | Real | Widget | Evidencia |
|---|---|---|---|---|
| 1 | Ejercicio bloqueado por dolor | **Aprobado** | Aprobado | `backend-real-escenarios.txt`, R2 |
| 2 | Variante equivalente excluida | **Aprobado**, en una sesión ya abierta (§2) | Aprobado | `backend-real-s2-s3-sesion-abierta.txt`, R8 |
| 3 | Precaución por cambio de ángulo | **Aprobado**, en una sesión ya abierta (§2) | Aprobado | `backend-real-s2-s3-sesion-abierta.txt`, R8, R9 |
| 4 | Sesión con permitidos y bloqueados | **Aprobado** | Aprobado | `backend-real-escenarios.txt` |
| 5 | Dolor sin ejercicio identificado | **Aprobado** | Aprobado | `backend-real-escenarios.txt`, R3, R4 |
| 6 | Identificación posterior | **Aprobado** | Aprobado | `backend-real-escenarios.txt` |
| 7 | Ejercicios no relacionados (`unrelatedExerciseIds`) | **Aprobado** | Aprobado | `backend-real-escenarios.txt` (cuerpo exacto enviado) |
| 8 | Respuestas 422 | **Aprobado** | Aprobado | `backend-real-escenarios.txt` y §4 |
| 9 | Exclusión provisional tras dos semanas | **Aprobado** (dos cierres semanales reales) | Aprobado | `backend-real-cierre1-07dic.txt`, `backend-real-cierre2-14dic.txt`, R5, R6 |
| 10 | Reactivación autorizada / rechazada | **Aprobado,** también el rechazo real (§3) | Aprobado | `backend-real-escenarios.txt`, `backend-real-reactivacion-rechazada.txt`, R10 |
| 11 | Adaptación `NO_FACTIBLE` | **Aprobado** (cierre real) | Aprobado | `backend-real-no-factible.txt`, R7 |
| 12 | Cerrar y volver a abrir | **Aprobado** | Aprobado | `backend-real-escenarios.txt` y §5 |

**Escenarios 9 y 11:** pasaron dos semanas con el reloj del proceso del Backend adelantado (libfaketime). Los cierres los ejecutaron sus propias tareas programadas, sin escribir nada a mano en la base.

## 2. Escenarios 2 y 3: equivalente y precaución en una sesión abierta

**El generador real nunca produce este caso.** En 34 cuentas sintéticas (planes de 3, 5 y 6 días, en casa y gimnasio), ningún plan puso en la misma semana una variante equivalente o una precaución del ejercicio que dolió (`busqueda-coocurrencia.txt`). Por eso, como prevé la orden, preparé una prueba de integración reproducible.

**La semilla:**

- **Plan real:** el del motor de reglas, en la base aislada `fitsense_val2` y para una cuenta sintética.
- **Cambio declarado:** se cambiaron por SQL 4 prescripciones de ese plan (`preparar-cierre.py`, sentencias en la evidencia):
  - la sesión W1 recibe 1054 «Escalador» y 1138 «Flexión de escápula»;
  - la sesión W2 recibe 13 «Escaladores» y 899 «Flexión de escápula en banco inclinado».
- **Lo que no se tocó:** las reglas del Backend, sus políticas y los datos de otras cuentas.
- **Lo que es real:** la omisión por dolor, la derivación, el bloqueo, cada respuesta HTTP y lo que muestra la app.

**El flujo** (`test/live/o20_cierre_live_test.dart`, etapa `equivalentes`):

1. **Primero se abre la sesión de W2:** 13 y 899 están permitidos y se registra un ejercicio.
2. **Se omite W1 por dolor.** `/effective` devuelve:
   - `EQUIVALENT 13` de 1054 (`VARIANTE_MISMO_EJERCICIO`);
   - `PRECAUTION 899` de 1138 (`PRECAUCION_OTRO_ANGULO`);
   - ambas provisionales.
3. **La app relee el plan.** En la sesión abierta, las prescripciones 889 (ejercicio 13) y 890 (ejercicio 899) llegan con `safetyBlockReason=dolor_registrado`. La sesión sigue `IN_PROGRESS` y `safetyBlocked=false`; el resto sigue permitido.
4. **Registros sobre cada una:**
   - completo → 422 `SESION_BLOQUEADA_POR_SEGURIDAD`;
   - parcial (1×4) → 422;
   - no realizado → 200.
5. **Textos en Flutter:**
   - para la equivalente: «No disponible por ahora. Es una variante de «Escalador», de la sesión en la que reportaste dolor, mientras confirmamos qué te dolió.»;
   - para la precaución: «… Es el mismo movimiento que «Flexión de escápula», con otro ángulo o apoyo, mientras confirmamos qué te dolió.».
   - El diálogo de la precaución solo ofrece «No lo hice» (R9). No hay manera de confundirla con una autorización.
6. **Nuevo inicio de sesión:** siguen bloqueadas. La sesión sigue abierta con 3 registros, sin duplicados.
7. **Identificación que no las nombra:** identificar otro ejercicio de W1 como el que dolió, sin nombrar 1054 ni 1138, no levanta nada. 13 y 899 siguen bloqueadas.

**Resultado: aprobado.**

## 3. Reactivación rechazada (`REACTIVACION_RECHAZADA_POR_SEGURIDAD`)

**Cómo se produjo de forma real, sin tocar el usuario 48 ni el perfil:**

- **La cuenta:** sintética y participante, de 59 años, nacida el 01/12/1966. Su plan natural (motor de reglas, sin semilla) incluía el 460 «Flexión pliométrica con toque de pecho», de alto impacto.
- **Antes del cumpleaños:** se omitió por dolor esa sesión.
- **El 02/12/2026:** con el reloj del Backend en esa fecha, la cuenta ya tiene 60 años y el Backend retira el alto impacto a partir de esa edad (`SafetyProfile.EDAD_SIN_IMPACTO`). El perfil de un participante con plan no se puede modificar (422), por eso se usó la edad.

| Comprobación | Resultado |
|---|---|
| 1. El rechazo se muestra bien | Respuesta real: `422 REACTIVACION_RECHAZADA_POR_SEGURIDAD: el ejercicio 460 choca con una restriccion de seguridad vigente (alto_impacto)…`. **La app mostraba ese texto crudo; corregido (C5).** Ahora dice: «Kora no puede volver a proponerte «Flexión pliométrica con toque de pecho» por ahora: no es compatible con una restricción de seguridad vigente (alto impacto). Sigue excluido; tu confirmación no puede levantar esa restricción.» (R10 y prueba con el mensaje literal) |
| 2. Sigue bloqueado | Sigue en `/effective` tras el 422 |
| 3. No aparece como permitido | La fila sigue en Perfil. La app no la quita ni la marca: solo relee |
| 4. Se vuelven a consultar las exclusiones | Prueba widget: `effective()` se vuelve a leer tras la respuesta |
| 5. No se elude por otro flujo | Real: identificar otro ejercicio y declarar el 460 «no relacionado» → `noRelacionadosNoLevantados {460: «choca con una restriccion de seguridad vigente (alto_impacto)»}`; sigue excluido. La app muestra el motivo sin códigos (C5). Los derivados no se pueden reactivar (404) |
| 6. El historial no cambia | Las mismas 7 filas en `/pain-exclusions` (una ahora confirmada) y los mismos planes |

**Resultado: aprobado.**

## 4. Conexión, tiempo de espera y rutina desactualizada

**Regla nueva (C3):** antes de enviar cualquier resultado, la app confirma la rutina con el Backend (`GET /users/me/plan/current`, hasta 8 s). Si no puede confirmarla, no envía nada:

- **La falta de respuesta nunca equivale a «permitido».**
- **El resultado no se pierde:** queda guardado en el teléfono («Pendiente de enviar»), con una explicación y «Reintentar envío».
- **Qué se descarta:** solo lo que ya nunca podrá ser válido, es decir, trabajo en un ejercicio bloqueado después o en uno que salió de la rutina.
- **Registro retroactivo:** se aplica la misma regla y se conservan todos los borradores.

Pruebas en `test/o20_rutina_desactualizada_test.dart` (12):

| N.º | Caso | Comportamiento comprobado |
|---|---|---|
| 1 | Falla la conexión | No se envía; queda pendiente; mensaje claro; «Reintentar envío» lo envía una vez |
| 2 | El Backend tarda más de 8 s | Igual que el caso 1, tras 8 s de espera (simulados) |
| 3 | La consulta devuelve 401 | No se envía; queda pendiente. La sesión caducada la gestiona el manejo global de 401 |
| 4 | La consulta devuelve 422 | No se envía; queda pendiente |
| 5 | El plan del Backend es distinto del que hay en pantalla | Si el ejercicio quedó bloqueado mientras el diálogo estaba abierto: no se envía, se explica, se muestra el bloqueo y solo se ofrece «No lo hice». Si la rutina salió del plan: no se envía y la rutina deja de ser editable. Si la pantalla mostraba un bloqueo que el Backend ya levantó: manda la respuesta del Backend |
| 6 | Se pierde Internet durante el envío | Queda pendiente con «Se perdió la conexión…». El reintento lo envía una vez (PUT reemplaza: sin duplicados) |
| 7 | La app pasa a segundo plano durante la consulta | Un solo diálogo y un solo registro |
| 8 | Dos acciones sobre el mismo ejercicio a la vez | Dos toques en «Registrar ejercicio» → un diálogo y un registro. Dos toques en «Reintentar envío» → un registro |
| — | Registro retroactivo sin red o con más de 8 s | No se envía; se conservan todos los borradores; con la rutina confirmada continúa |

**Prueba a la inversa:** si se quita la regla (es decir, si se envía cuando no hay confirmación), fallan las pruebas 1, 2, 3, 4 y la de reintento.

**Además siguen vigentes:**

- **C1:** se relee al volver del segundo plano, ahora en el widget `PainSafetyResumeRefresher`, que `app.dart` aplica a toda la app y se prueba con la pantalla de Inicio real.
- **C2:** el registro retroactivo descarta borradores inválidos.
- **El Backend sigue siendo la autoridad final:** si el bloqueo llega entre la confirmación y el envío (una carrera), responde 422. La app lo explica y relee (escenario 8, real y widget).

## 5. Comportamiento ante un plan desactualizado

| Situación | Resultado |
|---|---|
| Rutina en memoria anterior a un bloqueo | Antes de abrir el diálogo y antes de enviar, se confirma con el Backend. El diálogo usa el ejercicio tal como lo tiene el Backend ahora |
| La app vuelve del segundo plano | Se releen el plan, las exclusiones, las peticiones y las adaptaciones (C1, probado con Inicio real y con la rutina abierta) |
| Sin red o con una respuesta lenta | No se envía nada; los resultados se conservan (C3) |
| Una rutina reemplazada por una versión nueva | No se puede editar ni enviar |
| No hay caché en disco | La app no guarda rutinas entre arranques: al reabrir, todo se lee del Backend (escenario 12) |

## 6. Evidencias con el Backend real

Todas están en `evidencia/`. Las capturas usan las respuestas reales grabadas, sin cambios (`capturas/R*`, `D*`).

- `backend-real-escenarios.txt`: escenarios 1, 4–8, 10 y 12, además de la lista y la explicación de equivalentes y precauciones. Repetido con el código final.
- `backend-real-s2-s3-sesion-abierta.txt`: escenarios 2 y 3 en una sesión abierta (§2).
- `backend-real-reactivacion-rechazada.txt`: el rechazo real y la vía «no relacionado» (§3).
- `backend-real-cierre1-07dic.txt` y `backend-real-cierre2-14dic.txt`: escenario 9.
- `backend-real-no-factible.txt`: escenario 11.
- `busqueda-coocurrencia.txt`: las 34 cuentas sin coocurrencia.
- `demo-kora.txt`: la cuenta demo, leída solo con GET.

## 7. Usuario 48 (Demo Kora)

**Tu usuario 48 no se pudo verificar.** No tengo acceso a tu PostgreSQL ni a Railway, y no modifiqué nada.

**Copia local:** el dataset `feature/dataset-demo-kora` (`19ba896`) cargado en la base aislada `fitsense_demo`.

**Por GET** (`demo-kora.txt`), los datos siguen presentes:

- 4 planes: 910000000 (W-3, con 3 completados, 1 parcial y 1 omitido), 910000001 y 910000002 (completos) y 910000003 (vigente);
- 3 adaptaciones: `REGENERACION_SEGURA_SUSTITUCION` (la sustitución por dolor), `SIN_ADAPTACION` y `PROGRESION_DEL_BACKEND`;
- métricas de adherencia de 3 semanas;
- la exclusión `DIRECT 1025`, confirmada.

**Los procesos automáticos no alteraron el escenario:**

- no hay planes nuevos ni intentos de adaptación nuevos (siguen 4 y 3);
- lo único que cambió es lo que prevé el README del dataset: la tarea de vencimiento marcó como omitidos el lunes y el martes de la semana vigente, que la cuenta no entrenó.

**Desde la app** (`test/o20_demo_kora_app_test.dart`, en la suite):

- La pantalla de Inicio real, con sus proveedores y repositorios, funciona sobre las 17 respuestas reales grabadas (`test/fixtures/o20_demo_kora`). Cualquier petición que no sea GET hace fallar la prueba.
- Se comprobó:
  1. la sesión iniciada;
  2. la rutina vigente (D1, D2: los 5 entrenamientos);
  3. las semanas anteriores: el historial de 4 planes (D4);
  4. la adherencia: 100 % (5/5) el 16/11, 67,8 % (3/5) el 02/11 (D3);
  5. las adaptaciones: «Plan adaptado a ti» en la semana del 09/11, la sustitución, y «Sin ajustes registrados» el 16/11 (D3);
  6. la exclusión del 1025, «Lo marcaste con dolor.» (D5);
  7. los mensajes de seguridad: ninguno pendiente, correcto para esta cuenta;
  8. al volver del segundo plano se relee el plan.

**Discrepancia:** dices que el usuario 48 participa en el estudio (`is_study_participant = true`), pero el script `01_USUARIO_DEMO.sql` aborta con una cuenta participante (líneas 35–38). Por eso la copia local no participa. **En tu base, con participación:**

- el cierre de los lunes a las 03:00 (Lima) podría generar otro plan;
- conviene no hacer la demostración en esa franja;
- comprueba que no apareció ningún plan nuevo (consulta 3 de `06_VERIFICACION.sql`).

No cambié ese valor.

## 8. Android físico

**Pendiente de ejecución por el usuario.** No hay dispositivo, y `adb` no está disponible en este entorno.

`GUIA_ANDROID.md` explica, para Windows y Android Studio:

- actualizar la rama;
- ADB y `adb reverse` (no se usa `10.0.2.2`, que solo vale en el emulador);
- arrancar el Backend sin IA;
- el usuario demo (solo mirar);
- 18 comprobaciones, con lo que debe aparecer en cada una;
- cómo capturar `logcat`, pantallas y vídeo.

## 9. Pruebas automáticas y criterios de aceptación

| Verificación | Resultado |
|---|---|
| `flutter analyze` | Sin problemas |
| `flutter test` | **389 aprobadas, 0 fallidas, 31 omitidas.** Las omitidas son las de Backend real y capturas, que necesitan variables de entorno y se ejecutaron aparte |
| Pruebas de seguridad O20 en la suite | `pain_o20_test` 26, `o20_rutina_desactualizada_test` 12, `o20_demo_kora_app_test` 1. Nombres en `evidencia/pruebas-seguridad-o20.txt` |
| Backend real | `o20_validacion_live_test` 4/4, `o20_cierre_live_test` 2/2 (equivalentes, rechazo), `o20_dos_semanas_live_test` 3/3, grabación 5 modos |

| N.º | Criterio | Estado |
|---|---|---|
| 1 | Ningún bloqueado como completo | Aprobado (real: escenarios 1, 2, 3 y 4; widget) |
| 2 | Ningún bloqueado como parcial | Aprobado (real: parciales → 422; widget: no se ofrece) |
| 3 | No se usa un plan desactualizado para autorizar | Aprobado (C3, §4 y §5) |
| 4 | Los fallos de conexión no eliminan restricciones | Aprobado (§4, casos 1, 2 y 6) |
| 5 | Se respetan equivalentes y precauciones | Aprobado (§2) |
| 6 | Las confirmaciones inválidas no desbloquean | Aprobado (escenario 8; §3, vía «no relacionado») |
| 7 | Los 422 se recuperan | Aprobado (escenario 8, §4) |
| 8 | Las restricciones siguen tras reiniciar | Aprobado (escenario 12, §2, §7) |
| 9 | Firebase y D-M1 sin regresiones | Aprobado (§10) |
| 10 | El Backend es la autoridad final | Aprobado. La app nunca levanta ni concede nada por su cuenta; solo relee |

## 10. Firebase, D-M1, generación y adaptación

Resultados en `evidencia/regresiones-firebase-dm1-generacion.txt`.

| Grupo | Resultado |
|---|---|
| **Firebase y sesión:** registro del dispositivo, permisos, notificaciones, recuperación de sesión, desvinculación al cerrar sesión | 94/94 |
| **D-M1:** sesiones completas y parciales, duración por tiempo, un parcial igual al 100 % pide «Lo completé» | 28/28 |
| **Generación y adaptación:** plan vigente, historial, generación asíncrona, `NO_FACTIBLE`, adaptaciones | 104/104 |

- No se modificó nada de Firebase, D-M1, la generación ni el Backend.
- **Ajuste de pruebas:** las dos de D-M1 que tocan la rutina simulan también el repositorio de planes, porque la página confirma la rutina antes de enviar. No cambia ninguna expectativa.

## 11. Incidencias y correcciones de esta ronda

| N.º | Incidencia | Corrección | Prueba que lo reproduce |
|---|---|---|---|
| C3 | Sin respuesta del Backend (error o espera larga), la app seguía adelante y dejaba decidir al Backend. La orden exige no enviar | Confirmación obligatoria antes de cada envío; resultados pendientes guardados; «Reintentar envío»; bloqueo de acciones duplicadas | `o20_rutina_desactualizada_test`: fallan 5 pruebas sin la corrección |
| C4 | La relectura al volver del segundo plano (C1) estaba en `app.dart` y no se podía probar con pantallas reales | Widget `PainSafetyResumeRefresher`, aplicado a toda la app | `o20_demo_kora_app_test`, paso 6 |
| C5 | El rechazo de reactivación y los motivos de «no levantado» mostraban el texto crudo del Backend (código, identificador, `alto_impacto`) | `reactivationRefusal` y `notLiftedReason`, sin códigos | `pain_o20_test`: 2 pruebas con los mensajes literales del Backend |

**Fuera de O20 (no se cambió):** el historial de planes muestra el código técnico de la decisión del Backend en la semana adaptada («ADAPT_LOCALIZED», captura D4). Es anterior a esta PR.

## 12. Commits y archivos

- `c84e22c`: integración O20.
- `89a7be9`: primera validación.
- **El commit de este cierre:**

| Tipo | Archivos |
|---|---|
| Código | `lib/features/workouts/presentation/planned_workout_page.dart` (C3), `lib/features/pain/presentation/pain_confirmation_sheet.dart` (C4, C5), `lib/features/pain/domain/pain_safety.dart` (C5), `lib/features/pain/presentation/pain_exclusions_sheet.dart` (C5), `lib/app/app.dart` (C4) |
| Pruebas | `test/o20_rutina_desactualizada_test.dart`, `test/o20_demo_kora_app_test.dart` y su fixture `test/fixtures/o20_demo_kora/` (17 respuestas), `test/pain_o20_test.dart`, `test/live/o20_cierre_live_test.dart`, `test/live/o20_grabar_live_test.dart`, `test/screenshots/o20_backend_real_capturas_test.dart` |
| Documentación | Este informe, `GUIA_ANDROID.md`, `evidencia/` y `capturas/` |

## 13. Riesgos y limitaciones

1. **Android físico** sin ejecutar (§8).
2. **Usuario 48** no verificado en tu base, y con la discrepancia de participación (§7).
3. **Escenarios 2 y 3:** el plan se sembró por SQL en una base aislada (§2), porque el generador real no produce ese caso. Si un plan publicado lo contuviera, por ejemplo uno de la IA, la protección probada es la misma: el bloqueo del Backend y su 422, y la app que no ofrece registrar trabajo.
4. **Escenarios 9 y 11 y el rechazo:** se probaron con el reloj del Backend adelantado (libfaketime), no con semanas reales.
5. **Precio de la regla C3:** sin conexión no se puede enviar ningún resultado, aunque sea un «no realizado». Queda pendiente hasta que haya red. Es la conducta segura que pide la orden.
6. **Capturas:** las GIF no cargan porque las pruebas no tienen red. El texto de botones y avisos se dibuja con Poppins, mientras que el dispositivo usa su fuente.

## 14. Recomendación sobre el merge

**Apta para la revisión final.**

- **Seguridad:** los 10 criterios están demostrados, también en las rutas con conexión interrumpida, rutina antigua o sesión abierta.
- **Calidad:** no hay regresiones en Firebase, D-M1 ni generación; `flutter analyze` sale limpio; 389 pruebas aprobadas y 0 fallidas.

**Recomiendo autorizar el merge después de ejecutar `GUIA_ANDROID.md` en tu teléfono.** Esa prueba no cubre ninguna regla de seguridad que no esté ya demostrada. Lo que sí comprueba es:

- la conectividad real del dispositivo (`adb reverse` o Wi-Fi);
- el comportamiento con el modo avión (§6, filas S5 y S6 de la guía);
- la experiencia en pantalla.

Si decides fusionar sin ella, el riesgo restante es de presentación o conectividad del dispositivo, no de seguridad O20.

**La PR #19 queda pendiente de tu autorización. No se fusionó.**
