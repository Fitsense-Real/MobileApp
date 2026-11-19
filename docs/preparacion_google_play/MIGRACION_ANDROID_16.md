# Migración a Android 16 (API 36) (PR A)

## Versiones

| Pieza | Antes | Después | Motivo |
|---|---|---|---|
| `targetSdk` | 35 (`flutter.targetSdkVersion`) | **36** | Play lo exige para apps nuevas y actualizaciones desde el 31/08/2026 |
| `compileSdk` | 35 | **36** | Necesario para apuntar a 36 |
| Android Gradle Plugin | 8.7.3 | **8.9.1** | 8.7.3 avisa «tested up to compileSdk = 35». 8.9.1 es la versión mínima probada que compila con 36 sin aviso. No se ocultó el aviso con `suppressUnsupportedCompileSdk` |
| Gradle | 8.12 | 8.12 | 8.9.1 necesita 8.11.1 o superior |
| Kotlin | 2.1.0 | 2.1.0 | sin cambios |
| Flutter | 3.32.8 | 3.32.8 | sin cambios |
| NDK | 27.0.12077973 | sin cambios | lo exigen los plugins |
| Dependencias Dart | — | sin cambios | no hizo falta actualizar ninguna |

Comprobado en el APK release: `targetSdkVersion:'36'`, `compileSdkVersion='36'`. Las únicas advertencias
de la compilación son `source value 8 is obsolete` de una dependencia Java de terceros.

## Borde a borde

Android 15 ya dibuja las apps de borde a borde, y Android 16 (targetSdk 36) quita la opción de
excluirse. Kora no la usaba: sus temas no tienen `windowOptOutEdgeToEdgeEnforcement`, así que el
comportamiento en Android 15 ya era de borde a borde.

Cómo protege la app sus controles:

- `KoraPage` (la mayoría de pantallas): `Scaffold` + `SafeArea`.
- Dashboard: `Scaffold` con `NavigationBar`, que respeta el margen inferior.
- Tarjeta del tour: `SafeArea`.
- Hojas inferiores (Cuenta, historial): `SafeArea`.

### Prueba automática nueva

`test/support/system_bars.dart` simula una barra de estado (32) y una de navegación (48) como
`MediaQuery.padding` de Flutter, y opcionalmente el teclado. Falla si un control fijo (botón, campo,
interruptor o destino de navegación) fuera de un scroll queda debajo de esas barras.

| Pantalla | Variantes | Resultado |
|---|---|---|
| Tour de Kapi, los 10 pasos | 390×844; 360×740 con texto 2.0; 844×390 horizontal | ✓ |
| Resultado de la primera rutina (error con reintento) | 360×640 con texto 1.5 | ✓ |
| Iniciar sesión y registro | normal; 360×740 con texto 1.5 y teclado abierto | ✓ |
| Dashboard: Inicio, Rutinas, Progreso, Perfil | 390×844 | ✓ |
| Formulario de perfil (paso 1) | normal; 360×740 con texto 1.5 y teclado | ✓ tras corregir la cabecera |

### Corrección encontrada

La cabecera del formulario de perfil (volver + «Paso n de 5» + logo) **desbordaba 23 px** con texto
1.5 a 360 px (`onboarding_page.dart`, código anterior a estas PR). Ahora el texto ocupa el espacio
libre y se centra. No se encontraron controles debajo de las barras del sistema.

Las pantallas de entrenamiento (detalle de rutina y sesión en vivo) usan `KoraPage` con `ListView`:
todo su contenido se desplaza, y `SafeArea` las protege.

## Gesto de volver predictivo

- `android:enableOnBackInvokedCallback="true"` en el manifiesto, comprobado en el APK y en el AAB. Activa
  el gesto predictivo en Android 13 y 14 y se alinea con el comportamiento por defecto de Android 16.
- Las pantallas usan `PopScope`, la API de Flutter 3.32 para el gesto predictivo, en vez de
  `WillPopScope`.
- No se desactivó el gesto del sistema.

Detalle del tour en `VALIDACION_NAVEGACION_KAPI.md`.

## Lo que falta: comprobación física

Sin dispositivo ni emulador funcional (sin KVM; el emulador por software ya falló en la ORDEN 2 y no
se repitió), **no se comprobó la apariencia real en Android 13, 14, 15 ni 16**. La compatibilidad
visual está verificada con las pruebas de widget anteriores, no en pantalla.

Pasos para el teléfono en `GUIA_PUBLICACION_ANDROID.md` §8.
