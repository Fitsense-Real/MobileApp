# Configuración del backend por entorno (PR B)

## Problema

`ApiConstants.baseUrl` usaba `http://10.0.2.2:8080/api/v1` en Android (y `http://localhost:8080` en
web) **también en release** si no se pasaba `API_BASE_URL`. Una versión de Play compilada sin esa
variable habría intentado conectarse al emulador.

## Entornos

| Entorno | Modo | Dirección | HTTP sin cifrar |
|---|---|---|---|
| Desarrollo | debug / profile | `--dart-define=API_BASE_URL=...` o, si falta, `10.0.2.2:8080` (emulador) / `localhost:8080` | sí (`usesCleartextTraffic` solo en el manifiesto de debug) |
| Evaluación | release | `API_BASE_URL` HTTPS del backend de evaluación | no |
| Producción (Play) | release, AAB | `API_BASE_URL` HTTPS pública | no |

`lib/core/api/api_config.dart` (`ApiConfig.resolve`, función pura) decide la URL:

- **release sin `API_BASE_URL`**: URL vacía y la app muestra «Kora no está configurada»
  (`ConfigErrorApp`). No hay ninguna caída a `localhost` ni a `10.0.2.2`, y no se hace ninguna petición;
- **release con `http://`**: se rechaza;
- **release con host local**: se rechazan `localhost`, `127.x`, `10.x` (incluido `10.0.2.2`),
  `192.168.x`, `172.16–31.x`, `169.254.x` y `*.local`, aunque usen HTTPS;
- `ALLOW_INSECURE_API=true` levanta la regla de HTTPS **solo en Dart**, para compilaciones de
  evaluación local (web contra un backend local). Gradle nunca la acepta en Android.

## Bloqueo en la compilación Android

`android/app/build.gradle.kts` lee los `--dart-define` que Flutter pasa a Gradle y **detiene**
`assembleRelease` y `bundleRelease` si `API_BASE_URL` falta, no es HTTPS, es local, privada o del
emulador, o usa un dominio reservado de prueba (`.invalid`, `.test`, `.example`). Este último solo se
admite con `-Pkora.testBackendUrl=true`, para verificar el empaquetado.

Comprobado con compilaciones reales:

| Caso | Resultado |
|---|---|
| `flutter build apk --release` (sin URL) | **bloqueado**: «Falta --dart-define=API_BASE_URL=https://...» |
| `API_BASE_URL=http://10.0.2.2:8080/api/v1` | **bloqueado**: debe usar https |
| `API_BASE_URL=http://api.kora.invalid/api/v1` | **bloqueado**: debe usar https |
| `API_BASE_URL=https://192.168.1.20:8080/api/v1` | **bloqueado**: dirección local |
| `API_BASE_URL=https://api.kora.invalid/api/v1` | **bloqueado**: dominio reservado de prueba |
| ídem con `-Pkora.testBackendUrl=true` | compila un APK de evaluación (firmado con debug, no para Play) |

No se inventó ninguna URL de producción: la orden prohíbe suponer un dominio de Railway.

## Compilar para Play cuando exista la URL

```bash
flutter build appbundle --release --dart-define=API_BASE_URL=https://<dominio-real>/api/v1
```

## Otras comprobaciones del cliente

| Aspecto | Estado |
|---|---|
| Timeouts | conexión, envío y recepción de 20 s (Dio) |
| Errores de conexión | la app distingue «sin conexión» de «servidor no disponible» (5xx) y sigue consultando (generación) |
| Backend caído | la generación sigue en el servidor; la app muestra «Seguimos intentando» (probado en el E2E con el backend detenido) |
| Certificados HTTPS | almacén del sistema; no hay `badCertificateCallback` ni se aceptan certificados inválidos |
| JWT | se guarda en `FlutterSecureStorage` y se envía como `Bearer` |
| Renovación | el backend emite JWT de 7 días sin token de refresco. Ante un 401, la app cierra la sesión, lleva al login y avisa (`AuthInterceptor`). No hay renovación silenciosa porque el backend no la ofrece |
| Logs | sin `LogInterceptor`. El `ProviderObserver` que imprimía errores con su traza (`debugPrint` también escribe en release) **ahora solo se registra en debug** (`main.dart`). Los avisos de recordatorios no incluyen datos personales |
| Credenciales incrustadas | ninguna: la URL es la única configuración |

## Compilación web de evaluación local

La web en release contra un backend local por HTTP necesita la opción explícita:

```bash
flutter build web --release --dart-define=API_BASE_URL=http://localhost:8080/api/v1 --dart-define=ALLOW_INSECURE_API=true
```

## Lo que falta

La URL HTTPS del backend desplegado (Railway u otro). Sin ella no se puede compilar el AAB publicable.
