# 11 · Documentos visualizados en Flutter: revisión y correcciones

Orden: «Corrección del flujo de documentos y conservación de la integración existente». Fecha: 28/11/2026.

| | |
|---|---|
| Mobile `generation` revisado | `ba55e1dd55f3a9cca2162db6778c1154c815b3b2` (#33, #34 y #35 fusionadas) |
| Backend de referencia | `generation` `9aa7abf` (#96–#98 y #100; ninguno cambia el registro ni los documentos) |
| Contrato del Backend | `docs/FitSense/integracion_final_estudio/09_CONTRATO_MOBILE.md` (Backend #100) |
| Rama de esta revisión | `claude/mobile-documentos-formato-enlaces` (PR abierta, **sin fusionar**) |

## 1. Lo que ya funcionaba y no se tocó

| Requisito de la orden | Estado en `generation` | Cómo se comprobó |
|---|---|---|
| Documentos leídos dentro de Flutter (el Backend solo da tipo, versión y dirección) | ✓ El lector descarga el texto o HTML de la `url` y lo muestra en la app | Pruebas y app real |
| Abrir, leer y volver al registro | ✓ «Leer» → lector → «He leído el documento» o «Volver» | Pruebas y app real |
| Casilla sin marcar por defecto | ✓ Ninguna; se activa al leer el documento | Pruebas |
| Una aceptación por documento (sin consolidar) | ✓ Condiciones, privacidad y participación en casillas separadas | Pruebas |
| Consentimiento informado del estudio (opción A) | ✓ Obligatorio; «No deseo participar» no crea cuenta | Pruebas y app real |
| Política de privacidad accesible | ✓ Con su propia casilla, que exige el contrato (`acceptedPrivacyVersion`); el texto se adapta a `privacyRecord` | Pruebas |
| Registro cerrado sin documentos aprobados | ✓ «El registro todavía no está abierto» | App real contra `9aa7abf` |
| Versiones vigentes; si cambian, revisar de nuevo | ✓ Se comprueban antes de enviar; «Los documentos cambiaron» | App real (`T-QA-1` → `T-QA-2`) |
| Documento que no se puede abrir no cuenta como leído | ✓ Para direcciones rotas; **faltaba para un PDF** (§2) | Pruebas |
| Contrato: `type`, `version`, `url`, `status`, `requiredForSignup`, las cuatro versiones y los códigos | ✓ Sin cambios | Contrato en vivo 11/11 |
| Login tras registrarse, cierre de sesión sin 401, cambio de cuenta, retirada (también durante la generación) | ✓ | App real y pruebas en vivo |

**`requiredForSignup`:** Mobile exige siempre los tres documentos (opción A). Eso coincide con `requiredForSignup=true` en
el registro definitivo. Con la exigencia apagada (`false`), Mobile sigue pidiendo leerlos y aceptarlos, que es más
estricto y compatible. No hizo falta cambiar nada.

## 2. Defectos encontrados y corregidos

Los tres se reprodujeron **antes** de corregirlos.

| # | Defecto | Reproducción | Corrección |
|---|---|---|---|
| D-1 | Un documento publicado como **PDF** (o imagen, o archivo binario) se mostraba como caracteres ilegibles y se podía recorrer hasta el final y **aceptar** | `DocumentTextRepository.fetch` con `application/pdf` devolvía el contenido como texto | Solo se muestran texto y HTML (por `Content-Type` y, si falta, por el contenido). Lo demás: «El documento no está en un formato que Kora pueda mostrar (texto o HTML). Contacta al equipo del estudio.», con «Reintentar» y sin «He leído el documento» |
| D-2 | Los **enlaces** de un documento HTML perdían su destino: «Escribe a el equipo o visita esta página.» (desaparecían el correo y la dirección) | `plainText` quitaba la etiqueta `<a>` con su `href` | El enlace se muestra con su destino: «el equipo del estudio (equipo@estudio.example)». Al ser texto seleccionable, se puede copiar |
| D-3 | En un teléfono pequeño (320 × 568) con el **texto del sistema al 200 %**, el lector **se desbordaba 173 px**: el título y la versión fijos no dejaban sitio al documento | Prueba de interfaz a 320 × 568 y escala 2,0 | Arriba solo queda una barra compacta (volver y el título en dos líneas como máximo). El título completo y la versión abren el texto desplazable |

Además, una cabecera `Content-Type` repetida (la enviaba el servidor de pruebas) ya no impide abrir el documento.

**Sin cambios** en el registro, el contrato, los textos de las casillas ni ninguna otra pantalla.

## 3. Pruebas

`test/document_reader_test.dart` (7 pruebas nuevas):

| Prueba | Qué comprueba |
|---|---|
| Texto y HTML se muestran; cabecera repetida | Compatibilidad |
| PDF, binario sin cabecera e imagen | No se pueden abrir (D-1) |
| Enlaces | Conservan su destino (D-2) |
| PDF en el lector | Mensaje y «Reintentar»; vuelve con `false` (no leído) |
| Lector a 320 × 568 al 200 % | Sin desbordamiento; se llega al final; vuelve con `true` (D-3) |
| Registro a 320 px al 200 % | Todos los documentos, casillas y «No deseo participar» alcanzables, sin desbordes |
| Giro del teléfono y desplazamiento | Las aceptaciones se conservan |

`flutter analyze`: sin incidencias. `flutter test`: **529 aprobadas · 0 fallidas · 44 omitidas** (522 + 7). Ninguna prueba
existente se modificó.

## 4. Pruebas contra el Backend local `9aa7abf`

Entorno aislado (base `kora_documentos_9aa`), documentos **sintéticos** por HTTPS local, IA apagada, cuentas
`@audit.local`. Evidencia: [`evidencia/documentos_flutter/recorridos-y-contrato-9aa7abf.txt`](evidencia/documentos_flutter/recorridos-y-contrato-9aa7abf.txt).

| # de la orden | Prueba | Resultado |
|---|---|---|
| 1 | Registro cerrado sin documentos | ✓ |
| 2–4 | Abrir las condiciones, leer, volver; casilla desmarcada | ✓ |
| 5 | Registro rechazado sin aceptación requerida | ✓ (422 `CONSENTIMIENTO_REQUERIDO` y `VERSION_NO_VIGENTE`; la app no envía sin las aceptaciones) |
| 6 | Consentimiento informado | ✓ |
| 7 | Política de privacidad accesible (HTML con enlaces) | ✓ ([captura](capturas/documentos_flutter/D-02-documento-con-enlaces.jpg)) |
| 8 | Documento inaccesible (PDF publicado) | ✓ No se puede leer ni aceptar ([captura](capturas/documentos_flutter/D-01-documento-pdf.jpg)) |
| 9–10 | Versión desactualizada y cambio antes de confirmar | ✓ |
| 11 | Registro con versiones vigentes (sintéticas) | ✓ Envía las cuatro versiones |
| 12 | Rechazar participar | ✓ Ninguna petición |
| 13 | Usuario retirado | ✓ Estado de retirada; ninguna generación |
| 14 | Retirada durante la generación (IA simulada) | ✓ No se publica; la app muestra la retirada; una sola petición |
| 15 | Login tras el registro | ✓ |
| 16 | Cierre de sesión sin solicitudes tardías | ✓ 0 respuestas 401 |
| 17 | Cambio rápido de cuenta | ✓ Prueba automática (respuestas lentas) y app real |
| 18 | O20, D-M1, P1, P2 | ✓ Sus pruebas automáticas, sin cambios, en verde |

También: 429 (mensaje del Backend sin códigos), pérdida de conexión al crear la cuenta (una sola cuenta) y contrato en
vivo 11/11.

## 5. Probar Kora en tu teléfono Android

Ninguna de las 46 comprobaciones de la matriz
([`12_MATRIZ_DOS_TELEFONOS.csv`](../cierre_preproduccion/12_MATRIZ_DOS_TELEFONOS.csv)) se ha ejecutado: siguen
**pendientes**. Para probar con tu teléfono (compilación de **desarrollo**, nunca de producción ni de Google Play):

**Preparación (una vez)**
1. En el teléfono: Ajustes › Acerca del teléfono › tocar 7 veces «Número de compilación». Después, Opciones de
   desarrollador › «Depuración USB».
2. En el PC: Flutter y Android SDK instalados. `flutter doctor` debe mostrar el SDK de Android sin errores.
3. Conectar el teléfono por USB y aceptar «¿Permitir depuración USB?». `adb devices` debe listarlo como `device`.

**Backend de pruebas en el PC:** `docs/integracion_final_estudio/qa_android/1_backend_de_pruebas.ps1`. Usa una base
local nueva, la IA apagada y documentos sintéticos solo si se quieren probar los documentos. Para el teléfono, los
documentos deben estar en una dirección `https` con un certificado válido (Android no acepta certificados propios).

**Opción A: USB (recomendada)**

```powershell
.\docs\integracion_final_estudio\qa_android\2_compilar_qa.ps1 -Telefono <id de adb devices>
```

El script hace `adb reverse tcp:8080 tcp:8080` (así `127.0.0.1:8080` del teléfono es tu PC) e instala con
`flutter run --debug`.

**Opción B: misma red Wi-Fi (sin cable)**

```powershell
flutter run --debug -d <id> --dart-define=API_BASE_URL=http://<IP-del-PC>:8080/api/v1 --dart-define=ALLOW_INSECURE_API=true
```

El PC y el teléfono deben estar en la misma red, y el cortafuegos de Windows debe permitir el puerto 8080. No uses
`10.0.2.2`: solo funciona en el emulador.

**Evidencia de cada fila:** `3_evidencia.ps1 -Telefono <id> -Fila <N.º>` guarda modelo, versión de Android, commit,
captura y `logcat`. Anota en la matriz OK/FALLA/BLOQUEADO, la severidad y los pasos. Antes de compartir el `logcat`,
comprueba que no contenga datos personales.

## 6. Decisiones que te corresponden

| # | Decisión | Situación actual |
|---|---|---|
| 1 | **Formato de los documentos aprobados.** La app muestra texto o HTML sencillo; un PDF no se puede leer en la app | Publicar las versiones aprobadas como texto o HTML (con UTF-8) en una dirección `https`. Si se quiere PDF, haría falta un visor (una dependencia nueva, no autorizada en esta orden) |
| 2 | **¿Exigir llegar al final del documento?** Hoy la casilla se activa solo tras desplazarse hasta el final y pulsar «He leído el documento» | Es más garantista para el consentimiento informado; si prefieres activarla con solo abrir el documento, es un cambio pequeño |
| 3 | **Enlaces pulsables** dentro de los documentos | Hoy se muestran con su destino y se pueden copiar. Para abrirlos con un toque haría falta `url_launcher` (dependencia nueva) |
| 4 | **Forma de la casilla de privacidad** | El contrato exige `acceptedPrivacyVersion`. Con `privacyRecord=CONSTANCIA` la casilla dice «He leído…» en vez de «Acepto…». Lo decide la revisión legal en el Backend |
| 5 | **Correo ya registrado** | Hoy se muestra el mensaje del Backend y se conserva el formulario. El contrato sugiere ofrecer «Iniciar sesión» o «Recuperar contraseña»; no se hizo por estar fuera del alcance de documentos |
