const { k, log } = require('./lib');
(async () => {
  const { ctx, p } = await k.open('lucas');
  await k.waitText(p, 'Hola, Lucas', 20000); await p.waitForTimeout(2000);
  await k.dump(p, 'inicio'); await k.shot(p, 'D-inicio-tras-ciclo');
  await k.tap(p, 'Progreso', { role: 'tab' }); await p.waitForTimeout(2500);
  await k.dump(p, 'progreso'); await k.shot(p, 'D-progreso');
  await p.mouse.move(195, 420); await p.mouse.wheel(0, 700); await p.waitForTimeout(900);
  await k.dump(p, 'progreso 2'); await k.shot(p, 'D-progreso-2');
  await p.mouse.wheel(0, 700); await p.waitForTimeout(900);
  await k.dump(p, 'progreso 3'); await k.shot(p, 'D-progreso-3');
  await ctx.close(); process.exit(0);
})().catch(e => { console.log('ERROR', e.message); process.exit(1); });
