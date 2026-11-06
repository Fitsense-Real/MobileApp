# Backend local

La app usa `http://10.0.2.2:8080/api/v1` en el emulador Android y
`http://localhost:8080/api/v1` en web/escritorio. En Android debug se permite
HTTP local; no se cambió la política de tráfico de la versión release.
Un teléfono físico requiere la IP LAN del equipo y el servidor accesible
en esa red:

```powershell
.\tmp\flutter-sdk\bin\flutter.bat run --dart-define=API_BASE_URL=http://IP_DEL_PC:8080/api/v1
```

En web, el backend debe permitir el origen del navegador mediante CORS.

## Contratos verificados con OpenAPI local

- `POST /auth/register`: nombres, apellidos, email, contraseña, zona horaria IANA
  y consentimiento explícito. Devuelve usuario, sin token; luego se solicita login.
- `POST /auth/login`: email y contraseña. Devuelve JWT plano y userId.
- JWT guardado con FlutterSecureStorage. El interceptor añade `Authorization:
  Bearer ...` a las siguientes llamadas. No se registran contraseñas, JWT ni
  datos de salud en logs HTTP.
- `GET /users/me`: recupera nombres completos del usuario autenticado.
- `GET /users/me/profile`: 404 conduce al formulario inicial. Otros errores no
  se interpretan como ausencia de perfil.
- `POST /users/me/profile`: crea perfil; `PUT` actualiza uno existente.
- `GET /catalog/equipment-types`: alimenta el selector con code, nameEs y
  requiresGym. El selector tiene búsqueda y confirmación, filtra gimnasio en
  HOME y admite peso corporal sin selección.

## Perfil

Cinco pasos: objetivo; perfil físico; semana y duración; equipamiento;
permisos de movimiento. El cumpleaños se elige con un calendario en español
que no permite hoy ni fechas futuras. `daysPerWeek` se calcula con los días
marcados; no hay un desplegable adicional de sesiones. Se valida fecha real anterior a hoy,
estatura 120–250, pesos 30–300, duración entera 15–180, 1–7 sesiones y
suficientes días distintos (lunes=1, domingo=7). No se inventa una edad mínima.
Objetivo obligatorio y notas opcionales: máximo 500 caracteres.
Los cinco permisos se envían como booleanos: false excluye el movimiento.
Las notas no sustituyen a los permisos. Los blockedExerciseIds existentes
se preservan al editar; en creación se envía una lista vacía. La selección
visual de ejercicios bloqueados queda fuera de esta integración inicial.

El consentimiento al estudio está desmarcado inicialmente; nunca se deduce
de pulsar el botón de registro. La zona horaria inicial es America/Lima y
puede editarse.

Tras guardar el perfil se consulta el plan actual y, si no existe, se llama
`POST /users/me/plan/generate` sin cuerpo, con Bearer JWT y hasta cinco minutos
de espera. La animación continúa hasta recibir la respuesta. Los errores
permiten reintentar conservando el perfil guardado. Se consulta el plan actual
en los reintentos y ante un 409 para reconciliar una creación anterior.
El inicio muestra el plan devuelto, incluso si corresponde a la semana próxima.
El inicio y Rutinas muestran los entrenamientos y ejercicios del plan del servidor.
Las métricas e intervenciones se consultan con GET /users/me/metrics/weekly y
GET /users/me/interventions, ordenadas desde la semana o ajuste más reciente.
Cada sección tiene estados de carga, error y vacío; los valores ausentes no se
presentan como cero. Se pueden actualizar deslizando hacia abajo o con Actualizar.
El plan se vuelve a consultar al regresar de una rutina; si es de la semana
próxima y current no lo devuelve, se recarga por su ID, sin conservar estados viejos.

La rutina permite recuperar la sesión actual, iniciar, guardar resultados por
ejercicio (PUT que reemplaza el resultado anterior), finalizar con esfuerzo
obligatorio, abandonar y omitir indicando la causa. El botón de ciclo semanal
en Progreso pide confirmación antes de POST /cycle/run-for-me y recarga los datos.
El registro retrospectivo por /report permite introducir resultados por ejercicio,
fecha/hora y esfuerzo, incluso para entrenamientos vencidos. Cada ejercicio ofrece
completado (cantidades prescritas), parcial (cantidades reales y motivo) o no
realizado (cantidades cero y motivo). Los GIF se resuelven desde gifPath y se
cargan sin JWT desde el repositorio público. Las rutinas se agrupan por fecha.
La navegación por versiones históricas de planes todavía no tiene interfaz.
Las métricas se muestran con su fecha de
cálculo; no se inventan cálculos nuevos después de una sesión.

La documentación del backend actual no incluye recuperación de contraseña;
las pantallas anteriores siguen dependiendo de esos endpoints pendientes.

## Prueba de servidor

Se creó la cuenta sintética `kora.test.1793199312@example.com` (userId 28), sin
participación en el estudio. Se verificaron registro, login, JWT, /users/me,
catálogo (31 equipos), POST/GET/PUT del perfil y rechazo sin token. El perfil
de prueba se dejó en el servidor; no se guardaron contraseña ni JWT en archivos.

Pruebas del cliente:

```powershell
.\tmp\flutter-sdk\bin\flutter.bat test --no-pub test/backend_contract_test.dart test/onboarding_flow_test.dart
.\tmp\flutter-sdk\bin\flutter.bat test --no-pub --concurrency=1 test/dashboard_live_test.dart test/account_setup_test.dart
```
