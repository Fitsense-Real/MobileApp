# Una cuenta sintetica participante con plan del motor de reglas (Backend LOCAL con documentos sinteticos).
import json, os, sys, time, urllib.request, urllib.error
B = sys.argv[1]; P = os.environ['AUDIT_PASSWORD']; e = f'audit-c1-plan-{int(time.time())}@audit.local'
def call(m, p, b=None, t=None):
    r = urllib.request.Request(B + p, data=None if b is None else json.dumps(b).encode(), method=m); r.add_header('Content-Type', 'application/json')
    if t: r.add_header('Authorization', 'Bearer ' + t)
    try:
        with urllib.request.urlopen(r, timeout=30) as x: raw = x.read().decode(); return x.status, (json.loads(raw) if raw.strip() else None)
    except urllib.error.HTTPError as er: return er.code, er.read().decode()
d = {x['type']: x['version'] for x in call('GET', '/legal-documents')[1]['documents']}
assert call('POST', '/auth/register', {'firstName': 'Auditoria', 'email': e, 'password': P, 'timezone': 'America/Lima', 'acceptsStudyParticipation': True,
  'acceptedTermsVersion': d['TERMS_OF_SERVICE'], 'acceptedPrivacyVersion': d['PRIVACY_POLICY'], 'acceptedStudyConsentVersion': d['STUDY_PARTICIPATION']})[0] == 201
t = call('POST', '/auth/login', {'email': e, 'password': P})[1]['token']
call('POST', '/users/me/profile', {'birthDate': '1990-05-05', 'heightCm': 170, 'currentWeightKg': 70, 'fitnessLevel': 'BEGINNER', 'goalType': 'GENERAL_FITNESS', 'goalText': 'Constancia', 'trainingLocation': 'HOME', 'daysPerWeek': 3, 'availableDays': [1, 3, 5], 'sessionMinutes': 45, 'equipmentCodes': ['body weight'], 'blockedExerciseIds': []}, t)
s, op = call('POST', '/users/me/plan/generation', None, t)
for _ in range(40):
    if op.get('terminal') or op.get('status') == 'COMPLETED': break
    time.sleep(2); s, op = call('GET', '/users/me/plan/generation/' + op['operationId'], None, t)
print(e, op.get('status'))
