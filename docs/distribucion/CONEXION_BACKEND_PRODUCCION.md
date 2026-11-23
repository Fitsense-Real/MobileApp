# Conectar Kora al backend de producción: recomendaciones

**El Mobile está listo.** Lo único que falta para que funcione fuera de una PC de desarrollo es un backend HTTPS
desplegado. No se desplegó nada, por orden expresa. Este documento recoge lo necesario y el orden recomendado.

## 1. Lo que el backend necesita antes de conectar la app

| # | Requisito | Por qué | Referencia |
|---|---|---|---|
| 1 | **Dominio con HTTPS** y certificado válido (por ejemplo `api.kora.pe`), con la API en `/api/v1` | El guardián de release rechaza `http://`, IP privadas, `localhost` y dominios de prueba. Android no confía en certificados autofirmados | `CONFIGURACION_BACKEND_HTTPS.md` |
| 2 | **Backend `5977d28` o posterior compatible** con PostgreSQL gestionada y migraciones V1–V63 | La app se integró y auditó contra esos contratos | `CONTRATOS_BACKEND_ACTUALIZADOS.md` |
| 3 | **`JWT_SECRET` nuevo y aleatorio**, en el gestor de secretos | Los arneses históricos llevaban secretos locales: **ninguno debe reutilizarse** | `PENDIENTES_INTEGRACION.md` |
| 4 | **Logs sin correos (S-1)** | Hoy los logs incluyen correos: **no apto para participantes reales** hasta corregirlo | Hallazgo S-1 |
| 5 | **Límite de intentos en `/auth/login` (B-6)**, en el backend o en el proxy | Fuerza bruta de contraseñas | Hallazgo B-6 |
| 6 | **Ciclo semanal programado** (lunes, `America/Lima`) y `run-for-me` **apagado** | Sin el ciclo no se crea el plan de la semana siguiente. Si un usuario se queda sin plan vigente, la app pide uno (observación O-1 de la auditoría) | `fitsense.cycle.*` |
| 7 | **Generación asíncrona**: *worker*, latido y tiempo máximo configurados | La app espera 30 s y luego muestra el estado pendiente; el backend debe terminar o fallar de forma explícita (`FAILED` o `NO_FACTIBLE`), nunca quedar colgado | `fitsense.plan-generation.*` |
| 8 | **IA (Replicate): decidir** si se activa | Con la IA apagada, el motor de reglas genera planes válidos (auditado). Si se activa: token en el gestor de secretos, presupuesto con alertas y tiempo máximo. El respaldo por reglas sigue disponible | `fitsense.ai.*` |
| 9 | **Correo para recuperar la contraseña** (proveedor, SPF y DKIM), o dejar la recuperación apagada | Sin correo, la app se compila **sin** `PASSWORD_RECOVERY_ENABLED` y no ofrece la opción | `INTEGRACION_RECUPERACION.md` |
| 10 | **Eliminación de cuenta** en servicio (`DELETE /users/me`) y **página web pública** de eliminación | Exigencia de Play. Auditado: borra la cuenta, los planes, las sesiones y las operaciones | `INTEGRACION_ELIMINACION_CUENTA.md` |
| 11 | **Consentimientos**: publicar versiones aprobadas cuando existan los documentos. No activar la exigencia sin documentos aprobados | La app ya los muestra y registra (V63) | `VALIDACION_EDAD_CONSENTIMIENTO.md` |
| 12 | **Copias de seguridad y retención** según el protocolo ético; monitorización (salud, errores 5xx, latencia de generación) | Datos de salud de participantes | — |
| 13 | **CORS**: no hace falta para Android. Solo si hubiera cliente web, exponer también `Retry-After` (B-1) | — | Hallazgo B-1 |

## 2. Cómo se compila la app para ese backend

```
flutter build appbundle --release \
  --dart-define=API_BASE_URL=https://api.TU-DOMINIO/api/v1 \
  --dart-define=ACCOUNT_DELETION_ENABLED=true \
  --dart-define=ACCOUNT_DELETION_WEB_URL=https://TU-DOMINIO/eliminar-cuenta \
  --dart-define=PRIVACY_POLICY_URL=https://TU-DOMINIO/privacidad \
  -Pkora.applicationId=pe.fit.kora
```

- Añade `--dart-define=PASSWORD_RECOVERY_ENABLED=true` solo si el punto 9 está resuelto.
- **Nunca** uses `ALLOW_INSECURE_API` ni `-Pkora.testBackendUrl` para un backend real. El guardián de Gradle bloquea la
  compilación si la URL no es una dirección HTTPS pública.
- Para la beta: `tool/beta/distribuir_beta.sh` (`DISTRIBUCION_BETA.md`) con las mismas variables.

## 3. Entornos recomendados

| Entorno | Backend | App | Quién |
|---|---|---|---|
| Local | `5977d28` en la PC, IA apagada | debug, web o APK por `adb reverse` | Desarrollo y E2E (como en esta auditoría) |
| **Pruebas (*staging*)** | Copia del de producción con **su propia base**, IA apagada o con presupuesto mínimo | Beta por App Distribution | Equipo y evaluadores con cuentas de prueba |
| Producción | Base de participantes | Play (prueba cerrada y producción) | Participantes aprobados |

No mezcles cuentas de prueba con participantes en la base de producción. La cuenta del revisor de Play es la única
cuenta de prueba aceptable allí.

## 4. Prueba de humo tras conectar (en un teléfono, contra *staging*)

Es la misma lista de la auditoría (`docs/auditoria_final/AUDITORIA_FUNCIONAL.md`), pero comprobando con la API y no con
PostgreSQL:

1. Registro, perfil inicial y «Generar mi plan»: 30 s de «Generando» y después el recorrido, o el estado pendiente si
   el backend tarda.
2. Cerrar la app durante los 30 s y abrirla: debe aparecer el recorrido (PR #15).
3. Plan: fechas, ejercicios, series y repeticiones iguales a `GET /users/me/plan/current`.
4. Sesión del día con un completo, un parcial y un no realizado, y finalizar: el % coincide con el que muestra el
   backend.
5. Recordatorio a 10 minutos: llega (PR #14, ícono de notificación).
6. Cerrar sesión, volver a entrar y actualizar el APK encima: la sesión se conserva (PR #13).
7. Eliminar la cuenta: confirmación, y el inicio de sesión con esa cuenta falla.

## 5. Compatibilidad a futuro

- **No hay actualización forzada:** las versiones instaladas no pueden obligarse a actualizar. Los cambios del backend
  deben ser **compatibles hacia atrás** con la última versión distribuida: no quitar campos, no cambiar significados y
  añadir endpoints nuevos en lugar de romper los existentes.
- **Versión mínima:** antes de producción, conviene que el backend exponga una versión mínima de la app y que la app
  avise si está por debajo. Es una mejora pequeña para una PR futura; no se hizo por estar fuera del alcance.
- **Endpoints que usa la app** (contratos `5977d28`):
  - autenticación y recuperación;
  - `/users/me`, perfil y consentimientos;
  - catálogo;
  - plan actual, historial, limitaciones y adaptaciones;
  - generación asíncrona (`/users/me/plan/generation`);
  - entrenamientos (inicio, omisión y reporte);
  - sesiones;
  - métricas;
  - exclusiones por dolor;
  - `DELETE /users/me`.

  Lista completa en `lib/core/api/api_constants.dart`.
