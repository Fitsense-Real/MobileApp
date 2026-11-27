# 01 · Inventario funcional de Mobile Kora

| | |
|---|---|
| Código auditado | `Fitsense-Real/MobileApp`, rama `generation`, commit `76dcf34` (sin modificar) |
| Backend de referencia | `Fitsense-Real/Backend`, rama `generation`, commit `77b9df3` (solo lectura; ejecutado en local) |
| Fecha | 27/11/2026 |
| Herramientas | Flutter 3.50.1 / Dart 3.14.0 (las de CI) |
| Alcance de esta auditoría | Revisar, probar y documentar. Sin cambios de código, sin merge, sin despliegue |

## Cómo se obtuvo cada resultado

| Tipo de evidencia | Qué es | Dónde |
|---|---|---|
| **Código** | Lectura de `lib/` y de los controladores y recursos del Backend | Rutas `archivo:línea` en cada fila |
| **Pruebas automáticas** | `flutter analyze` sin incidencias; `flutter test` **422 aprobadas, 0 fallidas, 31 omitidas** (re-ejecutado hoy) | [`evidencia/flutter-analyze-y-test.txt`](evidencia/flutter-analyze-y-test.txt) |
| **Backend real en local** | Backend `generation` compilado y ejecutado en este entorno con base aislada, **IA apagada** (motor de reglas), sin correo, sin salida a Internet, cuentas sintéticas `@audit.local` | [`evidencia/contratos-backend-local.txt`](evidencia/contratos-backend-local.txt), [`evidencia/recuperacion-backend-local.txt`](evidencia/recuperacion-backend-local.txt) |
| **Pruebas en vivo de Mobile** | `test/live/timed_exercise_live_test.dart` (3) y `push_backend_live_test.dart` (1) contra ese Backend: **4/4 aprobadas** | [`evidencia/pruebas-en-vivo-backend-local.txt`](evidencia/pruebas-en-vivo-backend-local.txt) |
| **Capturas** | App real compilada para web (release) contra ese Backend, 390 × 844 y 320 × 568 | [`evidencia/capturas/`](evidencia/capturas/) |
| **Documentación previa** | Auditorías y validaciones anteriores del repositorio | Citadas en cada fila |

**Lo que no se hizo y no se presenta como hecho:** ninguna prueba en teléfono Android físico ni en emulador (no hay
dispositivo en este entorno y nunca se ha ejecutado una, ver §4), ninguna llamada a Replicate ni generación con IA,
ningún acceso a producción ni al usuario 48.

## Estados

`IMPLEMENTADA Y VERIFICADA` · `IMPLEMENTADA SIN VALIDACIÓN INTEGRAL` · `PARCIAL` · `NO IMPLEMENTADA` · `CON ERROR` ·
`NO APLICA`. "Verificada" significa probada contra el Backend real (local) o con pruebas automáticas que cubren el
comportamiento; **nunca** significa probada en un teléfono.

## 1. Inventario

