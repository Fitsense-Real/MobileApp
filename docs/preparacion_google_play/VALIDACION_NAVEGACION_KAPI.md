# Navegación hacia atrás en el tour de Kapi (PR A)

## Problema original

Con `PopScope(canPop: false)`, el gesto o botón atrás en el **primer paso** no hacía nada. En
Android 16, con el gesto predictivo por defecto, el usuario quedaba sin salida por atrás en tres
pantallas:

| Pantalla | Antes |
|---|---|
| Tour inicial, paso 1 | atrás no hacía nada |
| Repaso desde Perfil, paso 1 | atrás no hacía nada: el repaso es voluntario y solo se salía terminándolo |
| Resultado de la primera rutina | atrás no hacía nada |

Las tres pruebas nuevas **fallan con el código anterior** (comprobado).

## Comportamiento nuevo

| Situación | Gesto o botón atrás |
|---|---|
| Tour inicial, pasos 2 a 10 | vuelve **un paso** y guarda el progreso |
| Tour inicial, paso 1 | **sale de la app** (`SystemNavigator.pop`) sin saltar el tour: queda `inProgress` y al reabrir Kora continúa en ese paso |
| Repaso desde Perfil, paso 1 | vuelve a la app (Perfil), sin guardar nada |
| Resultado de la primera rutina | sale de la app; la generación sigue en el servidor y la pantalla vuelve al reabrir |
| Botón «Atrás» de la tarjeta | igual que antes (paso anterior) |

El tour inicial sigue siendo obligatorio: atrás nunca lo marca como completado ni lleva al
dashboard. Atrás tampoco reinicia la generación.

## Pruebas (`test/welcome_tour_test.dart`)

- Tour inicial: el atrás del sistema va del paso 3 al 2 y al 1, guardando el progreso. En el paso 1
  llama a `SystemNavigator.pop`, el tour sigue `inProgress` y la generación se pidió una sola vez.
- Repaso: en el paso 1 vuelve a la app, sin `SystemNavigator.pop` y sin tocar el progreso.
- Resultado: sale de la app y no vuelve a pedir la generación.
- Se mantienen las 18 pruebas anteriores del tour, entre ellas la reanudación tras cerrar la app.

El gesto se simula con `handlePopRoute`, el mismo camino que usa el gesto del sistema en Flutter.

## Pendiente

Comprobarlo con el gesto real en Android 13, 14, 15 y 16 (`GUIA_PUBLICACION_ANDROID.md` §8).
