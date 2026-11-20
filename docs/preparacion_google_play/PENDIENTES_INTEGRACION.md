# Pendientes tras la integración con el backend 5977d28

## Para fusionar Mobile

1. Revisar y aprobar #1 → #8 (`ESTADO_PR_MOBILE.md`). #7 lleva su commit correctivo y #8 es la PR de
   integración.
2. CI `verify` en verde en #8.
3. Fusionar en orden, cambiando la base de cada PR a `generation` tras fusionar la anterior. **No se hizo
   ningún merge.**

## Para desplegar el backend (Railway u otro). No se desplegó nada

1. URL HTTPS pública del backend 5977d28 (o posterior), con PostgreSQL gestionada y V1–V63.
2. Proveedor de correo real para la recuperación (`delivery=email`): dominio remitente, SPF/DKIM y prueba
   con una cuenta del equipo. Hasta entonces, compilar la app sin `PASSWORD_RECOVERY_ENABLED`.
3. CORS de producción: no lo necesita la app Android. Si hubiera cliente web, exponer `Retry-After`
   (B-1).
4. Logs: siguen incluyendo correos (S-1). Por orden expresa no se tocaron. **No son aptos para
   producción ni para participantes reales** hasta que el backend los corrija.
5. Ciclo semanal programado. El manual (`run-for-me`) debe seguir apagado en producción.

## Para Google Play

| # | Bloqueante | Estado tras esta orden |
|---|---|---|
| 1 | URL HTTPS del backend desplegado | pendiente (despliegue) |
| 2 | `DELETE /users/me` en servicio | **resuelto en el backend 5977d28 e integrado y probado en la app** (200, 202, 403, 429, PostgreSQL limpio). Falta desplegarlo |
| 3 | Política de datos del estudio al eliminar | el backend borra todo lo de la cuenta y guarda un registro anónimo. Falta que el propietario y el comité de ética la aprueben y que la política de privacidad lo diga |
| 4 | Página web pública de eliminación | el backend ya tiene `/api/v1/account-deletion/*`; falta la página y su URL (`ACCOUNT_DELETION_WEB_URL`) |
| 5 | Política de privacidad publicada | pendiente (`PRIVACY_POLICY_URL`) |
| 6 | Identificador aprobado | pendiente (`pe.fitsense.kora` propuesto; no se cambió) |
| 7 | Clave de subida propia | pendiente (no se creó ninguna) |
| 8 | Prueba en Android 13–16 reales | pendiente. Hay APK debug arm64 listo para `adb reverse` |
| 9 | Textos y versiones de condiciones y privacidad | pendiente. La app ya los muestra y registra cuando el backend publica versiones. No se activó la exigencia |
| 10 | Endpoint público de versiones de consentimiento | backend (B-4), solo si se quiere exigirlos en el registro |

Fuera del código, Play Console sigue pidiendo:

- declaración de apps de salud con investigación (aprobación del comité de ética);
- seguridad de los datos y público 18+ (la app ya valida 18 años);
- cuenta de prueba para el revisor;
- ficha;
- prueba cerrada de 12 testers durante 14 días.

## Decisiones de producto abiertas

- **B-5**: ¿se permite «Ya lo hice» para un entrenamiento de una fecha futura? Hoy lo permiten el backend y
  la app.
- **Cambiar la contraseña con sesión iniciada**: no existe ni en el backend ni en la app. Solo por
  recuperación.

## Sin cambios, por orden expresa

E002, Replicate, H2, P-03, validadores V24 y V8C, catálogo, fórmula de adherencia, progresión,
reincorporación, logs del backend, rama `generation` del backend, Railway, Google Play, identificador y
claves de firma.
