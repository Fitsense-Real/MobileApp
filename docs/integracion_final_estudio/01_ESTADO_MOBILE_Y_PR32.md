# 01 · Estado de Mobile y cierre de la PR #32

> **Revisión del 28/11/2026 (orden de merge):** ver [10](10_REVISION_FINAL_Y_BACKEND_96.md). El registro exige ahora
> los **tres** documentos publicados y Mobile usa los códigos estables de Backend #96. Backend #96 se fusionó
> (`434a9dc`) y después se fusionaron #33 (`ed11b5a`) y #34 (`9e9ebbc`).

| | |
|---|---|
| Orden | Integración definitiva con el Backend, opción A y preparación de QA Android |
| Fecha | 28/11/2026 |
| `generation` al empezar | `f8f5e244dea62daa3963dc9a8a0b1a96445c4d3b` (merge de la #25) |
| `generation` ahora | **`1cd9f97b4566de90ddcede2c46ff4da5714edebe`** (merge de la #32) |
| `main` | `3a4e26d1fed5170c6790cd05c9129f58ce88b4d0` antes y después: **sin cambios** |
| Backend integrado | `Fitsense-Real/Backend` `generation` **`41c498ab6220119cfb6b59fe07ba5c5c6112a64e`** |
| Herramientas | Flutter 3.50.1 / Dart 3.14.0 (las de CI) |

## 1. Verificación inicial

| Comprobación | Resultado |
|---|---|
| `generation` | En `f8f5e24`, sin commits posteriores de nadie |
| PR #25–#31 | Fusionadas e intactas en `generation` (el árbol de la #31 se conserva) |
| PR abiertas de Mobile | Solo la #32; ningún cambio pendiente de otros desarrolladores |
| PR #89–#95 del Backend | **Las siete integradas** en `41c498a` (comprobado por ascendencia de cada cabeza) |
| Contrato de #91 en `41c498a` | `SignUpResource.acceptedStudyConsentVersion` (máx. 20), `GET /api/v1/legal-documents` público, `ConsentimientoService` con mensajes 422 y evidencias (`CASILLA_REGISTRO`, `CASILLA_SIN_VERSION_CONFIRMADA`, `CASILLA_SIN_DOCUMENTO_APROBADO`, `CONSTANCIA_DE_LECTURA`), política A por omisión (`fitsense.study.plans-require-participation=true`) |
| Otros contratos nuevos | B1: límites de inicio de sesión y registro por IP y por cuenta (429 con `Retry-After`). B3/B5: 409 `PLAN_CAMBIADO_DURANTE_LA_GENERACION` y 429 por generaciones por usuario |
| `--dart-define` existentes | `API_BASE_URL`, `ALLOW_INSECURE_API`, `PASSWORD_RECOVERY_ENABLED`, `ACCOUNT_DELETION_*`, `TERMS_URL`, `PRIVACY_POLICY_URL`, `STUDY_CONTACT`, `PAIN_SAFETY_MESSAGE`, `SHOW_DROPOUT_RISK`, `DEFAULT_TIMEZONE`, `EXERCISE_MEDIA_LEGACY_SOURCE` y las versiones de documentos y la opción B (estas últimas se quitan en Mobile-C1, ver [03](03_DOCUMENTOS_Y_CONSENTIMIENTOS.md)) |
| Servicios de producción | Ninguno: Backend local con base aislada, IA apagada, correo `dev-log`, push apagado, documentos sintéticos y cuentas `@audit.local` |

## 2. M0 · PR #32

| Comprobación previa | Resultado |
|---|---|
| Estado | Abierta, base `generation` en `f8f5e24`, `mergeable_state = clean` |
| CI del último commit `772c5d8` | `verify` ✓ |
| Diff | 32 archivos, todos bajo `docs/` (documentación, matrices, capturas y evidencia) |
| Secretos o datos personales reales | Ninguno (revisado en la orden anterior y de nuevo aquí) |
| Código funcional | No modificado |

**Fusionada** el 28/11/2026 a las 01:59:06 UTC con un commit de merge: **`1cd9f97b4566de90ddcede2c46ff4da5714edebe`**.
CI de `generation` en `1cd9f97`: [`verify` ✓](https://github.com/Fitsense-Real/MobileApp/actions/runs/46095789950). `main` sin cambios.

La fusión es documental: **no autoriza a distribuir Kora**.

## 3. PR nuevas de esta orden (abiertas, sin fusionar)

| PR | Rama | Contenido | CI |
|---|---|---|---|
| [#33](https://github.com/Fitsense-Real/MobileApp/pull/33) Mobile-C1 | `claude/mobile-c1-opcion-a-consentimientos` | Opción A y contrato de consentimientos ([02](02_REGISTRO_OPCION_A.md), [03](03_DOCUMENTOS_Y_CONSENTIMIENTOS.md)) | `verify` ✓ |
| [#34](https://github.com/Fitsense-Real/MobileApp/pull/34) Mobile-C3 | `claude/mobile-c3-cierre-sesion-i01` | Incidencia I-01 ([07](07_INCIDENCIA_I01.md)) | ver la PR |
| Mobile-C4 (esta) | `claude/mobile-c4-integracion-qa-android` | Esta documentación, la evidencia, la matriz de QA y los scripts | ver la PR |

**No se abrió Mobile-C2** (recuperación): contra el Backend `41c498a` la recuperación funciona sin diferencias en Mobile
([05](05_RECUPERACION_CUENTA.md)).

C1 y C3 no comparten archivos y pueden revisarse en cualquier orden. C4 solo añade documentación; describe C1 y C3 tal
como están en sus PR.
