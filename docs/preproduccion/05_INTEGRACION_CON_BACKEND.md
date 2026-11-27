# 05 · Integración con el Backend

Mobile `generation` `76dcf34` frente a Backend `generation` `77b9df3`. El Backend se compiló y ejecutó en este entorno
con una base PostgreSQL nueva (`kora_audit_mobile`), perfil `local-dev`, **IA apagada** (motor de reglas), sin
proveedor de correo, ciclo manual cerrado y sin salida a Internet. Solo cuentas sintéticas `@audit.local`.
**No se usó producción, ni el usuario 48, ni Replicate.**

## 1. Endpoints que usa Mobile

Todos los endpoints de `lib/core/api/api_constants.dart` y de los repositorios existen en los controladores del Backend
con el mismo método (comprobado hoy contra `@*Mapping` de los 18 controladores).

| Área | Endpoint | Mobile | Verificación hoy (Backend local) | Prueba automática |
|---|---|---|---|---|
| Autenticación | `POST /auth/register` | `auth_remote_datasource.dart` | ✓ 201 (con y sin participación; zona `Lima` → 400) | Simulada (`backend_contract_test.dart`) |
| | `POST /auth/login` | ídem | ✓ 200 / 401 | Simulada + en vivo (`push_backend_live_test`) |
| | `POST /auth/password-reset/request`, `/confirm` | ídem | ✓ 202 / 204 / 400; JWT anterior → 401 | Simulada |
| Cuenta | `GET /users/me`, `POST /users/me/withdraw`, `DELETE /users/me` | `auth_*`, `account_deletion_repository.dart` | ✓ `me`, ✓ `withdraw`; `DELETE` no repetido hoy (E2E previa) | Simulada |
| Consentimientos | `GET/POST /users/me/consents` | `consents_repository.dart` | ✓ GET (sin versiones publicadas); POST → 422 sin versión | Simulada (`consents_test.dart`) |
| Push | `PUT/DELETE /users/me/push-devices[/{fid}]`, `GET/PUT /users/me/notification-preferences` | `push_device_repository.dart` | ✓ **en vivo** (`push_backend_live_test`: registro, renovación, token FCM rechazado, sin JWT, otra cuenta, borrado idempotente); ✓ GET preferencias | Simulada + en vivo |
| Perfil | `GET/POST/PUT /users/me/profile` | `profile_repository.dart` | ✓ POST 201, GET | Simulada (`profile_contract_v55_test.dart`) |
| Catálogo | `GET /catalog/equipment-types`, `/exercises`, `/exercises/{id}` | `profile_repository.dart`, `catalog_repository.dart` | ✓ (instrucciones en español, músculos en inglés) | Simulada |
| Generación | `POST /users/me/plan/generation`, `GET …/{operationId}` | `plan_generation_repository.dart` | ✓ `COMPLETED` en ~1 s (motor de reglas); **422 si no participa** | Simulada (`first_plan_generation_test.dart`) |
| Planes | `GET /users/me/plan/current`, `/plan/{id}`, `/plans`, `/plan/limitations`, `/plan/adaptations`; `POST /plan/generate` | `plan_repository.dart` | ✓ current, plans, limitations, adaptations | Simulada + fixtures reales del demo (`test/fixtures/o20_demo_kora`) |
| Ejecución | `POST /workouts/{id}/start|skip|report`; `GET /sessions/current|{id}`; `PUT /sessions/{s}/exercises/{pe}`; `POST /sessions/{id}/finish|abandon` | `workout_repository.dart` | ✓ start 201, PUT reemplaza (no acumula), finish 200 y repetido 422, skip 204 idempotente, report 201 | Simulada + **en vivo** (`timed_exercise_live_test` 3/3) |
| Dolor (O20) | `GET /users/me/pain-exclusions[/effective|/confirmation-requests]`; `POST …/{id}/identification|reactivation` | `pain_exclusion_repository.dart` | ✓ GET (vacíos para una cuenta nueva) | Simulada (`pain_o20_test.dart`); en vivo en validaciones previas (`docs/o20/validacion/evidencia/`) |
| Analítica | `GET /users/me/metrics/weekly`, `/users/me/interventions` | `dashboard_repository.dart` | ✓ (vacíos antes del primer cierre) | Simulada (`adherence_history_test.dart` con `fixtures/adherencia_demo.json`) |
| Ciclo | `POST /cycle/run-for-me` | `dashboard_repository.dart` (sin uso en pantallas) | Cerrado por defecto en el Backend | — |

