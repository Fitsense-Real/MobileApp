# 11 · Merge final y validación posmerge

| | |
|---|---|
| Orden | Revisión final y merge condicional de las PR #26–#31 (y #25) |
| Fecha | 27/11/2026 |
| `generation` antes | `76dcf340908a61fba0314b6705352759cafc0b2f` |
| `generation` después | **`f8f5e244dea62daa3963dc9a8a0b1a96445c4d3b`** |
| `main` | `3a4e26d1fed5170c6790cd05c9129f58ce88b4d0` antes y después: **sin cambios** |
| Backend de referencia | `Fitsense-Real/Backend` `generation` `77b9df3` (sin cambios; ninguna PR del Backend fusionada) |
| Herramientas | Flutter 3.50.1 / Dart 3.14.0 (las de CI) |

**Se fusionaron solo las PR #25–#31. No se desplegó nada, no se generó ni distribuyó ningún APK, no se modificó el
Backend, no se usó Replicate, no se activó ninguna bandera y no se hizo ninguna prueba en un teléfono físico.**

## 1. Estado de las PR

Merge con commit de merge (método `merge`), una por una y en orden. Antes de cada una se comprobó: PR abierta,
`mergeable_state = clean`, `verify` en verde sobre su último commit y en verde sobre el `generation` resultante de la
anterior. Después de cada una: estado `closed / merged = true`, la siguiente PR re-apuntada a `generation` (su diff
quedó en sus propios commits), `flutter analyze` y `flutter test` sobre el nuevo `generation`, CI de `generation` en
verde y `main` sin cambios.

