// Etapa 2: omitir, sesión del día (completo / parcial / no realizado), registro retroactivo,
// ciclo semanal (adherencia y adaptación), Progreso e historial. Solo base de pruebas y datos sintéticos.
const A = require('./aud-lib'); const { k, db, check, shot } = A;
const st = JSON.parse(require('fs').readFileSync(__dirname + '/aud-state.json'));
const E = st.E, N = st.N;
const uid = db.q(`SELECT user_id FROM users WHERE email='${E}'`);
const fondo = async p => { await p.mouse.move(195, 420); for (let i = 0; i < 40; i++) { await p.mouse.wheel(0, 700); await p.waitForTimeout(40); } await p.waitForTimeout(800); };
const arriba = async p => { await p.mouse.move(195, 420); for (let i = 0; i < 40; i++) { await p.mouse.wheel(0, -700); await p.waitForTimeout(40); } await p.waitForTimeout(800); };
const visibles = p => p.$$eval('flt-semantics[role=button]', ns => ns.filter(n => (n.textContent || '').trim() === 'Registrar ejercicio').map(n => { const b = n.getBoundingClientRect(); return [b.x + b.width / 2, b.y + b.height / 2]; }).filter(r => r[1] > 60 && r[1] < 800).sort((a, b) => a[1] - b[1]));
const dialogo = p => p.$$eval('flt-semantics[role=alertdialog]', ns => (ns[0]?.textContent || ''));
const shiftAll = days => {
  db.q(`UPDATE weekly_training_plans SET week_start_date=week_start_date+(${days}), week_end_date=week_end_date+(${days}), created_at=created_at+interval '${days} days', activated_at=activated_at+interval '${days} days' WHERE user_id=${uid}`);
  db.q(`UPDATE planned_workouts SET scheduled_date=scheduled_date+(${days}), expires_at=expires_at+interval '${days} days' WHERE plan_id IN (SELECT plan_id FROM weekly_training_plans WHERE user_id=${uid})`);
  db.q(`UPDATE workout_sessions SET started_at=started_at+interval '${days} days', ended_at=ended_at+interval '${days} days' WHERE user_id=${uid}`);
  db.q(`UPDATE users SET created_at=created_at+interval '${days} days' WHERE user_id=${uid}`);
  db.q(`UPDATE user_profiles SET created_at=created_at+interval '${days} days' WHERE user_id=${uid}`);
};
async function registrarEjercicios(p, modo) {
  const hechos = new Set(); let sin = 0;
  while (sin < 5) {
    let nuevo = false;
    for (const [x, y] of await visibles(p)) {
      await p.mouse.click(x, y); await p.waitForTimeout(900);
      const d = await dialogo(p); const nombre = d.split(/\d+ series/)[0].trim();
      if (!nombre || hechos.has(nombre)) { await k.tap(p, 'Cancelar', { role: 'button', exact: true }); await p.waitForTimeout(400); continue; }
      const n = hechos.size;
      if (modo === 'sesion' && n === 1) {
        await k.tap(p, 'Lo hice parcialmente', { role: 'checkbox' }); await p.waitForTimeout(300);
        await k.fill(p, 'Series realizadas', '1');
        const t = /\d+ s por serie/.test(d);
        await k.fill(p, t ? 'Duración total realizada (segundos, todas las series)' : 'Repeticiones totales (todas las series)', t ? '30' : '4');
        if (!(await dialogo(p)).includes('Fatiga')) { await k.tap(p, 'Motivo', { role: 'button', exact: true }); await p.waitForTimeout(500); await k.tap(p, 'Fatiga', { role: 'menuitem' }); }
      } else if (modo === 'sesion' && n === 2) {
        await k.tap(p, 'No lo hice', { role: 'checkbox' }); await p.waitForTimeout(300);
        await k.tap(p, 'Motivo', { role: 'button', exact: true }); await p.waitForTimeout(500); await k.tap(p, 'Falta de tiempo', { role: 'menuitem' });
      } else await k.tap(p, 'Lo completé', { role: 'checkbox' });
      await p.waitForTimeout(300);
      await k.tap(p, modo === 'sesion' ? 'Guardar' : 'Usar resultado', { role: 'button', exact: true }); await p.waitForTimeout(1300);
      if ((await dialogo(p)).length) throw new Error('el diálogo no se cerró: ' + (await dialogo(p)).slice(-160));
      hechos.add(nombre); nuevo = true; break;
    }
    if (!nuevo) { sin++; await p.mouse.move(195, 420); await p.mouse.wheel(0, 450); await p.waitForTimeout(700); } else sin = 0;
  }
  return hechos.size;
}
let CTX = null;
(async () => {
  let { ctx, p } = await k.open('aud-' + E); CTX = ctx;
  await k.waitText(p, `Hola, ${N}`, 20000);
  // 1. Omitir el entrenamiento del miércoles (futuro).
  const plan = A.api(E, '/users/me/plan/current'); const [w1, w2, w3] = [...plan.workouts].sort((a, b) => a.scheduledDate.localeCompare(b.scheduledDate));
  await k.tap(p, 'Rutinas', { role: 'tab' }); await p.waitForTimeout(1500);
  await A.abrirRutina(p, w2.scheduledDate, [w1, w2, w3].map(w => w.scheduledDate)); await fondo(p);
  await k.tap(p, 'Omitir entrenamiento', { role: 'button' }); await p.waitForTimeout(900); await shot(p, 'A2-omitir-motivos');
  await k.tap(p, 'Fatiga'); await p.waitForTimeout(2500);
  check('Rutinas', 'omitir un entrenamiento futuro con motivo', db.q(`SELECT status||'/'||coalesce(skip_reason,'-') FROM planned_workouts WHERE planned_workout_id=${w2.plannedWorkoutId}`) === 'SKIPPED/FATIGUE');
  await ctx.close();
  // 2. Sesión del lunes (sin mover fechas: la app y el backend permiten empezar un entrenamiento abierto y no vencido).
  ({ ctx, p } = await k.open('aud-' + E)); CTX = ctx;
  await k.waitText(p, `Hola, ${N}`, 20000); await p.waitForTimeout(1500);
  await k.tap(p, 'Rutinas', { role: 'tab' }); await p.waitForTimeout(1500);
  const rut = await A.allTexts(p, 20);
  check('Rutinas', 'el omitido se muestra «Omitido»', rut.includes(A.trainingDay(w2.scheduledDate)) && rut.includes('Omitido'));
  await A.abrirRutina(p, w1.scheduledDate, [w1, w2, w3].map(w => w.scheduledDate));
  await k.tap(p, 'Registrar ejercicio', { role: 'button' }); await p.waitForTimeout(1200);
  await k.tap(p, 'Comenzar sesión y registrar'); await p.waitForTimeout(2500);
  if ((await dialogo(p)).length) { await k.tap(p, 'Cancelar', { role: 'button', exact: true }); await p.waitForTimeout(500); }
  check('Sesión', 'iniciar la sesión del día', db.q(`SELECT status FROM workout_sessions WHERE planned_workout_id=${w1.plannedWorkoutId}`) === 'IN_PROGRESS');
  const n = await registrarEjercicios(p, 'sesion');
  const ej = db.q(`SELECT string_agg(r.status, ',' ORDER BY r.session_exercise_id) FROM workout_session_exercises r JOIN workout_sessions s USING(session_id) WHERE s.planned_workout_id=${w1.plannedWorkoutId}`);
  check('Sesión', `registrar ${n} ejercicios: completo, parcial (fatiga) y no realizado (falta de tiempo)`, /COMPLETED/.test(ej) && /PARTIAL/.test(ej) && /SKIPPED|NOT_PERFORMED/.test(ej), ej);
  await shot(p, 'A2-sesion-registrada');
  await fondo(p);
  await k.tap(p, 'Finalizar sesión', { role: 'button' }); await p.waitForTimeout(1200);
  await k.tap(p, 'Esfuerzo percibido', { role: 'button' }); await p.waitForTimeout(600); await k.tap(p, '7', { role: 'menuitem', exact: true }); await p.waitForTimeout(300);
  await k.tap(p, 'Satisfacción', { role: 'button' }); await p.waitForTimeout(600); await k.tap(p, '4', { role: 'menuitem', exact: true }); await p.waitForTimeout(300);
  await k.fill(p, 'Minutos activos (opcional)', '30');
  await k.tap(p, 'Finalizar', { role: 'button', exact: true }); await p.waitForTimeout(2500); await shot(p, 'A2-sesion-finalizada');
  const ses = db.q(`SELECT s.status||'|'||s.completion_percentage||'|'||s.session_rpe||'|'||s.satisfaction||'|'||s.active_minutes FROM workout_sessions s WHERE s.planned_workout_id=${w1.plannedWorkoutId}`);
  const pw = db.q(`SELECT status FROM planned_workouts WHERE planned_workout_id=${w1.plannedWorkoutId}`);
  check('Sesión', 'finalizar con esfuerzo 7, satisfacción 4 y 30 min (parcial: hubo un parcial y un no realizado)', /^PARTIAL\|[\d.]+\|7\|4\|30$/.test(ses) && pw === 'PARTIAL', `sesión ${ses}; entrenamiento ${pw}`);
  const pct = ses.split('|')[1];
  const det = await A.allTexts(p, 6);
  check('Sesión', `el detalle muestra el % que calculó el backend (${pct}%) y el estado «Parcial»`, det.includes(`${pct}% completado`) && det.includes('Parcial'));
  await shot(p, 'A2-sesion-detalle');
  await ctx.close();
  // 3. «Ya lo hice» del viernes (registro sin sesión en vivo). El backend acepta reportar un
  //    entrenamiento programado aunque su fecha no haya llegado (hallazgo B-5, documentado).
  ({ ctx, p } = await k.open('aud-' + E)); CTX = ctx;
  await k.waitText(p, `Hola, ${N}`, 20000);
  await k.tap(p, 'Rutinas', { role: 'tab' }); await p.waitForTimeout(1500);
  await A.abrirRutina(p, w3.scheduledDate, [w1, w2, w3].map(w => w.scheduledDate)); await fondo(p);
  await k.tap(p, 'Ya lo hice · registrar entrenamiento', { role: 'button' }); await p.waitForTimeout(1000); await arriba(p);
  const r = await registrarEjercicios(p, 'retro');
  await fondo(p);
  await k.tap(p, 'Guardar entrenamiento', { role: 'button' }); await p.waitForTimeout(1200);
  await k.tap(p, 'Elegir fecha y hora del entrenamiento', { role: 'button' }); await p.waitForTimeout(1000);
  await k.tap(p, 'ACEPTAR', { role: 'button', exact: true }); await p.waitForTimeout(1000);
  await k.tap(p, 'ACEPTAR', { role: 'button', exact: true }); await p.waitForTimeout(1000);
  await k.tap(p, 'Esfuerzo percibido', { role: 'button' }); await p.waitForTimeout(600); await k.tap(p, '6', { role: 'menuitem', exact: true }); await p.waitForTimeout(400);
  await k.tap(p, 'Finalizar', { role: 'button', exact: true }); await p.waitForTimeout(2500); await shot(p, 'A2-retroactivo');
  const retro = db.q(`SELECT s.status||' '||s.source||' %='||s.completion_percentage FROM workout_sessions s WHERE s.planned_workout_id=${w3.plannedWorkoutId}`);
  check('Sesión', `«Ya lo hice»: registro sin sesión en vivo (${r} ejercicios)`, /^COMPLETED USER_REPORTED/.test(retro), retro);
  await ctx.close();
  // La semana pasa a ser la de hace dos (solo base de pruebas): queda cerrada para el ciclo.
  shiftAll(-14);
  // 4. Cierre de semana: ciclo manual (solo pruebas).
  const ciclo = A.api(E, '/cycle/run-for-me', 'POST');
  check('Adherencia', 'ciclo semanal ejecutado', typeof ciclo === 'object', JSON.stringify(ciclo).slice(0, 160));
  const m = db.q(`SELECT weighted_adherence_pct||'|'||risk_level||'|'||completed_workouts||'/'||scheduled_workouts FROM weekly_user_metrics WHERE user_id=${uid}`);
  check('Adherencia', 'métrica semanal calculada por el backend', m.length > 0, `ponderada|riesgo|completos/programados = ${m}`);
  const adapt = db.q(`SELECT decision||' '||status||' '||generation_source FROM plan_adaptation_attempts WHERE user_id=${uid}`);
  const planes = db.q(`SELECT string_agg(plan_id||' '||week_start_date||' '||status||' '||generation_source, ' | ' ORDER BY plan_id) FROM weekly_training_plans WHERE user_id=${uid}`);
  check('Adaptación', 'intento de adaptación y plan de la semana siguiente', adapt.length > 0 && planes.split('|').length >= 2, `${adapt} · planes: ${planes}`);
  ({ ctx, p } = await k.open('aud-' + E)); CTX = ctx;
  await k.waitText(p, `Hola, ${N}`, 20000); await p.waitForTimeout(1500); await shot(p, 'A2-inicio-plan-nuevo');
  await k.tap(p, 'Progreso', { role: 'tab' }); await p.waitForTimeout(2500); await shot(p, 'A2-progreso');
  const prog = await A.allTexts(p, 12);
  const pct2 = (+m.split('|')[0]).toFixed(1).replace(/\.0$/, '');
  check('Adherencia', `Progreso muestra la adherencia del backend (${pct2}%)`, prog.includes(pct2 + '%'));
  check('Adaptación', 'Progreso resume el ajuste del plan', /RESUMEN DE AJUSTES|Resumen de ajustes/i.test(prog) && !prog.includes('Tu plan aún no tiene ajustes registrados'));
  await k.tap(p, 'Perfil', { role: 'tab' }); await p.waitForTimeout(1500);
  await k.tap(p, 'Historial de planes'); await p.waitForTimeout(2500); await shot(p, 'A2-historial');
  const hist = await A.allTexts(p, 10);
  const semanas = db.q(`SELECT string_agg(to_char(week_start_date,'DD/MM/YYYY'), ',' ORDER BY plan_id) FROM weekly_training_plans WHERE user_id=${uid}`).split(',');
  check('Historial', `historial con las ${semanas.length} semanas del backend`, semanas.every(s => hist.includes(s)), semanas.join(', '));
  A.save(__dirname + '/aud2.json'); await ctx.close();
})().catch(async e => { console.log('ERROR', e.message); A.save(__dirname + '/aud2.json'); await CTX?.close().catch(() => {}); process.exit(1); });
