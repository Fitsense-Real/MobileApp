# 05 · Recuperación de contraseña (M4)

**Sin cambios en Mobile** y **sin PR Mobile-C2**: contra el Backend `41c498a` todo funciona como en la orden anterior.

## 1. Revisión contra el Backend `41c498a` local (correo `dev-log`)

| Punto | Resultado | Cómo |
|---|---|---|
| Solicitar código | ✓ 202 | App real y API |
| Correo sin cuenta | ✓ El mismo 202 (no revela nada) | API |
| «Ya tengo un código» | ✓ Abre la pantalla del código sin pedir otro | Pruebas automáticas (`password_recovery_flow_test`) |
| Pegar código | ✓ La app quita espacios y saltos (`normalizeRecoveryCode`). Sin esa limpieza el Backend responde 400 | Pruebas automáticas + API |
| Solicitar uno nuevo | ✓ 202 y un código distinto | API |
| Usar el código | ✓ 204 → acceso con el correo escrito → login 200 con la clave nueva | App real |
| Un solo uso | ✓ Reutilizarlo → 400 | API |
| Caducidad (30 min) | Mensaje probado en pruebas automáticas; no se esperó la caducidad real | — |
| Error 429 | ✓ Tras 17 solicitudes seguidas: 429 con `Retry-After: 883`. En la recuperación, la app muestra su propio mensaje («Demasiadas solicitudes de recuperación…») | API + pruebas automáticas |
| Sesión antigua revocada | ✓ El JWT anterior → 401 tras el cambio | API |
| Volver al login | ✓ Con el correo escrito | App real |
| Reabrir la app durante el proceso | «Ya tengo un código» no depende de que la app siga abierta. Probarlo con la app cerrada por el sistema queda en la matriz Android (B2) | Pruebas automáticas; teléfono pendiente |

Evidencia: [`evidencia/recuperacion-41c498a.txt`](evidencia/recuperacion-41c498a.txt). El código se leyó del log de la
instancia local, nunca de un log de producción, y no se guarda en ningún archivo.

**Observación para el Backend (P2):** pedir un código nuevo **no invalida el anterior**. El primero sirvió (204) y, al
usarse, invalidó el segundo. No es un fallo de Mobile, que no promete lo contrario; conviene que el Backend invalide
los códigos anteriores al emitir uno nuevo.

## 2. Compilaciones

| Uso | `PASSWORD_RECOVERY_ENABLED` |
|---|---|
| Cualquier compilación para personas | `false` (por defecto) mientras no haya correo operativo: «¿Olvidaste la clave?» dice que no está disponible y remite al equipo |
| QA contra un Backend de pruebas | `true` en la compilación de QA ([06](06_QA_ANDROID.md) §2): el código se lee del log del Backend de pruebas con `dev-log` |

## 3. Para habilitar el correo real

Estado: **BLOQUEADO POR BACKEND**.

1. **Backend / infraestructura:** configurar el proveedor (`fitsense.mail.transport=smtp|resend|brevo`, remitente y
   plantilla; la clave solo por variable de entorno) y `fitsense.password-reset.delivery` según los procedimientos de
   B4. Mobile no cambia credenciales ni proveedores.
2. Probar el envío a un **buzón sintético** en el entorno de pruebas: el correo llega y la recuperación termina en
   menos de 3 minutos (matriz Android, B5).
3. Solo entonces, compilar con `PASSWORD_RECOVERY_ENABLED=true` las versiones para participantes.
