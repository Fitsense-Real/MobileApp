# Limpieza de accesos sociales inactivos (PR D)

## Problema original

En **Iniciar sesión** se mostraban «O CONTINÚA CON», dos botones desactivados («G GOOGLE» y
«● APPLE», `onPressed: null`) y el texto «Acceso social próximamente». No hay OAuth implementado.
Los revisores de Google Play tratan los controles que no hacen nada como funcionalidad rota o engañosa.

Comprobado en la app web real antes del cambio: el árbol de semántica tenía los botones `G GOOGLE` y
`● APPLE` (`capturas/D-login-antes.jpg`).

## Corrección

`lib/features/authentication/presentation/widgets/kora_auth_form.dart`: se quitó el bloque completo
(separador, los dos botones y el texto). No se añadieron dependencias ni se tocó la autenticación.
El acceso por correo y contraseña y la recuperación de contraseña siguen igual.

| Pantalla | Antes | Después |
|---|---|---|
| Iniciar sesión | separador, botones Google y Apple desactivados, «próximamente» | correo, contraseña, «¿Olvidaste la clave?», «INICIAR SESIÓN», enlace a registro |
| Registro | no tenía accesos sociales | sin cambios |
| Bienvenida | no tenía accesos sociales | sin cambios |

No quedan textos ni traducciones que mencionen Google, Apple o el acceso social (búsqueda en `lib/`).

## Pruebas

`test/auth_social_cleanup_test.dart` (4):

- login y registro sin Google, Apple, «O CONTINÚA CON» ni «próximamente», sin botones desactivados y
  con el formulario de correo y contraseña;
- login y registro a 320 px con texto 1,5, sin desbordamientos.

Falla con el código anterior (comprobado) y pasa con la corrección.

En la app web después del cambio, la semántica solo tiene «Volver», «Mostrar contraseña»,
«¿Olvidaste la clave?», «INICIAR SESIÓN» y «Únete a la comunidad Kora»
(`capturas/D-login-despues.jpg`).

## Nota

«¿Olvidaste la clave?» funciona en la app, pero el backend todavía no envía el correo
(`fitsense.password-reset.delivery=none`). Está registrado en `PENDIENTES_Y_DEPENDENCIAS.md`.
