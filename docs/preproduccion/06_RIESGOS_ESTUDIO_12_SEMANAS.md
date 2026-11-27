# 06 · Riesgos para el estudio de 12 semanas

Riesgos para los participantes, la calidad de los registros, la adherencia medida y la continuidad de uso, con su origen
en Mobile (o en la integración) y su mitigación. Incluye la revisión de **seguridad y privacidad** de Mobile (§2) y de la
**preparación para Android físico** (§3).

Escala: **Probabilidad** (Alta / Media / Baja) × **Impacto en el estudio** (Alto / Medio / Bajo).

## 1. Matriz de riesgos

| ID | Riesgo | Origen comprobado | Prob. | Impacto | Mitigación | Pendiente asociado |
|---|---|---|---|---|---|---|
| R-01 | **Personas que no marcan «Acepto participar» quedan sin rutina** tras completar el perfil; abandonan o escriben al equipo | Casilla «Opcional» + Backend que solo genera para participantes (verificado, `B3`) | Alta | Alto | Decidir el modelo (solo participantes o no) antes de distribuir; mientras tanto, ninguna versión con la casilla «Opcional» | M-01 (P0) |
| R-02 | **Consentimiento no informado**: participantes registrados sin haber leído el consentimiento; el comité puede invalidar datos | Ningún texto de consentimiento en la app; versión `MVP-1.0` sin documento | Alta | Alto | Texto aprobado, servido por el Backend, leído antes de aceptar | M-02 (P0) |
| R-03 | **Pérdida de acceso por olvido de contraseña** durante 12 semanas → semanas sin registros | Recuperación no operativa en producción (sin correo) | Media | Alto | Proveedor de correo + bandera; procedimiento manual del equipo mientras tanto (no existe endpoint de administración para restablecer, verificar) | M-04 (P0) |
| R-04 | **Correo mal escrito en el registro** → la recuperación nunca llega | Sin verificación de correo | Baja | Medio | Confirmar el correo en el registro (repetirlo) o verificarlo | M-29 |
| R-05 | **Fallos que solo aparecen en un teléfono** (push, recordatorios, almacenamiento seguro, cierre por Android, ahorro de batería de Samsung, teclado) descubiertos con participantes reales | Nunca se ejecutó en un teléfono (§3) | Alta | Alto | Ejecutar la guía Android ampliada (§3.3) en al menos un teléfono de gama baja y uno de gama media | M-05 (P0) |
| R-06 | **Esfuerzo percibido mal interpretado** → variable del estudio ruidosa | Escala 1–10 sin anclas | Alta | Medio | Escala con descripciones aprobadas; explicación en el recorrido | M-11 (P1) |
| R-07 | **Registros parciales mal sumados** (repeticiones totales de todas las series) → porcentajes erróneos (D-M1) | Diálogo con totales y 4 campos | Media | Medio | Registro por series con total calculado | M-10 (P1) |
| R-08 | **Fatiga de registro** (≈ 35 toques por sesión) → menos registros, cobertura baja, adherencia ponderada subestimada | Un diálogo por ejercicio, sin «marcar el resto como completado» | Media | Alto | Atajo con confirmación; menos campos | M-10, M-13 (P1) |
| R-09 | **Dolor no reportado** → O20 no actúa, riesgo físico y datos de seguridad incompletos | Informar dolor exige 4 toques; no existe para ejercicios completados; sin mensaje de seguridad | Media | Alto | Botón visible de dolor; mensaje de seguridad aprobado; paso en el recorrido | M-12, M-24 (P1) |
| R-10 | **Sin recordatorios de entrenamiento** para el participante típico → menor adherencia; o diferencias entre participantes que los activan y los que no (sesgo) | Recordatorios desactivados por defecto; push sin recordatorios | Alta | Alto | Decisión de protocolo: activados para todos, para nadie, o elegidos de forma registrada | M-16 (P1) |
| R-11 | **Mostrar «Riesgo de abandono: Alto»** influye en la conducta del participante | `dashboard_page.dart:1019` | Media | Medio | Decisión del equipo; propuesta: no mostrarlo | M-15 (P1) |
| R-12 | **Animaciones que desaparecen o deben retirarse** a mitad del estudio | GIF en un repositorio personal de terceros; licencia no documentada | Baja | Alto | Alojamiento propio y licencia antes de empezar | M-06 (P1) |
| R-13 | **Técnica incorrecta** por no entender el ejercicio | GIF pequeño, sin controles; guía de esfuerzo no visible; músculos en inglés | Media | Medio | Ficha del ejercicio y guía de esfuerzo | M-07, M-08, M-09 (P1) |
| R-14 | **Perfil congelado 12 semanas**: cambios de horario, equipamiento o lesiones no se reflejan; aumentan las omisiones | `PUT /profile` → 422 tras el primer plan | Media | Medio | Decisión de protocolo; si se mantiene, revisión del perfil antes de generar | M-25 (P1) |
| R-15 | **Retirada mal entendida**: la persona cree que puede seguir usando Kora y deja de tener planes | Texto del diálogo de retirada | Baja | Medio | Texto que describe la realidad | M-17 (P1) |
| R-16 | **Confusión al empezar una sesión** (botón al final, dos caminos «en vivo» / «Ya lo hice») → registros retroactivos en lugar de en vivo, menos datos de duración | Diseño del detalle de la rutina | Media | Medio | «Empezar» arriba; explicar «Ya lo hice» | M-13 (P1) |
| R-17 | **Desconfianza en el plan** por textos internos («pendiente de validación profesional») | `GET /plan/limitations` en la primera pantalla de Rutinas | Media | Medio | Contenido acordado y plegado | M-14 (P1) |
| R-18 | **Lectura difícil** para personas mayores o con baja visión | Texto de 8–11 px; contraste 2,85–3,1:1 | Media | Medio | Tamaños y colores mínimos | M-19 (P1) |
| R-19 | **Participantes con iPhone** sin push ni prueba alguna | Push solo Android; iOS nunca compilado | Desconocida | Alto si los hay | Decidir si el estudio es solo Android; si no, plan de iOS | M-23 (P1/decisión) |
| R-20 | **Borradores de «Ya lo hice» perdidos** si Android cierra la app | P3 conocido, fuera de alcance | Baja | Bajo | P3 cuando se autorice | M-36 (P2) |
| R-21 | **Activar `enforce-on-signup` en el Backend** sin cambiar Mobile → ningún registro funciona | Mobile no envía las versiones aceptadas | Baja (requiere acción) | Alto | Coordinar el cambio | M-03 (P0 condicionado) |

