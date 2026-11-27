# 07 · Plan de cierre de Mobile antes del piloto y del estudio de 12 semanas

Este plan ordena los 41 pendientes de la [matriz](08_MATRIZ_DE_PENDIENTES.md) (**5 P0 · 22 P1 · 14 P2**) en fases, con
sus dependencias y criterios de aceptación. **No se implementa nada en esta auditoría.** Cada tarea se haría en una rama
y PR propias, con `flutter analyze` y `flutter test` en verde, sin tocar O20, P1, P2 ni D-M1 salvo donde se indique, y
sin modificar el Backend desde Mobile.

## Criterios de prioridad aplicados

| Prioridad | Criterio | Por qué esa clasificación |
|---|---|---|
| **P0** | Sin resolverlo no se puede iniciar el piloto: impide usar Kora, invalida el consentimiento, deja sin acceso o no se ha probado nunca en un teléfono | M-01 bloquea a quien no marca una casilla «opcional»; M-02 afecta a la validez ética; M-03 bloquea todos los registros si se activa una opción del Backend; M-04 deja sin acceso durante 12 semanas; M-05 nada se ha ejecutado en un teléfono |
| **P1** | Kora funciona, pero la comprensión, la seguridad del participante o la calidad de los datos se resienten de forma medible | Ejercicios (M-06, M-07, M-09, M-12, M-13), registro (M-10, M-11), progreso (M-15), recordatorios (M-16), accesibilidad (M-19), textos que contradicen la realidad (M-14, M-17) |
| **P2** | Mejora sin impacto crítico en el uso ni en la adherencia | Código sin uso, textos menores, atajos, funciones que el Backend no tiene y no son imprescindibles |

## Fase 0 · Decisiones previas (no son código)

Sin estas decisiones las tareas de Mobile no pueden cerrarse. Responsable sugerido entre paréntesis.

| # | Decisión | Desbloquea | Responsable |
|---|---|---|---|
| D1 | ¿Kora solo para participantes o también para usuarios habituales? | M-01, M-17 | Producto + equipo del estudio + Backend |
| D2 | Textos aprobados: consentimiento informado (versión), condiciones de uso, política de privacidad, qué datos se recogen | M-02, M-03, M-27 | Equipo del estudio / comité de ética / legal |
| D3 | Proveedor de correo y remitente; ¿enlace con App Links o solo código? | M-04, M-26 | Backend / infraestructura |
| D4 | Licencia y alojamiento de las animaciones | M-06, M-09 | Legal + Backend |
| D5 | Política de recordatorios (todos / ninguno / elección registrada) | M-16 | Equipo del estudio |
| D6 | ¿Se muestra el riesgo de abandono al participante? | M-15 | Equipo del estudio |
| D7 | Descripciones de la escala de esfuerzo y de satisfacción; ¿se recogen observaciones? | M-11 | Equipo del estudio (+ Backend si hay observaciones) |
| D8 | Texto de seguridad ante el dolor y contacto del equipo | M-24, M-40 | Equipo del estudio |
| D9 | ¿Qué puede cambiar del perfil durante el estudio? | M-25, M-38 | Producto + Backend + protocolo |
| D10 | ¿Habrá participantes con iPhone? | M-23 | Producto + equipo del estudio |
| D11 | Textos de «Lo que tu plan no puede cubrir» visibles para participantes | M-14 | Backend + equipo del estudio |

## Fase 1 · P0 (bloquean el piloto)

| ID | Tarea de Mobile | Dependencia | Criterio de aceptación | Tamaño orientativo |
|---|---|---|---|---|
| M-01 | Según D1: (A) participación como condición explícita del registro con su consentimiento, y mensaje claro si se rechaza; o (B) mantener la casilla opcional cuando el Backend genere planes a no participantes. En ambos casos, la pantalla «Tu perfil está guardado…» ofrece cerrar sesión y contacto | D1, Backend en (B) | Prueba de registro con y sin participación contra el Backend de pruebas y en teléfono: ninguna cuenta llega al perfil sin poder recibir un plan; ningún «Reintentar» que siempre falle | Medio |
| M-02 + M-03 + M-27 | Registro en dos pasos: datos de la cuenta; documentos (condiciones, privacidad, consentimiento del estudio) leídos dentro de la app con su versión; envío de `acceptedTermsVersion`, `acceptedPrivacyVersion` y `acceptsStudyParticipation` en el mismo registro; «Ver lo que aceptaste» en Perfil | D2; Backend: servir texto/URL por versión y publicar versiones | Con versiones publicadas y `enforce-on-signup=true`, el registro funciona y el historial guarda la versión mostrada. Sin versiones publicadas no aparece ninguna aceptación simulada | Grande |
| M-04 | Encender `PASSWORD_RECOVERY_ENABLED` en la compilación del estudio; «Ya tengo un código» y «Pegar código»; mensajes de caducidad y reenvío; (opcional) App Links | D3; Backend con correo real | Con correo real y cuenta sintética: recuperación completa en < 3 min, código caducado y sin red probados, JWT anterior revocado; repetido en teléfono | Pequeño (sin App Links) / Medio (con App Links) |
| M-05 + M-39 | Actualizar la guía Android (Firebase, arranque del Backend, pruebas de 06 §3.3) y ejecutarla | Teléfonos; Backend de pruebas con credenciales de Firebase | Tabla OK/FALLA completa en dos teléfonos con logcat de cada fallo; ningún fallo P0 abierto | Medio (ejecución por el propietario) |

