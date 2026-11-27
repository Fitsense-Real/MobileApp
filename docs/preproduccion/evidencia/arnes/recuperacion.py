#!/usr/bin/env python3
"""Recuperacion de contrasena contra el Backend LOCAL (dev-log). Cuenta sintetica @audit.local."""
import json, sys, time, re, urllib.request, urllib.error
BASE, LOG, OUT = sys.argv[1], sys.argv[2], sys.argv[3]
lines = []
def say(*a):
    s = ' '.join(str(x) for x in a); print(s); lines.append(s)
def call(m, p, b=None, t=None):
    req = urllib.request.Request(BASE + p, data=None if b is None else json.dumps(b).encode(), method=m)
    req.add_header('Content-Type', 'application/json')
    if t: req.add_header('Authorization', 'Bearer ' + t)
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            raw = r.read().decode(); return r.status, (json.loads(raw) if raw.strip() else None)
    except urllib.error.HTTPError as e:
        raw = e.read().decode()
        try: return e.code, json.loads(raw)
        except Exception: return e.code, raw
email = f'audit-recupera-{int(time.time())}@audit.local'
s, _ = call('POST', '/auth/register', {'firstName': 'Auditoria', 'email': email, 'password': __import__('os').environ['AUDIT_PASSWORD'], 'timezone': 'America/Lima', 'acceptsStudyParticipation': True}); say('register', s)
s, r = call('POST', '/auth/login', {'email': email, 'password': __import__('os').environ['AUDIT_PASSWORD']}); old = r['token']; say('login', s)
before = open(LOG, encoding='utf-8', errors='replace').read().count('RECUPERACION (SOLO DESARROLLO')
s, r = call('POST', '/auth/password-reset/request', {'email': email}); say('request', s, r.get('message'))
time.sleep(1.5)
codes = re.findall(r'RECUPERACION \(SOLO DESARROLLO[^\n]*codigo ([A-Za-z0-9_-]+) valido hasta ([^.]+\.\d+Z)', open(LOG, encoding='utf-8', errors='replace').read())
code, until = codes[before] if len(codes) > before else (None, None)
say('codigo recibido (solo log local): longitud', len(code) if code else None, '| caduca', until)
s, r = call('POST', '/auth/password-reset/confirm', {'token': code, 'newPassword': '        '}); say('confirm con clave de solo espacios', s, r if isinstance(r, str) else r.get('message'), r.get('details') if isinstance(r, dict) else '')
s, r = call('POST', '/auth/password-reset/confirm', {'token': code, 'newPassword': 'NuevaClave-2026'}); say('confirm valido', s)
s, r = call('GET', '/users/me', None, old); say('GET /users/me con el JWT anterior', s, r.get('message') if isinstance(r, dict) else r)
s, r = call('POST', '/auth/password-reset/confirm', {'token': code, 'newPassword': 'OtraClave-2026'}); say('reutilizar el codigo', s, r.get('message') if isinstance(r, dict) else r)
s, r = call('POST', '/auth/login', {'email': email, 'password': __import__('os').environ['AUDIT_PASSWORD']}); say('login con la clave anterior', s)
s, r = call('POST', '/auth/login', {'email': email, 'password': 'NuevaClave-2026'}); say('login con la clave nueva', s)
for i in range(4):
    s, r = call('POST', '/auth/password-reset/request', {'email': email}); say(f'request #{i+2} en la misma hora', s)
open(OUT, 'w').write('\n'.join(lines) + '\n')
