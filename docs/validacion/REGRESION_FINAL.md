# Regresión final (ORDEN 2, fase 7)

Todas las cifras son de ejecuciones reales de esta orden; nada es estimado.

## Backend — Fitsense-Real/Backend#71, `12a01c6`

| Suite | Dónde | Resultado |
|---|---|---|
| Unitarias completas (`mvn test`) | local | **1555 ejecutadas, 0 fallos, 0 errores**, 1 omitida (ya omitida en `generation`) |
| Integración completa (`mvn verify -Pintegration`, Testcontainers, PostgreSQL 16) | CI de la PR | **770 ejecutadas, 0 fallos, 0 errores**, 72 omitidas (opt-in: Neon, Replicate, réplica P2-D) · BUILD SUCCESS en 19 min 19 s |
| Integración completa | local, en `1faaeb0` | 1554 unitarias + 769 de integración, 0 fallos (25 min 44 s) |
| `GeneracionAsincronaIT` (opt-in, base V1..V58 migrada desde cero) | local, `12a01c6` | **15/15** |
| Específicas V58 | local | `GenerationFailureClassifierTest` 6, `PlanGenerationOperationTest` 5, `PlanGenerationWorkerTest` 4 |

Antes de las correcciones: CI cancelado a los 45 min; en local, 48 errores en 20 IT con catálogo
fijado (ERRORES_CORREGIDOS.md, B1 y B2).

## Flutter — Fitsense-Real/MobileApp#2 (incluye #1)

| Comprobación | Resultado |
|---|---|
| `flutter test` (suite completa) | **127 pasan**, 0 fallan (antes de esta orden: 121) |
| `flutter analyze` | **No issues found** |
| `flutter build web --release` | OK |
| `flutter build apk --debug` | OK, `app-debug.apk` (SDK 35, minSdk 21, etiqueta «Kora», 6 SVG de Kapi incluidos) |
| `flutter build apk --release` | OK, `app-release.apk` 29,3 MB (R8 sin errores; firmado con la clave debug de la plantilla, no apto para Play) |
| iOS | **No compilado**: requiere macOS y Xcode, que este entorno (Linux) no tiene |

Pruebas nuevas en esta orden (6):
- 3 de pasos que caben: texto 2.0 a 360 px, horizontal, y horizontal con texto 1.5;
- 1 de tamaño, etiquetas y contraste de los botones;
- 1 de teclado y semántica;
- 1 de precarga de Kapi.

Además, el widget test del repaso comprueba ahora los textos neutros.

Desglose de las pruebas de bienvenida: `welcome_tour_test.dart` 18, `first_plan_generation_test.dart`
10, `kapi_precache_test.dart` 1, `kora_mascot_test.dart` 3. A ellas se suman `account_setup_test` y
`onboarding_flow_test`, adaptadas en la PR #2, que siguen pasando.

## Extremo a extremo (app real + backend real)

| Ejecución | Resultado |
|---|---|
| Recorrido principal (registro → perfil → generación → tour → resultado → plan → rutinas) | OK |
| Casos asíncronos 1–15 | 15/15 con el comportamiento esperado (PRUEBAS_GENERACION_ASINCRONA.md) |
| Repetición tras las correcciones (caso 8 con el SVG, caso 13 con SIGTERM y SIGKILL, regresión final con el build definitivo) | OK |
| Garantías sobre la base E2E | 0 planes duplicados, 0 COMPLETED sin plan, 0 cruces, 0 operaciones colgadas |
| Accesibilidad en web (320×568, 844×390, movimiento reducido, teclado) | OK |
