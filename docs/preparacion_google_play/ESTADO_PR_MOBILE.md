# Estado de las PR de Mobile

## Estado final (20/11/2026): las ocho PR están fusionadas en `generation`

Fusión autorizada por el propietario y hecha en orden, con commit de fusión (no squash, para conservar la
pila). Antes de cada paso se verificó que la siguiente PR apuntaba a `generation`, que su diff contenía solo
sus propios commits y que el CI estaba en verde.

| Orden | PR | Commit fusionado | Commit de fusión en `generation` | CI de `generation` tras la fusión |
|---|---|---|---|---|
| 1 | #1 Kapi | `400ee39` | `a83b00c` | — (el flujo llega con #3; 97 pruebas en local) |
| 2 | #2 Tour y generación asíncrona | `f26c7ce` | `a4526c2` | — (127 pruebas en local) |
| 3 | #3 Validación final y CI | `17ef213` | `6279338` | ✓ |
| 4 | #4 Botones sociales retirados | `363cc70` | `5951a48` | ✓ |
| 5 | #5 Android 16, INTERNET, gesto atrás | `5723437` | `4179375` | ✓ |
| 6 | #6 HTTPS, guardián de release, firma | `4f14397` | `ee7f01a` | ✓ |
| 7 | #7 Eliminar mi cuenta | `14c7241` | `1f60311` | ✓ |
| 8 | #8 Integración con el backend 5977d28 | `99b02b8` | **`aa1a0d2`** | ✓ (run 44778879192) |

- **SHA final de `generation`: `aa1a0d2`** (árbol `877fe4a`). Es idéntico al árbol de la cabeza de #8, que se validó contra el backend.
- No hubo conflictos.
- No se fusionó ninguna otra PR.

Durante la integración se añadió a #8, antes de fusionarla, `99b02b8`. Un `connectionError` al eliminar
la cuenta ya no afirma «No se eliminó nada»; ver `REVISION_SEGURIDAD_COMPATIBILIDAD.md`.

---

## Estado previo a la fusión

Integración con el backend `Fitsense-Real/Backend` `generation` = `5977d28` (incluye #77–#81). No se hizo
ningún merge.

## Pila

Todas siguen abiertas y apiladas en línea: cada una parte de la anterior.

| PR | Rama | Commit | Base | Contenido | CI `verify` |
|---|---|---|---|---|---|
| #1 | `claude/kora-mascot` | `400ee39` | `generation` (`4291c6b`) | Kapi | — (el workflow llega con #3) |
| #2 | `claude/welcome-tour` | `f26c7ce` | #1 | Tour inicial y generación asíncrona | — |
| #3 | `claude/mobile-final-validation` | `17ef213` | #2 | «8 DÍAS», contrato #72, perfil V55, CI | ✓ |
| #4 | `claude/play-d-social-cleanup` | `363cc70` | #3 | Botones de Google y Apple retirados | ✓ |
| #5 | `claude/play-a-android` | `5723437` | #4 | INTERNET, API 36, AGP 8.9.1, borde a borde, gesto atrás | ✓ |
| #6 | `claude/play-b-release` | `4f14397` | #5 | HTTPS obligatorio, guardián de release, firma, identificador | ✓ |
| #7 | `claude/play-c-account-deletion` | `a7f5f83` → **`14c7241`** | #6 | Eliminar mi cuenta | ✓ en `a7f5f83` |
| **#8 (nueva)** | `claude/play-e-backend-5977` | ver la PR | #7 | Integración con 5977d28 | se ejecutará al abrirla |

## Lo que cambió en esta orden

### #7: commit correctivo en su propia rama

`14c7241 fix(cuenta)`: la versión inicial se escribió cuando `DELETE /users/me` no existía (405). Hacía un
login aparte y enviaba el `DELETE` sin cuerpo. El backend real exige `{password, confirm: true}` y
responde 200, 202, 400, 403, 429, 401, 404 y 503. Detalle en `INTEGRACION_ELIMINACION_CUENTA.md`.

### #8: nueva PR de integración

Contiene solo correcciones y adaptaciones exigidas por el backend actualizado o encontradas en la prueba
real. No mezcla funciones ajenas.

| Commit | Qué | Por qué |
|---|---|---|
| `f30049f` fix(recuperacion) | «Enviar código», textos del código (30 min, un solo uso), mensajes 400 y 429, opción solo con `PASSWORD_RECOVERY_ENABLED=true` | Contrato real de #78; sin correo configurado la opción no debe parecer que funciona |
| `8843851` fix(perfil) | Edad mínima 18 en el cliente y traducción del 422 | #80; el mensaje del backend sale sin «ñ» |
| `66330f3` feat(consentimientos) | `GET/POST /users/me/consents`, una casilla por documento, sin premarcar | #80 (V63); hoy no hay versiones aprobadas y no se pide nada |
| `74994d4` fix(entrenamiento) | Un parcial exige repeticiones o segundos | Prueba real: «parcial» con 0 repeticiones quedaba `SKIPPED` |
| `323c8be` fix(recuperacion) | El correo se valida igual que en el registro | Prueba real: rechazaba `+` y dominios largos |
| `d96f4ab` fix(eliminacion) | Un 429 sin `Retry-After` pausa el botón | Prueba real en navegador: el backend no expone la cabecera por CORS |
| docs | Esta sección y la evidencia | Fase 13 |

## Qué necesita cada PR

| PR | ¿Necesita corrección? |
|---|---|
| #1–#6 | No. Sus pruebas siguen en verde y su comportamiento se volvió a comprobar con 5977d28 (Kapi, tour, generación, HTTPS, guardián, manifiesto) |
| #7 | Sí, ya aplicada (`14c7241`). Hay que empujarla para que la PR la incluya |
| #8 | Es la corrección. Revisión y CI pendientes |

## Orden de integración sugerido (cuando se autorice)

1. #1 → #2 → … → #7 → #8, cada una sobre `generation` tras fusionar la anterior.
2. No fusionar #7 sin #8: #7 corregida funciona sola, pero #8 completa la recuperación, la edad y los
   consentimientos que el backend 5977d28 ya exige o expone.
