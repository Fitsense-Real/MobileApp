#!/usr/bin/env python3
"""Auditoria Mobile: contratos contra un Backend generation LOCAL (IA apagada, base aislada).
Solo cuentas sinteticas @audit.local. Nunca el usuario 48 ni produccion.
Uso: python3 -I contratos.py http://localhost:8080/api/v1 <log_backend>
"""
import json, sys, time, re, urllib.request, urllib.error, datetime

BASE = sys.argv[1]
LOG = sys.argv[2] if len(sys.argv) > 2 else None
PWD = __import__('os').environ['AUDIT_PASSWORD']
STAMP = str(int(time.time()))
out = []

def say(*a):
    line = ' '.join(str(x) for x in a)
    print(line); out.append(line)

def call(method, path, body=None, token=None):
    data = None if body is None else json.dumps(body).encode()
    req = urllib.request.Request(BASE + path, data=data, method=method)
    req.add_header('Accept', 'application/json')
    if body is not None: req.add_header('Content-Type', 'application/json')
    if token: req.add_header('Authorization', 'Bearer ' + token)
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            raw = r.read().decode() or 'null'
            return r.status, json.loads(raw) if raw.strip() else None
    except urllib.error.HTTPError as e:
        raw = e.read().decode()
        try: return e.code, json.loads(raw)
        except Exception: return e.code, raw

def short(v, n=300):
    s = json.dumps(v, ensure_ascii=False) if not isinstance(v, str) else v
    return s if len(s) <= n else s[:n] + '…'

def register(tag, participa, tz='America/Lima', extra=None):
    email = f'audit-{tag}-{STAMP}@audit.local'
    body = {'firstName': 'Auditoria', 'lastName': tag, 'email': email, 'password': PWD,
            'timezone': tz, 'acceptsStudyParticipation': participa}
    if extra: body.update(extra)
    s, r = call('POST', '/auth/register', body)
    return email, s, r

def login(email, pwd=PWD):
    s, r = call('POST', '/auth/login', {'email': email, 'password': pwd})
    return (r or {}).get('token') if s == 200 else None, s, r

PROFILE = {
    'birthDate': '1990-05-10', 'biologicalSex': None, 'heightCm': 170, 'currentWeightKg': 70,
    'targetWeightKg': None, 'fitnessLevel': 'BEGINNER', 'goalType': 'GENERAL_FITNESS',
    'goalText': 'Sentirme mejor', 'trainingLocation': 'HOME', 'daysPerWeek': 3,
    'availableDays': [1, 3, 5], 'sessionMinutes': 45, 'equipmentCodes': ['body weight'],
    'blockedExerciseIds': [], 'healthNotes': None, 'allowHighImpact': True, 'allowFloorExercises': True,
    'allowKneelingExercises': True, 'allowHangingExercises': True, 'allowOverheadExercises': True,
}

def generate(token, wait=90):
    s, op = call('POST', '/users/me/plan/generation', None, token)
    say('  POST /users/me/plan/generation ->', s, short(op, 400))
    if s not in (200, 201, 202) or not isinstance(op, dict): return s, op
    oid = op.get('operationId')
    t0 = time.time()
    while time.time() - t0 < wait:
        if op.get('status') in ('COMPLETED', 'FAILED', 'NO_FACTIBLE', 'EXPIRED'): break
        time.sleep(2)
        s, op = call('GET', f'/users/me/plan/generation/{oid}', None, token)
    say('  operacion final ->', s, short(op, 500))
    return s, op

def section(t):
    say(''); say('=' * 8, t)

# ---------------------------------------------------------------- 1
section('1. Registro SIN participar en el estudio (casilla «Opcional» de Mobile)')
e1, s, r = register('noparticipa', False)
say('  POST /auth/register ->', s, short(r))
tok1, s, _ = login(e1); say('  POST /auth/login ->', s)
s, r = call('POST', '/users/me/profile', PROFILE, tok1); say('  POST /users/me/profile ->', s)
generate(tok1, 30)
s, r = call('GET', '/users/me/plan/current', None, tok1); say('  GET /users/me/plan/current ->', s, short(r))
s, r = call('GET', '/users/me/plan/limitations', None, tok1); say('  GET /users/me/plan/limitations ->', s, short(r))

# ---------------------------------------------------------------- 2
section('2. Registro con zona horaria escrita a mano (campo de texto libre de Mobile)')
for tz in ['Lima', 'america/lima', 'GMT-5', '']:
    e, s, r = register('tz' + re.sub(r'\W', '', tz or 'vacia'), True, tz=tz)
    say(f'  timezone={tz!r} -> register', s, short(r, 220))

# ---------------------------------------------------------------- 3
section('3. Registro con versiones de condiciones/privacidad (campos que Mobile no envia)')
s, r = call('GET', '/users/me/consents', None, tok1); say('  GET /users/me/consents (cuenta 1) ->', s, short(r, 400))
e, s, r = register('terms', True, extra={'acceptedTermsVersion': 'v1', 'acceptedPrivacyVersion': 'v1'})
say('  register con acceptedTermsVersion=v1 sin version vigente ->', s, short(r, 250))

