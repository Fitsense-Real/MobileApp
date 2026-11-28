# Participante sintetico @audit.local con perfil y SIN plan (Backend LOCAL con documentos sinteticos).
import json, os, sys, time, urllib.request, urllib.error
B = sys.argv[1]; P = os.environ['AUDIT_PASSWORD']; e = f'audit-espera-{int(time.time())}@audit.local'
def call(m, p, b=None, t=None):
    r = urllib.request.Request(B + p, data=None if b is None else json.dumps(b).encode(), method=m); r.add_header('Content-Type', 'application/json')
    if t: r.add_header('Authorization', 'Bearer ' + t)
    with urllib.request.urlopen(r, timeout=30) as x: raw = x.read().decode(); return x.status, (json.loads(raw) if raw.strip() else None)
d = {x['type']: x['version'] for x in call('GET', '/legal-documents')[1]['documents']}
call('POST', '/auth/register', {'firstName': 'Espera', 'email': e, 'password': P, 'timezone': 'America/Lima', 'acceptsStudyParticipation': True,
  'acceptedTermsVersion': d['TERMS_OF_SERVICE'], 'acceptedPrivacyVersion': d['PRIVACY_POLICY'], 'acceptedStudyConsentVersion': d['STUDY_PARTICIPATION']})
t = call('POST', '/auth/login', {'email': e, 'password': P})[1]['token']
call('POST', '/users/me/profile', {'birthDate': '1990-05-05', 'heightCm': 170, 'currentWeightKg': 70, 'fitnessLevel': 'BEGINNER', 'goalType': 'GENERAL_FITNESS', 'goalText': 'Constancia', 'trainingLocation': 'HOME', 'daysPerWeek': 3, 'availableDays': [1, 3, 5], 'sessionMinutes': 45, 'equipmentCodes': ['body weight'], 'blockedExerciseIds': []}, t)
print(e)
