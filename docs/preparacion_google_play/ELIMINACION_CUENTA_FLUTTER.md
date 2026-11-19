# Eliminación de cuenta desde Flutter (PR C)

## Problema

Solo existía «Retirarme del estudio» (`POST /users/me/withdraw`): deja de participar, **conserva la
cuenta y no borra datos**. Google Play exige poder **borrar la cuenta** desde la app y desde una página
web.

## Estado del backend (comprobado el 19/11/2026)

- `generation` (`a1ccf53`) **no tiene `DELETE /users/me`**: no hay `@DeleteMapping`, ni rama, ni PR que
  lo implemente.
- El backend real responde **405 Method Not Allowed** a `DELETE /users/me`, probado con `curl` y desde
  la app.
- La orden indica que el backend prepara `DELETE /users/me`. **Su contrato real todavía no existe**, así
  que la integración usa códigos REST estándar y debe revisarse cuando se publique.

## Qué se implementó

**Perfil → Cuenta → Eliminar mi cuenta**, una pantalla propia (`/cuenta/eliminar`), separada del retiro
del estudio, que se mantiene igual.

| Paso | Implementación |
|---|---|
| 1–2 | Perfil → Cuenta muestra «Retirarme del estudio» y, aparte, «Eliminar mi cuenta» |
| 3 | La pantalla explica: se pide al servidor eliminar la cuenta y se cierra la sesión; completada, no se puede volver a entrar; no se puede deshacer; retirarse del estudio es distinto |
| 4 | «Tus datos»: lo que ocurre con los datos del estudio se rige por el consentimiento informado y la política de privacidad. **No se inventa ninguna política de retención**, ni se afirma que todo se destruya. Enlaces a la política de privacidad y a la página web de eliminación, si están configurados |
| 5 | Contraseña, casilla «Entiendo que esta acción no se puede deshacer» y diálogo de confirmación |
| 6 | **Reautenticación** con el login existente (`POST /auth/login`): JWT nuevo y comprobación de que la contraseña es de **la misma cuenta** |
| 7 | `DELETE /users/me` con ese JWT |
| 8–9 | Estados distintos (abajo) |
| 10 | Solo si el backend completó o aceptó: se cancelan los recordatorios, se borran los datos locales de esa cuenta (`kora_welcome_<id>`, `kora_reminders_<id>`, `kora_favorites_<id>`) y el JWT, y se cierra la sesión. Las demás cuentas del teléfono se conservan |

### Respuestas y lo que muestra la app

| Respuesta | Estado | Mensaje | Sesión y datos locales |
|---|---|---|---|
| 200 / 204 | completada | «Tu cuenta fue eliminada» | se borran |
| 202 | **pendiente** | «Solicitud recibida… Todavía no está completada» (**nunca** «eliminada») | se borran |
| 401 en el login | contraseña incorrecta | «La contraseña no es correcta. No se eliminó nada.» No se envía el `DELETE` | se conservan |
| login de otra cuenta | — | «Esa contraseña corresponde a otra cuenta.» No se envía el `DELETE` | se conservan |
| 404 / 405 / 501 | servicio no disponible | «La eliminación de cuentas todavía no está disponible en el servidor. No se eliminó nada.» | se conservan |
| 5xx | error del servidor | «El servidor no pudo procesar la solicitud. No se eliminó nada…» | se conservan |
| sin red | sin conexión | «No hay conexión con el servidor. No se eliminó nada…» | se conservan |
| otros 4xx | rechazada | mensaje del backend (`ApiErrorResource`) | se conservan |
| varias pulsaciones | — | una sola solicitud | — |

### Activación controlada

La opción **solo aparece** con `--dart-define=ACCOUNT_DELETION_ENABLED=true`. Por defecto está oculta,
para que no parezca funcionar mientras no exista el servicio. No se muestra un botón desactivado de
«próximamente», el mismo motivo por el que se quitaron los accesos sociales.

Enlaces opcionales:

- `--dart-define=ACCOUNT_DELETION_WEB_URL=https://...`: página pública de eliminación (etapa web; no se
  inventó la URL);
- `--dart-define=PRIVACY_POLICY_URL=https://...`: política de privacidad.

El **AAB para Play se bloquea** si falta cualquiera de los tres. Así no puede salir una versión
publicable sin una eliminación que funcione.

## Pruebas

### Contratos simulados (`test/account_deletion_test.dart`, 13)

Cubren:

- usuario autenticado: explicación, términos del estudio y botón bloqueado hasta poner la contraseña
  y marcar la casilla;
- usuario sin sesión: pide iniciar sesión y no envía nada;
- confirmación cancelada: sin peticiones ni borrados;
- 204: login y después `DELETE`; sesión cerrada, recordatorios cancelados y claves de la cuenta
  borradas, conservando las de otra cuenta;
- 202: «Solicitud recibida», nunca «eliminada»;
- 500, 405, 404, sin conexión, contraseña incorrecta y contraseña de otra cuenta: no se elimina nada,
  la sesión y los datos locales se conservan, y sin reautenticación no hay `DELETE`;
- solicitud repetida: una sola `DELETE` y un solo login;
- retiro del estudio: es otra petición (`POST /users/me/withdraw`), conserva la cuenta y no borra nada
  del teléfono.

### Contra el backend real (E2E web, `capturas/F-05`…`F-08`)

- Perfil → Cuenta muestra «Retirarme del estudio» y «Eliminar mi cuenta».
- Login 200 y después `DELETE /users/me` **405**. La app mostró «todavía no está disponible… No se
  eliminó nada», no dijo «fue eliminada», la cuenta siguió en la base y la sesión siguió abierta.

## Lo que falta para activarla

1. **Backend**: implementar `DELETE /users/me` y publicar su contrato: códigos, si exige un cuerpo
   (por ejemplo la contraseña), si es inmediato (204) o diferido (202), y la política aprobada para los
   datos del estudio.
2. Revisar este cliente contra ese contrato (cambio mínimo si difiere) y repetir las pruebas.
3. Página web pública de eliminación y política de privacidad (sus URL).
4. Compilar con `ACCOUNT_DELETION_ENABLED=true` y las dos URL.

**Hasta entonces, esta versión no está lista para publicarse**, y el bloqueo del AAB lo impide.