## 2. Pruebas reales frente a simuladas

| Flujo | Integración real (Backend en ejecución) | Solo simulada (fakes/fixtures) | Teléfono físico |
|---|---|---|---|
| Registro | ✓ hoy (contratos); E2E web previa (`docs/auditoria_final`, siempre marcando la participación) | `backend_contract_test.dart` | ✗ |
| Login / sesión | ✓ hoy; E2E web previa | `session_expiry_test.dart` | ✗ |
| Perfil | ✓ hoy; E2E web previa | `onboarding_flow_test.dart`, `generation_screen_test.dart` | ✗ |
| Generación | ✓ hoy con **motor de reglas**; E2E web previa. **Con IA: nunca en esta auditoría** (prohibido) | `first_plan_generation_test.dart` | ✗ |
| Consulta de planes | ✓ hoy; E2E web previa 3/3 | `dashboard_visual_test.dart` | ✗ |
| Registro de sesiones (D-M1) | ✓ hoy **4 pruebas de Mobile en vivo**; contratos | `exercise_results_test.dart`, `timed_exercise_results_test.dart` | ✗ |
| Adherencia | E2E web previa (59,26 % = Backend). Hoy no: requiere cerrar una semana moviendo fechas en la base | `adherence_history_test.dart` | ✗ |
| Adaptaciones / P2 | E2E web previa (ADAPT_LOCALIZED); validación P2 | `adaptation_history_test.dart` | ✗ |
| O20 | Validación previa contra Backend real local con cuentas sintéticas y cierres (`docs/o20/validacion/INFORME_VALIDACION_O20.md`). Hoy las 9 pruebas en vivo O20 se omiten: necesitan un Backend preparado por etapas (`KORA_O20_STAGE`…) | `pain_o20_test.dart`, `o20_rutina_desactualizada_test.dart` | ✗ |
| P1 | No aplica integración (almacenamiento local); el reenvío usa los mismos endpoints verificados | `pending_results_persistence_test.dart` | ✗ (el cierre real por Android es la prueba que falta) |
| Firebase | Contrato de dispositivos ✓ en vivo hoy. **Nunca** se recibió un push real de FCM en un teléfono | `push_*_test.dart` | ✗ |

**CI** (`.github/workflows`): `flutter analyze`, `flutter test` y compilación. Las 16 pruebas en vivo y las 15 de capturas
se omiten siempre en CI.

## 3. Incompatibilidades y huecos de contrato

| ID | Hallazgo | Lado | Prioridad |
|---|---|---|---|
| M-01 | El registro permite no participar; el Backend solo genera planes a participantes activos (`User.isEligibleForPlanGeneration`) | Producto + Backend + Mobile | **P0** |
| M-03 | `SignUpResource` admite `acceptedTermsVersion`/`acceptedPrivacyVersion`; Mobile no los envía: con `enforce-on-signup=true` todo registro fallaría | Mobile | **P0 condicionado** |
| M-02 | El Backend versiona consentimientos pero no sirve el texto ni la URL de ningún documento; `STUDY_PARTICIPATION` `MVP-1.0` no apunta a un texto | Backend + equipo del estudio | **P0** |
| M-07 | `effortGuidance` llega en cada plan y Mobile lo ignora | Mobile | P1 |
| M-08 | `targetMuscle`, `bodyPart`, `equipment`, `secondaryMuscles` son códigos en inglés (`quads`, `upper legs`, `body weight`); Mobile los muestra crudos o no los muestra | Backend (campos en español) o Mobile (tabla cerrada) | P2 |
| M-06 | `gifPath` es una ruta relativa; Mobile construye la URL a `raw.githubusercontent.com/hasaneyldrm/exercises-dataset`. El Backend propuso `gifUrl`/`imageUrl` sin implementar | Backend + Mobile | P1 |
| M-18 | `timezone` del registro debe ser IANA válida; Mobile deja escribirla a mano | Mobile | P1 |
| M-14 | Textos de `GET /plan/limitations` pensados para revisión interna, mostrados a participantes | Backend (contenido) + Mobile (ubicación) | P1 |
| M-11 | No hay campo de observaciones en `FinishSessionResource` ni en `ReportWorkoutResource` | Backend (si se decide) | Decisión |
| M-12 | El dolor solo se registra como `skipReason` de un ejercicio no realizado o parcial; no existe «completado con molestias» | Backend (si se decide) | P1 |
| M-37 | Mensajes de error y notas del Backend sin tildes («Esta sesion ya esta cerrada», «deberias poder hablar») mostrados tal cual | Backend | P2 |
| M-25 | `PUT /users/me/profile` → 422 tras el primer plan: ni disponibilidad, ni equipamiento, ni restricciones cambian en 12 semanas (salvo exclusiones por dolor) | Producto + Backend | P1 (decisión) |
| — | El límite de 3 solicitudes de recuperación por hora y cuenta descarta en silencio (202) | Backend (diseño anti-enumeración) | Informativo: Mobile debe decir «si no llega, espera unos minutos» |
| — | `POST /workouts/{id}/start` acepta entrenamientos de días futuros (hoy se inició el del lunes siguiente) y `report` también (B-5 de la auditoría previa) | Backend | Decisión de producto |

