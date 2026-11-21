# Preparación para Google Play

| Documento | Contenido | PR |
|---|---|---|
| [AUDITORIA_ANDROID_RELEASE.md](AUDITORIA_ANDROID_RELEASE.md) | Estado real y problemas originales, con evidencia | A |
| [LIMPIEZA_ACCESOS_SOCIALES.md](LIMPIEZA_ACCESOS_SOCIALES.md) | Botones de Google y Apple retirados | D |
| [PERMISO_INTERNET.md](PERMISO_INTERNET.md) | `INTERNET` en release, comprobado en APK y AAB | A |
| [MIGRACION_ANDROID_16.md](MIGRACION_ANDROID_16.md) | API 36, AGP 8.9.1, borde a borde | A |
| [VALIDACION_NAVEGACION_KAPI.md](VALIDACION_NAVEGACION_KAPI.md) | Gesto atrás en el tour y el resultado | A |
| [CONFIGURACION_BACKEND_HTTPS.md](CONFIGURACION_BACKEND_HTTPS.md) | URL HTTPS obligatoria y bloqueo de compilación | B |
| [IDENTIFICADOR_APLICACION.md](IDENTIFICADOR_APLICACION.md) | `pe.fitsense.kora` propuesto, pendiente de aprobación | B |
| [FIRMA_Y_AAB.md](FIRMA_Y_AAB.md) | Firma propia, Play App Signing y AAB | B |
| [ELIMINACION_CUENTA_FLUTTER.md](ELIMINACION_CUENTA_FLUTTER.md) | Eliminar mi cuenta, separado del retiro | C |
| [PRUEBAS_RELEASE.md](PRUEBAS_RELEASE.md) | Suites, artefactos y prueba integral | C |
| [GUIA_PUBLICACION_ANDROID.md](GUIA_PUBLICACION_ANDROID.md) | Pasos de publicación y prueba física | C |
| [PENDIENTES_Y_DEPENDENCIAS.md](PENDIENTES_Y_DEPENDENCIAS.md) | Lo que todavía impide publicar | C |
| [capturas/](capturas) | Evidencias | D, C |

## Integración con el backend actualizado (`generation` 5977d28, 20/11/2026)

| Documento | Contenido | PR |
|---|---|---|
| [ESTADO_PR_MOBILE.md](ESTADO_PR_MOBILE.md) | Pila #1–#8, commits y qué necesita cada PR | — |
| [CONTRATOS_BACKEND_ACTUALIZADOS.md](CONTRATOS_BACKEND_ACTUALIZADOS.md) | Contratos comprobados por HTTP y defectos del backend (B-1…B-5, S-1) | — |
| [INTEGRACION_ELIMINACION_CUENTA.md](INTEGRACION_ELIMINACION_CUENTA.md) | 200, 202, 403, 429 y PostgreSQL tras eliminar | #7, #8 |
| [INTEGRACION_RECUPERACION.md](INTEGRACION_RECUPERACION.md) | Recuperación con el correo simulado | #8 |
| [VALIDACION_EDAD_CONSENTIMIENTO.md](VALIDACION_EDAD_CONSENTIMIENTO.md) | 18 años y consentimientos versionados | #8 |
| [PRUEBAS_AUTENTICACION_JWT.md](PRUEBAS_AUTENTICACION_JWT.md) | JWT, 401 e invalidación de sesiones | #8 |
| [E2E_KORA_BACKEND_ACTUALIZADO.md](E2E_KORA_BACKEND_ACTUALIZADO.md) | Recorrido completo A–E con el backend real | #8 |
| [VALIDACION_ANDROID.md](VALIDACION_ANDROID.md) | Protecciones, APK debug para USB e instalación en Windows | #8 |
| [REGRESION_FLUTTER.md](REGRESION_FLUTTER.md) | 200 pruebas, compilaciones y clasificación de fallos | #8 |
| [REVISION_SEGURIDAD_COMPATIBILIDAD.md](REVISION_SEGURIDAD_COMPATIBILIDAD.md) | Revisión independiente final: corregido y pendiente | #8 |
| [PENDIENTES_INTEGRACION.md](PENDIENTES_INTEGRACION.md) | Lo que falta para fusionar, desplegar y publicar | #8 |
| [integracion_backend_5977/](integracion_backend_5977) | Evidencia: respuestas HTTP, PostgreSQL, capturas y arnés | #8 |

## Flutter 3.50.1 y herramientas Android 9

| Documento | Contenido |
|---|---|
| [ACTUALIZACION_COMPONENTES_OBSOLETOS.md](ACTUALIZACION_COMPONENTES_OBSOLETOS.md) | `material_ui` (0 avisos), `go_router` 18, `fl_chart` retirada, AGP 9 sin banderas transitorias ni Jetifier |
| [MIGRACION_FLUTTER_3_50.md](MIGRACION_FLUTTER_3_50.md) | Causa y corrección de las 11 pruebas, Gradle 9.5/AGP 9.3.1/Kotlin 2.4.20/NDK 28.2, avisos de obsolescencia, verificación |
