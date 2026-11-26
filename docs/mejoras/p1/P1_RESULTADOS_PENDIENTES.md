# P1 · Resultados pendientes guardados de forma segura

**Rama:** `claude/p1-pendientes-persistentes`, sobre `generation` `6be9aef` (con O20 y la PR #20).

**Alcance:** solo Mobile. No cambia el Backend, O20 ni D-M1.

## Problema

Los resultados que la app no puede enviar se guardaban solo en memoria:

- **pendientes:** no se pudo confirmar la rutina, o la respuesta se perdió;
- **retenidos:** la rutina ya no los admite.

Si Android terminaba el proceso, se perdían.

## Solución

`lib/features/workouts/data/pending_results_store.dart` (`PendingResultsStore`):

| Aspecto | Decisión |
|---|---|
| **Dónde** | El almacenamiento seguro de la app (`appSecureStorage`: Android Keystore / iOS Keychain), con **su propia clave por cuenta**: `kora_pending_results_<userId>`. Es una clave y un ciclo de vida distintos de los del token de sesión (`access_token`) |
| **Qué se guarda** | Solo el cuerpo exacto del `PUT` (`actualSets`, `actualRepsTotal`, `actualDurationSeconds`, `actualLoadKg`, `skipReason`), los identificadores numéricos (cuenta, sesión, entrenamiento, ejercicio), el estado (`pending`, `maybeSent`, `held`) y la hora. **Ni JWT, ni correo, ni nombre** |
| **Asociación a la cuenta** | El identificador numérico de la cuenta, en la clave y en cada entrada. **Nunca el JWT** |
| **Otra cuenta** | Su clave es otra. Una entrada con otro identificador de cuenta se trata como dañada y se descarta |
| **Caducidad** | 48 h desde que se anotó. Al leer, lo caducado se descarta sin enviarse y se avisa |
| **Cerrar sesión** | **Política:** se conservan, cifrados, para esa misma cuenta y dentro de las 48 h, para que la persona los recupere al volver a entrar. No se muestran a otra cuenta |
| **Borrar la cuenta** | La clave está en `LocalAccountData.keysOf`, así que se elimina con el resto de los datos locales de la cuenta |
| **Datos dañados o incompletos** | Si el JSON es inválido o hay campos ausentes o inesperados, cantidades negativas o un estado desconocido, la entrada se descarta, se avisa al usuario y el almacén se reescribe sin ella. **Nunca se envía** |
| **Fallo del almacenamiento** | Se avisa. El resultado sigue en pantalla con la advertencia «se perderá si cierras la app». Nunca se envía sin validar |
| **Logs** | El almacén no escribe nada en los logs |
| **Sin cuenta iniciada** | No se guarda nada en el teléfono |

**Regla crítica:** desde el almacenamiento **nunca se envía nada automáticamente**. Al abrir la rutina:

1. **Se recuperan los resultados** de esa cuenta y de esa rutina.
2. **Si su sesión ya no es la sesión abierta** (por ejemplo, se finalizó o el Backend la cerró), quedan **retenidos**.
3. **Se relee el plan.** Lo que la rutina ya no admite, porque el ejercicio se bloqueó o la rutina se reemplazó, pasa a **retenido**.
4. **El usuario revisa, descarta o pulsa «Reintentar envío».** El envío pasa por todo el flujo de O20:
   - confirmar la rutina con el Backend (máximo 8 s);
   - comprobar el ejercicio;
   - si quizá ya llegó, consultar `GET /sessions/current` antes de repetir;
   - el `PUT` reemplaza el resultado, nunca acumula.

**Alcance del guardado:** solo los resultados del registro en vivo (pendientes y retenidos). Los borradores del registro retroactivo siguen en memoria, como hasta ahora.

## Casos de la orden (`test/pending_results_persistence_test.dart`, 14 pruebas)

| Caso | Comprobación |
|---|---|
| **A.** La app se cierra con un pendiente | Reaparece en la misma cuenta. **No se envía solo,** aunque haya vuelto la red. «Reintentar envío» confirma la rutina y lo envía una vez; después desaparece del teléfono |
| **B.** El ejercicio se bloquea con la app cerrada | Al volver: retenido, no se envía, el ejercicio aparece bloqueado. «Descartar» lo quita también del teléfono |
| **C.** El Backend lo recibió pero se perdió la respuesta | Queda guardado como `maybeSent`. Tras reabrir y reintentar se consulta la sesión y no se repite |
| **D.** Cambia la cuenta | La cuenta 8 no ve nada de la 7. La 7 lo recupera al volver |
| **E.** El plan original ya no está vigente | No se envía nada incompatible; la rutina vieja no se puede registrar |
| **—** La sesión se cerró con la app cerrada | Retenido, no se envía |
| **F.** Datos dañados | Aviso «…estaban dañados y se descartaron. No se ha enviado nada», sin pendientes |
| **F.** Fallo del almacenamiento | Aviso al leer y al guardar; el resultado sigue en pantalla y no se envía sin validar |
| **G.** Resultado parcial | Se guardan las cantidades reales (1 serie, 12 repeticiones, «Fatiga») y se envían tal cual tras validar (D-M1) |
| **Almacén** | Clave por cuenta, sin JWT ni correo; caducidad de 48 h; entradas dañadas descartadas; error al leer o escribir; clave incluida en el borrado de la cuenta |
| **Sin cuenta** | No se guarda nada |

**Prueba a la inversa:**

- si se reenvían solos al reabrir, fallan los casos A y C;
- si no se comprueba la sesión al restaurar, falla «la sesión se cerró con la app cerrada».
