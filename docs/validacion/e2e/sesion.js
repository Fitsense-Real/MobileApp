const { k, log } = require('./lib');
(async () => {
  const { ctx, p } = await k.open('main72');
  await k.waitText(p, 'Hola, Lucía', 20000);
  await k.tap(p, 'Rutinas', { role: 'tab' }); await p.waitForTimeout(2500);
  const r = await p.$$eval('flt-semantics', ns => { const n = ns.filter(n => /^\d+ MIN/.test(n.getAttribute('aria-label') || '')).sort((a, b) => a.getBoundingClientRect().y - b.getBoundingClientRect().y)[0]; if (!n) return null; const b = n.getBoundingClientRect(); return [b.x + 60, b.y + b.height / 2]; });
  log('tarjeta', JSON.stringify(r));
  await p.mouse.click(r[0], r[1]); await p.waitForTimeout(3500);
  await k.dump(p, 'detalle'); await k.shot(p, '24-sesion');
  await ctx.close(); process.exit(0);
})().catch(e => { console.log('ERROR', e.message); process.exit(1); });
