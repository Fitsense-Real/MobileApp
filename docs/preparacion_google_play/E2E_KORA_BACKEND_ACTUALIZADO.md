# Recorrido completo: Kora (Flutter web) + backend 5977d28 + PostgreSQL

## Condiciones

- **Backend**: 5977d28 en local, con PostgreSQL nueva, IA apagada (motor de reglas), correo simulado,
  una instancia. Ver `CONTRATOS_BACKEND_ACTUALIZADOS.md`.
- **App**: build web release de `claude/play-e-backend-5977`, con:
  - `API_BASE_URL=http://localhost:8080/api/v1`, `ALLOW_INSECURE_API=true`,
    `ACCOUNT_DELETION_ENABLED=true`, `PASSWORD_RECOVERY_ENABLED=true`;
  - `--no-web-resources-cdn`, para no depender de internet.
- **Arnés**: Playwright sobre el árbol de semántica de Flutter, en una ventana de 390 × 844
  (`integracion_backend_5977/evidencia/arnes/`). Cada paso se comprobó en la app **y** en PostgreSQL o por
  HTTP.
- **Commits de la app usados**:

  | Etapa | Commit |
  |---|---|
  | Entrenamiento | `74994d4` |
  | Recuperación | `323c8be` |
  | Eliminación, consentimientos, edad y adherencia en pantalla | `d96f4ab` |

  El commit final de la PR #8 solo añade documentación sobre `d96f4ab`.

## A. Registro, login, perfil, edad y consentimientos

| Paso | Resultado | Evidencia |
|---|---|---|
| Registro | 201 (`del4`, `edad2`, `rec3`, `con2`) | API |
| Login | 200 | API |
| Perfil (5 pasos) | 201 | API |
| Edad: cumple 18 mañana / 18 hoy | Aviso y no avanza / avanza | `A-edad-menor`, `A-edad-18-hoy` |
| Consentimientos con versiones de prueba | Pantalla propia, casillas sin marcar, 2 `POST` 201 | `G-*` |
| Consentimientos sin versiones (situación real) | No se pide nada | todos los demás recorridos |

## B. Generación asíncrona, Kapi, plan y sesiones

| Paso | Resultado | Evidencia |
|---|---|---|
| «Generar mi plan» | `POST /plan/generation` 202 | API |
| Tour de Kapi durante la generación | Pasos completos y «¡Tu primera rutina está lista! Semana del 23/11/2026 · 4 entrenamientos.» | `A-plan-listo` |
| Plan en la base | 1 `weekly_training_plans` `ACTIVE`, 1 operación `COMPLETED` | `del4` |
| Inicio y Rutinas | Plan de la semana y rutinas por día, con su estado | `C-plan-semana` |

## C. Entrenamiento (Lucas, plan 16–22/11)

| Paso | App | PostgreSQL |
|---|---|---|
| Abrir la rutina e iniciar la sesión | «Comenzar sesión y registrar» | `POST /workouts/5/start` 201; sesión `IN_PROGRESS` |
| 7 ejercicios | 5 «Lo completé» | `COMPLETED` 100 % |
| — | 1 «No lo hice», motivo Falta de tiempo | `SKIPPED/LACK_OF_TIME` 0 % |
| — | 1 «Lo hice parcialmente», 1 serie sin repeticiones | **Defecto hallado**: el backend lo guardó como `SKIPPED/FATIGUE`. Corregido en `74994d4`: la app pide las repeticiones (`C-parcial-sin-volumen`) |
| — | Parcial con 8 repeticiones, Fatiga | `PARTIAL/FATIGUE`, 1 serie, 8 reps, **44,44 %** (`C-parcial-guardado`) |
| Finalizar con esfuerzo 7, satisfacción 4 y 38 min | `POST /sessions/1/finish` 200 (`C-finalizar-datos`, `C-sesion-finalizada`) | sesión `PARTIAL` **77,78 %**, `session_rpe=7`, `satisfaction=4`, `active_minutes=38`, cuenta para la adherencia; planificado `PARTIAL` |
| Omitir «Tren inferior»: Falta de tiempo, «Fue algo puntual» | `POST /workouts/6/skip` 204 (`C-omitir-*`) | `SKIPPED/LACK_OF_TIME`, contexto `IMPREVISTO` |
| «Ya lo hice» (María): 6 ejercicios, fecha, esfuerzo 6 | `POST /workouts/3/report` 201 (`C-reporte-listo`) | sesión `COMPLETED`, `USER_REPORTED`, 100 % |
| Historial | Rutinas muestra el estado de cada día («Parcial», «Programado», `C-plan-semana`); tras omitir, la rutina queda cerrada, sin botones de registro (`C-omitido`), y `SKIPPED` en la base; cada ejercicio, «Guardado: N series · N reps · N s» (`C-sesion-finalizada`) | — |

