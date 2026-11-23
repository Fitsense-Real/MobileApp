# Compatibilidad del Mobile con el contrato push del Backend (PR #82)

**Fuentes:** Backend PR #82 (`cc703fb`), con `CONTRATO_PUSH_MOBILE.md` y `EJEMPLOS_REALES_HTTP.md`. El Backend no se
modificó: este documento sustituye la propuesta anterior del Mobile (token FCM y `PUT {token}`), que queda descartada.

## 1. Lo que el Backend espera (§7 de su contrato) y cómo lo cumple la app

| # | Expectativa del Backend | Mobile (PR #17) | Comprobado en |
|---|---|---|---|
| 1 | `firebase_messaging` ≥ 17.0.0, con `register()` / `onRegistered`, nunca `getToken()` | 17.1.0. `register()`, `onRegistered`, `unregister()` y `onUnregistered`. Ninguna API del token, y una prueba lo vigila | `push_messaging.dart`; `android_identifier_test.dart` |
| 2 | `applicationId` `pe.fit.kora` | Valor por defecto. `PushDeviceRepository.appId` es igual al de Gradle, y una prueba lo vigila | `aapt dump badging`; `android_identifier_test.dart` |
| 3 | URL base con `/api/v1` y exactamente los nombres de campo del §3 | `{"installationId","platform":"ANDROID","appId":"pe.fit.kora","appVersion"?}` byte a byte como en los ejemplos reales. `/api/v1` aparece una sola vez, también si la base termina en `/` | `push_notifications_test.dart` (contrato HTTP); prueba en vivo |
| 4 | `DELETE` con el FID antes de borrar el JWT al cerrar sesión | `DELETE /api/v1/users/me/push-devices` con `{"installationId": "<FID>"}`, y después `unregister()` con FCM. Un `401` en ese `DELETE` no provoca otro cierre de sesión | Pruebas del controlador; prueba en vivo (`DESVINCULADO`) |
| 5 | Deduplicación por `eventId`; canales `kora_planes` y `kora_cuenta` | Los dos canales se crean al arrancar. `kora_planes` es el canal por defecto del manifiesto. `eventId` repetido → descartado | `push_notifications_test.dart` (canales y mensajes) |
| 6 | Traducción de `targetScreen` a rutas | `WEEKLY_PLAN` → Inicio (`PLAN_GENERATED` → Preparación de cuenta, que decide). `ACCOUNT_SECURITY` → Perfil | `push_notifications_test.dart` |

**Contrato §3, §4 y §5**, también cubiertos:

| Parte del contrato | Cobertura en la app |
|---|---|
| `GET /push-devices` (`installationIdHint`, `receivesNotifications`) | Leído |
| Preferencias `GET`/`PUT` (`planUpdates`, `accountNotices`, los dos obligatorios) | Perfil → Avisos en el teléfono |
| Errores `400` con `details[0]` | Se lee el código (`IDENTIFICADOR_PUSH_INVALIDO`, `APLICACION_NO_ADMITIDA`, `PLATAFORMA_NO_ADMITIDA`, `CUENTA_NO_ACTIVA`) |
| `401` | Sesión caducada → inicio de sesión |
| `409` | Se reintenta una vez |
| Cambio de cuenta | Se repite el `PUT` |
| Cambio de contraseña | Nuevo inicio de sesión → nuevo `PUT` |
| Eliminación de cuenta | El `DELETE` posterior da `401` y se ignora en silencio |
| `onUnregistered` | `DELETE` con ese FID |

**Prueba en vivo:** el código del Mobile se ejecutó contra el Backend de la PR #82 en local
(`evidencia/prueba-integral-backend-pr82.txt`). Pasaron:
- registro (`201`) y renovación (`200`, mismo `deviceId`);
- `GET` sin el FID completo;
- preferencias;
- rechazo de un token FCM (`IDENTIFICADOR_PUSH_INVALIDO`) y `401` sin JWT;
- cambio de cuenta (`CAMBIO_DE_CUENTA`);
- `DELETE` idempotente (`DESVINCULADO`);
- fila activa en PostgreSQL con el FID enviado por la app;
- evento `PLAN_GENERATED` tras una generación asíncrona;
- intento de entrega dirigido a ese FID.

## 2. Incompatibilidades y riesgos encontrados

| # | Hallazgo | De quién | Efecto | Estado |
|---|---|---|---|---|
| **A** | **El Backend no arranca con el push activado y credenciales que se pueden leer.** `firebase-admin` 9.11.0 usa `JacksonFactory` (`google-http-client-jackson2`) como `JsonFactory` por defecto de `FirebaseOptions`. Esa librería llegaba a través de `google-cloud-firestore`, y la PR #82 excluye Firestore. Sus pruebas no lo ven porque solo arrancan sin credenciales o con credenciales inválidas | **Backend** | En Railway, con `FITSENSE_PUSH_ENABLED=true` y la cuenta de servicio real, el arranque falla: `NoClassDefFoundError: com/google/api/client/json/jackson2/JacksonFactory` (`evidencia/arranque-backend-pr82-sin-jackson2.txt`) | **Resuelto en el Backend `7abf3a1`** (`firebase-admin` 9.12.0). Comprobado: el jar sin modificar arranca con el push activado y credenciales sintéticas (`evidencia/registro-temprano-backend-pr82.txt`) |
| **B** | **`register()` necesita una línea en el manifiesto** que el contrato no menciona: `firebase_messaging_installation_id_enabled=true`. Sin ella, el SDK nativo de FCM 26 lanza «API disabled» | Mobile (contrato incompleto) | Sin la línea, no habría FID | **Resuelto en la app** y vigilado por una prueba. Conviene añadirlo al §7 del contrato |
| **C** | **El envío por FID exige Google Play services 26.12 o posterior** (marzo de 2026). Con uno anterior, el SDK vuelve en silencio al token clásico | Plataforma | Esos teléfonos no recibirían push | La app detecta que no es un FID y **no lo envía**: evita el `400` y no rompe nada. Los teléfonos actualizados reciben con normalidad. En emulador hace falta una imagen con Google Play reciente |
| **D** | **La consola de Firebase** («Enviar mensaje de prueba») está pensada para tokens de registro. Puede no aceptar un FID | Herramientas | La prueba manual desde la consola puede no servir | La prueba real se hace con el envío del Backend (`PRUEBAS_PUSH_E_IDENTIFICADOR.md` §2) |
| **E** | **`WEEKLY_PLAN_READY` y el aviso local del lunes** («tu plan de la semana está listo») pueden avisar de lo mismo | Producto | Dos avisos parecidos el lunes, si el usuario tiene los dos activados | Sin cambios: la orden prohíbe modificar los recordatorios locales. Se decide aparte |
| **F** | **`PLAN_ADAPTED` abre Inicio**, no Progreso como en la propuesta anterior, porque el Backend manda `targetScreen = WEEKLY_PLAN` | — | — | Alineado con el Backend |

**No queda ninguna incompatibilidad de contrato HTTP ni de formato de mensaje entre la app y la PR #82.** La integración
se probó satisfactoriamente en un celular real, según informó el propietario el 2026-11-23 (`PRUEBAS_PUSH_E_IDENTIFICADOR.md`
§3). La configuración de credenciales en Railway queda fuera de esta PR.
