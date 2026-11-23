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
| `lib/features/push/presentation/push_permission_prompt.dart` | Hoja explicativa y petición del permiso, una vez por teléfono, al final de la configuración del perfil y antes del primer plan |
| `lib/features/push/data/notification_settings.dart` + `MainActivity.kt` | Abre los ajustes de notificaciones de Kora en Android, tras un rechazo |
| `AndroidManifest.xml` | `firebase_messaging_installation_id_enabled=true`: sin esta línea, el SDK nativo rechaza `register()`. Además, el ícono `ic_stat_kora` y el canal por defecto `kora_planes` |
| `lib/app/app.dart` | Escucha el usuario con sesión y reintenta al volver la app al primer plano |

## Ciclo de sesión

| Momento | Qué hace la app |
|---|---|
| **Inicio de sesión** y **cada arranque con sesión** (solo con la sesión confirmada y el JWT guardado; no tras crear la cuenta sin JWT) | Si Android permite notificaciones, llama a `register()`. FCM entrega el FID por `onRegistered` (también si ya estaba registrado) y la app hace `PUT`. Respuestas: `201` la primera vez, `200` las siguientes. El registro solo cuenta como hecho con esa respuesta, no al recibir el FID |
| **Antes de la generación automática del primer plan** | `FirstPlanGenerationController` espera a que termine ese registro (`PushController.ensureSynced`, máximo 10 s) y solo después pide la generación. Así `PLAN_GENERATED` encuentra el teléfono activo. Sin permiso, sin Firebase o con el Backend fallando, no espera: la generación sigue y el registro se reintenta al volver a la app. Retomar una operación ya pedida no espera nada |
| **`onRegistered` con un FID nuevo** | `PUT` con el nuevo |
| **`onUnregistered(fid)` con sesión** | `DELETE` con ese FID |
| **Cierre de sesión** (también por sesión caducada o cuenta eliminada) | Primero, `DELETE {"installationId": fid}` mientras el JWT sigue guardado. Después, `unregister()` con FCM: aunque el Backend no responda, el teléfono deja de recibir hasta el próximo inicio de sesión. La confirmación de ese `unregister()` nunca desvincula a la cuenta siguiente |
| **Otra cuenta en el mismo teléfono** | `PUT` con el mismo FID. El Backend revoca el vínculo anterior (`CAMBIO_DE_CUENTA`) |
| **Cambio de contraseña** | El JWT anterior da `401` y la app vuelve al inicio de sesión. El nuevo inicio de sesión repite el `PUT` y el dispositivo vuelve a recibir |
| **Sin permiso de notificaciones** | No se registra nada. Al volver a la app (después del diálogo o de los ajustes), se comprueba otra vez |

## Permiso de notificaciones: independiente de los recordatorios

Android tiene **un solo permiso** de notificaciones (`POST_NOTIFICATIONS`, Android 13+) para los avisos push y para los
recordatorios. Antes solo lo pedía el flujo de recordatorios, así que quien no los activaba no recibía avisos push.
Ahora:

| Momento | Qué pasa |
|---|---|
| **Final de la configuración del perfil**, al pulsar «Generar mi plan», **antes** de pedir la primera generación | Si Android aún no da el permiso, Kora muestra una hoja que explica para qué sirve: plan listo o actualizado y avisos de seguridad de la cuenta, sin datos de salud. **Activar avisos** abre el diálogo de Android; con el permiso, la app registra el FID con el JWT de la sesión, y la generación espera el `200`/`201` del Backend, así que el `PLAN_GENERATED` del primer plan puede llegar al teléfono. **Ahora no**, un rechazo o un fallo de Firebase no detienen nada: la generación sigue normalmente. La pantalla de 30 s empieza al responder la hoja |
| **Permiso ya concedido** (Android 12 o anterior, o concedido antes) | No se muestra la hoja: el teléfono se sincroniza directamente y la generación espera el `200`/`201` |
| **Generación ya iniciada** (reintento tras un fallo, o app reabierta durante una generación) | La hoja no se muestra, para no interrumpirla. El Inicio no la muestra nunca |
| **Siguientes inicios de sesión y arranques** | No se vuelve a preguntar: la respuesta queda guardada en el teléfono, aunque cambie la cuenta (`PushPermissionPrompt`, `kora_push_permission_prompted`) |
| **Si lo rechaza** | Kora funciona igual. En Perfil → **Avisos en el teléfono** aparece «Las notificaciones de Kora están desactivadas en este teléfono» con **Activar notificaciones**, que vuelve a pedir el permiso si Android lo permite o abre los ajustes del sistema para Kora (`MainActivity.kt`, canal `pe.fit.kora/settings`). Al volver, el teléfono se registra |
| **Recordatorios desactivados** | Los avisos push funcionan igual: solo dependen del permiso y de las preferencias de la cuenta |
| **Recordatorios ya guardados** | La hoja de push **nunca** los modifica ni los borra, sea cual sea la respuesta: días, hora, aviso de las 20:00 y el interruptor general quedan igual. Si el permiso está desactivado y los recordatorios activados, Perfil → Recordatorios muestra «Activa las notificaciones para recibir tus recordatorios», aclara que sus días, su horario y sus preferencias se conservan, y ofrece **Activar notificaciones**. Llegan en cuanto se activa el permiso |
| **Primera configuración de los recordatorios** (todavía nada guardado; llega en el mismo momento) | Espera a la respuesta de la hoja: un solo diálogo de Android. **Aceptar los avisos push no activa los recordatorios**: si la hoja se mostró alguna vez en el teléfono, con cualquier respuesta, empiezan desactivados, sin un segundo diálogo, y se activan cuando el usuario quiera en Perfil → Recordatorios. Si la hoja no se mostró nunca (Android 12 o anterior con el permiso ya concedido, o sin pantalla), siguen su primera configuración aprobada. Sus horarios, días y programación no cambian |

**Preferencias**, en Perfil → Avisos en el teléfono: «Cambios en mi plan» (`planUpdates`) y «Avisos de seguridad de mi
cuenta» (`accountNotices`). Se guardan en el Backend y son independientes entre sí y de los recordatorios.

**Sin peticiones duplicadas:** un inicio de sesión, la vuelta a la app y un `onRegistered` repetido comparten el mismo
registro en curso. El `PUT` del mismo usuario y FID se hace una sola vez.

**Desvinculación fallida al cerrar sesión:** queda en el registro de depuración y en `PushController.lastResult`. El
`unregister()` con FCM se hace igual, así que el teléfono deja de recibir. El Backend desvincula el FID en el siguiente
envío (`UNREGISTERED`) o cuando otra cuenta lo registra.

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
