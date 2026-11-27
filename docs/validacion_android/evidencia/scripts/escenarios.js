// Escenarios S01, S03–S09, S12 y S13 con la app Kora real (compilación web profile de generation 76dcf34)
// contra el Backend real 77b9df3 (base sintética fitsense_avs, IA apagada). Solo cuentas sintéticas.
// La red se corta con el modo sin conexión del navegador o interceptando una petición concreta; el Backend no se toca.
const { execFileSync } = require('child_process');
const fs = require('fs');
const k = require('./kora');
const B = 'http://localhost:8092/api/v1';
const PASS = 'Sintetica-av-x9';
const [A, Bcta] = fs.readFileSync(__dirname + '/cuentas.txt', 'utf8').trim().split('\n');
const log = (...a) => console.log(new Date().toISOString().slice(11, 19), ...a);
const results = [];
function check(id, what, ok, detail = '') { results.push({ id, what, ok: !!ok, detail }); log(`${ok ? 'OK  ' : 'FALLA'} [${id}] ${what}${detail ? ' — ' + detail : ''}`); }
function q(sql) { return execFileSync('psql', ['-h', 'localhost', '-U', 'postgres', '-d', 'fitsense_avs', '-At', '-F', '|', '-c', sql], { env: { ...process.env, PGPASSWORD: 'x' } }).toString().trim(); }
function token(email) { return JSON.parse(execFileSync('curl', ['-s', B + '/auth/login', '-H', 'Content-Type: application/json', '-d', JSON.stringify({ email, password: PASS })]).toString()).token; }
function api(email, path, method = 'GET', body) {
  const args = ['-s', '-X', method, B + path, '-H', 'Authorization: Bearer ' + token(email)];
  if (body) args.push('-H', 'Content-Type: application/json', '-d', JSON.stringify(body));
  const out = execFileSync('curl', args).toString(); try { return JSON.parse(out); } catch { return out; }
}
const data = r => (r && r.data !== undefined ? r.data : r);
const texts = async p => (await p.$$eval('flt-semantics', ns => ns.map(n => ((n.getAttribute('aria-label') || '') + ' ' + (n.textContent || '')).replace(/\s+/g, ' ').trim()).filter(Boolean))).join(' | ');
const shot = (p, n) => p.screenshot({ path: __dirname + '/shots/' + n + '.png' });
const DAYS = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];
const short = iso => { const [y, m, d] = iso.split('-').map(Number); const dt = new Date(Date.UTC(y, m - 1, d)); return `${DAYS[(dt.getUTCDay() + 6) % 7]} ${String(d).padStart(2, '0')}/${String(m).padStart(2, '0')}`; };

// Peticiones del navegador al Backend, por método y ruta.
function watch(p) {
  const seen = [];
  p.on('request', r => { if (r.url().startsWith(B)) seen.push({ m: r.method(), path: r.url().slice(B.length), t: Date.now() }); });
  return seen;
}
const puts = (seen, pe) => seen.filter(r => r.m === 'PUT' && r.path.endsWith('/exercises/' + pe)).length;

