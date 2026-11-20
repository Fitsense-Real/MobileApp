#!/bin/bash
P="${E2E_PASSWORD:?Define E2E_PASSWORD (cuentas sintéticas locales)}"
PN="${E2E_NEW_PASSWORD:?Define E2E_NEW_PASSWORD}"
source <(sed -n '/^B=/,/^alta()/p' "$(dirname "$0")/contratos.sh")
codigo() { "$(dirname "$0")/../smtp-venv/bin/python" -I -c "
import email,sys,glob,re
f=sorted(glob.glob(sys.argv[1]+'/*'+sys.argv[2]+'.eml'))[-1]
m=email.message_from_bytes(open(f,'rb').read())
t=[p.get_payload(decode=True).decode() for p in m.walk() if p.get_content_type()=='text/plain'][0]
print(re.search(r'^\s*([A-Za-z0-9_-]{30,})\s*$',t,re.M).group(1))" "$(dirname "$0")/correo" "$1"; }
DB() { psql -h localhost -U postgres -d fitsense_int -At -c "$1"; }
echo "### Recuperacion: cambio, reutilizacion, sesiones"
alta rec2@e2e.local; TR=$(tok rec2@e2e.local $P); req POST /auth/password-reset/request '{"email":"rec2@e2e.local"}' >/dev/null; sleep 3; C=$(codigo rec2@e2e.local)
req GET /users/me "" "$TR" | cut -c1-40
req POST /auth/password-reset/confirm "{\"token\":\"$C\",\"newPassword\":\"corta\"}"
req POST /auth/password-reset/confirm "{\"token\":\"codigo-que-no-existe-xxxxxxxxxxxxxxxxxxxxxxxxx\",\"newPassword\":\"$PN\"}"
req POST /auth/password-reset/confirm "{\"token\":\"$C\",\"newPassword\":\"$PN\"}"
req POST /auth/password-reset/confirm "{\"token\":\"$C\",\"newPassword\":\"Otra12345\"}"
echo "-- JWT anterior al cambio:"; req GET /users/me "" "$TR" | cut -c1-90
req POST /auth/login "{\"email\":\"rec2@e2e.local\",\"password\":\"$P\"}"
req POST /auth/login "{\"email\":\"rec2@e2e.local\",\"password\":\"$PN\"}" | cut -c1-90
echo "### Recuperacion: codigo vencido (expiracion adelantada en la base de pruebas)"
req POST /auth/password-reset/request '{"email":"rec2@e2e.local"}' >/dev/null; sleep 3; C2=$(codigo rec2@e2e.local)
DB "UPDATE password_reset_tokens SET created_at = now() - interval '40 minutes', expires_at = now() - interval '1 minute' WHERE used_at IS NULL" >/dev/null
req POST /auth/password-reset/confirm "{\"token\":\"$C2\",\"newPassword\":\"Vencida123\"}"
