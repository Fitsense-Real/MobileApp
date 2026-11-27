# 04 · Visualización de ejercicios: diagnóstico y propuestas

**Nada de esto rediseña ni reemplaza lo existente.** Primero se describe lo que hay, después lo que se comprobó, y al final
propuestas con su dependencia y su criterio de aceptación. No se redacta ninguna explicación técnica nueva de ejercicios:
los textos de ejecución deben salir del catálogo del Backend, revisado por un profesional.

Evidencia: código `generation` `76dcf34`; plan real generado por el Backend local con el motor de reglas
([`evidencia/contratos-backend-local.txt`](evidencia/contratos-backend-local.txt) §4); capturas `C4`, `C6`, `C6b`, `C7`,
`C8`, `C9`, `D2`, `E1` (app compilada para web, 390 × 844 y 320 × 568, contra ese Backend).

## 1. Dónde se muestran los ejercicios hoy

| Lugar | Archivo | Qué muestra |
|---|---|---|
| Lista de rutinas (Rutinas / Inicio) | `dashboard_page.dart` `routineCard()` | Foto genérica por enfoque (no del ejercicio), duración, nombre del entrenamiento, estado. Fecha como encabezado del grupo |
| Rutina del día (detalle) | `planned_workout_page.dart:562-600` | Una tarjeta por ejercicio: GIF (220 px de alto), nombre, «N series · M repeticiones por serie» o «N s por serie», «Descanso: X s», notas del plan, bloqueo O20, botones de cronómetro (solo con sesión en curso), «Ver instrucciones», estado del registro, «Registrar ejercicio» |
| Detalle del ejercicio | `planned_workout_page.dart:679-702` `ExerciseInstructions` (hoja inferior) | Nombre, «Músculo principal», «Secundarios», instrucciones en un solo párrafo, atribución «© Gym visual» |
| Registro de ejecución | `exercise_result_dialog.dart` | Prescripción, «Lo completé / Lo hice parcialmente / No lo hice», 4 campos numéricos, motivo |
| Cronómetros | `session_timer.dart` | Tiempo activo con pausa; cuenta atrás de serie y de descanso con vibración y sonido |

**Datos que el Backend envía y Mobile no muestra** (claves reales del plan, verificadas hoy):

| Campo del plan | ¿Se muestra? |
|---|---|
| `effortGuidance` (nivel del plan): `repsInReserve`, `setsRepsText` «Termina cada serie sintiendo que podrías hacer unas 3 repeticiones más…», `durationText`, `loadText` | **No** (`grep effortGuidance lib/` → sin resultados) |
| `bodyPart` (p. ej. `upper legs`), `targetMuscle` (`quads`) en la tarjeta | No en la tarjeta; el músculo aparece en inglés en la hoja de instrucciones (`C6`: «Músculo principal: pectorals») |
| `equipment` (`body weight`, `smith machine`) | **No** |
| `difficultyLevel` | No |
| `imagePath` (imagen fija del mismo ejercicio) | **No**; tampoco como respaldo cuando el GIF falla |
| `mediaAttribution` | Solo en la hoja de instrucciones (el parámetro de `ExerciseMedia` no se usa) |
| `instruction_steps_es` (pasos en lista, en la base) | El Backend no los expone en `ExerciseDetailResource`; solo el párrafo `instructions` |

## 2. Origen de las animaciones

- `exercise_media.dart:3-13`: el `gifPath` del Backend (`videos/1688-K9VL0Jq.gif`) se convierte en
  `https://raw.githubusercontent.com/hasaneyldrm/exercises-dataset/main/videos/<archivo>.gif`. **Mobile depende de un
  repositorio personal de GitHub de un tercero.**
