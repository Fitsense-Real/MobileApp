#!/bin/bash
# Cuenta sintética con perfil en casa (peso corporal) y plan generado por el motor de reglas. Escribe cuenta.txt.
cd /tmp/claude-0/-home-user/7a9522d3-2797-5dcc-8e36-7b70b17e272d/scratchpad/dm1
B=http://localhost:8080/api/v1; J='Content-Type: application/json'; P="Sintetica-dm1-x9"; E="dm1-$(date +%s%N | cut -c1-13)@e2e.local"
curl -s -o /dev/null $B/auth/register -H "$J" -d "{\"email\":\"$E\",\"password\":\"$P\",\"firstName\":\"Sintetico\",\"timezone\":\"America/Lima\",\"acceptsStudyParticipation\":true}"
T=$(curl -s $B/auth/login -H "$J" -d "{\"email\":\"$E\",\"password\":\"$P\"}" | python3 -c 'import json,sys; print(json.load(sys.stdin)["token"])')
curl -s -o /dev/null $B/users/me/profile -H "$J" -H "Authorization: Bearer $T" -d '{"birthDate":"1995-03-10","heightCm":170,"currentWeightKg":70,"fitnessLevel":"BEGINNER","goalType":"GENERAL_FITNESS","goalText":"Sentirme mejor","trainingLocation":"HOME","daysPerWeek":3,"availableDays":[1,2,3,4,5,6,7],"sessionMinutes":45,"equipmentCodes":["body weight"]}'
curl -s -o /dev/null -X POST $B/users/me/plan/generation -H "Authorization: Bearer $T"
for i in $(seq 30); do s=$(curl -s $B/users/me/plan/current -H "Authorization: Bearer $T" -o /dev/null -w "%{http_code}"); [ "$s" = 200 ] && break; sleep 2; done
printf '%s\n%s\n' "$E" "$P" > cuenta.txt; echo "cuenta sintética lista (plan $s)"
