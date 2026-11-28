# 04 · Contratos con el Backend `41c498a` (M3)

Backend `Fitsense-Real/Backend` `generation` `41c498ab6220119cfb6b59fe07ba5c5c6112a64e`, compilado y ejecutado en este
entorno:
- **Base y servicios:** PostgreSQL de pruebas aislado (`kora_integracion_final`), perfil `local-dev`, IA apagada
  (`--fitsense.ai.enabled=false`, sin token), push apagado, correo `dev-log` y sin salida a Internet.
- **Consentimientos:** exigencia **forzada solo aquí** y tres documentos sintéticos servidos por HTTPS local con un
  certificado propio.
- **Cuentas:** solo `@audit.local`. El usuario 48 y los datos reales no se tocan.

Arnés reproducible en [`evidencia/arnes/`](evidencia/arnes/) (`backend_41c.sh`, `servidor_https.py`, `cuentas_c1.py`,
`cuenta_con_plan.py`, `escenarios_c1.js`, `recuperacion_api.py`). La prueba de contrato es
`test/live/consentimientos_live_test.dart` (PR #33), que usa los repositorios reales de la app.

## 1. Escenarios obligatorios

| Caso | Escenario | Resultado | Evidencia |
|---|---|---|---|
| I-01 | Consultar documentos publicados | ✓ Tres tipos con sus versiones (`T-QA-1`, `P-QA-1`, `C-QA-1`) y direcciones https; `enforcedOnSignup=true` | [`contrato-en-vivo.txt`](evidencia/contrato-en-vivo.txt) |
| I-02 | No hay documentos publicados | ✓ `{"enforcedOnSignup":false,"documents":[]}` → registro cerrado; ningún POST desde la app | ídem; [`C1-11`](capturas/C1-11-registro-cerrado.jpg) |
| I-03 | Rechazar participar | ✓ «No deseo participar» → «Salir del registro»; **ningún** `POST /auth/register` | [`escenarios-app-c1.txt`](evidencia/escenarios-app-c1.txt) UA1 |
| I-04 | Aceptar con versiones válidas | ✓ 201 con las cuatro versiones leídas; la app entra al perfil | `contrato-en-vivo.txt`, UA2 |
| I-05 | Versión de términos incorrecta | ✓ 422 «La version aceptada de TERMS_OF_SERVICE no es la vigente (T-QA-1).»; login → 401 (sin cuenta) | `contrato-en-vivo.txt` |
| I-06 | Versión de privacidad incorrecta | ✓ 422 (PRIVACY_POLICY); sin cuenta | ídem |
| I-07 | Falta `acceptedStudyConsentVersion` | ✓ 422 «Para participar en el estudio tienes que aceptar la version vigente del consentimiento informado.»; sin cuenta | ídem |
| I-08 | Versión de estudio incorrecta | ✓ 422 (STUDY_PARTICIPATION); sin cuenta | ídem |
| I-09 | Historial coherente | ✓ `user_consents`: STUDY_PARTICIPATION `C-QA-1`, TERMS `T-QA-1` y PRIVACY `P-QA-1`, todas con `CASILLA_REGISTRO`; ninguna pendiente. En la app: Perfil › Cuenta | ídem; [`C1-05`](capturas/C1-05-perfil-documentos.jpg) |
| I-10 | Usuario sin participación | ✓ Solo creable por la API (201, `studyParticipant=false`). Generación → 422 «En este momento no es posible preparar tu rutina…». En la app: pantalla sin rutina, sin peticiones de generación | ídem; [`C1-08`](capturas/C1-08-sin-participacion.jpg) |
| I-11 | Participante activo | ✓ Perfil y primera rutina del motor de reglas (`COMPLETED`) | ídem |
| I-12 | Usuario retirado | ✓ `withdrawnAt` registrado; generación → 422; consentimiento con `withdrawnAt`, no reactivado. En la app: estado de retirada y ninguna generación | ídem; [`C1-09`](capturas/C1-09-retirada.jpg), [`C1-12b`](capturas/C1-12b-retirada-con-plan-inicio-con-aviso.jpg) |
| I-13 | Límite HTTP 429 | ✓ Tras claves incorrectas repetidas: 429 «Demasiados intentos de inicio de sesion… Podrás intentarlo de nuevo en 15 minutos.», sin código interno. En la app web falta el tiempo de espera porque CORS oculta `Retry-After`; en Android sí se lee | ídem; [`C1-10`](capturas/C1-10-limite-429.jpg) |
| I-14 | Conflicto de plan 409 | ✓ **No sobrescribe nada**: dos peticiones simultáneas con un plan existente devuelven 200 `COMPLETED` (idempotente) y el plan sigue siendo el mismo. El 409 (`GeneracionEnCurso`, `PLAN_CAMBIADO_DURANTE_LA_GENERACION`) no se reprodujo en local; la app trata 409/422 de plan como «reconciliar con el actual» (`isPlanConflict`) y ya no muestra el código interno | ídem |
| I-15 | Pérdida de conexión durante el registro | ✓ Mensaje de conexión; se conservan los campos y las aceptaciones. Al reintentar con conexión se crea **una sola** cuenta (comprobado en PostgreSQL) | UA4; [`C1-07`](capturas/C1-07-sin-conexion-al-crear.jpg) |
| I-16 | Cambio de cuenta | ✓ Cerrar sesión → acceso; la otra cuenta entra y su Perfil muestra solo su correo | UA (cuenta) |

Además, con la app real: cambio de versión durante el registro ([03](03_DOCUMENTOS_Y_CONSENTIMIENTOS.md) §4) y
recuperación de contraseña ([05](05_RECUPERACION_CUENTA.md)).

**Total:** 16/16 escenarios. En vivo, 12 pruebas de contrato (11 con documentos + I-02 sin ellos), 12/12 ✓.

## 2. Otros contratos verificados

| Contrato | Resultado |
|---|---|
| `GET /users/me/consents`: `approvedDocuments` (nuevo) | Mobile lo tolera; lee `history` con `grantedAt` y `affirmativeAction` |
| 429 con `details: ["DEMASIADAS_SOLICITUDES"]` y `Retry-After` | `apiError` ya no muestra el código y añade «Podrás intentarlo de nuevo en N minutos.» |
| Registro sin participar | Aceptado por el Backend; la app no lo ofrece ([02](02_REGISTRO_OPCION_A.md) §5) |
| D-M1, O20, push (regresión en vivo de la orden anterior) | Sin cambios en esas rutas; las pruebas automáticas siguen en verde ([08](08_PRUEBAS_Y_RESULTADOS.md)) |

## 3. Limitaciones

- La exigencia y los documentos solo se activaron en la instancia local, nunca en un entorno de participantes.
- El navegador no es un teléfono: teclado, permisos, push y rendimiento quedan para la matriz Android ([06](06_QA_ANDROID.md)).
