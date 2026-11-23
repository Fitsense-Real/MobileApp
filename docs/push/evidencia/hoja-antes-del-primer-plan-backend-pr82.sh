#!/bin/bash
# Prueba integral: hoja de notificaciones al final del perfil, registro del FID (201) y solo después la
# primera generación. Mobile PR #17 ↔ Backend PR #82 (7abf3a1, jar sin modificar). Local, datos sintéticos,
# sin Replicate, sin salida a Internet. Las cuentas siguen con la sesión iniciada de principio a fin.
S=/tmp/claude-0/-home-user/7a9522d3-2797-5dcc-8e36-7b70b17e272d/scratchpad
export PATH=$S/sdk350/flutter/bin:$PATH
B=http://localhost:8080/api/v1; J='Content-Type: application/json'
RUN=$(date +%s); P="Sintetica-$RUN-x9"
fidgen() { python3 -c 'import secrets,string; a=string.ascii_letters+string.digits+"_-"; print("".join(secrets.choice(a) for _ in range(22)))'; }
q() { su postgres -c "psql -d fitsense_push2 -At -F ' | ' -c \"$1\""; }
alta() { curl -s -o /dev/null $B/auth/register -H "$J" -d "{\"email\":\"$1\",\"password\":\"$P\",\"firstName\":\"Sintetico\",\"timezone\":\"America/Lima\",\"acceptsStudyParticipation\":true}"
  local T=$(curl -s $B/auth/login -H "$J" -d "{\"email\":\"$1\",\"password\":\"$P\"}" | python3 -c 'import json,sys; print(json.load(sys.stdin)["token"])')
  [ "$2" = perfil ] && curl -s -o /dev/null $B/users/me/profile -H "$J" -H "Authorization: Bearer $T" -d '{"birthDate":"1995-03-10","heightCm":170,"currentWeightKg":70,"fitnessLevel":"INTERMEDIATE","goalType":"GENERAL_FITNESS","goalText":"Sentirme mejor","trainingLocation":"GYM","daysPerWeek":3,"availableDays":[1,3,5],"sessionMinutes":45}'
  true; }
A="concedido-a-$RUN@e2e.local"; BB="acepta-b-$RUN@e2e.local"; C="ahora-no-c-$RUN@e2e.local"; D="contrato-d-$RUN@e2e.local"; E="contrato-e-$RUN@e2e.local"
for x in $A $BB $C; do alta $x perfil; done; alta $D; alta $E
FA=$(fidgen); FB=$(fidgen); FC=$(fidgen); FD=$(fidgen)
echo "== 1. App: hoja al final del perfil → permiso → FID → PUT → generación (PushPermissionPrompt, PushController, FirstPlanGenerationController reales)"
cd /home/user/MobileApp && KORA_LIVE_API_BASE_URL=$B KORA_LIVE_EMAIL_A=$A KORA_LIVE_EMAIL_B=$BB KORA_LIVE_EMAIL_C=$C KORA_LIVE_PASSWORD=$P \
  KORA_LIVE_FID_A=$FA KORA_LIVE_FID_B=$FB KORA_LIVE_FID_C=$FC flutter test -r expanded test/live/push_generation_live_test.dart 2>&1 \
  | grep -E "^[0-9:]+ \+[0-9]+.*: (A|B|C) ·|All tests|Some tests|\[E\]|Expected|Actual" | sed -E 's/^[0-9:]+ \+[0-9]+( ~[0-9]+)?( -[0-9]+)?: //' | sort -u | sed 's/^/   /'
echo "== 2. PostgreSQL: dispositivo registrado ANTES de la operación de generación, sin duplicados"
for pair in "A:$A:$FA" "B:$BB:$FB" "C:$C:$FC"; do IFS=: read k email f <<<"$pair"; u=$(q "select user_id from users where email='$email'")
  echo "   $k: dispositivos=$(q "select count(*) from push_devices where user_id=$u") activos=$(q "select count(*) from push_devices where user_id=$u and revoked_at is null") filas_con_su_FID=$(q "select count(*) from push_devices where installation_id='$f'") registrado_antes_de_la_operacion=$(q "select coalesce(((select min(registered_at) from push_devices where user_id=$u) < (select min(created_at) from plan_generation_operations where user_id=$u))::text,'sin dispositivo')")"; done
echo "== 3. Contrato push (cuentas D y E)"
KORA_LIVE_API_BASE_URL=$B KORA_LIVE_EMAIL_A=$D KORA_LIVE_EMAIL_B=$E KORA_LIVE_PASSWORD=$P KORA_LIVE_FID=$FD \
  flutter test test/live/push_backend_live_test.dart 2>&1 | grep -E "All tests|Some tests|\[E\]|Expected|Actual" | sed 's/^/   /'
echo "== 4. Eventos PLAN_GENERATED y entregas (detector cada 30 s)"
for i in $(seq 60); do n=$(q "select count(*) from notification_events where status <> 'PENDIENTE' or attempts > 0"); [ "$n" -ge 3 ] && [ "$(q "select count(*) from notification_deliveries")" -ge 2 ] && break; sleep 3; done
q "select regexp_replace(u.email,'-[0-9]+@','-<n>@'), e.event_type, e.status, coalesce(e.status_reason,''), e.attempts from notification_events e join users u using(user_id) order by u.email" | sed 's/^/   evento: /'
q "select regexp_replace(u.email,'-[0-9]+@','-<n>@'), d.status, coalesce(d.error_code,''), left(p.installation_id,4)||'…' from notification_deliveries d join push_devices p using(device_id) join users u on u.user_id=d.user_id order by u.email" | sed 's/^/   entrega: /'
q "select regexp_replace(u.email,'-[0-9]+@','-<n>@'), o.status from plan_generation_operations o join users u using(user_id) order by u.email" | sed 's/^/   operacion: /'
