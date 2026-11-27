-- Verificación del usuario Demo Kora (ID 48) antes de la demostración. SOLO LECTURA.
--
-- Todo va dentro de una transacción READ ONLY: PostgreSQL rechaza cualquier INSERT, UPDATE o DELETE,
-- y el ROLLBACK final no deja nada. No lee password_hash ni otros datos sensibles. No cambia la
-- participación en el estudio ni el dataset.
-- Tablas y columnas del esquema real del Backend (Flyway hasta V65, rama generation).
-- Ejecutar en DBeaver o pgAdmin («Ejecutar script») y revisar cada resultado con lo esperado.

BEGIN TRANSACTION READ ONLY;

-- 1. Existencia del usuario. Esperado: 1 fila, user_id = 48, status ACTIVE.
SELECT user_id, email, first_name, last_name, status, timezone, created_at, last_login_at
FROM users
WHERE email = 'usuario.demo.kora@example.com';

-- 2. Participación en el estudio (solo se lee). Esperado según tu informe: is_study_participant = true.
SELECT user_id, is_study_participant, enrolled_at, withdrawn_at
FROM users
WHERE email = 'usuario.demo.kora@example.com';

-- 3. Planes. Esperado: 4 filas (910000000 a 910000003): 3 COMPLETED y 1 ACTIVE, ninguno con
--    generation_source = 'AI' ni model_name. Un quinto plan = un cierre automático alteró la demo.
SELECT p.plan_id, p.week_start_date, p.week_end_date, p.plan_version, p.status, p.generation_source,
       p.model_name, p.adjustment_applied, p.created_at
FROM weekly_training_plans p
JOIN users u ON u.user_id = p.user_id
WHERE u.email = 'usuario.demo.kora@example.com'
ORDER BY p.week_start_date, p.plan_version;

SELECT count(*) AS planes,
       count(*) FILTER (WHERE p.status = 'ACTIVE') AS activos,
       count(*) FILTER (WHERE p.generation_source = 'AI' OR p.model_name IS NOT NULL) AS con_ia
FROM weekly_training_plans p
JOIN users u ON u.user_id = p.user_id
WHERE u.email = 'usuario.demo.kora@example.com';

-- 4. Sesiones registradas y estado de los entrenamientos por semana.
--    Esperado: 14 sesiones del dataset (13 COMPLETED y 1 PARTIAL; el entrenamiento omitido no tiene sesión),
--    más las que se hagan en directo.
--    Semana W-3 (910000000): 3 COMPLETED, 1 PARTIAL, 1 SKIPPED; W-2 y W-1: 5 COMPLETED cada una;
--    la semana vigente: SCHEDULED, y SKIPPED en los días ya pasados (lo hace la tarea de vencimiento).
SELECT s.status, count(*) AS sesiones
FROM workout_sessions s
JOIN users u ON u.user_id = s.user_id
WHERE u.email = 'usuario.demo.kora@example.com'
GROUP BY s.status
ORDER BY s.status;

SELECT p.plan_id, p.week_start_date, w.status, count(*) AS entrenamientos
FROM planned_workouts w
JOIN weekly_training_plans p ON p.plan_id = w.plan_id
JOIN users u ON u.user_id = p.user_id
WHERE u.email = 'usuario.demo.kora@example.com'
GROUP BY p.plan_id, p.week_start_date, w.status
ORDER BY p.week_start_date, w.status;

-- 5. Adaptaciones almacenadas. Esperado: 3 filas:
--    semana 09/11 ADAPT_LOCALIZED / RESPALDO (la sustitución por dolor),
--    16/11 NO_CHANGE / SIN_ORDEN,
--    23/11 NO_CHANGE / SIN_ORDEN con progressed_sessions (la progresión). ai_calls = 0 en las tres.
SELECT a.attempt_id, a.new_week_start_date, a.source_plan_id, a.resulting_plan_id, a.decision, a.status,
       a.ai_calls, a.observed_adherence_pct, a.progressed_sessions, a.created_at
FROM plan_adaptation_attempts a
JOIN users u ON u.user_id = a.user_id
WHERE u.email = 'usuario.demo.kora@example.com'
ORDER BY a.new_week_start_date;

-- 6. Métricas de adherencia. Esperado: 3 semanas cerradas: 67,81 % (02/11), 100 % (09/11), 100 % (16/11).
SELECT m.week_start_date, m.plan_id, m.scheduled_workouts, m.valid_workouts, m.completed_workouts,
       m.skipped_workouts, m.weighted_adherence_pct, m.risk_level, m.calculated_at
FROM weekly_user_metrics m
JOIN users u ON u.user_id = m.user_id
WHERE u.email = 'usuario.demo.kora@example.com'
ORDER BY m.week_start_date;

-- 7. Exclusión vigente del ejercicio 1025. Esperado: 1 fila, reason DOLOR_IDENTIFICADO, status ACTIVA,
--    «Aperturas de pecho sentado con palanca».
SELECT x.exclusion_id, x.exercise_id, e.name_es, x.reason, x.status, x.event_date, x.recorded_by,
       x.reactivated_at, x.identified_at
FROM user_safety_exclusions x
JOIN users u ON u.user_id = x.user_id
LEFT JOIN exercises e ON e.exercise_id = x.exercise_id
WHERE u.email = 'usuario.demo.kora@example.com'
ORDER BY x.exercise_id;

-- 8. Perfil (para comparar con Perfil → Cuenta). Esperado: GAIN_MUSCLE, INTERMEDIATE, GYM, 5 días,
--    60 min, 176 cm, 74 kg.
SELECT pr.goal_type, pr.goal_text, pr.fitness_level, pr.training_location, pr.days_per_week,
       pr.session_minutes, pr.height_cm, pr.current_weight_kg, pr.birth_date
FROM user_profiles pr
JOIN users u ON u.user_id = pr.user_id
WHERE u.email = 'usuario.demo.kora@example.com';

ROLLBACK;
