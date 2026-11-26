# Busca, con cuentas sintéticas y el Backend real, una sesión abierta que quede bloqueada por una
# exclusión derivada (EQUIVALENT / PRECAUTION) de otra sesión omitida por dolor. Solo API pública.
import json, sys, time, urllib.request, itertools
B = "http://localhost:8080/api/v1"; P = "Sintetica-o20-x9"
def call(method, path, token=None, body=None):
    req = urllib.request.Request(B + path, method=method, data=None if body is None else json.dumps(body).encode(),
                                 headers={"Content-Type": "application/json", **({"Authorization": "Bearer " + token} if token else {})})
    try:
        with urllib.request.urlopen(req) as r:
            raw = r.read(); return r.status, (json.loads(raw) if raw else None)
    except urllib.error.HTTPError as e:
        raw = e.read(); return e.code, (json.loads(raw) if raw else None)
def account(tag, profile):
    email = f"o20busca-{tag}-{time.time_ns()}@e2e.local"
    call("POST", "/auth/register", body={"email": email, "password": P, "firstName": "Sintetico", "timezone": "America/Lima", "acceptsStudyParticipation": True})
    t = call("POST", "/auth/login", body={"email": email, "password": P})[1]["token"]
    call("POST", "/users/me/profile", t, profile); call("POST", "/users/me/plan/generation", t)
    for _ in range(40):
        s, plan = call("GET", "/users/me/plan/current", t)
        if s == 200: return email, t, plan
        time.sleep(1)
    return email, t, None
profiles = {
  "gym6": {"birthDate": "1995-03-10", "heightCm": 170, "currentWeightKg": 70, "fitnessLevel": "INTERMEDIATE", "goalType": "GAIN_MUSCLE", "goalText": "Ganar musculo", "trainingLocation": "GYM", "daysPerWeek": 6, "availableDays": [1,2,3,4,5,6,7], "sessionMinutes": 75},
  "gym5adv": {"birthDate": "1992-03-10", "heightCm": 175, "currentWeightKg": 75, "fitnessLevel": "ADVANCED", "goalType": "GAIN_MUSCLE", "goalText": "Ganar musculo", "trainingLocation": "GYM", "daysPerWeek": 5, "availableDays": [1,2,3,4,5,6,7], "sessionMinutes": 60},
  "home6": {"birthDate": "1995-03-10", "heightCm": 170, "currentWeightKg": 70, "fitnessLevel": "INTERMEDIATE", "goalType": "GENERAL_FITNESS", "goalText": "Sentirme mejor", "trainingLocation": "HOME", "daysPerWeek": 6, "availableDays": [1,2,3,4,5,6,7], "sessionMinutes": 60, "equipmentCodes": ["body weight", "dumbbell"]},
}
n = int(sys.argv[1]); hits = []
for i, name in zip(range(n), itertools.cycle(profiles)):
    email, t, plan = account(f"{name}{i}", profiles[name])
    if plan is None:
        print(f"{name}{i}: sin plan", flush=True); continue
    open_ = [w for w in plan["workouts"] if w["status"] in ("SCHEDULED", "IN_PROGRESS")]
    ids = {w["plannedWorkoutId"]: {e["exerciseId"] for e in w["exercises"]} for w in open_}
    # Session opened first on each candidate W2, pain on W1: try the pair with the most shared movement names.
    w1 = open_[0]
    call("POST", f"/workouts/{w1['plannedWorkoutId']}/skip", t, {"reason": "PAIN_OR_DISCOMFORT"})
    eff = call("GET", "/users/me/pain-exclusions/effective", t)[1]
    derived = {e["exerciseId"]: e for e in eff if e["origin"] != "DIRECT"}
    plan2 = call("GET", "/users/me/plan/current", t)[1]
    found = []
    for w in plan2["workouts"]:
        if w["plannedWorkoutId"] == w1["plannedWorkoutId"] or w["status"] not in ("SCHEDULED", "IN_PROGRESS"): continue
        for e in w["exercises"]:
            if e["exerciseId"] in derived:
                found.append((w["plannedWorkoutId"], e["plannedExerciseId"], e["exerciseId"], derived[e["exerciseId"]]["origin"], e.get("safetyBlockReason")))
    print(f"{name}{i}: {len(open_)} abiertos, {sum(len(v) for v in ids.values())} prescripciones, {len(derived)} derivadas; en rutinas abiertas: {found}", flush=True)
    if found: hits.append({"email": email, "found": found})
print(json.dumps(hits))
