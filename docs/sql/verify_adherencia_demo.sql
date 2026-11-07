-- Verificación del seed de adherencia: lo que la app debe mostrar.
--   psql "$DATABASE_URL" -f docs/sql/verify_adherencia_demo.sql

\echo '1) Progreso > gráfico y desplegable (GET /users/me/metrics/weekly)'
SELECT m.week_number                       AS semana,
       to_char(m.week_start_date, 'DD/MM/YYYY') AS "Semana del",
       m.weighted_adherence_pct            AS "Adherencia %",
       round(m.weighted_adherence_pct - lag(m.weighted_adherence_pct)
             OVER (ORDER BY m.week_start_date), 1) AS "Cambio pp",
       m.completed_workouts || ' / ' || m.scheduled_workouts AS "Sesiones",
       m.total_training_minutes            AS "Min entrenados",
       m.risk_level                        AS riesgo,
       m.dominant_skip_reason              AS motivo
  FROM weekly_user_metrics m
  JOIN users u USING (user_id)
 WHERE u.email = 'adherencia.demo@example.com'
 ORDER BY m.week_start_date;

\echo '2) Progreso > Resumen de ajustes y Notificaciones (GET /users/me/interventions)'
SELECT to_char(i.applied_at AT TIME ZONE 'America/Lima', 'DD/MM/YYYY') AS "Ajuste del",
       i.adjustment_types                  AS tipos,
       i.trigger_adherence_pct             AS "Adherencia previa",
       i.adherence_after_pct               AS "Adherencia después",
       i.outcome,
       i.message_shown                     AS mensaje
  FROM user_interventions i
  JOIN users u USING (user_id)
 WHERE u.email = 'adherencia.demo@example.com'
 ORDER BY i.applied_at;

\echo '3) Perfil > Historial de planes (GET /users/me/plans)'
SELECT p.plan_id, p.week_number AS semana, to_char(p.week_start_date, 'DD/MM/YYYY') AS "Semana del",
       p.plan_version AS v, p.status, p.adjustment_applied AS ajuste,
       (SELECT string_agg(DISTINCT pwe.planned_sets::text, ',') FROM planned_workouts pw
          JOIN planned_workout_exercises pwe USING (planned_workout_id) WHERE pw.plan_id = p.plan_id) AS series,
       (SELECT max(expected_duration_minutes) FROM planned_workouts pw WHERE pw.plan_id = p.plan_id) AS minutos
  FROM weekly_training_plans p
  JOIN users u USING (user_id)
 WHERE u.email = 'adherencia.demo@example.com'
 ORDER BY p.week_start_date DESC;

\echo '4) Inicio y Rutinas: semana actual (GET /users/me/plan/current)'
SELECT to_char(pw.scheduled_date, 'TMDay DD/MM') AS dia, pw.workout_name, pw.focus_code,
       pw.status, s.completion_percentage AS "% sesión"
  FROM planned_workouts pw
  JOIN weekly_training_plans p USING (plan_id)
  JOIN users u USING (user_id)
  LEFT JOIN workout_sessions s ON s.planned_workout_id = pw.planned_workout_id AND s.counts_toward_adherence
 WHERE u.email = 'adherencia.demo@example.com' AND p.status = 'ACTIVE'
 ORDER BY pw.scheduled_date, pw.display_order;

\echo '5) Coherencia: adherencia ponderada recalculada desde las sesiones (debe coincidir)'
SELECT m.week_number AS semana, m.weighted_adherence_pct AS guardada,
       round(sum(pw.expected_duration_minutes * coalesce(s.completion_percentage, 0))
             / sum(pw.expected_duration_minutes), 2) AS recalculada
  FROM weekly_user_metrics m
  JOIN users u USING (user_id)
  JOIN planned_workouts pw ON pw.plan_id = m.plan_id
  LEFT JOIN workout_sessions s ON s.planned_workout_id = pw.planned_workout_id AND s.counts_toward_adherence
 WHERE u.email = 'adherencia.demo@example.com'
 GROUP BY m.week_number, m.weighted_adherence_pct
 ORDER BY m.week_number;
