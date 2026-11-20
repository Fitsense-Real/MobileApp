# Validación Flutter ↔ backend (ORDEN 2, fases 1 y 2)

Fecha: 15/11/2026. Sin merge, sin despliegue, sin datos reales, sin Replicate.

## 1. Estado de partida (fase 1)

| PR | Rama | Base | Head validado | Conflictos |
|---|---|---|---|---|
| Fitsense-Real/Backend#71 | `claude/async-first-plan-generation` | `generation` @ `2578719` | `12a01c6` | ninguno (`clean`) |
| Fitsense-Real/MobileApp#1 | `claude/kora-mascot` | `generation` @ `4291c6b` | `400ee39` | ninguno |
| Fitsense-Real/MobileApp#2 | `claude/welcome-tour` | `claude/kora-mascot` (apilada) | `19b9e9b` | ninguno (`clean`) |

- **Catálogo, validadores, adherencia, H2, P-03 y políticas deportivas: intactos.** El diff del
  backend contra `generation` solo añade archivos nuevos, más `pom.xml` (worker apagado en
  pruebas) y una línea en una configuración de prueba (`EsquemaVigenteSobreCatalogoAnterior`,
  ver ERRORES_CORREGIDOS.md). No se modifica ningún archivo de producción existente.
- **Colores oficiales**: las tres PR solo usan la paleta Kora (`#D9FF59`, `#0F2E25`, `#F7F5ED`,
  `#7A9A7E`, `#5E7865`, `#F0F6D4`), el bosque con transparencia y blanco. Kapi usa además los
  tonos derivados documentados en la PR #1 (`#A3BCA6`, `#C9D8C9`, `#B6DB2E`).
- **CI**: la del backend se cancelaba a los 45 min; corregido (ERRORES_CORREGIDOS.md, B1). La
  ejecución final en `12a01c6` terminó en verde en 19 min 19 s. MobileApp no tiene workflow de
  CI; su verificación es local (REGRESION_FINAL.md).

## 2. Entorno de la prueba real (fase 2)

| Pieza | Configuración |
|---|---|
| Backend | Jar de `12a01c6` (y antes `e14a28e`/`1faaeb0`), Spring Boot en `localhost:8080` |
| Base | PostgreSQL 16 local, base nueva `fitsense_e2e`, migrada por Flyway desde cero (V1..V58, 61 migraciones) |
| IA | `fitsense.ai.enabled=false`, sin token: **motor de reglas real** (`origen=RESPALDO motivo_respaldo=IA_APAGADA` en el log) |
| Simulación | Solo del lado del servidor: un bean de prueba local (`docs/validacion/e2e/EscenariosE2E.java`, fuera del repositorio del backend) retrasa o hace fallar la generación según el correo, y luego llama al **pipeline real** |
| App | Flutter 3.32.8, `flutter build web --release --dart-define=API_BASE_URL=http://localhost:8080/api/v1`, servida en `localhost:5050` |
| Conducción | Playwright (Chromium) a través del árbol de semántica de Flutter, 390×844 |

**Flutter no usa respuestas falsas**: todas las llamadas (registro, login, perfil, catálogo,
generación, consulta, plan, métricas) llegaron al backend real; se ven en el registro de
peticiones de cada ejecución (`[api] POST /users/me/plan/generation 202`, etc.).

## 3. Flujo completo (usuario `ana+d45`, IA simulada de 45 s)

| t | Paso | Evidencia |
|---|---|---|
| 0 s | Registro (`POST /auth/register` 201) y login (200) | `capturas/01-registro.jpg` |
| — | `GET /users/me/profile` 404 → formulario; catálogo de equipo 200 | `02..05-perfil-*.jpg` |
| 22.6 s | Antes de generar: 0 operaciones, 0 planes | base |
| 23 s | «Generar mi plan»: `POST /users/me/profile` 201 y `POST /users/me/plan/generation` **202** | log |
| 26.2 s | Tour abierto, paso 1. Operación en la base: **PROCESSING**, executions 1 | base |
| 26–49 s | 10 pasos del tour sobre las pantallas reales; la app consulta `GET /plan/generation/{id}` (200) mientras tanto; **la operación sigue PROCESSING en cada paso** | `10-tour-10-pasos-durante-la-generacion.jpg` |
| 50.0 s | Tour terminado en 25.4 s; la rutina aún no está | `20-resultado-esperando.jpg` («¡Ya conoces Kora!», barra indeterminada, sin porcentaje) |
| ~71 s | La operación pasa a **COMPLETED** con `planId=1` | base: `COMPLETED|1`, 1 operación, 1 plan |
| 74.4 s | `GET /users/me/plan/1` 200 → «¡Tu primera rutina está lista! Semana del 16/11/2026 · 4 entrenamientos» | `21-resultado-lista.jpg` |
| — | «Ver mi plan» → inicio con el plan real (`/plan/current` 200, métricas, intervenciones) | `22-inicio-con-plan-real.jpg` |
| — | Rutinas: lunes, miércoles, viernes y domingo, «Tren superior / Tren inferior», con duración | `23-rutinas-del-plan.jpg` |

Sin intervención manual en la base de datos en ningún momento.

## 4. Respuestas de la fase 2

- **Flutter conectado al backend real**: sí, en web. Android: ver PRUEBAS_ANDROID.md.
- **Flujo completo**: funciona de punta a punta (registro → perfil → generación → tour → resultado → plan → rutinas).
- **Generación durante el tour**: sí; la operación estuvo PROCESSING durante los 10 pasos y terminó después.
- **Contrato**: 202 nueva / 200 existente / 404 ajena / 401 sin sesión, comprobado con la app y con `curl` (PRUEBAS_GENERACION_ASINCRONA.md).

## 5. Observación fuera del alcance

El inicio muestra «8 DÍAS» en «Tu plan de la semana» cuando el plan empieza mañana (domingo 15 →
semana del lunes 16 al domingo 22): cuenta desde hoy hasta el fin del plan, inclusive. Es código
anterior del dashboard (`heroPlan`), no de estas PR; no se tocó. Sugerencia: contar desde
`max(hoy, weekStartDate)`.
