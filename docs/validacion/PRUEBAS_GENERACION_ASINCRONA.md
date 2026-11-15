# Pruebas de la generación asíncrona (ORDEN 2, fase 4)

Cada caso se probó **de extremo a extremo** (app Flutter web → backend real → PostgreSQL local, IA
apagada; la demora o el fallo de la IA se simulan del lado del servidor) y, cuando aplica, con
pruebas automáticas del backend (`GeneracionAsincronaIT`, 15 casos sobre una base migrada V1..V58)
y de Flutter (`first_plan_generation_test.dart`, `welcome_tour_test.dart`).

Configuración E2E: worker con 2 en paralelo, latido 5 s, huérfana sin latido 30 s, tiempo máximo
300 s (en producción: 20 s, 180 s y 600 s).

## Casos

| # | Caso | Resultado E2E (estado real en la base) | Pantalla | Pruebas automáticas |
|---|---|---|---|---|
| 1 | La rutina termina antes que el tour | En el paso 1 la operación ya estaba `COMPLETED`; al pulsar «Terminar», «¡Tu primera rutina está lista!» al instante. 1 op, 1 plan | `caso01-rutina-antes-que-el-tour.jpg` | widget «A» |
| 2 | El tour termina antes que la rutina | Tour terminado en 25 s con la op `PROCESSING`; «¡Ya conoces Kora!» (espera sin porcentaje) y plan a los ~74 s | `20-resultado-esperando.jpg`, `21-resultado-lista.jpg` | widget «B» |
| 3 | Generación de 30 s | `+d30`: completó durante la espera; 1 op, 1 plan (junto con el caso 8) | `caso08-recuperado.jpg` | — |
| 4 | Generación de 90 s | `+d90`: completó tras cerrar y reabrir; 1 op, 1 plan (junto con 6/7) | — | — |
| 5 | Generación de varios minutos | `+d240`: `PROCESSING` 4 min con `executions=1` (el latido evitó reencolarla), luego `COMPLETED`; 1 op, 1 plan | `caso05-cuatro-minutos.jpg` | IT `unaGeneracionLentaQueLateNoSeTomaPorHuerfana`, `unaGeneracionLargaSeConsultaSinDuplicarse` |
| 6 | El usuario cierra la app | Cerrada en el paso 5 durante 15 s: la op siguió `PROCESSING` en el servidor | `caso06-antes-de-cerrar.jpg` | widget «4, 5, 6», controlador «7» |
| 7 | El usuario vuelve a abrir Kora | Reabre en el **paso 5**, retoma la **misma** operación (sin otra), termina `COMPLETED`; 1 op, 1 plan | `caso07-reabierta-mismo-paso.jpg` | controlador «7», «404 → se pide otra vez, idempotente» |
| 8 | Flutter pierde la conexión | Sin red desde el inicio del tour: «Seguimos intentando · No hay conexión…» con Kapi; mientras tanto el servidor completó; al volver la red, plan en ~5 s sin nueva petición; 1 op | `caso08-sin-conexion.jpg`, `caso08-recuperado.jpg` | controlador «13», widget «13» |
| 9 | El backend devuelve un error técnico | `+fallo1`: `FAILED / ERROR_TECNICO / retryable`; «Algo salió mal» + «Intentar de nuevo»; **8 s sin reintento automático**; al pulsar, op nueva → `COMPLETED`; 2 op, 1 plan | `caso09-error-tecnico.jpg`, `caso09-reintento-ok.jpg` | IT `unErrorTecnicoPermiteReintentarDeFormaSegura`, controlador «12» |
| 10 | El backend devuelve NO_FACTIBLE | `NO_FACTIBLE / SIN_SEMANA_GENERABLE`; explica que no se relajan restricciones, «Contactar al equipo» (diálogo) y «Cerrar sesión»; sin reintento; 0 planes | `caso10-no-factible.jpg`, `caso10-contacto.jpg` | IT `sinSemanaGenerableTerminaNoFactible`, widget «C» |
| 11 | Tocar «Generar mi plan» varias veces | 5 clics seguidos: **1** `POST /profile`, **1** `POST /plan/generation`, 1 op, 1 plan | — | IT `pedirDosVecesNoGeneraDosRutinas`, `peticionesSimultaneasDevuelvenLaMismaOperacion`; controlador «8, 18» |
| 12 | Dos usuarios generan a la vez | Dos navegadores en paralelo (`+d25`): op y plan propios (planes 10 y 11). Con el token de A: operación de B → **404**, plan de B → **404**, su plan → 200; sin token → 401 | — | IT `dosUsuariosSimultaneosNoCompartenEstados`; controlador «19» |
| 13 | El backend se reinicia durante una operación | **SIGTERM (despliegue)**: antes de B4 quedaba `FAILED/ERROR_TECNICO`; ahora vuelve a `PENDING` al apagarse (executions 0), la nueva instancia la retoma y termina `COMPLETED`. **SIGKILL (caída)**: queda `PROCESSING` sin latido; a los 30 s se reencola (executions 2) y termina `COMPLETED`. En ambos, la app mostró «Seguimos intentando» y luego el plan; 1 op, 1 plan | `caso13-backend-detenido.jpg`, `caso13-retomada-tras-despliegue.jpg`, `caso13-recuperada-tras-caida.jpg` | IT `unApagadoOrdenadoDevuelveLaOperacionALaColaYSeRetoma`, `unaEjecucionInterrumpidaSeRecuperaYNoQuedaColgada`; worker `alApagarseNoRegistraLaInterrupcion…` |
| 14 | Una operación supera el tiempo máximo | `+d400` con máximo 300 s: a los 5 min `FAILED / TIEMPO_EXCEDIDO / retryable`; «Algo salió mal · tardó más de lo permitido» + «Intentar de nuevo». La generación tardía terminó a los 400 s y **no se publicó** (log: «descartada antes de publicar»); 0 planes 140 s después | `caso14-tiempo-excedido.jpg` | IT `superarElTiempoMaximoCierraLaOperacionSinPublicarTarde`, `unaPendienteQueNadieAtiendeVence` |
| 15 | El usuario ya tiene una rutina publicada | Navegador nuevo: login → **inicio con su plan, sin tour**. `POST /plan/generation` devuelve la misma operación `COMPLETED` con `planId=1`; sigue habiendo 1 op | `caso15-ya-tiene-plan.jpg` | IT `pedirDosVecesNoGeneraDosRutinas` (POST tras COMPLETED) |

