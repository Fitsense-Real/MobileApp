# Auditoría funcional del Mobile (cierre)

## Condiciones

| | |
|---|---|
| App | Rama `claude/fix-recorrido-tras-cierre`: `generation` `fb01dd5` más la corrección de abajo. Compilación web release, ventana de 390 × 844 |
| Backend | `5977d28` local, PostgreSQL propia, **IA apagada (motor de reglas): sin Replicate** |
| Datos | Cuentas sintéticas `audit*@e2e.local` |
| Fechas | Para cerrar una semana se movieron las fechas del plan **solo en la base de pruebas** |
| Comparación | Cada comprobación compara la pantalla con lo que devuelve el backend: API `/users/me/plan/current`, `/cycle/run-for-me` y PostgreSQL |

Arnés: `arnes/` (Playwright sobre el árbol de semántica de Flutter web), con los helpers de
`docs/preparacion_google_play/integracion_backend_5977/evidencia/arnes/`. La contraseña de las cuentas sintéticas se lee de
`E2E_PASSWORD`.

## Resultado: 32 de 32 comprobaciones en verde

Registro completo en `resultado-e2e.txt`.

| Área | Comprobación | Resultado |
|---|---|---|
| Registro | Crear la cuenta e iniciar sesión hasta el perfil | ✓ |
| Onboarding | 5 pasos, sin «Ejercicios a evitar» | ✓ |
| Generación | «Generando» visible a los ~8 s | ✓ |
| Generación | **La app se cierra a mitad de los 30 s** (arranque en frío) y retoma: llega al recorrido | ✓ tras la corrección; antes ✗, ver abajo |
| Generación | Una sola operación de generación (no se pide otra al volver) | ✓ `COMPLETED`, 1 operación |
| Generación | Resultado «¡Tu primera rutina está lista!» con el plan real | ✓ |
| Inicio | Dashboard con el nombre del usuario | ✓ |
| Plan | El backend devolvió un plan | ✓ 3 entrenamientos, semana del 23/11, `RULE_ENGINE` (respaldo con la IA apagada) |
| Plan | Rutinas muestra cada entrenamiento con su nombre, día, fecha y estado iguales al backend | ✓ 3/3 |
| Plan | Detalle de la rutina: nombre, series, repeticiones o segundos por serie, y descanso de **cada** ejercicio | ✓ 8/8 iguales al backend |
| Rutinas | Omitir un entrenamiento futuro con motivo (Fatiga) | ✓ `SKIPPED/FATIGUE` |
| Rutinas | El omitido aparece como «Omitido» | ✓ |
| Sesión | Iniciar la sesión | ✓ `IN_PROGRESS` |
| Sesión | Registrar los 8 ejercicios: completo, parcial con motivo y no realizado con motivo | ✓ `COMPLETED, PARTIAL, SKIPPED, …` |
| Sesión | Finalizar con esfuerzo 7, satisfacción 4 y 30 min | ✓ sesión `PARTIAL`, 77,78 %, 7, 4, 30 |
| Sesión | La app muestra el % que calculó el backend y el estado «Parcial» | ✓ «77.78% completado» |
| Sesión | «Ya lo hice»: registro sin sesión en vivo | ✓ `COMPLETED USER_REPORTED`, 100 % |
| Adherencia | Ciclo semanal ejecutado | ✓ `EJECUTADO`, nuevo plan 35 |
| Adherencia | Métrica semanal calculada por el backend | ✓ ponderada 59,26 %, riesgo bajo, 1/3 |
| Adherencia | Progreso muestra la adherencia del backend | ✓ 59,3 % |
| Adaptación | Intento de adaptación y plan de la semana siguiente | ✓ `ADAPT_LOCALIZED`, plan `CONSERVED` activo |
| Adaptación | Progreso resume el ajuste | ✓ |
| Historial | El historial muestra las semanas del backend | ✓ 09/11 y 16/11 |
| Kapi | El repaso del recorrido abre con Kapi | ✓ |
| Kapi | Al terminar el repaso se vuelve a la app sin pedir otra generación | ✓ 1 → 1 operación |
| Notificaciones | La hoja de recordatorios muestra el interruptor, la hora y el aviso de vencimiento | ✓ |
| Sesión | Cerrar sesión lleva al inicio de sesión | ✓ |
| Sesión | Volver a iniciar sesión entra al inicio con su plan, sin repetir perfil ni recorrido | ✓ |
| Cuenta | Eliminar la cuenta: «Tu cuenta fue eliminada», «Salir» lleva al inicio de sesión y la cuenta no existe en PostgreSQL | ✓ |
| Cuenta | Sus planes, sesiones y operaciones tampoco quedan | ✓ |