| # | Funcionalidad | Estado | Evidencia (código · pruebas · ejecución) | Hallazgos |
|---|---|---|---|---|
| F01 | Registro de usuarios | **CON ERROR** | `kora_auth_form.dart:39-60,179-180`. Backend local: registro 201 con y sin participación. Captura `A3` | La casilla de participación se presenta como «Opcional», pero el Backend **solo genera planes a participantes activos**: quien no la marca termina el perfil, espera 30 s y queda sin rutina (`B3`). La zona horaria es texto libre: `Lima` → 400. [M-01](07_PLAN_DE_CIERRE_MOBILE.md), [M-18](07_PLAN_DE_CIERRE_MOBILE.md) |
| F02 | Validación de correo (formato) | IMPLEMENTADA Y VERIFICADA | `domain/email_format.dart`; `recovery_email_format_test.dart` | Solo formato. No hay verificación de propiedad del correo (F10) |
| F03 | Validación de contraseña | IMPLEMENTADA Y VERIFICADA | `domain/password_rules.dart` (8–72, no solo espacios, igual que el Backend `@Size(min=8,max=72)`); `password_rules_test.dart` | — |
| F04 | Inicio de sesión | IMPLEMENTADA Y VERIFICADA | `auth_repository_impl.dart:15-36` (guarda el JWT y valida con `/users/me`); 401 → «Correo o contraseña incorrectos.»; Backend local 200 | Tras registrarse hay que volver a escribir las credenciales (no inicia sesión solo) — [M-34](07_PLAN_DE_CIERRE_MOBILE.md) |
| F05 | Cierre de sesión | IMPLEMENTADA Y VERIFICADA | `auth_viewmodel.dart:102-117`: cancela recordatorios, desvincula el dispositivo push con el JWT aún válido y borra el token; `push_notifications_test.dart`, E2E previa (`docs/auditoria_final`) | Conserva 48 h los resultados P1 de esa cuenta, por diseño |
| F06 | Sesión persistente | IMPLEMENTADA Y VERIFICADA | `splash_page.dart:17-23`, `session_service.dart` (sin red no cierra sesión; solo un 401 borra el token); `secure_storage_upgrade_test.dart` | Migración 9.x→10.x de almacenamiento seguro nunca probada en teléfono (`PRUEBA_ACTUALIZACION_SAMSUNG.md`) |
| F07 | Sesión caducada | IMPLEMENTADA Y VERIFICADA | `auth_interceptor.dart`, `session_expiry.dart`; `session_expiry_test.dart`. Backend local: tras cambiar la clave, el JWT anterior → 401 | — |
| F08 | Cambio de contraseña con sesión iniciada | NO IMPLEMENTADA | Sin pantalla. Backend: `POST/PUT /users/me/password` → 404 (no existe) | Requiere Backend. [M-28](07_PLAN_DE_CIERRE_MOBILE.md) |
| F09 | Recuperación de contraseña | **PARCIAL** | Pantallas y servicios completos tras `--dart-define=PASSWORD_RECOVERY_ENABLED=true` (`api_constants.dart:22`). Backend local con `dev-log`: código de 43 caracteres, caduca a 30 min, un solo uso, revoca el JWT anterior (todo verificado). Producción: `fitsense.password-reset.delivery=none`, `fitsense.mail.transport=none` | Sin proveedor de correo no funciona para nadie; por defecto el botón dice «todavía no está disponible». [M-04](07_PLAN_DE_CIERRE_MOBILE.md), detalle en [02](02_AUTENTICACION_Y_CONSENTIMIENTOS.md) |
| F10 | Verificación de correo electrónico | NO IMPLEMENTADA | Ni Mobile ni Backend (404) | Un correo mal escrito impide la recuperación. [M-29](07_PLAN_DE_CIERRE_MOBILE.md) |
| F11 | Eliminación de cuenta | IMPLEMENTADA SIN VALIDACIÓN INTEGRAL | `account_deletion_page.dart`, `local_account_data.dart`; `account_deletion_test.dart`; verificada en E2E web previa (`docs/auditoria_final`). Oculta salvo `ACCOUNT_DELETION_ENABLED=true` (`app_links.dart:9`) | Desactivada en la compilación por defecto; la URL web de eliminación está vacía. [M-26](07_PLAN_DE_CIERRE_MOBILE.md) |
| F12 | Configuración del perfil (onboarding de 5 pasos) | IMPLEMENTADA Y VERIFICADA | `onboarding_page.dart`; `onboarding_flow_test.dart`, `generation_screen_test.dart`; Backend local `POST /users/me/profile` 201; E2E previa | El perfil queda **de solo lectura** tras el primer plan (Backend 422) durante las 12 semanas. [M-25](07_PLAN_DE_CIERRE_MOBILE.md) |
| F13 | Objetivos y disponibilidad | IMPLEMENTADA Y VERIFICADA | `onboarding_page.dart:54-55,330-338` (días máx. 4 principiante / 6 resto, 15–180 min) | No modificables después (M-25) |
| F14 | Equipamiento | IMPLEMENTADA Y VERIFICADA | `equipment_picker.dart`, `profile_repository.dart`; `docs/onboarding/GENERACION_30S_Y_EQUIPAMIENTO.md` | No modificable después (M-25) |
| F15 | Restricciones de movimiento (V25) | IMPLEMENTADA Y VERIFICADA | `onboarding_page.dart:356-358` (5 interruptores); `profile_contract_v55_test.dart` | Solo al inicio. Las «notas de salud» son informativas y no las usa nadie (`onboarding_page.dart:360-361`) |
| F16 | Generación de rutinas (primer plan, asíncrona) | IMPLEMENTADA Y VERIFICADA (participantes) · **CON ERROR** (no participantes) | `first_plan_generation_controller.dart`, `generating_plan.dart`; `first_plan_generation_test.dart`, `welcome_tour_test.dart`. Backend local: operación `COMPLETED` en ~1 s con motor de reglas; no participante → 422 | Generación con IA **no probada** (prohibido consumir Replicate). La pantalla mantiene 30 s aunque el Backend ya haya rechazado. M-01, [M-21](07_PLAN_DE_CIERRE_MOBILE.md) |
| F17 | Visualización de planes | IMPLEMENTADA Y VERIFICADA | `dashboard_page.dart` (Inicio, Rutinas); E2E previa 3/3 iguales al Backend; capturas `C1`, `C3` | En Rutinas el bloque «Lo que tu plan no puede cubrir» ocupa toda la primera pantalla (`C3`). [M-14](07_PLAN_DE_CIERRE_MOBILE.md). Titular roto en 320 px (`D1`) [M-19](07_PLAN_DE_CIERRE_MOBILE.md) |
| F18 | Visualización de ejercicios | **PARCIAL** | `exercise_media.dart`, `planned_workout_page.dart:562-600,679-702`; `exercise_media_semantics_test.dart`; capturas `C4`, `C6`, `E1` | GIF de terceros (licencia no documentada), 180 × 180 px, sin controles; no se muestra la guía de esfuerzo que envía el Backend; músculos en inglés. Ver [04](04_VISUALIZACION_DE_EJERCICIOS.md) |
| F19 | Registro de entrenamientos (en vivo) | IMPLEMENTADA Y VERIFICADA | `planned_workout_page.dart`, `exercise_result_dialog.dart`; `exercise_results_test.dart`; Backend local: PUT reemplaza (no acumula), finalizar dos veces → 422 | Diálogo con 4 campos y etiquetas truncadas (`C8`, `C9`). [M-10](07_PLAN_DE_CIERRE_MOBILE.md) |
| F20 | Sesiones completas y parciales (D-M1) | IMPLEMENTADA Y VERIFICADA | `workout_rules.dart:83-105`; `timed_exercise_results_test.dart`; **en vivo hoy 3/3**: «Lo completé» por tiempo = 100 %, parcial 150/270 s = 55,56 % | — |
| F21 | Registro retroactivo («Ya lo hice») | IMPLEMENTADA Y VERIFICADA | `planned_workout_page.dart` `report()`; en vivo hoy: 100 % | Borradores solo en memoria (P3, fuera de alcance). El selector de fecha permite cualquier fecha desde el año 2000 (`planned_workout_page.dart:720`) |
| F22 | Registro de sesiones omitidas | IMPLEMENTADA Y VERIFICADA | `planned_workout_page.dart` `skip()`, `LackOfTimeDialog`; Backend local 204 (idempotente) | — |
| F23 | Historial de entrenamientos | **PARCIAL** | `plan_history_sheet.dart` (semanas, entrenamientos y su estado) | No se pueden ver los resultados de sesiones pasadas (porcentaje, esfuerzo, ejercicios). [M-20](07_PLAN_DE_CIERRE_MOBILE.md) |
| F24 | Adherencia y progreso | IMPLEMENTADA Y VERIFICADA | `dashboard_page.dart:793-1050` muestra `weightedAdherencePct` del Backend sin recalcularlo; `adherence_history_test.dart`; E2E previa 59,3 % = Backend | Etiquetas técnicas («pp», «Cumplimiento en lo registrado») y «Riesgo de abandono» visible para el participante. [M-15](07_PLAN_DE_CIERRE_MOBILE.md) |
| F25 | Adaptaciones P2 | IMPLEMENTADA Y VERIFICADA | `adaptation_text.dart` (traduce `resultado`/`decision`, nunca muestra códigos; códigos desconocidos → texto general); `adaptation_history_test.dart`; capturas `docs/mejoras/p2/` | Hoy no se ejecutó un cierre semanal (requiere mover fechas); se apoya en las pruebas y en la validación P2 |
| F26 | Seguridad por dolor O20 | IMPLEMENTADA Y VERIFICADA (contra Backend real en local, auditorías previas) | `pain_safety.dart`, `planned_workout_page.dart` (`checkRoutine`, `refusal`, `hold`); `pain_o20_test.dart`, `o20_rutina_desactualizada_test.dart`; `docs/o20/validacion/INFORME_VALIDACION_O20.md` | Las 9 pruebas en vivo O20 requieren un Backend preparado por etapas y hoy se omitieron. Reportar dolor solo es posible desde «No lo hice/parcial → Motivo». [M-12](07_PLAN_DE_CIERRE_MOBILE.md) |
| F27 | Persistencia de resultados pendientes P1 | IMPLEMENTADA SIN VALIDACIÓN INTEGRAL | `pending_results_store.dart` (almacenamiento seguro, clave por cuenta, 48 h, entradas dañadas descartadas); `pending_results_persistence_test.dart` | El escenario real (Android cierra la app, se pierde la red) solo se probó con pruebas de widget; pendiente en teléfono (guía S13/S15) |
| F28 | Notificaciones push (Firebase `kora-fitpe`) | IMPLEMENTADA SIN VALIDACIÓN INTEGRAL | `push_controller.dart`, `push_device_repository.dart`; `push_*_test.dart`; **en vivo hoy**: contrato `PUT/DELETE /push-devices` 1/1 | Nunca se recibió un push real en un teléfono. Solo Android (`push_messaging.dart:48`). Ver [M-23](07_PLAN_DE_CIERRE_MOBILE.md) |
| F29 | Recordatorios locales de entrenamiento | IMPLEMENTADA SIN VALIDACIÓN INTEGRAL | `reminder_planner.dart`, `reminder_scheduler.dart`; `reminders_test.dart`, `reminder_channel_test.dart` | **Quedan desactivados por defecto** tras la explicación de avisos del onboarding (`reminders_controller.dart:107`). [M-16](07_PLAN_DE_CIERRE_MOBILE.md) |
| F30 | Actualización de pantallas | IMPLEMENTADA Y VERIFICADA | Deslizar para actualizar, `PainSafetyResumeRefresher`, relectura al volver del segundo plano (`planned_workout_page.dart:56`); `dashboard_live_test.dart` | — |
| F31 | Manejo de errores | PARCIAL | `api_error.dart` (mensajes por estado HTTP, sin pistas técnicas en release); cada sección del Inicio con su «Reintentar» | Algunos textos son técnicos o sin tildes porque vienen del Backend («deberias», «esta cerrada»); botón «Consultar estado de sesión» poco claro. [M-31](07_PLAN_DE_CIERRE_MOBILE.md) |
| F32 | Conectividad con el Backend | IMPLEMENTADA Y VERIFICADA | `api_config.dart` (release exige HTTPS público), `api_config_test.dart`; casos sin conexión de la generación (`docs/validacion/capturas-71-72/caso-sin-conexion.jpg`) | GIF sin conexión: aviso de texto, sin imagen de respaldo (`E1`) |
| F33 | Términos y política de privacidad | PARCIAL | `consents_repository.dart`, `consent_page.dart`; Backend: sin versión publicada (`currentVersions` nulas) | No se muestran en el registro; el enlace no se abre (solo copiar). Ver [02](02_AUTENTICACION_Y_CONSENTIMIENTOS.md) |
| F34 | Consentimiento informado del estudio | **NO IMPLEMENTADA** | La casilla registra `STUDY_PARTICIPATION` versión `MVP-1.0` sin mostrar ningún documento | [M-02](07_PLAN_DE_CIERRE_MOBILE.md) |
| F35 | Retirada del estudio | IMPLEMENTADA Y VERIFICADA (con texto engañoso) | `dashboard_page.dart:1287-1305`; Backend local: `withdrawnAt` y consentimiento retirado; generación posterior → 422 | El diálogo dice «puedes seguir usando la app», pero no habrá más planes. [M-17](07_PLAN_DE_CIERRE_MOBILE.md) |
| F36 | Recorrido de bienvenida (Kapi) | IMPLEMENTADA Y VERIFICADA | `welcome_tour_page.dart`, `tour_steps.dart` (10 pasos obligatorios); `welcome_tour_test.dart`; E2E previa | No explica cómo informar dolor ni qué es el esfuerzo percibido |
| F37 | iOS | NO APLICA (pendiente de decisión) | `push_messaging.dart:48` (push solo Android); sin `GoogleService-Info.plist` ni capacidades push en `ios/Runner` | Nunca compilado ni probado en este proyecto. [M-23](07_PLAN_DE_CIERRE_MOBILE.md) |

