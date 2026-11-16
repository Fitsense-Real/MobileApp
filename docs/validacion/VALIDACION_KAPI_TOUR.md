# Validación de Kapi y del tour (fase 2)

El código de Kapi (#1) y del tour (#2) **no cambió** en esta validación. La evidencia detallada de
accesibilidad está en `PRUEBAS_TOUR_KAPI.md` (ORDEN 2); aquí se resume y se marca qué se volvió a
comprobar.

| Requisito | Estado | Cómo se comprobó |
|---|---|---|
| Paleta oficial | ✓ | SVG: solo `#0F2E25`, `#5E7865`, `#7A9A7E`, `#D9FF59`, `#F0F6D4`, `#F7F5ED` y los tres derivados documentados; prueba `kora_mascot_test` (paleta en cada SVG) |
| Las 6 expresiones | ✓ | bienvenida, explicación, motivación, espera, éxito y error, vistas en el tour y en el resultado (capturas); precargadas para web sin conexión |
| Mensajes acordes a la pantalla | ✓ | cada paso resalta lo que describe: plan, pestaña Rutinas, registro, Progreso, Recordatorios y «Ver recorrido de Kora» (`capturas-71-72/10-tour-10-pasos.jpg`) |
| 10 pasos y elementos resaltados correctos | ✓ | E2E de esta ronda; anillo lima sobre el elemento explicado |
| Navegación con botones y pestañas | ✓ | botones de la tarjeta; toque real en la pestaña «Rutinas» dentro del resaltado (E2E) |
| Tour inicial obligatorio | ✓ | sin botón de saltar; atrás del sistema retrocede un paso (`PopScope`) |
| Avanzar y retroceder | ✓ | prueba «forward, back and progress saved at every step» |
| Progreso guardado / reanudación | ✓ | E2E: cerrada en el paso 5, reabre en el paso 5 |
| No se repite una vez completado | ✓ | E2E «ya completó el tour»: login en un navegador nuevo → inicio; `account_setup_test` (completado + plan → inicio; completado sin plan → resultado) |
| Repaso voluntario desde Perfil | ✓ | «Ver recorrido de Kora»; no genera ni toca el progreso |
| Sin información falsa | ✓ | repaso con textos neutros (corregido en ORDEN 2); sin porcentajes; el tour no muestra datos inventados |
| Texto ampliado | ✓ | widget tests con texto 1.3, 1.5 y 2.0 |
| Pantallas pequeñas y horizontal | ✓ | 320×568 y 844×390 (E2E web) y widget tests |
| Lectores de pantalla | ✓ en el árbol de semántica | solo la tarjeta en la semántica; etiquetas «Paso n de 10» y de Kapi. **TalkBack/VoiceOver reales: pendiente en teléfono** |
| Teclado | ✓ | Tab recorre solo la tarjeta y Enter avanza (widget test y E2E web) |
| Botones visibles | ✓ | botón principal dentro de la pantalla en los 10 pasos con texto 2.0 |
| Movimiento reducido | ✓ | Kapi estático y anillo sin animación (`kora_mascot_test`, E2E con `prefers-reduced-motion`) |
| Sin interacciones accidentales detrás del tour | ✓ | toques fuera del resaltado absorbidos; pantalla real fuera del foco y de la semántica |

Pruebas de widget del tour y de Kapi en esta ejecución: `welcome_tour_test` 18/18,
`kora_mascot_test` 4/4 y `kapi_precache_test` 1/1.

No se encontraron defectos nuevos en Kapi ni en el tour.
