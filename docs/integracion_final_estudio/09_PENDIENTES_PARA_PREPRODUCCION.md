# 09 · Pendientes para preproducción

> **Revisión del 28/11/2026 (orden de merge):** ver [10](10_REVISION_FINAL_Y_BACKEND_96.md). El registro exige ahora
> los **tres** documentos publicados y Mobile usa los códigos estables de Backend #96. Backend #96 se fusionó
> (`434a9dc`) y después se fusionaron #33 (`ed11b5a`) y #34 (`9e9ebbc`).

Estados: **RESUELTO / PREPARADO SIN ACTIVAR / BLOQUEADO POR BACKEND / BLOQUEADO POR APROBACIÓN / PENDIENTE DE DISPOSITIVO
/ PENDIENTE.**

## 1. P0 de la auditoría

| ID | Tema | Estado | Qué se hizo en esta orden | Qué falta y de quién |
|---|---|---|---|---|
| M-01 | Modelo de participación | **PREPARADO SIN ACTIVAR** | Opción A decidida e implementada (PR #33): registro solo para quien acepta participar; rechazo sin cuenta; retirada sin generación; opción B eliminada de Mobile | Revisar y fusionar la #33. Backend (opcional): rechazar altas sin participación por la API |
| M-02 | Consentimiento informado | **BLOQUEADO POR APROBACIÓN** | Documentos de `GET /legal-documents`, lector obligatorio, historial en Perfil | **Equipo / comité:** textos aprobados. **Backend:** publicarlos con su referencia de aprobación |
| M-03 | Versiones en el registro | **PREPARADO SIN ACTIVAR** | Mobile envía las cuatro versiones leídas, comprueba antes de enviar y explica los 422. Contrato probado en vivo con la exigencia encendida | Activación conjunta tras M-02 ([03](03_DOCUMENTOS_Y_CONSENTIMIENTOS.md) §6) |
| M-04 | Recuperación con correo | **BLOQUEADO POR BACKEND** | Revisada contra `41c498a`: funciona; sin cambios en Mobile | Proveedor de correo, remitente y plantilla; prueba con buzón sintético; luego `PASSWORD_RECOVERY_ENABLED=true` |
| M-05 | Prueba en Android físico | **PENDIENTE DE DISPOSITIVO** | Matriz de 46 comprobaciones, scripts de Backend de pruebas, compilación debug y evidencia | **Propietario:** ejecutarla en dos teléfonos |

## 2. Incidencias y observaciones

| ID | Tema | Estado |
|---|---|---|
| I-01 | 401 de fondo al cerrar sesión | **PREPARADO SIN ACTIVAR** (corregido en la PR #34) |
| — | Persona retirada con plan: aviso en Inicio | **PREPARADO SIN ACTIVAR** (PR #33). Queda la tarjeta «Tus datos aparecerán al cerrar tu primera semana», inexacta tras la retirada: **PENDIENTE** (P2) |
| — | 429 en la app web sin tiempo de espera (CORS oculta `Retry-After`) | **BLOQUEADO POR BACKEND** (exponer la cabecera) si importa la web; en Android se lee |
| — | Un código de recuperación nuevo no invalida el anterior | **BLOQUEADO POR BACKEND** (P2) |
| — | Registro sin participación aceptado por la API | **BLOQUEADO POR BACKEND** (opcional con la opción A) |

## 3. Decisiones del protocolo (no se activó nada por cuenta propia)

| Tema | Estado |
|---|---|
| Textos de condiciones, privacidad y consentimiento | **BLOQUEADO POR APROBACIÓN** |
| `privacy-record` (aceptación o constancia) | **BLOQUEADO POR APROBACIÓN** (Mobile adapta el texto a lo que publique el Backend) |
| Licencia y alojamiento de las animaciones | **BLOQUEADO POR APROBACIÓN**: siguen cargándose del repositorio de terceros; Mobile acepta direcciones autorizadas del Backend e imagen de respaldo. No se copió ningún medio |
| Política de recordatorios | **BLOQUEADO POR APROBACIÓN** |
| Mostrar u ocultar el riesgo de abandono | **BLOQUEADO POR APROBACIÓN** (`SHOW_DROPOUT_RISK`, sin cambios) |
| Mensaje de seguridad ante el dolor y contacto | **BLOQUEADO POR APROBACIÓN** (`PAIN_SAFETY_MESSAGE`, `STUDY_CONTACT`, vacíos) |
| Edición del perfil tras el primer plan | **BLOQUEADO POR APROBACIÓN** (sigue de solo lectura) |
| Descripciones de la escala de esfuerzo | **BLOQUEADO POR APROBACIÓN** |
| ¿Participantes con iPhone? | **BLOQUEADO POR APROBACIÓN** |

## 4. Riesgos que permanecen

**Seguridad y datos**
- Consentimiento: hasta publicar los textos aprobados no se puede registrar a nadie de forma válida (la app no lo
  permite).
- Cuentas creadas por la API sin participación: no reciben plan, pero existen.
- Animaciones de un tercero: dependen de su disponibilidad y de una licencia sin documentar.
- Push y almacenamiento seguro en teléfonos reales: sin probar.

**Usabilidad**
- Leer tres documentos completos antes de registrarse alarga el alta. Conviene medirlo en la prueba de usabilidad.
- Texto grande, TalkBack y teclado reales, sin probar.
- Recuperación sin correo: una persona que olvide la clave depende del equipo.

## 5. Qué falta para preproducción, en orden

1. ~~Backend #96 y Mobile #33 → #34 → #35~~: fusionadas el 28/11/2026 ([10](10_REVISION_FINAL_Y_BACKEND_96.md) §1).
2. **Equipo / comité:** aprobar los textos y su versión. **Backend:** publicarlos y decidir `privacy-record`.
3. **Backend:** proveedor de correo y prueba con buzón sintético.
4. **Activación conjunta** en el entorno de pruebas: exigencia encendida, I-01…I-09 repetidos y historial comprobado en
   su PostgreSQL. Aprobación del equipo.
5. **Propietario:** matriz Android de 46 comprobaciones en dos teléfonos; corregir los fallos críticos y altos.
6. Prueba de usabilidad con 3–5 personas que no sean participantes.
7. Solo entonces, una compilación de preproducción (nunca distribuida a participantes sin la aprobación del equipo).

**Mobile no está listo para participantes**: el registro está cerrado hasta que se publiquen los textos aprobados, y
no hay ninguna prueba física.
