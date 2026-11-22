# Actualización de componentes obsoletos (Flutter 3.50.1)

Rama `claude/material-ui-actualizacion`, creada desde `generation` `fca6546` (PR #9 ya fusionada).

## Resultado

| Comprobación | Antes (`fca6546`) | Ahora |
|---|---|---|
| `flutter analyze` | 81 `info` | **No issues found!** (0 errores, 0 warnings, 0 info) |
| CI | `flutter analyze --no-fatal-infos` | `flutter analyze`: los `info` vuelven a ser fatales |
| `flutter test` | 208 | **208 pasan, 0 fallan**; ninguna prueba modificada en sus expectativas |
| Avisos de AGP 9.3.1 al configurar | 3 opciones obsoletas + API de variantes antigua + 4 de `kotlin-android` | **ninguno** |

No se desactivó ninguna regla del analizador.

## 1. Material → `material_ui` (78 + 3 avisos)

- **Importaciones (78 archivos de `lib` y `test`).** `package:flutter/material.dart` pasa a
  `package:material_ui/material_ui.dart`. Se aplicó con `dart fix` (la corrección oficial ligada a la
  obsolescencia), primero en modo inspección (`--dry-run`: 81 correcciones en 78 archivos) y revisando
  después el diff archivo por archivo.
- **`GlobalMaterialLocalizations` (3 usos: `app.dart` y dos pruebas).** Ahora viene de `material_ui`.
  `dart fix` dejó una importación de `material_ui` duplicada y una ambigüedad con `flutter_localizations`,
  que se corrigieron a mano.
  - `GlobalMaterialLocalizations.delegates` de `material_ui` incluye las traducciones de Material, las de
    Cupertino (`cupertino_ui`) y las de widgets, así que en esos archivos ya no hace falta importar
    `flutter_localizations`.
  - El español se comprobó en la app: calendario («22, sábado, 22 de noviembre de 2008»), diálogos y
    menús.
- **`material_ui: ^1.11.1`** pasa a ser dependencia directa; ya estaba en el lock, transitiva de
  `flutter_riverpod`.

### Compatibilidad de las dependencias

`material_ui` trae copias propias de las clases (no es un alias de `flutter/material.dart`). Por eso se
revisó cada dependencia que importa el Material antiguo:

| Dependencia | Antes | Decisión |
|---|---|---|
| `go_router` | 17.0.0 (Material antiguo) | **18.1.4**. La 18.0.0 solo «migra a material_ui y cupertino_ui» y sube el mínimo a Flutter 3.44; sin cambios de API. La navegación se validó en la app |
| `fl_chart` | 1.1.0 (31 importaciones del Material antiguo; la 1.3.1, última, sigue igual) | **Retirada**: ningún archivo de `lib` ni de `test` la importa. La gráfica de adherencia es propia. No se elimina ninguna función |
| `flutter_riverpod` 3.5.0 | ya usa `material_ui` | sin cambios |
| `flutter_shaders` 0.1.3 (transitiva de `flutter_animate` 4.5.2, que es la última) | Material antiguo | Sin efecto en Kora: solo interviene en `ShaderEffect`, que la app no usa (usa `fade`, `slide` y similares). No hace falta el puente `MaterialUiCompatibilityBridge`, que además está marcado como obsoleto |
| `leak_tracker_flutter_testing` | Material antiguo | Solo en pruebas; la fija el SDK |

Cambios del `pubspec.lock`:

| Paquete | Cambio |
|---|---|
| `go_router` | 17.0.0 → 18.1.4 |
| `fl_chart` | 1.1.0 → retirado |
| `material_ui` | transitiva → directa (misma versión) |

## 2. Configuración transitoria de AGP 9, Kotlin y Jetifier

| Opción | Antes | Ahora | Verificación |
|---|---|---|---|
| `android.newDsl` | `false` (migrador de Flutter) | **`true`** | Compila con los plugins actuales (debug, release, AAB y bloqueos) |
| `android.builtInKotlin` | `false` (migrador de Flutter) | **`true`**: AGP compila el Kotlin de la app | Ídem |
| `android.enableJetifier` | `true` | **retirada** | `:app:checkJetifier`: «does not use any legacy support libraries» |

- **Por qué se declaran explícitamente en `true`.** Si las claves no existen, el migrador de Flutter 3.50.1
  las escribe en `false` en cada compilación (`DisableNewDslMigration` y
  `DisableBuiltInKotlinMigration`). Si existen, las respeta: «the developer has already configured the
  flag».
- **La combinación mixta falla.** `newDsl=true` con `builtInKotlin=false` da «Failed to apply plugin
  'kotlin-android'».
- **Kotlin Gradle Plugin 2.4.20.** Sigue declarado en `settings.gradle.kts` (`apply false`) para que los
  plugins que aún aplican `kotlin-android` usen una sola versión; también compila sin él.

### Pendiente: avisos de Gradle 10 en dos plugins de terceros

Con `--warning-mode all` solo quedan avisos de sintaxis Groovy («propName value») en los `build.gradle` de:

- `flutter_local_notifications` 19.5.0;
- `flutter_secure_storage` 9.2.4, que además compila con Java 8.

Son avisos para Gradle 10 y hoy no fallan. **No se actualizaron** porque las versiones que los resuelven
cambian más de lo que esta PR debe cambiar:

- **`flutter_local_notifications` 23.0.3**:
  - exige `compileSdk` 37, por encima del 36 validado;
  - desde la 20, los métodos de programación pasan de parámetros posicionales a nombrados, lo que obliga a
    adaptar los recordatorios.
- **`flutter_secure_storage` 11.2.0**:
  - exige `compileSdk` 37;
  - elimina la migración desde la 9: hay que pasar antes por la 10, o los datos guardados (sesión, tour,
    recordatorios) quedan ilegibles.

Conviene hacerlo en una PR propia, con `compileSdk` 37 y pruebas en dispositivo.

## 3. Funcionalidad comprobada con la app migrada

App web compilada desde esta rama contra el backend local 5977d28 (PostgreSQL de prueba, usuarios
sintéticos, sin Replicate).

| Área | Resultado |
|---|---|
| Registro / login / recuperación | 201 / 200. Recuperación completa: código del `.eml` simulado, código inválido 400, cambio 204, contraseña antigua 401 y nueva 200, la sesión antigua vuelve al login |
| Onboarding y restricciones | Perfil completo, incluida la tarjeta de restricciones de movimiento |
| Edad mínima | Cumple 18 mañana: aviso, no avanza. Cumple 18 hoy: avanza (calendario en español) |
| Generación y Kapi | `POST /plan/generation` 202 → tour de Kapi → «¡Tu primera rutina está lista!» → dashboard |
| Entrenamiento | 7 ejercicios (completo, parcial con «Fatiga», no realizado por «Falta de tiempo», 4 completos) y esfuerzo 7 → sesión `PARTIAL` 74,60 %, igual que antes de migrar |
| Progreso, Perfil y cerrar sesión | ✓ |
| Eliminación de cuenta | 403 y después 200; 0 filas del usuario; registro anónimo `COMPLETADA` |
| Aspecto | Tarjetas del Perfil, diálogos y menús iguales (capturas `M-*`) |

**Semántica web de los chips del diálogo de resultado.** En el navegador, «Lo completé», «Lo hice
parcialmente» y «No lo hice» se exponen como casilla (`checkbox`) con estado marcado.

- **No lo introduce esta migración.** El mismo build con el Material antiguo (desde `generation`) muestra
  lo mismo, y el código de semántica de `chip.dart` es idéntico en `flutter/material` y en `material_ui`.
- **Origen.** Es un cambio del paso de Flutter 3.32 a 3.50 en la web.
- **Android.** Usa `selected` y no hay diferencia.

## 4. Protecciones de Google Play

Con `newDsl` y `builtInKotlin` en `true` se repitió toda la matriz.

**APK release**, bloqueado en 5 casos:

- sin URL;
- con HTTP;
- con `10.0.2.2`;
- con IP privada;
- con dominio de prueba sin `-Pkora.testBackendUrl=true`.

**AAB**, bloqueado en 3 casos:

- sin configuración (6 motivos);
- con URL y páginas pero sin firma ni identificador;
- con el identificador propuesto pero sin firma.

**APK release de prueba permitido** (24,1 MB):

- INTERNET, minSdk 24 y targetSdk 36;
- sin tráfico en claro y no depurable;
- gesto atrás;
- alineado a 16 KB y 0 cadenas sensibles.

## Avisos no relacionados

`flutter build web` informa de que una dependencia web usa `dart:html`, lo que solo impide compilar a
WebAssembly. Kora compila la web en JavaScript, así que no es un error.

## Archivos

- **Código y pruebas:** 78 importaciones en `lib/` y `test/`. En `app.dart` y en dos pruebas además se
  quita `flutter_localizations`.
- **Dependencias:** `pubspec.yaml` y `pubspec.lock`.
- **Android:** `android/gradle.properties`, `android/app/build.gradle.kts` (comentario de Kotlin) y
  `android/settings.gradle.kts` (comentario).
- **CI:** `.github/workflows/ci.yml` (`flutter analyze` sin `--no-fatal-infos`).
- **Documentación:** este documento, notas en `MIGRACION_FLUTTER_3_50.md` y `README.md`, y la evidencia
  en `integracion_backend_5977/evidencia/material-ui/`.
