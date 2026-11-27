# Auditoría de preproducción de Mobile Kora

**Orden:** auditoría funcional y de experiencia de usuario antes del despliegue y del estudio de 12 semanas.
**Autorización:** revisar, probar y documentar. Sin merge, sin despliegue, sin cambios de código, sin rediseño.

| | |
|---|---|
| Mobile | `Fitsense-Real/MobileApp` rama `generation`, commit `76dcf34` (no modificado) |
| Backend | `Fitsense-Real/Backend` rama `generation`, commit `77b9df3` (solo lectura; ejecutado en local con IA apagada) |
| Rama de esta auditoría | `auditoria/mobile-preproduccion` (solo documentación) |
| Fecha | 27/11/2026 |

## Documentos

| # | Documento | Contenido |
|---|---|---|
| 01 | [Inventario funcional](01_INVENTARIO_FUNCIONAL_MOBILE.md) | 37 funcionalidades con estado y evidencia |
| 02 | [Autenticación y consentimientos](02_AUTENTICACION_Y_CONSENTIMIENTOS.md) | Contraseña, correo, recuperación (flujo propuesto), términos, privacidad, consentimiento del estudio |
| 03 | [Experiencia de usuario](03_AUDITORIA_EXPERIENCIA_USUARIO.md) | Recorrido de entrenamiento, evaluación por pantalla, accesibilidad, rendimiento |
| 04 | [Visualización de ejercicios](04_VISUALIZACION_DE_EJERCICIOS.md) | Las 15 verificaciones y propuestas |
| 05 | [Integración con el Backend](05_INTEGRACION_CON_BACKEND.md) | Endpoints, pruebas reales y simuladas, incompatibilidades, notificaciones |
| 06 | [Riesgos del estudio](06_RIESGOS_ESTUDIO_12_SEMANAS.md) | 21 riesgos, seguridad y privacidad, preparación para Android físico |
| 07 | [Plan de cierre](07_PLAN_DE_CIERRE_MOBILE.md) | Decisiones previas, fases, dependencias, criterios de aceptación |
| 08 | [Matriz de pendientes](08_MATRIZ_DE_PENDIENTES.md) ([CSV](08_MATRIZ_DE_PENDIENTES.csv)) | 41 pendientes con las 10 columnas pedidas |
| — | [Evidencia](evidencia/) | Salidas de pruebas, contratos, capturas y arnés reproducible |

## Resultado en una página

**Pruebas automáticas (re-ejecutadas hoy, Flutter 3.50.1 / Dart 3.14.0):** `flutter analyze` sin incidencias;
`flutter test` **422 aprobadas, 0 fallidas, 31 omitidas** (16 en vivo que necesitan Backend, 15 de capturas). Coincide
con la referencia conocida.

**Backend real en local** (base aislada, IA apagada, cuentas sintéticas): contratos de registro, sesión, perfil,
generación, planes, ejecución (completa, parcial D-M1, no realizada, omitida, «Ya lo hice»), métricas, recuperación de
contraseña y retirada verificados; **4/4 pruebas en vivo de Mobile** aprobadas (`timed_exercise_live_test`,
`push_backend_live_test`); capturas de la app real compilada para web.

**Teléfono físico: ninguna prueba**, ni antes ni en esta auditoría.

### Lo que funciona bien

Inicio de sesión y sesión persistente; perfil de 5 pasos y generación asíncrona con recuperación tras cerrar la app;
plan semanal fiel al Backend; registro en vivo con reglas D-M1 bien explicadas; O20 sin vías para saltárselo; P1 con
almacenamiento seguro y aislamiento por cuenta; adherencia mostrada sin recalcular; P2 en lenguaje natural; contrato
de push correcto.

### P0 · Bloquean el piloto (5)

| ID | Hallazgo |
|---|---|
| M-01 | La casilla de participación dice «Opcional», pero **el Backend solo genera planes a participantes activos**: quien no la marca completa el perfil, espera 30 s y queda sin rutina (verificado en Backend local y en la app, captura `B3`). Ninguna prueba previa cubría este camino |
| M-02 | **Consentimiento de investigación no informado**: se registra la versión `MVP-1.0` sin mostrar ningún documento; condiciones y privacidad sin versión publicada ni enlaces en el registro |
| M-03 | Mobile no envía las versiones aceptadas: si el Backend activa `enforce-on-signup`, **ningún registro funcionará** |
| M-04 | **Recuperación de contraseña no operativa** en producción (sin proveedor de correo); Mobile está listo tras una bandera |
| M-05 | **Nunca se ha ejecutado Kora en un teléfono**: push, recordatorios, almacenamiento seguro y cierre por Android sin comprobar |

### P1 más relevantes (22 en total)

Animaciones alojadas en un repositorio personal de terceros con licencia no documentada (M-06); guía de esfuerzo del
plan que no se muestra (M-07); registro parcial por totales y ~35 toques por sesión (M-10); escala de esfuerzo sin
explicación (M-11); informar dolor exige 4 toques (M-12); recordatorios desactivados por defecto (M-16); «Riesgo de
abandono» visible para el participante (M-15); textos internos del Backend en la primera pantalla de Rutinas (M-14);
texto de 8–11 px con contraste de 2,85–3,1:1 y titular partido en 320 px (M-19).

### Decisiones que no son de Mobile

Once decisiones previas (producto, equipo del estudio, legal, Backend) listadas en el [plan de cierre](07_PLAN_DE_CIERRE_MOBILE.md)
§Fase 0. Sin ellas, varios pendientes no pueden cerrarse.

## Restricciones respetadas

Sin merge ni despliegue; `main` y `generation` sin modificar; sin cambios de código ni rediseño; sin implementar
recuperación ni P3; sin pantallas de consentimiento; Firebase, O20, P1, P2 y D-M1 sin tocar; Backend solo leído y
ejecutado en local con una base nueva; sin generación con IA ni Replicate; usuario 48 y su dataset sin tocar (no se
accedió a ninguna base real); las pruebas web y simuladas no se presentan como pruebas en teléfono.
