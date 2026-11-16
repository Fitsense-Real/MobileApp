# Guía: instalar Kora en un teléfono Android y probarla con el backend local

El APK lleva la dirección del backend **compilada** (`--dart-define=API_BASE_URL`), así que se elige
el APK según cómo se conecte el teléfono. `localhost` en el teléfono es el propio teléfono, no tu PC:
por eso la opción recomendada usa `adb reverse` por cable USB, que no expone el backend en la red.

## 1. Obtener el APK

| APK | Dirección del backend | Uso |
|---|---|---|
| `kora-debug-telefono-usb-arm64.apk` (57 MB, arm64) | `http://localhost:8080/api/v1` | **teléfono físico por USB** con `adb reverse` (recomendado) |
| `kora-debug-telefono-usb.apk` (129 MB, todas las arquitecturas) | ídem | teléfonos de 32 bits u otras arquitecturas |
| `kora-debug-emulador.apk` (129 MB) | `http://10.0.2.2:8080/api/v1` | emulador de Android Studio |
| `kora-release-sin-firma-definitiva.apk` (29 MB) | — | solo comprueba que el release compila. **No sirve para probar**: el release no permite HTTP sin cifrar y está firmado con la clave debug |

SHA-256 de los entregados (rama `claude/mobile-final-validation`):

```
a08c266ad9afdbdf16c7730023ab84f6b7f9eae4db00cc506016a8fdfd9b1a95  kora-debug-telefono-usb-arm64.apk
e440d86afe3c9eaecd386ad0d4aacd1bfd124cad309721a1f32977d7dd272b81  kora-debug-telefono-usb.apk
77e423faced270f0a3afa0b08e00383aa967c35d70eb7ada0103e09b2051657a  kora-debug-emulador.apk
```

Para compilarlos tú mismo, desde la carpeta `MobileApp` y la rama `claude/mobile-final-validation`:

```powershell
.\tmp\flutter-sdk\bin\flutter.bat build apk --debug --split-per-abi --target-platform android-arm64 --dart-define=API_BASE_URL=http://localhost:8080/api/v1
```

Queda en `build\app\outputs\flutter-apk\app-arm64-v8a-debug.apk`.

## 2. Levantar el backend de pruebas en tu PC

Rama del backend: `fix/async-generacion-resiliente` (#72, incluye #71). Usa una base **local**, nunca
la de producción, y la IA apagada (motor de reglas, sin Replicate):

```powershell
createdb -U postgres fitsense_movil
$env:SPRING_APPLICATION_JSON = "{}"
.\mvnw spring-boot:run "-Dspring-boot.run.arguments=--spring.datasource.url=jdbc:postgresql://localhost:5432/fitsense_movil --spring.datasource.username=postgres --spring.datasource.password=TU_CLAVE_LOCAL --authorization.jwt.secret=una-clave-local-de-al-menos-32-caracteres --fitsense.ai.enabled=false --fitsense.ai.api-token="
```

Cuando el log diga `Started FitsenseApplication`, la API está en `http://localhost:8080/api/v1`.

## 3. Conectar el teléfono al backend (USB, recomendado)

1. En el teléfono: **Ajustes → Acerca del teléfono → toca 7 veces «Número de compilación»**; luego
   **Ajustes → Sistema → Opciones de desarrollador → Depuración USB** activada.
2. Conecta el cable y acepta «¿Permitir depuración USB?».
3. En el PC (`adb` viene con Android Studio, en `%LOCALAPPDATA%\Android\Sdk\platform-tools`):

```powershell
adb devices
```

Debe aparecer tu teléfono como `device`. Luego:

```powershell
adb reverse tcp:8080 tcp:8080
```

Desde ese momento, `localhost:8080` en el teléfono llega al backend del PC **solo por el cable**.
Repite `adb reverse` cada vez que reconectes el teléfono.

### Alternativa por Wi-Fi (solo en tu red privada)

Compila con la IP LAN del PC (`ipconfig` → IPv4, por ejemplo `192.168.1.20`):

```powershell
.\tmp\flutter-sdk\bin\flutter.bat build apk --debug --dart-define=API_BASE_URL=http://192.168.1.20:8080/api/v1
```

Permite el puerto 8080 en el firewall de Windows **solo para redes privadas** y ciérralo al terminar.
No publiques el backend en Internet ni uses redes públicas.

## 4. Instalar el APK

```powershell
adb install -r kora-debug-telefono-usb-arm64.apk
```

Sin cable: copia el APK al teléfono, ábrelo y permite «Instalar apps desconocidas» para el gestor de
archivos. Para desinstalar: `adb uninstall com.example.fitsense_mobile`.

## 5. Ejecutar el recorrido de Kapi

1. Abre **Kora** → «Comenzar ahora» → crea una cuenta con un correo de prueba (por ejemplo
   `prueba1@local.test`) y marca la participación en el estudio.
2. Inicia sesión y completa los **5 pasos del perfil**; pulsa **«Generar mi plan»**.
3. El tour empieza de inmediato: recorre los 10 pasos. En el paso 3, toca la pestaña **Rutinas** real.
4. Pruebas recomendadas:
   - **Cerrar y reabrir:** en el paso 5, cierra Kora desde Recientes y ábrela: continúa en el paso 5.
   - **Sin conexión:** en la espera, activa el modo avión: «Seguimos intentando», con Kapi. Quítalo y aparece el plan.
   - **Texto grande:** Ajustes → Pantalla → Tamaño de fuente al máximo.
   - **TalkBack:** solo debe leer la tarjeta de Kapi.
   - **Animaciones:** «Quitar animaciones» deja a Kapi estático.
5. «Ver mi plan» → Inicio con la etiqueta de la semana (por ejemplo «7 DÍAS» o «EMPIEZA MAÑANA») →
   Rutinas → abre una sesión.
6. Perfil → **«Ver recorrido de Kora»**: el repaso no debe decir que tu rutina se está preparando.

## 6. Comprobar que se generó la rutina

En la app: «¡Tu primera rutina está lista!» con la semana y el número de entrenamientos.

En la base local:

```sql
SELECT u.email, o.status, o.reason_code, o.plan_id, o.executions
FROM plan_generation_operations o JOIN users u USING (user_id)
ORDER BY o.created_at DESC LIMIT 5;

SELECT u.email, count(*) AS planes
FROM weekly_training_plans p JOIN users u USING (user_id)
GROUP BY u.email;
```

Esperado: `COMPLETED` con `plan_id` y **un** plan por usuario. En la consola del backend:
`Generacion inicial … completada: plan N del usuario M`.

## 7. Registros si algo falla

```powershell
adb logcat -c
```

Reproduce el fallo y luego:

```powershell
adb logcat -d > kora-logcat.txt
```

```powershell
adb logcat -d -s flutter > kora-flutter.txt
```

```powershell
adb exec-out screencap -p > kora-captura.png
```

Guarda también la consola del backend (o `> backend.log`) y la hora aproximada del fallo. La app no
escribe contraseñas, tokens ni datos de salud en el log.