# ---------------------------------------------------------------- 4
section('4. Participante: generacion (motor de reglas) y contenido del plan')
e2, s, r = register('participa', True); say('  register ->', s, short(r, 250))
tok2, s, _ = login(e2); say('  login ->', s)
s, r = call('POST', '/users/me/profile', PROFILE, tok2); say('  profile ->', s)
generate(tok2, 120)
s, plan = call('GET', '/users/me/plan/current', None, tok2)
say('  GET /users/me/plan/current ->', s)
if s == 200 and isinstance(plan, dict):
    say('  claves del plan:', sorted(plan.keys()))
    say('  effortGuidance:', short(plan.get('effortGuidance'), 500))
    ws = plan.get('workouts') or []
    say('  entrenamientos:', len(ws), [(w.get('scheduledDate'), w.get('workoutName'), w.get('status')) for w in ws])
    if ws:
        ex = (ws[0].get('exercises') or [])
        say('  claves de un ejercicio:', sorted(ex[0].keys()) if ex else None)
        for x in ex[:8]:
            say('   -', x.get('exerciseName'), '|', x.get('targetMuscle'), '|', x.get('bodyPart'), '|', x.get('equipment'),
                '|', x.get('prescriptionType'), x.get('plannedSets'), 'x', x.get('plannedReps') or x.get('plannedDurationSeconds'),
                '| desc', x.get('restSeconds'), '| gif', x.get('gifPath'), '| notes', x.get('notes'))
        if ex:
            s, d = call('GET', f"/catalog/exercises/{ex[0]['exerciseId']}", None, tok2)
            say('  GET /catalog/exercises/{id} ->', s, short(d, 900))

