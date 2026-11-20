# Regresión Flutter (integración con 5977d28)

Rama `claude/play-e-backend-5977`. Flutter 3.32.8. Se ejecutó en `d96f4ab` (200 pruebas) y de nuevo tras
las correcciones de la revisión final (**206**, ver `REVISION_SEGURIDAD_COMPATIBILIDAD.md`).

## Resultados

| Comprobación | Resultado |
|---|---|
| `flutter analyze` | No issues found |
| `flutter test` | **206 pasan, 0 fallan, 0 omitidas** (200 en `d96f4ab`; antes de esta orden: 177) |
| `flutter build web --release --no-web-resources-cdn` | ✓ (es la app usada en el E2E) |
| `flutter build apk --debug --target-platform android-arm64` | ✓, 57 MB (`VALIDACION_ANDROID.md`) |
| `flutter build apk --release` con URL `.invalid` y `-Pkora.testBackendUrl=true` | ✓, 12,4 MB; manifiesto revisado |
| `flutter build apk --release` con HTTP / con `10.0.2.2` | **bloqueado**, como corresponde |
| `flutter build appbundle` sin configuración | **bloqueado**, con 6 motivos |
| Integración HTTP real | `CONTRATOS_BACKEND_ACTUALIZADOS.md` |
| E2E real (navegación, autenticación, eliminación, recuperación, edad, consentimientos, entrenamiento, adherencia) | `E2E_KORA_BACKEND_ACTUALIZADO.md` |

## Pruebas nuevas o cambiadas (+23)

| Archivo | Antes → ahora | Qué fija |
|---|---|---|
| `account_deletion_test.dart` | 13 → 18 | Contrato real. Se reescribió porque el anterior suponía un login aparte, que ya no existe: los casos de esa reautenticación se sustituyeron por 403 y 429 del backend. Añade 202 con `alreadyRequested`, 404, 503, 401, 200 inesperado y 429 sin `Retry-After` |
| `backend_alignment_test.dart` | 36 → 38 | Recuperación apagada por defecto; mensajes 400 y 429 |
| `minimum_age_test.dart` | nuevo, 6 | Edad mínima |
| `consents_test.dart` | nuevo, 4 | Consentimientos |
| `account_setup_test.dart` | 5 → 8 | Consentimientos pendientes antes del perfil; error de consulta que no bloquea |
| `exercise_results_test.dart` | 7 → 8 | Parcial sin volumen |
| `recovery_email_format_test.dart` | nuevo, 2 | Correo con `+` y dominio largo |

Las de parcial, correo de recuperación y 429 sin `Retry-After` **fallan con el código anterior**
(comprobado), así que detectan los defectos que se encontraron con el backend real.

No se borró ninguna prueba sin sustituirla. Siguen en verde Kapi, el tour, la navegación, la persistencia,
la generación asíncrona, las fechas del dashboard, la sesión en vivo, los recordatorios, el 401 global, los
accesos sociales, borde a borde y `api_config`.

## Clasificación de los fallos encontrados

| Fallo | Tipo | Estado |
|---|---|---|
| Eliminación sin cuerpo y con login aparte | Mobile (contrato nuevo) | corregido (`14c7241`) |
| «Enviar enlace» cuando el backend envía un código | Mobile (contrato nuevo) | corregido (`f30049f`) |
| Mensaje de edad del backend sin «ñ» | Contrato backend (B-2) | la app usa su propio texto |
| Parcial sin repeticiones guardado como omitido | Mobile | corregido (`74994d4`) |
| Correo válido rechazado en recuperación | Mobile | corregido (`323c8be`) |
| `Retry-After` invisible en el navegador | Contrato backend (B-1, CORS) | mitigado en Mobile (`d96f4ab`) |
| Etiquetas de fechas, sesión persistente y caché del service worker | Entorno (arnés) | corregido en el arnés |
| CanvasKit desde el CDN sin internet | Entorno | se compila con `--no-web-resources-cdn` |
