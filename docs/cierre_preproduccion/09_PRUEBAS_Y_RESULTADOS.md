# 09 · Pruebas y resultados

Tres niveles, que **no se mezclan**:

| Nivel | Qué prueba | Dónde |
|---|---|---|
| Automáticas (simuladas) | Pantallas y contratos con simuladores fieles al Backend | `flutter test` |
| Backend real en local | Contratos y app real (web) contra el Backend `generation` ejecutado en este entorno | Evidencia de este documento |
| Dispositivo físico | Nada | [08](08_PRUEBAS_ANDROID.md) (pendiente) |

## 1. `flutter analyze` y `flutter test` en cada PR

Flutter 3.50.1 / Dart 3.14.0. `flutter analyze` sin incidencias en las seis ramas.

| Rama | Commit | Aprobadas | Fallidas | Omitidas |
|---|---|---|---|---|
| `generation` (referencia) | `76dcf34` | 422 | 0 | 31 |
| M1 | `947448b` | 442 | 0 | 31 |
| M2 | `a3839f9` | 454 | 0 | 31 |
| M3 | `1ce8779` | 467 | 0 | 31 |
| M4 | `24aa690` | 483 | 0 | 31 |
| M5 | `1a71644` | 494 | 0 | 31 |
| M6 | esta rama | 494 | 0 | 31 |

Las 31 omitidas son las mismas que en la auditoría: 16 en vivo (necesitan `KORA_LIVE_API_BASE_URL` y, algunas, un
Backend preparado por etapas) y 15 de capturas de documentación.

## 2. Pruebas nuevas (72)

| Archivo | Pruebas | PR |
|---|---|---|
| `registration_consents_test.dart` | 15 | M1 |
| `account_setup_test.dart` | +4 | M1 |
| `consents_test.dart` | +1 (la prueba de aceptación se reescribió para exigir la lectura) | M1 |
| `password_recovery_flow_test.dart` | 12 | M2 |
| `exercise_view_test.dart` | 13 | M3 |
| `workout_logging_test.dart` | 12 | M4 |
| `timed_exercise_results_test.dart` | +4 | M4 |
| `navigation_accessibility_test.dart` | 9 | M5 |
| `onboarding_review_test.dart` | 2 | M5 |

Apoyo: `test/support/fake_backend.dart` (simulador HTTP fiel al Backend).

**Tamaños de pantalla en pruebas de interfaz:** 320 × 568 (rutina, ficha del ejercicio, barra de acciones, las cuatro
pestañas del Inicio), 360 de ancho (registro, recuperación, documentos), 390 × 844 (Progreso, Perfil, Ayuda).

## 3. Pruebas existentes modificadas y por qué

| Archivo | Cambio | ¿Cambia lo que se envía al Backend? |
|---|---|---|
| `support/welcome_fakes.dart` | La cuenta simulada `SignedIn` pasa a ser participante (la única que el Backend atiende); admite no participante y retirada | No |
| `consents_test.dart` | Hay que leer el documento antes de aceptarlo | No (mismas versiones aceptadas) |
| `timed_exercise_results_test.dart`, `exercise_results_test.dart`, `o20_rutina_desactualizada_test.dart`, `pending_results_persistence_test.dart` | Pulsan «Escribir los totales» antes de escribirlos; «Lo completé» se comprueba por su texto | **No: mismos cuerpos esperados** |
| `exercise_media_semantics_test.dart` | «Descanso entre series: 2 min 30 s» | No |
| `backend_alignment_test.dart` | Músculos en español; notas del plan plegadas; textos de Progreso; desplazar antes de tocar por la barra fija | No |
| `adherence_history_test.dart` | «puntos frente a la semana anterior», «Actualizado el» | No (mismo valor) |
| `ink_feedback_test.dart` | Ayuda abre la hoja de ayuda | No |
| `reminder_channel_test.dart` | Llamada nueva `getNotificationAppLaunchDetails` | No |

Ninguna prueba se omitió, desactivó ni puso en cuarentena.

## 4. Regresiones vigiladas

O20 (`pain_o20_test`, `o20_rutina_desactualizada_test`, `o20_demo_kora_app_test`), P1
(`pending_results_persistence_test`), P2 (`adaptation_history_test`), D-M1 (`timed_exercise_results_test`,
`exercise_results_test`), autenticación (`session_expiry_test`, `backend_contract_test`), generación asíncrona
(`first_plan_generation_test`, `generation_screen_test`, `welcome_tour_test`), navegación, historial, Firebase
(`push_*_test`), seguridad de cuentas (`account_deletion_test`) y persistencia local: **todas en verde** en cada rama.

