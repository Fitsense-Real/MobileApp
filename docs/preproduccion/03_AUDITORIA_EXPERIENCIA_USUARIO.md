# 03 · Auditoría de experiencia de usuario

Evaluación de las pantallas existentes, del recorrido de entrenamiento, de la accesibilidad y del rendimiento, pensando
en una persona sin experiencia con aplicaciones de entrenamiento que debe usar Kora **12 semanas**. Las propuestas son
propuestas: no se implementa ni se rediseña nada en esta auditoría.

Evidencia: código `generation` `76dcf34`, capturas reales de la app (web release contra el Backend local, cuentas
sintéticas) en [`evidencia/capturas/`](evidencia/capturas/), y las pruebas descritas en
[01](01_INVENTARIO_FUNCIONAL_MOBILE.md). **Las capturas web no sustituyen a un teléfono**: no reproducen el teclado del
sistema, la barra de navegación de Android, los permisos ni el rendimiento real.

## 1. Recorrido completo de una persona

`Abrir Kora → Consultar rutina → Revisar ejercicio → Entrenar → Registrar resultado → Consultar progreso`

Conteo de toques medido sobre el código y las capturas, para una rutina de 8 ejercicios (la del plan generado hoy):

| Paso | Qué hace la persona | Toques (mínimo) | Observaciones |
|---|---|---|---|
| Abrir | Splash restaura la sesión → Preparación de cuenta → Inicio | 0 | Bien: no pide credenciales durante 7 días |
| Consultar rutina | Inicio → tarjeta de «Rutinas para hoy» (o «Próximas rutinas») | 1 | En 320 px la tarjeta queda debajo del pliegue (`D1`) |
| Revisar ejercicio | Ver GIF y datos en la tarjeta; «Ver instrucciones» | 0–1 por ejercicio | La hoja de instrucciones tapa el GIF (`C6`) |
| Empezar | Bajar hasta el final de la lista (8 tarjetas) → «Comenzar entrenamiento» | 1 + desplazamiento largo | El botón principal está **después de todos los ejercicios** (`C6b`). Alternativa: «Registrar ejercicio» en una tarjeta abre un diálogo «Comenzar sesión y registrar / Ya hice este entrenamiento» que no se explica |
| Registrar cada ejercicio | «Registrar ejercicio» → «Lo completé» → «Guardar» | 3 × 8 = **24** | No hay «Registrar todo como completado». Cada guardado consulta el plan antes de enviar (O20), con barra de progreso |
| Finalizar | Bajar → «Finalizar sesión» → esfuerzo (desplegable 1–10) → satisfacción (desplegable 1–5, opcional) → minutos (prellenado) → «Finalizar» | ~6 | Si falta un ejercicio: «Indica si realizaste o no cada ejercicio antes de finalizar» |
| Ver resultado | Tarjeta «Sesión guardada · 94.45% completado» | 0 | Sin mensaje de ánimo ni resumen; decimales y punto decimal inglés |
| Consultar progreso | Barra inferior → «Progreso» | 1 | Vacío hasta el primer cierre semanal (lunes): «Todavía no hay métricas semanales calculadas» (`F1`) |

**Total para una sesión completa sin incidencias: ~35 toques más dos desplazamientos largos.** Una sesión parcial suma, por
ejercicio parcial, elegir la opción, escribir 2–3 números y elegir un motivo.

## 2. Evaluación por pantalla

Formato de la orden: función · qué funciona bien · problema comprobado · impacto · mejora propuesta · prioridad ·
dependencia Backend · evidencia · criterio de aceptación. Los ID `M-xx` remiten a la matriz
([08](08_MATRIZ_DE_PENDIENTES.md)) y al plan de cierre ([07](07_PLAN_DE_CIERRE_MOBILE.md)).

### 2.1 Registro y primer ingreso

