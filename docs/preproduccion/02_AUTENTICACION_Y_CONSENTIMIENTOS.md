# 02 · Autenticación, contraseña, correo, términos, privacidad y consentimiento de investigación

Código `generation` `76dcf34` · Backend `generation` `77b9df3` ejecutado en local (IA apagada, base aislada, cuentas
sintéticas). Evidencia: [`evidencia/contratos-backend-local.txt`](evidencia/contratos-backend-local.txt),
[`evidencia/recuperacion-backend-local.txt`](evidencia/recuperacion-backend-local.txt), capturas `A2`–`A6`, `B3`, `F4`.

## 1. Estado de los 12 puntos de autenticación

| # | Punto | Mobile | Backend | Estado | Comentario |
|---|---|---|---|---|---|
| 1 | Pantalla de registro | `kora_auth_form.dart` (`register: true`) | `POST /auth/register` | **CON ERROR** | Ver §2 (participación y zona horaria) |
| 2 | Validación de correo | Formato (`looksLikeEmail`) | `@Email` | IMPLEMENTADA Y VERIFICADA | Solo formato |
| 3 | Validación de contraseña | `passwordProblem` 8–72, no solo espacios | `@Size(min=8,max=72)` | IMPLEMENTADA Y VERIFICADA | Mismas reglas en ambos lados |
| 4 | Inicio de sesión | `login()` + `/users/me` | `POST /auth/login` (JWT 7 días) | IMPLEMENTADA Y VERIFICADA | Tras registrarse hay que iniciar sesión a mano (M-34) |
| 5 | Cierre de sesión | Cancela recordatorios, desvincula push, borra JWT | JWT sin estado | IMPLEMENTADA Y VERIFICADA | — |
| 6 | Sesión persistente | `restoreSession()` en el splash | `GET /users/me` | IMPLEMENTADA Y VERIFICADA | Sin red no se cierra la sesión |
| 7 | Sesión caducada | `AuthInterceptor` → login + «Tu sesión expiró» | 401 | IMPLEMENTADA Y VERIFICADA | Verificado hoy: tras cambiar la clave, el JWT anterior recibe 401 |
| 8 | Cambio de contraseña con sesión | — | No existe (`/users/me/password` → 404) | NO IMPLEMENTADA | M-28 (P2) |
| 9 | Recuperación de contraseña | Completa tras `PASSWORD_RECOVERY_ENABLED=true` | Completa, sin proveedor de correo en producción | **PARCIAL** | §3 |
| 10 | Verificación de correo | — | No existe | NO IMPLEMENTADA | M-29 |
| 11 | Eliminación de cuenta | `account_deletion_page.dart` tras `ACCOUNT_DELETION_ENABLED=true` | `DELETE /users/me` (200/202) | IMPLEMENTADA SIN VALIDACIÓN INTEGRAL | Verificada en E2E web previa; desactivada por defecto (M-26) |
| 12 | Mensajes de error | `api_error.dart` + mensajes propios (401 login, 400/429 recuperación) | `ApiErrorResource` | PARCIAL | El 400 de zona horaria se muestra tal cual: «Zona horaria IANA no valida: Lima» |

## 2. Registro: dos problemas comprobados

### 2.1 Participación «Opcional» que deja a la persona sin rutina (P0, M-01)

- **Mobile** (`kora_auth_form.dart:180`): casilla «Acepto participar en el estudio — Opcional. Déjalo desmarcado si no
  deseas participar» (captura `A3`).
- **Backend**: `User.isEligibleForPlanGeneration() = canSignIn() && enrollment.isActiveParticipant()`
  (`User.java:113-115`); la generación lo comprueba antes de nada (`WeeklyTrainingPlanCommandServiceImpl.java:121`,
  `PlanGenerationOperationService.java:182`).
- **Comprobado en local:** cuenta sin participación → `POST /users/me/plan/generation` **422** «En este momento no es posible
  preparar tu rutina. Si persiste, contacta al equipo del estudio.» `GET /users/me/plan/limitations` → 422 «El usuario 1
  no esta activo en el estudio: no se le generan planes.»
- **En la app real** (captura `B3`): la persona completa los 5 pasos del perfil, ve «Generando…» 30 s (`B2`) y termina en
  «Tu perfil está guardado. En este momento no es posible preparar tu rutina…» con un único botón «Reintentar generación»
  que **siempre** fallará, sin opción de cerrar sesión ni explicación.
