# Migración a Flutter 3.50.1 y herramientas Android 9

Rama `claude/flutter-3-50-1`, creada desde `generation` `165364c` (código `aa1a0d2`).

## Entorno validado

| Componente | Antes | Ahora |
|---|---|---|
| Flutter | 3.32.8 | **3.50.1** (`ae9b586f34`, SHA-256 del paquete verificado) |
| Dart | 3.8 | **3.14.0** |
| Gradle | 8.12 | **9.5.0** |
| Android Gradle Plugin | 8.9.1 | **9.3.1** |
| Kotlin Gradle Plugin | 2.1.0 | **2.4.20** |
| JDK | 17 | **17** (OpenJDK 17.0.21, configurado con `flutter config --jdk-dir`; también compila con 21) |
| NDK | 27.0.12077973 | **28.2.13676358** |
| compileSdk / targetSdk | 36 / 36 | **36 / 36** |
| minSdk | 21 (Flutter 3.32) | **24** (mínimo de Flutter 3.50, Android 7.0) |

Flutter 3.50.1 exige al menos Gradle 9.3.1, AGP 9.1.1 y KGP 2.4.10. Recomienda 9.5.0, 9.3.1 y 2.4.20,
que son los que se usan aquí. **No se usa `--android-skip-build-dependency-validation`.**

## Las 11 pruebas que fallaban

**Causa:** Flutter 3.50 añadió una aserción. Un `ListTile` dentro de un `DecoratedBox` con fondo pinta
sus ondas y su color en el `Material` que hay **debajo** de ese fondo, así que la respuesta táctil queda
oculta. Hay dos estructuras de la app afectadas.

| Estructura | Dónde | Pruebas afectadas |
|---|---|---|
| Tarjetas «Actividad» y «Configuración» del Perfil: 9 `ListTile` (favoritos, notificaciones, recordatorios, historial, ejercicios excluidos por dolor, cuenta, ayuda, ver recorrido, cerrar sesión) dentro de `surface()` (fondo blanco, radio 30, borde y sombra) | `dashboard_page.dart` | `dashboard_live` (1), `dashboard_visual` (1), `edge_to_edge` (1), `welcome_tour` (7). El tour se dibuja sobre el dashboard real y recorre la pestaña Perfil |
| Tarjeta de restricciones de movimiento: 5 `SwitchListTile` dentro de `KoraCard` | `onboarding_page.dart` | `onboarding_flow` (1) |

**Corrección:** cada tarjeta da a sus filas un `Material(type: MaterialType.transparency)`, recortado
(`Clip.antiAlias`) al radio interior de la tarjeta: 29 en el Perfil y 16 en el onboarding.

- **No pinta fondo**: se conservan el color, el borde, la sombra, el radio, el espaciado y el tamaño.
- **Ondas visibles**: se dibujan encima del fondo blanco y no se salen de las esquinas redondeadas.
- **Tour intacto**: las `GlobalKey` del tour (recordatorios, ver recorrido) siguen en los mismos
  `ListTile`, y los rectángulos que resalta el tour no cambian.

No se tocó ninguna prueba existente ni sus expectativas. No se usó `takeException` ni se desactivaron
verificaciones.

**Prueba nueva** (`test/ink_feedback_test.dart`). Al pulsar una fila del Perfil comprueba tres cosas:

- el `Material` de pintura es el transparente de la tarjeta;
- se añaden la onda y el resaltado;
- la acción se ejecuta.

**Falla con el código anterior.**

El resto de `ListTile`, `SwitchListTile`, `CheckboxListTile` y `RadioListTile` de la app no tiene esta
estructura:

- unos están en hojas modales o en `Card`, que ya son `Material`;
- otros están directamente en listas y sus pruebas pasan;
- `CurrentPlanCard` no se usa en ninguna parte.

## APIs obsoletas

| Aviso | Cantidad | Decisión |
|---|---|---|
| `value` → `initialValue` en `DropdownButtonFormField` | 4 | **Corregido.** Los valores solo cambian por `onChanged`, o el campo se crea de nuevo al mostrarse; comportamiento idéntico, cubierto por pruebas |
| `groupValue` / `onChanged` de `Radio` | 2 | **Corregido** con `RadioGroup` (diálogo de falta de tiempo; cubierto por una prueba de widget que envía `MENOS_TIEMPO_HABITUAL`) |
| `package:flutter/material.dart` → `package:material_ui` | 78 | **Pendiente, en otra PR.** Ver abajo |
| `GlobalMaterialLocalizations` → la de `material_ui` | 3 | **Pendiente**, con la anterior |