| | |
|---|---|
| Función | Crear la cuenta (nombres, apellidos, correo, contraseña ×2, zona horaria, participación) y pasar a iniciar sesión |
| Funciona bien | Validaciones iguales al Backend; mostrar/ocultar contraseña; autocompletado; diseño claro (`A2`) |
| Problema comprobado | (1) Participación «Opcional» → sin rutina si no se marca (`A3` → `B3`). (2) Zona horaria editable a mano; `Lima` → 400. (3) Ni términos, ni privacidad, ni consentimiento informado. (4) Tras crear la cuenta vuelve a «Iniciar sesión» y hay que escribir todo otra vez |
| Impacto | (1) Bloquea a la persona tras 5 pasos y 30 s. (2) Error incomprensible. (3) Consentimiento no informado. (4) Fricción en el primer minuto |
| Mejora propuesta | Ver [02](02_AUTENTICACION_Y_CONSENTIMIENTOS.md) §2 y §4.4; iniciar sesión automáticamente tras registrar (el Backend no devuelve token en el registro: requiere un `login` inmediato con las mismas credenciales, sin cambio de Backend) |
| Prioridad | P0 (1, 3) · P1 (2) · P2 (4) |
| Dependencia Backend | Sí para (1) y (3) |
| Evidencia | `A2`, `A3`, `A6`, `B2`, `B3`; `contratos-backend-local.txt` §1–3 |
| Criterio de aceptación | Ninguna cuenta puede llegar al perfil sin poder recibir un plan; ningún registro falla por la zona horaria; el consentimiento se lee antes de aceptarse |

### 2.2 Perfil inicial (5 pasos) y generación

| | |
|---|---|
| Función | Objetivo, datos físicos, días y minutos, lugar y equipamiento, movimientos a evitar; explicación de avisos; «Generando…» 30 s; recorrido de Kapi (10 pasos) |
| Funciona bien | Paso a paso con progreso «Paso N de 5»; límites claros (días por nivel); «Peso corporal» premarcado y desmarcable; retoma la generación si se cierra la app; recorrido obligatorio que no se pierde |
| Problema comprobado | (1) Aviso «Tu perfil no se podrá cambiar durante el estudio» en letra pequeña al final (`onboarding_page.dart:359`): no hay forma de corregir un error de tecleo (peso, días) ni de adaptar el equipamiento si cambia. (2) «Volver» en el paso 1 lleva a `/dashboard` sin plan (`onboarding_page.dart:314`). (3) «Combinando tu perfil con modelos de optimización biomecánica» (`generating_plan.dart:160`) no describe lo que hace el sistema (motor de reglas o IA). (4) La espera de 30 s se mantiene aunque el Backend ya haya rechazado la solicitud (`B2` con 422 a los 0 s). (5) «Notas de salud» se piden pero nadie las usa |
| Impacto | (1) Un dato mal puesto condiciona 12 semanas de plan. (3) Afirmación que el estudio no puede sostener. (4) 30 s de espera para un error |
| Mejora propuesta | Pantalla de **revisión antes de «Generar mi plan»** con todos los datos y el aviso de que no podrán cambiarse; corregir «Volver»; texto neutro de espera; cortar la espera cuando la respuesta es un error; quitar o explicar las notas de salud |
| Prioridad | P1 (1) · P2 (2–5) |
| Dependencia Backend | Para (1), decidir si el perfil puede editarse en el estudio (hoy 422 tras el primer plan) |
| Evidencia | `B2`, `B3`; `onboarding_page.dart` |
| Criterio de aceptación | La persona ve y confirma su perfil completo antes de generar; ningún texto afirma técnicas que el sistema no usa |

### 2.3 Inicio

| | |
|---|---|
| Función | Saludo, tarjeta «Tu plan de la semana», «Tu progreso», «Rutinas para hoy / Próximas rutinas» |
| Funciona bien | Aspecto cuidado; días que faltan para el plan («EMPIEZA EN 3 DÍAS»); cada sección falla por separado con «Reintentar»; deslizar para actualizar |
| Problema comprobado | (1) En 320 × 568 el titular se parte a mitad de palabra «Muévet / e» y «VER PLAN ›» en dos líneas (`D1`). (2) La tarjeta principal ocupa la primera pantalla y la rutina de hoy queda abajo. (3) Fotos de stock por enfoque, no de los ejercicios. (4) Textos de 9–11 px en gris verdoso de contraste 3,1:1 (§4) |
| Impacto | Aspecto roto en teléfonos pequeños; la acción del día no es lo primero que se ve |
| Mejora propuesta | Titular con ajuste de tamaño y sin cortes; poner «Entrenamiento de hoy» con botón «Empezar» como primer bloque; tamaños mínimos de 12–14 px |
| Prioridad | P1 (1, 4: M-19) · P2 (2, 3) |
| Dependencia Backend | No |
| Evidencia | `C1`, `C2`, `D1` |
| Criterio de aceptación | En 320 × 568 ningún texto se corta a mitad de palabra y el entrenamiento de hoy aparece sin desplazarse |