## 2. Código sin uso que conviene retirar (no afecta al usuario)

| Archivo | Situación |
|---|---|
| `authentication/presentation/widgets/register_form.dart`, `login_form.dart` | No se usan (las páginas usan `kora_auth_form.dart`); conservan la marca «FitSense» |
| `dashboard/presentation/providers/dashboard_provider.dart`, `state/dashboard_state.dart`, `viewmodels/dashboard_viewmodel.dart`, `widgets/dashboard_shimmer.dart`, `greeting_header.dart`, `progress_card.dart` | Archivos vacíos (0 líneas) |
| `dashboard/data/dashboard_repository.dart` `runCycle()` | Sin llamadas; el Backend lo cierra por defecto (`fitsense.cycle.manual-run.enabled=false`) |
| `onboarding_page.dart:84-97` | Rama inalcanzable (`if (data != null)` después de redirigir cuando existe perfil) |
| `app_routes.dart` `profile`, `assessment`, `progress`, `settings` | Rutas declaradas sin pantalla |

[M-30](07_PLAN_DE_CIERRE_MOBILE.md) — P2.

## 3. Endpoints del Backend que Mobile no usa

| Endpoint | Comentario |
|---|---|
| `POST /users/me/consents/{type}/withdraw` | Equivalente a `POST /users/me/withdraw`, que sí se usa |
| `GET /users/me/push-devices` | Diagnóstico; no necesario |
| `GET /users/me/metrics/weekly/{weekStartDate}` | Mobile usa la lista completa |
| `GET /users/me/plan/generation/latest` | Mobile recuerda el `operationId` localmente |
| `/account-deletion/*` | Para la página web pública de eliminación (fuera de Mobile) |
| `/admin/*`, `/config/active` | No son para participantes |

Detalle de contratos en [05](05_INTEGRACION_CON_BACKEND.md).

## 4. Dispositivo físico

Todos los documentos del repositorio coinciden: **nunca se ha ejecutado Kora en un teléfono ni en un emulador**
(`docs/validacion/PRUEBAS_ANDROID.md`, `docs/preparacion_google_play/VALIDACION_ANDROID.md`,
`docs/o20/validacion/GUIA_ANDROID.md` §0 «no hay ninguna prueba física hecha», `docs/mejoras/PENDIENTES.md`). Los APK se
compilaron e inspeccionaron, pero no se instalaron. Esta auditoría tampoco dispone de un teléfono. Ver
[06](06_RIESGOS_ESTUDIO_12_SEMANAS.md) R-05 y [07](07_PLAN_DE_CIERRE_MOBILE.md) M-05.