**Por qué no se migró Material.** `material_ui` 1.11.1 trae sus propias copias de las clases: no es un
alias de `flutter/material.dart`. Las dependencias no están todas en el mismo lado:

- `fl_chart` 1.1.0 (31 importaciones) y `go_router` 17.0.0 siguen en `flutter/material.dart`;
- `flutter_riverpod` 3.5.0 ya usa `material_ui`.

Si la app migrara sola, el tema, las rutas y las traducciones (`GlobalMaterialLocalizations`) quedarían en
tipos distintos de los de las gráficas y del enrutador. Por ejemplo, el selector de fechas podría perder el
español y las gráficas, el tema. Conviene hacerlo en una PR propia, cuando `fl_chart` y `go_router` migren,
y antes inspeccionar con `dart fix --dry-run`.

El CI tiene un paso «Versiones» que imprime `flutter --version` y `dart --version` y **falla** si no son
Flutter 3.50.1 y Dart 3.14.0. En el CI, `flutter analyze --no-fatal-infos` mantiene fatales las advertencias y los errores (hay 0) y sigue
mostrando los 81 `info` en el registro. **No se ocultó nada en `analysis_options.yaml`.**

## Dependencias (`pubspec.lock`)

`flutter pub get` con Flutter 3.50.1 resuelve de nuevo el lock. Los cambios en dependencias directas los
impone el SDK; `pubspec.yaml` no cambia.

| Paquete | Antes → ahora | Motivo |
|---|---|---|
| `flutter_riverpod` | 3.3.2 → 3.5.0 | 3.3.2 no se puede resolver con el `test`/`analyzer` que fija el SDK |
| `freezed` (dev) | 3.0.0-0.0.dev → 3.2.3 | la versión dev dependía de `macros`, que Dart 3.14 eliminó |
| `intl` | 0.20.2 → 0.20.3 | la fija `flutter_localizations` |

El resto son transitivas fijadas por el SDK (`meta`, `characters`, `vector_math`, `test_api`, etc.).
`analysis_options.yaml` gana las exclusiones de `build/` y de las plataformas que añade `flutter pub get`.

### Comprobación de que cada cambio es necesario

Se comprobó fijando como restricción **exacta** cada versión anterior, en una copia aparte del proyecto.
Un `dependency_overrides` no sirve para esto, porque salta las restricciones del SDK.

| Versión anterior fijada | Resultado con Flutter 3.50.1 |
|---|---|
| `flutter_riverpod 3.3.2` (también con `freezed 3.2.3`) | **falla**: `riverpod 3.3.2` depende de `test ^1.0.0`, y ninguna versión de `test` es compatible con `matcher 0.12.20` + `test_api 0.7.14`, que fija `flutter_test` |
| `freezed 3.0.0-0.0.dev` | **falla**: depende de `macros` → `_macros 0.3.3`, que el SDK ya no trae |
| `intl 0.20.2` | **falla**: la fija `flutter_localizations` |
| `meta 1.16.0`, `vector_math 2.1.4`, `test_api 0.7.4`, `matcher 0.12.17`, `stack_trace 1.12.1`, `clock 1.1.2`, `leak_tracker 10.0.9` | **fallan**: las fija `flutter_test` |
| `characters 1.4.0`, `material_color_utilities 0.11.1` | **fallan**: las fija `flutter` |

`riverpod` 3.5.0 es la **primera** versión sin dependencia de `test`: las 3.3.2, 3.4.0, 3.4.1 y 3.4.x la
tienen. No hay una versión intermedia con menos cambios.

De dónde vienen los paquetes que entran y salen:

| Paquetes | Origen |
|---|---|
| Entran `material_ui` y `cupertino_ui` | `flutter_riverpod` 3.5.0 |
| Entran `source_gen` y las nuevas `analyzer`/`dart_style` | `freezed` 3.2.3 |
| Entra `listen` | el propio SDK |
| Salen `test`, `test_core`, `coverage`, `macros` y otros | solo los traían `riverpod` 3.3.2 y `freezed` 3.0.0-dev |

`flutter pub get` tras `flutter clean` no modifica el lock.

## Android

| Archivo | Cambio |
|---|---|
| `gradle-wrapper.properties` | Gradle 9.5.0 |
| `settings.gradle.kts` | AGP 9.3.1, KGP 2.4.20 |
| `app/build.gradle.kts` | Sin `id("kotlin-android")`: el plugin de Flutter lo aplica mientras `android.builtInKotlin=false`, como en la plantilla 3.50.1. `kotlinOptions {}` (eliminado en Kotlin 2.4) → `kotlin { compilerOptions { jvmTarget = JVM_11 } }`. NDK 28.2 |
| `gradle.properties` | `android.builtInKotlin=false` y `android.newDsl=false`, en el formato del migrador de Flutter |

