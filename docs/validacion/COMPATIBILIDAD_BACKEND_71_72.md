# Compatibilidad Flutter ↔ backend #71 + #72

## Contrato REST

Se comparó `fix/async-generacion-resiliente` (`93549d5`) con #71 (`12a01c6`):

- `interfaces/rest` (controlador y `PlanGenerationOperationResource`) y `GenerationOperationStatus`:
  **sin diferencias**;
- mismas rutas, códigos, campos y estados (`CONTRATO_API_ACTUALIZADO.md` de #72);
- `FirstPlanGenerationRunner`: la misma firma (el arnés E2E compila contra #72 sin cambios).

| Cambio en #72 | Efecto en Flutter |
|---|---|
| `TIEMPO_EXCEDIDO` a los 1.800 s desde la **primera** ejecución (antes 600 s) | Una operación puede seguir `PENDING`/`PROCESSING` hasta 30 min. Flutter sigue consultando sin límite propio: correcto, porque el backend garantiza el final |
| `EJECUCION_INTERRUMPIDA` tras 3 ejecuciones (antes 2) | Ninguno: `FAILED` con `retryable=true` muestra «Intentar de nuevo» |
| Reintento tras `FAILED` reutiliza predicciones (24 h) | Ninguno: `retry()` hace un `POST` y acepta la operación nueva |
| Lease, latido en hilo propio, libro de predicciones (V59) | Interno, invisible para la app |

**Conclusión: no hace falta ningún cambio en Flutter.** Se añadieron pruebas para fijar el
comportamiento.

## Requisitos de la orden, verificados en el código

| Requisito | Dónde se cumple | Prueba |
|---|---|---|
| No pedir una generación nueva porque pasaron minutos | `FirstPlanGenerationController`: sin tiempo límite en el cliente; solo `retry()` (botón) o un 404 del backend (POST idempotente) llaman a `start()` | `#72 · a generation that stays PROCESSING for many checks…` (240 consultas, cortes y 503: 1 sola petición) |
| No pedir una generación nueva por perder la conexión | `_onError`: conexión y 5xx solo alargan la consulta (3→6→12→20 s) | ídem y `13 · losing the connection…` |
| Recuperar tras cerrar Flutter | `operationId` guardado por usuario, `find(id)` al volver | `7 · after reopening…`; E2E |
| `TIEMPO_EXCEDIDO` y reintento manual | `FAILED`+`retryable` → «Intentar de nuevo» → un `POST` | `#72 · a manual retry after TIEMPO_EXCEDIDO…`; E2E |
| Respuesta documentada parseada | `GenerationOperation.fromJson` | `#72 · the documented PlanGenerationOperationResource…` |
| Estado desconocido futuro | se trata como «sigue esperando», no como fallo | ídem |

No se movió ninguna regla deportiva a Flutter: la app solo muestra el estado y el plan del backend.

## Comprobado de extremo a extremo

Los 12 puntos de la fase 3, con la app real contra el backend #71 + #72: ver PRUEBAS_INTEGRALES.md.
