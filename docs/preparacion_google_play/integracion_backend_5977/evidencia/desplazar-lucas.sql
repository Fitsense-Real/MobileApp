-- SOLO base de pruebas fitsense_int. Lleva la semana de Lucas (user_id 8) del 16-22/11 al 9-15/11
-- para que el cierre manual (POST /cycle/run-for-me) la mida como "semana anterior".
BEGIN;
UPDATE weekly_training_plans SET week_start_date = week_start_date - 7, week_end_date = week_end_date - 7,
  created_at = created_at - interval '7 days', activated_at = activated_at - interval '7 days' WHERE user_id = 8;
UPDATE planned_workouts SET scheduled_date = scheduled_date - 7, expires_at = expires_at - interval '7 days',
  created_at = created_at - interval '7 days', updated_at = updated_at - interval '7 days'
  WHERE plan_id IN (SELECT plan_id FROM weekly_training_plans WHERE user_id = 8);
UPDATE workout_sessions SET started_at = started_at - interval '7 days', ended_at = ended_at - interval '7 days',
  created_at = created_at - interval '7 days', updated_at = updated_at - interval '7 days' WHERE user_id = 8;
UPDATE users SET created_at = created_at - interval '7 days' WHERE user_id = 8;
UPDATE user_profiles SET created_at = created_at - interval '7 days' WHERE user_id = 8;
SELECT plan_id, week_start_date, week_end_date, status FROM weekly_training_plans WHERE user_id = 8;
SELECT planned_workout_id, scheduled_date, status, skip_reason FROM planned_workouts WHERE plan_id IN (SELECT plan_id FROM weekly_training_plans WHERE user_id = 8);
SELECT session_id, status, completion_percentage, started_at FROM workout_sessions WHERE user_id = 8;
COMMIT;
