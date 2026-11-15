# Pruebas del tour de Kapi (ORDEN 2, fase 3)

## 1. Sobre la app real (Playwright + backend real)

| Comprobación | Resultado | Evidencia |
|---|---|---|
| El tour se abre al pedir la rutina, no después | Sí: `POST /plan/generation` 202 y paso 1 visible en ~3 s | `VALIDACION_FLUTTER_BACKEND.md` §3 |
| 10 pasos sobre las pantallas reales (Inicio, Rutinas, Progreso, Perfil) | Sí; el anillo lima cae sobre el elemento explicado y la tarjeta no lo tapa | `capturas/10-tour-10-pasos-durante-la-generacion.jpg` |
| Paso interactivo: tocar la pestaña real «Rutinas» dentro del resaltado | Avanza al paso 4 (toque real por coordenadas) | `final.js`: «paso 3: toque en la pestaña real -> paso 4» |
| Sin botón para saltarlo; atrás/siguiente; «Paso n de 10» | Sí | capturas |
| Cerrar la app en el paso 5 y reabrir | Reabre en el **paso 5**, misma operación, sin nuevo POST que cree otra | `caso06-antes-de-cerrar.jpg`, `caso07-reabierta-mismo-paso.jpg` |
| No lee datos del usuario durante el tour | El inicio muestra el estado vacío real; el plan se presenta solo después | capturas del tour |
| Repaso desde Perfil → «Ver recorrido de Kora» | 10 pasos, vuelve a Perfil, no genera nada; **sin textos de «rutina en preparación»** (corregido, F4) | `repaso-desde-perfil-paso1.jpg`, `paso2.jpg` |
| Teclado (web): Tab + Enter | Recorre y completa los 10 pasos a 320×568, 844×390 y con movimiento reducido; el foco queda en la tarjeta | `a11y-320x568-teclado.jpg`, `a11y-horizontal-teclado.jpg` |
| Pantalla pequeña 320×568 | Todos los pasos caben; botones visibles | `a11y-320x568-teclado.jpg` |
| Horizontal 844×390 | Todos los pasos caben; botones visibles | `a11y-horizontal-teclado.jpg` |
| Movimiento reducido (`prefers-reduced-motion`) | Recorrido completo sin animaciones del anillo ni de Kapi | `a11y.js` |
| Sin conexión durante el tour (web) | Kapi visible en «Seguimos intentando» (corregido, F2) | `caso08-sin-conexion.jpg` |

## 2. Pruebas de widget (`test/welcome_tour_test.dart`, 18 casos)

Funcionales (13, ya existentes): arranque simultáneo con la generación; atrás/siguiente con
progreso guardado; solo la pestaña resaltada responde; reanudación sin marcar completado; no lee
datos reales; 320 px con texto 1.3; repaso sin generar ni tocar el progreso; resultado A, B y C;
sin conexión; 5xx.

Accesibilidad (nuevos en esta orden):

| Prueba | Qué comprueba | Resultado |
|---|---|---|
| texto 2.0 en 360×740 | Ningún desbordamiento y botón principal dentro de la pantalla en los 10 pasos | Falló antes de F1 (botón en y=834–890 de 740); pasa |
| horizontal 740×360 | Igual, en horizontal | Pasa |
| horizontal 800×380 con texto 1.5 | Igual | Pasa |
| tamaño, etiquetas y contraste | Botones de la tarjeta ≥ 44×44, `labeledTapTargetGuideline`, `iOSTapTargetGuideline`, `textContrastGuideline` (WCAG AA) en los 10 pasos | Pasa |
| teclado y lectores | Tab solo enfoca la tarjeta; la pantalla real no está en la semántica; Enter avanza | Falló antes de F3 (Tab enfocaba la pantalla real); pasa |

`test/kora_mascot_test.dart` (PR #1): etiqueta accesible por expresión, animación suave y
**estática con movimiento reducido**, burbuja a 320 px con texto 1.3.

## 3. Límites

- Lectores de pantalla reales (TalkBack, VoiceOver) no se probaron: no hay dispositivo. Se
  verificó el árbol de semántica (widget test y semántica web).
- El texto grande se probó en widget tests (escala 1.3, 1.5 y 2.0); en web, Chromium no expone
  un ajuste de tamaño de fuente que Flutter lea, así que no hay captura E2E de esa escala.
