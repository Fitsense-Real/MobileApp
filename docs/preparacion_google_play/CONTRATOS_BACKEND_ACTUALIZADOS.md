# Contratos del backend 5977d28 comprobados por HTTP

## Entorno

- **Backend**: `Fitsense-Real/Backend` `generation` = `5977d28`, en una copia de trabajo aparte y sin
  cambios.
- **Base**: PostgreSQL 16 local y nueva (`fitsense_int`). Flyway aplicó 66 migraciones, V60–V63
  incluidas:

  | Versión | Descripción |
  |---|---|
  | V60 | eliminación de cuentas |
  | V61 | versión de token |
  | V62 | solicitud de eliminación web |
  | V63 | consentimientos |

- **Una sola instancia**, con IA apagada (`fitsense.ai.enabled=false`: motor de reglas, sin Replicate).
- **Correo simulado**: `password-reset.delivery=email` con SMTP a un servidor local que guarda cada
  mensaje como `.eml`. No sale ningún correo real.
- **Usuarios sintéticos** `*@e2e.local`.
- Ciclo manual activado solo en local (`fitsense.cycle.manual-run.enabled=true`).
- Arranque: `integracion_backend_5977/evidencia/arnes/run-backend.sh` (secretos locales redactados).
- Respuestas completas en `integracion_backend_5977/evidencia/contratos-*.txt`. Las contraseñas aparecen
  como `***` y los códigos reales, redactados.

## Eliminación de cuenta: `DELETE /api/v1/users/me`

El 405 anterior **desapareció**: el endpoint existe y responde según `DeleteAccountResource`.

| Petición | Respuesta |
|---|---|
| sin cuerpo | 400 «El cuerpo de la solicitud no es valido.» |
| `{password}` o `confirm:false` | 400 `CONFIRMACION_REQUERIDA` |
| contraseña incorrecta | 403 `REAUTENTICACION_FALLIDA` |
| 6.º intento tras 5 fallos | 429 `DEMASIADOS_INTENTOS` + `Retry-After: 899` (15 min) |
| correcta | 200 `{status:"DELETED", deletionId, requestedAt, completedAt}` |
| fase 2 no termina (bloqueo > 5 s) | 202 `{status:"PENDING", deletionId, requestedAt, alreadyRequested?}`; la cuenta queda `DELETED` (sin acceso) y un `@Scheduled` reintenta (inicio 60 s, luego cada 300 s) |
| cuenta inexistente | 404 `CUENTA_INEXISTENTE` |
| no se pudo registrar | 503 `ELIMINACION_NO_REGISTRADA` |
| después | el token anterior da 401 y el login da 401 |

La eliminación web (`/api/v1/account-deletion/requests`, `/confirm`, `/requests/{reference}`) es para la
página pública. Mobile no la consume.

## Recuperación de contraseña

| Petición | Respuesta |
|---|---|
| `POST /auth/password-reset/request {email}` con un correo registrado o inexistente | 202, con el mismo mensaje neutro |
| más de 3 por hora y correo | 429 |
| `POST /auth/password-reset/confirm {token, newPassword}` correcto | 204 |
| código inexistente, usado o caducado (30 min) | 400 «El codigo de recuperacion no es valido o ha caducado.» |
| `newPassword` fuera de 8–72 | 400 de validación |
| después del cambio | el JWT anterior da 401 (V61 `token_version`); la contraseña antigua 401 y la nueva 200 |

El código es una cadena de 43 caracteres de un solo uso. **No es un enlace.**

## Edad mínima (`POST /users/me/profile`)

| Fecha de nacimiento | Respuesta |
|---|---|
| exactamente 18 años hoy | 201 |
| cumple 18 mañana / 17 años | 422 «Debes tener al menos 18 anos para usar la aplicacion.» |
| fecha futura | 400 «birthDate: must be a past date» |

## Consentimientos versionados (V63)

- `GET /users/me/consents` →
  ```json
  {"currentVersions": {"STUDY_PARTICIPATION": "MVP-1.0", "TERMS_OF_SERVICE": null, "PRIVACY_POLICY": null},
   "enforcedOnSignup": false, "history": [...]}
  ```
- `POST /users/me/consents {type, documentVersion}` → 201 solo con la versión vigente. Sin versión
  aprobada: 422 «Todavia no hay una version aprobada de TERMS_OF_SERVICE: no se puede aceptar.».
- `POST /users/me/consents/{type}/withdraw`: solo `STUDY_PARTICIPATION`.
- `POST /auth/register` acepta `acceptedTermsVersion` y `acceptedPrivacyVersion` (opcionales; 422 si no
  hay versión aprobada).
- Las versiones vigentes solo se leen con sesión. **No hay endpoint público** para mostrarlas antes del
  registro.

## Autenticación

- El filtro Bearer solo admite cuentas `ACTIVE` cuyo `token_version` coincida con el del JWT.
- Flutter **no decodifica el JWT**: el correo y el id salen de `GET /users/me`, así que el cambio S-2 del
  backend no afecta a la app.

## Defectos o huecos del backend (documentados, sin modificar el backend)

| # | Hallazgo | Reproducción mínima | Efecto en Mobile |
|---|---|---|---|
| B-1 | Falta `Access-Control-Expose-Headers: Retry-After` | `curl -D - -X DELETE /api/v1/users/me -H 'Origin: http://localhost:5050' …` tras 5 fallos: llega `Retry-After: 839` pero no `Access-Control-Expose-Headers` | Solo en navegador: la app no ve la espera. Mitigado en `d96f4ab`. En Android nativo la cabecera se lee |
| B-2 | Mensaje de edad sin «ñ» («anos») | perfil con 17 años → 422 | La app lo sustituye por su propio texto |
| B-3 | Mensajes sin tildes en general («contrasena», «codigo») | cualquier 4xx | La app usa sus propios textos para los casos conocidos |
| B-4 | No hay endpoint público de versiones de consentimiento | `GET /users/me/consents` sin token → 401 | Si se activa `enforce-on-signup`, la app no puede enviar `acceptedTermsVersion` al registrarse |
| B-5 | `report` acepta un entrenamiento de una fecha futura | «Ya lo hice» sobre el del 27/11 con fecha del 20/11 → 201 `USER_REPORTED` | La app también lo ofrece (`canReportWorkout` con `SCHEDULED`). Decisión de producto pendiente |
| S-1 | Los logs incluyen correos (p. ej. «generacion para 8 (correo)») | `grep @ backend.log` | Sin cambios por orden expresa; no aptos para producción ni participantes reales |