## 5. Integración contra el Backend real (local)

| Prueba | Resultado | Evidencia |
|---|---|---|
| `timed_exercise_live_test` (3) y `push_backend_live_test` (1) sobre el código integrado | 4/4 ✓ | [`evidencia/pruebas-en-vivo-cierre.txt`](evidencia/pruebas-en-vivo-cierre.txt) |
| Recuperación de contraseña de punta a punta en la app real (202 → código → 204 → login 200) | ✓ | [`evidencia/recuperacion-app-backend-local.txt`](evidencia/recuperacion-app-backend-local.txt) |
| Registro sin participar en la app real → pantalla sin rutina (sin perfil ni generación) | ✓ | `capturas/despues/A7`, `B3` |
| Rutina, ficha, sesión iniciada (`POST /workouts/16/start` 201), diálogos, Progreso, Perfil, Ayuda, 320 × 568 | ✓ (capturas) | `capturas/despues/` |
| Contratos de la auditoría (registro, generación, sesión, omisión, métricas, recuperación, retirada) | Siguen vigentes: el Backend no cambió | `../preproduccion/evidencia/contratos-backend-local.txt` |

Arnés reproducible: [`evidencia/arnes/`](evidencia/arnes/) (`visual_cierre.js`, `cuentas_vivo.py`, `perfil.json`;
contraseña por `AUDIT_PASSWORD`).

## 6. Comparaciones antes/después

Capturas reales: «antes» de la auditoría (`generation` `76dcf34`) y «después» de la rama de cierre, ambas compiladas
para web (release) contra el mismo Backend local, mismos tamaños.

| Pantalla | Comparación |
|---|---|
| Registro | [A3](capturas/comparaciones/A3-registro-abajo-participacion-zona.jpg) |
| Cuenta sin rutina posible | [B3](capturas/comparaciones/B3-sin-rutina-disponible.jpg) |
| Recuperación | [A5](capturas/comparaciones/A5-recuperar-correo.jpg) |
| Inicio 320 × 568 | [D1](capturas/comparaciones/D1-inicio-320x568.jpg) |
| Rutinas | [C3](capturas/comparaciones/C3-rutinas.jpg) |
| Rutina | [C4](capturas/comparaciones/C4-rutina-arriba-gif.jpg) |
| Instrucciones → ficha | [C6](capturas/comparaciones/C6-instrucciones.jpg) |
| Sesión en curso | [C7](capturas/comparaciones/C7-sesion-en-curso.jpg) |
| Diálogo de resultado | [C8](capturas/comparaciones/C8-dialogo-resultado.jpg), [C9](capturas/comparaciones/C9-dialogo-parcial.jpg) |
| Sin conexión a los GIF | [E1](capturas/comparaciones/E1-gif-sin-conexion.jpg) |
| Progreso | [F1](capturas/comparaciones/F1-progreso.jpg) |
| Perfil y Cuenta | [F3](capturas/comparaciones/F3-perfil-abajo.jpg), [F4](capturas/comparaciones/F4-cuenta.jpg) |
| Solo «después» (pantallas nuevas) | `despues/A7`, `A8`, `A9`, `C6c`, `C10`, `C11`, `C12`, `D3`, `F5`, `G1` |

Las capturas web no sustituyen al teléfono (teclado, permisos, push, rendimiento).

## 7. Prueba de usabilidad (preparada, no realizada)

**No se hizo con personas** (requiere autorización; no se inventan resultados) y **no forma parte del estudio de 12
semanas**.

- **Participantes:** 3–5 personas que no conozcan Kora y no sean participantes del estudio, con un teléfono Android y
  una cuenta sintética preparada por el equipo.
- **Conducción:** una persona observa sin ayudar; pensar en voz alta; sesión de 30–40 min; grabación de pantalla con
  consentimiento.
- **Tareas:** (1) crear la cuenta entendiendo la participación; (2) encontrar la rutina de hoy; (3) explicar cómo se
  hace un ejercicio; (4) encontrar cuánto esforzarse; (5) registrar un entrenamiento completo; (6) registrar un
  ejercicio parcial; (7) informar dolor; (8) encontrar la adherencia semanal; (9) explicar por qué cambió su rutina
  (con una cuenta con adaptación); (10) encontrar ayuda.
- **Medidas por tarea:** tiempo, toques (contados en el vídeo), errores, peticiones de ayuda, abandono, dificultades
  observadas y una pregunta de opinión (1–5 y comentario).
- **Criterio de éxito propuesto:** ≥ 4 de 5 personas completan cada tarea sin ayuda; tareas 5–7 en menos de 2 min.
- **Registro:** tabla por persona y tarea, sin datos personales.
