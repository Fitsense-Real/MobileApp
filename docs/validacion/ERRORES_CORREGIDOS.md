# Errores encontrados y corregidos (ORDEN 2, fase 6)

Para cada error: reproducción → causa → corrección localizada → prueba de regresión → pruebas
afectadas ejecutadas de nuevo. No se relajó ningún validador ni se cambió el catálogo, la
adherencia, H2 o la mascota.

## Backend (Fitsense-Real/Backend#71)

### B1 · El CI se cancelaba a los 45 minutos — `e14a28e`
- **Reproducción**: ejecución de CI de la PR cancelada por tiempo; el log terminaba con cientos de
  `HikariPool-NN - Connection to localhost:328xx refused`.
- **Causa**: `PlanGenerationWorker` (activo por defecto) sondeaba la base cada 2 s en **cada**
  contexto de Spring en caché de las pruebas, también cuando su contenedor de Testcontainers ya se
  había detenido; cada ciclo esperaba el tiempo de conexión de Hikari.
- **Corrección**: `fitsense.plan-generation.worker.enabled=false` en surefire y failsafe (`pom.xml`).
  Las pruebas del worker lo conducen paso a paso.
- **Verificación**: `verify -Pintegration` completo, local y en CI. El CI terminó en 19 min.

### B2 · 48 errores en las IT con catálogo fijado — `1faaeb0`
- **Reproducción**: `mvn verify -Pintegration` local (Testcontainers): 20 clases (V35..V50) fallaban
  al arrancar con `Schema validation: missing table [plan_generation_operations]`.
- **Causa**: esas IT fijan `spring.flyway.target` en un catálogo anterior y validan las entidades
  con `ddl-auto=validate`; la tabla nueva no existía. El repositorio ya tiene el mecanismo
  `EsquemaVigenteSobreCatalogoAnterior` para las migraciones de solo esquema.
- **Corrección**: añadir V58 (solo crea una tabla y sus índices) a esa lista. Una línea en una
  clase de prueba.
- **Verificación**: las 6 clases representativas (15 pruebas) y después la suite completa:
  1554 unitarias y 769 de integración, 0 fallos.

### B3 · Robustez: reencolado de generaciones lentas y sin tiempo máximo — `e14a28e`
- **Detectado** al revisar los casos 5, 13 y 14: la huérfana se detectaba 15 min después de
  `started_at`, así que una generación lenta pero viva podía reencolarse y ejecutarse dos veces, y
  una colgada no tenía límite.
- **Corrección**: latido cada 20 s (`updated_at`). Huérfana = sin latido durante 3 min. Tiempo
  máximo: `PROCESSING` > 10 min o `PENDING` > 30 min → `FAILED / TIEMPO_EXCEDIDO` reintentable.
  Antes de publicar se comprueba que la operación siga `PROCESSING`; si no, el resultado se descarta.
- **Pruebas**: IT `unaGeneracionLentaQueLateNoSeTomaPorHuerfana`,
  `superarElTiempoMaximoCierraLaOperacionSinPublicarTarde`, `unaPendienteQueNadieAtiendeVence`;
  worker `lateSoloPorLasOperacionesQueEstaEjecutando`. E2E casos 5 y 14.

### B4 · Un apagado ordenado marcaba la generación como fallida — `12a01c6`
- **Reproducción** (E2E, caso 13): `kill -TERM` al backend durante una generación → la operación
  quedó `FAILED / ERROR_TECNICO` y el participante tenía que reintentar a mano.
- **Causa**: `@PreDestroy` hacía `shutdownNow()`; la interrupción llegaba al pipeline como una
  excepción y `execute` la clasificaba como error técnico.
- **Corrección**: el worker marca que se está apagando, deja de reclamar, `execute` no registra
  la interrupción, y al terminar devuelve sus operaciones a `PENDING` sin gastar intento.
- **Pruebas**: IT `unApagadoOrdenadoDevuelveLaOperacionALaColaYSeRetoma`; worker
  `alApagarseNoRegistraLaInterrupcionYDevuelveLaOperacionALaCola`. E2E repetido con SIGTERM y
  SIGKILL: ambos terminan `COMPLETED` con un solo plan.

## Flutter (Fitsense-Real/MobileApp#2)

### F1 · Con texto grande el botón del tour quedaba fuera de la pantalla — `b5cbf30`
- **Reproducción**: widget test nuevo, texto 2.0 en 360×740: en el paso 3 el botón «Ir a Rutinas»
  quedaba en y = 834–890 con una pantalla de 740.
- **Causa**: la tarjeta no tenía altura máxima.
- **Corrección**: la tarjeta toma como máximo el espacio lejos del resaltado (al menos media
  pantalla) y solo el mensaje de Kapi se desplaza; el progreso y los botones quedan siempre visibles.
- **Pruebas**: texto 2.0, horizontal y horizontal con texto 1.5, en los 10 pasos.

### F2 · En web, sin conexión, Kapi no aparecía en las pantallas de error — `b5cbf30`
- **Reproducción** (E2E, caso 8): sin red, `kapi_explain.svg`, `kapi_motivate.svg` y
  `kapi_error.svg` fallaron con `net::ERR_FAILED`; «Seguimos intentando» se mostró sin Kapi.
- **Causa**: en web cada recurso se descarga la primera vez que se muestra. En Android e iOS van
  dentro de la app, así que allí no ocurre.
- **Corrección**: se precargan las seis expresiones en la caché de `flutter_svg` al empezar el tour
  y en la pantalla de resultado (misma clave de caché que usa `SvgPicture.asset`).
- **Pruebas**: `kapi_precache_test.dart`. E2E del caso 8 repetido: Kapi visible y ninguna petición
  de SVG fallida.

### F3 · Teclado y lectores de pantalla podían actuar detrás del velo — `19b9e9b`
- **Reproducción**: widget test nuevo: el primer Tab enfocaba un widget de la pantalla real.
- **Causa**: la barrera del tour bloquea toques, no el foco ni las acciones de semántica (un lector
  de pantalla activa botones sin pasar por la prueba de toque).
- **Corrección**: durante el tour la pantalla real queda fuera del foco y de la semántica
  (`ExcludeFocus` + `ExcludeSemantics`). El botón de la tarjeta hace lo mismo que tocar el
  resaltado, y el toque real sobre el resaltado sigue funcionando (prueba y E2E).
- **Pruebas**: «teclado y lectores: solo la tarjeta, Enter avanza». E2E con teclado en tres tamaños.

### F4 · El repaso desde Perfil decía que la primera rutina se estaba preparando — `19b9e9b`
- **Reproducción** (E2E, repaso con un usuario que ya tiene plan): los pasos 1 y 2 y el panel de
  muestra decían «Mientras Kora prepara tu primera rutina…» y «Tu primera rutina se está
  preparando». Era un estado falso.
- **Corrección**: textos neutros solo en el repaso (`replayMessage`, `tourReplay`). El primer
  recorrido no cambia.
- **Pruebas**: el widget test del repaso comprueba que no aparezca «prepara» ni «primera rutina».
  E2E: ambos `false`.

## Observaciones que no se corrigieron (fuera de alcance)

- «8 DÍAS» en la tarjeta del plan cuando este empieza mañana: código anterior del dashboard
  (VALIDACION_FLUTTER_BACKEND.md §5).
- En web, Flutter pide a `fonts.gstatic.com` una fuente de respaldo (Noto Sans SC) para algún
  carácter; sin conexión, la petición falla sin efecto visible. No afecta a Android ni iOS.
