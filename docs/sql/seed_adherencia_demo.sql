-- =============================================================================
-- Seed de prueba: historial de adherencia de 8 semanas para validar la app.
--
-- Crea (o recrea) el usuario  adherencia.demo@example.com / Kora2026!
-- con 7 semanas cerradas y la semana actual en curso:
--
--   Semana  Plan                       Sesiones (cumplimiento)       Adherencia
--   1       3 x 40 min                 100 / 100 / 85                ~95 %
--   2       3 x 40 min                 100 / 85 / 60                 ~82 %
--   3       3 x 40 min                 85 / 60 / omitido (tiempo)    ~48 %  -> ajuste REDUCE_DURATION
--   4       3 x 30 min (más corto)     50 / omitido / omitido (fatiga) ~17 % -> ajuste REDUCE_VOLUME
--   5       3 x 30 min, 2 series       70 / 100 / 60                 ~77 %
--   6       3 x 30 min, 2 series       100 / 85 / 100                ~95 %  -> sube volumen
--   7       3 x 40 min, 3 series       100 / 100 / 100               100 %
--   8       semana actual (ACTIVE)     días pasados hechos; hoy pendiente
--
-- Las fechas son relativas a CURRENT_DATE (lunes = inicio de semana) y las
-- métricas se calculan aquí con las mismas reglas que WeeklyMetricsCalculator
-- de la rama generation (esquema V44, config activa MVP-1.8): adherencia
-- semanal = promedio simple del cumplimiento de cada entrenamiento (cada uno
-- pesa 1), sesión válida >= 30 %, completada >= 80 %, cobertura de registro
-- de V30 y riesgo por adherencia, racha de saltos, caída y RPE. Los mensajes
-- de las intervenciones copian AdjustmentDecisionTable.
--
-- Es idempotente: si el usuario ya existe, borra todo lo suyo y lo vuelve a
-- crear. No toca a ningún otro usuario. Ejecutar con:
--   psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f docs/sql/seed_adherencia_demo.sql
-- =============================================================================

BEGIN;

DO $$
DECLARE
  v_email     constant text := 'adherencia.demo@example.com';
  -- BCrypt (cost 10) de 'Kora2026!', compatible con BCryptPasswordEncoder.
  v_hash      constant text := '$2a$10$VHW9qUBbnadEO4C1dSNiAOPtNXjaecYd7Y0YKGoqsZCGOmNePhCoe';
  v_tz        constant text := 'America/Lima';
  v_config    text;
  v_user      bigint;
  v_monday    date := date_trunc('week', current_date)::date;   -- lunes actual
  v_first     date;
  -- Ejercicios del catálogo (por source_code, estable entre bases).
  v_squat     bigint;
  v_bridge    bigint;
  v_plank     bigint;

  -- Guion: cumplimiento objetivo de cada entrenamiento (NULL = sin sesión).
  -- Semana 8 se resuelve aparte (en curso).
  v_targets   numeric[][] := ARRAY[
    ARRAY[100, 100,  85],
    ARRAY[100,  85,  60],
    ARRAY[ 85,  60, NULL],
    ARRAY[ 50, NULL, NULL],
    ARRAY[ 70, 100,  60],
    ARRAY[100,  85, 100],
    ARRAY[100, 100, 100]
  ];
  v_skip      text[] := ARRAY[NULL, 'FATIGUE', 'LACK_OF_TIME', 'FATIGUE', 'LACK_OF_TIME', NULL, NULL];
  v_sets      int[]  := ARRAY[3, 3, 3, 3, 2, 2, 3, 3];
  v_minutes   int[]  := ARRAY[40, 40, 40, 30, 30, 30, 40, 40];
  v_adjust    text[] := ARRAY[NULL, NULL, NULL, 'REDUCE_DURATION', 'REDUCE_VOLUME', NULL, NULL, NULL];
  v_adjust_reason text[] := ARRAY[NULL, NULL, NULL,
    'Semana anterior con falta de tiempo: sesiones más cortas, mismos días.',
    'Semana anterior con fatiga: menos series por ejercicio.',
    NULL,
    'Buena adherencia sostenida: se recupera el volumen original.',
    NULL];

  -- Estado por semana para métricas e intervenciones.
  v_plan_ids   bigint[] := '{}';
  v_metric_ids bigint[] := '{}';
  v_weighted   numeric[] := '{}';
  v_volumes    int[] := '{}';

  w int; i int; e int;
  v_week_start date; v_week_end date;
  v_plan bigint; v_workout bigint; v_session bigint; v_pex bigint;
  v_date date; v_target numeric; v_status text; v_wreason text;
  v_started timestamptz; v_active int; v_rpe int; v_sat int;
  v_ex_ids bigint[]; v_ex_type text; v_pct numeric; v_actual int; v_planned int;
  v_session_pct numeric; v_ex_status text; v_ex_reason text;

  -- Acumuladores de la semana.
  a_valid int; a_completed int; a_skipped int; a_assigned int; a_completed_ex int;
  a_minutes int; a_num numeric; a_den numeric; a_rpes int[]; a_sats int[];
  a_reasons text[]; a_streak int; a_session_pcts numeric[];
  a_planned_vol int; a_exec_vol int; a_planned_reps int; a_planned_secs int;
  a_exec_reps int; a_exec_secs int; a_recorded int; a_obs_num numeric;
  m_weighted numeric; m_prev numeric; m_score int; m_level text; m_factors jsonb;
  m_days smallint; m_reason text; m_rpe numeric; m_drop numeric;
  v_metric bigint; v_types text[]; v_message text; v_outcome text; v_after numeric;
  v_change numeric;
