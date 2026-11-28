# M4: recuperacion de contrasena contra el Backend LOCAL (entrega dev-log: el codigo se lee del log local y no se imprime).
import json, os, re, sys, time, urllib.request, urllib.error
B, LOG, EMAIL = sys.argv[1], sys.argv[2], sys.argv[3]; P = os.environ['AUDIT_PASSWORD']
def call(m, p, b=None, t=None):
    r = urllib.request.Request(B + p, data=None if b is None else json.dumps(b).encode(), method=m); r.add_header('Content-Type', 'application/json')
    if t: r.add_header('Authorization', 'Bearer ' + t)
    try:
        with urllib.request.urlopen(r, timeout=30) as x: raw = x.read().decode(); return x.status, (json.loads(raw) if raw.strip() else None), dict(x.headers)
    except urllib.error.HTTPError as e: return e.code, e.read().decode(), dict(e.headers)
def code():
    m = re.findall(r'RECUPERACION \(SOLO DESARROLLO[^\n]*codigo ([A-Za-z0-9_-]+) valido', open(LOG).read()); return m[-1] if m else None
say = lambda *a: print('RECUPERACION', *a)
s, r, _ = call('POST', '/auth/login', {'email': EMAIL, 'password': P}); old = r['token']; say('login inicial ->', s)
s, _, _ = call('POST', '/auth/password-reset/request', {'email': EMAIL}); say('solicitar codigo ->', s); time.sleep(1); c1 = code()
s, _, _ = call('POST', '/auth/password-reset/request', {'email': EMAIL}); say('solicitar uno nuevo ->', s); time.sleep(1); c2 = code()
say('el codigo nuevo es distinto del anterior ->', c1 != c2)
s, r, _ = call('POST', '/auth/password-reset/confirm', {'token': c1, 'newPassword': P + 'N1'}); say('confirmar con el codigo ANTERIOR ->', s, (r or '')[:90] if isinstance(r, str) else r)
s, _, _ = call('POST', '/auth/password-reset/confirm', {'token': ' ' + c2[:20] + '\n' + c2[20:] + ' ', 'newPassword': P + 'N1'}); say('confirmar con espacios/saltos (la app los quita; el Backend no) ->', s)
s, _, _ = call('POST', '/auth/password-reset/confirm', {'token': c2, 'newPassword': P + 'N1'}); say('confirmar con el codigo vigente ->', s)
s, _, _ = call('GET', '/users/me', None, old); say('sesion anterior (JWT viejo) ->', s)
s, r, _ = call('POST', '/auth/password-reset/confirm', {'token': c2, 'newPassword': P + 'N2'}); say('reutilizar el mismo codigo ->', s)
s, _, _ = call('POST', '/auth/login', {'email': EMAIL, 'password': P + 'N1'}); say('login con la clave nueva ->', s)
s, _, _ = call('POST', '/auth/password-reset/request', {'email': 'no-existe-%d@audit.local' % time.time()}); say('correo inexistente ->', s, '(misma respuesta)')
last = None
for i in range(40):
    s, r, h = call('POST', '/auth/password-reset/request', {'email': EMAIL})
    if s == 429: last = (i + 1, h.get('Retry-After'), r[:100] if isinstance(r, str) else r); break
say('solicitudes repetidas -> 429 tras', last[0] if last else 'NUNCA', 'peticiones; Retry-After', last[1] if last else '-', '|', last[2] if last else '')
