# Informe de validación de Kora Mobile (cierre de integración, previo a la prueba en Android)

**Fecha:** 27/11/2026 · **Mobile:** `Fitsense-Real/MobileApp` `generation@76dcf34` · **Backend:** `Fitsense-Real/Backend` `generation@77b9df3` (local, IA apagada)

## 1. Resumen

| Pregunta | Respuesta corta |
|---|---|
| ¿PR #24 fusionada? | **Sí**, merge `76dcf340908a61fba0314b6705352759cafc0b2f` |
| ¿`generation` estable? | **Sí**: analyze sin incidencias, 422 pruebas superadas (31 *live* omitidas), CI verde |
| ¿Backend real? | Validado con el Backend `77b9df3` en local: IA y push apagados, **ninguna conexión externa** (medido con `strace`) |
| ¿Usuario 48? | Verificado **en una copia local del dataset**, no en tu base real (no tengo acceso). Pendiente en tu base |
| ¿Android físico? | **PENDIENTE**: no hay teléfono en este entorno. Ninguna fila física se declara aprobada |
| ¿Algo bloquea la demo? | **No en Mobile.** Hay tres riesgos de datos, ajenos al código Mobile, con mitigación en la guía (§6) |

**Qué se probó y dónde**

1. **Pruebas automatizadas:** pruebas Flutter con dobles de prueba.
2. **Backend real:** pruebas *live* de los repositorios del Mobile y la **app Kora real** (compilación web *profile* de `generation@76dcf34`, el mismo código Dart) en Chromium. Todo contra el Backend `77b9df3` y bases locales.
3. **Android físico:** nada todavía.

La app en Chromium **no es un teléfono**: no sustituye la prueba física, que queda pendiente (§9).

## 2. PR #24

| Comprobación | Resultado |
|---|---|
| Estado antes del merge | Abierta, `mergeable_state = clean`, head `09cae40d5e9e7697c6f6c1a879418bdfc26849ed`, base `generation@5b9de9f` |
| CI de la PR | `verify` success |
| Archivos | Solo 2 de documentación: `GUIA_ANDROID.md` y `usuario48_verificacion_solo_lectura.sql` |
| Secretos | Ninguno (la única coincidencia era un comentario que dice que no se lee `password_hash`) |
| SQL | Sin sentencias de escritura; todo dentro de `BEGIN TRANSACTION READ ONLY … ROLLBACK` |
| Merge | `76dcf340908a61fba0314b6705352759cafc0b2f`, 27/11/2026 06:12:40 UTC, estado `closed / merged = true` |
| `main` | Sin cambios: `3a4e26d1fed5170c6790cd05c9129f58ce88b4d0` |
| Tras el merge | `flutter analyze`: sin incidencias. `flutter test`: **+422 ~31, 0 fallos**. CI de `generation@76dcf34`: `verify` success |

No se fusionó ninguna otra PR.

## 3. Entorno y versiones

| | |
|---|---|
| Mobile | `generation@76dcf34`, `fitsense_mobile 1.0.0+1` |
| Flutter / Dart | 3.50.1 (`ae9b586f34`) / 3.14.0 |
| Backend | `generation@77b9df3`, compilado en local desde su código (`mvn -o -DskipTests package`). Respecto al `98276a9` validado antes, solo cambia el transporte de Replicate (`ReplicateTrainingPlanGenerator`), además de pruebas y documentación: ningún controlador, contrato ni migración |
| Java / PostgreSQL | OpenJDK 21.0.12 / PostgreSQL 16.15 local |
| Navegador de la app web | Chromium 153 (Playwright 1.63), 390 × 844 |
| Bases | `fitsense_av48`: clon de la copia local del dataset demo. `fitsense_avs`: base sintética nueva, migrada por Flyway (68 migraciones, V65) |
| Teléfono | **Ninguno** (prueba física pendiente) |

## 4. Backend local (§4 de la orden)

