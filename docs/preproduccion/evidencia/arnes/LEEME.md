# Arnés de la auditoría de preproducción (solo lectura del código; datos sintéticos)

Scripts usados el 27/11/2026 para comprobar Mobile contra un Backend **local**. Ningún archivo contiene contraseñas:
se leen de `AUDIT_PASSWORD`.

| Archivo | Qué hace |
|---|---|
| `contratos.py` | Registro con y sin participación, zona horaria escrita a mano, generación, contenido del plan, sesión completa/parcial/no realizada, omisión, métricas, recuperación, retirada y endpoints inexistentes |
| `recuperacion.py` | Recuperación de contraseña de punta a punta con la entrega `dev-log` (el código se lee del log local, nunca se imprime) |
| `cuentas_vivo.py` | Crea dos cuentas sintéticas (una con plan del motor de reglas) para `test/live/` |
| `visual.js` + `perfil.json` | Capturas de la app real (Flutter web release) con Playwright, 390 × 844 y 320 × 568 |

## Condiciones obligatorias

- Backend `Fitsense-Real/Backend` rama `generation` (`77b9df3`), compilado con `mvn -DskipTests package`.
- PostgreSQL local con una base **nueva y vacía** (`kora_audit_mobile`). Nunca una base con datos reales ni el usuario 48.
- Perfil `local-dev`, `--fitsense.ai.enabled=false`, sin `REPLICATE_API_TOKEN`, sin proveedor de correo y con el proxy
  HTTP de Java apuntando a un puerto cerrado: el Backend no puede salir a Internet.
- `--fitsense.cycle.manual-run.enabled=false`.
- Para las capturas: `flutter build web --release --dart-define=API_BASE_URL=http://localhost:8080/api/v1
  --dart-define=ALLOW_INSECURE_API=true --dart-define=PASSWORD_RECOVERY_ENABLED=true`, servido en `localhost:5050`, y el
  Backend con `--fitsense.cors.allowed-origins=http://localhost:5050`.

```bash
AUDIT_PASSWORD=... python3 -I contratos.py http://localhost:8080/api/v1 <backend.log> contratos-salida.txt
```

```bash
AUDIT_PASSWORD=... ACCOUNT_PLAN=<correo sintético con plan> WEB_DIR=<build/web> SHOTS=<carpeta> node visual.js registro
```

Las capturas web **no sustituyen** la prueba en un teléfono Android: no cubren push, recordatorios nativos,
almacenamiento seguro del sistema ni el cierre de la app por Android.
