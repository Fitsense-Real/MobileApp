#!/bin/bash
# Prueba integral: registro temprano del dispositivo antes de la generación (Mobile PR #17 ↔ Backend PR #82 7abf3a1).
# Local, datos sintéticos, sin Replicate, sin salida a Internet.
S=/tmp/claude-0/-home-user/7a9522d3-2797-5dcc-8e36-7b70b17e272d/scratchpad
export PATH=$S/sdk350/flutter/bin:$PATH
B=http://localhost:8080/api/v1; J='Content-Type: application/json'
RUN=$(date +%s); P="Sintetica-$RUN-x9"
fidgen() { python3 -c 'import secrets,string; a=string.ascii_letters+string.digits+"_-"; print("".join(secrets.choice(a) for _ in range(22)))'; }
q() { su postgres -c "psql -d fitsense_push2 -At -F ' | ' -c \"$1\""; }
alta() { curl -s -o /dev/null $B/auth/register -H "$J" -d "{\"email\":\"$1\",\"password\":\"$P\",\"firstName\":\"Sintetico\",\"timezone\":\"America/Lima\",\"acceptsStudyParticipation\":true}"
  local T=$(curl -s $B/auth/login -H "$J" -d "{\"email\":\"$1\",\"password\":\"$P\"}" | python3 -c 'import json,sys; print(json.load(sys.stdin)["token"])')
  [ "$2" = perfil ] && curl -s -o /dev/null $B/users/me/profile -H "$J" -H "Authorization: Bearer $T" -d '{"birthDate":"1995-03-10","heightCm":170,"currentWeightKg":70,"fitnessLevel":"INTERMEDIATE","goalType":"GENERAL_FITNESS","goalText":"Sentirme mejor","trainingLocation":"GYM","daysPerWeek":3,"availableDays":[1,3,5],"sessionMinutes":45}'
  echo $T; }
A="temprano-a-$RUN@e2e.local"; C="control-c-$RUN@e2e.local"; D="contrato-d-$RUN@e2e.local"; E="contrato-e-$RUN@e2e.local"
alta $A perfil >/dev/null; TC=$(alta $C perfil); alta $D >/dev/null; alta $E >/dev/null
UA=$(q "select user_id from users where email='$A'"); UC=$(q "select user_id from users where email='$C'")
FA=$(fidgen); FD=$(fidgen)
echo "== 1. App (PushController + FirstPlanGenerationController reales): login → FID → PUT → generación"
cd /home/user/MobileApp && KORA_LIVE_API_BASE_URL=$B KORA_LIVE_EMAIL_A=$A KORA_LIVE_PASSWORD=$P KORA_LIVE_FID=$FA \
  flutter test test/live/push_generation_live_test.dart 2>&1 | grep -E "All tests|Some tests|\[E\]|Expected|Actual|reason" | sed 's/^/   /'
echo "== 2. PostgreSQL: dispositivo de A registrado ANTES de pedir la generación, sin duplicados"
q "select 'dispositivo', left(d.installation_id,4)||'…', d.app_id, coalesce(d.app_version,''), d.registered_at, d.last_seen_at, coalesce(d.revoked_at::text,'activo') from push_devices d where d.user_id=$UA" | sed 's/^/   /'
q "select 'operacion', o.status, o.created_at from plan_generation_operations o where o.user_id=$UA" | sed 's/^/   /'
echo "   registrado antes de la operación: $(q "select (select min(registered_at) from push_devices where user_id=$UA) < (select min(created_at) from plan_generation_operations where user_id=$UA)")"
echo "   filas de A: $(q "select count(*) from push_devices where user_id=$UA") (activas: $(q "select count(*) from push_devices where user_id=$UA and revoked_at is null")); filas con ese FID: $(q "select count(*) from push_devices where installation_id='$FA'")"
echo "== 3. Control: cuenta C genera su plan SIN dispositivo registrado"
curl -s -o /dev/null -w "   POST generacion C %{http_code}\n" -X POST $B/users/me/plan/generation -H "Authorization: Bearer $TC"
echo "== 4. Contrato push con el backend 7abf3a1 (cuentas D y E)"
KORA_LIVE_API_BASE_URL=$B KORA_LIVE_EMAIL_A=$D KORA_LIVE_EMAIL_B=$E KORA_LIVE_PASSWORD=$P KORA_LIVE_FID=$FD \
  flutter test test/live/push_backend_live_test.dart 2>&1 | grep -E "All tests|Some tests|\[E\]|Expected|Actual" | sed 's/^/   /'
echo "== 5. Eventos PLAN_GENERATED (detector cada 30 s) y entregas"
for i in $(seq 50); do n=$(q "select count(*) from notification_events e where e.user_id in ($UA,$UC) and (e.status <> 'PENDIENTE' or e.attempts > 0)"); [ "$n" -ge 2 ] && break; sleep 3; done
q "select case when user_id=$UA then 'A (con dispositivo)' else 'C (control, sin dispositivo)' end, event_type, status, coalesce(status_reason,''), attempts from notification_events where user_id in ($UA,$UC) order by user_id" | sed 's/^/   evento: /'
q "select d.status, coalesce(d.error_code,''), left(p.installation_id,4)||'…', (p.installation_id='$FA') from notification_deliveries d join push_devices p using(device_id) where d.user_id=$UA order by delivery_id" | sed 's/^/   entrega A: /'
echo "   entregas de C: $(q "select count(*) from notification_deliveries where user_id=$UC")"
echo "== 6. Registro del backend (envío)"
grep -E "FirebaseTransportePush|EmisorPush|DetectorEventosPush" $S/push82b/backend.log | sed "s/$FA/<FID>/g" | cut -c1-40,100-260 | tail -4 | sed 's/^/   /'
