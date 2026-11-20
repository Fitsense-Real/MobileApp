# Revisión final de seguridad y compatibilidad (Flutter ↔ backend 5977d28)

La hizo un revisor independiente, en solo lectura, sin recibir las conclusiones previas. Revisó el diff
`generation..claude/play-e-backend-5977` y lo comparó con el código del backend en `5977d28`. Cada
hallazgo se verificó después en el código antes de actuar.

## Corregido en #8 (con pruebas que fallan con el código anterior)

| Sev. | Hallazgo | Corrección |
|---|---|---|
| Media | **Eliminación sin respuesta** (timeout o corte después de enviar): la app decía «No se eliminó nada», pero el backend desactiva la cuenta al aceptar la solicitud. Al reintentar llegaba un 401 y los datos locales de la cuenta se quedaban en el teléfono | Sin respuesta tras el envío, la app dice «no sabemos si la eliminación se registró». Si el siguiente intento recibe 401, borra los datos locales de esa cuenta y muestra «Tu cuenta probablemente ya se eliminó». Un 401 sin intento previo dudoso no borra nada |
| Baja | Si el borrado local fallaba después de un 200/202, el mensaje era «No se eliminó nada» | Cada paso del borrado local es independiente; la pantalla refleja lo que respondió el servidor |
| Baja | Cualquier 403 se mostraba como contraseña incorrecta | Solo `REAUTENTICACION_FALLIDA` es contraseña incorrecta; los demás 403 son «El servidor rechazó la solicitud» |
| Baja | Una contraseña solo de espacios pasaba el formulario y el backend (`@NotBlank`) la rechazaba; en recuperación se mostraba como «código no válido» | Regla común `passwordProblem` (8–72 y no solo espacios) en registro y recuperación |
| Baja | En release, el error de conexión pedía comprobar «el puerto 8080» | Ese texto queda solo en debug; en release: «Revisa tu conexión a internet» |

Pruebas: `account_deletion_test.dart` (+4) y `password_rules_test.dart` (2). La suite pasa de 200 a **206**.

## Documentado, sin cambiar

| Sev. | Hallazgo | Responsable | Motivo |
|---|---|---|---|
| Media | **B-6**: `/auth/login` no limita intentos (`LimitePorIp` solo cubre la recuperación y la eliminación web) | Backend | Fuera del alcance de Mobile. Antes de producción: límite en el backend o en el proxy |
| Media (latente) | El registro no envía `acceptedTermsVersion`/`acceptedPrivacyVersion` | Contrato (B-4) | Solo falla si se activa `enforce-on-signup`, que está apagado. Requiere el endpoint público de versiones |
| Baja | La pantalla de consentimientos permite aceptar aunque falte `TERMS_URL` o `PRIVACY_POLICY_URL` | Configuración | Regla de publicación: si el backend publica versiones, compilar con ambas URL. `PRIVACY_POLICY_URL` ya la exige el AAB |
| Baja | `apiError` muestra los `details` del backend tal cual (códigos internos) y el backend devuelve el mensaje de cualquier `IllegalArgumentException` | Sobre todo backend | Los casos conocidos usan textos propios en la app |
| Baja | `ALLOW_INSECURE_API=true` permite HTTP también en release para web e iOS | App (intencionado) | En Android, Gradle lo bloquea; web e iOS no se publican en esta fase |
| Baja (sospecha) | El manifiesto no declara reglas de copia de seguridad: un respaldo restaurado de `flutter_secure_storage` no se puede descifrar | Android | Solo deja la app en el login. Recomendado antes de Play: `allowBackup="false"` o reglas de exclusión, con prueba en un dispositivo |
| Baja | El manifiesto profile no permite HTTP hacia `10.0.2.2` | Android (funcional) | Solo afecta a builds profile |
| Baja | `debugPrint` en `reminder_scheduler.dart` llega al logcat en release | App | Solo imprime errores de notificaciones, sin datos personales |

## Comprobado sin problemas

- **Endpoints**: rutas, métodos, campos y códigos de todos los que usa la app (autenticación, `/users/me`,
  perfil, plan y generación, sesiones, informe, consentimientos, recuperación, eliminación) coinciden con
  5977d28. También los límites 8–72, 100/150/64 y correo ≤ 254.
- **Edad**: el texto del 422 coincide con `isMinimumAgeRejection` y la regla local es la del backend.
- **Ejercicios**: el denominador y la regla de «parcial» coinciden con `classify()` del backend.
- **JWT**:
  - se guarda en almacenamiento seguro y se borra al cerrar sesión;
  - los 401 solo cierran la sesión si la petición llevaba el token y la ruta es protegida, y se
    deduplican;
  - no se envía a login, registro ni recuperación.
- **Contraseñas**: no se guardan y solo viajan en login, registro, recuperación y `DELETE`. No hay
  `LogInterceptor`, y el `Logger` de providers solo corre en debug.
- **Varias cuentas**: los datos locales van por `userId`, y los providers del plan se reinician al cambiar
  de usuario.
- **Release**: exige una URL HTTPS pública, no hay tráfico en claro fuera de debug, `INTERNET` está
  declarado, y el AAB exige clave e identificador propios.
- **Operaciones destructivas**: sin envíos duplicados (guardia, botón deshabilitado y confirmación); la
  generación es idempotente.
- **Secretos**: ninguno real en el repositorio. Las credenciales locales de los arneses se pasaron a
  variables de entorno (`0a70831`).
