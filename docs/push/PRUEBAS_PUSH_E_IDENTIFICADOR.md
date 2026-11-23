# Pruebas: identificador `pe.fit.kora` y notificaciones push por FID

## 1. Verificado en el entorno de compilación (Linux, sin teléfono)

| Comprobación | Resultado |
|---|---|
| `flutter analyze` (reglas estrictas, sin desactivar ninguna) | ✓ sin problemas |
| `flutter test` | ✓ **306** pruebas. Incluyen el permiso independiente de los recordatorios (`push_permission_test.dart`). Las de push y del identificador cubren eventos y rutas, el contrato HTTP byte a byte con los ejemplos reales de la PR #82, el ciclo de sesión del controlador, los canales Android y el manifiesto |
| APK debug (JDK 17) y APK release de prueba (JDK 21) con la configuración real de `kora-fitpe` | ✓ `package: name='pe.fit.kora'`, `firebase_messaging_installation_id_enabled=true`, canal por defecto `kora_planes`, `project_id` = `kora-fitpe`, alineación de 16 KB (`evidencia/apk-fid.txt`) |
| APK release con **JDK 17** | Bloqueado por el guardián con un mensaje claro. Android lint falla con `firebase_core` en JDK 17. **Las compilaciones release y el AAB se hacen con JDK 21** (el de Android Studio) |
| `flutter build web` | ✓ (Firebase Messaging no se inicializa fuera de Android) |
| Protecciones del AAB de Google Play | ✓ sin cambios: identificador `pe.fit.kora`, `google-services.json` de esa app, firma propia, HTTPS, eliminación de cuenta y páginas públicas (`evidencia/matriz-release-identificador-fcm.txt`) |

## 2. Prueba integral con el Backend real (PR #82), en local

**Evidencia:** `evidencia/prueba-integral-backend-pr82.txt`.

**Condiciones:**
- Backend `cc703fb` compilado desde la PR, **sin modificarla**, sobre PostgreSQL 16 local y una base aislada;
- IA apagada, **sin Replicate**;
- cuentas y FID **sintéticos**;
- push encendido con una **cuenta de servicio sintética** (clave RSA generada en local que no vale para Google);
- **sin salida a Internet** para el proceso Java: nada llegó a Google.

Por el hallazgo A de `COMPATIBILIDAD_BACKEND_PR82.md`, el Backend solo arrancó añadiendo
`google-http-client-jackson2` al classpath de la prueba.

| Paso de la orden | Resultado |
|---|---|
| 1. Iniciar sesión | ✓ JWT de `POST /api/v1/auth/login` (cuentas A y B) |
| 2. Registrar el FID en el Backend | ✓ **con el código del Mobile** (`PushDeviceRepository`, `test/live/push_backend_live_test.dart`): `201`, renovación `200` con el mismo `deviceId`, `GET` solo con la pista del FID, preferencias, `IDENTIFICADOR_PUSH_INVALIDO` para un token FCM, `401` sin JWT, cambio de cuenta y `DELETE` idempotente |
| 3. Comprobar en PostgreSQL que quedó asociado al usuario | ✓ `push_devices`: fila activa de A con `identifier_type=FID`, `platform=ANDROID`, `app_id=pe.fit.kora` y el FID exacto que envió la app. También quedan el vínculo revocado por `CAMBIO_DE_CUENTA` y el de B, `DESVINCULADO` |
| 4. Generar un plan con datos sintéticos | ✓ generación asíncrona → `plan_generation_operations.status = COMPLETED` |
| 5. Verificar que el Backend envía el evento | ✓ `notification_events`: `PLAN_GENERATED`, `WEEKLY_PLAN`, `PLAN:<id>`. `notification_deliveries`: el emisor intentó el envío **a ese FID**. Falló con `ERROR_TEMPORAL` (sin red ni credenciales reales), como se esperaba |
| 6. Firebase entrega la notificación | **Pendiente:** necesita credenciales reales en el Backend, el arreglo del hallazgo A y un teléfono |
| 7. Pulsar la notificación y comprobar la navegación | **Pendiente en el teléfono.** Cubierto en las pruebas automáticas (`push_notifications_test.dart`: arranque en frío, segundo plano y app abierta) |

Para repetirla, el script está en `evidencia/prueba-integral-backend-pr82.sh`.

## 3. Prueba integral en Android (pendiente: teléfono o emulador)

**Requisitos:**
- **Backend con el hallazgo A corregido**, o lanzado con `google-http-client-jackson2` en el classpath;
- el Backend con `FITSENSE_PUSH_ENABLED=true` y la cuenta de servicio **real** de `kora-fitpe` en
  `FITSENSE_FIREBASE_CREDENTIALS_BASE64`, como **secreto**, nunca en un archivo del repositorio. Ver el
  `CONFIGURACION_RAILWAY.md` del Backend;
- un teléfono con **Google Play services 26.12 o posterior** (Ajustes → Apps → Google Play services → versión). En
  emulador, una imagen **con Google Play** actualizada;
- JDK 21 para compilaciones release.

### Pasos (Windows, PowerShell; con el Backend local, como en `PRUEBA_ANDROID_WINDOWS_PENDIENTE.md` §1)

