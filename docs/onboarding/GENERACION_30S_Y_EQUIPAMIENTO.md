# Generación de 30 s con Kapi, peso corporal y retiro de «ejercicios a evitar»

Rama `claude/ux-generacion-onboarding`, creada desde `generation` `fca6546` (Flutter 3.50.1 / Dart 3.14.0).
No incluye nada de la PR #10 (`material_ui`). No cambia el backend, las reglas deportivas ni los contratos de la API.

## 1. Pantalla «Generando»

**Archivos:** `onboarding/presentation/generating_plan.dart` y `onboarding_page.dart` (`submit`, `settleGeneration`).

### Flujo

1. Al tocar «Generar mi plan» se arranca un `Timer` de 30 s y un reloj visual de 30 s (`AnimationController` con
   `AnimationBehavior.preserve`, para que avance igual con movimiento reducido).
2. Al mismo tiempo, sin esperar al temporizador:
   - se guarda el perfil;
   - se pide la generación una vez (`POST /users/me/plan/generation`, idempotente);
   - el controlador existente consulta el estado cada `pollAfterSeconds`. Esas consultas son lecturas (`GET`), no
     generaciones nuevas.
3. Lo que diga el backend se guarda, pero **no se mira hasta que pasan los 30 s**.

### Qué pasa a los 30 s

| Situación | Qué hace la app |
|---|---|
| El backend terminó antes (por ejemplo a los 5 o 20 s) | Conserva el resultado y continúa al recorrido de bienvenida justo a los 30 s. La pantalla de resultado muestra el plan |
| Termina justo a los 30 s | Continúa |
| Sigue en `PENDING`/`PROCESSING`, o la solicitud no ha respondido | Termina la animación y muestra **«Tu plan sigue en camino»**: Kapi en espera, barra indeterminada y «Continuar» (hacia el recorrido; aparece cuando la solicitud fue aceptada). Si el resultado llega mientras tanto, continúa sola. No inventa ningún plan ni dice que está listo |
| Sin conexión o 5xx al consultar | Igual que el anterior, con el aviso correspondiente. Como antes, la app trata los 5xx como fallos temporales y sigue intentándolo |
| Rechazo (422 u otro 4xx) | Muestra el error **después** de los 30 s: «Tu perfil está guardado. …» y «Reintentar generación» |
| No se pudo guardar el perfil | Vuelve al paso 5 con el error, después de los 30 s. No se pide ninguna generación |
| `FAILED` reintentable | Error después de los 30 s. «Reintentar generación» hace **una** solicitud nueva (`retry`) y abre otros 30 s |
| `NO_FACTIBLE` o `FAILED` no reintentable | Error después de los 30 s y «Continuar». La pantalla de resultado ya ofrece «Contactar al equipo» y «Cerrar sesión» |

- **Seguridad o cierre de sesión:** el manejador global de 401 sigue llevando al inicio de sesión al momento. Al
  salir de la pantalla, `dispose` cancela el temporizador, el reloj visual y la rotación de Kapi. La consulta de
  estado vive en su proveedor y se cancela con él.
- **La barra de progreso** depende solo del reloj de 30 s. No muestra porcentajes del backend, que no existen.
- **Textos:**
  - «Sincronizando...» pasa a ser «Generando...»;
  - la etiqueta superior pasa a ser «GENERANDO TU PLAN» (antes «SINCRONIZANDO PERFIL» o «MOTOR IA ACTIVO»);
  - para lectores de pantalla, «Generando plan».

## 2. Kapi durante los 30 s

**Archivo:** `onboarding/presentation/kapi_fun_messages.dart`.

- Hay 14 mensajes propios, entre ellos los cinco del ejemplo de la orden. Cada uno lleva una expresión de Kapi
  (explicar, motivar, saludar, celebrar).
- **Rotación:** cada 5 s, en orden aleatorio, sin repetir ninguno hasta mostrarlos todos y nunca dos veces seguidas
  (`KapiMessageDeck`).
- **Interacción:** al tocar a Kapi, da un saltito y cambia de mensaje. El texto «Toca a Kapi para otra curiosidad»
  lo indica.
- La rotación usa su propio temporizador. No toca la barra ni el temporizador de 30 s; una prueba lo comprueba.
- **Kapi nunca habla de la generación.** Una prueba rechaza cualquier mensaje con:
  - generar, preparar, procesar o sincronizar;
  - plan, rutina, backend o servidor;
  - IA, inteligencia, algoritmo o modelo;
  - esperar, segundos, minutos, tiempo, cargar, listo, casi o pronto.

  «Generando» solo aparece en la parte de progreso, nunca en el globo de Kapi.
