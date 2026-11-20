# Recuperación de contraseña con el backend 5977d28

## Qué cambió en la app (#8)

| Antes | Ahora |
|---|---|
| «Enviar enlace» y textos de enlace | «Enviar código». La pantalla siguiente explica: «Si el correo corresponde a una cuenta de Kora, te llegará un código… Caduca en 30 minutos y sirve una sola vez.» |
| La opción aparecía siempre | Solo con `--dart-define=PASSWORD_RECOVERY_ENABLED=true`. Sin ese valor, «¿Olvidaste la clave?» explica que la recuperación no está disponible y que hay que escribir al equipo del estudio |
| 400 genérico | «El código no es válido, ya se usó o caducó. Solicita uno nuevo.» |
| 429 sin mensaje propio | «Demasiadas solicitudes de recuperación. Espera un rato antes de volver a intentarlo.» |
| El correo se validaba con una expresión más estricta que en el registro (rechazaba `+` y dominios de más de 4 letras) | Una sola regla para registro, login y recuperación (`looksLikeEmail`, `323c8be`) |

La app **no dice que se haya enviado un correo**: repite el mensaje neutro, que no revela si la cuenta
existe.

### Cuándo activarla

`PASSWORD_RECOVERY_ENABLED=true` solo si el backend desplegado tiene
`fitsense.password-reset.delivery=email` con un proveedor de correo real y probado. Con `delivery=none`
(lo que había antes de #78), dejarla apagada.

## Pruebas por HTTP (`evidencia/contratos-2*.txt`)

| Caso | Resultado |
|---|---|
| Correo registrado | 202 neutro y un `.eml` en el servidor SMTP simulado |
| Correo inexistente | 202 con el mismo mensaje y **ningún** `.eml` |
| Código correcto | 204 |
| Código reutilizado | 400 |
| Código caducado (`expires_at` llevado al pasado en la base de prueba) | 400 |
| Código inexistente | 400 |
| Contraseña de menos de 8 caracteres | 400 de validación |
| JWT anterior al cambio | 401 |
| Contraseña antigua / nueva | 401 / 200 |
| Más de 3 solicitudes por hora | 429 |

## Prueba en la app con el backend real (`recuperar.js`, capturas `E-*`)

Se usaron dos navegadores: **A**, con la sesión abierta antes del cambio, y **B**, otro dispositivo sin
sesión.

| Paso | Resultado |
|---|---|
| B: Login → «¿Olvidaste la clave?» → correo → «Enviar código» | `POST /request` 202. Pantalla del código (`E-recuperar-correo`, `E-recuperar-codigo`) |
| Correo simulado | 1 `.eml` nuevo; el código de 43 caracteres se leyó del archivo |
| B: código inválido | 400 → «El código no es válido, ya se usó o caducó…» (`E-recuperar-invalido`) |
| B: código real y nueva contraseña | 204 → «Contraseña actualizada» y vuelta al login (`E-recuperar-hecho`). En la base: 1 token, marcado como usado |
| B: contraseña antigua | 401, sigue en el login |
| B: contraseña nueva | 200, entra |
| A: recargar | Su JWT ya no vale (401): la app borra la sesión y muestra el login (`E-sesion-antigua`) |

El primer intento destapó el defecto del correo `rec3@e2e.local` («Ingrese un correo válido»).
Corregido en `323c8be`, con prueba que falla con el código anterior.

## Pruebas automáticas

- `backend_alignment_test.dart`: rutas y cuerpos de `/request` y `/confirm`; opción apagada por
  defecto; mensajes 400 y 429.
- `recovery_email_format_test.dart` (2): mismas direcciones válidas en los tres formularios, y la
  recuperación envía la solicitud para `maria+d20@e2e.local`.

## Lo que no se afirma

- **No se envió ningún correo real**: solo existe el servidor SMTP local de pruebas.
- Falta elegir y configurar el proveedor de correo de producción (dominio remitente, SPF/DKIM) y
  probarlo con una cuenta real del equipo. Hasta entonces, compilar sin `PASSWORD_RECOVERY_ENABLED`.
