# 01 · Resumen de cambios del cierre de preproducción de Mobile

| | |
|---|---|
| Orden | Cierre funcional, experiencia de usuario y preparación para el estudio |
| Auditoría de partida | `auditoria/mobile-preproduccion` `c979e04` (`docs/preproduccion/01–08`) sobre `generation` `76dcf34` |
| Base | `generation` `76dcf34` (sin cambios desde la auditoría; PR #24 fusionada) |
| Backend de referencia | `Fitsense-Real/Backend` `generation` `77b9df3` (sin cambios desde la auditoría; solo lectura) |
| Fecha | 27/11/2026 |
| Herramientas | Flutter 3.50.1 / Dart 3.14.0 (las de CI) |

**Nada se ha desplegado. No se generó ningún APK de producción. No se consumió Replicate. Ninguna prueba se hizo en un
teléfono físico.** Las seis PR y la #25 se fusionaron en `generation` el 27/11/2026, una por una y en orden
(`generation` = `f8f5e244dea62daa3963dc9a8a0b1a96445c4d3b`; `main` sin cambios): ver [11](11_MERGE_FINAL_Y_VALIDACION.md).

## 1. Organización: seis PR apiladas

Las PR comparten archivos (`planned_workout_page.dart`, `dashboard_page.dart`, la configuración del estudio), así que
cada una parte de la anterior. Se revisan y fusionan **en orden**; cada una está en verde por sí sola.

| PR | Rama | Base | Último commit | Contenido | Pruebas al cerrar |
|---|---|---|---|---|---|
| Mobile-M1 ([#26](https://github.com/Fitsense-Real/MobileApp/pull/26)) | `claude/mobile-m1-registro-consentimientos` | `generation` | `947448b` | Registro, participación, documentos, zona horaria, login tras registro | 442 ✓ · 0 ✗ · 31 omitidas |
| Mobile-M2 ([#27](https://github.com/Fitsense-Real/MobileApp/pull/27)) | `claude/mobile-m2-recuperacion-cuenta` | M1 | `a3839f9` | Recuperación de contraseña; revisión de eliminación de cuenta | 454 ✓ · 0 ✗ · 31 |
| Mobile-M3 ([#28](https://github.com/Fitsense-Real/MobileApp/pull/28)) | `claude/mobile-m3-ejercicios` | M2 | `1ce8779` | Ficha del ejercicio, guía de esfuerzo, medios preparados, etiquetas en español | 467 ✓ · 0 ✗ · 31 |
| Mobile-M4 ([#29](https://github.com/Fitsense-Real/MobileApp/pull/29)) | `claude/mobile-m4-registro-entrenamientos` | M3 | `24aa690` | Barra de acciones, registro por series, «Marcar varios», dolor en 2 toques, escala explicada | 483 ✓ · 0 ✗ · 31 |
| Mobile-M5 ([#30](https://github.com/Fitsense-Real/MobileApp/pull/30)) | `claude/mobile-m5-navegacion-accesibilidad` | M4 | `1a71644` | Accesibilidad, Progreso, notas del plan, ayuda, revisión del perfil, recordatorios | 494 ✓ · 0 ✗ · 31 |
| Mobile-M6 ([#31](https://github.com/Fitsense-Real/MobileApp/pull/31)) | `claude/mobile-m6-integracion-documentacion` | M5 | (este) | Auditoría incorporada, pruebas de integración, capturas, guía Android, matriz actualizada y esta documentación | 494 ✓ · 0 ✗ · 31 |

Referencia de la auditoría: 422 ✓ · 0 ✗ · 31 omitidas. Las 72 pruebas nuevas no sustituyen a ninguna existente; las
pruebas existentes que se modificaron cambian solo textos de pantalla o la forma de escribir un resultado, nunca el
cuerpo HTTP esperado (detalle en [09](09_PRUEBAS_Y_RESULTADOS.md)).

## 2. Qué cambió para la persona

| Pantalla | Antes | Después | Doc |
|---|---|---|---|
| Registro | Participación «Opcional» que llevaba a un callejón sin salida; zona horaria a mano | Se explica que Kora prepara rutinas solo a participantes y se pregunta antes de crear la cuenta sin participar; lista cerrada de zonas; documentos legibles en la app cuando estén aprobados; entra directamente tras crear la cuenta | [02](02_REGISTRO_Y_CONSENTIMIENTOS.md) |
| Cuenta sin rutina posible | 5 pasos de perfil, 30 s de espera y «Reintentar generación» que siempre fallaba | «Por ahora no hay una rutina para ti»: motivo, contacto, «Volver a comprobar», «Cerrar sesión» | [02](02_REGISTRO_Y_CONSENTIMIENTOS.md) |
| Recuperación | Sin «Ya tengo un código»; había que copiar 43 caracteres a mano | «Ya tengo un código», «Pegar código», «Pide un código nuevo» con el correo escrito, caducidad explicada, vuelta al login con el correo | [03](03_RECUPERACION_DE_CUENTA.md) |
| Rutina | Botón «Comenzar» al final de la lista; sin guía de esfuerzo | Barra de acciones fija; «Cómo esforzarte hoy» con el texto del Backend; explicación de empezar en vivo o «Ya lo hice» | [04](04_REDISENO_DE_EJERCICIOS.md), [05](05_REGISTRO_DE_ENTRENAMIENTOS.md) |
| Ejercicio | Hoja que tapaba la animación; músculos en inglés | Ficha a pantalla completa: animación grande con pausa y ampliar, qué hacer, descanso entre series en minutos, equipo, zona, guía, instrucciones, anterior/siguiente | [04](04_REDISENO_DE_EJERCICIOS.md) |
| Registro de resultado | 4 campos de totales antes de elegir; ~35 toques por sesión | Primero qué pasó; parcial serie por serie con total calculado; «Marcar varios como completados» con confirmación; 8 toques probados para 8 ejercicios | [05](05_REGISTRO_DE_ENTRENAMIENTOS.md) |
| Dolor | 4 toques y un desplegable | «Tengo dolor o molestias» en cada ejercicio y en su ficha: 2 toques | [05](05_REGISTRO_DE_ENTRENAMIENTOS.md) |
| Inicio, Rutinas, Progreso, Perfil | Texto de 8–11 px, contraste 3,1:1, palabras partidas en 320 px, notas internas en primer plano, «pp» | Mínimo 12 px, contraste 4,8:1, sin palabras partidas, notas plegadas, lenguaje natural, ayuda con preguntas frecuentes | [06](06_ACCESIBILIDAD_Y_NAVEGACION.md) |
| Perfil inicial | Aviso de que no se podrá cambiar en letra pequeña | Revisión completa con «Editar» antes de «Generar mi plan» | [06](06_ACCESIBILIDAD_Y_NAVEGACION.md) |

## 3. Lo que se conserva sin cambios

Autenticación y sesión persistente; perfil inicial; generación asíncrona y la pantalla de 30 s; visualización de
planes; reglas D-M1 (mismos cuerpos HTTP); O20 (confirmación de la rutina antes de cada envío, retención, rechazo del
Backend); P1 (almacenamiento seguro, 48 h, aislamiento por cuenta); P2; adherencia del Backend sin recalcular;
Firebase; eliminación de cuenta (bandera); recuperación detrás de su bandera. **No se modificaron** prompts, validadores,
fórmulas de adherencia, Firebase, el Backend ni el usuario 48. **No se implementó P3.**

## 4. Configuración nueva (toda vacía o igual a hoy por defecto)

| `--dart-define` | Por defecto | Para qué |
|---|---|---|
| `PLANS_FOR_NON_PARTICIPANTS` | `false` | Opción B de M-01 cuando el Backend genere planes a no participantes |
| `TERMS_VERSION`, `PRIVACY_VERSION` (+ `TERMS_URL`, `PRIVACY_POLICY_URL` existentes) | vacías | Documentos legibles y aceptados en el registro, solo con dirección **y** versión aprobada |
| `STUDY_CONSENT_URL`, `STUDY_CONSENT_VERSION` | vacías | Consentimiento informado legible antes de la casilla de participación |
| `STUDY_CONTACT` | vacío | Contacto aprobado del equipo (Ayuda, pantalla sin rutina) |
| `PAIN_SAFETY_MESSAGE` | vacío | Mensaje de seguridad aprobado al informar dolor y en Ayuda |
| `SHOW_DROPOUT_RISK` | `true` | Poner `false` oculta «Riesgo de abandono» si el equipo lo decide |
| `DEFAULT_TIMEZONE` | `America/Lima` | Zona preseleccionada en el registro |
| `EXERCISE_MEDIA_LEGACY_SOURCE` | `true` | Poner `false` muestra solo medios con dirección autorizada por el Backend |
| `PASSWORD_RECOVERY_ENABLED`, `ACCOUNT_DELETION_ENABLED` | `false` (existentes) | Sin cambios |

Las descripciones de los niveles de esfuerzo y satisfacción se escriben en `lib/features/workouts/domain/rpe_scale.dart`
cuando estén aprobadas (vacías hoy).

## 5. Estado de los pendientes de la auditoría

Ver la matriz actualizada [`docs/preproduccion/08_MATRIZ_DE_PENDIENTES.md`](../preproduccion/08_MATRIZ_DE_PENDIENTES.md)
y el detalle en [10](10_PENDIENTES_PARA_EL_PILOTO.md).

| Estado | P0 | P1 | P2 |
|---|---|---|---|
| RESUELTO | 0 | 13 | 3 |
| PREPARADO SIN ACTIVAR | 1 (M-03) | 3 | 0 |
| BLOQUEADO POR BACKEND | 2 (M-02, M-04) | 1 | 3 |
| BLOQUEADO POR DECISIÓN | 1 (M-01) | 4 | 0 |
| PENDIENTE DE DISPOSITIVO | 1 (M-05) | 1 | 1 |
| PENDIENTE | 0 | 0 | 6 |
| NO APLICA | 0 | 0 | 1 |

**Ningún P0 está resuelto del todo**: M-01 ya no tiene callejón sin salida, pero falta la decisión del modelo; M-02 y
M-04 dependen del Backend; M-03 está listo en Mobile; M-05 necesita un teléfono. **Kora no está lista para
participantes.**