77,78 % = (5 × 100 + 44,44 + 0) / 7.

Observación B-5: el backend aceptó «Ya lo hice» para un entrenamiento programado el 27/11 con fecha del
20/11, y la app ofrece la opción para entrenamientos programados. Queda como decisión de producto.

## D. Adherencia y adaptación (motor de reglas)

El cierre manual mide la **semana anterior**. Para no esperar una semana real, en la base de pruebas se
movió la semana de Lucas del 16–22/11 al 9–15/11, con sus sesiones
(`evidencia/desplazar-lucas.sql`/`.out`). Después se ejecutó `POST /cycle/run-for-me` (solo local):
200 `EJECUTADO`, `measuredWeekStart=2026-11-09`, `generatedPlanId=3` (`evidencia/ciclo-lucas.txt`).

| Resultado | Valor |
|---|---|
| `GET /users/me/metrics/weekly` | 2 programados, 1 válido, 0 completos, 1 omitido; 5/13 ejercicios; volumen 114/260 |
| Adherencia | ponderada **38,89 %**, frecuencia 50 %, por ejercicio 38,46 % |
| Sesiones | 38 min, RPE 7, satisfacción 4 |
| Riesgo | 35, `MODERATE`, cobertura de registro 100 % |
| `user_interventions` | `ADAPT_EXPANDED` con el mensaje «La semana pasada cumpliste el 39 %… te faltó tiempo… llegabas con cansancio…» |
| `plan_adaptation_attempts` | `RESPALDO_SIN_IA`, sesiones `CONSERVAR` y `REVISAR_CARGA_Y_RECUPERACION`, ambas `SIN_EFECTO` |
| Plan nuevo (id 3, 16–22/11) | `CONSERVED`, mismas 2 sesiones, plan anterior `COMPLETED` |

En la app (`D-inicio-tras-ciclo`, `D-progreso`, `D-progreso-3`):

- Inicio: «38.9 % Tu progreso · 0/2 entrenamientos · Semana del 09/11/2026», y la rutina de hoy del plan
  nuevo.
- Progreso:
  - adherencia 38,9 %, barra de la semana 09/11, sesiones 0/2 y 38 min;
  - «Riesgo de abandono: Moderado», «Registraste 2 de 2 entrenamientos (100 %)»;
  - el resumen del ajuste con el mensaje de la intervención.
- «Adaptación: Sin ajustes registrados»: es fiel, porque el intento no aplicó cambios (`SIN_EFECTO`).

No se modificó la fórmula de adherencia, la progresión ni la reincorporación. El cálculo es del backend.

## E. Perfil, contraseña, sesión, recuperación y eliminación

| Paso | Resultado | Documento |
|---|---|---|
| Perfil → Cuenta: retiro y eliminación separados | ✓ | `INTEGRACION_ELIMINACION_CUENTA.md` |
| Cambiar la contraseña con sesión iniciada | **No existe** ni en el backend (no hay endpoint) ni en Flutter. Solo por recuperación | — |
| Cerrar sesión y volver a entrar | ✓ (login posterior en recuperación y eliminación) | — |
| Recuperación con correo simulado | ✓ completa, incluida la invalidación de la otra sesión | `INTEGRACION_RECUPERACION.md` |
| Eliminación 200, 202, 403, 429 y doble toque | ✓ | `INTEGRACION_ELIMINACION_CUENTA.md` |
| PostgreSQL tras eliminar | 0 filas en 12 tablas; registro anónimo en `account_deletions` | idem |

## Estados de error vistos con el backend real