BEGIN
  SELECT version INTO v_config FROM calculation_configs WHERE is_active ORDER BY valid_from DESC LIMIT 1;
  v_config := coalesce(v_config, 'MVP-1.8');

  SELECT exercise_id INTO v_squat  FROM exercises WHERE source_code = '1685' AND is_active;
  SELECT exercise_id INTO v_bridge FROM exercises WHERE source_code = '0870' AND is_active;
  SELECT exercise_id INTO v_plank  FROM exercises WHERE source_code = '0464' AND is_active;
  -- Respaldo si el catálogo difiere: cualquier ejercicio activo del tipo.
  IF v_squat IS NULL THEN SELECT exercise_id INTO v_squat FROM exercises WHERE is_active AND default_prescription = 'SETS_REPS' ORDER BY difficulty_level, exercise_id LIMIT 1; END IF;
  IF v_bridge IS NULL THEN SELECT exercise_id INTO v_bridge FROM exercises WHERE is_active AND default_prescription = 'SETS_REPS' AND exercise_id <> v_squat ORDER BY difficulty_level, exercise_id LIMIT 1; END IF;
  IF v_plank IS NULL THEN SELECT exercise_id INTO v_plank FROM exercises WHERE is_active AND default_prescription = 'DURATION' ORDER BY difficulty_level, exercise_id LIMIT 1; END IF;
  IF v_squat IS NULL OR v_bridge IS NULL OR v_plank IS NULL THEN
    RAISE EXCEPTION 'El catálogo no tiene ejercicios activos suficientes.';
  END IF;
  v_ex_ids := ARRAY[v_squat, v_bridge, v_plank];

  -- ---------------------------------------------------------------- limpieza
  SELECT user_id INTO v_user FROM users WHERE email = v_email;
  IF v_user IS NOT NULL THEN
    DELETE FROM user_interventions WHERE user_id = v_user;
    DELETE FROM weekly_user_metrics WHERE user_id = v_user;
    DELETE FROM workout_sessions WHERE user_id = v_user;          -- cascada a ejercicios de sesión
    UPDATE weekly_training_plans SET parent_plan_id = NULL WHERE user_id = v_user;
    DELETE FROM weekly_training_plans WHERE user_id = v_user;     -- cascada a entrenamientos
    DELETE FROM users WHERE user_id = v_user;                     -- cascada al perfil
  END IF;

  -- --------------------------------------------------------- usuario y perfil
  v_first := v_monday - 49;   -- lunes de la semana 1
  INSERT INTO users (email, password_hash, first_name, last_name, timezone, status,
                     consent_granted_at, consent_version, is_study_participant,
                     participant_code, enrolled_at, last_login_at)
  VALUES (v_email, v_hash, 'Ana', 'Demo Adherencia', v_tz, 'ACTIVE',
          (v_first - 1)::timestamp AT TIME ZONE v_tz, 'v1', true,
          'DEMO-ADH-01', (v_first - 1)::timestamp AT TIME ZONE v_tz, now())
  RETURNING user_id INTO v_user;

  INSERT INTO user_profiles (user_id, birth_date, biological_sex, height_cm, current_weight_kg,
                             target_weight_kg, fitness_level, goal_type, goal_text,
                             training_location, days_per_week, available_days, session_minutes,
                             equipment_codes, blocked_exercise_ids, health_notes)
  VALUES (v_user, DATE '1994-03-15', 'FEMALE', 162, 64.5, NULL, 'BEGINNER', 'GENERAL_FITNESS',
          'Ser constante tres veces por semana', 'HOME', 3, ARRAY[1,3,5]::smallint[], 40,
          '{}', '{}', NULL);

  -- ------------------------------------------------------- semanas 1 a 8
  FOR w IN 1..8 LOOP
    v_week_start := v_first + (w - 1) * 7;
    v_week_end   := v_week_start + 6;

    INSERT INTO weekly_training_plans (user_id, week_number, week_start_date, week_end_date,
        plan_version, planned_days_count, status, generation_source, model_name, input_snapshot,
        adjustment_applied, adjustment_reason, activated_at)
    VALUES (v_user, w, v_week_start, v_week_end, 1, 3,
            CASE WHEN w = 8 THEN 'ACTIVE' ELSE 'COMPLETED' END,
            'RULE_ENGINE', NULL,
            jsonb_build_object('user', jsonb_build_object('fitnessLevel', 'BEGINNER'), 'seed', 'adherencia-demo'),
            v_adjust[w], v_adjust_reason[w],
            (v_week_start + time '00:30') AT TIME ZONE v_tz)
    RETURNING plan_id INTO v_plan;
    v_plan_ids := v_plan_ids || v_plan;

    a_valid := 0; a_completed := 0; a_skipped := 0; a_assigned := 0; a_completed_ex := 0;
    a_minutes := 0; a_num := 0; a_den := 0; a_rpes := '{}'; a_sats := '{}'; a_reasons := '{}';
    a_session_pcts := '{}'; a_planned_vol := 0; a_exec_vol := 0; a_planned_reps := 0;
    a_planned_secs := 0; a_exec_reps := 0; a_exec_secs := 0; a_recorded := 0; a_obs_num := 0;

    FOR i IN 1..3 LOOP
      IF w < 8 THEN
        v_date := v_week_start + (i - 1) * 2;               -- lun, mié, vie
        v_target := v_targets[w][i];
      ELSE
        -- Semana actual: lunes y miércoles si ya pasaron; el último, hoy o el viernes.
        v_date := CASE i WHEN 1 THEN v_week_start WHEN 2 THEN v_week_start + 2
                         ELSE greatest(current_date, v_week_start + 4) END;
        v_target := CASE WHEN v_date < current_date THEN 100 END;
      END IF;

      -- Estado final del entrenamiento (como lo deja execution/planning).
      v_wreason := NULL;
      IF w = 8 AND v_date >= current_date THEN
        v_status := 'SCHEDULED';
      ELSIF v_target IS NULL THEN
        v_status := 'SKIPPED'; v_wreason := coalesce(v_skip[w], 'OTHER');
      ELSIF v_target >= 80 THEN v_status := 'COMPLETED';
      ELSIF v_target >= 30 THEN v_status := 'PARTIAL';
      ELSE v_status := 'SKIPPED';
      END IF;

      INSERT INTO planned_workouts (plan_id, scheduled_date, focus_code, workout_name,
          expected_duration_minutes, display_order, status, skip_reason, expires_at)
      VALUES (v_plan, v_date, (ARRAY['FULL_BODY', 'LOWER_BODY', 'CORE'])[i],
              (ARRAY['Cuerpo completo en casa', 'Piernas y glúteos', 'Core y estabilidad'])[i],
              v_minutes[w], i, v_status, v_wreason,
              (v_date + time '23:59') AT TIME ZONE v_tz)
      RETURNING planned_workout_id INTO v_workout;

      -- Ejercicios: 2 de repeticiones y 1 por tiempo (plancha).
      FOR e IN 1..3 LOOP
        v_ex_type := CASE WHEN e = 3 THEN 'DURATION' ELSE 'SETS_REPS' END;
        INSERT INTO planned_workout_exercises (planned_workout_id, exercise_id, exercise_order,
            prescription_type, planned_sets, planned_reps, planned_duration_seconds,
            target_load_kg, rest_seconds, notes)
        VALUES (v_workout, v_ex_ids[e], e, v_ex_type, v_sets[w],
                CASE WHEN e = 3 THEN NULL ELSE 12 END,
                CASE WHEN e = 3 THEN 30 ELSE NULL END,
                NULL, CASE WHEN e = 3 THEN 45 ELSE 60 END, NULL);
        -- Volumen equivalente: reps = series x reps; tiempo = series x seg / 30.
        IF e = 3 THEN
          a_planned_secs := a_planned_secs + v_sets[w] * 30;
          a_planned_vol  := a_planned_vol + round(v_sets[w] * 30 / 30.0);
        ELSE
          a_planned_reps := a_planned_reps + v_sets[w] * 12;
          a_planned_vol  := a_planned_vol + v_sets[w] * 12;
        END IF;
      END LOOP;
      a_assigned := a_assigned + 3;
      a_den := a_den + 1;   -- V31+: cada previsto pesa 1

      IF v_target IS NULL THEN
        -- Sin sesión: cuenta como salto y su causa entra al motivo dominante.
        IF v_status = 'SKIPPED' THEN
          -- Omisión declarada (con causa): hay registro (V30).
          a_recorded := a_recorded + 1;
          a_skipped := a_skipped + 1;
          a_reasons := a_reasons || v_wreason;
          a_session_pcts := a_session_pcts || 0::numeric;
        END IF;
        CONTINUE;
      END IF;

      -- Sesión registrada en la app.
      v_started := (v_date + time '19:00') AT TIME ZONE v_tz;
      v_active  := greatest(5, round(v_minutes[w] * v_target / 100.0));
      v_rpe     := CASE WHEN v_target >= 85 THEN 6 WHEN v_target >= 60 THEN 7 ELSE 8 END;
      v_sat     := CASE WHEN v_target >= 85 THEN 5 WHEN v_target >= 60 THEN 4 ELSE 2 END;
      INSERT INTO workout_sessions (user_id, planned_workout_id, plan_id, attempt_number,
          counts_toward_adherence, started_at, ended_at, active_minutes, completion_percentage,
          session_rpe, satisfaction, source, status)
      VALUES (v_user, v_workout, v_plan, 1, true, v_started,
              v_started + make_interval(mins => v_active), v_active, 0,
              v_rpe, v_sat, 'APP_TRACKED', 'IN_PROGRESS')
      RETURNING session_id INTO v_session;

      v_session_pct := 0;
      FOR v_pex, v_ex_type, v_planned IN
        SELECT planned_exercise_id, prescription_type,
               CASE WHEN prescription_type = 'DURATION' THEN planned_sets * planned_duration_seconds
                    ELSE planned_sets * planned_reps END
        FROM planned_workout_exercises WHERE planned_workout_id = v_workout ORDER BY exercise_order
      LOOP
        v_actual := round(v_planned * v_target / 100.0);
        v_pct := least(100, round(v_actual * 100.0 / v_planned, 2));
        v_ex_status := CASE WHEN v_pct >= 80 THEN 'COMPLETED' WHEN v_pct > 0 THEN 'PARTIAL' ELSE 'SKIPPED' END;
        v_ex_reason := CASE WHEN v_ex_status = 'COMPLETED' THEN NULL ELSE coalesce(v_skip[w], 'OTHER') END;
        INSERT INTO workout_session_exercises (session_id, planned_exercise_id, actual_sets,
            actual_reps_total, actual_duration_seconds, actual_load_kg, completion_percentage,
            status, skip_reason)
        VALUES (v_session, v_pex,
                CASE WHEN v_target >= 80 THEN v_sets[w] ELSE greatest(1, v_sets[w] - 1) END,
                CASE WHEN v_ex_type = 'DURATION' THEN 0 ELSE v_actual END,
                CASE WHEN v_ex_type = 'DURATION' THEN v_actual ELSE 0 END,
                NULL, v_pct, v_ex_status, v_ex_reason);
        v_session_pct := v_session_pct + v_pct;
        IF v_ex_status = 'COMPLETED' THEN a_completed_ex := a_completed_ex + 1; END IF;
        IF v_ex_type = 'DURATION' THEN
          a_exec_secs := a_exec_secs + v_actual; a_exec_vol := a_exec_vol + round(v_actual / 30.0);
        ELSE
          a_exec_reps := a_exec_reps + v_actual; a_exec_vol := a_exec_vol + v_actual;
        END IF;
        IF v_ex_reason IS NOT NULL THEN a_reasons := a_reasons || v_ex_reason; END IF;
      END LOOP;
      v_session_pct := least(100, round(v_session_pct / 3, 2));

      UPDATE workout_sessions
         SET completion_percentage = v_session_pct,
             status = CASE WHEN v_session_pct >= 80 THEN 'COMPLETED' ELSE 'PARTIAL' END
       WHERE session_id = v_session;

      a_num := a_num + v_session_pct;
      a_recorded := a_recorded + 1; a_obs_num := a_obs_num + v_session_pct;
      a_session_pcts := a_session_pcts || v_session_pct;
      IF v_session_pct >= 30 THEN a_valid := a_valid + 1; ELSE a_skipped := a_skipped + 1; END IF;
      IF v_session_pct >= 80 THEN a_completed := a_completed + 1; END IF;
      a_minutes := a_minutes + v_active;
      a_rpes := a_rpes || v_rpe; a_sats := a_sats || v_sat;
    END LOOP;

    v_volumes := v_volumes || a_planned_vol;
    CONTINUE WHEN w = 8;   -- la semana en curso aún no tiene métricas

    -- ---------------------------------------------- métricas de la semana w
    m_weighted := round(a_num / nullif(a_den, 0), 2);
    m_prev := CASE WHEN w > 1 THEN v_weighted[w - 1] END;
    v_weighted := v_weighted || m_weighted;

    -- Racha final de entrenamientos sin sesión válida (>= 30 %).
    a_streak := 0;
    FOR i IN REVERSE 3..1 LOOP
      EXIT WHEN a_session_pcts[i] >= 30;
      a_streak := a_streak + 1;
    END LOOP;

    m_rpe := (SELECT round(avg(x), 2) FROM unnest(a_rpes) x);
    m_reason := (SELECT r FROM unnest(a_reasons) r GROUP BY r ORDER BY count(*) DESC, r LIMIT 1);
    m_days := (SELECT v_week_end - max((s.started_at AT TIME ZONE v_tz)::date)
                 FROM workout_sessions s
                WHERE s.user_id = v_user AND (s.started_at AT TIME ZONE v_tz)::date <= v_week_end);

    m_factors := '{}'::jsonb; m_score := 0;
    i := CASE WHEN m_weighted >= 80 THEN 0 WHEN m_weighted >= 60 THEN 10 WHEN m_weighted >= 40 THEN 20 ELSE 30 END;
    IF i > 0 THEN m_factors := m_factors || jsonb_build_object('low_adherence', i); END IF;
    m_score := m_score + i;
    i := CASE WHEN a_streak >= 3 THEN 25 WHEN a_streak = 2 THEN 15 WHEN a_streak = 1 THEN 5 ELSE 0 END;
    IF i > 0 THEN m_factors := m_factors || jsonb_build_object('consecutive_skips', i); END IF;
    m_score := m_score + i;
    m_drop := m_prev - m_weighted;
    IF m_drop > 0 THEN
      i := CASE WHEN m_drop >= 25 THEN 15 WHEN m_drop >= 15 THEN 5 ELSE 0 END;
      IF i > 0 THEN m_factors := m_factors || jsonb_build_object('adherence_drop', i); END IF;
      m_score := m_score + i;
    END IF;
    IF m_rpe >= 8 THEN m_factors := m_factors || jsonb_build_object('overexertion', 10); m_score := m_score + 10; END IF;
    m_level := CASE WHEN m_score >= 70 THEN 'CRITICAL' WHEN m_score >= 50 THEN 'HIGH'
                    WHEN m_score >= 25 THEN 'MODERATE' ELSE 'LOW' END;

    INSERT INTO weekly_user_metrics (user_id, plan_id, week_number, week_start_date, week_end_date,
        has_active_plan, scheduled_workouts, valid_workouts, completed_workouts, skipped_workouts,
        assigned_exercises, completed_exercises, weighted_adherence_pct, frequency_adherence_pct,
        workout_adherence_pct, exercise_adherence_pct, total_training_minutes, average_session_rpe,
        average_satisfaction, consecutive_skips, days_since_last_workout, dominant_skip_reason,
        risk_score, risk_level, risk_factors, is_dropout, calculation_version, calculated_at,
        planned_week_volume, executed_volume, planned_reps, planned_seconds, executed_reps,
        executed_seconds, recorded_workouts, observed_adherence_pct, registration_coverage_pct)
    VALUES (v_user, v_plan, w, v_week_start, v_week_end, true, 3, a_valid, a_completed, a_skipped,
            a_assigned, a_completed_ex, m_weighted, round(a_valid * 100.0 / 3, 2),
            round(a_completed * 100.0 / 3, 2), round(a_completed_ex * 100.0 / a_assigned, 2),
            a_minutes, m_rpe, (SELECT round(avg(x), 2) FROM unnest(a_sats) x),
            a_streak, m_days, m_reason, m_score, m_level, m_factors, coalesce(m_days >= 14, false),
            v_config, (v_week_end + 1 + time '00:30') AT TIME ZONE v_tz,
            a_planned_vol, a_exec_vol, a_planned_reps, a_planned_secs, a_exec_reps, a_exec_secs,
            a_recorded, round(a_obs_num / nullif(a_recorded, 0), 2),
            round(a_recorded * 100.0 / 3, 2))
    RETURNING weekly_metric_id INTO v_metric;
    v_metric_ids := v_metric_ids || v_metric;
  END LOOP;

  -- ------------------------------------- intervenciones (una por semana medida)
  FOR w IN 1..7 LOOP
    v_types := CASE WHEN v_adjust[w + 1] IS NULL THEN ARRAY['NONE'] ELSE ARRAY[v_adjust[w + 1]] END;
    v_change := round((v_volumes[w + 1] - v_volumes[w]) * 100.0 / v_volumes[w], 2);
    v_message := CASE
      WHEN v_types[1] = 'NONE' AND v_change > 0 THEN
        format('Cumpliste el %s %% de tu plan. Esta semana subimos un poco el volumen para seguir avanzando.', round(v_weighted[w]))
      WHEN v_types[1] = 'NONE' THEN
        format('Cumpliste el %s %% de tu plan. Mantenemos el mismo volumen esta semana.', round(v_weighted[w]))
      WHEN v_skip[w] = 'FATIGUE' THEN
        format('Cumpliste el %s %% de tu plan. Nos dijiste que llegabas cansado, asi que bajamos el volumen y la carga.', round(v_weighted[w]))
      WHEN v_skip[w] = 'LACK_OF_TIME' THEN
        format('Cumpliste el %s %% de tu plan. Nos dijiste que te falto tiempo, asi que acortamos las sesiones y mantenemos los mismos dias.', round(v_weighted[w]))
      ELSE format('Cumpliste el %s %% de tu plan. Ajustamos el plan a lo que lograste esta semana.', round(v_weighted[w]))
    END;
    v_after := CASE WHEN w < 7 THEN v_weighted[w + 1] END;
    v_outcome := CASE WHEN v_after IS NULL THEN 'PENDING'
                      WHEN v_after - v_weighted[w] > 5 THEN 'IMPROVED'
                      WHEN v_weighted[w] - v_after > 5 THEN 'WORSENED'
                      ELSE 'UNCHANGED' END;
    INSERT INTO user_interventions (user_id, weekly_metric_id, source_plan_id, resulting_plan_id,
        trigger_adherence_pct, trigger_skip_reason, adjustment_types, target_volume_change_pct,
        previous_week_volume, resulting_week_volume, actual_volume_change_pct, duration_change_pct,
        days_change, difficulty_change, load_change_pct, message_shown, rule_version, applied_at,
        adherence_after_pct, outcome)
    VALUES (v_user, v_metric_ids[w], v_plan_ids[w], v_plan_ids[w + 1], v_weighted[w],
            (SELECT dominant_skip_reason FROM weekly_user_metrics WHERE weekly_metric_id = v_metric_ids[w]),
            v_types::varchar[], v_change, v_volumes[w], v_volumes[w + 1], v_change,
            round((v_minutes[w + 1] - v_minutes[w]) * 100.0 / v_minutes[w], 2), 0, 0, NULL,
            v_message, v_config, (v_first + w * 7 + time '00:30') AT TIME ZONE v_tz,
            v_after, v_outcome);
  END LOOP;

  RAISE NOTICE 'Usuario % (id %) creado con 8 semanas; plan vigente %.', v_email, v_user, v_plan_ids[8];
END $$;

COMMIT;
