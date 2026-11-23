# Pendientes y dependencias para publicar Kora

> **Identificador:** el aprobado es **`pe.fit.kora`** (Firebase `kora-fitpe`; ver `IDENTIFICADOR_APLICACION.md`). Las
> menciones a `com.example.fitsense_mobile` o `pe.fitsense.kora` de este documento son el registro de lo que se probó entonces.

> **Actualización (20/11/2026):** con el backend 5977d28, `DELETE /users/me` ya existe y está integrado (bloqueante 2), la app
> valida la edad mínima y la recuperación funciona con correo. El estado vigente está en `PENDIENTES_INTEGRACION.md`.

`flutter build appbundle` los enumera y se niega a compilar mientras falte alguno:

```
Compilacion release bloqueada (docs/preparacion_google_play/):
 - Falta --dart-define=API_BASE_URL=https://... (URL HTTPS del backend de produccion).
 - Falta android/key.properties: el AAB para Google Play no se firma con la clave debug.
 - applicationId de ejemplo (com.example.fitsense_mobile): define kora.applicationId con el identificador aprobado.
 - La eliminacion de cuenta esta desactivada: Play exige poder borrar la cuenta desde la app (...).
 - Falta --dart-define=ACCOUNT_DELETION_WEB_URL=https://... (pagina publica exigida por Google Play).
 - Falta --dart-define=PRIVACY_POLICY_URL=https://... (pagina publica exigida por Google Play).
```

## Bloqueantes

| # | Pendiente | Depende de | Qué hacer después |
|---|---|---|---|
| 1 | URL HTTPS del backend desplegado | Despliegue (Railway u otro) | Compilar con `API_BASE_URL=https://<dominio>/api/v1` |
| 2 | `DELETE /users/me` en servicio y su contrato | Backend | Revisar `account_deletion_repository.dart` contra el contrato, repetir `account_deletion_test.dart` y el E2E, y compilar con `ACCOUNT_DELETION_ENABLED=true` |
| 3 | Política de datos del estudio al borrar (borrar o anonimizar) | Propietario y comité de ética | El backend la implementa; la app ya remite al consentimiento y a la política |
| 4 | Página web pública de eliminación | Etapa web | `ACCOUNT_DELETION_WEB_URL=https://...` |
| 5 | Política de privacidad publicada | Propietario | `PRIVACY_POLICY_URL=https://...` y en la ficha de Play |
| 6 | Identificador aprobado | Propietario | `kora.applicationId=pe.fitsense.kora` (u otro) en `android/gradle.properties` |
| 7 | Clave de subida propia | Propietario | `android/key.properties` y Play App Signing (`FIRMA_Y_AAB.md`) |
| 8 | Prueba en Android 13 a 16 reales | Teléfono | `GUIA_PUBLICACION_ANDROID.md` §8 |

## Requisitos de Play Console (fuera del código)

- Declaración de apps de salud, con la sección de **investigación en salud**: aprobación del comité de
  ética y consentimiento informado.
- Formulario de seguridad de los datos: correo, nombre, datos de salud y fitness, cifrado en tránsito
  y eliminación.
- Público objetivo de 18 años o más. La app no valida la edad mínima; conviene añadirlo en el perfil en
  una PR aparte.
- Cuenta de prueba para el revisor, en el backend de producción y con un plan ya generado.
- Ficha: icono de 512×512, gráfico de 1024×500, capturas, descripciones.
- Cuenta personal creada después del 13/11/2023: prueba cerrada con 12 testers durante 14 días.

## Backend, relacionado y no bloqueante del código móvil

- **Recuperación de contraseña sin envío de correo** (`delivery=none`): «¿Olvidaste la clave?» no
  completa el flujo. Un revisor podría marcarlo como roto. O se configura el proveedor de correo o se
  decide ocultar la opción.

## Fuera de alcance de esta orden

E002, H2, Replicate, catálogo, validadores, adherencia, progresión y reincorporación: sin cambios.