| Situación | App |
|---|---|
| 400 | Código de recuperación inválido |
| 401 | Sesión antigua, cuenta eliminada |
| 403 | Contraseña incorrecta al eliminar |
| 422 | Edad (traducido) |
| 429 | Eliminación |
| 202 | Eliminación pendiente |
| Defectos del arnés | No de la app: etiquetas de fechas de 2008, perfil persistente que ya tenía sesión, caché del service worker con CanvasKit del CDN. Se corrigieron en el arnés |

## Revalidación sobre el código integrado (árbol `877fe4a` = `generation` `aa1a0d2`)

Se repitió con una base PostgreSQL nueva (`fitsense_final`, V1–V63) y el mismo backend 5977d28, con IA
apagada, correo simulado y usuarios sintéticos (`fin*`, `edadf*`). Arnés:
`evidencia/arnes/fin-*.js`, `alta-con-plan.sh` y `smoke-final.js`, con credenciales tomadas del entorno.

| Área | Resultado | Evidencia |
|---|---|---|
| Registro, login, perfil | 201 / 200 / 201 | API |
| Generación asíncrona y tour de Kapi | 202 → `COMPLETED`; el tour se retoma donde quedó tras cerrar la app | — |
| Sesión de hoy | 1 completo, 1 parcial (`PARTIAL/FATIGUE` 22,22 %), 1 no realizado (`SKIPPED/LACK_OF_TIME`), 4 completos; esfuerzo 7, satisfacción 4, 30 min → sesión `PARTIAL` 74,60 % | `X-sesion-finalizada` |
| Parcial sin repeticiones | La app lo rechaza y pide las repeticiones; no se guarda como omitido | `X-parcial-sin-repeticiones-rechazado` |
| Omitir | `SKIPPED/FATIGUE` | — |
| Adherencia | Backend 37,30 %, riesgo `MODERATE`, 0/2 completos, 30 min; **Progreso muestra 37,3 %** | `X-progreso` |
| Adaptación | `ADAPT_EXPANDED`, `CONSERVED`, plan nuevo con el mensaje de la intervención | `X-progreso-ajuste` |
| Registro retroactivo | 201 `USER_REPORTED` 100 %, esfuerzo 6 | `X-reporte-guardado` |
| Recuperación | 202 neutro, código de 43 caracteres leído del `.eml`, código inválido 400, cambio 204, token usado, contraseña antigua 401 y nueva 200, la sesión antigua vuelve al login | `X-rec-*` |
| Eliminación 403 → 200 | Triple toque = un solo `DELETE`; 0 filas en 12 tablas; registro anónimo `COMPLETADA` | `evidencia/generation-aa1a0d2/pg-fin1-*` |
| **Respuesta perdida** (el servidor respondió 200, la conexión se cortó) | La app **no** dice «No se eliminó nada»: explica los dos casos. Al reintentar, 401: se borran los datos locales de la cuenta y la app vuelve al login | `X-del-corte`, `X-del-corte-reintento` |
| 202 | «Solicitud recibida», `PENDIENTE` con `users.status=DELETED`; el reintento del backend la completó a los 5 min | `X-del-202` |
| 429 | Botón desactivado y la cuenta sigue `ACTIVE` | `X-del-429` |
| Edad | HTTP: 422 / 201 / 400. App: aviso y no avanza / pasa al paso 3 | `final-edad-consent.txt`, `X-edad-*` |
| Consentimientos | Sin versiones aprobadas y exigencia apagada; una versión inventada → 422; la app no pide nada | `final-edad-consent.txt` |
| Cerrar sesión | ✓ | `X-smoke-final` |

**Observación menor** (Mobile, no bloquea): tras una respuesta perdida, el reintento recibe 401 y el aviso
global de sesión caducada («Tu sesión expiró») lleva al login antes de que la pantalla de eliminación
muestre «Tu cuenta probablemente ya se eliminó». Los datos locales sí se borran. Se puede mejorar el texto
en una PR futura.

Fallos del arnés corregidos durante la revalidación, que no eran de la app:

- carrera entre el registro y el login;
- confundir «repeticiones por serie» con un ejercicio por tiempo;
- desmarcar la casilla en el segundo intento;
- consultas SQL con nombres de columna equivocados.

## No implementado en Flutter

- Cambio de contraseña con sesión iniciada (tampoco existe en el backend).
- Lectura de las versiones de consentimiento antes del registro (falta un endpoint público, B-4).
