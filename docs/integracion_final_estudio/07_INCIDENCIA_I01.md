# 07 · Incidencia I-01: 401 de fondo al cerrar sesión (Mobile-C3, PR #34)

> **Revisión del 28/11/2026 (orden de merge):** ver [10](10_REVISION_FINAL_Y_BACKEND_96.md). El registro exige ahora
> los **tres** documentos publicados y Mobile usa los códigos estables de Backend #96. Backend #96 se fusionó
> (`434a9dc`) y después se fusionaron #33 (`ed11b5a`) y #34 (`9e9ebbc`).

Prioridad P2. Comportamiento previo a las PR #26–#31, documentado en `docs/cierre_preproduccion/11` §4.3.

## 1. Causa

Las consultas por cuenta observan el id del usuario (`ref.watch(authViewModelProvider.select((s) => s.user?.id))`)
para reiniciarse al cambiar de cuenta, y gracias a eso nunca se ven datos de otra cuenta. Al cerrar sesión ese id pasa
a `null`. Las consultas se relanzaban mientras el Inicio aún estaba montado, pero el token ya se había borrado:

```
GET /users/me/interventions 401
GET /users/me/metrics/weekly 401
GET /users/me/profile 401
```

Según la pantalla abierta, también podían relanzarse el historial, las limitaciones, las adaptaciones y las tres
consultas de dolor/O20.

## 2. Comprobaciones previas (orden §9)

| Riesgo | Resultado |
|---|---|
| Exposición de datos entre cuentas | **No.** El reinicio por cuenta funciona: la cuenta siguiente usa solo su token y su Perfil muestra solo su correo |
| Restauración accidental de la sesión anterior | **No.** Un 401 sin token no restaura nada |
| Mensajes erróneos visibles | **No.** La pantalla ya está en el acceso |
| Reintentos infinitos | **No.** Una sola vez por consulta |
| Persistencia indebida de datos personales | **No.** Nada se guarda a raíz de esas consultas |

Solo eran solicitudes tardías y el arreglo no toca la autenticación ni P1, así que se corrigió en una PR independiente.

## 3. Corrección

`watchAccount(ref)` (`authentication/presentation/providers/account_scope.dart`): las nueve consultas por cuenta lo
observan igual que antes, pero **sin cuenta no envían nada** y devuelven vacío (`[]`, `{}` o `null`). Con otra cuenta
se recargan con su propio token.

No cambia `logout()`, el borrado del token, el almacenamiento seguro, la restauración de sesión, P1, O20 ni D-M1.
`currentPlanProvider` ya comprobaba la sesión y no se tocó.

## 4. Pruebas

| Prueba | Resultado |
|---|---|
| `test/logout_requests_test.dart`: con sesión, una petición por consulta; al cerrar, **ninguna** más y los datos quedan vacíos; con otra cuenta, recarga con `Bearer jwt-8` | ✓ con la corrección; **falla con el código anterior** (detecta la incidencia) |
| Suite completa en la rama C3 | 495 ✓ · 0 ✗ · 31 omitidas |
| App real contra el Backend local: cerrar sesión y entrar con otra cuenta | **0 respuestas 401** (antes 3) |

Evidencia: [`evidencia/i01-antes-despues.txt`](evidencia/i01-antes-despues.txt).

Dos pruebas existentes (`adaptation_history_test`, `pain_o20_test`) abrían pantallas sin una cuenta iniciada, algo que
en la app no ocurre (el login y la restauración fijan siempre el usuario). Ahora inician sesión; lo que comprueban no
cambia.

Estado: **PREPARADO SIN ACTIVAR** (PR #34 abierta, sin fusionar).