# ---------------------------------------------------------------- 5
section('5. Sesion en vivo: registro completo, parcial (D-M1) y no realizado; finalizar')
w = next((w for w in (plan or {}).get('workouts', []) if w.get('status') == 'SCHEDULED'), None) if isinstance(plan, dict) else None
if w:
    s, sess = call('POST', f"/workouts/{w['plannedWorkoutId']}/start", None, tok2)
    say('  start ->', s, short(sess, 200))
    if s in (200, 201):
        sid = sess['sessionId']; exs = sorted(w['exercises'], key=lambda e: e.get('exerciseOrder') or 0)
        for i, x in enumerate(exs):
            dur = x.get('prescriptionType') == 'DURATION'
            sets = x.get('plannedSets') or 1
            if i == 0:   # completo
                body = {'actualSets': sets, 'actualRepsTotal': 0 if dur else sets * (x.get('plannedReps') or 0),
                        'actualDurationSeconds': sets * (x.get('plannedDurationSeconds') or 0) if dur else 0,
                        'actualLoadKg': None, 'skipReason': None}
            elif i == 1:  # parcial
                body = {'actualSets': 1, 'actualRepsTotal': 0 if dur else max(1, (x.get('plannedReps') or 2) // 2),
                        'actualDurationSeconds': max(1, (x.get('plannedDurationSeconds') or 2) // 2) if dur else 0,
                        'actualLoadKg': None, 'skipReason': 'FATIGUE'}
            else:         # no realizado
                body = {'actualSets': 0, 'actualRepsTotal': 0, 'actualDurationSeconds': 0, 'actualLoadKg': 0, 'skipReason': 'LACK_OF_TIME'}
            s, r = call('PUT', f"/sessions/{sid}/exercises/{x['plannedExerciseId']}", body, tok2)
            rec = next((e for e in (r or {}).get('exercises', []) if e.get('plannedExerciseId') == x['plannedExerciseId']), {}) if isinstance(r, dict) else {}
            say(f'   PUT ejercicio {i+1} ->', s, rec.get('status'), rec.get('completionPercentage'))
        # repetir el mismo PUT (reintento P1): no debe acumular
        x = exs[0]
        s, r = call('PUT', f"/sessions/{sid}/exercises/{x['plannedExerciseId']}", {'actualSets': 1, 'actualRepsTotal': 1, 'actualDurationSeconds': 0, 'actualLoadKg': None, 'skipReason': 'FATIGUE'}, tok2)
        rec = next((e for e in r.get('exercises', []) if e.get('plannedExerciseId') == x['plannedExerciseId']), {})
        say('   PUT repetido sobre el ejercicio 1 (reemplaza, no acumula) ->', s, rec.get('actualRepsTotal'), rec.get('status'))
        s, r = call('POST', f'/sessions/{sid}/finish', {'sessionRpe': 6, 'satisfaction': 4}, tok2)
        say('  finish ->', s, short({k: (r or {}).get(k) for k in ['status', 'completionPercentage', 'sessionRpe', 'activeMinutes']}))
        s, r = call('POST', f'/sessions/{sid}/finish', {'sessionRpe': 6}, tok2)
        say('  finish repetido (doble toque) ->', s, short(r, 200))
        s, r = call('POST', f'/sessions/{sid}/finish', {'sessionRpe': 6, 'notes': 'observacion'}, tok2)
        say('  finish con campo «notes» (no existe en el contrato) ->', s, short(r, 160))

# ---------------------------------------------------------------- 6
section('6. Omitir un entrenamiento con motivo y contexto de falta de tiempo')
s, plan = call('GET', '/users/me/plan/current', None, tok2)
w2 = next((w for w in plan.get('workouts', []) if w.get('status') == 'SCHEDULED'), None) if s == 200 else None
if w2:
    s, r = call('POST', f"/workouts/{w2['plannedWorkoutId']}/skip", {'reason': 'LACK_OF_TIME', 'lackOfTimeContext': 'IMPREVISTO'}, tok2)
    say('  skip ->', s, short(r, 200))
    s, r = call('POST', f"/workouts/{w2['plannedWorkoutId']}/skip", {'reason': 'LACK_OF_TIME'}, tok2)
    say('  skip repetido ->', s, short(r, 200))
    s, r = call('POST', f"/workouts/{w2['plannedWorkoutId']}/report", {'performedAt': datetime.datetime.now(datetime.timezone.utc).isoformat(), 'sessionRpe': 5, 'exercises': [
        {'plannedExerciseId': x['plannedExerciseId'], 'actualSets': 0, 'actualRepsTotal': 0, 'actualDurationSeconds': 0, 'actualLoadKg': 0, 'skipReason': 'OTHER'} for x in w2['exercises']]}, tok2)
    say('  report («Ya lo hice») sobre un omitido ->', s, short(r, 250))

# ---------------------------------------------------------------- 7
section('7. Metricas, intervenciones y adaptaciones (lectura)')
for p in ['/users/me/metrics/weekly', '/users/me/interventions', '/users/me/plan/adaptations', '/users/me/plans',
          '/users/me/pain-exclusions/effective', '/users/me/pain-exclusions/confirmation-requests', '/users/me/notification-preferences']:
    s, r = call('GET', p, None, tok2); say(f'  GET {p} ->', s, short(r, 220))

# ---------------------------------------------------------------- 8
section('8. Recuperacion de contrasena (entrega dev-log) y revocacion del JWT')
s, r = call('POST', '/auth/password-reset/request', {'email': e2}); say('  request ->', s, short(r))
s, r = call('POST', '/auth/password-reset/request', {'email': 'no-existe-' + STAMP + '@audit.local'}); say('  request (correo inexistente) ->', s, short(r))
token_reset = None
if LOG:
    time.sleep(2)
    txt = open(LOG, encoding='utf-8', errors='replace').read()
    m = [x for x in re.findall(r'[A-Za-z0-9_-]{43}', txt.split(e2)[-1] if e2 in txt else '')]
    token_reset = m[0] if m else None
say('  token en el log local (longitud):', len(token_reset) if token_reset else None)
s, r = call('POST', '/auth/password-reset/confirm', {'token': 'codigo-invalido', 'newPassword': 'NuevaClave-2026'}); say('  confirm con codigo invalido ->', s, short(r))
if token_reset:
    s, r = call('POST', '/auth/password-reset/confirm', {'token': token_reset, 'newPassword': 'NuevaClave-2026'}); say('  confirm valido ->', s)
    s, r = call('GET', '/users/me', None, tok2); say('  GET /users/me con el JWT anterior ->', s, short(r, 150))
    s, r = call('POST', '/auth/password-reset/confirm', {'token': token_reset, 'newPassword': 'OtraClave-2026'}); say('  reutilizar el codigo ->', s, short(r, 150))
    tok2, s, _ = login(e2, 'NuevaClave-2026'); say('  login con la nueva clave ->', s)

# ---------------------------------------------------------------- 9
section('9. Retirada del estudio y generacion posterior')
s, r = call('POST', '/users/me/withdraw', None, tok2); say('  withdraw ->', s, short({k: (r or {}).get(k) for k in ['studyParticipant', 'withdrawnAt', 'participantCode']}))
s, r = call('GET', '/users/me/consents', None, tok2); say('  consents tras retirarse ->', s, short(r, 400))
s, r = call('POST', '/users/me/plan/generate', None, tok2); say('  POST /users/me/plan/generate tras retirarse ->', s, short(r, 250))
s, r = call('GET', '/users/me/plan/current', None, tok2); say('  GET /users/me/plan/current tras retirarse ->', s, 'plan' if isinstance(r, dict) and r.get('planId') else short(r, 150))

# ---------------------------------------------------------------- 10
section('10. Endpoints que Mobile no expone: cambio de clave con sesion y verificacion de correo')
for m, p in [('POST', '/users/me/password'), ('PUT', '/users/me/password'), ('POST', '/auth/verify-email'), ('POST', '/auth/email-verification')]:
    s, r = call(m, p, {}, tok2); say(f'  {m} {p} ->', s)

open(sys.argv[3] if len(sys.argv) > 3 else 'contratos-salida.txt', 'w').write('\n'.join(out) + '\n')
