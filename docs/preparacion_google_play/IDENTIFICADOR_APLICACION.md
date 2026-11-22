# Identificador de la aplicación

## Estado

| | Valor |
|---|---|
| **Aprobado por el propietario** | **`pe.fit.kora`** |
| Proyecto Firebase | `kora-fitpe`, con la app Android `pe.fit.kora` registrada por el propietario con FlutterFire CLI |
| `applicationId` | `pe.fit.kora` por defecto en `android/app/build.gradle.kts`. Ya no depende de una propiedad local |
| `namespace` y paquete de `MainActivity` | `pe.fit.kora` (`android/app/src/main/kotlin/pe/fit/kora/MainActivity.kt`). No queda ninguna referencia de ejemplo |
| Antes | `com.example.fitsense_mobile` (plantilla de Flutter). Se propuso `pe.fitsense.kora`, que **ya no se usa** |

El identificador es **permanente** en Google Play: tras la primera subida de un AAB no se puede cambiar.

## Cómo queda configurado

```kotlin
val approvedApplicationId = "pe.fit.kora"
val koraApplicationId = findProperty("kora.applicationId") ?: approvedApplicationId
namespace = "pe.fit.kora"
applicationId = koraApplicationId
```

- **Por defecto:** todas las compilaciones (debug, release de prueba, AAB) usan `pe.fit.kora`. Ya no hace falta
  `kora.applicationId=pe.fit.kora` en `gradle.properties`. Si lo tienes en local, puedes dejarlo, porque es el mismo
  valor, o quitarlo.
- **Para el AAB de Play**, el guardián de Gradle bloquea la compilación si:
  - el identificador empieza por `com.example` (como antes);
  - el identificador no es exactamente `pe.fit.kora`, aunque se haya cambiado con `-Pkora.applicationId`;
  - falta `android/app/google-services.json`, o no contiene la app `pe.fit.kora`.

  Siguen intactos los demás controles (HTTPS, sin hosts locales, clave propia, eliminación de cuenta, páginas
  públicas).

## Transición desde `com.example.fitsense_mobile`

**Cambiar el identificador crea otra aplicación para Android.** Una instalación de `com.example.fitsense_mobile` y una
de `pe.fit.kora` son apps distintas:
- se instalan **una junto a la otra**, con dos íconos de Kora;
- `adb install -r` de `pe.fit.kora` **no** actualiza la antigua;
- Android **no transfiere datos** entre ellas.

| Dato | Dónde vive | ¿Pasa a `pe.fit.kora`? |
|---|---|---|
| Cuenta, perfil, planes, sesiones, adherencia | Backend | **Sí**: basta con iniciar sesión con la misma cuenta en el mismo backend |
| Sesión iniciada (token) | Teléfono, almacenamiento seguro | **No**: hay que volver a iniciar sesión |
| Progreso del recorrido de Kapi | Teléfono | **No**: si el plan ya existe, la app entra al inicio. El recorrido puede verse desde Perfil |
| Preferencias de recordatorios | Teléfono | **No**: hay que activarlos otra vez |
| Rutinas favoritas | Teléfono | **No**: hay que marcarlas otra vez |
| Recordatorios programados | Sistema de la app antigua | **No**: siguen siendo de la app antigua hasta desinstalarla |

**Cómo pasar sin perder información importante** (equipo y teléfonos de prueba):
1. En la app **antigua**, anota tus rutinas favoritas y la hora de tus recordatorios. Todo lo demás está en el backend.
2. Instala la app **nueva** (`pe.fit.kora`) e inicia sesión con **la misma cuenta y el mismo backend**.
3. Comprueba que aparecen tu plan, tus sesiones y tu progreso.
4. Vuelve a activar los recordatorios y a marcar tus favoritas.
5. Cuando todo esté bien, **desinstala la antigua**, para no tener dos Kora ni recordatorios duplicados:

   ```
   adb uninstall com.example.fitsense_mobile
   ```

**Participantes reales:** no hay ninguno con la app antigua, porque Kora no se distribuyó. Para ellos no hay
transición: la primera instalación ya será `pe.fit.kora`.

### Efecto en la prueba de actualización de la PR #13

Los APK preparados para el Samsung (`PRUEBA_ACTUALIZACION_SAMSUNG.md`) usan `com.example.fitsense_mobile`.
- **Siguen sirviendo** para comprobar la migración de `flutter_secure_storage` 9 → 10, porque es la misma app en las dos
  versiones.
- **El riesgo real disminuye:** ninguna instalación de `pe.fit.kora` ha usado nunca la 9.x, ya que el identificador
  nuevo llega con la 10. Toda instalación de `pe.fit.kora` empieza sin datos que migrar.
- **Lo que hay que probar ahora en `pe.fit.kora`:**
  - instalación limpia;
  - inicio de sesión;
  - notificaciones push;
  - recordatorios;
  - una actualización de `pe.fit.kora` a `pe.fit.kora`, de versionCode 1 a 2, con la misma firma.

  Pasos en `docs/push/PRUEBAS_PUSH_E_IDENTIFICADOR.md`.

## Comprobaciones

| Comprobación | Resultado |
|---|---|
| Formato Android válido | ✓ |
| APK debug y APK release de prueba con `pe.fit.kora` | ✓ (`aapt dump badging`; ver `docs/push/PRUEBAS_PUSH_E_IDENTIFICADOR.md`) |
| Plugin de Google Services y configuración de la app `pe.fit.kora` | ✓ con el `google-services.json` **real** de `kora-fitpe`, que el propietario subió en `62083b2`: el APK debug y el release de prueba llevan los recursos de Firebase con `project_id` `kora-fitpe` (`docs/push/evidencia/configuracion-real-kora-fitpe.txt`) |
| Disponible en Google Play | Solo Play Console lo confirma al crear la app y subir el primer AAB |
| Dominio `fit.pe` | Play no lo exige. Si el equipo no controla `fit.pe`, conviene saberlo antes de la primera subida, porque el identificador será permanente |
