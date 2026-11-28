# 08 · Pruebas y resultados

> **Revisión del 28/11/2026 (orden de merge):** ver [10](10_REVISION_FINAL_Y_BACKEND_96.md). El registro exige ahora
> los **tres** documentos publicados; Mobile usa los códigos estables de Backend #96; las PR siguen **sin fusionar**
> porque Backend #96 no está integrado.

Tres niveles, que no se mezclan:

| Nivel | Dónde |
|---|---|
| Automáticas (simuladores fieles al Backend) | `flutter test`, en cada rama y en la CI |
| Backend real en local (`41c498a`) | Pruebas en vivo de Dart y la app real compilada para web |
| Dispositivo físico | **Nada** ([06](06_QA_ANDROID.md)) |

## 1. `flutter analyze` y `flutter test` (Flutter 3.50.1 / Dart 3.14.0)

| Rama | Commit | analyze | Aprobadas | Fallidas | Omitidas | CI |
|---|---|---|---|---|---|---|
| `generation` (referencia, tras la #32) | `1cd9f97` | sin incidencias | 494 | 0 | 31 | [✓](https://github.com/Fitsense-Real/MobileApp/actions/runs/46095789950) |
| Mobile-C1 (#33) | `b8397bd` | sin incidencias | **509** | 0 | 43 | [✓](https://github.com/Fitsense-Real/MobileApp/actions/runs/46099634872) |
| Mobile-C3 (#34) | `955af82` | sin incidencias | **495** | 0 | 31 | [✓](https://github.com/Fitsense-Real/MobileApp/actions/runs/46100326435) |
| Mobile-C4 (esta, solo documentación) | — | sin incidencias | 494 | 0 | 31 | ver la PR |

Omitidas: las 31 de siempre (16 en vivo + 15 de capturas), más, en C1, las 12 nuevas en vivo de consentimientos, que
solo corren con `KORA_LIVE_API_BASE_URL`. Ninguna prueba se omitió, desactivó ni puso en cuarentena para conseguir el
verde.

## 2. Pruebas nuevas y modificadas

| Archivo | Rama | Cambio |
|---|---|---|
| `registration_consents_test.dart` | C1 | Reescrita para la opción A: 15 → 27 en ejecución (estudio explicado, nada premarcado, sin participar no hay cuenta, «No deseo participar», las cuatro versiones con comprobación previa, solo consentimiento publicado, CONSTANCIA, registro cerrado sin consentimiento o sin conexión, versión cambiada, 422 de términos/privacidad/estudio/falta, documento retirado, 429 con espera y sin código, pérdida de conexión al crear y al comprobar, lector, zona horaria, modelo `PublishedDocuments`, mensajes 422, `apiError`, historial) |
| `consents_test.dart` | C1 | Documentos de `GET /legal-documents`; +1 (CONSTANCIA) |
| `navigation_accessibility_test.dart` | C1 | +2 (aviso de retirada en Inicio; ningún aviso para un participante activo) |
| `account_setup_test.dart`, `auth_social_cleanup_test.dart`, `edge_to_edge_test.dart` | C1 | Texto de la opción A; el registro de prueba tiene documentos publicados para mostrar el formulario |
| `support/fake_backend.dart` | C1 | Cabeceras de respuesta (`Retry-After`) |
| `live/consentimientos_live_test.dart` | C1 | **Nueva**, en vivo: I-01, I-02, I-04 a I-14 |
| `logout_requests_test.dart` | C3 | **Nueva**: I-01 (falla con el código anterior) |
| `adaptation_history_test.dart`, `pain_o20_test.dart` | C3 | Inician sesión como en la app; lo que comprueban no cambia |

Ninguna prueba de D-M1, O20, P1, P2, generación, Firebase, adherencia o recuperación cambió lo que espera.

## 3. Regresiones vigiladas

Autenticación (`session_expiry_test`, `backend_contract_test`), registro, generación (`first_plan_generation_test`,
`generation_screen_test`, `welcome_tour_test`), ejercicios (`exercise_view_test`), D-M1
(`timed_exercise_results_test`, `exercise_results_test`), O20 (`pain_o20_test`, `o20_rutina_desactualizada_test`,
`o20_demo_kora_app_test`), P1 (`pending_results_persistence_test`), P2 (`adaptation_history_test`), Firebase
(`push_*_test`), adherencia (`adherence_history_test`), recuperación (`password_recovery_flow_test`) y accesibilidad
(`navigation_accessibility_test`, `edge_to_edge_test`): **todas en verde** en C1 y en C3.

## 4. Integración real contra el Backend `41c498a`

| Prueba | Resultado | Evidencia |
|---|---|---|
| Contrato de registro en vivo (I-01, I-04 a I-14, con documentos y exigencia) | 11/11 ✓ | [`contrato-en-vivo.txt`](evidencia/contrato-en-vivo.txt) |
| I-02 (sin documentos) | 1/1 ✓ | ídem |
| App real (C1): rechazo, aceptación, Perfil, cambio de versión, conexión, sin participación, retirada, 429, registro cerrado, cambio de cuenta | Todas ✓ (tras corregir el arnés, ver la cabecera de la evidencia) | [`escenarios-app-c1.txt`](evidencia/escenarios-app-c1.txt), [`capturas/`](capturas/) |
| Recuperación (app + API) | ✓; observación del Backend sobre el código anterior | [`recuperacion-41c498a.txt`](evidencia/recuperacion-41c498a.txt) |
| I-01 antes / después | 3 respuestas 401 → 0 | [`i01-antes-despues.txt`](evidencia/i01-antes-despues.txt) |

Los 16 escenarios obligatorios (I-01…I-16) se pasaron todos ([04](04_CONTRATOS_BACKEND.md)).

## 5. Lo que no prueban

- Ninguna prueba se hizo en un teléfono ni en un emulador.
- No se recibió ningún push real ni se envió un correo real.
- La exigencia y los documentos solo se activaron en la instancia local de pruebas.
- Los documentos usados son sintéticos; no hay textos aprobados.
