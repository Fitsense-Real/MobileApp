#!/bin/bash
# Prueba integral Mobile ↔ Backend PR #82 (local, datos sintéticos, sin Replicate, sin Google).
S=/tmp/claude-0/-home-user/7a9522d3-2797-5dcc-8e36-7b70b17e272d/scratchpad
export PATH=$S/sdk350/flutter/bin:$PATH
B=http://localhost:8080/api/v1; J='Content-Type: application/json'
RUN=$(date +%s); A="push-a-$RUN@e2e.local"; BB="push-b-$RUN@e2e.local"; P="Sintetica-$RUN-x9"
FID=$(python3 -c 'import secrets,string; a=string.ascii_letters+string.digits+"_-"; print("".join(secrets.choice(a) for _ in range(22)))')
q() { su postgres -c "psql -d fitsense_push -At -F ' | ' -c \"$1\""; }
echo "== Cuentas sintéticas (A con perfil, B sin plan)"
for E in $A $BB; do curl -s -o /dev/null -w "registro %{http_code}\n" $B/auth/register -H "$J" -d "{\"email\":\"$E\",\"password\":\"$P\",\"firstName\":\"Sintetico\",\"timezone\":\"America/Lima\",\"acceptsStudyParticipation\":true}"; done
TA=$(curl -s $B/auth/login -H "$J" -d "{\"email\":\"$A\",\"password\":\"$P\"}" | python3 -c 'import json,sys; print(json.load(sys.stdin)["token"])')
curl -s -o /dev/null -w "perfil A %{http_code}\n" $B/users/me/profile -H "$J" -H "Authorization: Bearer $TA" -d '{"birthDate":"1995-03-10","heightCm":170,"currentWeightKg":70,"fitnessLevel":"INTERMEDIATE","goalType":"GENERAL_FITNESS","goalText":"Sentirme mejor","trainingLocation":"GYM","daysPerWeek":3,"availableDays":[1,3,5],"sessionMinutes":45}'
UA=$(q "select user_id from users where email='$A'"); echo "usuario A = $UA, FID sintético = ${FID:0:4}… (22 caracteres)"
echo "== Código Mobile (PushDeviceRepository) contra el backend real"
cd /home/user/MobileApp && KORA_LIVE_API_BASE_URL=$B KORA_LIVE_EMAIL_A=$A KORA_LIVE_EMAIL_B=$BB KORA_LIVE_PASSWORD=$P KORA_LIVE_FID=$FID \
  flutter test test/live/push_backend_live_test.dart 2>&1 | grep -E "All tests|Some tests|\[E\]|Expected|Actual|skip" | sed 's/^/   /'
echo "== PostgreSQL: dispositivo asociado al usuario"
q "\\d push_devices" >/dev/null 2>&1
q "select table_name from information_schema.tables where table_name like '%push%' or table_name like 'notification%' order by 1"
q "select d.device_id, u.email, left(d.installation_id,4)||'…', d.identifier_type, d.platform, d.app_id, d.app_version, coalesce(d.revoked_at::text,'activo'), coalesce(d.revoke_reason,'') from push_devices d join users u using(user_id) where u.email in ('$A','$BB') order by d.device_id" | sed "s/$RUN/<n>/g; s/^/   /"
echo "   FID guardado = FID enviado por la app: $(q "select count(*) from push_devices where installation_id='$FID' and revoked_at is null and user_id=$UA") fila activa de A"
echo "== Generación asíncrona del primer plan de A (motor de reglas, IA apagada)"
curl -s -o /dev/null -w "   POST generacion asincrona %{http_code}\n" -X POST $B/users/me/plan/generation -H "Authorization: Bearer $TA"
for i in $(seq 60); do s=$(curl -s $B/users/me/plan/current -H "Authorization: Bearer $TA" -o /dev/null -w "%{http_code}"); [ "$s" = 200 ] && break; sleep 1; done; echo "   plan actual $s"
q "select operation_id, status, plan_id from plan_generation_operations where user_id=$UA" | sed 's/^/   /'
echo "== Detector push (cada 30 s) y emisor"
for i in $(seq 40); do n=$(q "select count(*) from notification_events where user_id=$UA"); [ "$n" != 0 ] && [ "$(q "select count(*) from notification_deliveries where user_id=$UA")" != 0 ] && break; sleep 3; done
q "select event_type, resource_type, resource_id, target_screen, source, dedupe_key, status, coalesce(status_reason,''), attempts from notification_events where user_id=$UA" | sed 's/^/   evento: /'
q "select d.status, coalesce(d.error_code,''), d.device_id, left(p.installation_id,4)||'…', (p.installation_id='$FID') from notification_deliveries d join push_devices p using(device_id) where d.user_id=$UA order by delivery_id" | sed 's/^/   entrega: /'
echo "== Registro del backend (envío)"
grep -iE "push|fcm|firebase" $S/push82/backend.log | grep -viE "Notificaciones push activas" | sed "s/$FID/<FID>/g" | cut -c1-260 | tail -6 | sed 's/^/   /'
