const { k, db, log } = require('./lib');
(async () => {
  const { ctx, p } = await k.open('lucas');
  await k.waitText(p, 'Hola, Lucas', 20000);
  await k.tap(p, 'TREN SUPERIOR 41 MIN'); await p.waitForTimeout(2500);
  await p.mouse.move(195, 420); for (let i = 0; i < 30; i++) { await p.mouse.wheel(0, 700); await p.waitForTimeout(50); } await p.waitForTimeout(800);
  await k.tap(p, 'Finalizar sesión', { role: 'button' }); await p.waitForTimeout(1200);
  await k.tap(p, 'Esfuerzo percibido', { role: 'button' }); await p.waitForTimeout(600);
  await k.tap(p, '7', { role: 'menuitem', exact: true }); await p.waitForTimeout(400);
  await k.tap(p, 'Satisfacción', { role: 'button' }); await p.waitForTimeout(600);
  await k.tap(p, '4', { role: 'menuitem', exact: true }); await p.waitForTimeout(400);
  await k.fill(p, 'Minutos activos (opcional)', '38');
  await k.shot(p, 'C-finalizar-datos');
  await k.tap(p, 'Finalizar', { role: 'button', exact: true }); await p.waitForTimeout(2500);
  await k.dump(p, 'tras finalizar'); await k.shot(p, 'C-sesion-finalizada');
  log('sesión en BD:', db.q(`SELECT status||' %='||completion_percentage||' rpe='||coalesce(session_rpe::text,'-')||' sat='||coalesce(satisfaction::text,'-')||' min='||coalesce(active_minutes::text,'-')||' fin='||coalesce(ended_at::text,'-')||' adherencia='||counts_toward_adherence FROM workout_sessions WHERE session_id=1`));
  log('planned_workout:', db.q(`SELECT status FROM planned_workouts WHERE planned_workout_id=5`));
  await ctx.close(); process.exit(0);
})().catch(e => { console.log('ERROR', e.message); process.exit(1); });