async function login(p, email) {
  if (!(await k.waitText(p, 'INICIAR SESIÓN', 3000))) { await k.waitText(p, 'COMENZAR AHORA', 20000); await k.tap(p, 'INICIA SESIÓN', { role: 'button' }); await k.waitText(p, 'INICIAR SESIÓN', 15000); }
  await k.fill(p, 'Correo', email); await k.fill(p, 'Contraseña', PASS); await k.tap(p, 'INICIAR SESIÓN');
  if (!await k.waitText(p, 'Hola, Sintetico', 20000)) throw new Error('no entró a Inicio');
  await p.waitForTimeout(1500);
}
async function alFinal(p) { await p.mouse.move(195, 420); for (let i = 0; i < 25; i++) { await p.mouse.wheel(0, 800); } await p.waitForTimeout(800); }
async function alInicio(p) { await p.mouse.move(195, 420); for (let i = 0; i < 25; i++) { await p.mouse.wheel(0, -800); } await p.waitForTimeout(800); }
/** Todos los textos de la pantalla, recorriéndola entera (la lista solo expone lo visible). */
async function todo(p) {
  const seen = new Set(); await alInicio(p);
  for (let i = 0; i < 30; i++) { for (const t of (await texts(p)).split(' | ')) seen.add(t); await p.mouse.wheel(0, 350); await p.waitForTimeout(200); }
  await alInicio(p); return [...seen].join(' | ');
}
async function logout(p) {
  for (let i = 0; i < 3 && !(await k.waitText(p, 'Perfil', 800)); i++) { await alInicio(p); await k.tap(p, 'Volver').catch(() => {}); await p.waitForTimeout(1500); }
  await k.tap(p, 'Perfil', { role: 'tab' }); await p.waitForTimeout(1500);
  await k.tap(p, 'Cerrar sesión'); await p.waitForTimeout(800);
  if (await k.waitText(p, 'Cerrar sesión', 1500)) { await k.tap(p, 'Cerrar sesión', { role: 'button' }).catch(() => {}); }
  await k.waitText(p, 'INICIAR SESIÓN', 15000);
}
/** Abre desde Rutinas el entrenamiento de esa fecha (las tarjetas siguen el orden de fechas del plan). */
async function abrir(p, iso, fechas) {
  await k.tap(p, 'Rutinas', { role: 'tab' }); await p.waitForTimeout(2000);
  const idx = [...fechas].sort().indexOf(iso);
  await p.mouse.move(195, 420); for (let i = 0; i < 20; i++) await p.mouse.wheel(0, -800); await p.waitForTimeout(400);
  for (let i = 0; i < 40; i++) {
    const c = (await p.$$eval('flt-semantics', ns => ns.filter(n => n.hasAttribute('flt-tappable') && /\d+ MIN\s/.test(n.getAttribute('aria-label') || '')).map(n => { const b = n.getBoundingClientRect(); return [b.y, b.height]; }))).sort((a, b) => a[0] - b[0]);
    const vh = p.viewportSize().height;
    if (c.length > idx && c[idx][0] > 80 && c[idx][0] + c[idx][1] < vh - 80) { await p.mouse.click(150, c[idx][0] + c[idx][1] / 2); await p.waitForTimeout(2500); break; }
    await p.mouse.move(195, 420); await p.mouse.wheel(0, 200); await p.waitForTimeout(300);
  }
  const t = await todo(p);
  if (!t.includes(short(iso))) { await shot(p, 'X-abrir'); throw new Error('no se abrió el entrenamiento del ' + short(iso)); }
}
/** «Registrar ejercicio» del ejercicio con ese nombre → «Lo completé» → Guardar. */
async function registrar(p, nombre, outcome = 'Lo completé') {
  await p.mouse.move(195, 420); for (let i = 0; i < 20; i++) await p.mouse.wheel(0, -800); await p.waitForTimeout(300);
  for (let i = 0; i < 60; i++) {
    const pos = await p.$$eval('flt-semantics', (ns, nombre) => {
      const head = ns.filter(n => (n.getAttribute('aria-label') || '').trim().startsWith(nombre) || (n.textContent || '').trim().startsWith(nombre)).map(n => n.getBoundingClientRect().y)[0];
      if (head === undefined) return null;
      const btn = ns.filter(n => n.getAttribute('role') === 'button' && /Registrar ejercicio/.test((n.getAttribute('aria-label') || '') + (n.textContent || '')))
        .map(n => n.getBoundingClientRect()).filter(b => b.y > head).sort((a, b) => a.y - b.y)[0];
      return btn ? [btn.x + btn.width / 2, btn.y + btn.height / 2, head] : null;
    }, nombre);
    const vh = p.viewportSize().height;
    if (pos && pos[1] > 60 && pos[1] < vh - 60) { await p.mouse.click(pos[0], pos[1]); break; }
    await p.mouse.move(195, 420); await p.mouse.wheel(0, 250); await p.waitForTimeout(300);
  }
  await p.waitForTimeout(1000);
  await k.tap(p, outcome); await p.waitForTimeout(400);
  if (outcome === 'No lo hice') { await k.tap(p, 'Motivo'); await p.waitForTimeout(700); await k.tap(p, 'Fatiga'); await p.waitForTimeout(500); }
  await k.tap(p, 'Guardar', { role: 'button' }); await p.waitForTimeout(3500);
}
const row = (session, pe) => q(`select status||':'||coalesce(actual_sets,0)||':'||coalesce(actual_reps_total,0)||':'||coalesce(actual_duration_seconds,0) from workout_session_exercises where session_id=${session} and planned_exercise_id=${pe}`);
const rows = (session, pe) => +q(`select count(*) from workout_session_exercises where session_id=${session} and planned_exercise_id=${pe}`);

