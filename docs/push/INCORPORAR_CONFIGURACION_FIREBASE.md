# Incorporar a la PR los archivos de Firebase generados en tu PC (Windows, PowerShell)

**Situación:**
- Ejecutaste FlutterFire CLI y registraste `kora-fitpe` con `pe.fit.kora`. Los archivos generados están solo en tu PC.
- La PR (rama `claude/identificador-fcm`) ya trae:
  - el identificador;
  - el plugin de Google Services;
  - las dependencias `firebase_core` y `firebase_messaging`;
  - todo el código push.

**Falta subir exactamente tres archivos:**

| Archivo | ¿Secreto? | Se versiona |
|---|---|---|
| `android/app/google-services.json` | No: configuración de cliente (claves de API restringidas a la app) | **Sí** |
| `lib/firebase_options.dart` | No: la misma configuración, para Dart | **Sí** |
| `firebase.json` | No: configuración de FlutterFire | **Sí** |

**Nunca subas:**
- una cuenta de servicio (`*-firebase-adminsdk-*.json` o cualquier JSON con `private_key`);
- `.firebase/`;
- `firebase-debug.log`;
- `build/`;
- `local.properties`;
- `key.properties`.

`.gitignore` ya bloquea los de Firebase.

**Qué hacer con lo demás que tocó FlutterFire:**
- **Cambios en archivos de Gradle o en `pubspec`:** FlutterFire suele añadir el plugin de Google Services en
  `android/settings.gradle.kts` y `android/app/build.gradle.kts`, y `firebase_core` en `pubspec.yaml`. La PR ya lo trae
  con versiones compatibles con AGP 9, así que **no subas esos cambios tuyos**. Quedan guardados en un *stash*, sin
  perderse.
- **`kora.applicationId=pe.fit.kora`:** ya no hace falta, porque es el valor predeterminado. Queda en el *stash*.

## Pasos

En la carpeta del repositorio:

1. **Mira qué cambió en local.** Anota la lista:

   ```
   git status
   ```

2. **Copia los tres archivos fuera del repositorio,** como respaldo:

   ```
   New-Item -ItemType Directory -Force "$HOME\kora-firebase-respaldo" | Out-Null
   ```

   ```
   Copy-Item lib\firebase_options.dart, android\app\google-services.json, firebase.json "$HOME\kora-firebase-respaldo\"
   ```

3. **Guarda todo lo demás en un *stash*,** incluidos los archivos nuevos. No se borra nada:

   ```
   git stash push --include-untracked -m "flutterfire-local-kora-fitpe"
   ```

4. **Trae la rama de la PR:**

   ```
   git fetch origin claude/identificador-fcm
   ```

   ```
   git switch claude/identificador-fcm
   ```

   Si Git dice que no existe en local, usa: `git switch -c claude/identificador-fcm --track origin/claude/identificador-fcm`.
5. **Copia los tres archivos desde el respaldo:**

   ```
   Copy-Item "$HOME\kora-firebase-respaldo\firebase_options.dart" lib\
   ```

   ```
   Copy-Item "$HOME\kora-firebase-respaldo\google-services.json" android\app\
   ```

   ```
   Copy-Item "$HOME\kora-firebase-respaldo\firebase.json" .
   ```

6. **Comprueba que son los correctos.** Deben aparecer las dos líneas:

   ```
   Select-String -Path android\app\google-services.json -Pattern '"project_id": "kora-fitpe"', '"package_name": "pe.fit.kora"'
   ```

   Y que no llevan credenciales de administrador. Esto **no** debe mostrar nada:

   ```
   Select-String -Path android\app\google-services.json, lib\firebase_options.dart, firebase.json -Pattern 'private_key', 'client_email', 'service_account'
   ```

7. **Compila y prueba en local** (opcional pero recomendado). En la salida de `adb logcat` de una compilación debug
   aparece `FCM token (…)`:

   ```
   flutter analyze
   ```

   ```
   flutter test
   ```

   ```
   flutter build apk --debug
   ```

8. **Añade solo esos tres archivos**, nombrándolos uno por uno:

   ```
   git add lib/firebase_options.dart android/app/google-services.json firebase.json
   ```

   ```
   git status
   ```

   En «Changes to be committed» deben aparecer **solo** esos tres.
9. **Commit y push a la rama de la PR:**

   ```
   git commit -m "chore(firebase): configuración de cliente de kora-fitpe para pe.fit.kora (FlutterFire)"
   ```

   ```
   git push origin claude/identificador-fcm
   ```

10. **El *stash*:** guárdalo hasta que la PR esté fusionada. Para verlo o recuperarlo:

    ```
    git stash list
    ```

    ```
    git stash show -p stash@{0}
    ```

    Cuando ya no lo necesites: `git stash drop stash@{0}`. Revisa antes con `git stash list` que es el que tiene el
    mensaje `flutterfire-local-kora-fitpe`.

**Si en el paso 4 Git se niega a cambiar de rama** porque quedaría algo sin guardar, no fuerces nada: repite el paso 3 y
vuelve a intentarlo.

Cuando el CI de la PR pase con los tres archivos, el AAB de Play ya puede compilarse con push. Avísame y reviso el
resultado.
