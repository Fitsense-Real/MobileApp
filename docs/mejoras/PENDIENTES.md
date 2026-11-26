# Pendientes de Mobile tras O20, P1 y P2

**Estado de `generation`:** `d7bbc1a`, con O20 (PR #19), la guía (PR #20), P2 (PR #21) y P1 (PR #22).

## P3 · Guardar los borradores del registro retroactivo (propuesta, sin implementar)

### Situación

P1 guarda en el teléfono los resultados del **registro en vivo** que no se pudieron enviar.

Los **borradores del registro retroactivo** («Ya lo hice · registrar entrenamiento») siguen solo en memoria: si Android cierra Kora antes de pulsar «Guardar entrenamiento», se pierden y hay que volver a anotarlos.

La seguridad no se ve afectada: antes de enviar, `report()` confirma la rutina con el Backend y descarta lo que ya no es válido.

### Propuesta

1. **Reutilizar `PendingResultsStore`** con un estado nuevo, `draft`, en la misma clave por cuenta. Cada borrador lleva:
   - `plannedWorkoutId` y `plannedExerciseId`;
   - el cuerpo del ejercicio;
   - la hora.

   Los borradores retroactivos no tienen sesión, así que `sessionId` sería nulo y solo se permitiría en ese estado.
2. **Al abrir la rutina en modo registro,** se recuperan los borradores de esa cuenta y de esa rutina. Se muestran como borradores y **nunca se envían solos**.
3. **«Guardar entrenamiento»** sigue el flujo actual:
   - confirmar la rutina (máximo 8 s);
   - descartar, avisando, el trabajo en ejercicios bloqueados después;
   - pedir fecha y esfuerzo;
   - `POST /workouts/{id}/report`, que el Backend valida (422 si algo no es seguro).
4. **Mismas garantías que P1:**
   - caducidad de 48 h;
   - aislamiento por cuenta;
   - borrado con la cuenta;
   - datos dañados descartados y avisados;
   - sin JWT ni correo.
5. **Pruebas previstas:**
   - cierre completo con borradores → reaparecen sin enviarse;
   - bloqueo posterior → se descarta el trabajo en ese ejercicio;
   - otra cuenta no los ve;
   - borrador parcial conserva sus cantidades (D-M1);
   - un entrenamiento ya registrado elimina sus borradores.
6. **Alcance:** `pending_results_store.dart` y `planned_workout_page.dart` (`report()` y la restauración). PR independiente.

## Prueba en Android físico

**Pendiente de ejecución por el usuario.** Las pruebas automáticas no sustituyen la comprobación en un teléfono real. Guía: `docs/o20/validacion/GUIA_ANDROID.md`.

## Usuario Demo Kora (48)

Pendiente de comprobar en la base real con las consultas de solo lectura de la guía (§5.1), antes de la demostración. No se modifica su participación ni el dataset.
