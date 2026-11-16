# Estado de las PR del Mobile (validación final, 16/11/2026)

Sustituye a `ESTADO_PR_Y_ORDEN_MERGE.md` (ORDEN 2) en lo que respecta al Mobile. **Nada se fusionó ni
se desplegó.**

## Ramas y PR

| PR | Rama → base | Head | Conflictos | Contenido |
|---|---|---|---|---|
| — | `generation` (Mobile) | `4291c6b` | — | rama principal actual |
| Fitsense-Real/MobileApp#1 | `claude/kora-mascot` → `generation` | `400ee39` | ninguno; al día con `generation` | Kapi (6 expresiones), `KoraMascot`, diseño |
| Fitsense-Real/MobileApp#2 | `claude/welcome-tour` → `claude/kora-mascot` | `f26c7ce` | ninguno; contiene #1 | Tour de 10 pasos, generación en segundo plano, informes de la ORDEN 2 |
| Fitsense-Real/MobileApp#3 (esta validación) | `claude/mobile-final-validation` → `claude/welcome-tour` | ver la PR | ninguno; contiene #1 y #2 | «8 DÍAS», pruebas de contrato #72 y del perfil V55, CI, guía APK, informes |

Backend, solo para comprobar contratos:

| PR | Rama → base | Head | Contrato con Flutter |
|---|---|---|---|
| Fitsense-Real/Backend#71 | `claude/async-first-plan-generation` → `generation` | `12a01c6` | define `POST/GET /users/me/plan/generation` |
| Fitsense-Real/Backend#72 (borrador) | `fix/async-generacion-resiliente` → #71 | `93549d5` | **sin cambios REST** (COMPATIBILIDAD_BACKEND_71_72.md) |

## Cambios pendientes

Ninguno en #1 y #2: los defectos de esta validación no estaban en su código. «8 DÍAS» es código
anterior del dashboard en `generation`, y el resto son pruebas, CI y documentación. Todo va en la PR
nueva, pequeña y apilada sobre #2 para que se integre sin conflictos en el orden previsto.

## Orden de integración

1. Backend #71 y después #72, cuando estén validados y autorizados.
2. MobileApp #1.
3. MobileApp #2. Si al fusionar #1 se borra su rama, GitHub cambia la base a `generation`; si no, hay
   que cambiarla a mano.
4. Fitsense-Real/MobileApp#3, de esta validación (misma nota sobre la base).

La app con #2 necesita el backend con #71 desplegado: sin él, `POST /users/me/plan/generation`
responde 404.

## Pruebas existentes

- 142 pruebas Flutter (REGRESION_FLUTTER.md).
- E2E en web con el backend real: ORDEN 2 sobre #71 y esta ronda sobre #71 + #72 (PRUEBAS_INTEGRALES.md).
- CI: MobileApp no tenía. La PR nueva añade `.github/workflows/ci.yml` (análisis, pruebas, web y APK
  debug); empezará a ejecutarse en las PR cuando llegue a `generation`.
