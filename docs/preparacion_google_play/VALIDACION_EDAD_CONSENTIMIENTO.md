# Edad mínima y consentimientos versionados (backend #80, V63)

## Edad mínima: 18 años

No se cambió la edad ni el modelo del backend.

### En la app (`8843851`)

- `minimum_age.dart`: `minimumAge = 18` y `ageOn(nacimiento, hoy)`, que cuenta el cumpleaños exacto.
- **Paso 2 del perfil**: si la persona no tiene 18 años, el campo muestra «Para participar en Kora debes
  tener al menos 18 años.» y no se puede continuar.
- **Respaldo**: si aun así el backend responde 422 por edad, `ProfileRepository` lo traduce al mismo
  texto. El del backend sale sin «ñ».
- El selector solo permite fechas pasadas, y el backend rechaza las futuras con 400.

| Caso | HTTP directo | App |
|---|---|---|
| Adulto (2001) | 201 | perfil completo en todos los E2E |
| Exactamente 18 hoy (20/11/2008) | 201 | pasa al paso 3 (`A-edad-18-hoy`) |
| Cumple 18 mañana (21/11/2008) | 422 | aviso y sigue en el paso 2 (`A-edad-menor`) |
| 17 años | 422 | mismo aviso (validador; prueba unitaria) |
| Fecha futura | 400 | el selector no la ofrece |
| Sin fecha o fecha inválida | — | «Elige una fecha anterior a hoy» (validador del campo) |

Pruebas automáticas: `minimum_age_test.dart` (6) cubre: cumplir 18 hoy, el día anterior, un adulto y alguien nacido el 29 de febrero, la edad del backend, la traducción del 422 y que los demás 422 conserven su manejo.

## Consentimientos versionados

### Qué hace la app (`66330f3`)

- Tras iniciar sesión, `GET /users/me/consents`.
- Si el backend publica una versión de **condiciones de uso** o de **política de privacidad** que la
  persona no aceptó, aparece la pantalla «Antes de continuar», con una casilla por documento:
  - sin premarcar;
  - con la versión indicada;
  - con el enlace al texto, si se configuró `TERMS_URL` / `PRIVACY_POLICY_URL`.
- «Continuar» solo envía cuando ambas están marcadas: `POST /users/me/consents {type, documentVersion}`.
- **Participación en el estudio**: sigue siendo la casilla propia del registro
  (`acceptsStudyParticipation`). No se mezcla con los otros dos documentos. El retiro está en Perfil →
  Cuenta.
- Perfil → Cuenta muestra, por documento, la versión aceptada o «sin versión publicada».
- Si la consulta falla o el backend es antiguo (404), no se bloquea la cuenta.

### Con el backend tal como está (sin versiones aprobadas)

`currentVersions.TERMS_OF_SERVICE` y `PRIVACY_POLICY` son `null` y `enforcedOnSignup` es `false`: la app
**no pide nada**. Así ocurrió en todos los E2E salvo el siguiente.

### Prueba con versiones de PRUEBA

Se reinició el backend local con `FITSENSE_CONSENT_TERMS_VERSION=prueba-terminos-1`,
`FITSENSE_CONSENT_PRIVACY_VERSION=prueba-privacidad-1` y `FITSENSE_CONSENT_ENFORCE_ON_SIGNUP=false`. Son
nombres de prueba, no documentos.

| Paso | Resultado |
|---|---|
| Login de `con2` | Pantalla «Antes de continuar», 2 casillas sin marcar (`G-consentimientos`) |
| «Continuar» sin marcar | 0 `POST`; sigue en la pantalla |
| Marcar ambas y continuar | 2 `POST` 201: `TERMS_OF_SERVICE prueba-terminos-1` y `PRIVACY_POLICY prueba-privacidad-1` (`G-consentimientos-marcados`) |
| Después | Paso 1 del perfil |
| Base | `user_consents`: `PRIVACY_POLICY prueba-privacidad-1`, `STUDY_PARTICIPATION MVP-1.0`, `TERMS_OF_SERVICE prueba-terminos-1` |

Pruebas automáticas: `consents_test.dart` (4) y `account_setup_test.dart` (+3).

### Lo que no se hizo

- No se inventaron versiones ni textos legales.
- No se activó la exigencia (`enforce-on-signup`).
- No se premarcó ninguna casilla.
- No se afirma ninguna aprobación ética.

### Dependencias para activarlos de verdad

1. Textos aprobados de condiciones de uso y política de privacidad, publicados en una URL HTTPS.
2. Las versiones de esos textos en `FITSENSE_CONSENT_TERMS_VERSION` / `…_PRIVACY_VERSION` del backend
   desplegado.
3. Compilar la app con `TERMS_URL` y `PRIVACY_POLICY_URL`.
4. Para exigirlos **en el registro** (`enforce-on-signup=true`), el backend necesita un endpoint público de
   versiones vigentes (B-4). Hoy solo se leen con sesión. Hasta entonces, la exigencia debe seguir
   apagada; la app los pide justo después del primer login.
5. Aprobación del comité de ética para el consentimiento del estudio, fuera del código.
