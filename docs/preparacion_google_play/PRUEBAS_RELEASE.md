# Pruebas de release (19/11/2026)

> **Identificador:** el aprobado es **`pe.fit.kora`** (Firebase `kora-fitpe`; ver `IDENTIFICADOR_APLICACION.md`). Las
> menciones a `com.example.fitsense_mobile` o `pe.fitsense.kora` de este documento son el registro de lo que se probó entonces.

> **Actualización (20/11/2026):** esta prueba se hizo con el backend `a1ccf53`, cuando `DELETE /users/me` daba 405. La
> repetición con 5977d28 (200 pruebas, eliminación real, recuperación, edad y consentimientos) está en
> `REGRESION_FLUTTER.md` y `E2E_KORA_BACKEND_ACTUALIZADO.md`.

Rama final: `claude/play-c-account-deletion` (contiene #1, #2, #3 y las PR D, A, B y C).

## Suites

| Comprobación | Resultado |
|---|---|
| `flutter analyze` | No issues found |
| `flutter test` | **177 pasan, 0 fallan** (antes de esta orden: 142) |
| `flutter build web --release` | ✓ |
| `flutter build apk --debug` (arm64, USB) | ✓ |
| `flutter build apk --release` con URL de prueba explícita | ✓ (APK de evaluación, firmado con debug) |
| `flutter build apk --release` sin URL / con `10.0.2.2` / con HTTP / con IP privada / con dominio de prueba | **bloqueado** (5 casos, `CONFIGURACION_BACKEND_HTTPS.md`) |
| `flutter build appbundle` sin configuración | **bloqueado** con los 6 motivos de `PENDIENTES_Y_DEPENDENCIAS.md` |
| `flutter build appbundle` con clave de prueba desechable, identificador propuesto y URL de prueba | ✓; firma propia verificada; ese AAB no era publicable y se borró |

### Pruebas nuevas (35)

| Archivo | Pruebas | PR |
|---|---|---|
| `auth_social_cleanup_test.dart` | 4 | D |
| `welcome_tour_test.dart` (gesto atrás y borde a borde) | +5 | A |
| `edge_to_edge_test.dart` | 4 | A |
| `api_config_test.dart` | 9 | B |
| `account_deletion_test.dart` | 13 | C |

Las de D (acceso social) y A (gesto atrás) **fallan con el código anterior** (comprobado), así que
detectan el problema original. Siguen en verde Kapi, el tour, la navegación, la autenticación, la
persistencia, la generación asíncrona, el contrato con #71/#72, las fechas del dashboard y el perfil.

## Artefactos inspeccionados

| Comprobación | APK release | AAB release | APK debug |
|---|---|---|---|
| `android.permission.INTERNET` | ✓ (`aapt dump permissions`) | ✓ (manifiesto extraído del `.aab`) | ✓ |
| `targetSdkVersion` 36 / `compileSdkVersion` 36 | ✓ (`aapt dump badging`) | misma configuración | ✓ |
| `enableOnBackInvokedCallback=true` | ✓ (`aapt dump xmltree`) | ✓ | ✓ |
| Identificador | `com.example.fitsense_mobile` (sin aprobar) | `pe.fitsense.kora` con `-Pkora.applicationId` | `com.example.fitsense_mobile` |
| Firma | `CN=Android Debug` sin `key.properties` | `CN=Kora PRUEBA NO PUBLICAR` (clave desechable; `jar verified`) | debug |
| Páginas de 16 KB | librerías de 64 bits alineadas a 64 KB; `zipalign -P 16` ✓ | — | — |

`bundletool` no se pudo usar: descargar y ejecutar su jar desde GitHub quedó bloqueado por la política
del entorno. El manifiesto del AAB se comprobó extrayendo `base/manifest/AndroidManifest.xml` del
`.aab` y leyendo sus cadenas, y la firma con `jarsigner`.

## Prueba integral con el backend real

Backend `generation` (`a1ccf53`: #71 + #72 + #76), PostgreSQL local nueva (V59), IA apagada; app web
con `ACCOUNT_DELETION_ENABLED=true`.

| Paso | Resultado | Captura |
|---|---|---|
| 1–4 | Abrir, registrarse (201), iniciar sesión (200), perfil (201) | — |
| 5–6 | `POST /plan/generation` 202; tour de Kapi con la generación en curso | `F-01` |
| 7 | Primera rutina: `COMPLETED`, 1 operación, 1 plan | `F-02` |
| 8–9 | Rutinas y sesión abierta («Registrar ejercicio») | `F-03`, `F-04` |
| 10–11 | Perfil → Cuenta: retiro y eliminación separados; pantalla de eliminación, confirmación | `F-05`…`F-07` |
| — | `DELETE /users/me` → **405**: «todavía no está disponible… No se eliminó nada»; la cuenta sigue en la base y la sesión sigue abierta | `F-08` |
| 12 | Cerrar sesión → pantalla de login | `F-09` |

En el primer intento del paso 12, el arnés tocó la pestaña «Progreso» al desplazarse. Se repitió
desplazándose antes y cerró la sesión correctamente. Fue un problema del arnés, no de la app.

## No ejecutado

- **Android físico o emulador**: no hay dispositivo, y el emulador sin aceleración ya falló y no se
  repitió. Borde a borde y gesto atrás solo están verificados con pruebas de widget.
- Conexión HTTPS real: falta la URL de producción.
- `DELETE /users/me` real: el backend no lo tiene.
- CI de GitHub: el workflow de #3 correrá cuando llegue a `generation`. Sus pasos (analyze, test, web,
  APK debug) pasan en local; el guardián de release no afecta al APK debug del CI.
