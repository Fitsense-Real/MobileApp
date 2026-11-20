const { k, db, log } = require('./lib');
const { execFileSync } = require('child_process');
const E = 'fin1@e2e.local';
const fondo = async p => { await p.mouse.move(195, 420); for (let i = 0; i < 40; i++) { await p.mouse.wheel(0, 700); await p.waitForTimeout(50); } await p.waitForTimeout(800); };
const arriba = async p => { await p.mouse.move(195, 420); for (let i = 0; i < 40; i++) { await p.mouse.wheel(0, -700); await p.waitForTimeout(50); } await p.waitForTimeout(800); };
const visibles = p => p.$$eval('flt-semantics[role=button]', ns => ns.filter(n => (n.textContent || '').trim() === 'Registrar ejercicio').map(n => { const b = n.getBoundingClientRect(); return [b.x + b.width / 2, b.y + b.height / 2]; }).filter(r => r[1] > 60 && r[1] < 800).sort((a, b) => a[1] - b[1]));
const dialogo = p => p.$$eval('flt-semantics[role=alertdialog]', ns => (ns[0]?.textContent || ''));
(async () => {
  const uid = db.q(`SELECT user_id FROM users WHERE email='${E}'`);
  let { ctx, p } = await k.open('diag');
  await k.waitText(p, 'Hola, Fina', 20000);
  // 1. Omitir el entrenamiento del sábado
  if (db.q(`SELECT status FROM planned_workouts WHERE planned_workout_id=2`) === 'SCHEDULED') {
    await k.tap(p, 'VER PLAN', { role: 'button' }); await p.waitForTimeout(2000);
    await k.tap(p, 'Tren inferior'); await p.waitForTimeout(2500); await fondo(p);
    await k.tap(p, 'Omitir entrenamiento', { role: 'button' }); await p.waitForTimeout(900);
    await k.tap(p, 'Fatiga'); await p.waitForTimeout(2500);
  }
  log('omitido:', db.q(`SELECT status||'/'||coalesce(skip_reason,'-') FROM planned_workouts WHERE planned_workout_id=2`));
  await ctx.close();
  // 2. Cierre semanal: la semana de fin1 se mueve 7 días atrás (solo en la base de pruebas) y se ejecuta el ciclo manual
  if (db.q(`SELECT count(*) FROM weekly_user_metrics WHERE user_id=${uid}`) === '0') {
    db.q(`UPDATE weekly_training_plans SET week_start_date=week_start_date-7, week_end_date=week_end_date-7, created_at=created_at-interval '7 days', activated_at=activated_at-interval '7 days' WHERE user_id=${uid}`);
    db.q(`UPDATE planned_workouts SET scheduled_date=scheduled_date-7, expires_at=expires_at-interval '7 days' WHERE plan_id IN (SELECT plan_id FROM weekly_training_plans WHERE user_id=${uid})`);
    db.q(`UPDATE workout_sessions SET started_at=started_at-interval '7 days', ended_at=ended_at-interval '7 days' WHERE user_id=${uid}`);
    db.q(`UPDATE users SET created_at=created_at-interval '7 days' WHERE user_id=${uid}`);
    db.q(`UPDATE user_profiles SET created_at=created_at-interval '7 days' WHERE user_id=${uid}`);
    const tok = JSON.parse(execFileSync('curl', ['-s', 'http://localhost:8080/api/v1/auth/login', '-H', 'Content-Type: application/json', '-d', JSON.stringify({ email: E, password: process.env.E2E_PASSWORD })]).toString()).token;
    log('ciclo:', execFileSync('curl', ['-s', '-X', 'POST', 'http://localhost:8080/api/v1/cycle/run-for-me', '-H', `Authorization: Bearer ${tok}`]).toString());
  }
  const m = db.q(`SELECT weighted_adherence_pct||'|'||risk_level||'|'||completed_workouts||'/'||scheduled_workouts||'|'||total_training_minutes FROM weekly_user_metrics WHERE user_id=${uid}`);
  log('métrica en BD (ponderada|riesgo|completos/programados|min):', m);
  log('intervención:', db.q(`SELECT adjustment_types::text||' '||left(message_shown,90) FROM user_interventions WHERE user_id=${uid}`));
  log('adaptación:', db.q(`SELECT decision||' '||status||' '||generation_source FROM plan_adaptation_attempts WHERE user_id=${uid}`));
  log('planes:', db.q(`SELECT string_agg(plan_id||' '||week_start_date||' '||status||' '||generation_source, ' | ' ORDER BY plan_id) FROM weekly_training_plans WHERE user_id=${uid}`));
  // 3. La app muestra la métrica del backend
  ({ ctx, p } = await k.open('diag'));
  await k.waitText(p, 'Hola, Fina', 20000); await p.waitForTimeout(1500); await k.shot(p, 'X-inicio-tras-ciclo');
  await k.tap(p, 'Progreso', { role: 'tab' }); await p.waitForTimeout(2500); await k.shot(p, 'X-progreso');
  const txt = (await k.tree(p)).map(x => x[1] + ' ' + x[2]).join(' ');
  const pct = (+m.split('|')[0]).toFixed(1);
  log(`Progreso muestra ${pct}%:`, txt.includes(pct + '%'), '· riesgo:', /Riesgo de abandono: \w+/.exec(txt)?.[0] ?? '(no visible)');
  await p.mouse.move(195, 420); await p.mouse.wheel(0, 1400); await p.waitForTimeout(900); await k.shot(p, 'X-progreso-ajuste');
  await k.tap(p, 'Inicio', { role: 'tab' }); await p.waitForTimeout(1500);
  // 4. Registro retroactivo («Ya lo hice») del entrenamiento de hoy del plan nuevo
  const [pw, nombre, min] = db.q(`SELECT pw.planned_workout_id||'|'||pw.workout_name||'|'||pw.expected_duration_minutes FROM planned_workouts pw JOIN weekly_training_plans w USING(plan_id) WHERE w.user_id=${uid} AND w.status='ACTIVE' AND pw.scheduled_date=current_date`).split('|');
  await k.tap(p, `${nombre.toUpperCase()} ${min} MIN`); await p.waitForTimeout(2500); await fondo(p);
  await k.tap(p, 'Ya lo hice · registrar entrenamiento', { role: 'button' }); await p.waitForTimeout(1000); await arriba(p);
  const hechos = new Set(); let sin = 0;
  while (sin < 5) {
    let nuevo = false;
    for (const [x, y] of await visibles(p)) {
      await p.mouse.click(x, y); await p.waitForTimeout(900);
      const n = (await dialogo(p)).split(/\d+ series/)[0].trim();
      if (!n || hechos.has(n)) { await k.tap(p, 'Cancelar', { role: 'button', exact: true }); await p.waitForTimeout(400); continue; }
      await k.tap(p, 'Lo completé', { role: 'button' }); await p.waitForTimeout(300);
      await k.tap(p, 'Usar resultado', { role: 'button', exact: true }); await p.waitForTimeout(900);
      hechos.add(n); nuevo = true; break;
    }
    if (!nuevo) { sin++; await p.mouse.move(195, 420); await p.mouse.wheel(0, 450); await p.waitForTimeout(700); } else sin = 0;
  }
  await fondo(p);
  await k.tap(p, 'Guardar entrenamiento', { role: 'button' }); await p.waitForTimeout(1200);
  await k.tap(p, 'Elegir fecha y hora del entrenamiento', { role: 'button' }); await p.waitForTimeout(1000);
  await k.tap(p, 'ACEPTAR', { role: 'button', exact: true }); await p.waitForTimeout(1000);
  await k.tap(p, 'ACEPTAR', { role: 'button', exact: true }); await p.waitForTimeout(1000);
  await k.tap(p, 'Esfuerzo percibido', { role: 'button' }); await p.waitForTimeout(600); await k.tap(p, '6', { role: 'menuitem', exact: true }); await p.waitForTimeout(400);
  await k.tap(p, 'Finalizar', { role: 'button', exact: true }); await p.waitForTimeout(2500); await k.shot(p, 'X-reporte-guardado');
  log(`retroactivo (${hechos.size} ejercicios):`, db.q(`SELECT s.status||' '||s.source||' %='||s.completion_percentage||' rpe='||s.session_rpe FROM workout_sessions s WHERE s.planned_workout_id=${pw}`));
  await ctx.close(); process.exit(0);
})().catch(e => { console.log('ERROR', e.message); process.exit(1); });
