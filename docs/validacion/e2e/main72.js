// Flujo principal contra backend #71+#72: registro -> perfil -> generacion -> tour -> espera -> plan -> Rutinas -> sesion.
const { k, db, avanzar, pasoActual, log } = require('./lib');
const perfil = require('./profile'); const registrar = require('./register');
(async () => {
  const e = 'lucia+d45@e2e.local';
  const { ctx, p } = await k.open('main72');
  try {
    await registrar(p, 'Lucía', e);
    await k.shot(p, '01-perfil-paso1');
    await perfil(p, true);
    log('antes de generar:', db.counts(e));
    await k.tap(p, 'Generar mi plan');
    if (!await k.waitText(p, 'Soy Kapi', 20000)) throw new Error('sin tour');
    for (let i = 1; i <= 10; i++) {
      await p.waitForTimeout(1200);
      const paso = await pasoActual(p);
      log(`tour paso ${paso} | BD: ${db.op(e)}`);
      await k.shot(p, `10-tour-${String(paso).padStart(2, '0')}`);
      if (paso === 3) { await p.mouse.click(390 * 1.5 / 4, 844 - 36); await p.waitForTimeout(1200); continue; }
      if (paso === 10) break;
      await avanzar(p);
    }
    await k.tap(p, 'Terminar', { role: 'button' }); await p.waitForTimeout(1500);
    log('tour terminado | BD:', db.op(e)); await k.shot(p, '20-espera');
    if (!await k.waitText(p, 'Tu primera rutina está lista', 120000)) throw new Error('sin plan');
    await p.waitForTimeout(2000);
    log('plan listo | BD:', db.op(e), '|', db.counts(e)); await k.shot(p, '21-lista');
    await k.tap(p, 'Ver mi plan'); await p.waitForTimeout(3500);
    await k.dump(p, 'inicio'); await k.shot(p, '22-inicio');
    await k.tap(p, 'Rutinas', { role: 'tab' }); await p.waitForTimeout(2500);
    await k.shot(p, '23-rutinas');
    // abrir la primera sesion generada
    const card = await p.$$eval('flt-semantics', ns => { const n = ns.filter(n => /\d+ MIN/.test(n.textContent || '') && n.getAttribute('role') === 'button').pop(); if (!n) return null; const b = n.getBoundingClientRect(); return [b.x + b.width / 2, b.y + 20]; });
    if (card) { await p.mouse.click(card[0], card[1]); await p.waitForTimeout(3000); }
    await k.dump(p, 'sesion'); await k.shot(p, '24-sesion');
  } catch (err) { console.log('ERROR', err.message); await k.shot(p, '_error'); }
  await ctx.close(); process.exit(0);
})();