- Archivos comprobados hoy: GIF89a de **180 × 180 px**, 65–116 KB cada uno, servidos en 0,3–0,5 s.
- Licencia: el propio Backend documenta que «las imágenes y los GIF son © Gym visual, redistribuidos con permiso **al
  autor del conjunto de datos**. El derecho de FitSense a usarlos no está documentado» y que la propuesta de alojamiento
  propio está «sin implementar · decisión pendiente» (`Backend/docs/FitSense/cierre_definitivo_backend/MATRIZ_CONTRATOS_API.md`
  filas 8 y §2).
- Riesgos durante 12 semanas: el repositorio puede borrarse, renombrarse o limitarse; GitHub puede limitar descargas; un
  uso sin licencia puede obligar a retirar las animaciones a mitad del estudio.

## 3. Las 15 verificaciones obligatorias

| # | Pregunta | Resultado | Evidencia |
|---|---|---|---|
| 1 | ¿Las animaciones cargan correctamente? | **Sí** con conexión: los GIF de un plan real cargaron en la app (`C4`, `C6b`). Muestran indicador mientras cargan | `exercise_media.dart:37` |
| 2 | ¿Corresponden al ejercicio asignado? | **Sí en lo comprobado**: el `gifPath` viene del mismo registro del catálogo que el nombre; el Backend revisó GIF y textos (V36, V49, V56 «texto según GIF»). Muestra revisada hoy: «Gancho de izquierda (boxeo)», «Flexión con protracción escapular», «Escalador» coinciden con su animación. No se revisaron los 1.324 | `C4`, `C6b`, `D2` |
| 3 | ¿Se ven completas? | **Sí**: `BoxFit.contain` no recorta. Fondo blanco del GIF sobre tarjeta blanca | `exercise_media.dart:30` |
| 4 | ¿Su tamaño permite observar el movimiento? | **Parcialmente**. Ocupan 220 px de alto, pero el original es de 180 px: se amplía y se ve algo borroso en pantallas de alta densidad. En 320 × 568 la figura se ve pequeña junto al texto (`D2`). No se puede ampliar ni ver a pantalla completa | `C4`, `D2` |
| 5 | ¿Hay controles de reproducción? | **No**. Bucle continuo, sin pausa, ni cámara lenta, ni repetición paso a paso. No respeta «reducir movimiento» del sistema (sí lo hace Kapi) | `exercise_media.dart`; `kora_mascot.dart:50` como contraste |
| 6 | ¿Se puede acceder a las instrucciones? | **Sí**, «Ver instrucciones» abre una hoja inferior con el texto del catálogo (en español) | `C6` |
| 7 | ¿Se entiende cómo ejecutar el ejercicio? | **Parcialmente**. El texto es claro y describe lo que muestra el GIF, pero (a) GIF e instrucciones nunca se ven juntos: la hoja tapa la animación (`C6`); (b) un solo párrafo, sin pasos; (c) músculos en inglés («pectorals», «triceps, shoulders»); (d) no se muestra la guía de esfuerzo del plan | `C6` |
| 8 | ¿Los nombres son comprensibles? | **Mayoritariamente**. Nombres en español del catálogo. Algunos son técnicos o poco habituales para principiantes («Flexión con protracción escapular», «Sentadilla isométrica en pared con extensión de pierna», «Gancho de izquierda (boxeo)») | `D2`, `E1` |
| 9 | ¿Series y repeticiones visibles? | **Sí**: «2 series · 10 repeticiones por serie» bajo el nombre | `C4` |
| 10 | ¿Los descansos se interpretan correctamente? | **Ambiguo**: «Descanso: 90 s» no dice si es entre series o tras el ejercicio. Con sesión en curso aparece «Descanso 90 s» como botón de cuenta atrás (`C7`), que ayuda; sin sesión, no hay cronómetro. «120 s» en lugar de «2 min» | `C4`, `C7` |
| 11 | ¿Funciona en distintos tamaños? | **Con defectos en 320 px**: en el Inicio el titular se parte a mitad de palabra («Muévet / e») y «VER PLAN ›» se parte en dos líneas (`D1`); la rutina es legible (`D2`); en el diálogo de resultado las etiquetas se cortan con «…» ya a 390 px (`C8`) | `D1`, `D2`, `C8` |
| 12 | ¿Sin conexión o si falla la imagen? | Texto «No se pudo cargar el GIF.» + «Reintentar GIF»; el resto de la tarjeta funciona (`E1`). Sin imagen fija de respaldo (`imagePath` no se usa) y sin caché en disco: cada arranque descarga de nuevo y sin red no hay ninguna animación, aunque se haya visto antes | `E1`, `exercise_media.dart:38` |
| 13 | ¿Se puede informar dolor o dificultad fácilmente? | **No fácilmente**: solo dentro de «Registrar ejercicio» → «Lo hice parcialmente» o «No lo hice» → desplegable «Motivo» → «Dolor o molestias» / «Demasiado difícil» (4 toques y un desplegable). No hay botón visible de «Me duele». Si la persona completó el ejercicio con molestias, no hay forma de decirlo | `exercise_result_dialog.dart:120-136` |
| 14 | ¿Se diferencian bloqueados y permitidos? | **Sí**: recuadro rojo claro «No disponible por ahora» con la explicación O20 en lenguaje natural; el diálogo solo deja «No lo hice» | `planned_workout_page.dart:569-578`; `docs/o20/capturas/01-rutina-con-ejercicio-bloqueado.png` |
| 15 | ¿Se puede volver al entrenamiento sin perder información? | **Sí** en el registro en vivo: cada resultado se envía al guardarlo y la sesión vive en el Backend; los pendientes se guardan en el teléfono (P1). **No** en «Ya lo hice»: los borradores se pierden si Android cierra la app (P3, fuera de alcance). La hoja de instrucciones y los diálogos vuelven a la misma posición | `pending_results_store.dart`; `docs/mejoras/PENDIENTES.md` |

