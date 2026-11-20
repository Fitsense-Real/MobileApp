// «Ya lo hice»: registra de una vez el primer entrenamiento de María (todo completado) con fecha y esfuerzo.
const { k, db, log } = require('./lib');
async function visibles(p) {
  return p.$$eval('flt-semantics[role=button]', ns => ns.filter(n => (n.textContent || '').trim() === 'Registrar ejercicio')
    .map(n => { const b = n.getBoundingClientRect(); return [b.x + b.width / 2, b.y + b.height / 2]; }).filter(r => r[1] > 60 && r[1] < 800).sort((a, b) => a[1] - b[1]));
}
const dlg = p => p.$$eval('flt-semantics[role=alertdialog]', ns => (ns[0]?.textContent || '').split(/\d+ series|\d+ s por serie/)[0].trim());
const fondo = async p => { await p.mouse.move(195, 420); for (let i = 0; i < 40; i++) { await p.mouse.wheel(0, 700); await p.waitForTimeout(50); } await p.waitForTimeout(800); };
const arriba = async p => { await p.mouse.move(195, 420); for (let i = 0; i < 40; i++) { await p.mouse.wheel(0, -700); await p.waitForTimeout(50); } await p.waitForTimeout(800); };
(async () => {
  const { ctx, p } = await k.open('maria');
  await k.waitText(p, 'María', 20000);
  await k.tap(p, 'VER PLAN', { role: 'button' }); await p.waitForTimeout(2000);
  await k.tap(p, 'Tren superior'); await p.waitForTimeout(2500);
  await fondo(p); await k.dump(p, 'fondo');
  await k.tap(p, 'Ya lo hice · registrar entrenamiento', { role: 'button' }); await p.waitForTimeout(1000);
  await arriba(p); await k.shot(p, 'C-reporte-inicio');
  const hechos = new Set(); let sin = 0;
  while (sin < 5) {
    let nuevo = false;
    for (const [x, y] of await visibles(p)) {
      await p.mouse.click(x, y); await p.waitForTimeout(900);
      const n = await dlg(p);
      if (!n || hechos.has(n)) { await k.tap(p, 'Cancelar', { role: 'button', exact: true }); await p.waitForTimeout(400); continue; }
      await k.tap(p, 'Lo completé', { role: 'button' }); await p.waitForTimeout(300);
      await k.tap(p, 'Usar resultado', { role: 'button', exact: true }); await p.waitForTimeout(900);
      hechos.add(n); log(hechos.size + '.', n); nuevo = true; break;
    }
    if (!nuevo) { sin++; await p.mouse.move(195, 420); await p.mouse.wheel(0, 450); await p.waitForTimeout(700); } else sin = 0;
  }
  await fondo(p);
  await k.tap(p, 'Guardar entrenamiento', { role: 'button' }); await p.waitForTimeout(1200);
  await k.shot(p, 'C-reporte-dialogo');
  await k.tap(p, 'Elegir fecha y hora del entrenamiento', { role: 'button' }); await p.waitForTimeout(1000);
  await k.dump(p, 'selector fecha'); await k.shot(p, 'C-reporte-fecha');
  const ok = async () => { const t = (await k.tree(p)).map(x => x[1] + ' ' + x[2]).join('|'); const b = ['Aceptar', 'ACEPTAR', 'OK', 'Guardar'].find(x => t.includes(x)); await k.tap(p, b, { role: 'button', exact: true }); await p.waitForTimeout(1000); };
  await ok(); await k.dump(p, 'selector hora'); await ok();
  await k.tap(p, 'Esfuerzo percibido', { role: 'button' }); await p.waitForTimeout(600);
  await k.tap(p, '6', { role: 'menuitem', exact: true }); await p.waitForTimeout(400);
  await k.dump(p, 'listo'); await k.shot(p, 'C-reporte-listo');
  await k.tap(p, 'Finalizar', { role: 'button', exact: true }); await p.waitForTimeout(2500);
  await k.dump(p, 'tras reportar'); await k.shot(p, 'C-reporte-guardado');
  log('BD:', db.q(`SELECT s.status||' src='||s.source||' %='||s.completion_percentage||' rpe='||s.session_rpe||' start='||s.started_at||' pw='||pw.status FROM workout_sessions s JOIN planned_workouts pw USING(planned_workout_id) WHERE pw.planned_workout_id=1`));
  await ctx.close(); process.exit(0);
})().catch(e => { console.log('ERROR', e.message); process.exit(1); });
