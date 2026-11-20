# Guía de publicación Android de Kora

> **Actualización (20/11/2026):** `DELETE /users/me` ya está en el backend 5977d28 y la app usa su contrato real. La
> MobileApp suma la PR #8 (integración) después de #7. Ver `ESTADO_PR_MOBILE.md` y `PENDIENTES_INTEGRACION.md`.

No subas nada hasta tener los 8 bloqueantes de `PENDIENTES_Y_DEPENDENCIAS.md` resueltos.

## 1. Integrar el código, en este orden

1. Backend #71 y #72 (ya en `generation` del backend), y el futuro `DELETE /users/me`.
2. MobileApp #1 → #2 → #3 → D → A → B → C (apiladas). Al fusionar cada una, cambia la base de la
   siguiente a `generation` si GitHub no lo hace solo.

## 2. Decidir el identificador (una sola vez)

En `android/gradle.properties`:

```properties
kora.applicationId=pe.fitsense.kora
```

Ver `IDENTIFICADOR_APLICACION.md`.

## 3. Crear y custodiar la clave de subida

En tu computadora, siguiendo `FIRMA_Y_AAB.md` §1–4:

```bash
keytool -genkeypair -v -keystore kora-upload.jks -alias upload -keyalg RSA -keysize 2048 -validity 10000
```

Luego crea `android/key.properties`, que no se versiona.

## 4. Tener los servicios publicados

- Backend con HTTPS y `DELETE /users/me` activo.
- Página web de eliminación de cuenta.
- Política de privacidad.

## 5. Compilar el AAB

```bash
flutter build appbundle --release --dart-define=API_BASE_URL=https://<dominio>/api/v1 --dart-define=ACCOUNT_DELETION_ENABLED=true --dart-define=ACCOUNT_DELETION_WEB_URL=https://<pagina-eliminacion> --dart-define=PRIVACY_POLICY_URL=https://<politica>
```

Si falta algo, la compilación se detiene y dice qué.

## 6. Verificar el AAB

```bash
jarsigner -verify -verbose -certs build/app/outputs/bundle/release/app-release.aab
```

Debe decir `jar verified` y tu `CN`, no `Android Debug`.

Con `bundletool` (opcional) puedes revisar el manifiesto:

```bash
java -jar bundletool.jar dump manifest --bundle build/app/outputs/bundle/release/app-release.aab
```

Comprueba `package`, `targetSdkVersion="36"` y `android.permission.INTERNET`.

## 7. Play Console

1. Crea la app con el identificador aprobado. Play App Signing viene activado por defecto.
2. **Contenido de la app**: política de privacidad, declaración de apps de salud (con investigación),
   seguridad de los datos, público 18+, acceso para el revisor (cuenta de prueba) y URL de eliminación
   de cuenta.
3. **Ficha**: icono de 512×512, gráfico de 1024×500, capturas y descripciones.
4. **Prueba cerrada**: sube el AAB, invita a 12 testers o más y mantenlos 14 días (cuenta personal
   reciente).
5. Solicita el acceso a producción.

## 8. Prueba física antes de subir (Android 13, 14, 15 y 16)

Con el APK debug por USB (`docs/validacion/GUIA_INSTALACION_APK.md`) o con el AAB por la pista interna:

| Qué probar | Esperado |
|---|---|
| Barras del sistema en login, registro, perfil, dashboard, rutinas, sesión en vivo, tour y resultado | Ningún botón ni campo debajo de la barra de estado o de navegación; el teclado no tapa el campo activo |
| Gesto atrás en el tour inicial | Retrocede un paso; en el paso 1 la app pasa a segundo plano y al abrirla sigue en el paso 1 |
| Gesto atrás en el repaso desde Perfil | En el paso 1 vuelve a Perfil |
| Gesto atrás en la espera de la rutina | La app pasa a segundo plano; al volver sigue la espera o aparece el plan |
| Animación predictiva (Android 14+) | Se ve la vista previa al deslizar, sin saltos raros |
| Perfil → Cuenta → Eliminar mi cuenta | Con el backend que tenga `DELETE /users/me`: «Tu cuenta fue eliminada» (o «Solicitud recibida» si es diferido) y vuelta al login; sin él: «todavía no está disponible» |
| Modo avión | «Seguimos intentando», sin pedir otra generación |
| Fuente máxima y TalkBack | Todo legible; TalkBack solo lee la tarjeta del tour |

Si algo falla, toma una captura y el log:

```bash
adb exec-out screencap -p > kora.png
```

```bash
adb logcat -d -s flutter > kora-flutter.txt
```