### 2.4 Rutinas (lista del plan)

| | |
|---|---|
| Función | Avisos O20, «Lo que tu plan no puede cubrir», filtros por enfoque, búsqueda, favoritos, tarjetas por día |
| Funciona bien | Agrupado por día con fecha; estado de cada entrenamiento en español |
| Problema comprobado | El bloque **«Lo que tu plan no puede cubrir» ocupa toda la primera pantalla** con textos del Backend pensados para revisión interna: «Las cifras orientativas están pendientes de validación profesional», «ejercicios cuya clasificación está en revisión… la revisión profesional del catálogo está pendiente» (`C3`). Las rutinas quedan debajo |
| Impacto | Resta confianza («¿mi plan está validado?») y esconde la acción principal |
| Mejora propuesta | Mostrar una línea plegada «Tu plan tiene 3 notas» que se abre bajo demanda; acordar con el Backend y el equipo del estudio qué textos ven los participantes |
| Prioridad | **P1** |
| Dependencia Backend | Sí (contenido de `GET /users/me/plan/limitations`) |
| Evidencia | `C3` |
| Criterio de aceptación | La primera tarjeta de entrenamiento es visible sin desplazarse en 390 × 844; ningún texto visible menciona revisiones internas pendientes sin acuerdo del equipo |

### 2.5 Detalle de la rutina y de los ejercicios

Ver diagnóstico completo en [04](04_VISUALIZACION_DE_EJERCICIOS.md). Resumen: GIF de terceros sin controles, guía de
esfuerzo ausente, músculos en inglés, botón «Comenzar entrenamiento» al final, informar dolor difícil. P1.

### 2.6 Registro de entrenamiento

| | |
|---|---|
| Función | Diálogo por ejercicio; finalizar con esfuerzo, satisfacción y minutos; omitir con motivo; «Ya lo hice» |
| Funciona bien | Reglas D-M1 bien explicadas con mensajes que evitan errores («Eso es todo lo indicado en tu plan… elige Lo completé»); O20 retiene lo que ya no es válido; P1 guarda lo no enviado; minutos prellenados por el cronómetro; motivo de omisión con contexto de falta de tiempo; evita dobles envíos (`sending`) |
| Problema comprobado | (1) Cuatro campos visibles antes de elegir una opción y campo de duración en ejercicios por repeticiones (`C8`). (2) «Repeticiones totales (todas las series)» obliga a sumar; etiquetas cortadas con «…» a 390 px (`C8`, `C9`). (3) **Esfuerzo percibido 1–10 sin ninguna explicación** de la escala (`planned_workout_page.dart` `FinishDialog`). (4) Satisfacción 1–5 sin etiquetas. (5) No hay campo de **observaciones** (el Backend tampoco lo tiene: `FinishSessionResource` solo `sessionRpe`, `satisfaction`, `activeMinutes`). (6) 24 toques para registrar una sesión completa de 8 ejercicios. (7) Resultado final «94.45% completado» sin mensaje de cierre. (8) «Ya lo hice» permite elegir cualquier fecha desde el año 2000 |
| Impacto | El esfuerzo percibido es una variable del estudio: sin anclas, cada persona interpreta la escala a su manera. Registros parciales mal sumados. Fatiga de registro → menos registros → menor cobertura |
| Mejora propuesta | Diálogo guiado por serie (ver [04](04_VISUALIZACION_DE_EJERCICIOS.md) propuesta 7); escala de esfuerzo con descripciones aprobadas por el equipo del estudio (no inventarlas); «Marcar los ejercicios restantes como completados» con confirmación; mensaje final que resuma lo hecho; limitar la fecha de «Ya lo hice» a la semana del plan |
| Prioridad | **P1** (1–3, 6) · P2 (4, 7, 8) · (5) depende de decisión |
| Dependencia Backend | (5) sí; (8) el Backend ya acepta fechas futuras (observación B-5 de `docs/auditoria_final`) |
| Evidencia | `C7`, `C8`, `C9`; `contratos-backend-local.txt` §5; `pruebas-en-vivo-backend-local.txt` |
| Criterio de aceptación | Registrar una sesión completa de 8 ejercicios en ≤ 12 toques; una parcial se registra serie a serie y el total enviado coincide con D-M1; la escala de esfuerzo muestra texto aprobado |