| Elemento | Valor real (`77b9df3`) |
|---|---|
| Puerto | `8080` por defecto. `server.port` y `server.address` no se definen, así que escucha en todas las interfaces |
| URL base | `http://HOST:8080/api/v1` |
| Perfiles | `application` (por defecto), `application-local-dev` (IA apagada, base local) y `application-prod` |
| Base por defecto | **La URL y el usuario de la base remota están en `application.properties`**; la contraseña llega por `DB_PASSWORD`, sin valor por defecto. Sin `--spring.datasource.url`, el jar se conecta a la base remota |
| Flyway | `spring.flyway.enabled=true`: al arrancar migra la base a la que se conecta |
| Autenticación | JWT con `authorization.jwt.secret` (`JWT_SECRET`, sin valor por defecto), 7 días. `token_version` invalida tokens al cambiar la contraseña |
| IA (Replicate) | `fitsense.ai.enabled=${FITSENSE_AI_ENABLED:true}` y `fitsense.ai.api-token=${REPLICATE_API_TOKEN:}`. Solo se usa si `enabled` es true y hay token (`ReplicateProperties.isUsable()`) |
| Push | `fitsense.push.enabled=${FITSENSE_PUSH_ENABLED:false}` |
| CORS | `fitsense.cors.allowed-origins` (vacío). Solo lo necesita la app web; Android no |
| Tareas programadas | Ciclo semanal (lunes 03:00 hora local del participante), vencimiento (:30), sesiones colgadas (:35). **Ninguna se puede desactivar por configuración** |

**IA apagada, comprobado.** El Backend arrancó con `--fitsense.ai.enabled=false --fitsense.ai.api-token= --fitsense.push.enabled=false`, sin variables de Replicate ni de proxy y con el proxy de Java anulado. Se registraron con `strace` **todas** las llamadas `connect()` de los cuatro procesos Backend: solo hubo conexiones a PostgreSQL local, a la propia IP del contenedor al apagarse (Tomcat) y a nscd. Ningún destino externo, ni siquiera durante 25 generaciones de plan sintéticas: todas `RULE_ENGINE`, sin modelo. En el log aparece `(IA apagada)` y `Notificaciones push apagadas`. Evidencia: `evidencia/02_backend_config.txt`.

**Rutas del Mobile.** Las 18 rutas que lee la app en la cuenta demo responden en `77b9df3` lo mismo que en los fixtures fusionados (`test/fixtures/o20_demo_kora`), sin contar campos de hora. No se inventó ninguna ruta.

## 5. Base de datos y usuario 48 (§3)

**Base real del usuario 48: NO verificada.** No tengo acceso a ella, así que esta comprobación queda **PENDIENTE** y debes hacerla tú con el script (guía §5.1).

**Copia local.** Se ejecutó el script de solo lectura sobre el clon `fitsense_av48`. El resultado íntegro está en `evidencia/03_copia_demo_solo_lectura.txt`:

| Comprobación | Esperado | Copia local | Nota |
|---|---|---|---|
| Usuario | 48, ACTIVE | user_id **1**, ACTIVE | El id cambia en la copia |
| Participación | `true` | **`false`** | El script 01 del dataset aborta con participantes, así que la copia se cargó sin participación. Por eso el ciclo semanal no la toca |
| Planes | 4 (3 COMPLETED, 1 ACTIVE, 0 IA) | 4 / 1 activo / 0 IA | ✓ |
| Sesiones | 13 COMPLETED + 1 PARTIAL; W-3 3/1/1 | ✓ | La semana vigente: 2 SKIPPED + 3 SCHEDULED (ver abajo) |
| Adaptaciones | 3 | ADAPT_LOCALIZED/RESPALDO, NO_CHANGE/SIN_ORDEN, NO_CHANGE/SIN_ORDEN con progresión | ✓ `ai_calls = 0` |
| Métricas | 67,81 / 100 / 100 | ✓ | |
| Exclusión 1025 | DOLOR_IDENTIFICADO, ACTIVA | ✓ | |
| Perfil | GAIN_MUSCLE, INTERMEDIATE, GYM, 5 d, 60 min, 176 cm, 74 kg | ✓ | |

**Qué escribe el Backend durante una prueba de solo lectura.** Medido con una suma MD5 de las 29 tablas antes y después de cada paso:

| Paso | Tablas que cambian |
|---|---|
| Arranque del Backend sobre la copia | Ninguna (Flyway: «No migration necessary») |
| 18 lecturas del Mobile (`o20_grabar_live_test`, modo demo) | Solo `users`: `last_login_at` y `updated_at`, por el **login**. Al restaurar esos dos campos, la suma coincide con la original |
| Recorrido completo de la **app real** F01–F09 | Solo `users`, por el login. 35 peticiones: un POST `/auth/login` y el resto GET |
| Tarea programada de las 06:30:00 UTC, **sin el Mobile** | `planned_workouts`: el Backend pasó a SKIPPED los entrenamientos vencidos del 25/11 y 26/11 |

No se generó ningún plan, adaptación ni métrica. Solo se modificó la copia local; la base real no se tocó.

## 6. Incidencias

| ID | Gravedad | Descripción | Causa | Propuesta | ¿Bloquea? |
|---|---|---|---|---|---|
| I-01 | **Alta (datos)** | Con el usuario 48 como participante en tu base, **el lunes 30/11/2026 a las 03:00 (Lima)** cualquier Backend conectado a esa base cerrará su semana y publicará un 5.º plan. Además, cada hora a los :30 se cierran como SKIPPED los entrenamientos vencidos de la semana vigente | Tareas programadas del Backend, sin interruptor (`WeeklyCycleScheduler`, `OverdueWorkoutScheduler`) | Haz la prueba con un Backend local sobre **una copia** (`pg_dump`, guía §2.2) y antes del lunes. A medio plazo, el equipo Backend podría añadir una propiedad para desactivar las tareas en entornos de demostración (**pendiente de Backend; no se modificó**) | No bloquea Mobile. Sí condiciona la demo con datos reales |
| I-02 | Media (datos) | Iniciar sesión escribe `users.last_login_at` y `users.updated_at`. F01 con la base real modifica esos dos campos del usuario 48 | Comportamiento del Backend en el login | Hacer F01–F09 sobre la copia, o aceptar explícitamente esa escritura. **Decisión tuya** | No |
| I-03 | Media (datos) | Una compilación debug **con** `google-services.json` y el permiso de notificaciones concedido registra el teléfono (`PUT /users/me/push-devices`) para la cuenta que entra | Diseño de push (PR de FCM), correcto para usuarios reales | Con el usuario 48: compilar sin `google-services.json` o denegar el permiso. Firebase (S14), solo con la cuenta sintética. Ya está en la guía §4 | No |
| I-04 | Media (configuración) | `application.properties` del Backend apunta por defecto a la base remota y Flyway migra al arrancar | Configuración del Backend | Arrancar siempre con `--spring.datasource.url` de la copia (guía §2.3). Revisar en Backend si conviene quitar esa URL por defecto (**pendiente de Backend**) | No |
| I-05 | Baja | Tras cerrar sesión voluntariamente, 3 o 4 lecturas de Inicio salen ya sin token y reciben `401`. No se muestra ningún aviso ni se expone ningún dato | Los proveedores del panel se recargan al cambiar la sesión | Ninguna ahora (la orden prohíbe desarrollar). Anotada como limpieza futura | No |
| I-06 | Informativa | La versión web *release* rechaza HTTP y direcciones locales («La versión publicada solo se conecta por HTTPS») | Protección intencionada de la preparación para publicar | Para la validación local se usó la compilación *profile*; en Android, la *debug* (guía §4) | No |

No se encontró ningún fallo funcional del Mobile, así que no se abre ninguna PR correctiva.

## 7. Matriz de pruebas

**Leyenda de entorno:**

- **Simulado:** prueba Flutter automatizada, con dobles de prueba.
- **Backend real:** Backend `77b9df3` local. Incluye las pruebas *live* de los repositorios del Mobile y la **app real en Chromium**.
- **Android físico:** el teléfono.

**Cuentas:**

- **Demo (copia):** la cuenta Demo Kora en la copia local, solo lectura.
- **Sintética:** cuentas nuevas en `fitsense_avs`.

### 7.1 Pruebas automatizadas (Simulado)

