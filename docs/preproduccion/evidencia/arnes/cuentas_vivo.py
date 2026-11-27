#!/usr/bin/env python3
"""Crea dos cuentas sinteticas @audit.local (A con plan del motor de reglas, B sin plan) en el Backend LOCAL."""
import json, sys, time, urllib.request, urllib.error
BASE = sys.argv[1]; PWD = __import__('os').environ['AUDIT_PASSWORD']; T = str(int(time.time()))
def call(m, p, b=None, t=None):
    req = urllib.request.Request(BASE + p, data=None if b is None else json.dumps(b).encode(), method=m)
    req.add_header('Content-Type', 'application/json')
    if t: req.add_header('Authorization', 'Bearer ' + t)
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            raw = r.read().decode(); return r.status, (json.loads(raw) if raw.strip() else None)
    except urllib.error.HTTPError as e: return e.code, e.read().decode()
emails = []
for tag in ['vivo-a', 'vivo-b']:
    e = f'audit-{tag}-{T}@audit.local'; emails.append(e)
    call('POST', '/auth/register', {'firstName': 'Auditoria', 'email': e, 'password': PWD, 'timezone': 'America/Lima', 'acceptsStudyParticipation': True})
tok = call('POST', '/auth/login', {'email': emails[0], 'password': PWD})[1]['token']
call('POST', '/users/me/profile', {'birthDate': '1988-03-02', 'heightCm': 165, 'currentWeightKg': 64, 'fitnessLevel': 'BEGINNER', 'goalType': 'GENERAL_FITNESS', 'goalText': 'Constancia', 'trainingLocation': 'HOME', 'daysPerWeek': 3, 'availableDays': [1, 3, 5], 'sessionMinutes': 45, 'equipmentCodes': ['body weight'], 'blockedExerciseIds': []}, tok)
s, op = call('POST', '/users/me/plan/generation', None, tok)
for _ in range(40):
    if op.get('terminal'): break
    time.sleep(2); s, op = call('GET', '/users/me/plan/generation/' + op['operationId'], None, tok)
print(emails[0], emails[1], op.get('status'))
