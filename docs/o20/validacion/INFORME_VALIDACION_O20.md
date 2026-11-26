# Cierre definitivo de O20 en Mobile (PR #19)

**Contexto:**

| | |
|---|---|
| Rama | `claude/o20-exclusiones-dolor`, sobre `generation` `abe5e3d` (incluye las PR #17 y #18) |
| Backend de referencia | `generation` `98276a9`, con #84 (O20 + V65) y #83. Se ejecutó en local con la IA apagada |
| Bases aisladas | `fitsense_val`, `fitsense_val2` (cuentas sintéticas) y `fitsense_demo` (copia del dataset Demo Kora) |
| Recursos externos | No se usó Replicate ni OpenAI. No se hizo ningún despliegue. No se tocó ninguna base real ni el usuario 48 |

## Conclusión: APROBADA PARA MERGE

- **Seguridad:** las pruebas están completas. Kora impide registrar trabajo en un ejercicio bloqueado aun con errores de conexión, resultados pendientes, reintentos, sesiones antiguas o restricciones nuevas.
- **Calidad:** no quedan bloqueos críticos ni regresiones. `flutter analyze` sale limpio; 396 pruebas aprobadas y 0 fallidas; CI en verde.

**Pendientes, por separado (no son de seguridad):**

- **La prueba en un Android físico sigue pendiente** de ejecución por el usuario (§7). No se declara aprobada.
- **El usuario 48 de tu base** no se pudo comprobar desde aquí; la demostración se validó sobre una copia local del dataset (§6).

## 1. Mensaje de reactivación rechazada

**Respuesta real del Backend** (cuenta sintética de 60 años, ejercicio de alto impacto; `evidencia/backend-real-reactivacion-rechazada.txt`):

`422 REACTIVACION_RECHAZADA_POR_SEGURIDAD: el ejercicio 460 choca con una restriccion de seguridad vigente (alto_impacto). Tu confirmacion no puede levantarla.`

**Lo que muestra la app ahora:**

- un **diálogo propio** titulado «Sigue bloqueado», con el botón «Entendido»;
- **no** usa el aviso inferior de las acciones correctas, así que no se confunde con un éxito;
- el texto (captura R10): «Flexión pliométrica con toque de pecho» todavía no puede habilitarse porque existe una restricción de seguridad en tu perfil (alto impacto). Sigue bloqueado y Kora no te lo propondrá. Puedes continuar con los ejercicios permitidos.

| Requisito | Cómo se cumple | Prueba |
|---|---|---|
| 1. Mensaje comprensible | El texto anterior, en un diálogo | `pain_o20_test` «10 · REACTIVACION_RECHAZADA_POR_SEGURIDAD as the real backend sends it» (mensaje literal del Backend) |
| 2. Explica que sigue bloqueado por una restricción | «Sigue bloqueado… existe una restricción de seguridad en tu perfil» | Igual |
| 3. Sin códigos ni detalles técnicos | Sin `REACTIVACION_…`, sin `alto_impacto` y sin el identificador | Igual (se comprueba que no aparece ninguno) |
| 4. Bloqueo visual y funcional | La fila sigue en Perfil. El plan no cambia: el ejercicio sigue con `safetyBlockReason` y solo admite «No lo hice» | Igual; escenario 4 |
| 5. Exclusiones releídas del Backend | `effective()` se vuelve a leer tras la respuesta | Igual |
| 6. Historial sin cambios | La app no envía nada más. Real: las mismas 7 filas y los mismos planes | Igual; evidencia real |
| 7. No es un éxito | Diálogo propio, sin aviso inferior | Igual (`SnackBar` ausente) |

- **El motivo es el del Backend:** el código entre paréntesis se traduce a palabras («alto impacto»). Si el código no se reconoce, se dice solo «una restricción de seguridad en tu perfil». Nunca se inventa un motivo.
- **Otra vía:** al declarar el ejercicio «no relacionado», el Backend tampoco lo levanta y la app muestra el motivo sin códigos («No es compatible con una restricción de seguridad vigente (alto impacto).»).

## 2. Reintentos cuando llega un bloqueo después

**Corrección C6.** Un resultado pendiente que, al reintentar, el plan vigente ya no admite:

- **No se envía nunca.** Pasa a «Resultados retenidos: no se enviarán».
- **Queda visible** y se puede descartar.
- **El ejercicio aparece bloqueado** y solo admite «No lo hice», que sustituye al retenido. Se registra una sola vez.
- **La app relee** el plan y las exclusiones, y pide al usuario revisar la rutina actualizada.

El escenario obligatorio, probado con un resultado **completo** y con uno **parcial** (1 serie, 12 repeticiones), en `o20_rutina_desactualizada_test`:

1. **Rutina válida:** se registra el ejercicio.
2. **Se corta la conexión antes del envío:** queda «Pendiente de enviar» y no se envía nada.
3. **El Backend registra una exclusión** para ese ejercicio.
4. **Vuelve la conexión** y el usuario pulsa «Reintentar envío». La app relee el plan:
   - **no envía** el registro antiguo;
   - lo pasa a «retenido» y muestra «Revisa la rutina actualizada»;
   - el ejercicio aparece bloqueado.
5. **«No lo hice»:** se registra una sola vez y desaparece el retenido. No hay sesiones ni registros duplicados.

**Además:**

- **Al volver del segundo plano** se revalidan los pendientes. Uno incompatible pasa a retenido, sin enviarse.
- **Prueba a la inversa:** si se quita la revalidación, fallan 5 pruebas (las dos variantes, la de segundo plano, la de descartar y la del plan cambiado con el diálogo abierto).

## 3. Conectividad y concurrencia

| Escenario | Resultado obligatorio | Comportamiento comprobado | Prueba |
|---|---|---|---|
| Sin conexión | No enviar sin confirmar la rutina | No se envía; queda pendiente; «Reintentar envío» | «1 · the connection fails» |
| Más de 8 s de espera | Bloquear el envío y ofrecer reintento | Igual, tras 8 s | «2 · the backend takes more than 8 seconds» |
| HTTP 401 | No seguir con una autorización inválida | No se envía. La sesión caducada la cierra el manejo global de 401 | «3 · the plan request answers 401» |
| HTTP 422 | Mostrar el error y actualizar las restricciones | 422 al consultar el plan: no se envía. 422 al registrar: se explica, se releen el plan, la sesión y las exclusiones, y el resultado no queda pendiente | «4 · …422»; escenario 8 |
| Plan modificado | Invalidar los resultados incompatibles | Ejercicio bloqueado después o rutina reemplazada: no se envía y el resultado queda retenido | Grupo «5 · …different plan» y §2 |
| Conexión perdida durante el envío | Evitar duplicados y consultar el estado antes de repetir | El resultado queda pendiente y marcado como «quizá recibido». Al reintentar, primero `GET /sessions/current`: si ya consta, no se repite; si la sesión se cerró, queda retenido; si no se puede consultar, no se repite | Grupo «6 · lost answer» (3 pruebas) y «6 · the connection drops…» |
| App en segundo plano | Revalidar al regresar | Se releen la rutina y los pendientes; un solo diálogo y un solo registro | «7 · …background…» y §2 |
| Doble pulsación | Evitar envíos simultáneos duplicados | Dos toques en «Registrar ejercicio» → un diálogo y un registro. Dos toques en «Reintentar envío» → un registro | Grupo «8 · two actions…» |

**Reintentos y deduplicación.** No se inventó ningún endpoint ni mecanismo de deduplicación:

- se usan `GET /sessions/current`, que devuelve los registros de la sesión, y `PUT /sessions/{s}/exercises/{pe}`;
- el Backend define ese PUT como «reemplaza el resultado de ese ejercicio, nunca acumula» (`WorkoutRepository.record`);
- por eso repetir un mismo resultado no crea duplicados, y la app además comprueba antes si ya consta.

**Prueba a la inversa:** sin la consulta previa a la sesión, fallan las 3 pruebas del grupo 6.

## 4. No se envían resultados de rutinas desactualizadas

| Ruta | Protección | Evidencia |
|---|---|---|
| Registro en vivo | Se confirma la rutina con el Backend antes del diálogo y antes de enviar. Sin confirmación no hay envío | `o20_rutina_desactualizada_test` (19) |
| Reintento de pendientes | Se vuelve a confirmar; lo incompatible se retiene; si la respuesta se perdió, se consulta la sesión | §2 y §3 |
| Registro retroactivo | Misma regla: sin confirmación no se envía y se conservan todos los borradores; los inválidos se descartan avisando | «retroactive report…» y `pain_o20_test` |
| Volver del segundo plano | Se relee toda la app (`PainSafetyResumeRefresher`) y la rutina abierta | `o20_demo_kora_app_test` (Inicio real); `pain_o20_test` |
| Carrera: bloqueo entre la confirmación y el envío | El Backend responde 422; la app lo explica y relee | Real: escenario 8 y escenarios 2 y 3; widget «8 · a 422…» |
| Última barrera | Cualquier trabajo sobre un bloqueado lo rechaza el Backend: completo, parcial o retroactivo → 422 | `backend-real-escenarios.txt`, `backend-real-s2-s3-sesion-abierta.txt` |

## 5. Equivalencias y precauciones

Repetido con el código final (`evidencia/backend-real-s2-s3-sesion-abierta.txt`).

**Es una prueba controlada, no generación natural:** el plan es del motor de reglas, nunca de la IA. En la base aislada `fitsense_val2` se sembraron por SQL 4 prescripciones (`preparar-cierre.py`), porque en 34 cuentas el generador nunca puso una variante o una precaución en la misma semana que el ejercicio de origen (`busqueda-coocurrencia.txt`). No se tocaron los validadores ni los criterios del Backend.

**Resultado real:**

1. Sesión abierta primero; después, omisión por dolor de la otra rutina.
2. `EQUIVALENT 13` de 1054 y `PRECAUTION 899` de 1138, ambas bloqueadas en la sesión abierta.
3. Completo → 422; parcial → 422; no realizado → 200.
4. Siguen bloqueadas al volver a iniciar sesión y tras una identificación que no las nombra.

**Las explicaciones en la app no tienen códigos.** El diálogo de la precaución solo ofrece «No lo hice» (R8, R9).

## 6. Usuario Demo Kora

**Tu usuario 48** (participante del estudio) no es accesible desde aquí. No se modificó nada: ni su participación, ni generaciones, ni cierres.

**Copia local:** dataset `feature/dataset-demo-kora` (`19ba896`) en la base aislada `fitsense_demo`.

- **Datos presentes y sin planes adicionales** (`demo-kora.txt`, `demo-kora-estado-base.txt`):
  - 4 planes y 3 intentos de adaptación, sin cambios;
  - el único cambio es el previsto por el README: la tarea de vencimiento marcó como omitidos los días pasados de la semana vigente.
- **En la app** (`test/o20_demo_kora_app_test.dart`, en la suite):
  - la pantalla de Inicio real, con sus proveedores y repositorios, funciona sobre 18 respuestas reales grabadas (`test/fixtures/o20_demo_kora`), solo GET;
  - se leen 12 rutas distintas y todas estaban grabadas.

| N.º | Requisito | Resultado | Captura |
|---|---|---|---|
| 1 | Perfil completo | «Ganar masa muscular…», cumpleaños 12/04/1995, 176 cm, 74 kg, 5 días · 60 min | D6 |
| 2 | Rutina vigente | Plan 910000003 con sus 5 entrenamientos | D1, D2 |
| 3 | Historial de 4 planes | 23/11 vigente; 16/11, 09/11 y 02/11 completados | D4 |
| 4 | Sesiones completadas, parciales y omitidas | Semana del 02/11: 3 «Completado», 1 «Parcial» y 1 «Omitido» | D4 (semana) |
| 5 | Adherencia histórica | 67,8 % (3/5) el 02/11; 100 % el 09/11 y el 16/11 | D3 |
| 6 | Adaptación por sustitución (dolor) | Semana del 09/11: «Plan adaptado a ti» (`REGENERACION_SEGURA_SUSTITUCION`) | D3 (09/11) |
| 7 | Adaptación por progresión | `PROGRESION_DEL_BACKEND` (23/11) en «Resumen de ajustes» | D3 |
| 8 | Exclusión del 1025 | «Aperturas de pecho sentado con palanca. Lo marcaste con dolor.» | D5, R1 |
| — | Actualización al volver a la app | Se relee el plan | paso 6 de la prueba |

**Diferencia con tu base:**

- El script `01_USUARIO_DEMO.sql` aborta con cuentas participantes, así que la copia local no participa (D6 muestra «No participas en el estudio»).
- Tu usuario 48 sí participa. **Antes de la demostración:**
  - ejecuta la consulta 3 de `06_VERIFICACION.sql` para confirmar que siguen siendo 4 planes;
  - evita los lunes de 02:30 a 04:00 (Lima): el cierre semanal procesa a los participantes.

## 7. Android físico

**Pendiente de ejecución por el usuario.** No hay dispositivo, y `adb` no está disponible en este entorno.

`GUIA_ANDROID.md` explica, para Windows y Android Studio:

- actualizar la rama;
- conectar con ADB y `adb reverse` (o por Wi-Fi, nunca con `10.0.2.2`);
- arrancar el Backend sin IA;
- iniciar sesión con el usuario demo;
- 22 comprobaciones:
  - rutina, historial y sesiones, adaptaciones, perfil y bloqueos;
  - volver del segundo plano;
  - modo avión, «Reintentar envío», resultados retenidos y respuesta perdida;
- cómo capturar `logcat`, pantallas y vídeo.

## 8. Pruebas

| | Aprobadas | Fallidas | Omitidas |
|---|---|---|---|
| `flutter test` (suite completa) | **396** | **0** | 31 (Backend real y capturas, que necesitan variables de entorno y se ejecutaron aparte) |
| Seguridad O20 en la suite: `pain_o20_test` 26, `o20_rutina_desactualizada_test` 19, `o20_demo_kora_app_test` 1 | 46 | 0 | — |
| Backend real: `o20_validacion_live_test` 4/4, `o20_cierre_live_test` (equivalentes) 1/1, `o20_dos_semanas_live_test` 3/3, reactivación rechazada 1/1, grabación 5 modos | todas | 0 | — |

**Regresiones** (`evidencia/regresiones-firebase-dm1-generacion.txt`):

| Grupo | Resultado |
|---|---|
| Firebase y registro de dispositivos, autenticación y cierre de sesión | 117/117 |
| D-M1: parciales y duraciones | 28/28 |
| Generación asíncrona, historial, adaptaciones y `NO_FACTIBLE` | 104/104 |
| Exclusiones y confirmaciones por dolor | 46/46 |

No se cambió nada de Firebase, D-M1, la generación ni el Backend.

## 9. `flutter analyze`

Sin problemas.

## 10. CI

Resultado del último commit: lo indica el comentario de esta validación en la PR #19.

## 11. Archivos y commits

**Commits previos:**

- `c84e22c`: integración O20.
- `89a7be9`: primera validación.
- `d8b5d9f`: cierre de seguridad (C3, C4 y C5).

**Este commit:**

| Tipo | Archivos |
|---|---|
| Código | `lib/features/workouts/presentation/planned_workout_page.dart` (C6: retenidos, consulta de la sesión antes de repetir, revalidación al volver), `lib/features/pain/domain/pain_safety.dart` y `lib/features/pain/presentation/pain_exclusions_sheet.dart` (mensaje y diálogo del rechazo) |
| Pruebas | `test/o20_rutina_desactualizada_test.dart` (19), `test/pain_o20_test.dart`, `test/o20_demo_kora_app_test.dart` y `test/fixtures/o20_demo_kora/` (18), `test/live/o20_grabar_live_test.dart`, `test/screenshots/o20_backend_real_capturas_test.dart` |
| Documentación | Este informe, `GUIA_ANDROID.md`, `evidencia/` y `capturas/` |

## 12. Riesgos y limitaciones

1. **Android físico** sin ejecutar (§7).
2. **Usuario 48** no verificado en tu base y, a diferencia de la copia local, participante (§6).
3. **Escenarios 2 y 3:** son una prueba controlada con un plan sembrado (§5). El generador real no produce ese caso.
4. **Escenarios 9 y 11 y el rechazo de reactivación:** se probaron con el reloj del Backend adelantado (libfaketime).
5. **Sin conexión:** no se envía ningún resultado, ni siquiera un «no realizado»; queda guardado hasta que el Backend confirme la rutina. Es la conducta segura que pide la orden.
6. **Resultados pendientes y retenidos solo en memoria:** se pierden si el sistema cierra la app antes de reenviarlos. Nunca se envían sin validar; lo único que puede ocurrir es que el usuario tenga que volver a anotarlos.
7. **Fuera de O20 (no se cambió):** el historial de planes muestra el código técnico «ADAPT_LOCALIZED» en la semana adaptada (captura D4). Es anterior a esta PR.
8. **Capturas:** las GIF no cargan porque las pruebas no tienen red. El texto se dibuja con Poppins, mientras que el dispositivo usa su fuente.

**La PR #19 queda pendiente de tu autorización de merge. No se fusionó.**