## 4. Validación con Backend real: qué no se hizo y por qué

| Flujo | Motivo |
|---|---|
| Generación con IA | Prohibido consumir Replicate. Solo motor de reglas |
| Cierre semanal real (adherencia, adaptación, P2 en vivo) | Requiere mover fechas en la base o esperar al lunes; ya cubierto por E2E y validaciones previas |
| O20 en vivo (9 pruebas) | Requiere preparar estados por etapas del Backend; cubierto por la validación O20 previa |
| Usuario demo 48 | Solo lectura en la base real, que no está en este entorno. Las consultas de solo lectura están en `docs/o20/validacion/usuario48_verificacion_solo_lectura.sql`; **pendiente** de ejecutar por el propietario |
| Firebase real | No hay teléfono ni credenciales de servidor FCM en este entorno; no se modificó Firebase |
| Producción | No se accedió |

## 5. Notificaciones (estado técnico)

| Comprobación | Estado | Evidencia |
|---|---|---|
| Configuración Firebase | Proyecto `kora-fitpe`; `android/app/google-services.json` y `lib/firebase_options.dart` en el repositorio (identificadores públicos de cliente, no secretos de servidor) | `firebase.json` |
| Solicitud de permisos | Explicación propia al final del perfil, una vez por teléfono, antes del primer plan; «Ahora no» no bloquea | `push_permission_prompt.dart`; `push_permission_test.dart`, `push_first_plan_prompt_test.dart` |
| Registro del identificador | Firebase Installation ID (FID) con `PUT /push-devices`; reintento al volver a primer plano | `push_controller.dart`; en vivo ✓ |
| Asociación con la sesión | Solo con JWT confirmado (`pushSessionUserId`) | `app.dart:45-46` |
| Cierre de sesión | `DELETE` con el JWT aún válido y `unregister()` en FCM | `push_early_registration_test.dart` |
| Push en primer plano | Se muestra con notificación local (FCM no lo hace) | `push_notifier.dart` |
| Apertura desde notificación | `onMessageOpenedApp` y `getInitialMessage` (app cerrada) → pantalla de `targetScreen` | `push_messaging.dart:89-94` |
| App cerrada | Mensaje de FCM con `notification` lo muestra el sistema en el canal `kora_planes` | Nunca comprobado en teléfono |
| Permiso rechazado | Estado `permissionMissing`; no registra; se vuelve a mirar al volver a la app | `push_controller.dart` |
| Duplicados | Descarta por `eventId` repetido (`_RecentIds`) | `push_notifications_test.dart` |
| Recordatorios locales | Programados en la zona del usuario, inexactos (sin `SCHEDULE_EXACT_ALARM`), máx. 20, reprogramados tras reiniciar (`RECEIVE_BOOT_COMPLETED`); **desactivados por defecto** tras la explicación de push | `reminder_scheduler.dart`, `reminders_controller.dart:107` |
| Recordatorio tocado con la app cerrada | No navega a la rutina (no se usa `getNotificationAppLaunchDetails`) | `reminder_scheduler.dart:78` |
| iOS | Push no soportado (`PushMessaging.supported` solo Android); sin `GoogleService-Info.plist` ni capacidades | `push_messaging.dart:48` |

Tipos de push que envía el Backend: `PLAN_GENERATED`, `PLAN_ADAPTED`, `WEEKLY_PLAN_READY`, `ACCOUNT_NOTICE`
(`push_event.dart`). **No hay recordatorios de entrenamiento por push**; dependen de los locales. Antes de proponer
nuevas notificaciones hay que validar las existentes en un teléfono (M-05).
