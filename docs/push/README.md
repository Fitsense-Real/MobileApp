# Notificaciones push de Kora (Firebase Cloud Messaging)

**Proyecto Firebase:** `kora-fitpe`. **App Android:** `pe.fit.kora`.

El backend todavía **no envía** notificaciones push y esta PR no lo modifica. El Mobile queda preparado:
- registra el token del dispositivo;
- muestra y abre los mensajes de los cuatro eventos.

El contrato propuesto para el backend está en `CONTRATO_PUSH_BACKEND.md`.

## Piezas

| Archivo | Qué hace |
|---|---|
| `lib/features/push/domain/push_event.dart` | Eventos `PLAN_GENERATED`, `PLAN_ADAPTED`, `WEEKLY_PLAN_READY` y `ACCOUNT_NOTICE`: pantalla que abren y si cambian el plan. Un tipo desconocido abre Inicio |
| `lib/features/push/data/push_messaging.dart` | Firebase Messaging, solo en Android: inicialización con `google-services.json`, **token de registro FCM**, mensajes en primer plano, toques y mensaje de arranque. Incluye el *handler* de segundo plano |
| `lib/features/push/data/push_device_repository.dart` | `PUT` y `DELETE /users/me/push-devices` (contrato propuesto). Si el backend no tiene el endpoint (404, 405 o 501), no rompe nada y lo reintenta en el siguiente inicio de sesión |
| `lib/features/push/data/push_notifier.dart` | Muestra el mensaje cuando la app está abierta (FCM no lo hace). Usa el canal `kora_avisos` y el ícono `ic_stat_kora`, con el mismo plugin que los recordatorios |
| `lib/features/push/presentation/push_controller.dart` | Registra el token al iniciar sesión y cuando FCM lo renueva. Muestra los mensajes, recarga el plan, abre la pantalla al tocar y retira el token antes de cerrar sesión |
| `lib/app/app.dart` | Escucha el usuario con sesión y conecta la navegación |
| `AndroidManifest.xml` | Ícono (`ic_stat_kora`) y canal (`kora_avisos`) que Android usa para los mensajes con la app en segundo plano |
| `android/app/build.gradle.kts` | Plugin de Google Services, aplicado **solo si existe** `google-services.json`. El AAB de Play lo exige y comprueba que sea de `pe.fit.kora` |

## Token: de registro FCM, no el ID de instalación

- Kora envía al backend el **token de registro FCM** (`FirebaseMessaging.getToken()` y `onTokenRefresh`). Es el
  destino que usan FCM HTTP v1 y el Firebase Admin SDK de Spring Boot.
- **No** es el *Firebase Installation ID* (FID). `firebase_messaging` 17 marca `getToken` como obsoleto y propone
  `register()`/`onRegistered`, pero estos devuelven el FID del nuevo modo de envío directo, que es otro identificador.
  Por eso el código usa a propósito las APIs del token de registro, con tres supresiones del aviso de obsolescencia
  justificadas en el propio código.
- **Ciclo de vida del token:**
  - al iniciar sesión se registra;
  - si FCM lo renueva, se vuelve a registrar;
  - antes de cerrar sesión se retira del backend y se borra en el teléfono (`deleteToken`). Si la sesión caducó, el
    `DELETE` puede fallar, pero el token se borra igual en el teléfono;
  - si se elimina la cuenta, el backend borra sus tokens y el teléfono borra el suyo al cerrar la sesión.

## Qué ve el usuario

| Estado de la app | Qué pasa |
|---|---|
| **Abierta** | Kora muestra el aviso con el ícono de Kora y, si el plan cambió, lo recarga. Si se está esperando el primer plan, consulta la generación al momento |
| **En segundo plano o cerrada** | Android muestra el aviso del mensaje (parte `notification`) con el ícono y el canal de Kora |
| **Toque en el aviso** | `PLAN_GENERATED` → «Preparación de cuenta», que decide entre resultado, recorrido o inicio. `PLAN_ADAPTED` → Progreso. `WEEKLY_PLAN_READY` → Inicio. `ACCOUNT_NOTICE` → Perfil |

- **Permiso de notificaciones (Android 13+):** Kora lo pide una sola vez, en el flujo de recordatorios. FCM usa ese
  mismo permiso; no se pregunta dos veces. Sin permiso, el token se registra igual pero Android no muestra los avisos.
- **Recordatorios locales:** siguen igual (`flutter_local_notifications`). El aviso local del lunes y un futuro
  `WEEKLY_PLAN_READY` podrían coincidir; cuando el backend envíe ese push, conviene quitar el aviso local.

## Sin `google-services.json`

Desde `62083b2` el archivo está versionado, así que el CI compila con Firebase. Esto solo ocurre si se borra el archivo,
o en la web, donde Firebase no se inicializa:
- la app compila y funciona;
- el push queda apagado;
- solo se ve un aviso en el log de depuración;
- las 270 pruebas no tocan Firebase.

El AAB de Play no compila sin ese archivo.

## Documentos

- `INCORPORAR_CONFIGURACION_FIREBASE.md`: cómo subir a esta PR los archivos que generó FlutterFire en tu PC.
- `PRUEBAS_PUSH_E_IDENTIFICADOR.md`: verificaciones hechas, pruebas en el teléfono o el emulador, y limitaciones.
- `CONTRATO_PUSH_BACKEND.md`: lo que necesita el backend de Spring Boot.