| PR | Rama (último commit) | Merge (SHA completo) | Hora (UTC) | Archivos | `flutter test` en `generation` tras el merge | CI de `generation` |
|---|---|---|---|---|---|---|
| [#26](https://github.com/Fitsense-Real/MobileApp/pull/26) Mobile-M1 | `claude/mobile-m1-registro-consentimientos` `947448b` | `e6b2b085d213ff605d77d1551622a71f0ddd8856` | 20:22:46 | 21 | 442 ✓ · 0 ✗ · 31 | [verify ✓](https://github.com/Fitsense-Real/MobileApp/actions/runs/46063229782) |
| [#27](https://github.com/Fitsense-Real/MobileApp/pull/27) Mobile-M2 | `claude/mobile-m2-recuperacion-cuenta` `a3839f9` | `f2a7d35e9a85c8df04049ae051921d911ebdec2c` | 20:30:04 | 8 | 454 ✓ · 0 ✗ · 31 | [verify ✓](https://github.com/Fitsense-Real/MobileApp/actions/runs/46064042449) |
| [#28](https://github.com/Fitsense-Real/MobileApp/pull/28) Mobile-M3 | `claude/mobile-m3-ejercicios` `1ce8779` | `1b25e29d1fc1e0f14653fe9f572ec59d337e55cb` | 20:37:26 | 10 | 467 ✓ · 0 ✗ · 31 | [verify ✓](https://github.com/Fitsense-Real/MobileApp/actions/runs/46064899862) |
| [#29](https://github.com/Fitsense-Real/MobileApp/pull/29) Mobile-M4 | `claude/mobile-m4-registro-entrenamientos` `24aa690` | `da2a0a28d7d1804cd72c16e83651bb6654542dcc` | 20:45:18 | 9 | 483 ✓ · 0 ✗ · 31 | [verify ✓](https://github.com/Fitsense-Real/MobileApp/actions/runs/46065771116) |
| [#30](https://github.com/Fitsense-Real/MobileApp/pull/30) Mobile-M5 | `claude/mobile-m5-navegacion-accesibilidad` `1a71644` | `5032f7f68b9a4f01e67d46a9fd8110320786a860` | 20:52:13 | 18 | 494 ✓ · 0 ✗ · 31 | [verify ✓](https://github.com/Fitsense-Real/MobileApp/actions/runs/46066531303) |
| [#31](https://github.com/Fitsense-Real/MobileApp/pull/31) Mobile-M6 | `claude/mobile-m6-integracion-documentacion` `4cbb97c` | `e627010c3891aa3d55d9edfd4a1ae694662751b1` | 20:58:49 | 100 (solo docs y pruebas) | 494 ✓ · 0 ✗ · 31 | [verify ✓](https://github.com/Fitsense-Real/MobileApp/actions/runs/46067231816) |
| [#25](https://github.com/Fitsense-Real/MobileApp/pull/25) Guía Android e informe | `claude/validacion-android-informe` `2f887a1` | `f8f5e244dea62daa3963dc9a8a0b1a96445c4d3b` | 21:07:54 | 27 (solo docs) | 494 ✓ · 0 ✗ · 31 | [verify ✓](https://github.com/Fitsense-Real/MobileApp/actions/runs/46068258772) |

- **Ninguna PR quedó bloqueada.** No hubo conflictos ni fue necesario corregir nada en las ramas: no se hizo ningún
  push a ellas ni ningún force-push. Las ramas se conservan (el repositorio no las borra al fusionar).
- Cada cifra de pruebas coincide con la de su rama antes del merge ([09](09_PRUEBAS_Y_RESULTADOS.md) §1): el merge no
  cambió el resultado de ninguna.
- El árbol de `generation` tras #31 es **idéntico** al de la rama M6 (`git diff 4cbb97c e627010` vacío).
- **#25 conciliada con #31:** no comparten ningún archivo (#25: `docs/o20/validacion/GUIA_ANDROID.md` y
  `docs/validacion_android/`; #31: `docs/preproduccion/`, `docs/cierre_preproduccion/`, `lib/`, `test/`). Combinación
  local de `generation` (con #31) y #25 sin conflictos: analyze limpio y 494 ✓ · 0 ✗ · 31. Revisada antes de fusionar:
  sin credenciales (la contraseña de la demo se lee de `KORA_DEMO_PASSWORD`; `PGPASSWORD=x` es la base local),
  escrituras solo en copias locales, y declara la prueba física **PENDIENTE**.
- No quedan PR abiertas en Mobile. No se fusionó ninguna otra PR.

## 2. Revisión previa al merge

| Comprobación | Resultado |
|---|---|
| Combinación de #26–#31 (rama M6, que contiene las cinco anteriores) | `flutter pub get` ✓ · `flutter analyze`: sin incidencias · `flutter test`: **494 ✓ · 0 ✗ · 31 omitidas** |
| Pruebas nuevas presentes | 72 en ejecución (registro 15, configuración de cuenta +4, consentimientos +1, recuperación 12, ficha 13, registro de entrenamientos 12, ejercicios por tiempo +4, navegación 9, revisión del perfil 2) |
| Pruebas omitidas, desactivadas o en cuarentena | Ninguna nueva: las 31 omitidas son las mismas de la auditoría (16 en vivo + 15 de capturas) |
| Archivos de compilación | Sin cambios en `pubspec.*`, `android/`, `ios/` ni `.github/` |
| Secretos | Ninguno en el diff (búsqueda de claves, tokens, JWT y contraseñas). Los arneses leen la contraseña de `AUDIT_PASSWORD`; las contraseñas literales de `docs/preproduccion/evidencia/arnes/` son de cuentas sintéticas en una base local ya descartada |
| Banderas | Todas apagadas o con el valor de siempre por defecto ([01](01_RESUMEN_DE_CAMBIOS.md) §4) |
| O20 y P1 en el camino rápido | «Marcar varios» envía cada resultado por `send()`: confirma la rutina con el Backend antes de cada envío, retiene lo que O20 ya no permite y guarda en el teléfono lo que no se puede enviar |
| D-M1 | Mismos cuerpos HTTP (pruebas existentes sin cambiar lo esperado) |
| Fórmulas de adherencia, validadores, prompts, usuario 48 | Sin cambios |
| Comparaciones antes/después | Las 14 de [09](09_PRUEBAS_Y_RESULTADOS.md) §6 presentes |
| Auditoría original | Intacta en `auditoria/mobile-preproduccion` (`c979e04`); en `docs/preproduccion/` solo cambió la matriz 08 (columnas añadidas, autorizado por la orden del cierre) |

Ningún criterio de bloqueo de la orden (§17) se cumplió.

## 3. Contratos del Backend

`Backend` `generation` sigue en `77b9df3`; sus PR #89–#95 siguen **abiertas** (ninguna fusionada).

| Contrato | Hoy (`77b9df3`) | Con la PR del Backend #91 (B2), si se fusiona tal como está (`13b17cd`) |
|---|---|---|
| `acceptedTermsVersion`, `acceptedPrivacyVersion` | Mobile los envía solo si hay versión configurada (hoy no hay ninguna: no se envían) | Igual |
| `acceptsStudyParticipation` | Enviado siempre | Igual |
| `acceptedStudyConsentVersion` | No existe | Campo nuevo y opcional. Con `enforce-on-signup` apagado, un registro sin él se acepta (evidencia `CASILLA_SIN_DOCUMENTO_APROBADO` o `CASILLA_SIN_VERSION_CONFIRMADA`). **Mobile no lo envía todavía**: con la exigencia encendida, el registro con participación fallaría. Hay que añadirlo en Mobile **antes** de encender la exigencia (pendiente, ver §8) |
| `GET /api/v1/legal-documents` | No existe | Público, lista vacía mientras no haya documentos aprobados. Mobile no lo consume todavía: sus documentos salen de `--dart-define` (`TERMS_URL`/`TERMS_VERSION`, etc.), vacíos |
| `GET /users/me/consents` | `currentVersions`, `enforcedOnSignup`, `history` | Añade `approvedDocuments`; Mobile ignora campos desconocidos |
| Participación A/B | Solo participantes reciben planes | `fitsense.study.plans-require-participation=true` por defecto (opción A, igual que hoy). Mobile tiene la B preparada (`PLANS_FOR_NON_PARTICIPANTS=false`) |

**Conclusión:** Mobile es compatible con el Backend de hoy y con #91 apagada. No se adaptó Mobile a un contrato sin
fusionar, no se activó la opción B y la opción A no se presenta como decisión formal.

## 4. Validación posmerge sobre `generation` `f8f5e24`

### 4.1 Automáticas

`flutter analyze`: sin incidencias · `flutter test`: **494 ✓ · 0 ✗ · 31 omitidas** · CI `verify` ✓.

### 4.2 En vivo contra el Backend local

Backend `77b9df3` en este entorno, perfil `local-dev`, IA apagada (`--fitsense.ai.enabled=false`, sin token), push
apagado, recuperación `dev-log`, **base nueva aislada** `kora_merge_final`, solo cuentas `@audit.local`.

| Prueba | Resultado | Evidencia |
|---|---|---|
| D-M1 (`timed_exercise_live_test`) | 3/3 ✓ (una serie 33,33 %, todas 100 %, parcial 55,56 %) | [`evidencia/posmerge/pruebas-en-vivo-posmerge.txt`](evidencia/posmerge/pruebas-en-vivo-posmerge.txt) |
| O20 (`o20_validacion_live_test`, `pain_o20_live_test`) | 4/4 ✓ y 1/1 ✓ (422 `SESION_BLOQUEADA_POR_SEGURIDAD`, exclusiones, reactivación) | ídem |
| Push: contrato de dispositivos y registro antes de la primera generación | 1/1 ✓ y 3/3 ✓ (FID ficticios) | ídem |
| O20 por etapas (`o20_cierre`, `o20_dos_semanas`, `o20_grabar`) | No ejecutadas: necesitan un Backend preparado por etapas | — |

### 4.3 Escenarios integrales en la app real (Flutter web release de `f8f5e24`)

| # | Escenario | Resultado | Evidencia |
|---|---|---|---|
| 1 | Registro **sin** participación | ✓ Pregunta antes; entra; «Por ahora no hay una rutina para ti»; ni perfil ni generación; ningún consentimiento registrado | [`registro-y-recuperacion-app.txt`](evidencia/posmerge/registro-y-recuperacion-app.txt), `capturas/posmerge/B3` |
| 2 | Registro **con** participación | ✓ Entra al perfil sin volver a escribir la clave; el Backend registra su propio `MVP-1.0` (`CASILLA_REGISTRO`); la app no inventa versiones | [`escenarios-app-backend-local.txt`](evidencia/posmerge/escenarios-app-backend-local.txt) |
| 3 | Recuperación con código simulado | ✓ 202 → código del log local → 204 → acceso con el correo escrito → login 200 con la clave nueva; el código queda usado | `registro-y-recuperacion-app.txt`, `A8`, `A9` |
| 4 | Perfil y revisión antes de generar | ✓ `POST /users/me/profile` 201 | `P1` |
| 5 | Generación por el motor de reglas | ✓ 202 → plan visible; Kapi durante la espera | `P2` |
| 6 | Ejercicios: ficha, guía de esfuerzo, sin conexión a los GIF | ✓ (flujo `rutina` del arnés sin errores) | `D2`, `E1` |
| 7 | Sesión completa por el camino rápido | ✓ `POST /workouts/34/start` 201 → «Marcar varios» sin nada preseleccionado → «Seleccionar todos» → 8 × (`GET /plan/current` + `PUT` 200) → resumen «Completados: 8» → esfuerzo → `POST /finish` 200 | `P3`, `P4`, `P5` |
| 8 | Sesión parcial y diálogo serie por serie | ✓ en pantalla (flujo `rutina`) y en D-M1 en vivo (parcial 55,56 %) | `C9` (cierre), §4.2 |
| 9 | Dolor | ✓ «Tengo dolor o molestias» abre el diálogo de 2 toques; O20 en vivo | `C11` |
| 10 | O20 | ✓ §4.2 | — |
| 11 | P1 y reintento | ✓ Sin red el resultado queda «Pendiente de enviar»; con red, «Reintentar envío» → `PUT` 200 y deja de estar pendiente | `escenarios-app-backend-local.txt` |
| 12 | P2 y adherencia | Automáticas en verde (`adaptation_history_test`, `adherence_history_test`); Progreso sin métricas explica el lunes (`F1`). **El cierre semanal real no se ejecutó** (ciclo manual apagado; sin semana cerrada no hay adaptación ni adherencia que mostrar) | `F1` |
| 13 | Cierre de sesión y cambio de cuenta | ✓ Vuelve al acceso; la otra cuenta entra y su Perfil muestra solo su correo; no ve pendientes de la anterior | `P8a`, `P8` |
| 14 | Error de conexión | ✓ Mensaje claro de conexión al iniciar sesión sin servidor | `P9` |
| 15 | 320 × 568 | ✓ Inicio y rutina | `D1`, `D2` |

**Observación (no es regresión):** al cerrar sesión, tres consultas de fondo del Inicio salen ya sin token y reciben
401. La pantalla queda en el acceso y la siguiente cuenta no ve datos de la anterior. El código de cierre de sesión no
cambió en #26–#31: es comportamiento previo. P2 menor, sin acción en esta orden.

Las capturas posmerge están en [`capturas/posmerge/`](capturas/posmerge/) y los arneses en
[`evidencia/arnes/`](evidencia/arnes/) (`escenarios_posmerge.js`, `perfil_sin_plan.py`). Las capturas web no sustituyen
al teléfono.

## 5. Antes / después

Las 14 comparaciones de [09](09_PRUEBAS_Y_RESULTADOS.md) §6 (`capturas/comparaciones/`) siguen siendo válidas: el
`generation` fusionado es el mismo código que las produjo (árbol idéntico al de M6). Las capturas posmerge lo
confirman en las mismas pantallas (B3, D1, D2, E1, F1, C11).

## 6. Estado por área

| Área | Estado |
|---|---|
| Consentimientos | Pantallas fusionadas y probadas con documentos sintéticos. **No activadas**: sin textos aprobados ni versiones configuradas no se muestra ni se registra ninguna aceptación de condiciones o privacidad. Falta enviar `acceptedStudyConsentVersion` cuando el Backend lo incorpore |
| Recuperación | Fusionada y probada de punta a punta contra el Backend local. **Apagada** (`PASSWORD_RECOVERY_ENABLED=false`) hasta que el Backend tenga proveedor de correo y se valide el envío real |
| Firebase | Sin cambios. Contrato de dispositivos y registro antes de la primera generación verificados en vivo con FID ficticios. **Recepción real de push nunca probada** |
| Animaciones | Ficha mejorada; acepta direcciones autorizadas por el Backend y una imagen de respaldo. **Licencia de los GIF actuales sin documentar**; siguen cargándose del repositorio de terceros, como antes (no se añadieron medios) |
| Accesibilidad | Mínimo 12 px, contraste 4,8:1, sin palabras partidas en 320 px. **Abierto:** texto del sistema al 130–200 % y TalkBack, solo comprobables en el teléfono |
| Prueba física | **Ninguna realizada** |

## 7. Matriz para dos teléfonos (pendiente)

Para el propietario. Teléfono 1: gama baja, Android 11–13. Teléfono 2: gama media, Android 15–16. Compilación de
prueba (nunca de producción) contra un Backend de pruebas con IA apagada y cuentas sintéticas; usuario 48 solo lectura.
Detalle de cada fila en [08](08_PRUEBAS_ANDROID.md) §2 y en `docs/o20/validacion/GUIA_ANDROID.md` (fusionada con #25).
Copia rellenable: [`12_MATRIZ_DOS_TELEFONOS.csv`](12_MATRIZ_DOS_TELEFONOS.csv).

| N.º | Área | Prueba | Teléfono 1 | Teléfono 2 |
|---|---|---|---|---|
| A1–A2 | Registro | Sin participación → pantalla sin rutina; «Volver a comprobar», «Cerrar sesión» | PENDIENTE | PENDIENTE |
| A3–A4 | Registro | Con participación → perfil directo; zona horaria de la lista | PENDIENTE | PENDIENTE |
| A5 | Consentimientos | Con documentos **de prueba**: leer, aceptar, versión cambiada | PENDIENTE | PENDIENTE |
| B1–B4 | Recuperación | Código (log local), «Ya tengo un código» tras cerrar Kora, «Pegar código», reutilizar | PENDIENTE | PENDIENTE |
| B5 | Recuperación | Con correo real | BLOQUEADO (Backend) | BLOQUEADO (Backend) |
| C1–C4 | Ejercicios | Ficha, pausa y ampliar, «Quitar animaciones», modo avión | PENDIENTE | PENDIENTE |
| D1–D2 | Registro | 8 ejercicios en ≤ 12 toques; parcial serie por serie | PENDIENTE | PENDIENTE |
| D3–D4 | Dolor y P1 | Dolor en 2 toques; sin red, cerrar y reabrir → pendiente, no se envía solo | PENDIENTE | PENDIENTE |
| E1–E2 | Accesibilidad | Texto 130 % y 200 %; TalkBack | PENDIENTE | PENDIENTE |
| E3–E4 | Recordatorios y ayuda | Aviso con Kora cerrada abre Rutinas; Ayuda | PENDIENTE | PENDIENTE |
| F1 | Push | Backend de pruebas con credenciales autorizadas; nunca a participantes | PENDIENTE (credenciales) | PENDIENTE (credenciales) |
| F2–F3 | Plataforma | Actualizar sin desinstalar; restaurar copia de seguridad | PENDIENTE | PENDIENTE |
| F4–F5 | Plataforma | Ahorro de batería; sesión de 40 min | PENDIENTE | PENDIENTE |

## 8. Dependencias del Backend y de decisiones

| Necesita | De quién | Desbloquea |
|---|---|---|
| Fusionar B2 (#91) o equivalente; publicar documentos aprobados; después, que Mobile envíe `acceptedStudyConsentVersion` y lea `GET /legal-documents` (o configure las mismas versiones) **antes** de encender `enforce-on-signup` | Backend + equipo del estudio, luego Mobile | M-02, M-03 |
| Proveedor de correo (B4, #95), remitente, plantilla y prueba con correo real | Backend / infraestructura | M-04, M-26 |
| Modelo de participación A/B | Equipo del estudio | M-01 |
| Licencia y alojamiento de las animaciones | Equipo / Backend | M-06 |
| Credenciales de Firebase de un entorno de pruebas | Backend / infraestructura | F1 |

## 9. P0 y P1 restantes

**P0 (ninguno resuelto del todo):** M-01 (decisión A/B; mitigado: sin callejón sin salida) · M-02 (textos aprobados y
su publicación) · M-03 (preparado en Mobile; falta encenderlo a la vez que el Backend y añadir
`acceptedStudyConsentVersion`) · M-04 (correo real) · M-05 (pruebas en dos teléfonos).

**P1 abiertos:** M-06 (licencia de medios), M-11 (descripciones de la escala), M-16 (política de recordatorios), M-22
(copia de seguridad), M-23 (¿iPhone?), M-24 (mensaje de seguridad ante el dolor), M-25 (edición del perfil), M-26
(eliminación por web), M-39 (incorporar 08 a `GUIA_ANDROID.md`, ya posible tras #25).

## 10. Riesgos para el estudio de 12 semanas

| Riesgo | Situación |
|---|---|
| Consentimiento no informado (R-02) | **Abierto** hasta publicar textos aprobados y ligar la versión al registro |
| Pérdida de acceso por olvido de contraseña (R-03) | **Abierto** hasta tener correo real; durante 12 semanas es probable que alguien la olvide |
| Fallos solo visibles en el teléfono (R-05): teclado, permisos, push, recordatorios, rendimiento, texto grande | **Abierto** |
| Sin recordatorios definidos (R-10) | **Abierto** (decisión); afecta a la adherencia |
| Animaciones que deban retirarse a mitad del estudio (R-12) | **Abierto** (licencia) |
| Personas sin rutina por no participar (R-01) | Mitigado en la app; decisión A/B pendiente |
| Registro rápido inflando la adherencia (R-07/R-08) | Reducido: nada se marca por defecto y se confirma; conviene vigilar en el análisis cuántas sesiones se registran por «Marcar varios» |
| Dolor no reportado (R-09) | Reducido (2 toques); falta mensaje de seguridad aprobado |
| Cambio de comportamiento entre versiones de la app durante el estudio | Nuevo riesgo operativo: congelar la versión de la app (y la configuración de `--dart-define`) que se use con participantes y registrar cualquier cambio |

## 11. Qué falta para QA integral y para preproducción

**Para solicitar QA integral (ya posible en Mobile):** compilación de pruebas de `f8f5e24` contra un Backend de pruebas
con IA apagada; ejecutar la matriz del §7 en los dos teléfonos y registrar los fallos.

**Para preproducción con participantes:** decisiones D1–D4 ([10](10_PENDIENTES_PARA_EL_PILOTO.md) §4); Backend con B2 y
B4 (o equivalentes) fusionados y configurados; Mobile con `acceptedStudyConsentVersion` y los documentos publicados,
compilado con las mismas versiones; recuperación encendida tras validar el correo; matriz del §7 sin fallos abiertos de
prioridad alta; prueba de usabilidad con 3–5 personas ([09](09_PRUEBAS_Y_RESULTADOS.md) §7).

**Mobile no está listo para participantes.** Está fusionado, estable en pruebas automáticas y en vivo, y en
condiciones de pasar a QA en teléfono.
