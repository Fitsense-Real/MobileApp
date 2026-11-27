# Arnés del cierre de preproducción

Mismas condiciones que el arnés de la auditoría (`docs/preproduccion/evidencia/arnes/LEEME.md`): Backend `generation`
local con base nueva, perfil `local-dev`, IA apagada, sin correo, sin salida a Internet, solo cuentas `@audit.local`.
La contraseña se lee de `AUDIT_PASSWORD`; ningún archivo contiene credenciales.

| Archivo | Uso |
|---|---|
| `cuentas_vivo.py` | Crea dos cuentas sintéticas (una con plan del motor de reglas, otra sin perfil) |
| `visual_cierre.js` | Capturas «después» con Playwright sobre la compilación web: `registro`, `recuperacion` (lee el código del log local con `BACKEND_LOG`), `rutina`, `pequeno`, `perfil` |
| `perfil.json` | Pasos del perfil inicial |
| `escenarios_posmerge.js` | Escenarios integrales tras el merge final (registro con participación y generación, sesión por «Marcar varios», P1 y reintento, cambio de cuenta, sin conexión): `todo`, `cuenta`, `sinred` |
| `perfil_sin_plan.py` | Tres cuentas con perfil y sin plan para `push_generation_live_test` |

```bash
AUDIT_PASSWORD=... WEB_DIR=<build/web> SHOTS=<carpeta> BACKEND_LOG=<log del backend> ACCOUNT_PLAN=<correo con plan> node visual_cierre.js rutina
```
