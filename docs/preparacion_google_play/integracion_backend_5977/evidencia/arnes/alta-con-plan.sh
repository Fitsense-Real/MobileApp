#!/bin/bash
# Cuenta sintética con perfil y primer plan, solo por HTTP (backend local). Uso: alta-con-plan.sh correo
E="$1"; P="${E2E_PASSWORD:?Define E2E_PASSWORD}"; B=http://localhost:8080/api/v1; J='Content-Type: application/json'
curl -s -o /dev/null -w "registro %{http_code}\n" $B/auth/register -H "$J" -d "{\"email\":\"$E\",\"password\":\"$P\",\"firstName\":\"Sintetico\",\"timezone\":\"America/Lima\",\"acceptsStudyParticipation\":true}"
T=$(curl -s $B/auth/login -H "$J" -d "{\"email\":\"$E\",\"password\":\"$P\"}" | python3 -c 'import json,sys; print(json.load(sys.stdin)["token"])')
curl -s -o /dev/null -w "perfil %{http_code}\n" $B/users/me/profile -H "$J" -H "Authorization: Bearer $T" -d '{"birthDate":"1995-03-10","heightCm":170,"currentWeightKg":70,"fitnessLevel":"INTERMEDIATE","goalType":"GENERAL_FITNESS","goalText":"Sentirme mejor","trainingLocation":"GYM","daysPerWeek":3,"availableDays":[1,3,5],"sessionMinutes":45}'
curl -s -o /dev/null -w "generacion %{http_code}\n" -X POST $B/users/me/plan/generation -H "Authorization: Bearer $T"
for i in $(seq 20); do s=$(curl -s $B/users/me/plan/current -H "Authorization: Bearer $T" -o /dev/null -w "%{http_code}"); [ "$s" = 200 ] && break; sleep 1; done; echo "plan actual $s"
