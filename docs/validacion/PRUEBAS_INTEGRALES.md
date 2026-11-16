# Pruebas integrales con el backend #71 + #72 (16/11/2026)

## Entorno

| Pieza | Valor |
|---|---|
| Backend | head de Fitsense-Real/Backend#72 (`93549d5`, incluye #71), jar local |
| Base | PostgreSQL 16 local, base nueva `fitsense_e2e72`, Flyway desde cero hasta **V59** (62 migraciones) |
| IA | apagada: motor de reglas real; demoras y fallos simulados del lado del servidor por correo (`e2e/EscenariosE2E.java`) |
| Ajustes de prueba | lease 15 s, latido 5 s, tiempo máximo 300 s, 4 en paralelo (`e2e/run-backend-71-72.sh`) |
| App | rama `claude/mobile-final-validation` (#1 + #2 + correcciones), Flutter web release |
| Conducción | Playwright, 390×844, por la semántica de Flutter |
| Usuarios | sintéticos `*@e2e.local` |

Sin Replicate, sin bases reales y sin respuestas falsas en Flutter.

## Flujo principal (`lucia+d45`) — superado

| Paso | Evidencia |
|---|---|
| Registro 201, login 200, perfil 404 → formulario | `capturas-71-72/01-perfil.jpg` |
| Perfil y preferencias (objetivo, físico, días, equipo, permisos) → `POST /profile` 201 | — |
| «Generar mi plan» → `POST /plan/generation` **202**; tour en ~2 s | — |
| 10 pasos con la operación **PROCESSING** en cada uno (verificado en la base) | `10-tour-10-pasos.jpg` |
| Tour terminado con la rutina aún en curso → espera sin porcentaje | `20-espera-tras-el-tour.jpg` |
| 19 s después: `COMPLETED`, plan 1 → «¡Tu primera rutina está lista! Semana del 16/11/2026 · 4 entrenamientos» | `21-rutina-lista.jpg` |
| Inicio con el plan real: **«7 DÍAS»** (el plan empieza hoy, lunes 16) | `22-inicio-7-dias.jpg` |
| Rutinas: lunes, miércoles, viernes y domingo | `23-rutinas.jpg` |
| Sesión abierta: «Tren superior · Lunes 16/11 · 40 min», instrucciones y registro | `24-sesion-generada.jpg` |

Resultado: 1 operación, 1 plan.

## Casos adicionales

| Caso | Resultado (estado en la base) | Captura |
|---|---|---|
| La rutina termina antes del tour | `COMPLETED` ya en el paso 1; plan al pulsar «Terminar» | `caso-rutina-antes-del-tour.jpg` |
| El tour termina antes que la rutina | flujo principal | `20-espera-tras-el-tour.jpg` |
| Generación de varios minutos (`+d240`) | `PROCESSING` 4 min con `executions=1` (el lease no la reencoló) → `COMPLETED` | `caso-cuatro-minutos.jpg` |
| Cerrar Flutter durante el tour | cerrada en el paso 5, 15 s; reabre en el **paso 5**, misma operación → `COMPLETED`; 1 op | `caso-cerrar-en-el-tour-reabierta.jpg` |
| Cerrar Flutter durante la espera | cerrada 20 s en la pantalla de resultado; reabre en la **pantalla de resultado** (no repite el tour), misma operación → plan; 1 op | `caso-cerrar-en-la-espera-*.jpg` |
| Pérdida de conexión | «Seguimos intentando» con Kapi; el servidor completa; al volver la red, plan sin nueva petición; 1 op; 0 SVG fallidos | `caso-sin-conexion.jpg` |
| Reinicio del backend, SIGTERM | vuelve a `PENDING` (executions 0); la nueva instancia la retoma → `COMPLETED`; la app muestra el plan | `caso-reinicio-sigterm.jpg` |
| Reinicio del backend, SIGKILL | `PROCESSING` sin lease → a los 15 s se reencola (executions 2) → `COMPLETED`; la app muestra el plan | `caso-reinicio-sigkill.jpg` |
| NO_FACTIBLE | `NO_FACTIBLE/SIN_SEMANA_GENERABLE`, contacto, sin reintento, 0 planes | `caso-no-factible.jpg` |
| La generación falla | `FAILED/ERROR_TECNICO`; 8 s sin reintento automático; «Intentar de nuevo» → op nueva → `COMPLETED`; 2 op, 1 plan | `caso-error-tecnico.jpg`, `caso-reintento-manual.jpg` |
| Tiempo excedido (`+d400`, máximo 300 s) | `FAILED/TIEMPO_EXCEDIDO` a los 308 s con «Intentar de nuevo»; la generación tardía **no se publicó** (0 planes 140 s después) | `caso-tiempo-excedido.jpg` |
| Pedir el plan repetidamente | 5 clics en «Generar mi plan»: 1 `POST /profile`, 1 `POST /plan/generation`, 1 op, 1 plan | — |
| El usuario ya completó el tour | navegador nuevo, login: inicio con su plan, **sin tour** | `caso-tour-ya-completado.jpg` |

## Garantías en toda la base

| Comprobación | Resultado |
|---|---|
| usuarios con más de un plan | 0 |
| `COMPLETED` sin plan | 0 |
| `COMPLETED` con plan de otro usuario | 0 |
| operaciones `PENDING`/`PROCESSING` colgadas | 0 |
| totales | 13 operaciones: 10 `COMPLETED`, 1 `ERROR_TECNICO` (el caso de fallo), 1 `TIEMPO_EXCEDIDO`, 1 `NO_FACTIBLE`; 10 planes |
| ejecuciones del generador | 15 para 13 operaciones: las 2 extra son las reanudaciones de SIGTERM y SIGKILL |

## Incidencias del arnés (no de la app)

Dos ejecuciones lanzadas a la vez con otras tres no llegaron a empezar: un registro con correo
mezclado (409) y una espera de 15 s del arnés agotada bajo carga. El backend no registró ningún
error. Se repitieron solas y pasaron (casos de conexión y de tiempo excedido).

## Lo que no se repitió

La accesibilidad del tour y la ronda E2E de la ORDEN 2 (#71, 15 casos) no se repitieron completas:
el código del tour no cambió desde entonces y sus 18 pruebas de widget siguen en verde.
