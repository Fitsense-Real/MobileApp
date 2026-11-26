# P2 · Historial de adaptaciones comprensible

**Rama:** `claude/p2-historial-adaptaciones`, sobre `generation` `6be9aef` (con O20 y la PR #20).

**Alcance:** solo textos de Mobile.

- No cambia el Backend, sus reglas de adaptación ni los datos.
- No cambia O20 ni D-M1.

## Problema

El historial de planes mostraba el campo `adjustmentApplied` tal cual, por ejemplo `ADAPT_LOCALIZED`.

Según el Backend, ese campo es **el nombre de la decisión, «también cuando nada se cambió»** (`AdaptationOutcome`, `AdaptedPublication.etiquetaDeAjuste`). Por eso no se puede traducir como «se ajustó tu rutina»: lo que de verdad pasó lo dice `resultado` en `GET /users/me/plan/adaptations`.

## Valores reales del Backend (`generation` 98276a9)

### `resultado` (lo que pasó en la semana)

| Código | Texto en la app | Tipo |
|---|---|---|
| `ADAPTACION_APLICADA` | Se ajustó parte de tu rutina | Cambió |
| `REGENERACION_SEGURA_SUSTITUCION` | Se sustituyó un ejercicio por seguridad | Cambió |
| `REGENERACION_SEGURA_REGLAS` | Se preparó una semana nueva que respeta tus restricciones | Cambió |
| `PROGRESION_DEL_BACKEND` | Tu rutina avanzó un paso | Cambió |
| `SIN_ADAPTACION` | Tu rutina se mantiene igual | Se mantuvo |
| `CONSERVACION_DELIBERADA` | Tu rutina se mantiene igual: no había nada que cambiar | Se mantuvo |
| `SIN_CAMBIOS_VALIDOS` | Se revisó tu rutina, pero no hubo un cambio aplicable: se mantiene igual | Se mantuvo |
| `RESPALDO_PROPUESTA_IA_INVALIDA` | Se propuso un ajuste que no pasó las comprobaciones de seguridad: tu rutina se mantiene igual | Propuesta rechazada |
| `RESPALDO_SIN_IA` | No se pudo preparar un ajuste esa semana: tu rutina se mantiene igual | Se mantuvo |
| `ACORTAMIENTO_IMPOSIBLE` | No era posible acortar más tus sesiones: tu rutina se mantiene igual | Se mantuvo |
| `REPROGRAMACION_IMPOSIBLE` | No era posible cambiar los días de tus sesiones: tu rutina se mantiene igual | Se mantuvo |
| `ADAPTACION_IMPOSIBLE` | No había un ajuste posible dentro de tus condiciones: tu rutina se mantiene igual | Se mantuvo |
| `RECHAZADA` (estado sin traducción propia en el Backend) | Se propuso un ajuste que no se aplicó: tu rutina se mantiene igual | Propuesta rechazada |
| `NO_FACTIBLE_POR_SEGURIDAD` | Kora no pudo adaptar esa semana sin volver a proponer lo que te dolió. Además: «No se publicó una rutina nueva para esa semana.» | No factible |
| `NO_FACTIBLE` | Kora no pudo adaptar esa semana dentro de tus restricciones. Además: «No se publicó una rutina nueva para esa semana.» | No factible |
| Cualquier otro | Kora revisó tu plan de esa semana. El código se registra para diagnóstico y **no se muestra** | Desconocido |

### `decision` (por qué se revisó la semana)

`decision` viene de `AdaptationDecision` y se muestra como explicación secundaria. En la semana de progresión se usa la explicación de la progresión.

| Código | Texto |
|---|---|
| `NO_CHANGE` | Tus registros no mostraban baja adherencia, así que no hacía falta un ajuste. |
| `INSUFFICIENT_DATA` | Aún faltaban entrenamientos registrados para evaluar cambios. |
| `ADAPT_LOCALIZED` | Algunas sesiones tuvieron menos cumplimiento: Kora revisó esas sesiones. |
| `ADAPT_EXPANDED` | Varias sesiones tuvieron menos cumplimiento: Kora revisó varias sesiones. |

### Qué cambió

Solo con datos que envía el Backend:

- **`sesionAfectada`:** «Sesión revisada: jueves 05/11 (Tren superior).»
- **`sesiones`:** «N sesiones con cambios» (APLICADA) y «N sesiones con un paso de progresión» (PROGRESADA).
- **Motivo:** `motivoTexto`, el texto neutro del Backend.
- **`motivos` no se muestra:** puede contener textos internos de validación, por ejemplo «V24: el ejercicio 498…».

### Etiqueta corta en el historial de planes

- **Con registro de adaptación del plan:**
  - Progresión;
  - Sustitución por seguridad;
  - Semana nueva por seguridad;
  - Rutina ajustada;
  - Sin cambios.
- **Sin ese registro**, la etiqueta sale de `adjustmentApplied`, sin afirmar un cambio:
  - `ADAPT_LOCALIZED` → «Revisión de parte de tu rutina»;
  - `ADAPT_EXPANDED` → «Revisión de varias sesiones»;
  - `SAFETY_REPAIR` → «Ajustada por seguridad»;
  - `AdjustmentType` → «Menos volumen», etc.;
  - `NONE` → no se muestra;
  - un código desconocido → «Plan ajustado», y el código se registra para diagnóstico.

## Dónde se ve

- **Perfil → Historial de planes:** etiqueta corta por semana. Al abrir una semana, la tarjeta de la adaptación muestra el título, el motivo y qué cambió (captura `capturas/historial-de-planes.png`).
- **Progreso → «Historial de adaptaciones»:** todas las semanas, la más reciente primero, incluidas las `NO_FACTIBLE` sin rutina (captura `capturas/historial-adaptaciones-progreso.png`, con las respuestas reales de la cuenta demo).

## Pruebas

**`test/adaptation_history_test.dart`** (12):

1. adaptación localizada;
2. adaptación ampliada;
3. sin cambios (respuesta real de la demo);
4. datos insuficientes;
5. no factible: sin presentar una rutina inexistente y sin mostrar `motivos` internos;
6. resultado desconocido: texto general, código registrado y no mostrado;
7. historial de varias semanas con las respuestas reales de la demo, sin códigos en pantalla;
8. actualización después de consultar de nuevo el Backend.

Además:

- progresión (respuesta real);
- todos los resultados del Backend tienen texto sin códigos;
- se distingue la adaptación aplicada de la propuesta rechazada;
- los datos no se alteran;
- etiquetas del historial.

**También se actualizaron:**

- `test/o20_demo_kora_app_test.dart`: el historial de la demo sin `ADAPT_LOCALIZED` y con la sección nueva en Progreso.
- `test/backend_alignment_test.dart`: el motivo del Backend aparece ahora también en la sección nueva, por eso se espera dos veces.