- **Accesibilidad:**
  - el globo no es región viva, para que el lector de pantalla no interrumpa cada 5 s;
  - con movimiento reducido, Kapi y el pulso quedan quietos.
- Se reutilizan los SVG y las animaciones de `KoraMascot`. No hay IA ni servicios externos.

## 3. Lugar de entrenamiento y «Peso corporal»

- **Nombres reales, sin cambios:** `HOME` «Casa», `GYM` «Gimnasio» y `MIXED` «Ambos». La orden lo llama
  «Personalizado»; en el código y en el backend es «Ambos».
- **Código existente:** `body weight` («Peso corporal»), de `equipment_types` (V3) y `GET /catalog/equipment-types`.
  No se creó ningún código. Queda como constante `bodyWeightCode`.
- **Perfil nuevo:** empieza con `body weight` seleccionado en los tres lugares.
  - En la tarjeta, «Peso corporal» aparece como chip fijo marcado, sin quitar. El resto del equipo tiene su chip
    con ✕.
  - En el selector aparece marcado, bloqueado y con «Siempre incluido».
  - Por qué no se puede desmarcar: el backend siempre añade peso corporal a los ejercicios elegibles
    (`ExerciseQueryServiceImpl`, `declared.add("body weight")`). Desmarcarlo daría a entender algo que no ocurre.
- **Agregar equipo:** se agrega desde «Elegir equipamiento», como antes.
- **Cambiar de lugar:**
  - Gimnasio sigue añadiendo su equipo;
  - Casa sigue quitando solo lo de gimnasio;
  - peso corporal se mantiene siempre;
  - las elecciones del usuario se conservan.
- **Perfil existente:** durante el estudio no se edita. Si la cuenta ya tiene perfil, el onboarding la manda a
  «Preparación de cuenta» sin enviar nada. El código que rellena un perfil guardado conserva sus códigos tal cual,
  sin añadir peso corporal.
- **Sin duplicados:** el equipo se guarda en un `Set` y el backend normaliza con `distinct()`.
  `UserProfile.bodyWeightOnly()` (lista vacía) no se usa en ningún sitio del backend `5977d28`, así que enviar el
  código explícito no cambia la planificación.

## 4. Retiro de «Ejercicios a evitar» (la orden lo llama «Ejercicios restringidos»)

**Se retiró:**
- del paso 5, la tarjeta «Sin ejercicios excluidos / N ejercicios excluidos»;
- el botón «Elegir ejercicios a evitar» y la hoja `BlockedExercisePicker` (archivo eliminado; no tenía pruebas
  propias);
- la carga de nombres desde el catálogo;
- los dos textos que remitían a esa lista.

**Se conservó:**
- los interruptores de movimientos (impacto, suelo, rodillas, colgado, brazos sobre la cabeza);
- las notas de salud y las exclusiones por dolor del Perfil;
- el campo `blockedExerciseIds` en el contrato (`createProfileFields`). Un perfil nuevo envía `[]` y uno existente
  conserva sus ids;
- los filtros y validadores del backend, sin tocar: V24, V8C y las políticas de seguridad.

**Pasos:** siguen siendo 5, porque el paso 5 conserva los interruptores y las notas. El indicador «Paso N de 5» y la
barra no cambian.

## 5. Pruebas

- **Nuevas (24),** en `test/generation_screen_test.dart`, todas con respuestas simuladas:
  - **Generación:**
    - el backend responde a los 5 s y a los 20 s: la pantalla sigue hasta los 30 s y no se vuelve a consultar;
    - responde justo a los 30 s: continúa;
    - pasa de 30 s: estado pendiente sin plan inventado, continúa solo cuando llega el resultado, y «Continuar»
      funciona;
    - la solicitud sin responder no muestra «Continuar» hasta que la aceptan;
    - 422, guardado fallido, `FAILED` reintentable y `NO_FACTIBLE`;
    - sin solicitudes duplicadas;
    - limpieza al salir con cierre de sesión.
  - **Kapi:**
    - palabras prohibidas;
    - sin repetición;
    - el cambio de mensaje, solo o al tocar, no mueve la barra;
    - pantallas de 320 × 568 y 360 × 640, con texto a ×1, ×1,3 y ×2.
  - **Onboarding:**
    - peso corporal por defecto en Casa, Gimnasio y Ambos, enviado una sola vez;
    - agregar equipo y cambiar de lugar;
    - un perfil existente no se sobrescribe;
    - «Ejercicios a evitar» ausente;
    - navegación entre pasos;
    - el cuerpo enviado.
