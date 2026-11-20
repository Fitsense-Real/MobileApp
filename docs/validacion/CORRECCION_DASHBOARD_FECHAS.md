# Corrección de «8 DÍAS» en el dashboard (fase 5)

## Síntoma

El domingo 15/11 la tarjeta «Tu plan de la semana» mostraba **«8 DÍAS»** para un plan del lunes 16 al
domingo 22, que solo tiene 7 días y aún no había empezado.

## Investigación

| Pregunta | Respuesta |
|---|---|
| ¿Qué fecha envía el backend? | `weekStartDate` y `weekEndDate` como `LocalDate` (`yyyy-MM-dd`), lunes a domingo, calculados en la zona horaria del usuario (`iam.timezoneOf`) |
| ¿El plan puede empezar en el futuro? | Sí. `firstPlanWeekStart` usa la semana actual si su primera sesión es hoy o después; si no, la siguiente: hasta 6 días después |
| ¿Fecha de creación o de inicio? | El backend no expone la fecha de creación del plan; Flutter debe usar `weekStartDate` |
| ¿Qué interpretaba Flutter? | `weekEndDate − hoy + 1`: contaba desde hoy y no desde el inicio del plan. Además, `difference().inDays` entre medianoches locales pierde un día al cruzar un cambio de horario (23 h → 0 días) en las zonas con horario de verano |
| ¿Zona horaria? | Las fechas del backend son días de calendario en la zona del perfil; Flutter usa la fecha local del teléfono. Si ambas zonas difieren, el cambio de día puede no coincidir durante unas horas (documentado en RIESGOS_PENDIENTES.md) |

## Corrección

`lib/features/dashboard/domain/plan_week_label.dart`, una función pura que la tarjeta usa (`heroPlan`):

| Situación | Etiqueta |
|---|---|
| El plan empieza mañana | `EMPIEZA MAÑANA` |
| Empieza en n días (n ≥ 2) | `EMPIEZA EN n DÍAS` |
| Durante la semana | días restantes contando hoy: `7 DÍAS` … `2 DÍAS` |
| Último día | `ÚLTIMO DÍA` |
| Semana terminada, fechas ausentes, inválidas o invertidas | nada |

Los días se comparan como días de calendario en UTC (`DateTime.utc(y, m, d)`), así que la hora y el
horario de verano no influyen. No hay valores fijos.

## Pruebas (`test/plan_week_label_test.dart`, 10)

- Empieza mañana; empieza en 6 días; empieza hoy (7); mitad de semana (5).
- 23:59 frente a 00:00; último día; después de la semana.
- Semanas con cambio de horario (octubre y marzo); fechas ausentes, inválidas o invertidas.
- **Widget** con la tarjeta real del dashboard y un plan que empieza mañana: muestra
  `EMPIEZA MAÑANA` y nunca «8 DÍAS». Esta prueba **falla con el código anterior** (comprobado) y
  pasa con la corrección.

En el E2E (lunes 16, plan que empieza hoy) la tarjeta muestra «7 DÍAS» (`capturas-71-72/22-inicio-7-dias.jpg`).

## Pantallas relacionadas revisadas

| Pantalla | Fecha | Estado |
|---|---|---|
| Resultado de la primera rutina | «Semana del 16/11/2026 · 4 entrenamientos» (`weekStartDate`) | correcta |
| Próximas rutinas y Rutinas | `scheduledDate` de cada entreno | correcta |
| Recordatorios (`reminder_planner`) | aritmética `DateTime(y, m, d + n)`, segura ante cambios de horario | correcta |
| `CurrentPlanCard` | mostraría la fecha ISO sin formato, pero **no se usa** en ninguna pantalla | sin cambio (código muerto) |
| Tour | no muestra fechas | — |