- **Ninguna prueba previa cubrió este camino**: todos los arneses E2E marcan la casilla
  (`docs/validacion/e2e/register.js:7`, `docs/preparacion_google_play/integracion_backend_5977/evidencia/arnes/register.js:7`).

**Decisión necesaria (producto + Backend + equipo del estudio):** ¿Kora admite «usuarios habituales» que no participan?

| Opción | Mobile | Backend |
|---|---|---|
| A. Solo participantes (estado actual del Backend) | La participación deja de ser «opcional»: se presenta como condición para usar Kora, con el consentimiento informado (§4). Quien no acepta no crea la cuenta o recibe una explicación clara | Ninguno (ya lo exige) |
| B. Kora también para no participantes | La casilla sigue siendo opcional y se distingue el tipo de usuario en Perfil | Permitir generar planes a no participantes y excluirlos de los análisis del estudio |

Hasta decidirlo, **no debe distribuirse una versión con la casilla «Opcional»**.

### 2.2 Zona horaria como texto libre (P1, M-18)

- `kora_auth_form.dart:179`: campo «Zona horaria» con `America/Lima` escrito; la persona puede borrarlo y escribir.
- Comprobado en local: `Lima` → 400 «Zona horaria IANA no valida: Lima»; `america/lima` → 400; `GMT-5` → 201; vacío → 201
  con `America/Lima`.
- La zona decide `scheduledDate`, el vencimiento `expiresAt` (23:59 local) y la hora de los recordatorios.
- **Propuesta:** no pedirla. Enviar la del teléfono (o `America/Lima` si el estudio es solo en Perú) y mostrarla en Perfil.
  Criterio: un registro nunca falla por la zona horaria.

## 3. Recuperación de contraseña

### 3.1 Qué existe ya (reutilizable)

| Pieza | Archivo | Estado |
|---|---|---|
| Botón «¿Olvidaste la clave?» | `kora_auth_form.dart:161-176` | Sin la bandera abre un diálogo «todavía no está disponible… contacta al equipo del estudio» |
| Pantalla «¿Olvidaste tu contraseña?» (correo) | `forgot_password_form.dart` (captura `A5`) | Completa |
| Pantalla «Restablecer contraseña» (código + nueva clave ×2) | `reset_password_form.dart` | Completa; explica «Caduca en 30 minutos y sirve una sola vez» |
| Servicio | `auth_remote_datasource.dart:31-41`: `POST /auth/password-reset/request {email}` y `/confirm {token, newPassword}` | Contrato correcto |
| Mensajes | 400 → «El código no es válido, ya se usó o caducó. Solicita uno nuevo.»; 429 → «Demasiadas solicitudes…» | Correctos |
| Bandera | `ApiConstants.passwordRecoveryAvailable` (`--dart-define=PASSWORD_RECOVERY_ENABLED`) | Apagada por defecto |

### 3.2 Comprobado hoy contra el Backend local (entrega `dev-log`)

| Caso | Resultado |
|---|---|
| Solicitar con correo existente / inexistente | 202, mismo mensaje (no revela si existe) |
| Código recibido | 43 caracteres (Base64 URL de 32 bytes), caduca a los 30 min |
| Confirmar con código inválido | 400 «El codigo de recuperacion no es valido o ha caducado.» |
| Confirmar válido | 204; **el JWT anterior pasa a 401** (revocación por `token_version`) |
| Reutilizar el código | 400 |
| Clave anterior / nueva | 401 / 200 |
| 4 solicitudes más en la misma hora | 202 todas (el límite de 3 por hora y cuenta descarta en silencio; no hay 429 por cuenta) |

### 3.3 Qué falta