| ID | Funcionalidad | Entorno | Cuenta | Resultado esperado | Resultado obtenido | Estado | Evidencia | Observaciones |
|---|---|---|---|---|---|---|---|---|
| F01–F09 | Lectura demo | Simulado | Respuestas reales de la demo (fixtures) | Pantallas con los datos de la demo, sin códigos | Superadas | APROBADO | `test/o20_demo_kora_app_test.dart`, `test/adaptation_history_test.dart` | Sirven las 18 respuestas grabadas |
| S01, S02 | D-M1 | Simulado | — | Completo = total de la prescripción; un parcial nunca cuenta como completo | Superadas (28) | APROBADO | `exercise_results_test`, `timed_exercise_results_test`, `session_timer_test` | |
| S03–S05 | P1 / O20 | Simulado | — | Sin conexión o > 8 s: pendiente; nada se envía sin confirmar | Superadas | APROBADO | `o20_rutina_desactualizada_test` (casos 1, 2, 6, 7), `pending_results_persistence_test` A | |
| S06, S07 | O20 | Simulado | — | Bloqueo posterior o rutina fuera del plan: retenido, no se envía | Superadas | APROBADO | `pending_results_persistence_test` B y E; `o20_rutina_desactualizada_test` | Cubre también el **cambio de versión del plan** de S07 |
| S08 | P1 | Simulado | — | Respuesta perdida: se consulta la sesión y no se repite | Superada | APROBADO | `pending_results_persistence_test` C; `o20_rutina_desactualizada_test` 6 | |
| S09 | P1 | Simulado | — | Otra cuenta no ve nada | Superada | APROBADO | `pending_results_persistence_test` D | |
| S10 | P1 | Simulado | — | Datos dañados o almacenamiento que falla: aviso; nada se envía | Superadas | APROBADO | `pending_results_persistence_test` F (×2) | La orden lo define como simulación |
| S11 | P1 | Simulado | — | Más de 48 h: se descarta al leer | Superada | APROBADO | `pending_results_persistence_test` «expiry: older than 48 h» | Reloj simulado, como pide la orden |
| S12 | Sesión / O20 | Simulado | — | 401: se cierra la sesión una sola vez, con aviso. 422: no se envía | Superadas | APROBADO | `session_expiry_test` (7), `o20_rutina_desactualizada_test` 3 y 4 | |
| S13 | P1 + O20 | Simulado | — | Reabrir con bloqueo: retenido | Superada | APROBADO | `pending_results_persistence_test` B | |
| S14 | Firebase | Simulado | — | Registro solo con permiso; renovación; borrado al cerrar sesión | Superadas (83) | APROBADO | `push_*_test`, `android_identifier_test` | Firebase simulado |
| S15 | Generación / historial | Simulado | — | Generación inicial, tour e historial | Superadas (68 + 28) | APROBADO | `first_plan_generation_test`, `generation_screen_test`, `welcome_tour_test`, `adaptation_history_test` | |

Suite completa: **+422 ~31, 0 fallos**. Por áreas: O20 46, P1 14, P2 28, D-M1 28, Firebase 83, generación 68, sesión y cuentas 37, contrato 53 (`evidencia/01_merge_ci_pruebas.txt`).

### 7.2 Pruebas contra Backend real

