// Omite «Tren inferior» (falta de tiempo, algo puntual) y luego lo registra como hecho («Ya lo hice»).
const { k, db, log } = require('./lib');
const W = `planned_workout_id=6`;
(async () => {
  const { ctx, p } = await k.open('lucas');
  await k.waitText(p, 'Hola, Lucas', 20000);
  await k.tap(p, 'VER PLAN', { role: 'button' }); await p.waitForTimeout(2000); await k.dump(p, 'plan'); await k.shot(p, 'C-plan-semana'); await k.tap(p, 'Tren inferior'); await p.waitForTimeout(2500);
  await k.shot(p, 'C-tren-inferior'); await p.mouse.move(195, 420); for (let i = 0; i < 40; i++) { await p.mouse.wheel(0, 700); await p.waitForTimeout(50); } await p.waitForTimeout(800); await k.dump(p, 'fondo'); await k.shot(p, 'C-tren-inferior-fondo');
  await k.tap(p, 'Omitir entrenamiento', { role: 'button' }); await p.waitForTimeout(900);
  await k.dump(p, 'motivos'); await k.shot(p, 'C-omitir-motivos');
  await k.tap(p, 'Falta de tiempo'); await p.waitForTimeout(900);
  await k.dump(p, 'contexto');
  await k.tap(p, 'Fue algo puntual'); await p.waitForTimeout(400);
  await k.shot(p, 'C-omitir-contexto');
  await k.tap(p, 'Continuar', { role: 'button', exact: true }); await p.waitForTimeout(2500);
  log('tras omitir:', db.q(`SELECT status||'/'||coalesce(skip_reason,'-')||' ctx='||coalesce(lack_of_time_context,'-') FROM planned_workouts WHERE ${W}`));
  await k.dump(p, 'omitido'); await k.shot(p, 'C-omitido');
  await ctx.close(); process.exit(0);
})().catch(e => { console.log('ERROR', e.message); process.exit(1); });
