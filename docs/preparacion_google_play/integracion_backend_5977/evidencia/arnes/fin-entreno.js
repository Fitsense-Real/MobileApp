// Recorrido esencial sobre el Mobile integrado: registro, perfil, generación, tour, plan,
// sesión de hoy (completo, parcial, no realizado), esfuerzo y omitir otro entrenamiento.
const { k, db, nuevo, terminarTour, log } = require('./lib');
const E = 'fin1@e2e.local';
async function visibles(p) {
  return p.$$eval('flt-semantics[role=button]', ns => ns.filter(n => (n.textContent || '').trim() === 'Registrar ejercicio')
    .map(n => { const b = n.getBoundingClientRect(); return [b.x + b.width / 2, b.y + b.height / 2]; }).filter(r => r[1] > 60 && r[1] < 800).sort((a, b) => a[1] - b[1]));
}
const dialogo = p => p.$$eval('flt-semantics[role=alertdialog]', ns => (ns[0]?.textContent || ''));
const fondo = async p => { await p.mouse.move(195, 420); for (let i = 0; i < 40; i++) { await p.mouse.wheel(0, 700); await p.waitForTimeout(50); } await p.waitForTimeout(800); };
(async () => {
  let ctx, p;
  const perfil = require('./profile');
  if (db.q(`SELECT count(*) FROM user_profiles f JOIN users u USING(user_id) WHERE u.email='${E}'`) === '0') {
    ({ ctx, p } = await k.open('diag'));
    await k.waitText(p, 'Paso 1 de 5', 15000); await perfil(p);
    await k.tap(p, 'Generar mi plan');
    if (!await k.waitText(p, 'Soy Kapi', 20000)) throw new Error('no aparecio el tour');
    await k.shot(p, 'X-tour'); await terminarTour(p);
    if (await k.waitText(p, 'Ver mi plan', 30000)) { await k.shot(p, 'X-plan-listo'); await k.tap(p, 'Ver mi plan', { role: 'button' }); }
  } else ({ ctx, p } = await k.open('diag'));
  if (await k.waitText(p, 'de 10', 5000)) { log('tour retomado donde quedó'); await terminarTour(p); if (await k.waitText(p, 'Ver mi plan', 20000)) await k.tap(p, 'Ver mi plan', { role: 'button' }); }
  await k.waitText(p, 'Hola, Fina', 30000); await p.waitForTimeout(1500);
  log('generación:', db.q(`SELECT o.status||' plan='||coalesce(o.plan_id::text,'-') FROM plan_generation_operations o JOIN users u USING(user_id) WHERE u.email='${E}'`));
  log('plan:', db.q(`SELECT string_agg(pw.planned_workout_id||' '||pw.scheduled_date||' '||pw.workout_name||' '||pw.status, ' | ' ORDER BY pw.scheduled_date) FROM planned_workouts pw JOIN weekly_training_plans w USING(plan_id) JOIN users u USING(user_id) WHERE u.email='${E}'`));
  await k.shot(p, 'X-inicio');
  // Rutina de hoy
  const [nombre, min] = db.q(`SELECT pw.workout_name||'|'||pw.expected_duration_minutes FROM planned_workouts pw JOIN weekly_training_plans w USING(plan_id) JOIN users u USING(user_id) WHERE u.email='${E}' AND pw.scheduled_date=current_date`).split('|');
  const hoy = `${nombre.toUpperCase()} ${min} MIN`; log('rutina de hoy:', hoy);
  await k.tap(p, hoy); await p.waitForTimeout(2500);
  if (db.q(`SELECT count(*) FROM workout_sessions s JOIN users u USING(user_id) WHERE u.email='${E}'`) === '0') {
    await k.tap(p, 'Registrar ejercicio', { role: 'button' }); await p.waitForTimeout(1200);
    await k.tap(p, 'Comenzar sesión y registrar'); await p.waitForTimeout(2500);
  }
  if ((await dialogo(p)).length) { await k.tap(p, 'Cancelar', { role: 'button', exact: true }); await p.waitForTimeout(500); }
  log('sesión:', db.q(`SELECT s.status FROM workout_sessions s JOIN users u USING(user_id) WHERE u.email='${E}'`));
  const hechos = new Set(); let sin = 0;
  while (sin < 4) {
    let nuevoEj = false;
    for (const [x, y] of await visibles(p)) {
      await p.mouse.click(x, y); await p.waitForTimeout(900);
      const d = await dialogo(p); const nombre = d.split(/\d+ series/)[0].trim();
      if (!nombre || hechos.has(nombre)) { await k.tap(p, 'Cancelar', { role: 'button', exact: true }); await p.waitForTimeout(400); continue; }
      const n = hechos.size;
      if (n === 1) {
        await k.tap(p, 'Lo hice parcialmente', { role: 'button' }); await p.waitForTimeout(300);
        await k.fill(p, 'Series realizadas', '1');
        const tiempo = /\d+ s por serie/.test(d);
        await k.fill(p, tiempo ? 'Duración total realizada (segundos, todas las series)' : 'Repeticiones totales (todas las series)', tiempo ? '30' : '4');
        if (!(await dialogo(p)).includes('Fatiga')) { await k.tap(p, 'Motivo', { role: 'button', exact: true }); await p.waitForTimeout(500); await k.tap(p, 'Fatiga', { role: 'menuitem' }); }
      } else if (n === 2) {
        await k.tap(p, 'No lo hice', { role: 'button' }); await p.waitForTimeout(300);
        await k.tap(p, 'Motivo', { role: 'button', exact: true }); await p.waitForTimeout(500); await k.tap(p, 'Falta de tiempo', { role: 'menuitem' });
      } else { await k.tap(p, 'Lo completé', { role: 'button' }); }
      await p.waitForTimeout(300);
      await k.tap(p, 'Guardar', { role: 'button', exact: true }); await p.waitForTimeout(1300);
      if ((await dialogo(p)).length) { await k.shot(p, 'X-dialogo-abierto'); const v = await p.$$eval('input', ns => ns.map(n => (n.getAttribute('aria-label')||'') + '=' + n.value)); log('DIÁLOGO SIGUE ABIERTO', JSON.stringify(v), (await dialogo(p)).slice(-200)); throw new Error('no se guardó'); }
      hechos.add(nombre); log(`${hechos.size}. ${nombre}`); nuevoEj = true; break;
    }
    if (!nuevoEj) { sin++; await p.mouse.move(195, 420); await p.mouse.wheel(0, 450); await p.waitForTimeout(700); } else sin = 0;
  }
  log('ejercicios:', db.q(`SELECT string_agg(r.status||coalesce('/'||r.skip_reason,'')||' '||r.completion_percentage, ', ' ORDER BY r.session_exercise_id) FROM workout_session_exercises r JOIN workout_sessions s USING(session_id) JOIN users u USING(user_id) WHERE u.email='${E}'`));
  await fondo(p);
  await k.tap(p, 'Finalizar sesión', { role: 'button' }); await p.waitForTimeout(1200);
  await k.tap(p, 'Esfuerzo percibido', { role: 'button' }); await p.waitForTimeout(600); await k.tap(p, '7', { role: 'menuitem', exact: true }); await p.waitForTimeout(300);
  await k.tap(p, 'Satisfacción', { role: 'button' }); await p.waitForTimeout(600); await k.tap(p, '4', { role: 'menuitem', exact: true }); await p.waitForTimeout(300);
  await k.fill(p, 'Minutos activos (opcional)', '30');
  await k.tap(p, 'Finalizar', { role: 'button', exact: true }); await p.waitForTimeout(2500);
  await k.shot(p, 'X-sesion-finalizada');
  log('sesión final:', db.q(`SELECT s.status||' %='||s.completion_percentage||' rpe='||s.session_rpe||' sat='||s.satisfaction||' min='||s.active_minutes FROM workout_sessions s JOIN users u USING(user_id) WHERE u.email='${E}'`));
  await ctx.close(); process.exit(0);
})().catch(e => { console.log('ERROR', e.message); process.exit(1); });
