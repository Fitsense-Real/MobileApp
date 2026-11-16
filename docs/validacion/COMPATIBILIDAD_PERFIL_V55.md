# Compatibilidad del perfil con el backend actual, incluido V55 (fase 7)

Referencia: `CreateUserProfileResource`, `UpdateUserProfileResource` y `UserProfileResource` en
`generation` (`2578719`) y en #72 (`93549d5`), que son idénticos en estos archivos.

## Campos

| Campo del backend | Validación del backend | Flutter envía | Validación en Flutter |
|---|---|---|---|
| `birthDate` | `@NotNull @Past` | ✓ (calendario) | fecha real anterior a hoy |
| `biologicalSex` | opcional | ✓ | opcional |
| `heightCm` | 120–250 | ✓ | 120–250 |
| `currentWeightKg` | 30–300 | ✓ | 30–300 |
| `targetWeightKg` | opcional, 30–300 | ✓ | opcional, 30–300 |
| `fitnessLevel` | `@NotNull` | ✓ | obligatorio |
| `goalType` | `@NotNull` | ✓ | obligatorio |
| `goalText` | `@NotBlank`, ≤ 500 | ✓ | obligatorio, ≤ 500 |
| `trainingLocation` | `@NotNull` | ✓ (Casa/Gimnasio/Ambos) | obligatorio |
| `daysPerWeek` | 1–7 | ✓ (= días marcados) | 1–7 y máximo por nivel |
| `availableDays` | no vacío, 1–7 | ✓ | lunes=1 … domingo=7 |
| `sessionMinutes` | 15–180 | ✓ | entero 15–180 |
| `equipmentCodes` | lista | ✓ (catálogo real) | buscador; HOME filtra gimnasio |
| `blockedExerciseIds` | lista | ✓ (buscador del catálogo) | — |
| `healthNotes` | ≤ 500 | ✓ | ≤ 500 |
| `allowHighImpact`, `allowFloorExercises`, `allowKneelingExercises`, `allowHangingExercises`, `allowOverheadExercises` (V25) | `Boolean`, omitido = admitido | ✓ (5 interruptores) | — |

Flutter envía **exactamente** estos 20 campos (`createProfileFields`) y en la actualización omite
`birthDate`. Los errores 400/422 del backend se muestran con su mensaje (`apiError`).

## V55 — permiso «apoyo suspendido»

| Pregunta | Respuesta |
|---|---|
| ¿Qué añade V55? | Dos columnas en `user_profiles`: `allow_suspended_support` (NULL = sin responder, hereda «no colgarse») y `suspended_support_confirmed_at` |
| ¿Lo acepta la API? | **No.** Ninguno de los tres recursos REST del perfil tiene el campo; solo lo leen la entidad y el `ProfileSnapshot` interno |
| ¿Está activo? | No: depende de `fitsense.seguridad.permiso-apoyo-suspendido`, apagado por defecto. Con él apagado, nada usa las columnas |
| ¿Qué hace Flutter? | No lo envía ni lo muestra. Es lo correcto: no puede enviar un campo que la API ignora, y la orden prohíbe inventar controles que el backend no pide |

Cuando el backend exponga el campo en la API y active el permiso, hará falta un interruptor más en el
paso 5 del perfil (anotado en RIESGOS_PENDIENTES.md).

## Pruebas

- `test/profile_contract_v55_test.dart` (2):
  - `createProfileFields` es igual a la lista literal del record del backend;
  - no contiene ningún campo de apoyo suspendido.
- `test/backend_alignment_test.dart` (existente): el `POST` envía solo esos campos, descarta campos
  desconocidos y el `PUT` omite `birthDate`.
- E2E: el perfil creado desde la app (`POST /users/me/profile` 201) generó un plan válido.

Ningún cambio en el código del perfil: no había incompatibilidades.
