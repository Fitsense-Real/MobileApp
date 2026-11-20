// Registra todos los ejercicios de la sesion en curso de hoy (completo, parcial, no realizado) y finaliza.
const { k, db, log } = require('./lib');
async function visibles(p) {
  return p.$$eval('flt-semantics[role=button]', ns => ns.filter(n => (n.textContent || '').trim() === 'Registrar ejercicio')
    .map(n => { const b = n.getBoundingClientRect(); return [b.x + b.width / 2, b.y + b.height / 2]; }).filter(r => r[1] > 60 && r[1] < 800).sort((a, b) => a[1] - b[1]));
}
async function nombreDialogo(p) {
  return p.$$eval('flt-semantics[role=alertdialog]', ns => (ns[0]?.textContent || '').split(/\d+ series|\d+ s por serie/)[0].trim());
}
(async () => {
  const e = 'lucas@e2e.local';
  const { ctx, p } = await k.open('lucas');
  await k.waitText(p, 'Hola, Lucas', 20000);
  await k.tap(p, 'TREN SUPERIOR 41 MIN'); await p.waitForTimeout(2500);
  const hechos = new Map(); let sinNuevos = 0;
  const plan = (n) => n === 1 ? ['Lo hice parcialmente', 'Fatiga'] : n === 2 ? ['No lo hice', 'Falta de tiempo'] : ['Lo completé', null];
  while (sinNuevos < 4) {
    let nuevo = false;
    for (const [x, y] of await visibles(p)) {
      await p.mouse.click(x, y); await p.waitForTimeout(1000);
      const nombre = await nombreDialogo(p);
      if (!nombre || hechos.has(nombre)) { await k.tap(p, 'Cancelar', { role: 'button', exact: true }); await p.waitForTimeout(500); continue; }
      const [opcion, motivo] = plan(hechos.size);
      await k.tap(p, opcion, { role: 'button' }); await p.waitForTimeout(400);
      if (motivo) { await k.tap(p, 'Motivo', { role: 'button', exact: true }); await p.waitForTimeout(600); await k.tap(p, motivo, { role: 'menuitem' }); await p.waitForTimeout(400); }
      if (opcion === 'Lo hice parcialmente') { await k.fill(p, 'Series realizadas', '1'); await k.shot(p, 'C-registro-parcial'); }
      await k.tap(p, 'Guardar', { role: 'button', exact: true }); await p.waitForTimeout(1500);
      hechos.set(nombre, opcion); log(`${hechos.size}. ${nombre}: ${opcion}${motivo ? ' (' + motivo + ')' : ''}`);
      nuevo = true; break;
    }
    if (!nuevo) { sinNuevos++; await p.mouse.move(195, 420); await p.mouse.wheel(0, 450); await p.waitForTimeout(700); } else sinNuevos = 0;
  }
  log('ejercicios en BD:', db.q(`SELECT string_agg(r.status || coalesce('/' || r.skip_reason, ''), ', ' ORDER BY r.session_exercise_id) FROM workout_session_exercises r JOIN workout_sessions s USING(session_id) JOIN users u USING(user_id) WHERE u.email='${e}'`));
  await p.mouse.move(195, 420); for (let i = 0; i < 30; i++) { await p.mouse.wheel(0, 700); await p.waitForTimeout(50); } await p.waitForTimeout(800);
  await k.shot(p, 'C-antes-de-finalizar');
  await k.tap(p, 'Finalizar sesión', { role: 'button' }); await p.waitForTimeout(1200);
  await k.dump(p, 'finalizar'); await k.shot(p, 'C-finalizar');
  await ctx.close(); process.exit(0);
})().catch(e => { console.log('ERROR', e.message); process.exit(1); });
