# Distribución beta de Kora (Firebase App Distribution)

Objetivo: entregar el APK de Kora a un grupo cerrado de evaluadores y enviarles actualizaciones, **sin publicar en Google
Play**. No se creó ningún proyecto de Firebase ni ninguna clave: este documento y `tool/beta/` dejan todo listo para
que lo hagas desde tu cuenta.

## 0. Antes de la primera beta (una sola vez)

| # | Requisito | Por qué no se puede saltar |
|---|---|---|
| 1 | **Backend HTTPS accesible desde internet** (de pruebas o de producción) | Los teléfonos de los evaluadores no llegan a tu PC. El guardián de release rechaza `http://`, `localhost`, IP privadas y dominios `.test` (ver `CONEXION_BACKEND_PRODUCCION.md`). Es la dependencia principal: **sin despliegue no hay beta remota** |
| 2 | **`applicationId` aprobado** (`pe.fitsense.kora` propuesto) | Firebase registra la app por su identificador. Cambiarlo después crea **otra** app: los evaluadores tendrían que desinstalar y perderían sesión y datos locales |
| 3 | **Clave de subida propia** (`android/key.properties`, `FIRMA_Y_AAB.md`) | Android solo instala una actualización firmada con **la misma clave**. Nunca uses la clave debug: es distinta en cada computadora y rompería las actualizaciones. Es la misma clave que usarás para el AAB de Play |
| 4 | **Política de privacidad y página de eliminación** publicadas (https) | La app las enlaza, los evaluadores son participantes de un estudio y Play las pedirá igual |
| 5 | **Aprobación ética y consentimiento** de los evaluadores, si son participantes reales | La beta recoge datos de salud y actividad. Hasta entonces, solo cuentas sintéticas del equipo |
| 6 | Que la PR #13 (`flutter_secure_storage` 10) esté en todas las betas | La migración de la sesión debe pasar por la 10 antes de cualquier 11 (`ACTUALIZACION_NOTIFICACIONES_ALMACENAMIENTO.md`) |

## 1. Crear el proyecto en Firebase (una sola vez)

1. En <https://console.firebase.google.com>, crea un proyecto, por ejemplo «Kora Beta». **No hace falta Analytics**:
   Kora no lleva SDK de analítica.
2. Añade una app **Android** con el `applicationId` aprobado. No hace falta descargar `google-services.json`:
   App Distribution funciona sin el SDK de Firebase en la app, y así Kora no envía ningún dato a Google.
3. En **App Distribution**:
   - pulsa «Comenzar»;
   - crea el grupo `evaluadores`;
   - añade los correos.
4. Copia el **ID de la app** (`1:…:android:…`, en Configuración del proyecto). No es secreto, pero tampoco hace falta
   versionarlo.
5. En tu computadora, instala el CLI y entra con tu cuenta. Nunca en un entorno compartido.

   ```
   npm install -g firebase-tools
   ```

   ```
   firebase login
   ```

## 2. Compilar y distribuir una beta

1. **Sube la versión** en `pubspec.yaml`. El número tras `+` es el `versionCode` y **debe aumentar en cada entrega**;
   Android no instala uno igual o menor encima.

   ```
   version: 1.0.0+2
   ```

2. **Escribe las notas** a partir de `tool/beta/notas_version_plantilla.txt`.
3. **Compila y distribuye.** El script se niega si falta algo: clave, URL https, identificador aprobado, páginas o notas.

   ```
   KORA_API_BASE_URL=https://TU-BACKEND/api/v1 KORA_APPLICATION_ID=pe.fitsense.kora KORA_ACCOUNT_DELETION_WEB_URL=https://TU-DOMINIO/eliminar-cuenta KORA_PRIVACY_POLICY_URL=https://TU-DOMINIO/privacidad FIREBASE_APP_ID=1:XXXX:android:YYYY tool/beta/distribuir_beta.sh notas.txt
   ```

   - Con `KORA_PASSWORD_RECOVERY_ENABLED=1`, se activa «¿Olvidaste tu contraseña?». Solo si el backend tiene un correo
     real configurado.
   - Sin Firebase CLI, el script deja el APK en `build/app/outputs/flutter-apk/app-release.apk` y basta con subirlo a
     mano en la consola.
4. **Guarda el SHA-256** que imprime el script junto a las notas. Así sabes exactamente qué recibió cada evaluador.

## 3. Instalación para los evaluadores

1. Reciben un correo de Firebase App Distribution y aceptan la invitación desde el teléfono.
2. Instalan **App Tester**, cuando la página lo ofrece, o descargan el APK desde el enlace.
3. Android pide permitir **«Instalar apps desconocidas»** para el navegador o App Tester. Es normal en una beta fuera de
   Play.
4. Si **Play Protect** avisa de una app desconocida: «Más detalles» y luego «Instalar de todas formas». Ocurre porque
   la app aún no está en Play.
5. Abren Kora, crean su cuenta y siguen el perfil inicial. La primera vez, Kora pide permiso de notificaciones para los
   recordatorios (Android 13+).

## 4. Actualizaciones posteriores

- **Mismo proceso:**
  1. subir `+N` en `pubspec.yaml`;
  2. actualizar las notas;
  3. ejecutar `distribuir_beta.sh`.
- Los evaluadores reciben un aviso y **actualizan encima, sin desinstalar**. Se conservan la sesión, el recorrido, los
  favoritos y los recordatorios. Esto exige la misma clave y el mismo identificador (ver §0).
- **Antes de cada entrega:**
  - `flutter analyze` y `flutter test` en verde;
  - instalar encima de la beta anterior en un teléfono propio y comprobar la lista de
    `PRUEBA_ANDROID_WINDOWS_PENDIENTE.md` §3, al menos la sesión y los recordatorios.
- **Desinstalar a mano** solo hace falta si cambiara la clave o el identificador. Por eso hay que decidir ambos antes
  de la primera beta.
- **Volver atrás:** Android no instala un `versionCode` menor. Para retirar una beta defectuosa, se distribuye una
  versión nueva (`+N+1`) con el arreglo.

## 5. Del grupo beta a Google Play

- Cuando estén listos el backend de producción, las páginas y la ficha, el **mismo** código y la **misma** clave
  generan el AAB (`FIRMA_Y_AAB.md` §6).
- Las cuentas personales de Play Console creadas después de noviembre de 2023 deben pasar por una **prueba cerrada con
  al menos 12 evaluadores durante 14 días** antes de producción. El grupo de App Distribution puede convertirse en esa
  lista.
- La lista completa está en `INVENTARIO_PLAY_CONSOLE.md`.
