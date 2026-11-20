# Permiso INTERNET en release (PR A)

## Problema

El APK release no declaraba `android.permission.INTERNET`. La plantilla de Flutter lo pone solo en
`android/app/src/debug/AndroidManifest.xml` y `src/profile`, así que la versión de Play no podía
abrir ninguna conexión con el backend.

El informe anterior (`docs/validacion/PRUEBAS_ANDROID.md`) lo daba por presente porque se leyó del
APK debug; ya está corregido allí.

## Corrección

`android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.INTERNET"/>
```

Ningún manifiesto de dependencia lo elimina (`tools:node="remove"`): se comprobó en los artefactos.

## Comprobado en los artefactos finales

**APK release** (`aapt dump permissions`):

```
uses-permission: name='android.permission.INTERNET'
uses-permission: name='android.permission.RECEIVE_BOOT_COMPLETED'
uses-permission: name='android.permission.VIBRATE'
uses-permission: name='android.permission.POST_NOTIFICATIONS'
```

**AAB release**: se extrajo `base/manifest/AndroidManifest.xml` (formato protobuf) del `.aab`. Contiene
`android.permission.INTERNET`, `POST_NOTIFICATIONS`, `RECEIVE_BOOT_COMPLETED` y `VIBRATE`.
`android.permission.DUMP` también aparece, pero no es un permiso que pida la app: es el atributo
`android:permission` del `ProfileInstallReceiver` de AndroidX, estándar en toda app.

`bundletool dump manifest` no se ejecutó: descargar y ejecutar su jar desde GitHub quedó bloqueado
por la política del entorno. Ver `PRUEBAS_RELEASE.md`.

**APK debug**: también declara `INTERNET` (sin cambios).

## Conexión HTTPS

Con el permiso presente y el release limitado a HTTPS (`usesCleartextTraffic` solo en debug), la app
usa el almacén de certificados del sistema y no acepta certificados inválidos: no hay
`badCertificateCallback` ni *pinning*. La comprobación contra un servidor HTTPS real queda pendiente
de la URL de producción (`CONFIGURACION_BACKEND_HTTPS.md`) y de un teléfono.