### 2.7 Progreso

| | |
|---|---|
| Función | Adherencia semanal del Backend, gráfico de barras, sesiones, adaptación, resumen de ajustes, historial de adaptaciones (P2) |
| Funciona bien | Muestra exactamente `weightedAdherencePct` del Backend (no recalcula); distingue cobertura de registro y cumplimiento observado; P2 en lenguaje natural sin códigos |
| Problema comprobado | (1) «+5 pp», «Cumplimiento en lo registrado», «Calculado: …» son términos técnicos. (2) **«Riesgo de abandono: Alto/Crítico»** se muestra al participante (`dashboard_page.dart:1019`). (3) Vacío durante la primera semana sin explicar cuándo habrá datos (`F1`). (4) Textos de 8–11 px (fechas del gráfico a 8 px) |
| Impacto | (2) Etiquetar al participante con su riesgo de abandono puede desmotivarle e influir en el resultado del estudio. (1) No se entiende la cifra principal |
| Mejora propuesta | Frases: «Esta semana hiciste 4 de 5 entrenamientos»; «2 puntos más que la semana anterior»; explicar «Tus datos aparecerán el lunes, al cerrar tu primera semana»; **decidir con el equipo del estudio si el riesgo se muestra** (propuesta: no mostrarlo) |
| Prioridad | **P1** (1–3: M-15) · P2 (4) |
| Dependencia Backend | No (decisión de protocolo) |
| Evidencia | `F1`; `dashboard_page.dart:793-1050` |
| Criterio de aceptación | Ningún término técnico ni etiqueta de riesgo visible sin acuerdo; el valor mostrado sigue siendo idéntico al del Backend |

### 2.8 Adaptaciones

| | |
|---|---|
| Función | Por qué cambió (o no) la rutina, semana a semana |
| Funciona bien | P2: «Tu rutina avanzó un paso», «Se sustituyó un ejercicio por seguridad», «Aún faltaban entrenamientos registrados para evaluar cambios»; códigos desconocidos con texto general |
| Problema comprobado | No dice **qué debe hacer la persona** después (p. ej. «registra todos tus entrenamientos para que Kora pueda ajustar»); el historial está al final de Progreso y «Novedades de tu plan» está en otro sitio (campana del Inicio y «Notificaciones» de Perfil) |
| Impacto | La persona ve que algo cambió pero no qué hacer; tres entradas parecidas confunden |
| Mejora propuesta | Una sola sección «Cambios en tu plan» con la última adaptación arriba y una frase de acción por tipo de resultado (textos acordados) |
| Prioridad | P2 |
| Dependencia Backend | No |
| Evidencia | `docs/mejoras/p2/capturas/` |
| Criterio de aceptación | Cada resultado de P2 tiene una frase de qué hacer; no hay dos menús con el mismo contenido |

### 2.9 Restricciones por dolor (O20)