Sobre la línea ✗ de «Eliminar mi cuenta» en `resultado-e2e.txt` (`aud3`): la eliminación funcionó (0 filas). La
comprobación buscaba el texto «INICIA SESIÓN» del *splash*, mientras que «Salir» lleva al formulario «INICIAR SESIÓN».
Corregido el texto, la repetición aislada (`aud3b`) pasó.

**Estados de la generación** cubiertos en conjunto:

| Estado | Dónde se comprobó |
|---|---|
| Éxito y respaldo (`RULE_ENGINE`) | Aquí |
| Espera prolongada (más de 30 s) | E2E con respuestas simuladas de la PR #11 (`docs/onboarding/evidencia_generacion_30s/`) y pruebas de widget |
| Error (422 y 503) | Ídem |
| `NO_FACTIBLE` y `FAILED` | Pruebas de widget de la PR #11 y `welcome_tour_test.dart` |
| Recuperación tras cerrar la app | Aquí |

**Recordatorios nativos:** no se pueden probar en la web. Su programación se verifica a nivel del canal nativo
(`reminder_channel_test.dart`, PR #13) y queda en la prueba de Android (`PRUEBA_ANDROID_WINDOWS_PENDIENTE.md`).

## Fallo encontrado y corregido en esta PR

**El recorrido obligatorio se perdía si la app se cerraba durante los 30 s de «Generando».**

- **Cómo pasaba:**
  1. El backend termina el plan en ~3 s.
  2. El usuario cierra la app antes de los 30 s.
  3. Al abrirla, «Preparación de cuenta» encuentra un plan y un recorrido `notStarted`, y va directo al dashboard. Solo
     retomaba recorridos `inProgress`.
  4. El recorrido de Kapi no se mostraba nunca.
- **Por qué apareció ahora:** antes de la PR #11 el recorrido empezaba en cuanto el backend aceptaba la solicitud, así
  que el hueco era de milisegundos. Con la pantalla de 30 s, el hueco es de 30 s.
- **Corrección** en `onboarding_page.dart`:
  - al tocar «Generar mi plan», el recorrido pasa de `notStarted` a `inProgress`, paso 0;
  - no se toca un recorrido ya completado ni uno a medias;
  - la regla existente de «Preparación de cuenta» («plan listo y recorrido a medias → recorrido», cubierta por
    `account_setup_test.dart`) hace el resto.
- **Sin cambios** en el comportamiento de los 30 s ni en Kapi.
- **Pruebas:**
  - `generation_screen_test.dart` comprueba que el toque deja el recorrido en curso. Falla sin la corrección:
    `notStarted` frente a `inProgress`.
  - Otra prueba comprueba que un recorrido completado o a medias se respeta.
  - E2E: tras el arranque en frío, el recorrido aparece a los 11,4 s.

## Observaciones (sin cambiar, por estar fuera del alcance o ser menores)

| # | Observación | Severidad | Recomendación |
|---|---|---|---|
| O-1 | Si un usuario que ya tuvo planes se queda sin plan vigente (el ciclo semanal no generó la semana), la app pide uno y lo presenta con el título «¡Tu primera rutina está lista!» | Baja | Ajustar el título cuando no es el primer plan. Con el ciclo semanal programado en el backend de producción no debería ocurrir |
| O-2 | El primer mensaje del recorrido dice «Mientras Kora prepara tu primera rutina…», pero tras los 30 s el plan suele estar listo | Baja | Revisar el texto (ya anotado en la PR #11) |
| O-3 | Con el GIF cargado, la tarjeta del ejercicio se anuncia con rol de imagen (la etiqueta incluye nombre, series y descanso, así que se lee completa) | Baja (accesibilidad) | Excluir el GIF de la semántica o marcar la tarjeta como contenedor |
| B-5 | El backend acepta «Ya lo hice» de un entrenamiento cuya fecha no llegó | Media (backend; ya documentado) | Decisión de producto en el backend |

## Problemas del arnés (no son fallos de la app)

Todos se corrigieron en el arnés:
- **Recarga web:** recargar la página web conserva la ruta y se salta el *splash*. El arranque en frío se simula
  cargando la URL raíz.
- **Tarjeta con GIF:** cuando el GIF carga, la tarjeta está en `flt-semantics-img`.
- **Nombres largos:** se parten en dos nodos de semántica.
- **Fechas agrupadas:** las fechas de Rutinas comparten una sola etiqueta. La tarjeta se elige por orden y se verifica
  la fecha en el detalle.
- **Opciones del diálogo:** «Lo completé / parcial / No lo hice» tienen el rol `checkbox`.
- **Cierre de Chromium:** un Chromium cerrado a la fuerza puede no guardar el último `localStorage`.