| Falta | Dónde | Detalle |
|---|---|---|
| Proveedor de correo en producción | **Backend / infraestructura** | `fitsense.password-reset.delivery=none`, `fitsense.mail.transport=none` por defecto (`application.properties:19,26`). Admite `smtp`, `resend`, `brevo`; la clave solo por variable de entorno |
| Remitente y plantilla aprobados | Backend + equipo del estudio | `FITSENSE_MAIL_FROM`, nombre «Kora», texto del correo |
| Encender la bandera en la compilación del estudio | Mobile (configuración, sin código) | `--dart-define=PASSWORD_RECOVERY_ENABLED=true` solo cuando el correo funcione |
| «Ya tengo un código» | Mobile | Si Android cierra Kora mientras la persona mira su correo, al volver no hay forma de llegar a «Restablecer» sin pedir otro código (la ruta solo se abre tras enviar) |
| Código de 43 caracteres | Backend o Mobile | Hay que copiarlo y pegarlo; escribirlo a mano es impracticable. Mitigación sin Backend: pegar desde el portapapeles con un botón. Con Backend: enlace (§3.4) |
| Enlace que abre la app | Backend + web + Mobile | `fitsense.password-reset.link-template` (https con `{token}`) ya existe pero vacío; Mobile no declara App Links (`AndroidManifest.xml` solo tiene el `MAIN/LAUNCHER`) |

### 3.4 Flujo propuesto (no implementado)

```
Iniciar sesión → «¿Olvidaste tu contraseña?» → correo → «Enviar enlace»
   → pantalla «Revisa tu correo» (con «Ya tengo un código» y «Reenviar en 60 s»)
   → correo con enlace https://<dominio>/restablecer?token=… (y el código como respaldo)
   → el enlace abre Kora en «Nueva contraseña» con el código ya puesto
       (si Kora no está instalada, una página web del mismo dominio permite cambiarla)
   → nueva contraseña ×2 → «Contraseña actualizada» → Iniciar sesión con el correo ya escrito
```

| Situación | Comportamiento esperado |
|---|---|
| Enlace caducado o usado | «Este enlace ya no sirve (caduca a los 30 minutos y se usa una vez). Pide uno nuevo.» + botón que vuelve a la pantalla de correo con el correo escrito |
| Sin red al enviar o confirmar | Mensaje de conexión; los campos se conservan; nada se da por enviado |
| La app se cerró mientras miraba el correo | El enlace la abre directamente; sin enlace, «Ya tengo un código» desde «¿Olvidaste…?» |
| Sesión abierta en otro teléfono | Queda cerrada (el Backend ya revoca el JWT); al volver ve «Tu sesión expiró» |
| Correo inexistente | Mismo mensaje que si existe (ya es así) |

Dependencias: App Links requiere un dominio con `/.well-known/assetlinks.json` (huella del certificado de firma de
`pe.fit.kora`) y la plantilla del Backend. Sin dominio, la opción mínima es **correo con código + botón «Pegar código»**:
solo cambios de Mobile pequeños más el proveedor de correo del Backend.

**Criterios de aceptación:** con proveedor real y una cuenta sintética, la persona recupera el acceso sin ayuda en menos de
3 minutos; enlace caducado y sin red probados; el JWT anterior deja de servir; la prueba se repite en un teléfono Android.

## 4. Términos, privacidad y consentimiento de investigación

### 4.1 Lo que ofrece el Backend (V63)

| Elemento | Estado verificado hoy |
|---|---|
| Tipos separados: `STUDY_PARTICIPATION`, `TERMS_OF_SERVICE`, `PRIVACY_POLICY` (`ConsentimientoService.java`) | ✓ |
| Versión vigente de condiciones y privacidad | **Ninguna**: `currentVersions` = `{STUDY_PARTICIPATION: "MVP-1.0", TERMS_OF_SERVICE: null, PRIVACY_POLICY: null}` |
| `enforcedOnSignup` | `false`. Encenderlo exige tener ambas versiones |
| Aceptar en el registro: `acceptedTermsVersion`, `acceptedPrivacyVersion` en `SignUpResource` | Existen. **Mobile no los envía** |
| Aceptar después: `POST /users/me/consents {type, documentVersion}` | Solo la versión vigente; hoy 422 «Todavia no hay una version aprobada…» |
| Consentimiento de investigación | Solo en el registro (`CASILLA_REGISTRO`, versión `MVP-1.0`); la reincorporación la gestiona el equipo |
| Retirada | `POST /users/me/withdraw` o `/consents/STUDY_PARTICIPATION/withdraw`: marca `withdrawnAt` y retira al usuario (verificado) |
| Texto o URL de los documentos | **El Backend no los sirve**: solo versiones |

### 4.2 Lo que permite Mobile hoy