| | |
|---|---|
| Función | Bloqueo de ejercicios, preguntas de identificación, exclusiones en Perfil, reactivación |
| Funciona bien | Explicaciones claras sin códigos; nunca envía sin confirmar la rutina; retiene resultados inválidos; pregunta sin insistir |
| Problema comprobado | Informar dolor exige 4 toques y no existe para ejercicios completados (ver 04 V-6); **no hay ningún mensaje de seguridad** en la app del tipo «si el dolor es intenso o persiste, detente y consulta a un profesional» (solo en algunos `messageShown` del Backend); el recorrido de Kapi no enseña cómo informar dolor |
| Impacto | Dolor no reportado → O20 no actúa |
| Mejora propuesta | Botón visible «Tengo dolor o molestias» (04, propuesta 6); texto de seguridad aprobado por el equipo del estudio en el primer uso y al informar dolor; un paso del recorrido |
| Prioridad | **P1** |
| Dependencia Backend | Texto aprobado; Backend solo si se registra dolor en ejercicios completados |
| Evidencia | `exercise_result_dialog.dart:120-136`; `grep -rn profesional lib/` sin resultados |
| Criterio de aceptación | Informar dolor en ≤ 2 toques; el mensaje de seguridad aparece con el texto aprobado |

### 2.10 Perfil, cuenta y ayuda

| | |
|---|---|
| Función | Favoritos, Notificaciones, Recordatorios, Avisos en el teléfono, Historial de planes, Excluidos por dolor, Cuenta, Ayuda, Recorrido, Cerrar sesión |
| Funciona bien | Estado del estudio y código visibles; documentos aceptados; retirada con confirmación (`F4`) |
| Problema comprobado | (1) Tres entradas casi iguales: «Notificaciones» (novedades del plan), «Recordatorios» (locales), «Avisos en el teléfono» (push). (2) «Ayuda y soporte» es un único párrafo, sin contacto del equipo del estudio. (3) Texto de retirada engañoso (M-17). (4) Menú con texto de 12 px |
| Impacto | La persona no sabe dónde activar los recordatorios ni a quién escribir |
| Mejora propuesta | Agrupar en «Avisos y recordatorios»; «Ayuda» con preguntas frecuentes y el contacto del estudio (dato que debe facilitar el equipo) |
| Prioridad | P1 (2, 3) · P2 (1, 4) |
| Dependencia Backend | No |
| Evidencia | `F3`, `F4` |
| Criterio de aceptación | Una sola entrada para avisos; la ayuda muestra un contacto real |

### 2.11 Errores y estados vacíos

| Situación | Lo que ve la persona | Valoración |
|---|---|---|
| Sin conexión (release) | «No se pudo conectar con el servidor. Revisa tu conexión a internet e inténtalo de nuevo.» | ✓ |
| 401 | «Tu sesión expiró. Vuelve a iniciar sesión.» y vuelve al login | ✓ |
| 422 del Backend | El texto del Backend tal cual (sin tildes: «Esta sesion ya esta cerrada», «deberias») | P2: acordar textos con tildes en el Backend |
| Resultado no enviado | Tarjeta «1 resultado guardado en este teléfono, sin enviar…» + «Reintentar envío» | ✓ |
| Tarjeta de error en la rutina | Botón «Consultar estado de sesión» | P2: «Actualizar» |
| Sin plan | «No tienes un plan disponible.» + «Preparar mi plan» | Para un no participante o retirado lleva a un 422 (M-01, M-17) |

## 3. Notificaciones y recordatorios (experiencia)

Ver estado técnico en [05](05_INTEGRACION_CON_BACKEND.md) §5. Experiencia:

- Tras la explicación de avisos del onboarding, **los recordatorios de entrenamiento quedan desactivados**
  (`reminders_controller.dart:107`) y el Backend no envía recordatorios por push (solo `PLAN_GENERATED`, `PLAN_ADAPTED`,
  `WEEKLY_PLAN_READY`, `ACCOUNT_NOTICE`). El recorrido de Kapi dice «Activa avisos para los días que tienes
  entrenamiento», pero no los activa. **Resultado: un participante típico no recibe ningún recordatorio de entrenar** (M-16,
  P1, decisión de protocolo: los recordatorios son una intervención que afecta a la adherencia medida).
- Tocar un recordatorio con la app cerrada abre Kora en el inicio, no en la rutina (no se usa
  `getNotificationAppLaunchDetails`). P2, verificar en teléfono.

## 4. Accesibilidad