**Compatibilidad transitoria, documentada.** Las dos banderas existen porque los plugins Flutter del lock
aún usan el DSL clásico de Android y necesitan `kotlin-android`. Las añaden el migrador y la plantilla de
Flutter 3.50.1. Se quitarán cuando todos los plugins admitan el DSL nuevo y Kotlin integrado de AGP 9.

**Sin cambios:**

- `compileSdk`/`targetSdk` 36 y permiso `INTERNET`;
- HTTPS obligatorio en release y bloqueo de direcciones locales y del emulador;
- dominios de prueba solo con `-Pkora.testBackendUrl=true`;
- firma propia exigida para el AAB y bloqueo de `com.example`;
- eliminación de cuenta y URL de eliminación web y de privacidad;
- borde a borde y gesto atrás;
- desugaring (`desugar_jdk_libs` 2.1.4) y Java 11.

## Avisos de AGP 9.3.1 (validación final)

`./gradlew` con JDK 17 resuelve `com.android.application` **9.3.1** y `org.jetbrains.kotlin.android`
**2.4.20**, con `kotlin-stdlib` 2.4.20. `flutter analyze --suggestions` informa «compatible
java/gradle/agp/kgp».

AGP avisa de que estas opciones se retirarán en AGP 10:

| Opción o uso | Situación |
|---|---|
| `android.builtInKotlin=false` / `android.newDsl=false` | **Necesarias hoy.** El plugin de Flutter usa la API antigua `applicationVariants`, que AGP 9 solo permite con `android.newDsl=false`. Además, `kotlin-android` (aplicado a `:app` y a `flutter_local_notifications`, `flutter_secure_storage` y `path_provider_android`) requiere `builtInKotlin=false`. Se quitarán cuando Flutter y los plugins adopten el DSL nuevo |
| `android.enableJetifier=true` | Heredada. `:app:checkJetifier` confirma que ningún módulo usa las bibliotecas de soporte antiguas, así que se puede quitar en una limpieza aparte. No se cambió en esta PR para no alterar la configuración validada |

## Avisos de terceros (sin cambios en el proyecto)

- **`flutter_secure_storage` 9.2.4** compila con Java 1.8 y `javac` avisa de que esa opción está obsoleta.
  Es el `build.gradle` del plugin; desaparecerá cuando el plugin suba de versión de Java.
- **«SDK XML version 4»**: aviso de las herramientas de línea de comandos de este entorno, no del
  proyecto.

## Tamaño del APK

Con `minSdk` 24, AGP guarda las librerías nativas **sin comprimir** y alineadas a 16 KB, para que Android
las cargue desde el APK sin extraerlas. El APK release arm64 pasa de 12,4 MB a 24,0 MB en disco (las
librerías nativas ya no van comprimidas dentro del archivo). La descarga desde Play se comprime en la
transferencia. No es una regresión.

## Verificación

Evidencia en `integracion_backend_5977/evidencia/flutter-3.50.1/`.

| Comprobación | Resultado |
|---|---|
| `flutter analyze` | 0 errores, 0 advertencias, 81 `info` (pendientes, arriba) |
| `flutter test` | **208 pasan, 0 fallan** (207 + 1 nueva) |
| Las 5 suites que fallaban | `dashboard_live` 4, `dashboard_visual` 1, `edge_to_edge` 4, `onboarding_flow` 1, `welcome_tour` 23, todas ✓ |
| `flutter build web --release` | ✓ |
| `flutter build apk --debug` (arm64 y todas las ABI) | ✓ con JDK 17 y con JDK 21 |
| APK release de prueba (`backend.example.test` + `-Pkora.testBackendUrl=true`) | ✓. INTERNET, targetSdk 36, sin tráfico en claro, no depurable, gesto atrás, alineación de 16 KB verificada, 0 cadenas sensibles |
| Release con HTTP, con `10.0.2.2`, con IP privada, con dominio de prueba sin bandera o sin URL | **bloqueado** (5 casos) |
| AAB sin configuración / con URL pero sin firma ni identificador | **bloqueado** (6 motivos / 2 motivos) |
| Emulador o dispositivo físico | **Pendiente.** Este entorno no tiene KVM ni dispositivo. No se da por aprobado |
