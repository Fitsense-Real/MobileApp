const { k, db, nuevo, avanzar, pasoActual, log } = require('./lib');
(async () => {
  const e = 'final+d20@e2e.local';
  const { ctx, p } = await nuevo('final', 'Final', e);
  log('tour visible; BD:', db.op(e));
  for (let i = 1; i <= 10; i++) {
    const paso = await pasoActual(p);
    if (paso === 3) {
      // toque REAL en la pestana "Rutinas" dentro del hueco (segunda de cuatro, abajo)
      await p.mouse.click(390 * 1.5 / 4, 844 - 36); await p.waitForTimeout(1200);
      log('paso 3: toque en la pestana real -> paso', await pasoActual(p), '| BD:', db.op(e));
      continue;
    }
    if (paso === 10) break;
    await avanzar(p);
  }
  await k.tap(p, 'Terminar', { role: 'button' });
  const ok = await k.waitText(p, 'Tu primera rutina está lista', 60000); await p.waitForTimeout(2000);
  log('resultado listo:', ok, '| BD:', db.op(e), db.counts(e));
  await k.tap(p, 'Ver mi plan'); await p.waitForTimeout(3000);
  log('inicio con plan:', await k.waitText(p, 'Próximas rutinas', 8000));
  await k.shot(p, 'final-inicio');
  // repaso desde Perfil: textos neutros
  await k.tap(p, 'Perfil', { role: 'tab' }); await p.waitForTimeout(1000);
  await p.mouse.move(195, 422); await p.mouse.wheel(0, 2000); await p.waitForTimeout(800);
  await k.tap(p, 'Ver recorrido de Kora'); await p.waitForTimeout(1500);
  await k.shot(p, 'repaso-01');
  log('repaso paso 1 menciona preparación:', await k.waitText(p, 'prepara', 800));
  await avanzar(p); await p.waitForTimeout(800); await k.shot(p, 'repaso-02');
  log('repaso paso 2 menciona "primera rutina":', await k.waitText(p, 'primera rutina', 800));
  await ctx.close(); process.exit(0);
})().catch(e => { console.log('ERROR', e.message); process.exit(1); });