## 2. Seguridad y privacidad en Mobile

| Punto | Estado | Evidencia | Hallazgo |
|---|---|---|---|
| Almacenamiento del JWT | ✓ `flutter_secure_storage` 10 (Keystore/Keychain), una sola configuración | `core/storage/secure_storage.dart`, `token_storage.dart` | — |
| Datos locales sensibles | ✓ En almacenamiento seguro, clave por cuenta: progreso del recorrido, recordatorios, favoritos, resultados pendientes. Sin datos de salud del perfil en el teléfono | `local_account_data.dart` | — |
| Persistencia P1 | ✓ Solo el cuerpo del `PUT` (cantidades y motivo), sin JWT ni correo; ligado al id numérico | `pending_results_store.dart` | — |
| Separación entre cuentas | ✓ Clave por usuario y comprobación del `userId` de cada entrada | `pending_results_persistence_test.dart` | Guía S15 pendiente en teléfono |
| Caducidad de pendientes | ✓ 48 h; descartados con aviso | ídem | — |
| Eliminación de datos locales | ✓ Al eliminar la cuenta borra las 4 claves y el token. Al cerrar sesión se conservan (por cuenta) favoritos, recordatorios y pendientes 48 h, por diseño | `local_account_data.dart`, `auth_viewmodel.dart:102` | — |
| Copia de seguridad de Android | **Riesgo**: el manifiesto no define `android:allowBackup` ni reglas de copia (por defecto activa). Las preferencias cifradas pueden restaurarse en otro teléfono sin la clave del Keystore | `android/app/src/main/AndroidManifest.xml` | M-22 (P1): verificar en teléfono restaurando una copia; definir `allowBackup="false"` o reglas que excluyan el almacenamiento seguro |
| Logs | ✓ Sin `LogInterceptor` de Dio; el observador de Riverpod solo en debug. `debugPrint` en recordatorios (texto de la excepción) y en códigos P2 desconocidos (código y fecha): no contienen datos personales, pero aparecen en `logcat` también en release | `main.dart:44`, `reminder_scheduler.dart:82,132`, `adaptation_text.dart:100` | Aceptable |
| Permisos Android | `INTERNET`, `RECEIVE_BOOT_COMPLETED`; `POST_NOTIFICATIONS` (del plugin); sin alarmas exactas, sin ubicación, sin cámara | `AndroidManifest.xml` | ✓ |
| HTTP en claro | Solo en debug (`src/debug/AndroidManifest.xml`); release exige `https://` público, bloqueado también por Gradle | `api_config.dart`, `api_config_test.dart` | ✓ |
| Archivos de Firebase | `google-services.json` y `firebase_options.dart` versionados: son identificadores de cliente, no secretos de servidor. La clave de API de Android debe estar **restringida** al paquete `pe.fit.kora` y su huella en Google Cloud (no verificable desde aquí) | `android/app/google-services.json` | Verificar restricción (P2) |
| Endpoints protegidos | ✓ JWT en todo salvo login, registro y recuperación; un 401 cierra la sesión una sola vez | `auth_interceptor.dart` | El router no tiene guarda de sesión (`/dashboard` se abre sin sesión y muestra errores); la protección real es el Backend (P2) |
| Sesiones expiradas | ✓ Mensaje y vuelta al login; cambio de contraseña revoca el JWT (verificado) | `session_expiry_test.dart` | — |
| Envíos duplicados | ✓ Bloqueo por ejercicio (`sending`), botones deshabilitados mientras `busy`, reconciliación con `/sessions/current` antes de iniciar, comprobación de la sesión antes de reenviar un resultado dudoso. Backend: finalizar dos veces → 422, omitir dos veces → 204 | `planned_workout_page.dart`; contratos hoy | ✓ |
| Eludir O20 | ✓ No es posible desde Mobile: confirma la rutina con el Backend antes de cada envío (8 s máx.), retiene lo que ya no es válido y el Backend rechaza con 422 en cualquier caso. Ninguna pantalla decide que un ejercicio es seguro | `pain_safety.dart`, `docs/o20/validacion/evidencia/pruebas-seguridad-o20.txt` | ✓ |
| Eludir reglas del Backend en general | ✓ Las reglas de inicio, informe, omisión y D-M1 se reflejan en Mobile solo para ofrecer acciones válidas; el Backend valida todo | `workout_rules.dart` | — |
| Artefactos de compilación en el repositorio | `android/build/reports/problems/problems-report.html` versionado | `git ls-files android/build` | P2 (limpieza) |