- **Ajustada:** `test/onboarding_flow_test.dart`. Antes comprobaba que el recorrido abría «al instante»; ahora
  comprueba los 30 s y el estado pendiente, y espera `body weight` en `equipmentCodes`. No se quitó ninguna
  comprobación.

## 6. Evidencia E2E (`evidencia_generacion_30s/`)

App web release de esta rama, en una ventana de 390 × 844, con Playwright. El tiempo se mide desde el clic.

### Con el backend local `5977d28`

IA apagada (motor de reglas), sin Replicate (`e2e-backend-local.txt`).

| Momento | Hecho |
|---|---|
| 0,3 s | `POST /users/me/profile` 201 |
| 0,5 s | `POST /users/me/plan/generation` 202 `PENDING` |
| 3,6 s | `GET …/generation/{id}` 200 **`COMPLETED`** |
| 0–30 s | La pantalla «Generando…» sigue. Kapi cambia de mensaje a los 0, 5,4, 10,5, 15,5, 20,4 y 25,5 s, sin repetir ninguno |
| **30,2 s** | Aparece el recorrido («Soy Kapi») |
| PostgreSQL | `equipment_codes` incluye `"body weight"`, `blocked_exercise_ids = {}`; 1 operación y 1 plan |

Capturas:
- de la generación: `U-generando-02s/09s/16s/24s/29s.png`;
- del lugar: `U-equipo-{casa,gimnasio,ambos}.png` y `U-selector-*.png`, este último con «Siempre incluido»;
- del paso 5 sin la lista: `U-paso5-arriba.png` y `U-paso5-abajo.png`.

### Con respuestas simuladas

Por `page.route` de Playwright; el backend no generó nada (`e2e-respuestas-simuladas.txt`).

| Caso | Resultado |
|---|---|
| Siempre `PROCESSING` | A los 28 s sigue «Generando» (8 consultas de estado). A los **30,1 s**, «Tu plan sigue en camino», sin «lista» ni recorrido. «Continuar» lleva al recorrido. En PostgreSQL: 0 operaciones |
| 422 | A los 5 s, sin error. A los **30,1 s**, «Tu perfil está guardado. …» (`U-error-422-tras-30s.png`) |
| 503 | A los **30,1 s**, pendiente con «El servidor no responde…» (`U-pendiente-503-tras-30s.png`) |

Los arneses (`arnes/ux30.js`, `arnes/ux-simulado.js`, `arnes/p1-ux.json`) usan los helpers de
`docs/preparacion_google_play/integracion_backend_5977/evidencia/arnes/`.

## 7. Observaciones fuera del alcance (sin cambiar)

- **Primer mensaje del recorrido:** dice «Mientras Kora prepara tu primera rutina…». Con la pantalla de 30 s, el plan
  suele estar listo al empezar el recorrido. Conviene revisarlo en otra orden.
- **Avisos del analizador:**
  - el nuevo archivo de prueba importa `package:flutter/material.dart`, como el resto en `generation`. Eso suma un
    aviso informativo de obsolescencia: 81 → 82, ninguno es error ni advertencia;
  - la PR #10 cambia solo la línea del import en seis archivos de onboarding. Si se fusiona una de las dos PR antes
    que la otra, habrá dos conflictos triviales:
    - `generating_plan.dart`: esta rama reescribe la cabecera; hay que quedarse con esta versión y poner el import
      de `material_ui`;
    - `blocked_exercise_picker.dart`: esta rama lo elimina y la PR #10 le cambia el import; hay que confirmar el
      borrado.

    El nuevo `test/generation_screen_test.dart` también tendrá que pasar a `material_ui`. En `onboarding_page.dart`,
    `equipment_picker.dart` y `onboarding_flow_test.dart` las líneas tocadas no coinciden.

## 8. Sin cambios, por orden expresa

Backend, contratos, V24, V8C, políticas de seguridad, reglas deportivas, H2, P-03, catálogo, adherencia,
progresión, Replicate, Railway, Google Play, identificador y firma.
