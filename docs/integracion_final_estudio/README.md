# Integración final con el Backend, opción A y preparación de QA Android

Orden del 28/11/2026. Base: `generation` `1cd9f97` (con la #32 fusionada). Backend integrado: `41c498a`.
**Sin despliegue, sin APK de producción, sin Replicate y sin pruebas en teléfono físico.**

| # | Documento |
|---|---|
| 01 | [Estado de Mobile y cierre de la PR #32](01_ESTADO_MOBILE_Y_PR32.md) |
| 02 | [Registro con la opción A](02_REGISTRO_OPCION_A.md) (Mobile-C1, PR #33) |
| 03 | [Documentos y consentimientos versionados](03_DOCUMENTOS_Y_CONSENTIMIENTOS.md) (Mobile-C1) |
| 04 | [Contratos con el Backend (I-01…I-16)](04_CONTRATOS_BACKEND.md) |
| 05 | [Recuperación de contraseña](05_RECUPERACION_CUENTA.md) (sin cambios; sin Mobile-C2) |
| 06 | [QA en Android físico](06_QA_ANDROID.md) (pendiente de dispositivo) |
| 07 | [Incidencia I-01](07_INCIDENCIA_I01.md) (Mobile-C3, PR #34) |
| 08 | [Pruebas y resultados](08_PRUEBAS_Y_RESULTADOS.md) |
| 09 | [Pendientes para preproducción](09_PENDIENTES_PARA_PREPRODUCCION.md) |

- **Evidencia:** [`evidencia/`](evidencia/), con los arneses en `evidencia/arnes/` y los documentos sintéticos en
  `evidencia/documentos_sinteticos/`.
- **Capturas:** [`capturas/`](capturas/).
- **Scripts de QA:** [`qa_android/`](qa_android/).
- **Matriz:** [`../cierre_preproduccion/12_MATRIZ_DOS_TELEFONOS.csv`](../cierre_preproduccion/12_MATRIZ_DOS_TELEFONOS.csv).

La evidencia de auditorías anteriores se conserva sin cambios en `docs/preproduccion/` y `docs/cierre_preproduccion/`.
Allí solo se añadieron notas que remiten aquí y la fila M-01 de la matriz.