**Conclusión de seguridad:** no se encontró ninguna vía en Mobile para saltarse las reglas del Backend ni datos sensibles
expuestos. Los riesgos son de configuración (copia de seguridad de Android, restricción de la clave de Firebase) y
deben comprobarse en un teléfono y en la consola de Google Cloud.

## 3. Preparación para Android físico

### 3.1 Qué se ha probado en un teléfono real

**Nada.** Ningún documento del repositorio registra una ejecución en un teléfono o emulador; la guía lo dice
expresamente (`docs/o20/validacion/GUIA_ANDROID.md:3`). Todo lo demás (APK compilados, AAB, alineación de 16 KB,
identificador `pe.fit.kora`) se verificó por inspección de artefactos. Esta auditoría tampoco tuvo teléfono.

### 3.2 Revisión de `docs/o20/validacion/GUIA_ANDROID.md`

| Aspecto | Valoración | Observación |
|---|---|---|
| Compatibilidad con Windows | ✓ | Comandos de PowerShell, `curl.exe`, `New-NetFirewallRule` |
| Android Studio | ✓ | Ruta del SDK, plugins, configuración de ejecución con `--dart-define` |
| Flutter | ✓ | 3.50.1, igual que CI |
| ADB por USB | ✓ | Depuración USB explicada |
| ADB inalámbrico | ✓ | `adb pair` / `adb connect` (Android 11+) |
| `adb reverse` | ✓ | Opción recomendada, con comprobación `adb reverse --list` y prueba desde el navegador del teléfono |
| Wi-Fi | ✓ | IP del PC, cortafuegos, `netstat` para `0.0.0.0:8080` |
| URL del Backend | ✓ | Avisa de que `10.0.2.2` solo vale para el emulador |
| Configuración Firebase | **Desactualizada** | Dice «sin `google-services.json` la app compila, pero sin push»; el archivo **ya está en el repositorio**. Falta explicar que un Backend local sin credenciales de servidor de Firebase no envía push, así que la recepción no se puede probar con él |
| Arranque del Backend | **Incompleto** | `java -jar target\…jar` sin indicar cómo compilarlo (`mvnw package -DskipTests`) ni los parámetros obligatorios («añade tus parámetros habituales»). Con `fitsense.password-reset.delivery=dev-log` el Backend no arranca sin el perfil `local-dev` (comprobado hoy) |
| Inicio de sesión | ✓ | Con usuario 48 (solo lectura) y cuenta sintética |
| Capturas y logs | ✓ | `adb logcat`, `screencap`, `screenrecord` |
| Usuario demo | ✓ | Solo lectura, consultas SQL previas, ventana del cierre semanal (lunes 02:30–04:00 Lima) |
| Cuenta sintética | ✓ | S1–S17 cubren O20, P1, D-M1 y cambio de cuenta |