| ID | Funcionalidad | Entorno | Cuenta | Resultado esperado | Resultado obtenido | Estado | Evidencia | Observaciones |
|---|---|---|---|---|---|---|---|---|
| F01 | Login | Backend real + app web | Demo (copia) | Entra a Inicio | «Hola, Usuario» | APROBADO | `06_app_web_demo48.txt`, `capturas/F01-inicio.png` | Escribe `last_login_at` (I-02) |
| F02 | Perfil | Backend real + app web | Demo (copia) | Datos y preferencias | Nombre, correo; objetivo, 176 cm, 74 kg | APROBADO | `capturas/F02-cuenta.png` | |
| F03 | Rutina vigente | Backend real + app web | Demo (copia) | Semana del 23/11 con sus 5 entrenamientos | Empuje, Traccion, Piernas, Tren superior, Tren inferior | APROBADO | `capturas/F03-rutinas.png` | |
| F04 | Historial de planes | Backend real + app web | Demo (copia) | 4 semanas | 4 semanas: Progresión, Sin cambios, Sustitución por seguridad | APROBADO | `capturas/F04-historial-planes.png` | |
| F05 | Historial de sesiones | Backend real + app web | Demo (copia) | Completos, parcial y omitido | 02/11: 3 Completado, 1 Parcial, 1 Omitido | APROBADO | `capturas/F05-semana-02-11.png` | |
| F06 | Adherencia | Backend real + app web | Demo (copia) | Coherente con `weekly_user_metrics` | 100 %, 5/5, semana del 16/11 | APROBADO | `capturas/F01-inicio.png`, `capturas/F06-progreso.png` | |
| F07 | P2 | Backend real + app web | Demo (copia) | Progresión, sustitución, sin cambios; sin códigos | Las 3 tarjetas en lenguaje natural; 0 códigos en Progreso e Historial | APROBADO | `capturas/F06-progreso.png`, `capturas/F04-historial-planes.png` | |
| F08 | O20 | Backend real + app web | Demo (copia) | 1025 excluido y fuera de las rutinas | «Aperturas de pecho… Lo marcaste con dolor · 05/11/2026»; no está en ninguna rutina | APROBADO | `capturas/F08-exclusiones.png` | No se pulsó «Ya no me duele» |
| F09 | Recarga | Backend real + app web | Demo (copia) | Recargar al volver del segundo plano | Tras `visibilitychange`: GET de la rutina vigente, `confirmation-requests`, `adaptations` y `limitations` | APROBADO | `06_app_web_demo48.txt` | En web, el segundo plano se simula con la visibilidad de la página |
| F01–F09 | Solo lectura | Backend real + app web | Demo (copia) | Ninguna escritura | 35 peticiones: 1 POST de login y el resto GET; en la base solo cambia `users` (login) | APROBADO | `03_copia_demo_solo_lectura.txt` | |
| S01 | Registro | Backend real + app web | Sintética | Se guarda una vez; la sesión se cierra con 1 registro por ejercicio | `COMPLETED:2:16:0`; sesión COMPLETED 88 %, 8 filas para 8 ejercicios | APROBADO | `05_app_web_escenarios.txt`, `capturas/S01-finalizada.png` | |
| S02 | D-M1 | Backend real (repositorios del Mobile) | Sintética | Parcial con su duración real | 150/270 s → 55,56 % PARTIAL; completo 270 s → 100 % | APROBADO | `04_live_backend.txt` (`timed_exercise_live_test`) | Desde los repositorios, no desde la pantalla |
| S03 | P1 | Backend real + app web | Sintética | Sin conexión: pendiente; nada llega | Aviso «No pudimos confirmar…», «Pendiente de enviar», 0 PUT, 0 filas | APROBADO | `capturas/S03-sin-conexion.png` | Sin conexión = modo sin conexión del navegador |
| S04 | P1 | Backend real + app web | Sintética | Tras cerrar y reabrir, sigue pendiente y no se envía | Reaparece; 0 PUT hasta reintentar | APROBADO | `capturas/S04-reabrir.png` | Cierre = cerrar el navegador, no matar el proceso de Android |
| S05 | P1 | Backend real + app web | Sintética | Confirma la rutina y envía una vez | GET `/users/me/plan/current` antes del PUT; 1 PUT, 1 fila | APROBADO | `05_app_web_escenarios.txt` | |
| S06 | O20 | Backend real + app web | Sintética | La nueva exclusión llega a la rutina | «No disponible por ahora» | APROBADO | `capturas/S13-retenido.png` | Exclusión creada omitiendo por dolor otra rutina con la API |
| S07 | O20 | Backend real + app web | Sintética | El pendiente incompatible queda retenido y no se envía; se puede descartar | «Retenido: no se enviará»; 0 PUT, 0 filas; «Descartar» lo quita sin enviar | APROBADO | `capturas/S13-retenido.png` | La incompatibilidad vino de un bloqueo O20. El cambio de versión del plan solo está simulado (§7.1) |
| S08 | P1 | Backend real + app web | Sintética | El reintento no duplica | El PUT llegó (1 fila) y la respuesta se cortó; al reintentar, 2 GET `/sessions/current` y **0 PUT nuevos** | APROBADO | `capturas/S08-respuesta-perdida.png` | Corte de la respuesta con la interceptación de Playwright |
| S09 | P1 | Backend real + app web | Sintética | B no ve nada de A; A lo recupera | ✓ y ✓ | APROBADO | `05_app_web_escenarios.txt` | Mismo navegador = mismo almacenamiento |
| S12 | 401 / 422 | Backend real + app web y repositorios | Sintética | 401: vuelve al login. 422: no se registra lo inseguro | 401: 9 respuestas 401 → pantalla «Iniciar sesión». 422 `SESION_BLOQUEADA_POR_SEGURIDAD` al registrar trabajo en un bloqueado (live) | APROBADO | `capturas/S12-401.png`, `04_live_backend.txt` | 401 provocado con `token_version` (lo mismo que hace el cambio de contraseña) |
| S13 | P1 + O20 | Backend real + app web | Sintética | Reabrir con bloqueo: no se envía | Retenido, 0 PUT | APROBADO | `capturas/S13-retenido.png` | |
| S14 | Firebase | Backend real (repositorios, FCM simulado) | Sintética | Registro del dispositivo; generación solo tras el registro | `PUT /users/me/push-devices` 201 antes de generar; sin permiso no se registra | APROBADO (parcial) | `04_live_backend.txt` | **FID ficticio y permiso simulado**. El permiso real y una notificación real requieren el teléfono |
| S15 | Generación / historial | Backend real | Sintética y demo (copia) | Generación sin IA e historial correctos | 25 planes RULE_ENGINE; historial F04/F05 en la app real | APROBADO | `02_backend_config.txt`, `capturas/F04…` | Sin generaciones pagadas |
| O20 | O20 completo | Backend real (repositorios) | Sintética | S1–S12 de O20 | 4/4 + 1/1 | APROBADO | `04_live_backend.txt` | |

