-- SOLO fitsense_int: simula una generación que otra instancia está procesando (arrendada 30 min),
-- para comprobar que la eliminación de la cuenta la cancela. El worker local no la toca mientras el arriendo siga vigente.
INSERT INTO plan_generation_operations (operation_id, user_id, kind, status, week_start_date, executions, created_at, started_at, updated_at, lease_owner, lease_expires_at, first_started_at)
VALUES (gen_random_uuid(), 8, 'FIRST_PLAN', 'PROCESSING', '2026-11-23', 1, now(), now(), now(), 'instancia-simulada-e2e', now() + interval '30 minutes', now());
SELECT status, lease_owner FROM plan_generation_operations WHERE user_id = 8 ORDER BY created_at;