**Puerta de salida de la fase 1:** las cinco filas en verde y una ronda en teléfono sin fallos bloqueantes.

## Fase 2 · P1 (antes de iniciar el estudio)

Agrupadas por pantalla para hacer PR coherentes.

| Bloque | IDs | Dependencia | Criterio de aceptación (resumen; detalle en la matriz) |
|---|---|---|---|
| **Detalle de la rutina y del ejercicio** | M-07, M-09, M-12, M-13 (y M-06 cuando esté D4) | M-06: Backend (`gifUrl`/`imageUrl`); M-12 básico: ninguna | Guía de esfuerzo idéntica a la del Backend; ficha con GIF grande y pausa; «Tengo dolor o molestias» en ≤ 2 toques con las mismas reglas O20; «Empezar entrenamiento» visible sin desplazarse en 320 × 568; ninguna URL de GitHub |
| **Registro de resultados** | M-10, M-11 | D7 | Sesión de 8 ejercicios en ≤ 12 toques; registro por series con el mismo cuerpo D-M1 (las pruebas actuales siguen en verde); escala de esfuerzo con textos aprobados |
| **Rutinas e Inicio** | M-14, M-19 | D11 | Primera tarjeta visible sin desplazarse; ningún texto partido a mitad de palabra en 320 px; contraste ≥ 4,5:1 en texto; tamaño mínimo 12–14 px; áreas táctiles ≥ 48 dp |
| **Progreso** | M-15 | D6 | Lenguaje natural; adherencia idéntica al Backend; sin riesgo de abandono salvo decisión contraria; explicación de cuándo habrá datos |
| **Registro y perfil inicial** | M-18, M-38 | — | Ningún registro falla por la zona horaria; resumen del perfil confirmado antes de generar |
| **Avisos** | M-16 | D5 | Comportamiento igual al protocolo, comprobado en teléfono |
| **Cuenta y estudio** | M-17, M-24, M-40, M-26 | D1, D8; M-26: Backend (correo) y web | Retirada con texto real; mensaje de seguridad aprobado al empezar y al informar dolor; contacto del equipo visible; eliminación de cuenta disponible si se distribuye por Google Play |
| **Plataforma** | M-22, M-23, M-25 | D9, D10 | Copia de seguridad restaurada sin errores; decisión de iOS documentada; política de edición del perfil aplicada |

**Puerta de salida de la fase 2:** segunda ronda de la guía Android en teléfono y una prueba con 3–5 personas sin
experiencia en apps de entrenamiento (registrar una sesión completa y una parcial, informar dolor, encontrar su progreso)
sin ayuda.

## Fase 3 · P2 (durante o después del piloto)

M-08 (términos en inglés), M-20 (resultados de sesiones pasadas), M-21 (espera de 30 s ante error), M-28 (cambio de
contraseña con sesión), M-29 (verificación de correo), M-30 (código sin uso), M-31 (textos y menús), M-32 (recordatorio
con la app cerrada), M-33 (guarda de sesión), M-34 (inicio de sesión tras el registro), M-35 («Volver» del paso 1),
M-36 (P3, solo cuando se autorice), M-37 (tildes en textos del Backend), M-41 (restricción de la clave de Firebase).

## Dependencias con el Backend (resumen para coordinar)

| Necesidad | IDs | Tipo |
|---|---|---|
| Servir texto o URL de condiciones, privacidad y consentimiento por versión; publicar versiones | M-02, M-27 | Nuevo endpoint público + configuración |
| Coordinar `enforce-on-signup` con la versión de Mobile que envía las versiones | M-03 | Configuración |
| Proveedor de correo real (recuperación y eliminación web); opcional `link-template` | M-04, M-26 | Configuración / infraestructura |
| Generar planes a no participantes (solo si D1 = B) | M-01 | Regla de dominio |
| `gifUrl`/`imageUrl` con alojamiento propio | M-06, M-09 | Campos aditivos |
| Textos de `plan/limitations` para participantes | M-14 | Contenido |
| Campos en español de músculo, grupo y equipamiento; pasos de instrucciones | M-08, M-09 | Campos aditivos |
| Dolor en ejercicio completado; observaciones de sesión (si se decide) | M-12, M-11 | Contrato nuevo |
| Edición del perfil durante el estudio (si se decide) | M-25 | Regla de dominio |
| Tildes en mensajes y notas | M-37 | Contenido |
| Credenciales de Firebase en el Backend de pruebas | M-05 | Configuración |

## Lo que este plan no hace

- No implementa P3 ni la recuperación de contraseña en esta auditoría.
- No crea pantallas de aceptación de documentos sin versión y texto servidos por el Backend.
- No modifica Firebase, O20, P1, P2 ni D-M1, ni el Backend, ni el usuario 48 o su dataset.
- No reemplaza las animaciones actuales: primero se resuelve su licencia y alojamiento.
- No presenta pruebas web o simuladas como pruebas en teléfono.
