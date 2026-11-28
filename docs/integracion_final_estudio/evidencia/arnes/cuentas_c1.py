# Cuentas sinteticas @audit.local para los recorridos de Mobile-C1 (Backend LOCAL con documentos sinteticos).
import json, os, sys, time, urllib.request, urllib.error
B = sys.argv[1]; P = os.environ['AUDIT_PASSWORD']; T = str(int(time.time()))
def call(m, p, b=None, t=None):
    r = urllib.request.Request(B + p, data=None if b is None else json.dumps(b).encode(), method=m); r.add_header('Content-Type', 'application/json')
    if t: r.add_header('Authorization', 'Bearer ' + t)
    try:
        with urllib.request.urlopen(r, timeout=30) as x: raw = x.read().decode(); return x.status, (json.loads(raw) if raw.strip() else None)
    except urllib.error.HTTPError as e: return e.code, e.read().decode()
docs = {d['type']: d['version'] for d in call('GET', '/legal-documents')[1]['documents']}
perfil = {'birthDate': '1990-05-05', 'heightCm': 170, 'currentWeightKg': 70, 'fitnessLevel': 'BEGINNER', 'goalType': 'GENERAL_FITNESS', 'goalText': 'Constancia', 'trainingLocation': 'HOME', 'daysPerWeek': 3, 'availableDays': [1, 3, 5], 'sessionMinutes': 45, 'equipmentCodes': ['body weight'], 'blockedExerciseIds': []}
out = {}
for tag, part in [('nopart', False), ('retirada', True), ('limite', True)]:
    e = f'audit-c1-{tag}-{T}@audit.local'; out[tag] = e
    body = {'firstName': 'Auditoria', 'email': e, 'password': P, 'timezone': 'America/Lima', 'acceptsStudyParticipation': part,
            'acceptedTermsVersion': docs['TERMS_OF_SERVICE'], 'acceptedPrivacyVersion': docs['PRIVACY_POLICY']}
    if part: body['acceptedStudyConsentVersion'] = docs['STUDY_PARTICIPATION']
    s, _ = call('POST', '/auth/register', body); assert s == 201, (tag, s, _)
    tok = call('POST', '/auth/login', {'email': e, 'password': P})[1]['token']
    if tag != 'limite': call('POST', '/users/me/profile', perfil, tok)
    if tag == 'retirada': assert call('POST', '/users/me/withdraw', None, tok)[0] == 200
print(out['nopart'], out['retirada'], out['limite'])
