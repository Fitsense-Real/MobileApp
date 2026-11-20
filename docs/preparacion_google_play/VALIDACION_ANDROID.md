# Validación Android (integración con 5977d28)

**No hubo teléfono físico ni emulador.** Todo lo de abajo son compilaciones e inspección de artefactos.
Que un APK compile no prueba que funcione en un teléfono.

## Protecciones de #4–#7, comprobadas de nuevo sobre `d96f4ab`

| Protección | Comprobación | Resultado |
|---|---|---|
| `INTERNET` en release | `aapt dump permissions` del APK release | ✓ |
| targetSdk / compileSdk 36 | `aapt dump badging` | 36 / 36 |
| AGP 8.9.1, NDK 27 | compilación debug y release | ✓ |
| Borde a borde y gesto atrás | `enableOnBackInvokedCallback=true` en el manifiesto; pruebas de widget en verde | ✓ (sin dispositivo) |
| Sin tráfico en claro en release | release sin `usesCleartextTraffic`; solo el manifiesto **debug** lo activa, para `adb reverse` | ✓ |
| No depurable en release | sin `android:debuggable` | ✓ |
| `API_BASE_URL` segura | release con `http://localhost…` → **bloqueado**; con `https://10.0.2.2…` → **bloqueado** | ✓ (`evidencia/release.log`) |
| AAB sin configuración | **bloqueado**, con 6 motivos (URL, `key.properties`, identificador, eliminación, página web, privacidad) | ✓ |
| Firma | El APK release de evaluación (URL `.invalid` con `-Pkora.testBackendUrl=true`) usa la firma debug, como está documentado; no es publicable. No se creó ninguna clave definitiva | ✓ |
| Identificador | `com.example.fitsense_mobile` (sin cambiar; `pe.fitsense.kora` sigue pendiente de autorización) | — |
| Botones sociales | ausentes (`auth_social_cleanup_test`) | ✓ |
| Secretos en el binario | `strings libapp.so`: 0 coincidencias de `localhost:8080`, `10.0.2.2`, el secreto JWT local, claves privadas o `storePassword` | ✓ |

## APK debug para el teléfono por USB

Compilado con el código final de #8 (tras la revisión de seguridad); el primero, de `d96f4ab`, queda sustituido:

```
flutter build apk --debug --target-platform android-arm64 \
  --dart-define=API_BASE_URL=http://localhost:8080/api/v1 --dart-define=ALLOW_INSECURE_API=true \
  --dart-define=ACCOUNT_DELETION_ENABLED=true --dart-define=PASSWORD_RECOVERY_ENABLED=true
```

| Dato | Valor |
|---|---|
| Archivo | `app-debug.apk`, entregado como `kora-debug-usb-arm64-5977.apk` (57 MB) |
| SHA-256 | `53b67931ed73d73830aff08d7a6ca8825fd4e6df92d16581b58e0bab10cb4cef` |
| Paquete | `com.example.fitsense_mobile`, `minSdk 21`, `targetSdk 36`, `arm64-v8a`, etiqueta «Kora» |
| Uso | solo pruebas; tráfico en claro únicamente hacia `localhost` por `adb reverse` |

No se versiona en el repositorio. Se entrega aparte, junto con este informe.

### Instalación en Windows

1. **En el teléfono**: Ajustes → Acerca del teléfono → toca 7 veces «Número de compilación». Luego
   Opciones de desarrollador → activa «Depuración USB».
2. **En el PC**: instala Android Studio o solo las *Platform Tools*. `adb` queda en
   `%LOCALAPPDATA%\Android\Sdk\platform-tools`.
3. Conecta el cable USB, acepta la huella del PC en el teléfono y comprueba la conexión:

   ```
   adb devices
   ```

4. Con el backend local corriendo en el PC (puerto 8080):

   ```
   adb reverse tcp:8080 tcp:8080
   ```

   Repítelo cada vez que reconectes el cable.
5. Instala el APK:

   ```
   adb install -r kora-debug-usb-arm64-5977.apk
   ```

6. Si algo falla, guarda la evidencia:

   ```
   adb logcat -d -s flutter > kora-flutter.txt
   ```

   ```
   adb exec-out screencap -p > kora.png
   ```

Desinstalar: `adb uninstall com.example.fitsense_mobile`.

Para probar la recuperación en el teléfono, el backend del PC debe tener el correo simulado o uno real.
Sin correo, compila sin `PASSWORD_RECOVERY_ENABLED`.

## Qué queda por probar en un teléfono real (Android 13–16)

La tabla de `GUIA_PUBLICACION_ANDROID.md` §8 sigue vigente. Además:

- **Eliminar mi cuenta**: 200, «Solicitud recibida» (202) y 403/429. En el teléfono, el 429 debe
  mostrar los minutos exactos, porque `Retry-After` sí se lee fuera del navegador.
- Recuperación con el correo del backend del PC.
- Pantalla de consentimientos, si el backend publica versiones.
