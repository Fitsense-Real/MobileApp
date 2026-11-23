# Notificaciones push de Kora (Firebase Cloud Messaging)

| | |
|---|---|
| Proyecto Firebase | `kora-fitpe` |
| App Android | `pe.fit.kora` |
| Contrato | El del Backend, **PR #82** (`docs/FitSense/notificaciones_push/CONTRATO_PUSH_MOBILE.md` y `EJEMPLOS_REALES_HTTP.md`). Esta PR no modifica el Backend |
| Identificador | **Firebase Installation ID (FID)**, nunca un token de registro FCM |

Compatibilidad punto por punto e incompatibilidades encontradas: `COMPATIBILIDAD_BACKEND_PR82.md`.

## Piezas

| Archivo | Qué hace |
|---|---|
| `lib/features/push/data/push_messaging.dart` | Firebase Messaging, solo en Android. `register()`, `onRegistered`, `unregister()` y `onUnregistered` de `firebase_messaging` 17. Mensajes en primer plano, toques, mensaje de arranque y *handler* de segundo plano. No usa `getToken()`, `onTokenRefresh` ni `deleteToken()` |
| `lib/features/push/data/push_device_repository.dart` | `PUT`, `GET` y `DELETE /api/v1/users/me/push-devices` y `GET`/`PUT /api/v1/users/me/notification-preferences`, con los nombres exactos del contrato: `installationId`, `platform`, `appId` (`pe.fit.kora`) y `appVersion`. Lee el código de error de `details[0]` |
| `lib/features/push/presentation/push_controller.dart` | Ciclo de sesión, renovación, desvinculación, deduplicación por `eventId` y navegación. También el estado de las preferencias |
| `lib/features/push/data/push_notifier.dart` | Crea los canales `kora_planes` y `kora_cuenta` del contrato. Muestra el aviso con la app abierta (FCM no lo hace), con la misma agrupación que el Backend: `plan_semana` y `aviso_cuenta` |
| `lib/features/push/domain/push_event.dart` | Lee `schemaVersion`, `eventType`, `eventId`, `resourceType`, `resourceId`, `targetScreen`, `createdAt` y `noticeCode`. Traduce `targetScreen` a rutas |
| `lib/features/push/presentation/push_preferences_sheet.dart` | Perfil → **Avisos en el teléfono**: dos interruptores, «Cambios en mi plan» (`planUpdates`) y «Avisos de seguridad de mi cuenta» (`accountNotices`) |
| `AndroidManifest.xml` | `firebase_messaging_installation_id_enabled=true`: sin esta línea, el SDK nativo rechaza `register()`. Además, el ícono `ic_stat_kora` y el canal por defecto `kora_planes` |
| `lib/app/app.dart` | Escucha el usuario con sesión y reintenta al volver la app al primer plano |

## Ciclo de sesión

| Momento | Qué hace la app |
|---|---|
| **Inicio de sesión** y **cada arranque con sesión** | Si Android permite notificaciones, llama a `register()`. FCM entrega el FID por `onRegistered` (también si ya estaba registrado) y la app hace `PUT`. Respuestas: `201` la primera vez, `200` las siguientes |
| **`onRegistered` con un FID nuevo** | `PUT` con el nuevo |
| **`onUnregistered(fid)` con sesión** | `DELETE` con ese FID |
| **Cierre de sesión** (también por sesión caducada o cuenta eliminada) | Primero, `DELETE {"installationId": fid}` mientras el JWT sigue guardado. Después, `unregister()` con FCM: aunque el Backend no responda, el teléfono deja de recibir hasta el próximo inicio de sesión. La confirmación de ese `unregister()` nunca desvincula a la cuenta siguiente |
| **Otra cuenta en el mismo teléfono** | `PUT` con el mismo FID. El Backend revoca el vínculo anterior (`CAMBIO_DE_CUENTA`) |
| **Cambio de contraseña** | El JWT anterior da `401` y la app vuelve al inicio de sesión. El nuevo inicio de sesión repite el `PUT` y el dispositivo vuelve a recibir |
| **Sin permiso de notificaciones** | No se registra nada. Al volver a la app (después del diálogo o de los ajustes), se comprueba otra vez |

**Nada de esto bloquea el inicio de sesión:**
- sin Firebase, sin conexión, con el Backend caído o con `400`, la app sigue igual;
- el resultado queda en `PushController.state`;
- se reintenta en el próximo arranque o al volver la app al primer plano;
- un `409` (dos `PUT` simultáneos) se reintenta una vez.

**El `DELETE` del cierre de sesión no provoca un segundo cierre de sesión:** se marca con `AuthInterceptor.quietUnauthorized`, así que su `401` no cuenta como sesión caducada.

**Si FCM entrega un token en lugar de un FID,** la app **no lo envía**. Ocurre con Google Play services anteriores a la versión con envío directo (26.12): el SDK vuelve en silencio al token clásico, y el Backend lo rechazaría con `IDENTIFICADOR_PUSH_INVALIDO`.

## Mensajes

| `eventType` | `targetScreen` | Canal | Al tocar |
|---|---|---|---|
| `PLAN_GENERATED` | `WEEKLY_PLAN` | `kora_planes` | «Preparación de cuenta», que muestra el resultado, el recorrido de Kapi o el Inicio según el estado |
| `PLAN_ADAPTED` | `WEEKLY_PLAN` | `kora_planes` | Inicio (plan de la semana) |
| `WEEKLY_PLAN_READY` | `WEEKLY_PLAN` | `kora_planes` | Inicio |
| `ACCOUNT_NOTICE` (`PASSWORD_CHANGED`) | `ACCOUNT_SECURITY` | `kora_cuenta` | Perfil |
| Otro tipo | Según `targetScreen` | Según `targetScreen` | Inicio si tampoco se conoce `targetScreen` |

- **Con la app abierta:** los eventos de plan recargan el plan. `PLAN_GENERATED` además consulta la generación al momento, si la app la estaba esperando.
- **Deduplicación:** la app descarta un `eventId` repetido, tanto al mostrar el aviso como al abrirlo.
- **Datos que lleva el mensaje:** ninguno de salud. Al tocarlo, la app recarga el plan con su JWT.

## Lo que no cambia

- **Recordatorios locales.** El aviso local del lunes y un `WEEKLY_PLAN_READY` pueden coincidir; ver `COMPATIBILIDAD_BACKEND_PR82.md`.
- **Kapi, rutinas, favoritos, adherencia y reglas deportivas.**
- **Autenticación por JWT.** Firebase no autentica.

## Sin `google-services.json` o fuera de Android

En la web, o si falta el archivo:
- la app compila y funciona;
- el push queda apagado;
- solo se ve un aviso en el log de depuración.

## Documentos

- `COMPATIBILIDAD_BACKEND_PR82.md`: el contrato del Backend frente a la app, y las incompatibilidades encontradas.
- `PRUEBAS_PUSH_E_IDENTIFICADOR.md`: verificaciones hechas, la prueba integral en Android y lo pendiente.
- `INCORPORAR_CONFIGURACION_FIREBASE.md`: cómo se incorporaron los archivos de FlutterFire (hecho en `62083b2`).
- `evidencia/`: salidas de las pruebas.
