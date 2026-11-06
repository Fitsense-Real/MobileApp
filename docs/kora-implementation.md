# Interfaz Kora

Implementación Flutter de los mockups suministrados: bienvenida, acceso,
registro, recuperación de contraseña, perfil inicial de cinco pasos,
inicio, rutinas, progreso, perfil y sesión de entrenamiento.
Las fotografías y el logotipo se extrajeron de los PDF originales. Poppins
se incluye localmente con su licencia OFL, sin descargas en tiempo de ejecución.

## Flujos

- Comenzar ahora → registro → login → perfil inicial → inicio.
- Inicia sesión → autenticación → inicio si el perfil existe, o perfil inicial.
- Rutinas: filtros, favoritos y apertura de sesión; Fuerza Total permite
  registrar cuatro series con peso y repeticiones.
- Entrenamiento: temporizador, pausa, reanudar y cambio de ejercicio.
- Perfil: favoritos, preferencias, cuenta, ayuda y cierre de sesión existente.

## Alcance de datos

Acceso, registro y perfil están conectados al backend local. El cierre de sesión
borra el JWT local. Ver `local-backend.md` para contratos y pruebas reales.
La recuperación de contraseña no existe en el backend; el enlace lo explica.
Rutinas, estadísticas, reto y sugerencias son ejemplos locales; no hay una
integración de IA ni persistencia remota para ellos. El perfil se guarda, se recupera y se edita en el backend con JWT. Los favoritos
se guardan solo en el dispositivo (el backend no tiene endpoint para ellos). Los registros de series duran mientras la sesión está abierta.
Google y Apple aparecen deshabilitados hasta implementar sus proveedores.

## Ejecutar y verificar

El proyecto requiere Dart >=3.8 y Flutter >=3.32. La instalación encontrada
en PATH (Flutter 3.29.3 / Dart 3.7.2) es anterior a estos requisitos.
Se descargó Flutter 3.32.8 en `tmp/flutter-sdk` para las verificaciones sin
alterar la instalación global. `tmp` está excluido de Git y del analizador.

```powershell
.\tmp\flutter-sdk\bin\flutter.bat test --no-pub
.\tmp\flutter-sdk\bin\flutter.bat analyze --no-pub lib test
.\tmp\flutter-sdk\bin\flutter.bat build web --no-pub
```

Para desarrollar normalmente, configurar un SDK compatible en el IDE y ejecutar
`flutter pub get`. En Windows, los plugins de escritorio requieren soporte
para enlaces simbólicos (modo de desarrollador). La compilación web no lo requiere.

Las pruebas cubren navegación inicial, validación del registro, filtros,
favoritos, validación del perfil, pausa del temporizador y pantallas de 320 px
con escala de texto 1.3. Las capturas de revisión están en `tmp/previews`.
