# Crea tres cuentas sinteticas @audit.local con perfil y sin plan (prueba en vivo push_generation). Backend LOCAL; contrasena por AUDIT_PASSWORD.
import json, sys, time, os, urllib.request, urllib.error
BASE=sys.argv[1]; PWD=os.environ['AUDIT_PASSWORD']; T=str(int(time.time()))
def call(m,p,b=None,t=None):
    r=urllib.request.Request(BASE+p,data=None if b is None else json.dumps(b).encode(),method=m); r.add_header('Content-Type','application/json')
    if t: r.add_header('Authorization','Bearer '+t)
    try:
        with urllib.request.urlopen(r,timeout=30) as x: raw=x.read().decode(); return x.status,(json.loads(raw) if raw.strip() else None)
    except urllib.error.HTTPError as e: return e.code,e.read().decode()
out=[]
for tag in 'abc':
    e=f'audit-push-{tag}-{T}@audit.local'; out.append(e)
    call('POST','/auth/register',{'firstName':'Auditoria','email':e,'password':PWD,'timezone':'America/Lima','acceptsStudyParticipation':True})
    tok=call('POST','/auth/login',{'email':e,'password':PWD})[1]['token']
    s,_=call('POST','/users/me/profile',{'birthDate':'1990-05-05','heightCm':170,'currentWeightKg':70,'fitnessLevel':'BEGINNER','goalType':'GENERAL_FITNESS','goalText':'Constancia','trainingLocation':'HOME','daysPerWeek':3,'availableDays':[1,3,5],'sessionMinutes':45,'equipmentCodes':['body weight'],'blockedExerciseIds':[]},tok)
print(' '.join(out))