## 4. Problemas comprobados (resumen)

| ID | Problema | Impacto en el usuario | Prioridad |
|---|---|---|---|
| V-1 (M-06) | GIF de un repositorio personal de terceros, licencia de uso no documentada | Si desaparecen o hay que retirarlos, el estudio queda sin animaciones a mitad de camino | **P1** (sube a P0 si el equipo legal no autoriza su uso) |
| V-2 (M-07) | No se muestra `effortGuidance` (repeticiones en reserva, carga) | La persona no sabe cuánto esforzarse ni qué peso usar; afecta al esfuerzo percibido que se registra y a la seguridad | **P1** |
| V-3 (M-08) | Músculo y grupo en inglés o ausentes; equipamiento no visible | Principiantes no saben qué trabaja ni qué necesitan antes de empezar | P2 (no impide ejecutar el ejercicio; el nombre y las instrucciones están en español) |
| V-4 (M-09) | GIF pequeño (180 px), sin controles, sin ampliar, todos animándose a la vez | Difícil observar la técnica; consumo de batería y datos (~0,8 MB por rutina en cada apertura) | P1 |
| V-5 (M-09) | Sin respaldo cuando el GIF falla ni caché | Sin red no hay ninguna referencia visual | P1 |
| V-6 (M-12) | Informar dolor exige 4 toques y no existe para ejercicios completados | Dolor no reportado → O20 no actúa → riesgo para el participante | **P1** |
| V-7 | Instrucciones en hoja separada que tapa el GIF; un solo párrafo | Hay que memorizar el texto y cerrar la hoja para ver el movimiento | P1 |
| V-8 | «Descanso: 90 s» ambiguo; cronómetros solo con sesión iniciada | Descansos mal interpretados | P2 |
| V-9 (M-10) | Diálogo de registro con 4 campos visibles antes de elegir, «Repeticiones totales (todas las series)» exige multiplicar, campo de duración en ejercicios por repeticiones, etiquetas cortadas | Registros parciales erróneos (D-M1) o abandono del registro | **P1** |

