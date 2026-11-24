# D-M1 — Registro de ejercicios por tiempo

**Síntoma:** al pulsar «Lo completé» en un ejercicio por tiempo, se registraba la duración de **una** serie. Por ejemplo,
120 s en lugar de 360 s para 3 × 120 s. El Backend lo marcaba al 33 % (PARTIAL) aunque el ejercicio se hubiera hecho
completo, y la adherencia de la sesión bajaba sin motivo.

## Causa

| Versión | «Lo completé» enviaba | Resultado en el Backend |
|---|---|---|
| `main` (`3a4e26d`, primera versión del Mobile) | `actualDurationSeconds: plannedDurationSeconds`, los segundos de **una** serie (`exercise_result_dialog.dart`) | Con 3 series: 33,33 %, PARTIAL |
| `generation` (desde `bedcf0d`, 2026-11-06) | `prescribedResult` → `plannedTotal`: **series × segundos** | 100 %, COMPLETED |

Así que la parte principal del defecto **ya estaba corregida en `generation`**, pero `main` nunca recibió esa corrección.
Cualquier APK compilada desde `main` sigue registrando una sola serie. Esta rama no modifica `main` ni `generation`.

**Defecto relacionado, presente en `generation` y corregido aquí (punto 4):**
1. El usuario pulsaba «Lo completé», y el diálogo rellenaba las cantidades del plan (por ejemplo, 360 s).
2. Luego pasaba a «Lo hice parcialmente».
3. Las cantidades seguían ahí y se podían guardar sin editarlas.

El resultado «parcial» llevaba los 360 s no realizados, y el Backend lo guardaba al 100 % (COMPLETED), descartando
además el motivo.

## Corrección

En `lib/features/workouts/presentation/exercise_result_dialog.dart`:
- **Cambio a «Lo hice parcialmente»:** si las cantidades en pantalla venían rellenadas por «Lo completé» o «No lo hice», se
  borran las series, repeticiones y segundos. La carga se mantiene. Los valores escritos por el usuario o cargados de un
  resultado guardado no se tocan.
- **Guardar un parcial que alcanza todo lo indicado:** si el volumen llega al total del plan (`plannedTotal`), no se
  guarda. Aparece «Eso es todo lo indicado en tu plan (360 s en total). Si lo hiciste completo, elige «Lo completé»». Lo
  mismo vale para repeticiones.
- **Sin cambios:** el cálculo de «Lo completé» (`workout_rules.dart`), ya correcto en `generation`.

## Compatibilidad con el Backend (`generation` `e46dbe1`)

| Concepto | Backend | Mobile |
|---|---|---|
| Ejercicio por tiempo | `"DURATION".equals(prescriptionType)` | `prescriptionType == 'DURATION'` (el Backend siempre lo envía) |
| Total por tiempo | `PlannedExerciseTarget.plannedDurationTotal()`: `(plannedSets ?? 1) × plannedDurationSeconds`, y 0 sin duración | `plannedTotal`: lo mismo |
| Total por repeticiones | `plannedRepsTotal()`: `plannedSets × plannedReps`, y 0 si falta alguno | `plannedTotal`: lo mismo |
| Porcentaje del ejercicio | `actual × 100 / total`, con tope | No se calcula en la app: lo calcula el Backend |
| Porcentaje de la sesión | Suma de los porcentajes / ejercicios asignados, con tope | No se calcula en la app |

**Ejercicio por tiempo sin número explícito de series:** cuenta como una serie, igual que en el Backend (`plannedSets ?? 1`).

**Ejercicio por tiempo sin duración en el plan:** el total es 0 en los dos lados. El Backend no puede medirlo (denominador
0 → 0 %) y la app muestra «Duración no indicada en el plan». Es el contrato actual y no se cambió.

**No se modificó:**
- la fórmula de adherencia ni el Backend;
- la generación de rutinas;
- Firebase;
- los recordatorios.

## Pruebas

**Automatizadas:** `test/timed_exercise_results_test.dart`, 13 casos.
- 3 × 120 s → 360 s, repeticiones 3 × 12 → 36, y series × segundos para varias combinaciones.
- Sin series → una serie; sin duración o sin series de repeticiones → 0, como el Backend.
- Diálogo: «Lo completé» muestra y guarda 360 s.
- «Lo completé» → «Lo hice parcialmente» borra las cantidades y guarda solo lo realizado.
- «No lo hice» → «Lo hice parcialmente» tampoco deja ceros.
- Un parcial con todo lo indicado pide «Lo completé», tanto por tiempo como por repeticiones.
- Editar un parcial guardado conserva sus valores.
- Registro de la rutina completa (36 repeticiones y 360 s) y parcial (solo los 150 s realizados).

**En vivo contra el Backend:** `test/live/timed_exercise_live_test.dart`, que se omite sin Backend. Evidencia en
`docs/correcciones/evidencia/d-m1-backend-en-vivo.txt`.

| Caso | Resultado del Backend |
|---|---|
| 3 × 90 s registrado con una serie (lo que enviaba `main`) | 33,33 %, PARTIAL |
| 3 × 90 s con «Lo completé» de la app (270 s) | 100 %, COMPLETED. Sesión al 100 %, COMPLETED |
| Sesión con un ejercicio parcial (75 de 120 s) | Ejercicio al 62,5 %, PARTIAL. Sesión al 95,31 %, exactamente la media de sus 8 ejercicios |
| Registro de la rutina completa («Ya lo hice») con 4 ejercicios por tiempo | Cada uno con series × segundos. Sesión al 100 % |
