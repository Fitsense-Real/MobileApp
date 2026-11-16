# Regresión Flutter (fase 8, 16/11/2026)

Rama `claude/mobile-final-validation` (incluye #1 y #2). Flutter 3.32.8.

| Comprobación | Resultado |
|---|---|
| `flutter test` | **142 pasan, 0 fallan** (antes: 127) |
| `flutter analyze` | No issues found |
| `flutter build web --release` | ✓ |
| `flutter build apk --debug` (emulador y USB) | ✓ |
| `flutter build apk --debug --split-per-abi` (arm64) | ✓ |
| `flutter build apk --release` | ✓ (29,3 MB) |
| E2E con backend #71 + #72 | flujo principal y 13 casos ✓ (PRUEBAS_INTEGRALES.md) |

## Pruebas nuevas (15)

| Archivo | Pruebas | Qué fija |
|---|---|---|
| `plan_week_label_test.dart` | 10 | «8 DÍAS»: empieza mañana o en n días, hoy, mitad de semana, cambio de día, último día, después, horario de verano, fechas inválidas; widget de la tarjeta real (falla con el código anterior) |
| `first_plan_generation_test.dart` | +3 | #72: operación larga con cortes y 5xx sin pedir otra; recurso documentado; reintento manual tras `TIEMPO_EXCEDIDO` |
| `profile_contract_v55_test.dart` | 2 | campos del perfil = `CreateUserProfileResource` actual; V55 fuera del contrato REST |

## Áreas pedidas

| Área | Archivos | Estado |
|---|---|---|
| Kapi | `kora_mascot_test` 4, `kapi_precache_test` 1 | ✓ |
| Recorrido | `welcome_tour_test` 18 | ✓ |
| Navegación | `welcome_tour_test` (pestañas, atrás), `account_setup_test`, `onboarding_flow_test`, `session_expiry_test` | ✓ |
| Persistencia | `welcome_tour_test` (reanudación), `first_plan_generation_test` (operación guardada, dos usuarios) | ✓ |
| Generación asíncrona | `first_plan_generation_test` 13 | ✓ |
| Errores | 422, 5xx, conexión, `FAILED`, `NO_FACTIBLE`, `TIEMPO_EXCEDIDO` | ✓ |
| Fechas del dashboard | `plan_week_label_test` 10 | ✓ |
| Perfil | `profile_contract_v55_test` 2, `backend_alignment_test` | ✓ |

## No ejecutado

- Android en dispositivo o emulador (PRUEBAS_ANDROID.md).
- iOS (sin macOS).
- TalkBack/VoiceOver reales.
- El CI nuevo todavía no se ejecutó en GitHub: solo correrá en las PR cuando el workflow llegue a
  `generation`. Sus pasos son los mismos que se ejecutaron aquí.