(async () => {
  // Plan de A (por la API, solo para elegir los ejercicios y comprobar en la base).
  const plan = data(api(A, '/users/me/plan/current'));
  const workouts = plan.workouts.slice().sort((a, b) => a.scheduledDate.localeCompare(b.scheduledDate));
  const fechas = workouts.map(w => w.scheduledDate);
  const W1 = workouts[0];
  // Un ejercicio de W1 que también esté en otra rutina: lo bloqueará el dolor registrado en esa otra (S06/S07).
  const otra = workouts.slice(1).find(w => w.exercises.some(e => W1.exercises.some(x => x.exerciseId === e.exerciseId)));
  const compartido = W1.exercises.find(e => otra && otra.exercises.some(x => x.exerciseId === e.exerciseId));
  const libres = W1.exercises.filter(e => e !== compartido);
  const [e1, e2, e3] = libres;
  log(`cuenta A ${A}: plan ${plan.planId}, rutina ${W1.plannedWorkoutId} (${W1.scheduledDate}) con ${W1.exercises.length} ejercicios; compartido con ${otra?.plannedWorkoutId}: ${compartido?.exerciseName}`);
  if (!compartido || libres.length < 3) throw new Error('el plan no permite los escenarios (sin ejercicio compartido o con pocos ejercicios)');

  const perfil = 'escenarios-' + Date.now();
  let { ctx, p } = await k.open(perfil);
  let seen = watch(p);
  await login(p, A);
  await abrir(p, W1.scheduledDate, fechas);
  await alFinal(p); await k.tap(p, 'Comenzar entrenamiento', { role: 'button' }); await p.waitForTimeout(3000);
  const session = +q(`select session_id from workout_sessions where planned_workout_id=${W1.plannedWorkoutId} and status='IN_PROGRESS'`);
  check('S01', 'Comenzar entrenamiento abre la sesión en el Backend', session > 0, `sesión ${session}`);

  // S01 · registro con conexión.
  await registrar(p, e1.exerciseName);
  check('S01', `«Lo completé» en ${e1.exerciseName} llega al Backend una vez`, rows(session, e1.plannedExerciseId) === 1 && puts(seen, e1.plannedExerciseId) === 1, row(session, e1.plannedExerciseId));

  // S03 · sin conexión: queda pendiente y no se envía.
  await ctx.setOffline(true);
  await registrar(p, e2.exerciseName);
  let t = await todo(p);
  await shot(p, 'S03-sin-conexion');
  check('S03', 'Sin conexión: aviso y «Pendiente de enviar»; nada llega al Backend', t.includes('Pendiente de enviar') && rows(session, e2.plannedExerciseId) === 0 && puts(seen, e2.plannedExerciseId) === 0,
    (t.match(/No pudimos confirmar[^|]{0,90}/) || ['sin aviso'])[0]);

  // S04 · P1: se cierra la app y se vuelve a abrir (mismo navegador, como el mismo teléfono).
  await ctx.close();
  ({ ctx, p } = await k.open(perfil)); seen = watch(p);
  if (!await k.waitText(p, 'Hola, Sintetico', 20000)) throw new Error('la sesión no se mantuvo al reabrir');
  await abrir(p, W1.scheduledDate, fechas); await p.waitForTimeout(2000);
  t = await todo(p);
  await shot(p, 'S04-reabrir');
  check('S04', 'Al reabrir, el resultado sigue «Pendiente de enviar» y no se envía solo', t.includes('Pendiente de enviar') && puts(seen, e2.plannedExerciseId) === 0 && rows(session, e2.plannedExerciseId) === 0);

  // S05 · reintento con conexión: una sola vez.
  await alInicio(p); await k.tap(p, 'Reintentar envío', { role: 'button' }); await p.waitForTimeout(4000);
  t = await todo(p);
  check('S05', '«Reintentar envío» confirma la rutina y envía una sola vez', puts(seen, e2.plannedExerciseId) === 1 && rows(session, e2.plannedExerciseId) === 1 && !t.includes('Pendiente de enviar'),
    `PUT=${puts(seen, e2.plannedExerciseId)} fila=${row(session, e2.plannedExerciseId)}; antes del PUT: ${seen.filter(r => r.m === 'GET').map(r => r.path).filter(x => /plan\/current|sessions\/current/.test(x)).slice(-3).join(', ')}`);

  // S08 · respuesta perdida: el PUT llega al Backend pero la respuesta no llega al teléfono.
  let cortar = true;
  await p.route(`**/exercises/${e3.plannedExerciseId}`, async route => {
    if (route.request().method() === 'PUT' && cortar) { cortar = false; await route.fetch(); await route.abort('connectionreset'); } else await route.continue();
  });
  await registrar(p, e3.exerciseName);
  t = await todo(p);
  await shot(p, 'S08-respuesta-perdida');
  const llego = rows(session, e3.plannedExerciseId);
  check('S08', 'Respuesta perdida: el Backend lo guardó y la app lo marca para comprobar antes de repetir', llego === 1 && t.includes('Se perdió la conexión'), `fila=${row(session, e3.plannedExerciseId)}`);
  const putsAntes = puts(seen, e3.plannedExerciseId);
  await alInicio(p); await k.tap(p, 'Reintentar envío', { role: 'button' }); await p.waitForTimeout(4000);
  t = await todo(p);
  check('S08', 'Al reintentar consulta la sesión, ve que ya llegó y no repite el PUT', puts(seen, e3.plannedExerciseId) === putsAntes && rows(session, e3.plannedExerciseId) === 1 && !t.includes('Pendiente de enviar'),
    `PUT antes=${putsAntes} después=${puts(seen, e3.plannedExerciseId)}; GET /sessions/current=${seen.filter(r => r.path === '/sessions/current').length}`);
  await p.unroute(`**/exercises/${e3.plannedExerciseId}`);

  // S13 + S06/S07 · pendiente guardado, app cerrada, nueva exclusión O20 desde «otro dispositivo», reabrir.
  await ctx.setOffline(true);
  await registrar(p, compartido.exerciseName);
  t = await todo(p);
  check('S13', `Sin conexión, ${compartido.exerciseName} queda pendiente`, t.includes('Pendiente de enviar') && rows(session, compartido.plannedExerciseId) === 0);
  await ctx.close();
  const skip = api(A, `/workouts/${otra.plannedWorkoutId}/skip`, 'POST', { reason: 'PAIN_OR_DISCOMFORT' });
  log(`otro dispositivo: omitir ${otra.plannedWorkoutId} por dolor → ${JSON.stringify(skip).slice(0, 120)}`);
  ({ ctx, p } = await k.open(perfil)); seen = watch(p);
  await k.waitText(p, 'Hola, Sintetico', 20000);
  await abrir(p, W1.scheduledDate, fechas); await p.waitForTimeout(2500);
  t = await todo(p);
  await shot(p, 'S13-retenido');
  check('S06', 'La nueva exclusión O20 llega a la rutina abierta: el ejercicio aparece «No disponible por ahora»', t.includes('No disponible por ahora'));
  check('S07', 'El pendiente incompatible pasa a «Retenido: no se enviará» y no se envía', t.includes('Retenido: no se enviará') && puts(seen, compartido.plannedExerciseId) === 0 && rows(session, compartido.plannedExerciseId) === 0);

  // S09 · cambio de cuenta: B no ve nada de A; al volver, A lo recupera.
  await logout(p);
  await login(p, Bcta);
  const planB = data(api(Bcta, '/users/me/plan/current'));
  const wB = planB.workouts.slice().sort((a, b) => a.scheduledDate.localeCompare(b.scheduledDate));
  await abrir(p, wB[0].scheduledDate, wB.map(w => w.scheduledDate));
  t = await todo(p);
  check('S09', 'Otra cuenta en el mismo teléfono no ve pendientes ni retenidos de A', !t.includes('Retenido') && !t.includes('Pendiente de enviar') && !t.includes('Resultados retenidos'));
  await logout(p);
  await login(p, A);
  await abrir(p, W1.scheduledDate, fechas); await p.waitForTimeout(2000);
  t = await todo(p);
  check('S09', 'De vuelta en A (dentro de 48 h), su retenido reaparece', t.includes('Retenido: no se enviará'));

  // Descartar el retenido (no se envía nada) y terminar la sesión: S01 completo.
  await alInicio(p); await k.tap(p, 'Descartar', { role: 'button' }); await p.waitForTimeout(1500);
  t = await todo(p);
  check('S07', '«Descartar» quita el retenido sin enviarlo', !t.includes('Retenido: no se enviará') && rows(session, compartido.plannedExerciseId) === 0 && puts(seen, compartido.plannedExerciseId) === 0);
  for (const e of W1.exercises.filter(x => ![e1, e2, e3].includes(x))) await registrar(p, e.exerciseName, e === compartido ? 'No lo hice' : 'Lo completé');
  t = await todo(p);
  check('S01', 'Todos los ejercicios registrados (el bloqueado solo como «No lo hice»)', !t.includes('Sin registrar') && rows(session, compartido.plannedExerciseId) === 1 && row(session, compartido.plannedExerciseId).includes(':0:0:0'), row(session, compartido.plannedExerciseId));
  await alFinal(p); await k.tap(p, 'Finalizar sesión', { role: 'button' }); await p.waitForTimeout(1500);
  await k.tap(p, 'Esfuerzo percibido'); await p.waitForTimeout(700); await k.tap(p, '6', { exact: true }); await p.waitForTimeout(500);
  await k.tap(p, 'Finalizar', { role: 'button', exact: true }); await p.waitForTimeout(4000);
  const fin = q(`select status||' '||coalesce(round(completion_percentage)::text,'-')||' %' from workout_sessions where session_id=${session}`);
  const filas = q(`select count(*) from workout_session_exercises where session_id=${session}`);
  await shot(p, 'S01-finalizada');
  check('S01', 'Finalizar sesión: el Backend la cierra con un registro por ejercicio, sin duplicados', /^(COMPLETED|PARTIAL)/.test(fin) && +filas === W1.exercises.length, `${fin}; ${filas} filas para ${W1.exercises.length} ejercicios`);

  // S12 · 401: el token deja de valer en el Backend (token_version, como al cambiar la contraseña).
  q(`update users set token_version = token_version + 1 where email='${A}'`);
  await k.tap(p, 'Progreso', { role: 'tab' }).catch(() => {}); await p.waitForTimeout(1500);
  await k.tap(p, 'Inicio', { role: 'tab' }).catch(() => {}); await p.waitForTimeout(3000);
  t = await todo(p);
  await shot(p, 'S12-401');
  const r401 = seen.filter(r => r.t > Date.now() - 6000).length;
  check('S12', '401: la app vuelve al inicio de sesión sin quedarse en un estado roto', t.includes('INICIAR SESIÓN') || t.includes('COMENZAR AHORA') || t.includes('INICIA SESIÓN'), (t.match(/[^|]{0,60}(sesión expir|vuelve a iniciar)[^|]{0,60}/i) || [''])[0] + ` (${r401} peticiones)`);

  await ctx.close();
  fs.writeFileSync(__dirname + '/resultados.json', JSON.stringify(results, null, 1));
  log(`${results.filter(r => r.ok).length}/${results.length} comprobaciones superadas`);
  process.exit(results.every(r => r.ok) ? 0 : 1);
})().catch(e => { console.log('ERROR', e.message); fs.writeFileSync(__dirname + '/resultados.json', JSON.stringify(results, null, 1)); process.exit(2); });