| Requisito de la orden | Estado | Evidencia |
|---|---|---|
| Leer términos y condiciones | **No** en el registro. Tras iniciar sesión, solo si hay versión publicada (`ConsentPage`), mostrando la URL como texto seleccionable con «Copiar enlace» (`consent_page.dart:82-89`); no se abre el navegador (no hay `url_launcher`) | `consent_page.dart`, `app_links.dart:16-19` (`TERMS_URL`, `PRIVACY_POLICY_URL` vacías) |
| Consultar la política de privacidad | Igual que arriba | — |
| Registrar las aceptaciones | Tras el inicio de sesión, una casilla por documento, ninguna premarcada (`consent_page.dart`) | `consents_test.dart` |
| Consultar el consentimiento informado | **No**: no hay ningún texto del consentimiento | `kora_auth_form.dart:180` |
| Aceptar o rechazar participar | Casilla en el registro; rechazar deja la cuenta sin rutina (§2.1) | Captura `A3`, `B3` |
| Distinguir habituales de participantes | Perfil → Cuenta: «Participas en el estudio · código P-009» / «No participas» / «Te retiraste el…» | Captura `F4` |
| Mostrar la versión vigente | Perfil → Cuenta: «Condiciones de uso: todavía sin versión publicada» | Captura `F4` |
| Informar de los datos recopilados | **No** hay ninguna explicación en la app | — |
| Opciones para retirar el consentimiento | «Retirarme del estudio» en Perfil → Cuenta (con confirmación) | `dashboard_page.dart:1287-1305` |
| No mezclar términos con investigación | ✓ Son casillas y momentos distintos | `consents_repository.dart:6-17` |

### 4.3 Hallazgos

| ID | Hallazgo | Prioridad | Depende de |
|---|---|---|---|
| M-02 | **El consentimiento de investigación no es informado**: se registra `STUDY_PARTICIPATION` con la versión `MVP-1.0` sin que la persona haya visto ningún documento, ni qué datos se recogen, ni cómo retirarse | **P0** | Equipo del estudio (texto aprobado por el comité), Backend (servir texto o URL por versión) |
| M-03 | Si el Backend enciende `enforce-on-signup`, **todos los registros de Mobile fallarán** (Mobile no envía `acceptedTermsVersion`/`acceptedPrivacyVersion`) | **P0 condicionado**: bloquea el día que se encienda | Backend + Mobile coordinados |
| M-27 | Las URL de documentos no se abren (solo copiar) y están vacías | P1 | Documentos publicados |
| M-17 | El diálogo de retirada dice «puedes seguir usando la app», pero el Backend no generará más planes (verificado: 422 tras retirarse; el plan de la semana en curso sigue visible) | P1 | Texto acordado con el equipo del estudio |

### 4.4 Propuesta (no implementar sin acuerdo con Backend)

1. **Registro en dos pasos:** (a) datos de la cuenta; (b) «Antes de empezar»: condiciones de uso y política de privacidad
   (lectura obligatoria dentro de la app, con su versión), una casilla cada una; (c) consentimiento informado del
   estudio en una pantalla propia con: propósito, duración (12 semanas), qué datos se recogen (perfil, entrenamientos,
   esfuerzo, dolor reportado, uso de notificaciones), quién accede, cómo se seudonimiza (código P-xxx), cómo retirarse y qué
   pasa con los datos, contacto del equipo; botones «Acepto participar» / «No acepto».
2. Mobile envía `acceptedTermsVersion`, `acceptedPrivacyVersion` y `acceptsStudyParticipation` en el mismo `POST
   /auth/register` (el Backend ya lo guarda en una sola transacción).
3. **No crear ninguna pantalla de aceptación mientras el Backend no tenga versión aprobada y no sirva el texto** (regla
   de la orden). La pantalla actual `ConsentPage` ya respeta esto: no aparece si no hay versión.
4. Perfil → Cuenta: «Ver lo que aceptaste» (documentos y versión) y «Retirarme del estudio» con el texto correcto sobre lo
   que pasa después.

**Requisitos de Backend:** endpoint público (sin JWT) con la versión vigente y el texto o la URL de cada documento,
incluido el consentimiento del estudio; decisión sobre `enforce-on-signup`; versión del consentimiento ligada a un
documento real (hoy `MVP-1.0` no apunta a ningún texto).

**Criterios de aceptación:** ninguna cuenta queda registrada como participante sin haber mostrado el texto del
consentimiento de esa versión; condiciones y privacidad se leen dentro de la app; con `enforce-on-signup=true` el registro
funciona; la persona puede consultar en cualquier momento qué aceptó y retirarse con un texto que describe la realidad.
