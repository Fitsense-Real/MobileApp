# Identificador de la aplicación (PR B)

## Estado

| | Valor |
|---|---|
| Actual | `com.example.fitsense_mobile` (plantilla de Flutter) |
| Propuesto | **`pe.fitsense.kora`** |
| Aprobado | **pendiente de la decisión del propietario** |

El identificador es permanente en Google Play: no se puede cambiar después de la primera subida. Por
eso esta PR **no lo fija**. Lo deja configurable y bloquea el AAB mientras siga siendo el de ejemplo.

## Por qué `pe.fitsense.kora`

- `pe.fitsense`: dominio inverso del estudio FitSense en Perú (zona horaria por defecto `America/Lima`
  y ámbito del estudio).
- `.kora`: nombre de la app publicada.

Alternativa si la titularidad es de otra organización, por ejemplo una universidad:
`pe.edu.<universidad>.kora`. Debe corresponder a un dominio o identidad que controlen.

## Comprobaciones antes de aprobarlo

| Comprobación | Resultado |
|---|---|
| Formato Android válido (segmentos en minúsculas, sin palabras reservadas) | ✓ |
| No usado en vuestra Play Console | **lo tiene que comprobar el propietario**: este entorno no tiene acceso a Play Console |
| Corresponde a una identidad que controlaréis | decisión del propietario |
| Firebase | el proyecto no usa Firebase ni tiene `google-services.json`: no hay nada que actualizar |
| Compilación | AAB generado con `-Pkora.applicationId=pe.fitsense.kora`: el manifiesto del `.aab` contiene `pe.fitsense.kora` ✓ |

## Cómo se configura

`android/app/build.gradle.kts`:

```kotlin
applicationId = koraApplicationId   // propiedad Gradle kora.applicationId; si falta, com.example.fitsense_mobile
```

**Cuando lo aprobéis**, una línea en `android/gradle.properties` (versionado, no es un secreto):

```properties
kora.applicationId=pe.fitsense.kora
```

`bundleRelease` se niega a compilar mientras sea `com.example.*`.

## Lo que no se cambia

- `namespace = "com.example.fitsense_mobile"` y el paquete Kotlin de `MainActivity`. Son internos: Play
  solo usa el `applicationId`, y cambiarlos obligaría a mover clases sin beneficio. En el AAB de
  verificación, la actividad sigue siendo `com.example.fitsense_mobile.MainActivity` con
  `applicationId` `pe.fitsense.kora`, una combinación válida.
- Pruebas y CI: no dependen del identificador.

## Efecto en instalaciones de prueba

Un APK con otro `applicationId` se instala como **otra app**, junto a la de `com.example`. Conviene
desinstalar la versión anterior de los teléfonos de prueba.