1. **Compila e instala.** Con el teléfono por USB:

   ```
   flutter build apk --debug --dart-define=API_BASE_URL=http://localhost:8080/api/v1 --dart-define=ALLOW_INSECURE_API=true
   ```

   ```
   adb reverse tcp:8080 tcp:8080
   ```

   ```
   adb install -r build\app\outputs\flutter-apk\app-debug.apk
   ```

2. **Inicia sesión** con una cuenta de prueba **con los recordatorios desactivados**. Al llegar al Inicio, después del
   onboarding, aparece la hoja «¿Te avisamos cuando haya novedades?»: pulsa **Activar avisos** y concede el permiso en el
   diálogo de Android. Cierra sesión y vuelve a entrar: la hoja **no** debe volver a aparecer.
3. **Registro del FID.** En una compilación de depuración, el log muestra el estado y el FID:

   ```
   adb logcat -d -s flutter | Select-String "FCM installation ID"
   ```

   Esperado: `FCM installation ID (registered): <FID de 22 caracteres>`. Con `backendNotReady`, el Backend no tiene la
   PR #82; con `rejected`, se ve el código. **No pegues el FID en GitHub ni en chats.**
4. **PostgreSQL.** Debe haber una fila activa de esa cuenta:

   ```sql
   SELECT left(installation_id,4), app_id, revoked_at FROM push_devices d JOIN users u USING (user_id) WHERE u.email = '<correo de prueba>';
   ```

5. **Genera el primer plan** en modo asíncrono, con una cuenta nueva y datos sintéticos.
6. **Entrega.** Llega «Tu plan está listo» con la silueta de Kora. En la base:

   ```sql
   SELECT status, fcm_message_id FROM notification_deliveries ORDER BY attempted_at DESC LIMIT 1;
   ```

   Esperado: `ENVIADO` y un `fcm_message_id`.
7. **Navegación:**

   | # | Estado de la app | Al tocar |
   |---|---|---|
   | 1 | **Abierta** | Aparece el aviso de Kora; tocarlo abre «Preparación de cuenta», que lleva al resultado o al Inicio |
   | 2 | **En segundo plano** | Aviso del sistema en el canal «Tu plan»; tocarlo abre lo mismo |
   | 3 | **Cerrada** (deslizada desde recientes) | Igual que el 2 |
   | 4 | `PLAN_ADAPTED` / `WEEKLY_PLAN_READY` (ciclo semanal) | Inicio |
   | 5 | `ACCOUNT_NOTICE` (recuperar la contraseña desde otra sesión) | Canal «Avisos de tu cuenta»; abre Perfil. La sesión anterior vuelve al inicio de sesión |
   | 6 | Ajustes de Android → Apps → Kora → Notificaciones | Canales «Recordatorios de entrenamiento», «Tu plan» y «Avisos de tu cuenta» |

8. **Cierre de sesión.** Cierra sesión y repite la consulta del paso 4: el vínculo queda con
   `revoke_reason = DESVINCULADO`. Un plan nuevo de esa cuenta ya no llega al teléfono.
9. **Rechazo y activación posterior.** Con otra instalación limpia, pulsa **Ahora no**:
   - Kora funciona con normalidad;
   - en Perfil → Avisos en el teléfono aparece «Las notificaciones de Kora están desactivadas en este teléfono»;
   - **Activar notificaciones** abre el diálogo o los ajustes de Android para Kora;
   - al activarlas y volver, el log muestra `FCM installation ID (registered)`.
10. **Preferencias.** En Perfil → Avisos en el teléfono, desactiva «Cambios en mi plan». Un plan nuevo no llega: el
   evento queda `DESCARTADO`.
11. **Resto de la app:**
    - [ ] Inicio de sesión y cierre de sesión, sin errores en el log.
    - [ ] Rutinas y favoritas.
    - [ ] Recordatorios locales: llega uno a la hora fijada.
    - [ ] Sesión en vivo.

**Limitaciones de Android, que no son errores de Kora:**
- **«Forzar detención»:** Android no entrega FCM a una app detenida a la fuerza hasta que se vuelve a abrir.
- **Ahorro de batería de Samsung:** puede retrasar los avisos.
- **La consola de Firebase:** «Enviar mensaje de prueba» espera un token de registro y puede no aceptar un FID. La
  prueba válida es la del Backend.

### Actualizar `pe.fit.kora` a `pe.fit.kora`

1. Con la app instalada y la sesión iniciada, cambia `version: 1.0.0+1` a `1.0.0+2` en `pubspec.yaml`. **Solo en local.**
2. Vuelve a compilar e instala encima con `adb install -r`.
3. Comprueba con `adb shell dumpsys package pe.fit.kora | Select-String "versionCode"`.
4. Se conservan la sesión, las favoritas, los recordatorios y el recorrido. El FID no cambia y el `PUT` del arranque lo
   renueva (`200`).
5. Deshaz el cambio con `git checkout -- pubspec.yaml`.

## 4. Qué hacer con el resultado

Anota en la PR qué pasos pasaron. Si uno falla, adjunta:
- el número del paso;
- el modelo del teléfono o la imagen del emulador;
- la versión de Google Play services;
- `adb logcat -d -s flutter FirebaseMessaging > kora-push.txt`, después de quitar el FID y cualquier dato personal.
