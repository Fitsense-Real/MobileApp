# Prepara, en la base AISLADA fitsense_val2, dos cuentas sintéticas para la prueba en vivo de Mobile:
#  equivalentes: plan real del motor de reglas + semilla SQL declarada (4 prescripciones) para que una sesión
#                abierta contenga la variante equivalente (13 de 1054) y la precaución por ángulo (899 de 1138)
#                de dos ejercicios de otra sesión. Lo demás (omisión por dolor, derivación, bloqueo, 422) es real.
#  rechazo:      participante de 59 años (cumple 60 el 01/12/2026) con un ejercicio de alto impacto en una
#                sesión que se omite por dolor. Sin semilla si el plan ya lo trae.
import json, subprocess, sys, time, urllib.request
B = "http://localhost:8080/api/v1"; P = "Sintetica-o20-x9"; OUT = sys.argv[1]
def call(method, path, token=None, body=None):
    req = urllib.request.Request(B + path, method=method, data=None if body is None else json.dumps(body).encode(),
                                 headers={"Content-Type": "application/json", **({"Authorization": "Bearer " + token} if token else {})})
    try:
        with urllib.request.urlopen(req) as r:
            raw = r.read(); return r.status, (json.loads(raw) if raw else None)
    except urllib.error.HTTPError as e:
        raw = e.read(); return e.code, (json.loads(raw) if raw else None)
def sql(q):
    return subprocess.run(["psql", "-U", "postgres", "-h", "localhost", "-d", "fitsense_val2", "-v", "ON_ERROR_STOP=1", "-Atc", q],
                          env={"PGPASSWORD": "x", "PATH": "/usr/bin:/bin"}, check=True, capture_output=True, text=True).stdout.strip()
def account(tag, birth):
    email = f"o20cierre-{tag}-{time.time_ns()}@e2e.local"
    call("POST", "/auth/register", body={"email": email, "password": P, "firstName": "Sintetico", "timezone": "America/Lima", "acceptsStudyParticipation": True})
    t = call("POST", "/auth/login", body={"email": email, "password": P})[1]["token"]
    s, _ = call("POST", "/users/me/profile", t, {"birthDate": birth, "heightCm": 170, "currentWeightKg": 70, "fitnessLevel": "INTERMEDIATE",
        "goalType": "GENERAL_FITNESS", "goalText": "Sentirme mejor", "trainingLocation": "GYM", "daysPerWeek": 3, "availableDays": [1,2,3,4,5,6,7], "sessionMinutes": 45})
    assert s in (200, 201), s
    call("POST", "/users/me/plan/generation", t)
    for _ in range(40):
        s, plan = call("GET", "/users/me/plan/current", t)
        if s == 200: return email, t, plan
        time.sleep(1)
    raise SystemExit("sin plan")
state = {}
# --- equivalentes -------------------------------------------------------------------------------
email, t, plan = account("equivalentes", "1995-03-10")
w1, w2 = [w for w in plan["workouts"] if w["status"] == "SCHEDULED"][:2]
seed = [(w1["exercises"][0]["plannedExerciseId"], 1054), (w1["exercises"][1]["plannedExerciseId"], 1138),
        (w2["exercises"][0]["plannedExerciseId"], 13), (w2["exercises"][1]["plannedExerciseId"], 899)]
statements = [f"UPDATE planned_workout_exercises SET exercise_id = {x} WHERE planned_exercise_id = {pe};" for pe, x in seed]
sql(" ".join(statements))
state["equivalentes"] = {"email": email, "w1": w1["plannedWorkoutId"], "w2": w2["plannedWorkoutId"], "semilla": statements}
print("equivalentes:", email, "W1", w1["plannedWorkoutId"], "W2", w2["plannedWorkoutId"], "semilla:", " ".join(statements))
# --- rechazo por edad ---------------------------------------------------------------------------
for i in range(8):
    email, t, plan = account(f"rechazo{i}", "1966-12-01")
    impact = set(map(int, filter(None, sql("SELECT exercise_id FROM exercises WHERE high_impact").split("\n"))))
    open_ = [w for w in plan["workouts"] if w["status"] == "SCHEDULED"]
    target = next(((w, e) for w in open_ for e in w["exercises"] if e["exerciseId"] in impact), None)
    if target: break
else:
    raise SystemExit("ningún plan con alto impacto")
w, e = target
call("POST", f"/workouts/{w['plannedWorkoutId']}/skip", t, {"reason": "PAIN_OR_DISCOMFORT"})
state["rechazo"] = {"email": email, "workout": w["plannedWorkoutId"], "exerciseId": e["exerciseId"], "exerciseName": e["exerciseName"]}
print("rechazo:", email, "sesión", w["plannedWorkoutId"], "omitida por dolor; alto impacto", e["exerciseId"], e["exerciseName"], f"(intento {i})")
json.dump(state, open(OUT, "w"), ensure_ascii=False, indent=2)