| Aspecto | Hallazgo | Evidencia | Prioridad |
|---|---|---|---|
| Tamaño de texto | 30 usos de tamaños de 8 a 11,5 px (1 × 8, 6 × 9, 12 × 10, 10 × 11, 1 × 11,5), sobre todo en Inicio, Rutinas y Progreso: etiquetas, duración de la tarjeta, fechas del gráfico, «VER PLAN» | `grep -rhoE "fontSize: ?[0-9]+" lib/` | P1 |
| Contraste | `Kora.sage` (#7A9A7E), usado 30 veces en `dashboard_page.dart` para texto secundario pequeño: **3,11:1 sobre blanco y 2,85:1 sobre marfil** (WCAG AA exige 4,5:1). Iconos y etiquetas no seleccionados de la barra inferior (sage al 45–55 %): **1,78:1**. `Kora.muted` cumple (4,83:1) | Cálculo sobre `kora_ui.dart:5-9` | P1 |
| Escalado del texto del sistema | No se limita (bien), pero no se probó con texto grande en un teléfono; con tamaños fijos de 8–11 px y alturas fijas (botón de 76 px, tarjetas) pueden aparecer cortes | — | P1 (probar en teléfono) |
| Áreas táctiles | «VER PLAN» con alto mínimo de 34 px (`dashboard_page.dart:545`, < 48 dp); chips de categoría de 10 px; «Ver instrucciones» como `TextButton` compacto. Botones principales (`KoraButton`) y menú del Perfil cumplen | `C1`, `C3` | P2 |
| Lectores de pantalla | Botones con `tooltip`, gráfico con `Semantics` por barra, GIF fuera del árbol de semántica (correcto, el texto lo describe). 19 `Semantics` y 13 `tooltip` en total | `exercise_media_semantics_test.dart` | ✓ |
| Movimiento | Kapi respeta «reducir movimiento»; los GIF de ejercicios no | `kora_mascot.dart:50` | P2 |
| Orientación | No se bloquea; la app usa `maxWidth` 560–600; en horizontal se probó el teclado en validaciones previas (`docs/validacion/capturas/a11y-horizontal-teclado.jpg`) | — | ✓ |
| Idioma | Solo español (`locale es`); términos en inglés del catálogo (músculos, grupos) y del Backend | `C6` | P2 (ver 04) |

**Personas sin experiencia:** las barreras principales son la escala de esfuerzo sin explicación, el registro parcial
por totales, el texto pequeño de bajo contraste y la falta de un «qué hago hoy» en primer plano.

## 5. Rendimiento

**No se midió en un teléfono** (no hay dispositivo). Observaciones de código y de la compilación web:

| Aspecto | Observación | Riesgo |
|---|---|---|
| Tiempo de apertura | Splash → `GET /users/me` → consentimientos → perfil → plan → Inicio: 4–5 peticiones encadenadas antes de ver el Inicio (registro `[api]` del arnés) | Con conexión lenta (3G) varios segundos en «Preparando tu cuenta…» |
| Navegación | Las pantallas se construyen con listas no perezosas (`ListView(children: …)`); el detalle de la rutina construye todas las tarjetas | Bajo con 8 ejercicios |
| Animaciones | Varios GIF animándose a la vez en la rutina; `flutter_animate` en Kapi | Batería/CPU en gama baja: medir en teléfono |
| Memoria | GIF decodificados en la caché de imágenes en memoria (sin caché en disco) | Bajo; recargas en cada apertura |
| Datos móviles | ~0,8 MB de GIF por rutina en cada apertura en frío | Medio para participantes con datos limitados |
| Conexión lenta | Tiempos de 20 s por petición (`dio_client.dart`); el registro de un resultado espera hasta 8 s la confirmación del plan antes de guardar en el teléfono | Aceptable; los mensajes lo explican |
| Sin conexión | Mensaje claro; resultados en P1; GIF sin respaldo | Ver 04 |
| Tamaño | `main.dart.js` de la compilación web: 5,9 MB (referencia; el APK no se midió en esta auditoría) | — |

**Pendiente en teléfono (gama baja Android 11–16):** arranque en frío, desplazamiento de la rutina, memoria con la rutina
abierta 10 min, consumo de batería de una sesión de 40 min con la pantalla encendida.
