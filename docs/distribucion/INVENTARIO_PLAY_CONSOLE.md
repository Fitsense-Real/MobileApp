# Inventario para Google Play Console

Estado al cierre del Mobile: `generation` con las PR #1–#16 integradas. La migración de la #13 (dependencias) está pendiente de la prueba manual en Android.

**Leyenda:**
- ✓ **cumplido**: en el código o el repositorio;
- ◐ **preparado**: hay borrador o base, falta tu decisión o tu contenido;
- ✗ **pendiente externo**: depende de algo fuera del Mobile.

## 1. Requisitos técnicos de la app

| Requisito | Estado | Dónde |
|---|---|---|
| targetSdk 36 (exigido desde el 31/08/2026) | ✓ | `android/app/build.gradle.kts` |
| Compatibilidad con páginas de 16 KB | ✓ | `PREPARACION_PUBLICACION.md`: `zipalign -P 16` y alineación `LOAD` |
| AAB firmado (ruta verificada con clave desechable) | ✓ | `PREPARACION_PUBLICACION.md`, `FIRMA_Y_AAB.md` |
| Bloqueos de release (HTTPS, sin hosts locales, sin clave debug, sin `com.example`, eliminación y páginas obligatorias) | ✓ | Matriz repetida en las PR #10 y #14 |
| Nombre «Kora», ícono adaptativo, ícono de notificación, pantalla de lanzamiento | ✓ (PR #14) | `PREPARACION_PUBLICACION.md` |
| Recordatorios funcionando en release | ✓ (PR #14) | Fallo del *shrinker* corregido |
| Permisos mínimos, sin alarmas exactas | ✓ | `INTERNET`, `RECEIVE_BOOT_COMPLETED`, `POST_NOTIFICATIONS`, `VIBRATE` |
| Borde a borde y gesto atrás (Android 15/16) | ✓ | `MIGRACION_ANDROID_16.md` |
| Eliminación de cuenta dentro de la app | ✓ | `ELIMINACION_CUENTA_FLUTTER.md`; E2E en la auditoría (`docs/auditoria_final/`) |
| Accesibilidad: GIF fuera de la semántica, textos de Kapi sin procesos internos | ✓ (PR #15) | `AUDITORIA_FUNCIONAL.md` |
| Edad mínima 18 | ✓ | Validación en la app y en el backend |
| Dependencias al día sin perder sesiones | ◐ integradas (PR #13) | **Migración pendiente de validar a mano** en el Samsung SM-A145M o el emulador (`PRUEBA_ACTUALIZACION_SAMSUNG.md`). Bloquea la distribución externa |
| Prueba en Android 13–16 físico o emulador | ✗ (guía lista) | `PRUEBA_ANDROID_WINDOWS_PENDIENTE.md`, en Windows |
| `applicationId` definitivo | ✓ **`pe.fit.kora`** aprobado (Firebase `kora-fitpe`) | Predeterminado en Gradle; transición en `IDENTIFICADOR_APLICACION.md`; ver §5 |
| Clave de subida propia y Play App Signing | ✗ | `FIRMA_Y_AAB.md` §1–5 |
| Backend HTTPS de producción | ✗ | `CONEXION_BACKEND_PRODUCCION.md` |

## 2. Políticas y formularios de Play Console

| Elemento | Estado | Qué falta |
|---|---|---|
| **Política de privacidad** (URL pública) | ✗ | Redactarla con el comité de ética y publicarla. Debe decir qué datos se recogen, para qué (estudio de adherencia), dónde se guardan, cuánto tiempo, quién accede y cómo pedir el borrado. Se pasa en `PRIVACY_POLICY_URL` |
| **Página web de eliminación de cuenta** (URL pública) | ✗ | El backend ya tiene `/api/v1/account-deletion/*`. Falta la página y su URL (`ACCOUNT_DELETION_WEB_URL`), y que explique qué se borra y qué registro anónimo se conserva |
| **Seguridad de los datos (*Data Safety*)** | ◐ borrador abajo | Confirmarlo con el comité y con lo que haga el backend desplegado |
| **Declaración de apps de salud** | ✗ | Formulario de Play para apps de salud y fitness. Kora es de **fitness y bienestar con investigación**: no diagnostica ni trata, no es un dispositivo médico y no usa Health Connect. Falta la aprobación del comité de ética y un aviso en la ficha («no sustituye consejo médico») |
| **Público objetivo y contenido** | ◐ | 18+ (la app ya lo valida). Sin contenido para menores |
| **Clasificación de contenido** (cuestionario IARC) | ✗ | Rellenarlo: sin violencia, sin compras, sin interacción entre usuarios ni contenido generado por ellos. Resultado esperado: apta para todos o equivalente |
| **Anuncios** | ✓ «No contiene anuncios» | No hay SDK de publicidad |
| **Acceso a la app (credenciales para el revisor)** | ✗ | Crear en el backend de producción una cuenta de prueba con perfil y plan, y escribir en Play Console el correo, la contraseña y los pasos («Inicia sesión → Inicio → Rutinas»). Nunca una cuenta de un participante |
| **Apps gubernamentales, financieras o de noticias** | ✓ No aplica | |
| **Verificación del desarrollador** (identidad o D-U-N-S si es organización) | ✗ | Trámite de la cuenta de Play Console |
| **Prueba cerrada: 12 evaluadores durante 14 días** (cuentas personales nuevas) | ✗ | Puede hacerse con el grupo beta (`DISTRIBUCION_BETA.md` §5) |

### Borrador de «Seguridad de los datos»

Basado en el código de la app. Revisarlo con el backend desplegado y con la política aprobada.

| Pregunta | Respuesta propuesta |
|---|---|
| ¿Recoge o comparte datos? | Recoge. **No comparte** con terceros: sin analítica ni publicidad. Usa **Firebase Cloud Messaging** (Google) como proveedor que solo entrega las notificaciones push, con el token FCM del dispositivo; en Play eso es un proveedor de servicio, no «compartir» |
| Cifrado en tránsito | Sí, HTTPS obligatorio en release |
| ¿El usuario puede pedir que se borren? | Sí, dentro de la app y en la web |
| Información personal | Nombre, correo |
| Salud y fitness | Datos de salud: sexo biológico (opcional), fecha de nacimiento, estatura, peso, notas de salud, limitaciones de movimiento y exclusiones por dolor. Datos de fitness: nivel, objetivo, días y minutos disponibles, equipamiento, entrenamientos realizados, esfuerzo y satisfacción |
| Actividad en la app | Interacciones con el plan: entrenamientos completados u omitidos y sus motivos |
| Identificadores del dispositivo u otros | **Sí:** token de registro FCM, para enviar las notificaciones push de la app. Se guarda en el backend asociado a la cuenta y se borra al cerrar sesión o eliminar la cuenta |
| Ubicación, contactos, fotos, audio, archivos, mensajes, calendario, identificadores de publicidad | **No** |
| Finalidad | Funcionalidad de la app (plan personalizado) e investigación del estudio. No publicidad ni marketing |
| ¿Obligatorios u opcionales? | La cuenta y el perfil son necesarios para el plan; el sexo biológico y las notas de salud son opcionales |
| Datos solo en el teléfono | Token de sesión, progreso del recorrido, preferencias de recordatorios y favoritos, cifrados en el almacenamiento seguro. No salen del teléfono |

## 3. Ficha de la tienda

| Recurso | Estado | Detalle |
|---|---|---|
| Nombre (≤ 30) | ◐ | «Kora» o «Kora: entrena a tu ritmo» |
| Descripción corta (≤ 80) | ◐ borrador | «Tu plan de entrenamiento semanal, a tu ritmo, con Kapi como compañía.» |
| Descripción completa (≤ 4000) | ◐ borrador abajo | Revisarla con el comité: debe mencionar el estudio y no prometer resultados de salud |
| Ícono 512 × 512 | ✓ (PR #14) | `docs/preparacion_google_play/recursos/icono-play-512.png` |
| Capturas de teléfono (mín. 2, 9:16) | ◐ borradores | `capturas_ficha/`: 6 capturas de **1080 × 1920** con datos sintéticos (bienvenida, «Generando» con Kapi, recorrido, inicio, rutinas, detalle de rutina). Se regeneran con `capturas_ficha/generar.js` |
| Gráfico destacado 1024 × 500 | ✗ | Pieza de diseño |
| Categoría | ◐ | Salud y bienestar |
| Correo de contacto, sitio web | ✗ | Del equipo del estudio |
| Países e idioma | ◐ | Español (Latinoamérica); países según el estudio |

### Borrador de la descripción completa

> Kora te acompaña a entrenar con constancia, no con perfección.
>
> Cuéntale tu objetivo, tu nivel, los días y minutos que tienes y el equipo con el que cuentas, y recibe un plan semanal
> pensado para ti. Cada entrenamiento te muestra los ejercicios con su animación, series, repeticiones o tiempo, y
> descansos. Registra lo que hiciste, aunque sea parcial, y Kora ajusta la semana siguiente a tu ritmo.
>
> Kapi, la capibara de Kora, te guía por la app y te acompaña mientras preparamos tu plan.
>
> - Plan semanal según tus días, tiempo y equipamiento (peso corporal incluido).
> - Entrenamientos con cronómetro, descansos e instrucciones.
> - Registro de lo completado, lo parcial y lo que no pudiste hacer.
> - Recordatorios de tus entrenamientos.
> - Tu progreso y los ajustes del plan, explicados.
>
> Kora forma parte de un estudio sobre adherencia al ejercicio. No sustituye el consejo de un profesional de la salud;
> si tienes una condición médica, consulta antes de empezar. Puedes eliminar tu cuenta y tus datos desde la app en
> cualquier momento.

## 4. Orden recomendado

1. Crear la clave de subida (el `applicationId` `pe.fit.kora` ya está aprobado) y subir los archivos de Firebase a la PR de push.
2. Validar a mano la actualización de la PR #13 (ya integrada) en el Samsung o el emulador.
3. Desplegar el backend HTTPS (`CONEXION_BACKEND_PRODUCCION.md`), con S-1 y B-6 resueltos.
4. Publicar la política de privacidad y la página de eliminación.
5. Beta por App Distribution (`DISTRIBUCION_BETA.md`).
6. Play Console:
   - ficha;
   - seguridad de los datos;
   - declaración de salud;
   - clasificación;
   - acceso del revisor;
   - prueba cerrada de 12 × 14 días;
   - producción.

## 5. Identificador `pe.fit.kora`: qué se comprobó y qué falta

Es **permanente**: cuando una app se publica (incluso en una prueba cerrada) o se sube su primer AAB, Play no deja
cambiarlo. Cambiarlo después sería otra app, con otra ficha, sin los usuarios ni las reseñas.

| Comprobación | Resultado |
|---|---|
| Formato válido de paquete Android (minúsculas, segmentos que empiezan por letra, sin palabras reservadas de Java) | ✓ |
| Compila y empaqueta con ese identificador (predeterminado; APK debug y release de prueba inspeccionados) | ✓ (`PREPARACION_PUBLICACION.md`) |
| El código no depende del identificador (el `namespace` de Kotlin sigue en `com.example.fitsense_mobile`, que no se publica) | ✓ |
| Que no exista ya una app pública con ese identificador en Play | **No verificable desde este entorno** (la red no llega a Play). Comprobar <https://play.google.com/store/apps/details?id=pe.fit.kora>: debe dar «no encontrado» |
| Que esté disponible para tu cuenta | **Solo Play Console lo confirma**, al crear la app y subir el primer AAB. Si estuviera tomado, la subida lo rechaza |
| Convención de dominio invertido (`fit.pe`) | Decisión del propietario. Play no lo exige |
| Coherencia con Firebase | La app de App Distribution debe registrarse con el **mismo** identificador definitivo |

Aprobado: el código usa `pe.fit.kora` por defecto. El AAB para Play solo acepta ese identificador y exige el
`google-services.json` de `kora-fitpe`.
