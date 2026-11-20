#!/bin/bash
# Pruebas HTTP directas contra el backend 5977d28 local (usuarios sinteticos *@e2e.local).
B=http://localhost:8080/api/v1
J='Content-Type: application/json'
req() { # metodo ruta [cuerpo] [token]  -> imprime "METODO ruta -> codigo cuerpo"
  local m=$1 p=$2 d=$3 t=$4 out code
  out=$(curl -s -i -X $m "$B$p" -H "$J" ${t:+-H "Authorization: Bearer $t"} ${d:+-d "$d"})
  code=$(echo "$out" | head -1 | awk '{print $2}')
  ra=$(echo "$out" | grep -i '^retry-after:' | tr -d '\r')
  body=$(echo "$out" | sed '1,/^\r$/d' | tr -d '\n' | sed -E 's/"token":"[^"]+"/"token":"<jwt>"/; s/"timestamp":"[^"]+",?//' | cut -c1-230)
  echo "$m $p ${d:+$(echo "$d" | sed -E 's/"(password|newPassword)":"[^"]*"/"\1":"***"/g')} -> $code ${ra:+[$ra] }$body"
}
tok() { curl -s -X POST $B/auth/login -H "$J" -d "{\"email\":\"$1\",\"password\":\"$2\"}" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("token",""))' 2>/dev/null; }
alta() { req POST /auth/register "{\"email\":\"$1\",\"password\":\"Kora12345\",\"firstName\":\"Sintetico\",\"timezone\":\"America/Lima\",\"acceptsStudyParticipation\":true}" >/dev/null; }
echo "### Eliminacion de cuenta"
alta del1@e2e.local; T=$(tok del1@e2e.local Kora12345)
req DELETE /users/me "" "$T"
req DELETE /users/me '{"password":"Kora12345"}' "$T"
req DELETE /users/me '{"password":"Kora12345","confirm":false}' "$T"
req DELETE /users/me '{"password":"Incorrecta1","confirm":true}' "$T"
req DELETE /users/me '{"password":"Kora12345","confirm":true}' "$T"
echo "-- despues de eliminar:"
req GET /users/me "" "$T"
req POST /auth/login '{"email":"del1@e2e.local","password":"Kora12345"}'
echo "### 429 por intentos de reautenticacion fallidos"
alta del2@e2e.local; T2=$(tok del2@e2e.local Kora12345)
for i in 1 2 3 4 5 6 7; do req DELETE /users/me '{"password":"Mala-'$i'xx","confirm":true}' "$T2"; done
echo "### Recuperacion de contrasena"
alta rec1@e2e.local; TR=$(tok rec1@e2e.local Kora12345)
req POST /auth/password-reset/request '{"email":"rec1@e2e.local"}'
req POST /auth/password-reset/request '{"email":"noexiste@e2e.local"}'
sleep 3; ls -1 correo/ | tail -3
