# Contrato propuesto: notificaciones push desde el backend (Spring Boot)

**Propuesta.** El backend `5977d28` no tiene nada de esto y esta PR no lo modifica. Es lo que el Mobile ya implementa.
Si el backend decide otra forma, se ajusta el Mobile en una PR pequeña.

## 1. Registro del dispositivo

### `PUT /api/v1/users/me/push-devices` (con sesión)

```json
{ "token": "<token de registro FCM>", "platform": "ANDROID", "appVersion": "1.0.0+1", "locale": "es" }
```

- **Idempotente por `token`:**
  - crea la fila o la actualiza (`lastSeenAt`);
  - si el token estaba asociado a **otra** cuenta (teléfono compartido), lo mueve a esta;
  - así un token nunca recibe mensajes de dos cuentas.
- **Respuesta:** `204` o `200`.
- **Mientras no exista:** el Mobile trata `404`, `405` y `501` como «backend no listo», sin error. Lo reintenta en el
  siguiente inicio de sesión.

### `DELETE /api/v1/users/me/push-devices/{token}` (con sesión; el token va codificado en la URL)

- **Cuándo:** el Mobile lo llama antes de cerrar sesión.
- **Respuesta:** `204`, aunque el token no exista.

### Tabla sugerida `push_devices`

| Columna | Tipo |
|---|---|
| `push_device_id` | PK |
| `user_id` | FK → `users`, `ON DELETE CASCADE`: **eliminar la cuenta borra sus tokens** |
| `token` | `varchar(4096)`, **único** |
| `platform` | `varchar(16)`, `ANDROID` |
| `app_version`, `locale` | Opcionales |
| `created_at`, `last_seen_at` | `timestamptz` |

- **El token es un dato personal** (identificador del dispositivo):
  - nunca en los logs; hay que tener en cuenta el hallazgo S-1;
  - no exponerlo en ninguna respuesta.

## 2. Envío

- **SDK:** Firebase Admin SDK para Java (`com.google.firebase:firebase-admin`), con **FCM HTTP v1**.
- **Credencial:** cuenta de servicio del proyecto `kora-fitpe` con el rol mínimo para enviar mensajes. Se guarda en el
  gestor de secretos del despliegue (variable o volumen), **nunca en el repositorio** ni en la app.
- **Destino:** los **tokens de registro FCM** de `push_devices`. No uses *Firebase Installation IDs* ni temas
  compartidos para mensajes personales.
- **Errores:** si FCM responde `UNREGISTERED` o `INVALID_ARGUMENT` para un token, hay que **borrarlo**, porque la app se
  desinstaló o el token caducó.
- **Formato de cada mensaje:** parte `notification` (lo que Android muestra con la app cerrada) y parte `data` (lo que
  la app usa para abrir la pantalla correcta):

```json
{
  "message": {
    "token": "<token>",
    "notification": { "title": "¡Tu rutina está lista!", "body": "Tu plan de esta semana ya está en Kora." },
    "data": { "type": "PLAN_GENERATED", "planId": "123" },
    "android": {
      "priority": "NORMAL",
      "collapse_key": "plan",
      "notification": { "channel_id": "kora_avisos", "icon": "ic_stat_kora" }
    }
  }
}
```

- **Valores de `data`:** todos son *strings*, como exige FCM.
- **Textos:** en español y sin datos de salud. **Nada de diagnósticos, dolor, peso ni adherencia en el texto**, porque
  se ve en la pantalla de bloqueo.

## 3. Eventos

| `type` | Cuándo lo envía el backend | `data` | Qué hace la app al tocar |
|---|---|---|---|
| `PLAN_GENERATED` | Una operación de generación termina en `COMPLETED` (primer plan o regenerado) | `planId` | Abre «Preparación de cuenta», que muestra el resultado, el recorrido o el inicio según el estado |
| `PLAN_ADAPTED` | El ciclo semanal publica un plan adaptado | `planId` | Abre Progreso (resumen de ajustes) |
| `WEEKLY_PLAN_READY` | El ciclo crea el plan de la semana nueva | `planId` | Abre Inicio |
| `ACCOUNT_NOTICE` | Avisos de la cuenta: consentimientos nuevos, eliminación solicitada, avisos del estudio | Opcional | Abre Perfil |

- **Con la app abierta:** los tres primeros recargan el plan. `PLAN_GENERATED` además consulta la generación al momento
  si se estaba esperando.
- **Si el envío falla:** la app sigue funcionando. La generación asíncrona ya se consulta cada `pollAfterSeconds`, así
  que el push no cambia ninguna regla ni el contrato de generación; solo avisa antes.

## 4. Lo que no cambia

No hay reglas deportivas, adherencia, V24, V8C, progresión, reincorporación ni Replicate en este contrato: el push solo
notifica resultados que el backend ya produce.