S10 y S11 no se repiten contra el Backend real: la orden pide simularlos. Para S10 no hay forma segura de dañar el almacenamiento cifrado del teléfono desde fuera, y S11 necesita un reloj simulado.

### 7.3 Pruebas en Android físico

| ID | Funcionalidad | Entorno | Cuenta | Resultado esperado | Resultado obtenido | Estado | Evidencia | Observaciones |
|---|---|---|---|---|---|---|---|---|
| F01–F09 | Lectura demo | Android físico | Demo (copia o base real con I-02 aceptado) | Guía §5.2 | — | **PENDIENTE** | — | Sin teléfono en este entorno |
| S01–S09, S12–S15 | Escritura | Android físico | Sintética | Guía §6 | — | **PENDIENTE** | — | Sobre todo S04/S13 (matar el proceso de Android), S03/S08 (modo avión real) y S14 (permiso y notificación reales) |
| S10, S11 | P1 | Android físico | Sintética | Opcionales | — | PENDIENTE (opcional) | — | Cubiertos por simulación, como define la orden |

### 7.4 Pruebas pendientes

1. Ejecutar el script SQL en **tu base real**: comprobar 4 planes, 14 sesiones, 3 adaptaciones, 3 métricas y la exclusión 1025.
2. Toda la columna **Android físico** (§7.3), siguiendo `docs/o20/validacion/GUIA_ANDROID.md`.
3. S14 con permiso real y, si se quiere, una notificación real a la cuenta sintética.
4. Decidir I-02: la copia, o aceptar la escritura de `last_login_at` en la base real.

## 8. Restricciones respetadas

- **Merges:** solo la PR #24. `main` no cambió y no se desplegó nada.
- **Backend:** no se modificó. Solo se compiló y ejecutó en local con parámetros de arranque.
- **IA:** ninguna llamada a Replicate. Medido con `strace`.
- **Ciclo semanal:** no se ejecutó. Ninguna base sintética ni la copia tenían participantes en su lunes a las 03:00.
- **Rutinas y datos demo:** no se generaron rutinas para la demo ni se modificó el usuario 48 ni tu base. Solo se usó una copia local.
- **Código Mobile:** O20, P1, P2 y D-M1 sin cambios. No se implementó P3.
- **Firebase y APK:** sin cambios en Firebase de producción y sin APK de producción.
- **Dataset demo de la copia:** su única escritura fue el login y la tarea propia del Backend a los :30, que se documenta como hallazgo.

