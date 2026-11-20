// Vuelve a registrar «Remo sentado con cuerda elevada» como parcial: primero sin repeticiones (debe pedirlas), luego con 8.
const { k, db, log } = require('./lib');
const OBJ = 'Remo sentado con cuerda elevada';
async function visibles(p) {
  return p.$$eval('flt-semantics[role=button]', ns => ns.filter(n => (n.textContent || '').trim() === 'Registrar ejercicio')
    .map(n => { const b = n.getBoundingClientRect(); return [b.x + b.width / 2, b.y + b.height / 2]; }).filter(r => r[1] > 60 && r[1] < 800).sort((a, b) => a[1] - b[1]));
}
const nombre = p => p.$$eval('flt-semantics[role=alertdialog]', ns => (ns[0]?.textContent || ''));
(async () => {
  const { ctx, p } = await k.open('lucas');
  await k.waitText(p, 'Hola, Lucas', 20000);
  await k.tap(p, 'TREN SUPERIOR 41 MIN'); await p.waitForTimeout(2500);
  let hecho = false;
  for (let vuelta = 0; vuelta < 12 && !hecho; vuelta++) {
    for (const [x, y] of await visibles(p)) {
      await p.mouse.click(x, y); await p.waitForTimeout(1000);
      if (!(await nombre(p)).includes(OBJ)) { await k.tap(p, 'Cancelar', { role: 'button', exact: true }); await p.waitForTimeout(400); continue; }
      await k.tap(p, 'Lo hice parcialmente', { role: 'button' }); await p.waitForTimeout(400);
      await k.fill(p, 'Series realizadas', '1');
      await k.fill(p, 'Repeticiones totales (todas las series)', '');
      if (!(await nombre(p)).includes('Fatiga')) { await k.tap(p, 'Motivo', { role: 'button', exact: true }); await p.waitForTimeout(600); await k.tap(p, 'Fatiga', { role: 'menuitem' }); await p.waitForTimeout(400); }
      await k.tap(p, 'Guardar', { role: 'button', exact: true }); await p.waitForTimeout(1200);
      log('sin repeticiones, aviso:', await k.waitText(p, 'cuántas repeticiones hiciste', 2000));
      await k.shot(p, 'C-parcial-sin-volumen');
      await k.fill(p, 'Repeticiones totales (todas las series)', '8');
      await k.tap(p, 'Guardar', { role: 'button', exact: true }); await p.waitForTimeout(1500);
      hecho = true; break;
    }
    if (!hecho) { await p.mouse.move(195, 420); await p.mouse.wheel(0, 450); await p.waitForTimeout(700); }
  }
  log('ejercicio 2 en BD:', db.q(`SELECT status||'/'||coalesce(skip_reason,'-')||' series='||actual_sets||' reps='||actual_reps_total||' %='||completion_percentage FROM workout_session_exercises WHERE session_exercise_id=2`));
  await k.shot(p, 'C-parcial-guardado');
  await ctx.close(); process.exit(0);
})().catch(e => { console.log('ERROR', e.message); process.exit(1); });