## 5. Propuestas (no implementadas)

Cada propuesta conserva el comportamiento actual (O20, P1, D-M1) y se presenta como opción.

| # | Propuesta | Resuelve | Dependencia Backend | Criterio de aceptación |
|---|---|---|---|---|
| 1 | **Alojar los medios en un almacenamiento propio** con licencia confirmada; el Backend devuelve `gifUrl`/`imageUrl` (propuesta ya escrita en la matriz del Backend) y Mobile deja de construir la URL | V-1 | **Sí** (alojamiento, licencia, campos aditivos) | Ninguna URL de `raw.githubusercontent.com` en la app; licencia documentada; si el campo es nulo, la tarjeta funciona sin imagen |
| 2 | **Mostrar la guía de esfuerzo** del plan una vez arriba de la rutina («Cómo esforzarte hoy») y en cada ejercicio por repeticiones/tiempo, con el texto exacto de `effortGuidance` | V-2 | No (ya llega) | El texto mostrado es idéntico al del Backend; si falta, no se muestra nada inventado |
| 3 | **Ficha del ejercicio a pantalla completa** (en lugar de la hoja): GIF grande arriba (ancho completo, ampliable con un toque), debajo series/repeticiones/descanso, equipamiento y las instrucciones; botones «Pausar animación» y «Anterior / Siguiente ejercicio» | V-4, V-7, navegación | Recomendable: exponer `instruction_steps_es` como lista y nombres de músculo/grupo/equipamiento en español | GIF e instrucciones visibles a la vez en 390 × 844; pausa funciona; con «reducir movimiento» la animación empieza pausada |
| 4 | **Traducir músculo, grupo y equipamiento** con una tabla cerrada de códigos del catálogo (como ya se hace con los estados) o con campos `*Es` del Backend | V-3 | Preferible Backend (`targetMuscleEs`, `equipmentEs`); alternativa: tabla en Mobile con código desconocido → se omite | Ningún término en inglés visible; un código desconocido no se muestra crudo |
| 5 | **Imagen fija de respaldo** (`imagePath`) cuando el GIF falla y caché en disco de los GIF ya vistos | V-5 | Depende de la propuesta 1 (misma fuente) | Sin red, un ejercicio visto antes muestra su animación o su imagen |
| 6 | **Botón «Tengo dolor o molestias»** visible en cada tarjeta durante la sesión, que abre el mismo diálogo ya en «No lo hice / Lo hice parcialmente» con el motivo «Dolor o molestias» preseleccionado | V-6 | No para lo básico. Para «lo completé pero me dolió» **sí** (hoy el Backend solo registra dolor como motivo de no realizar) | Informar dolor en ≤ 2 toques; O20 recibe el mismo `skipReason` que hoy; nada se envía sin confirmar la rutina (regla O20 vigente) |
| 7 | **Diálogo de registro guiado**: tras elegir «Lo hice parcialmente», preguntar por serie («Serie 1: __ repeticiones», …) y calcular el total que se envía; mostrar solo los campos del tipo de ejercicio (repeticiones **o** segundos); carga solo si el plan la indica | V-9 | No | El cuerpo enviado es idéntico al actual (`actualRepsTotal` total); ninguna etiqueta cortada a 320 px |
| 8 | **Descanso explícito**: «Descansa 1 min 30 s entre series» y cuenta atrás disponible también fuera de la sesión en vivo | V-8 | No | Texto con unidad legible; la cuenta atrás no registra nada |
| 9 | Cargar solo el GIF visible y pausar los que salen de pantalla | V-4 (rendimiento) | No | Medido en un Android de gama baja: desplazamiento fluido y sin aumento de memoria al recorrer la rutina |

**No se propone** reemplazar las animaciones actuales por otras: su correspondencia con los ejercicios ya fue revisada en
el Backend. Lo que debe resolverse primero es su **derecho de uso y su alojamiento** (propuesta 1).