## 9. Respuestas finales (§16)

1. **¿PR #24 quedó fusionada?** Sí: `76dcf340908a61fba0314b6705352759cafc0b2f`, solo documentación, con todas las comprobaciones previas superadas.
2. **¿Mobile `generation` continúa estable?** Sí: analyze sin incidencias, 422 pruebas superadas y CI verde en `76dcf34`.
3. **¿Las pruebas automatizadas siguen pasando?** Sí: +422 ~31, 0 fallos; las 31 omitidas son las *live*. También pasan las 8 áreas por separado y todas las pruebas *live* contra el Backend `77b9df3`.
4. **¿Está preparada la conexión Android–Backend?** Sí, documentada y con el lado del Backend comprobado: puerto, URL, interfaces, IA y push apagados, y el `401` sin token. La guía cubre las opciones A (USB y `adb reverse`), B (ADB inalámbrico) y C (Wi-Fi directo), además de la comprobación desde el navegador del teléfono. La conexión desde tu teléfono no se ha probado.
5. **¿Se verificó la base de datos real del usuario 48?** **No.** No tengo acceso a ella. Se verificó una copia local con el mismo script; coincide salvo el id y la participación de la copia. En tu base queda pendiente.
6. **¿Qué escenarios se probaron realmente?** Contra el Backend real: F01–F09 en la app real (Chromium) sobre la copia demo, y S01–S09, S12, S13, S15 y la parte de registro de S14 con cuentas sintéticas. Además, O20 y D-M1 con los repositorios del Mobile. S10 y S11 están simulados, como pide la orden.
7. **¿Qué escenarios todavía necesitan tu teléfono?** Todos en su versión física: F01–F09 y S01–S15. Los imprescindibles son S03/S08 con modo avión real, S04/S13 matando el proceso de Android y S14 con el permiso y una notificación reales.
8. **¿Existe algún problema que bloquee la demostración?** Ningún fallo de Mobile. Hay tres condiciones de datos que debes respetar: el cierre semanal del **lunes 30/11 a las 03:00 (Lima)** (I-01); que el login escribe `last_login_at` (I-02); y que, con el usuario 48, no se use una compilación con Firebase y permiso concedido (I-03). Con la copia de la base de la guía §2.2, las tres quedan resueltas.
9. **¿Qué queda pendiente de Mobile?** La prueba física y la verificación en tu base. Como mejoras fuera de esta orden: la limpieza menor I-05 y P3, que sigue siendo solo una propuesta (`docs/mejoras/PENDIENTES.md`).
10. **¿Puede considerarse Mobile listo para una validación física completa?** **Sí.** El código está integrado y estable, y todo lo automatizable está ejecutado contra el Backend real. La guía y la matriz están preparadas. **La validación física no está aprobada:** lo estará cuando se ejecute en tu teléfono.

## 10. Evidencia

| Archivo | Contenido |
|---|---|
| `evidencia/01_merge_ci_pruebas.txt` | Merge, CI, analyze, test y regresiones por área |
| `evidencia/02_backend_config.txt` | Configuración real, tareas programadas, IA y `connect()` de los 4 procesos |
| `evidencia/03_copia_demo_solo_lectura.txt` | Salida del SQL, instantáneas MD5 y diferencias por paso |
| `evidencia/04_live_backend.txt` | Pruebas *live* (O20, D-M1, dolor, push, generación) |
| `evidencia/05_app_web_escenarios.txt` | App real: S01–S13 con cuentas sintéticas |
| `evidencia/06_app_web_demo48.txt` | App real: F01–F09 con la copia demo y las peticiones hechas |
| `evidencia/capturas/` | 13 capturas de la app real contra el Backend real |
| `evidencia/scripts/` | Guiones reproducibles (Playwright, instantáneas, cuentas sintéticas). La contraseña de la copia demo se pasa por `KORA_DEMO_PASSWORD` |
