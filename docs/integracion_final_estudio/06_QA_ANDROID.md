# 06 · QA en Android físico (M5)

**Estado: PENDIENTE DE DISPOSITIVO. Ninguna prueba física realizada.** Este entorno no tiene teléfono ni emulador. Todo
lo que sigue es para que lo ejecute el propietario. Las pruebas en navegador y las automáticas **no** cuentan como
pruebas Android.

## 1. Teléfonos

| | Teléfono 1 | Teléfono 2 |
|---|---|---|
| Gama | Baja | Media |
| Android | 11–13 | 15–16 (la más reciente disponible) |
| Para qué sobre todo | Rendimiento, memoria, texto grande, ahorro de batería | Permisos de Android 13+ (notificaciones), comportamiento de `targetSdk 36` |

## 2. Preparación (scripts en [`qa_android/`](qa_android/))

| Paso | Script | Qué hace |
|---|---|---|
| 1 | `1_backend_de_pruebas.ps1` | Backend de **pruebas**: base nueva `kora_qa_android`, IA y push apagados, correo `dev-log`, documentos **sintéticos** publicados con «PRUEBA-QA-SINTETICA (no es una aprobacion real)» y exigencia encendida **solo ahí**. `-VersionTerminos T-QA-2` para A6; `-SinDocumentos` para A7 |
| 2 | `2_compilar_qa.ps1 -Telefono <id>` | `adb reverse tcp:8080`, anota el commit (la «Versión de Kora») e instala una compilación **debug** con `API_BASE_URL=http://127.0.0.1:8080/api/v1` y la recuperación encendida **solo en esta compilación**. **No** genera una APK de producción ni de Google Play |
| 3 | `3_evidencia.ps1 -Telefono <id> -Fila D8` | Guarda el modelo, la versión de Android, el commit, la captura, el `logcat` y, si se pide, un vídeo |

**Documentos sintéticos:** los textos están en [`evidencia/documentos_sinteticos/`](evidencia/documentos_sinteticos/).
Para el teléfono hay que publicarlos en una dirección `https` con un certificado válido que controle el equipo: el
Backend exige `https`, y Android no acepta certificados propios. Nunca se presentan como aprobados.

**Cuentas:** solo sintéticas. El usuario 48 solo se consulta, según la guía base (`docs/o20/validacion/GUIA_ANDROID.md`,
actualizada con la #25). El push real (E6) solo con un Backend de pruebas con credenciales autorizadas y **nunca hacia
participantes reales**.

## 3. Matriz

[`docs/cierre_preproduccion/12_MATRIZ_DOS_TELEFONOS.csv`](../cierre_preproduccion/12_MATRIZ_DOS_TELEFONOS.csv),
actualizada en esta orden: pasa de 27 a **46 comprobaciones** para cubrir todas las de la orden §8. La columna «Fila
anterior» enlaza con la matriz de 27.

| Bloque | Filas | Contenido |
|---|---|---|
| A · Registro | A1–A7 | Crear cuenta, documentos sintéticos, Perfil › Documentos, rechazar participar, zona horaria, versión cambiada, registro cerrado |
| B · Recuperación | B1–B6 | Solicitar, pegar, cerrar y reabrir, usar, reutilizar, correo real (**BLOQUEADO POR BACKEND**) |
| C · Ejercicios | C1–C7 | Ficha, animación, pausar, ampliar, instrucciones, imagen de respaldo, sin Internet |
| D · Entrenamiento | D1–D10 | Iniciar, 8 ejercicios, parcial por series, dolor, O20, perder Internet, cierre forzoso, reabrir, recuperar P1, reenviar sin duplicar |
| E · Notificaciones | E1–E6 | Permisos, recordatorios, app cerrada, abrir desde el aviso, registro FCM, push real (**PENDIENTE**: credenciales) |
| F · Accesibilidad y plataforma | F1–F10 | Texto 130 % y 200 %, TalkBack, teclado, pantalla pequeña, cambio de cuenta, actualización, copia de seguridad, ahorro de batería, 40 minutos |

Por cada fila y teléfono se anota: **modelo, versión de Android, versión de Kora (commit), fecha, resultado
(OK/FALLA/BLOQUEADO), evidencia, pasos para reproducir el fallo y severidad.** Hoy todas las filas dicen PENDIENTE
(B6: BLOQUEADO POR BACKEND; E6: pendiente de credenciales).

**Severidad sugerida:** crítica (pérdida de datos, acceso entre cuentas, registro de un consentimiento que no
corresponde, envío duplicado), alta (bloquea una tarea del estudio), media (hay un rodeo), baja (estética).

## 4. Qué ya está cubierto fuera del teléfono (no sustituye a la matriz)

| Bloque | Cubierto por |
|---|---|
| A | Pruebas automáticas (registro: 27; consentimientos: 6) y recorridos en navegador contra el Backend `41c498a` ([04](04_CONTRATOS_BACKEND.md)) |
| B | Pruebas automáticas y recorrido en navegador contra el Backend local ([05](05_RECUPERACION_CUENTA.md)) |
| C, D | Pruebas automáticas (ficha, registro de entrenamientos, D-M1, O20, P1) y pruebas en vivo de D-M1/O20 de la orden anterior |
| E | Contrato de dispositivos en vivo con FID ficticios; **nunca** se recibió un push real |
| F | Pruebas de diseño en 320 px y texto 1,5×; TalkBack, teclado real y rendimiento **sin probar** |

## 5. Al terminar

Enviar la matriz rellena y la carpeta `evidencia_qa/` de cada fallo (comprobando que el `logcat` no contenga datos
personales). Los fallos críticos o altos bloquean preproducción ([09](09_PENDIENTES_PARA_PREPRODUCCION.md)).
