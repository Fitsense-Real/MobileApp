# Pendientes tras O20: propuestas (sin implementar)

Se identificaron durante la validación de la PR #19, ya fusionada en `generation` (`0649f78`). **No bloquean O20 y no se incluyeron en ella.** Este documento solo propone; nada de esto está implementado.

## P1 · Guardar en el teléfono los resultados pendientes

### Situación actual

`PlannedWorkoutPage` guarda en memoria dos tipos de resultado:

- **pendientes** (`pending`): no se pudieron confirmar con el Backend;
- **retenidos** (`held`): la rutina ya no los admite.

Si Android termina el proceso, se pierden y el usuario tiene que volver a anotarlos. La seguridad no se ve afectada: nunca se envían sin validar.

### Propuesta

1. **Dónde guardar:** en `FlutterSecureStorage`, que ya usa la app para el JWT y los datos locales de la cuenta (`LocalAccountData`). Serían pocos registros pequeños, cifrados por el sistema.
2. **Una clave por cuenta y sesión:** `pending_results_<userId>`, con una lista JSON. Cada elemento lleva:
   - `sessionId`, `plannedWorkoutId` y `plannedExerciseId`;
   - el cuerpo exacto del `PUT`;
   - el estado (`pending`, `held` o `maybeSent`) y la fecha en que se anotó.
3. **Nada se envía solo.** Al abrir la rutina, los resultados guardados aparecen como «Pendiente de enviar» o «Retenido». El envío pasa siempre por el flujo actual:
   - confirmar la rutina con `GET /users/me/plan/current` (máximo 8 s);
   - comprobar el ejercicio;
   - consultar `GET /sessions/current` si quizá ya llegó;
   - solo entonces, `PUT`.
4. **Caducidad:**
   - se borra lo que pertenece a una sesión que el Backend ya no tiene abierta;
   - se borra también lo que tenga más de 48 h, avisando al usuario;
   - nunca se reabre ni se recrea una sesión.
5. **Al cambiar de cuenta:** la clave se añade a `LocalAccountData.keysOf(userId)`, de modo que se borra al eliminar la cuenta, y no se muestra si entra otra persona. Al cerrar sesión se conserva solo para esa misma cuenta.
6. **Pruebas previstas:**
   - matar la app con un resultado pendiente y volver a abrirla: sigue pendiente y no se envía hasta validar;
   - pendiente guardado más bloqueo posterior: pasa a retenido;
   - respuesta perdida guardada: al reintentar se consulta la sesión y no hay duplicado;
   - sesión cerrada en el Backend: se descarta avisando;
   - otra cuenta en el mismo teléfono: no ve nada;
   - eliminar la cuenta: la clave desaparece.
7. **Riesgo y alcance:**
   - no cambia ningún contrato del Backend ni la regla de no enviar sin confirmar;
   - afecta a `planned_workout_page.dart`, a un repositorio nuevo de pendientes y a `LocalAccountData`;
   - PR independiente.

## P2 · Texto comprensible en el historial de planes

### Situación actual

`PlanHistorySheet` muestra `adjustmentApplied` traducido con `adjustmentLabels`, pero ese mapa no conoce las decisiones del ciclo semanal. El Backend guarda ahí, por ejemplo, `ADAPT_LOCALIZED`, y la app muestra el código tal cual (captura `validacion/capturas/D4-demo-historial.png`, semana del 09/11).

### Propuesta

1. **Etiquetas** para los valores del enum del Backend (`AdaptationOutcome` y la reparación de seguridad):

   | Código | Texto propuesto |
   |---|---|
   | `ADAPT_LOCALIZED` | Ajustada una sesión |
   | `ADAPT_EXPANDED` | Ajustadas varias sesiones |
   | `NO_CHANGE` | No se muestra |
   | `INSUFFICIENT_DATA` | No se muestra |
   | Ajuste de reparación de seguridad (`PublishedPlanSafetyRepairService.AJUSTE`) | Ajustada por seguridad |

2. **Códigos desconocidos:** en lugar de mostrar el código, «Plan ajustado». Nunca un código técnico en pantalla.
3. **Prueba:** cada código conocido produce su texto; uno desconocido produce «Plan ajustado». Se usaría el fixture real `test/fixtures/o20_demo_kora/_users_me_plans.json`, que contiene `ADAPT_LOCALIZED`.
4. **Alcance:** solo `plan_history_sheet.dart` y su prueba. PR independiente.
