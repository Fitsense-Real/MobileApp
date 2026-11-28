# Arnés de la integración final (Backend 41c498a local)

Backend local con base nueva aislada, IA y push apagados, correo `dev-log`, exigencia de consentimientos **forzada solo
aquí** y documentos **sintéticos** servidos por HTTPS local. Solo cuentas `@audit.local`. Las contraseñas y la clave
JWT se leen de variables de entorno; ningún archivo contiene credenciales.

| Archivo | Uso |
|---|---|
| `backend_41c.sh` | Arranca el Backend: `BACKEND_DIR=<clon en 41c498a> JWT_SECRET_LOCAL=<clave de pruebas> backend_41c.sh [T-QA-1\|T-QA-2] [si\|no]` |
| `servidor_https.py` | Sirve `../documentos_sinteticos/` en `https://localhost:8443` (necesita `cert.pem`/`key.pem` propios en la carpeta superior de `www`; ver el script) |
| `cuentas_c1.py` | Crea, por la API, una cuenta sin participación, una retirada y otra para el límite 429 |
| `cuenta_con_plan.py` | Una cuenta participante con el primer plan del motor de reglas |
| `escenarios_c1.js` | Recorridos de la app real (Playwright, compilación web) |
| `recuperacion_api.py` | Comprobaciones de recuperación por la API (lee el código del log local; nunca lo imprime) |

La prueba de contrato en Dart es `test/live/consentimientos_live_test.dart` (PR #33).
