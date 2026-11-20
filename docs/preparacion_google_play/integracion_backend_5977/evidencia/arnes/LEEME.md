# Arnés E2E (Playwright + psql)

Ningún archivo lleva contraseñas ni secretos. Se leen del entorno:

| Variable | Para qué |
|---|---|
| `E2E_PASSWORD` | Contraseña de las cuentas sintéticas `*@e2e.local` (la eliges tú) |
| `E2E_NEW_PASSWORD` | Contraseña nueva en la prueba de recuperación |
| `E2E_DB_PASSWORD` | Clave de la PostgreSQL local desechable (`run-backend.sh`) |
| `E2E_JWT_SECRET` | Secreto JWT solo local, de 32 caracteres o más (`run-backend.sh`) |
| `PGPASSWORD` | Lo usan `psql` y `db.js` |
| `E2E_DB` | Nombre de la base de pruebas |

Las contraseñas incorrectas de las pruebas (`incorrecta-N`) no pertenecen a ninguna cuenta.

**Nunca** apuntes el arnés a una base o un backend con datos reales.