### 3.3 Lo que la guía no cubre y debe añadirse antes del piloto

| Prueba | Por qué |
|---|---|
| Registro **sin** marcar la participación | Comportamiento de M-01 en el teléfono (debe cambiar antes) |
| Explicación de avisos → permiso de Android 13+ → «Activar» y «Ahora no» | Primer contacto con permisos |
| Recepción de un push real (`PLAN_GENERATED`) con la app abierta, en segundo plano y cerrada, y su apertura | Nunca comprobado; requiere un Backend con credenciales de Firebase (entorno de pruebas, no producción) |
| Recordatorios: activarlos en Perfil, recibir el del día, tocarlo con la app cerrada, reinicio del teléfono | Nunca comprobados; tocar con la app cerrada no navega (M-32) |
| Ahorro de batería (Samsung) | Puede retrasar avisos (`docs/push/PRUEBAS_PUSH_E_IDENTIFICADOR.md`) |
| Actualización sobre una versión anterior sin desinstalar | Migración de `flutter_secure_storage` 9→10 pendiente (`PRUEBA_ACTUALIZACION_SAMSUNG.md`) |
| Restaurar una copia de seguridad en otro teléfono | M-22 |
| Texto grande del sistema (130–200 %) y pantalla de 5″ | Cortes de texto (M-19) |
| Recuperación de contraseña de punta a punta | Cuando haya correo (M-04) |
| Sesión de 40 min con pantalla encendida: batería, temperatura, fluidez con los GIF | Rendimiento real |
| Modo avión durante la generación del primer plan | Retoma (`caso-sin-conexion` solo probado en web) |

**Criterio de salida:** tabla de la guía §7 más las filas anteriores con OK/FALLA, modelo y versión de Android, y los
`logcat` de cada fallo, en al menos dos teléfonos (uno de gama baja con Android 11–13 y uno con Android 15–16).
