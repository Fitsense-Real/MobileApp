# Eliminación de cuenta: integración con el backend real (5977d28)

## Cliente ajustado al contrato

En `14c7241`, sobre la rama de #7:

- **Una sola petición**: `DELETE /api/v1/users/me` con `{"password": …, "confirm": true}`. Se quitó el
  login aparte: la reautenticación la hace el backend.
- **Estados de la app** (`AccountDeletionController`): `idle`, `inProgress`, `pending`, `completed`,
  `gone`, `failed`.
- **Un solo envío**: el controlador ignora nuevas pulsaciones mientras hay uno en curso, y durante un
  bloqueo 429.
- **Datos locales**: solo con 200, 202 o 404 se borran (recordatorios, tour, favoritos, JWT) y se cierra
  la sesión. Las otras cuentas del teléfono se conservan.
- **429 sin `Retry-After` legible** (`d96f4ab`, en #8): el botón se pausa 1 minuto. Ver B-1 en
  `CONTRATOS_BACKEND_ACTUALIZADOS.md`.

| Respuesta | Pantalla | Sesión y datos locales |
|---|---|---|
| 200 `DELETED` | «Tu cuenta fue eliminada» | se borran |
| 202 `PENDING` | «Solicitud recibida»: la cuenta quedó desactivada y la eliminación todavía no está terminada; si no se completa, escribe al equipo del estudio (nunca «eliminada»). Con `alreadyRequested`: «Ya habías solicitado…» | se borran |
| 404 | «Tu cuenta ya no existe» | se borran |
| 403 | «La contraseña no es correcta. No se eliminó nada…» | se conservan |
| 429 | «Demasiados intentos… espera N minutos / unos minutos… No se eliminó nada.» Botón desactivado | se conservan |
| 401 | «Tu sesión ya no es válida…» | se conservan |
| 405 / 501 | «todavía no está disponible en este servidor» | se conservan |
| 5xx / 503 | «El servidor no pudo registrar la solicitud. No se eliminó nada…» | se conservan |
| sin red (no conecta) | «No hay conexión…» | se conservan |
| sin respuesta tras enviar (timeout, corte) | «No recibimos la respuesta… no sabemos si la eliminación se registró» (nunca «No se eliminó nada») | se conservan |
| 401 después de un intento sin respuesta | «Tu cuenta probablemente ya se eliminó» | se borran |
| 403 que no es `REAUTENTICACION_FALLIDA` | «El servidor rechazó la solicitud…» | se conservan |
| 200 inesperado (sin `DELETED`) | error, «No se eliminó nada» | se conservan |

**Retirarse del estudio** (`POST /users/me/withdraw`) sigue siendo otra opción, en Perfil → Cuenta. No
borra la cuenta.

## Pruebas con el backend real (app web, PostgreSQL)

Capturas en `integracion_backend_5977/capturas/F-*`.

| Caso | Cuenta | Resultado |
|---|---|---|
| Pantalla y confirmación | María | `F-eliminar-pantalla`, `F-eliminar-confirmar` |
| Cancelar en el diálogo | María | 0 `DELETE` enviados |
| Contraseña incorrecta | María, Lucas | 403; mensaje, nada borrado, se puede corregir (`F-eliminar-403`) |
| 5 fallos y luego otro intento | María | 403 ×5, luego 429. Con el arreglo `d96f4ab`: mensaje «espera unos minutos», botón desactivado y **un solo** `DELETE` (`F-eliminar-429`). La cuenta sigue `ACTIVE` |
| Bloqueo de eliminación y login | María | El login sigue funcionando (200): el bloqueo solo afecta a la eliminación |
| Doble y triple toque en «Eliminar» | Lucas | Un solo `DELETE` |
| Cuenta con rutina, sesiones, historial, métricas, intervención, adaptación y generación en curso | Lucas | **200** «Tu cuenta fue eliminada» (`F-eliminar-200`) |
| Eliminación pendiente | Diego (`del4`) | psql retuvo una fila de su plan 40 s → **202**, «Solicitud recibida… desactivada» (`F-eliminar-202`). En la base `PENDIENTE`, `users.status=DELETED` y `last_error=UncategorizedSQLException/PSQLException`. El reintento programado la completó a los 2 min (`COMPLETADA`, intento 2) |
| Login durante la eliminación pendiente | Diego | 401, sigue en el login |
| Login después de eliminar | Lucas | 401, sigue en el login (`F-login-tras-eliminar`) |
| Registrarse de nuevo con el mismo correo | Lucas | 201: cuenta **nueva** (id 14), sin datos de la anterior |
| Datos locales tras 200 | Lucas | Solo queda la clave interna `FlutterSecureStorage`; el JWT ya no está |

La «generación en curso» de Lucas se simuló insertando en la base de pruebas una operación
`PROCESSING` arrendada a otra instancia (`evidencia/generacion-en-curso-lucas.sql`). La eliminación la
marcó `FAILED`/`CUENTA_ELIMINADA` en la fase 1 y la borró en la fase 2.

## PostgreSQL después de eliminar a Lucas

`evidencia/pg-lucas-antes.txt` → `evidencia/pg-lucas-despues.txt`:

| Tabla | Antes | Después |
|---|---|---|
| `users` | 1 | 0 |
| `user_profiles` | 1 | 0 |
| `user_consents` | 1 | 0 |
| `weekly_training_plans` | 2 | 0 |
| `planned_workouts` | 4 | 0 |
| `workout_sessions` | 1 | 0 |
| `workout_session_exercises` | 7 | 0 |
| `weekly_user_metrics` | 1 | 0 |
| `user_interventions` | 1 | 0 |
| `plan_adaptation_attempts` | 1 | 0 |
| `plan_generation_operations` | 2 | 0 |
| `password_reset_tokens` | 0 | 0 |

`account_deletions` conserva el registro de la eliminación (`evidencia/pg-account-deletions.txt`):
`COMPLETADA`, `user_id` NULL, sin correo, y el recuento por tabla en `rows_deleted`. **No quedan datos
personales de la cuenta.**

## Pruebas automáticas

`test/account_deletion_test.dart`: 18 pruebas contra un adaptador con el contrato real. Cubren:

- 200, 202, 202 con `alreadyRequested`, 404 y 403 (con corrección posterior);
- 429 con y sin `Retry-After`;
- 503, 500, 401, 405, sin conexión y 200 inesperado;
- doble toque, cancelar, usuario sin sesión, explicación;
- el retiro del estudio como petición distinta.