Observación del caso 1 (primera ejecución): con los dos huecos del worker ocupados por los casos 5
y 14, la operación esperó en `PENDING` hasta que se liberó uno (~2,5 min) y luego completó; la app
mostró la espera sin porcentaje. Es el comportamiento previsto con `max-concurrent=2`; conviene
dimensionarlo según la carga real con IA (ver ESTADO_PR_Y_ORDEN_MERGE.md).

## Garantías, comprobadas sobre toda la base E2E al final

| Garantía | Consulta | Resultado |
|---|---|---|
| Sin rutinas duplicadas | usuarios con más de un plan | **0** |
| Nunca COMPLETED sin plan válido | `COMPLETED` sin `plan_id` | **0** |
| Sin acceso cruzado | `COMPLETED` con plan de otro usuario | **0**; 404 por API |
| Sin operaciones perdidas ni cargas infinitas | operaciones `PENDING`/`PROCESSING` colgadas | **0** |
| Una sola operación activa por usuario | usuarios con más de una activa | **0** (índice único parcial) |
| Sin llamadas innecesarias a la IA | 20 ejecuciones del generador para 18 operaciones | las 2 extra son las reanudaciones legítimas del caso 13 |
| Sin rutinas inválidas | todo plan sale del pipeline con los validadores de siempre; un resultado fuera de tiempo se descarta | caso 14 |
| Sin porcentajes falsos | la app solo muestra una barra indeterminada | capturas |

Totales: 18 operaciones (14 `COMPLETED`, 2 `FAILED/ERROR_TECNICO` (caso 9 y la ejecución del caso 13
anterior a B4), 1 `FAILED/TIEMPO_EXCEDIDO`, 1 `NO_FACTIBLE`), 14 planes.

## Recuperación tras reiniciar el backend

| Situación | Qué pasa |
|---|---|
| Apagado ordenado (SIGTERM, despliegue) | El worker deja de reclamar, interrumpe sus generaciones sin registrarlas como fallo y las devuelve a `PENDING` sin gastar intento. La siguiente instancia las toma en ~2 s tras arrancar. |
| Caída (SIGKILL, OOM, máquina perdida) | La operación queda `PROCESSING` y deja de latir. A los 3 min (producción) el barrido la reencola una vez; si vuelve a caer, `FAILED / EJECUCION_INTERRUMPIDA` reintentable. |
| Generación lenta pero viva | Sigue latiendo cada 20 s: nunca se reencola ni se duplica. |
| Generación colgada | A los 10 min `FAILED / TIEMPO_EXCEDIDO` reintentable; si al final produce algo, no se publica. |
| Ningún worker activo | Una `PENDING` vence a los 30 min (`TIEMPO_EXCEDIDO`) cuando vuelve un worker. |
