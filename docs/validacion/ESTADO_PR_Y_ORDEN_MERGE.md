# Estado de las PR y orden de merge (ORDEN 2, fase 7)

> Para el Mobile, este documento queda sustituido por `ESTADO_PR_MOBILE.md` (validación final, 16/11/2026).

**Ninguna PR se fusionó ni se desplegó.** Quedan listas para su revisión y aprobación.

| Orden | PR | Rama → base | Head | CI | Estado |
|---|---|---|---|---|---|
| 1 | [Fitsense-Real/Backend#71](https://github.com/Fitsense-Real/Backend/pull/71) · Generación inicial asíncrona (V58) | `claude/async-first-plan-generation` → `generation` | `12a01c6` | **verde** (`verify`, 19 min 19 s: integración 770, 0 fallos, 72 opt-in omitidas) | sin conflictos (`clean`) |
| 2 | [Fitsense-Real/MobileApp#1](https://github.com/Fitsense-Real/MobileApp/pull/1) · Kapi, la mascota | `claude/kora-mascot` → `generation` | `400ee39` | el repo no tiene CI; verificación local en verde | sin conflictos |
| 3 | [Fitsense-Real/MobileApp#2](https://github.com/Fitsense-Real/MobileApp/pull/2) · Tour de bienvenida | `claude/welcome-tour` → `claude/kora-mascot` (apilada) | este commit | el repo no tiene CI; verificación local en verde | sin conflictos (`clean`) |

## Por qué este orden

1. **#71 primero**: la app de la PR #2 llama a `POST /users/me/plan/generation`, que solo existe con
   V58. Si se publica la app antes que el backend, el onboarding falla con 404.
2. **#1 después**: solo añade la mascota y su documentación; no depende del backend.
3. **#2 al final**: está apilada sobre #1. Al fusionar #1, GitHub cambia la base de #2 a
   `generation` si se borra la rama `claude/kora-mascot`; si no se borra, hay que cambiar la base a
   mano antes de fusionar #2.

## Antes de desplegar (no lo hice)

- **Migración V58**: crea una tabla y tres índices, sin datos. Es aditiva y no bloquea tablas existentes.
- **Tiempos con IA real**: `max-processing-seconds=600` debe ser mayor que el peor caso del pipeline
  con Replicate (hasta 150 s por intento). Conviene medirlo en un entorno de pruebas con IA real
  antes de producción; no lo medí para no consumir Replicate.
- **Concurrencia**: `max-concurrent=2` por instancia. En el E2E, con dos generaciones largas en
  curso, una tercera esperó en `PENDING` ~2,5 min. Ajustar según la carga y el límite de
  Replicate (`fitsense.ai.generate.max-per-hour=5`).
- **Despliegue sin cortes**: con el apagado ordenado (B4), una generación en curso vuelve a la cola
  y la nueva instancia la retoma. La plataforma debe enviar SIGTERM y esperar al menos 10 s.
- **Orden de publicación**: backend (#71) desplegado y migrado antes de publicar la app con #2.

## Pendiente de decisión del equipo

- Probar en un teléfono Android real o en un emulador con aceleración (PRUEBAS_ANDROID.md) y en iPhone.
- NO_FACTIBLE ofrece «Contactar al equipo»; se podría añadir «Revisar mi perfil» (el backend lo
  permite antes del primer plan). No lo añadí: es una funcionalidad nueva.
- El progreso del tour se guarda en el teléfono; si se reinstala, el tour empieza de nuevo.
- «8 DÍAS» en el dashboard: código anterior a estas PR (VALIDACION_FLUTTER_BACKEND.md §5).
