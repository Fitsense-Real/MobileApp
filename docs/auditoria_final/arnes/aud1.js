// Etapa 1: registro, perfil, generación (con recarga a mitad), recorrido y fidelidad del plan.
const A = require('./aud-lib'); const { k, db, check, shot } = A;
const registrar = require('./register'); const perfil = require('./profile');
const E = process.env.EMAIL; const N = process.env.NOMBRE || 'Audi';
let CTX = null;
(async () => {
  const { ctx, p } = await k.open('aud-' + E); CTX = ctx;
  await registrar(p, N, E);
  check('Registro', 'cuenta creada e inicio de sesión hasta el perfil', db.q(`SELECT count(*) FROM users WHERE email='${E}'`) === '1');
  process.env.P1 = './p1-ux.json'; await perfil(p);
  await p.mouse.move(195, 400); await p.mouse.wheel(0, 3000); await p.waitForTimeout(400);
  await k.tap(p, 'Continuar'); await p.waitForTimeout(1000);
  const paso5 = (await A.texts(p)).join(' | ');
  check('Onboarding', '5 pasos y sin «Ejercicios a evitar»', paso5.includes('Paso 5 de 5') && !/ejercicios a evitar/i.test(paso5));
  await p.mouse.wheel(0, 3000); await p.waitForTimeout(400);
  await k.tap(p, 'Generar mi plan', { role: 'button' }); const t0 = Date.now();
  await p.waitForTimeout(8000);
  check('Generación', '«Generando» visible a los ~8 s', (await A.texts(p)).join(' ').includes('Generando'));
  await shot(p, 'A1-generando');
  // Recuperación: la app se cierra a mitad (recarga) y retoma la misma operación, sin pedir otra.
  // Arranque en frío como en Android: la app vuelve a abrir desde el inicio (splash), no desde la ruta actual.
  await p.goto('http://localhost:5050/'); await k.semantics(p);
  const tour = await k.waitText(p, 'Soy Kapi', 45000);
  check('Generación', 'tras cerrar la app a mitad, retoma y llega al recorrido', tour, `${((Date.now() - t0) / 1000).toFixed(1)} s`);
  check('Generación', 'una sola operación de generación', db.q(`SELECT count(*) FROM plan_generation_operations o JOIN users u USING(user_id) WHERE u.email='${E}'`) === '1', db.op(E));
  await shot(p, 'A1-tour');
  await A.terminarTour(p);
  const listo = await k.waitText(p, 'Ver mi plan', 30000); await shot(p, 'A1-plan-listo');
  check('Generación', 'resultado «¡Tu primera rutina está lista!» con el plan real', listo && (await A.texts(p)).join(' ').includes('Semana del'));
  await k.tap(p, 'Ver mi plan', { role: 'button' });
  check('Inicio', 'dashboard con el nombre', await k.waitText(p, `Hola, ${N}`, 20000));
  // Fidelidad del plan: lo que el backend envía frente a lo que se ve en Rutinas.
  const plan = A.api(E, '/users/me/plan/current');
  const ws = plan.workouts || [];
  check('Plan', 'el backend devolvió un plan con entrenamientos', ws.length > 0, `${ws.length} entrenamientos, semana ${plan.weekStartDate}, fuente ${plan.generationSource}`);
  await k.tap(p, 'Rutinas', { role: 'tab' }); await p.waitForTimeout(2000); await shot(p, 'A1-rutinas');
  const rut = await A.allTexts(p, 25);
  for (const w of ws) {
    const ok = rut.includes(w.workoutName) && rut.includes(A.trainingDay(w.scheduledDate)) && rut.includes(A.STATUS[w.status] || w.status);
    check('Plan', `Rutinas muestra «${w.workoutName}», ${A.trainingDay(w.scheduledDate)}, ${A.STATUS[w.status]}`, ok);
  }
  // Rutina de hoy: ejercicios, series, repeticiones o segundos, descanso.
  const hoy = ws.find(w => w.scheduledDate === new Date().toISOString().slice(0, 10)) || ws[0];
  await k.tap(p, 'Inicio', { role: 'tab' }); await p.waitForTimeout(1500);
  await k.tap(p, 'Rutinas', { role: 'tab' }); await p.waitForTimeout(1500);
  // Los entrenamientos pueden llamarse igual: se abre la tarjeta por su fecha, que es única.
  await A.abrirRutina(p, hoy.scheduledDate, ws.map(w => w.scheduledDate)); await shot(p, 'A1-rutina-detalle');
  const det = await A.allTexts(p, 90);
  let bien = 0;
  // Un nombre largo se parte en dos líneas y la web lo expone en nodos separados: se compara sin espacios.
  const norm = t => t.replace(/[\s|]+/g, '');
  const detN = norm(det);
  for (const e of hoy.exercises || []) {
    const ok = detN.includes(norm(e.exerciseName)) && det.includes(A.prescription(e)) && (e.restSeconds == null || det.includes(`Descanso: ${e.restSeconds} s`));
    if (ok) bien++; else check('Plan', `ejercicio «${e.exerciseName}»: ${A.prescription(e)}`, false, `nombre=${detN.includes(norm(e.exerciseName))} prescripción=${det.includes(A.prescription(e))} descanso=${e.restSeconds == null || det.includes(`Descanso: ${e.restSeconds} s`)}`);
  }
  check('Plan', `detalle de «${hoy.workoutName}» (${hoy.scheduledDate}): nombre, series, reps/segundos y descanso de cada ejercicio`, bien === (hoy.exercises || []).length, `${bien}/${(hoy.exercises || []).length} ejercicios iguales al backend`);
  require('fs').writeFileSync(__dirname + '/aud-state.json', JSON.stringify({ E, N, hoy: hoy.plannedWorkoutId, hoyName: hoy.workoutName, plan: plan.planId }));
  A.save(__dirname + '/aud1.json'); await ctx.close();
})().catch(async e => { console.log('ERROR', e.message); A.save(__dirname + '/aud1.json'); await CTX?.close().catch(() => {}); process.exit(1); });
