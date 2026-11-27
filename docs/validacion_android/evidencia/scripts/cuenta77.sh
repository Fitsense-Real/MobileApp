#!/bin/bash
# Cuenta sintética (participante, casa, peso corporal). Uso: cuenta77.sh <puerto> <prefijo> <conPlan 1|0>. Imprime el correo.
B=http://127.0.0.1:$1/api/v1; J='Content-Type: application/json'; P="Sintetica-av-x9"; E="$2-$(date +%s%N | cut -c1-13)@e2e.local"
curl -s -o /dev/null $B/auth/register -H "$J" -d "{\"email\":\"$E\",\"password\":\"$P\",\"firstName\":\"Sintetico\",\"timezone\":\"America/Lima\",\"acceptsStudyParticipation\":true}"
T=$(curl -s $B/auth/login -H "$J" -d "{\"email\":\"$E\",\"password\":\"$P\"}" | python3 -c 'import json,sys; print(json.load(sys.stdin)["token"])')
curl -s -o /dev/null $B/users/me/profile -H "$J" -H "Authorization: Bearer $T" -d '{"birthDate":"1995-03-10","heightCm":170,"currentWeightKg":70,"fitnessLevel":"BEGINNER","goalType":"GENERAL_FITNESS","goalText":"Sentirme mejor","trainingLocation":"HOME","daysPerWeek":3,"availableDays":[1,2,3,4,5,6,7],"sessionMinutes":45,"equipmentCodes":["body weight"]}'
if [ "$3" = 1 ]; then
  curl -s -o /dev/null -X POST $B/users/me/plan/generation -H "Authorization: Bearer $T"
  for i in $(seq 40); do s=$(curl -s $B/users/me/plan/current -H "Authorization: Bearer $T" -o /dev/null -w "%{http_code}"); [ "$s" = 200 ] && break; sleep 2; done
  [ "$s" = 200 ] || { echo "SIN PLAN $E" >&2; exit 1; }
fi
echo "$E"
