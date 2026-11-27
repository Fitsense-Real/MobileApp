# 07 · Integración con el Backend

Backend `Fitsense-Real/Backend` `generation` `77b9df3`, **solo lectura**. Sin cambios desde la auditoría (comprobado el
27/11/2026 con `git fetch` y la lista de ramas remotas). No se modificó el Backend desde Mobile.

## 1. Entorno usado

Backend compilado (`mvn -DskipTests package`) y ejecutado en este contenedor con: base PostgreSQL nueva
`kora_audit_mobile`, perfil `local-dev`, `--fitsense.ai.enabled=false` (motor de reglas, **sin Replicate**), sin
proveedor de correo (entrega `dev-log` solo en el log local), `--fitsense.cycle.manual-run.enabled=false`, CORS solo para
`localhost:5050`, y el proxy HTTP de Java apuntando a un puerto cerrado (sin salida a Internet). **Solo cuentas
sintéticas `@audit.local`. No se usó `main`, producción ni el usuario 48.**

## 2. Contratos que usa cada PR

| PR | Endpoint / campo | Disponible | Verificado contra el servidor local |
|---|---|---|---|
| M1 | `POST /auth/register` con `acceptsStudyParticipation`, `timezone` | Sí | Sí (auditoría y hoy en la app: registro sin participar → login → pantalla sin rutina) |
| M1 | `acceptedTermsVersion`, `acceptedPrivacyVersion` | Sí | Rechazo 422 sin versión aprobada (auditoría). **Aceptación con versión vigente: no verificable** (no hay versión configurada) |
| M1 | `acceptedStudyConsentVersion` | **No existe** | No se envía |
| M1 | Texto/dirección de documentos por versión | **No existe** | — |
| M1 | `GET /users/me` (`studyParticipant`, `withdrawnAt`) para la elegibilidad | Sí | Sí |
| M2 | `POST /auth/password-reset/request` / `confirm` | Sí | Sí, también de punta a punta en la app (dev-log) |
| M3 | `effortGuidance` del plan; `bodyPart`, `equipment`, `targetMuscle`, `secondaryMuscles`; `GET /catalog/equipment-types` (`nameEs`) | Sí | Sí (plan generado por el motor de reglas) |
| M3 | `gifUrl`, `imageUrl` autorizadas | **No existe** (propuesta del Backend) | Probado con simulador |
| M4 | `PUT /sessions/{s}/exercises/{pe}`, `finish`, `report`, `skip` | Sí, sin cambios | 3 pruebas en vivo de D-M1 sobre el código integrado ✓ |
| M4 | Dolor en un ejercicio completado | **No existe** | Interfaz que no envía nada |
| M4 | Observaciones de sesión | **No existe** | — |
| M5 | `GET /users/me/metrics/weekly`, `/plan/limitations`, `/users/me/withdraw` | Sí | Sí |
| — | `PUT/DELETE /users/me/push-devices` | Sí | `push_backend_live_test` en vivo ✓ |

## 3. Simuladores fieles al contrato

`test/support/fake_backend.dart` (`ScriptedBackend`) responde con los cuerpos, estados y mensajes del Backend real
(copiados de `contratos-backend-local.txt`: `ApiErrorResource`, `UserResource`, 422 «no es la vigente», 422 «no hay una
version aprobada», 202/204/400/429 de recuperación). `workout_logging_test.dart` añade un servidor con estado de sesión
(PUT reemplaza el resultado, como el real).

## 4. Dependencias restantes (§12 de la orden)

| Mobile | Dependencia | Estado del Backend | Qué falta verificar contra el servidor real |
|---|---|---|---|
| M-01 | Política de participación | Solo participantes | Si se elige B: generación para no participantes |
| M-02 / M-03 | Documentos versionados y registro exigido | Versiones vacías; sin texto servido; `enforce-on-signup=false` | Registro con versiones vigentes y con la exigencia encendida |
| M-04 | Proveedor de correo real | `delivery=none`, `transport=none` | Recepción real del código y su caducidad |
| M-06 | Licencia y alojamiento de medios | Sin decisión | Direcciones autorizadas `gifUrl`/`imageUrl` |
| M-09 | Campos de imagen y respaldo | `imagePath` existe | Ídem M-06 |
| M-12 | Contrato de dolor para casos nuevos | No existe | «Completado con molestias» |
| M-16 | Política de recordatorios | Sin decisión | — |
| M-17 | Política de retirada | Comportamiento verificado (422 tras retirarse) | — |
| M-25 | Cambios permitidos del perfil | 422 tras el primer plan | Según decisión |
| M-26 | Eliminación y correo | Correo apagado | Vía web con correo |
| M-29 | Verificación de correo | No existe | Si se autoriza |
| M-37 | Contenido de mensajes | Sin tildes en varios textos | — |

## 5. Lo que Mobile no hace (a propósito)

No calcula adherencia, no decide seguridad, no reactiva ejercicios, no deduce equivalencias, no acepta documentos sin
versión publicada y no genera planes con IA. Ninguna solución local contradice la seguridad del Backend: la
elegibilidad de M-01 solo evita un recorrido sin salida; la decisión sigue siendo del servidor.
