# Arnés E2E (ORDEN 2)

Reproduce la validación de extremo a extremo **sin Replicate ni datos reales**:
backend real (rama `claude/async-first-plan-generation`) sobre una PostgreSQL 16
local vacía, IA apagada (motor de reglas real), y la app Flutter compilada para
web, manejada con Playwright a través del árbol de semántica de Flutter.

## Piezas

| Archivo | Qué es |
|---|---|
| `EscenariosE2E.java` | Solo para E2E local, **no se versiona en el backend**. Bean `@Primary` que envuelve el pipeline real y, según el correo del participante, simula una IA lenta o caída: `+d30`/`+d90`/`+d240`/`+d400` (espera N s y luego ejecuta el pipeline real), `+fallo1` (falla la 1.ª vez), `+nofactible`. |
| `run-backend.sh` | Arranca el backend contra `fitsense_e2e` (local), IA apagada, CORS para `localhost:5050`, latido 5 s, huérfana a los 30 s y tiempo máximo de 300 s (acortados para poder probar reinicios y tiempo máximo). |
| `kora.js`, `lib.js` | Utilidades: abrir la app, activar la semántica, tocar/llenar por etiqueta, recorrer el tour. |
| `db.js` | Lee el estado real de la operación y cuenta planes en la base (solo lectura). |
| `register.js`, `profile.js`, `p1.json` | Registro, login y los 5 pasos del perfil en la app real. |
| `e2e-main.js` | Recorrido principal: perfil → generar → tour durante la generación → resultado → plan → rutinas. |
| `casos-cortos.js` | Casos 1, 6/7, 8, 9, 10, 11, 12, 15. |
| `caso-largo.js` | Casos 5 (4 min) y 14 (tiempo máximo). |
| `c13.js` | Caso 13: reinicio del backend con `SENAL=TERM` (despliegue) o `SENAL=KILL` (caída). |
| `a11y.js`, `final.js` | Repaso del tour a 320 px, horizontal y con movimiento reducido avanzando con teclado; regresión final. |

## Cómo se ejecutó

```bash
createdb fitsense_e2e
mvn -q package -Dmaven.test.skip=true            # en el backend
mkdir -p $E2E_DIR/app && (cd $E2E_DIR/app && unzip -q /ruta/backend/target/fitsense-backend-0.0.1-SNAPSHOT.jar)
javac -d $E2E_DIR/harness/classes -cp "$E2E_DIR/app/BOOT-INF/classes:$E2E_DIR/app/BOOT-INF/lib/*" EscenariosE2E.java
E2E_DIR=... ./run-backend.sh
flutter build web --release --no-web-resources-cdn --dart-define=API_BASE_URL=http://localhost:8080/api/v1 --dart-define=ALLOW_INSECURE_API=true  # desde la PR B, release exige HTTPS salvo esta opción
(cd build/web && python3 -m http.server 5050)
node e2e-main.js
```

Ninguna respuesta del backend se simula en Flutter: todas las llamadas van al
backend real; lo único simulado es la duración o el fallo de la IA, del lado
del servidor.

## Ronda con el backend #71 + #72 (16/11/2026)

`run-backend-71-72.sh` arranca el head de Fitsense-Real/Backend#72 (`93549d5`, V59) contra
`fitsense_e2e72` con lease de 15 s, latido de 5 s, tiempo máximo de 300 s y 4 generaciones en
paralelo. Los scripts leen la base de `E2E_DB` (por defecto `fitsense_e2e`).

- `main72.js`: flujo principal hasta abrir una sesión generada;
- `sesion.js`: abre una sesión desde Rutinas;
- `casos-cortos.js cEspera`: cerrar Flutter durante la espera.
