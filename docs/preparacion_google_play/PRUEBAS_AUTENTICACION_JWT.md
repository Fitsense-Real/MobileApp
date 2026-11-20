# Autenticación y JWT con el backend 5977d28

No se cambió la estructura del JWT.

## Cómo usa la app el token

| Aspecto | Comportamiento |
|---|---|
| ¿Lee el correo del JWT (S-2)? | **No.** Flutter no decodifica el JWT: el id, el correo y el nombre salen de `GET /users/me`. Si el backend quita el correo del JWT (S-2), la app no cambia |
| Almacenamiento | `flutter_secure_storage` (Keystore en Android) |
| Envío | `Authorization: Bearer` desde `AuthInterceptor` |
| 401 en un endpoint protegido | El interceptor borra el token una sola vez, aunque lleguen varios 401 a la vez, y lleva al login con «Tu sesión no es válida» |
| Error de red | El token **no** se borra: solo se borra cuando el servidor lo rechaza |
| Renovación | El backend no tiene refresh token; el JWT dura 7 días (`authorization.jwt.expiration.days=7`). Al caducar llega un 401 → login. No se inventó un endpoint de renovación |
| Cerrar sesión | Cancela los recordatorios y borra el token. Las preferencias por cuenta (`kora_*_<id>`) solo se borran al eliminar la cuenta |

## Pruebas con el backend real

| Caso | Evidencia | Resultado |
|---|---|---|
| Login correcto / incorrecto | E2E | 200 entra / 401 «Correo o contraseña incorrectos», sigue en el login |
| Cambio de contraseña por recuperación | `recuperar.js`, `E-sesion-antigua` | El JWT anterior da 401 (V61 `token_version`). La otra sesión, al recargar, borra el token y muestra el login |
| Contraseña antigua tras el cambio | `E-login-antigua` | 401 |
| Cuenta eliminada: token anterior | `contratos-1.txt` | `GET /users/me` 401 |
| Cuenta eliminada: login | `F-login-tras-eliminar` | 401, sigue en el login |
| Eliminación pendiente (202): login | `eliminar-pendiente.js` | 401: la cuenta ya está `DELETED` |
| Reautenticación de la eliminación fallida ×5 | `eliminar-maria*.js` | 429 solo en `DELETE /users/me`; el login sigue funcionando (200) |
| Volver a registrarse con el correo de una cuenta eliminada | HTTP | 201, cuenta nueva sin datos de la anterior |

## Efectos secundarios revisados

- **Reautenticación al eliminar**: va dentro del propio `DELETE`. No crea un JWT nuevo ni cambia la
  sesión si falla.
- **403 o 429 al eliminar**: no cierran la sesión ni borran datos locales.
- **401 durante la eliminación**: la app lo trata como sesión caducada. No borra la cuenta local ni
  afirma nada sobre el servidor.
- **Varias cuentas en el mismo teléfono**: al eliminar una, solo se borran sus claves `kora_*_<id>`
  (prueba de widget).

## Pruebas automáticas

- `account_deletion_test.dart`: 401, 403 y 429 sin cerrar la sesión.
- `backend_alignment_test.dart`: 401 en recuperación y mensajes.
- `session_expiry_test.dart` (401 global, órdenes anteriores): sigue en verde.
