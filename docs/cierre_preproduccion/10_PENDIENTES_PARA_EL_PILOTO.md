# 10 · Pendientes para el piloto y recomendación

> **Actualización 28/11/2026 — opción A decidida.** Kora es exclusiva para participantes del estudio; la opción B ya no
> existe en Mobile (`PLANS_FOR_NON_PARTICIPANTS` eliminada en la PR #33). Las versiones de los documentos salen ahora
> de `GET /legal-documents`, no de `--dart-define`. Estado actual: [`docs/integracion_final_estudio/`](../integracion_final_estudio/).
> Lo que sigue se conserva como evidencia histórica.

> **Actualización 27/11/2026 (merge final):** las PR #26–#31 y #25 están fusionadas en `generation`
> (`f8f5e244dea62daa3963dc9a8a0b1a96445c4d3b`); `main` sin cambios. La validación posmerge (494 ✓ · 0 ✗ · 31; 12/12 en
> vivo; 15 escenarios en la app real contra el Backend local) está en [11](11_MERGE_FINAL_Y_VALIDACION.md). Ningún
> estado de la matriz cambia por el merge: fusionar no activa nada. Cambios de este documento: M-39 desbloqueado,
> dependencia nueva de `acceptedStudyConsentVersion` en M-03 y el paso 1 de la recomendación hecho.

Estado de cada ID en la matriz actualizada
[`docs/preproduccion/08_MATRIZ_DE_PENDIENTES.md`](../preproduccion/08_MATRIZ_DE_PENDIENTES.md) (y `.csv`).

## 1. P0: ninguno resuelto del todo

| ID | Estado | Qué se hizo | Qué falta y de quién |
|---|---|---|---|
| M-01 | BLOQUEADO POR DECISIÓN | Sin callejón sin salida: aviso antes de crear la cuenta sin participar y pantalla con motivo, contacto y salida | **Equipo del estudio + Backend:** elegir A (solo participantes) o B (también usuarios habituales). B está preparada (`PLANS_FOR_NON_PARTICIPANTS`) |
| M-02 | BLOQUEADO POR BACKEND | Lector de documentos, lectura obligatoria, consentimiento antes de la casilla, documentos aceptados en Perfil | **Equipo del estudio / comité:** textos aprobados. **Backend:** servir texto o dirección por versión y ligar `MVP-1.0` a un documento |
| M-03 | PREPARADO SIN ACTIVAR | Mobile envía las versiones mostradas y explica los 422 | **Backend + Mobile, a la vez:** configurar versiones y encender `enforce-on-signup` con una compilación que tenga las mismas versiones. Si se fusiona la PR del Backend #91 (B2), Mobile debe enviar antes `acceptedStudyConsentVersion` (con la exigencia encendida, el registro con participación sin ella se rechaza) y puede leer `GET /api/v1/legal-documents` ([11](11_MERGE_FINAL_Y_VALIDACION.md) §3) |
| M-04 | BLOQUEADO POR BACKEND | Recuperación completa y probada de punta a punta (log local) | **Backend/infraestructura:** proveedor de correo, remitente y plantilla; prueba con correo real; después encender `PASSWORD_RECOVERY_ENABLED` |
| M-05 | PENDIENTE DE DISPOSITIVO | Guía completa ([08](08_PRUEBAS_ANDROID.md)) | **Propietario:** ejecutarla en dos teléfonos |

## 2. P1

| Estado | IDs |
|---|---|
| RESUELTO (13) | M-07, M-09, M-10, M-12, M-13, M-14, M-15, M-17, M-18, M-19, M-27, M-38, M-40 |
| PREPARADO SIN ACTIVAR (3) | M-11 (descripciones de la escala), M-24 (mensaje de seguridad), M-39 (guía complementaria; la PR #25 ya está fusionada: falta incorporar [08](08_PRUEBAS_ANDROID.md) a `GUIA_ANDROID.md`) |
| BLOQUEADO POR DECISIÓN (4) | M-06 (licencia de medios), M-16 (política de recordatorios), M-23 (¿iOS?), M-25 (edición del perfil) |
| BLOQUEADO POR BACKEND (1) | M-26 (correo y página de eliminación web) |
| PENDIENTE DE DISPOSITIVO (1) | M-22 (copia de seguridad de Android) |

## 3. P2

RESUELTO: M-08, M-34, M-35 · BLOQUEADO POR BACKEND: M-28, M-29, M-37 · PENDIENTE DE DISPOSITIVO: M-32 · PENDIENTE:
M-20, M-21, M-30, M-31 (parcial), M-33, M-41 · NO APLICA: M-36 (P3 excluido).

**Incidencia de seguimiento detectada tras el merge (fuera de la matriz de la auditoría):**

| ID | Prioridad | Qué pasa | Estado |
|---|---|---|---|
| I-01 | P2 | Al cerrar sesión, tres consultas de fondo del Inicio salen sin token y reciben 401. Sin efecto visible ni fuga entre cuentas. Comportamiento previo a #26–#31, no regresión ([11](11_MERGE_FINAL_Y_VALIDACION.md) §4.3) | PENDIENTE (corregir en una PR propia) |

## 4. Decisiones que esperan respuesta

| # | Decisión | Desbloquea |
|---|---|---|
| D1 | Modelo de participación (A/B) | M-01 |
| D2 | Textos aprobados (condiciones, privacidad, consentimiento) | M-02, M-03 |
| D3 | Proveedor de correo | M-04, M-26 |
| D4 | Licencia y alojamiento de las animaciones | M-06 |
| D5 | Política de recordatorios | M-16 |
| D6 | ¿Mostrar el riesgo de abandono? (`SHOW_DROPOUT_RISK`) | M-15 |
| D7 | Descripciones de la escala de esfuerzo y satisfacción; ¿observaciones? | M-11 |
| D8 | Mensaje de seguridad ante el dolor y contacto del equipo (`PAIN_SAFETY_MESSAGE`, `STUDY_CONTACT`) | M-24, M-40 |
| D9 | Edición del perfil durante el estudio | M-25 |
| D10 | ¿Habrá participantes con iPhone? | M-23 |
| D11 | Textos de «Lo que tu plan no puede cubrir» para participantes | M-14 (contenido) |

## 5. Estado por área (respuestas de la orden §14)

| Área | Estado | Distinción |
|---|---|---|
| Firebase | Integración existente conservada; contrato de dispositivos verificado en vivo contra el Backend local | **Recepción real de push: nunca probada** (falta teléfono y credenciales de servidor de un entorno de pruebas). Firebase no se modificó |
| Recuperación de contraseña | Implementada y probada contra el Backend local de punta a punta en la app | **No operativa para participantes** hasta que haya correo real; bandera apagada |
| Consentimientos | Pantallas implementadas y probadas con documentos sintéticos | **No listas para participantes**: faltan textos aprobados y su publicación en el Backend |
| Animaciones y licencias | Ficha mejorada; Mobile acepta direcciones autorizadas e imagen de respaldo | **Licencia de Gym visual no documentada**; siguen cargándose del repositorio de terceros |
| Prueba física | Guía preparada | **Ninguna prueba realizada** |

**Pruebas que necesitan el teléfono del propietario:** todas las de [08](08_PRUEBAS_ANDROID.md) §2 (A1–F5), en
especial push (F1), recordatorios y apertura con la app cerrada (E3), texto grande y TalkBack (E1–E2), P1 tras cerrar
Kora (D4), actualización (F2), copia de seguridad (F3) y rendimiento (F5).

## 6. Riesgos restantes para el estudio

| Riesgo (auditoría) | Situación tras el cierre |
|---|---|
| R-01 Personas sin rutina por no marcar la casilla | Mitigado: lo saben antes de crear la cuenta y no quedan atrapadas; sigue pendiente la decisión del modelo |
| R-02 Consentimiento no informado | **Abierto** hasta publicar textos aprobados |
| R-03 Pérdida de acceso por olvido de contraseña | **Abierto** hasta tener correo real |
| R-05 Fallos solo visibles en teléfono | **Abierto** |
| R-06 Esfuerzo mal interpretado | Reducido (explicación); abierto hasta aprobar descripciones |
| R-07 / R-08 Parciales mal sumados y fatiga de registro | Reducido: registro por series y camino rápido con confirmación |
| R-09 Dolor no reportado | Reducido: 2 toques; falta mensaje de seguridad aprobado y «completado con dolor» |
| R-10 Sin recordatorios | **Abierto** (decisión) |
| R-11 Riesgo de abandono visible | Preparado para ocultarlo; decisión pendiente |
| R-12 Animaciones que deban retirarse | **Abierto** (licencia) |
| R-13 Técnica incorrecta | Reducido (ficha, guía de esfuerzo) |
| R-17 Desconfianza por textos internos | Reducido (notas plegadas); contenido del Backend sin cambios |
| R-18 Lectura difícil | Reducido (12 px, 4,8:1, sin palabras partidas); falta prueba con texto grande en teléfono |
| R-19 iPhone | **Abierto** (decisión) |

## 7. Recomendación

**Mobile no está listo para participantes y no debe distribuirse al piloto todavía**: los cinco P0 siguen abiertos
(uno mitigado). Sí está en condiciones de **solicitar una validación integral de preproducción** en cuanto se
cumplan, en este orden:

1. ~~Revisar y fusionar las PR Mobile-M1 → M6 en orden (y la PR #25 de la guía).~~ **Hecho el 27/11/2026** ([11](11_MERGE_FINAL_Y_VALIDACION.md)).
2. Decidir D1, D2, D3 y D4.
3. Backend: textos por versión, versiones configuradas, correo real; Mobile: compilación de pruebas con las mismas
   versiones y la recuperación encendida.
4. Ejecutar la guía Android en dos teléfonos (M-05) con la matriz [`12_MATRIZ_DOS_TELEFONOS.csv`](12_MATRIZ_DOS_TELEFONOS.csv) y corregir lo que aparezca.
5. Prueba de usabilidad con 3–5 personas ([09](09_PRUEBAS_Y_RESULTADOS.md) §7).
6. Repetir esta matriz: solo con los P0 en RESUELTO o con una decisión explícita del equipo para cada uno, pasar al piloto.
