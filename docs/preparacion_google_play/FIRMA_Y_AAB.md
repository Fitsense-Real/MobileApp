# Firma de release y Android App Bundle (PR B)

## Problema

`buildTypes.release` firmaba con `signingConfigs.debug` (`CN=Android Debug`): no sirve para Play.
Además, Play exige subir un `.aab`, no un APK.

## Configuración preparada

`android/app/build.gradle.kts` lee `android/key.properties`:

```properties
storePassword=...
keyPassword=...
keyAlias=upload
storeFile=/ruta/segura/kora-upload.jks
```

- Si existe, el release se firma con esa clave de subida.
- Si no existe, los APK release de evaluación usan la clave debug, y **`bundleRelease` se niega a
  compilar**: «Falta android/key.properties».
- `android/.gitignore` ya excluye `key.properties`, `*.jks` y `*.keystore`.

**No se generó ninguna clave de publicación.** La debe crear y custodiar el propietario.

## Verificación del empaquetado (con una clave de prueba desechable)

Para comprobar la configuración sin la clave real se creó una clave **de prueba**: válida 1 día,
contraseña aleatoria nunca mostrada, `CN=Kora PRUEBA NO PUBLICAR`. Se usó una vez y se borró junto
con su `key.properties` y el AAB resultante.

| Comprobación | Resultado |
|---|---|
| `flutter build appbundle --release` sin `key.properties` y con el identificador de ejemplo | **bloqueado**, con los dos motivos |
| `flutter build appbundle` con la clave de prueba, `-Pkora.applicationId=pe.fitsense.kora` y URL de prueba permitida | AAB de 48,6 MB |
| `jarsigner -verify -certs` | `jar verified`, firmado por `CN=Kora PRUEBA NO PUBLICAR` (no `Android Debug`) |
| Manifiesto del AAB | `pe.fitsense.kora`, `android.permission.INTERNET` |

Ese AAB **no era publicable** (clave y URL de prueba) y no se conservó.

## Guía de Play App Signing (para el propietario)

### 1. Crear la clave de subida, en tu computadora y no en un entorno temporal

```bash
keytool -genkeypair -v -keystore kora-upload.jks -alias upload -keyalg RSA -keysize 2048 -validity 10000
```

Usa una contraseña fuerte y guárdala en tu gestor de contraseñas.

### 2. Custodia

- Guarda `kora-upload.jks` y su contraseña en dos sitios seguros, por ejemplo el gestor de contraseñas
  y una copia cifrada fuera del equipo.
- Nunca va al repositorio, a chats ni a correos.
- Con Play App Signing, si pierdes la clave de subida, Google permite restablecerla; la clave de firma
  de la app la custodia Google.

### 3. Huella del certificado (la pide Play Console en algunos pasos)

```bash
keytool -list -v -keystore kora-upload.jks -alias upload
```

Anota la SHA-256 del certificado.

### 4. Configurar el proyecto

Crea `android/key.properties`, que no se versiona, con las cuatro líneas de arriba y la ruta absoluta
a tu `.jks`.

### 5. Activar Play App Signing

Play Console → tu app → **Configuración → Integridad de la app**. Es la opción por defecto para apps
nuevas: Google genera y guarda la clave de firma, y tú subes con la clave de subida.

### 6. Compilar el AAB

Necesita el identificador aprobado y la URL HTTPS real:

```bash
flutter build appbundle --release --dart-define=API_BASE_URL=https://<dominio-real>/api/v1
```

Queda en `build/app/outputs/bundle/release/app-release.aab`.

### 7. Verificar antes de subir

```bash
jarsigner -verify -verbose -certs build/app/outputs/bundle/release/app-release.aab
```

Debe decir `jar verified` y tu `CN`, no `Android Debug`.

### 8. Subida

Primero a una pista de **prueba cerrada** (ver `GUIA_PUBLICACION_ANDROID.md`).

## Artefactos de esta orden

| Artefacto | Estado |
|---|---|
| APK debug | ✓ (pruebas por USB, `GUIA_INSTALACION_APK.md`) |
| APK release de evaluación | ✓ compila con URL HTTPS; firmado con debug si no hay `key.properties` |
| AAB publicable | **no existe todavía**: faltan la clave de subida propia, el identificador aprobado y la URL HTTPS real |
