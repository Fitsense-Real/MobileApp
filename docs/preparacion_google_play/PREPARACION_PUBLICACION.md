# Preparación técnica para Google Play (cierre del Mobile)

Rama `claude/preparacion-publicacion`, desde `generation` `fb01dd5`. **No se publicó nada** y no se creó ninguna
clave real.

## Estado por punto

| Punto | Estado | Detalle |
|---|---|---|
| `applicationId` | **Pendiente de tu aprobación** | Sigue siendo `com.example.fitsense_mobile`. Se propone `pe.fitsense.kora` (`IDENTIFICADOR_APLICACION.md`). Se define con `-Pkora.applicationId=...`, sin tocar el código. El AAB de Play se niega a compilar con `com.example.*` |
| Nombre público | ✓ | `android:label="Kora"` (comprobado con `aapt dump badging`) |
| Ícono del lanzador | **Corregido en esta PR** | Antes era un *vector* sin adaptar. Ahora es un **ícono adaptativo** (Android 8+): fondo lima `#D9FF59`, letra en bosque y capa **monocroma** para los íconos temáticos de Android 13+. En Android 7.x se usan PNG generados con el mismo diseño, que sustituyen al logo de Flutter |
| Ícono de notificación | **Fallo corregido en esta PR** | Ver la sección siguiente |
| Ícono de Play (512 × 512) | ✓ preparado | `recursos/icono-play-512.png`: cuadrado completo sin transparencia, porque Play aplica su máscara. Se genera con `recursos/play.js` |
| Pantalla de lanzamiento | ✓ | Fondo marfil `#F7F5ED` con el ícono de Kora, también en la API de *splash* de Android 12+ |
| Permisos | ✓ mínimos | `INTERNET`, `RECEIVE_BOOT_COMPLETED` (reprogramar recordatorios tras reiniciar), `POST_NOTIFICATIONS` y `VIBRATE` (del plugin de notificaciones). **No** se pide `SCHEDULE_EXACT_ALARM`, ubicación, cámara, contactos ni almacenamiento. `DUMP` solo aparece como protección del receptor `profileinstaller` de AndroidX; no es un permiso que pida la app |
| Versión | `1.0.0+1` | Para la beta: subir el número tras `+` (`versionCode`) en cada entrega. Ver `DISTRIBUCION_BETA.md` |
| Firma de producción | **Pendiente (externo)** | La configuración está lista (`key.properties`, `FIRMA_Y_AAB.md`). Falta que crees **tu** clave de subida en tu computadora. Ruta comprobada con una clave desechable (abajo) |
| Compatibilidad con páginas de 16 KB | ✓ | `zipalign -c -P 16`: *Verification successful*. Todos los segmentos `LOAD` de las `.so` (`libapp`, `libflutter`, en arm64, armv7 y x86_64) tienen alineación ≥ 16 KB (0x4000 o 0x10000) |
| targetSdk | ✓ 36 | Es el exigido por Play desde el 31/08/2026 |
| AAB | ✓ ruta verificada | Ver abajo |
| Bloqueos de release | ✓ sin cambios | Matriz repetida en esta rama (abajo) |

## Fallo encontrado: los recordatorios no funcionaban en una build de release

- **Síntoma:** en una build de Google Play los recordatorios nunca se programarían. En debug, que es donde se probó
  hasta ahora, sí funcionan.
- **Causa:**
  1. El plugin se inicializaba con `@mipmap/ic_launcher` como ícono por defecto.
  2. Ese recurso solo se nombra desde Dart, así que el *resource shrinker* de release lo elimina. Comprobado: el APK
     release de `fb01dd5` no contiene `mipmap/ic_launcher`.
  3. Al inicializarse, el plugin comprueba el ícono, falla con `invalid_icon` y `_ensureInitialized()` devuelve
     `false`. Desde ahí, cada recordatorio se descarta en silencio.

  Además, ese recurso era el logo de Flutter en color, inadecuado como ícono pequeño de notificación.
- **Corrección:**
  - nuevo `drawable/ic_stat_kora.xml`: la letra de Kora en blanco sobre transparente, como exige Android para los
    íconos pequeños;
  - `res/raw/keep.xml` (`tools:keep`) para que el *shrinker* no lo elimine;
  - `reminder_scheduler.dart` usa `'ic_stat_kora'`.
- **Comprobado** en el APK release de esta rama: `drawable/ic_stat_kora` presente.
  `test/android_release_resources_test.dart` lo vigila.

> La PR #13 (dependencias) toca la línea anterior de `reminder_scheduler.dart` (`settings:`). Si se fusionan las dos,
> el conflicto es de una línea: conservar `settings:` de la #13 y `'ic_stat_kora'` de esta.

## AAB firmado (clave de prueba desechable)

Se creó una clave **de prueba**:
- válida 30 días;
- contraseña aleatoria que no se mostró;
- `CN=Kora PRUEBA NO PUBLICAR`.

Se usó una vez y después se borraron la clave, su `key.properties` y el AAB.

```
flutter build appbundle --release \
  --dart-define=API_BASE_URL=https://backend.example.test/api/v1 \
  --dart-define=ACCOUNT_DELETION_ENABLED=true \
  --dart-define=ACCOUNT_DELETION_WEB_URL=https://kora.example.test/eliminar \
  --dart-define=PRIVACY_POLICY_URL=https://kora.example.test/privacidad \
  -Pkora.testBackendUrl=true -Pkora.applicationId=pe.fitsense.kora
```

| Comprobación | Resultado |
|---|---|
| Compilación | AAB de 62,4 MB, SHA-256 `7a3251abf76391082eef35537c3d5d703cd3f5261ddf0268980215fdc17fc085` (no conservado) |
| `jarsigner -verify -certs` | `jar verified`, firmado por `CN=Kora PRUEBA NO PUBLICAR` (**no** por la clave debug) |
| Manifiesto | `pe.fitsense.kora`, versión `1.0.0`, etiqueta `Kora`; sin `debuggable` ni `usesCleartextTraffic`; permisos iguales a los del APK |
| Bibliotecas | `base/lib/{arm64-v8a,armeabi-v7a,x86_64}/` |

**No es publicable,** porque la clave y la URL son de prueba. Con tu clave, tu URL HTTPS y tus páginas, es el mismo
comando sin `-Pkora.testBackendUrl=true` (`FIRMA_Y_AAB.md` §6–7).

## Matriz de bloqueos de release (repetida en esta rama)

Ver `evidencia_publicacion/matriz-release.txt`. Se comprobaron estos casos:

| Caso | Resultado |
|---|---|
| APK release sin `API_BASE_URL` | Bloqueado |
| APK release con `http://` | Bloqueado |
| APK release con `10.0.2.2` | Bloqueado |
| APK release con IP privada | Bloqueado |
| APK release con dominio `.test` sin la bandera | Bloqueado |
| AAB sin configuración | Bloqueado, con 6 motivos |
| AAB sin firma ni identificador | Bloqueado |
| APK release de prueba con la bandera | Permitido: `INTERNET`, minSdk 24, targetSdk 36, sin `debuggable` ni tráfico en claro, 0 secretos en `libapp.so` |

## Qué queda fuera del código

Ver `INVENTARIO_PLAY_CONSOLE.md`:
- aprobar el identificador;
- crear la clave de subida;
- backend HTTPS de producción;
- política de privacidad y página de eliminación publicadas;
- formulario de seguridad de los datos (*Data Safety*) y declaración de salud;
- capturas y ficha;
- cuenta para el revisor.
