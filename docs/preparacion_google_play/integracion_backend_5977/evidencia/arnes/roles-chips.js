// Roles de semántica de los chips del diálogo de resultado, en un build dado (puerto por argumento).
const { chromium } = require('playwright'); const k = require('./kora');
const PORT = process.argv[2]; const PERFIL = process.argv[3];
(async () => {
  const ctx = await chromium.launchPersistentContext(__dirname + '/profiles/' + PERFIL, { viewport: { width: 390, height: 844 } });
  const p = ctx.pages()[0] || await ctx.newPage();
  await p.goto(`http://localhost:${PORT}/`); await k.semantics(p);
  if (!await k.waitText(p, 'Hola, Mia', 8000)) {
    await k.waitText(p, 'COMENZAR AHORA', 15000); await k.tap(p, 'INICIA SESIÓN', { role: 'button' }); await p.waitForTimeout(1000);
    await k.fill(p, 'Correo', 'mui2@e2e.local'); await k.fill(p, 'Contraseña', process.env.E2E_PASSWORD); await k.tap(p, 'INICIAR SESIÓN');
    if (await k.waitText(p, 'de 10', 6000)) { const { terminarTour } = require('./lib'); await terminarTour(p); }
    await k.waitText(p, 'Hola, Mia', 20000);
  }
  await k.dump(p, 'inicio-'+PORT);
  await k.tap(p, 'TREN SUPERIOR'); await p.waitForTimeout(2500);
  await k.tap(p, 'Registrar ejercicio', { role: 'button' }); await p.waitForTimeout(1200);
  await k.dump(p, 'dialogo-'+PORT);
  const roles = await p.$$eval('flt-semantics', ns => ns.filter(n => /^(Lo completé|Lo hice parcialmente|No lo hice)$/.test((n.textContent || '').trim()) && n.getAttribute('role')).map(n => `${(n.textContent || '').trim()} → role=${n.getAttribute('role')} aria-checked=${n.getAttribute('aria-checked')} aria-pressed=${n.getAttribute('aria-pressed')}`));
  console.log(`[puerto ${PORT}]`, JSON.stringify(roles, null, 0));
  await ctx.close(); process.exit(0);
})().catch(e => { console.log('ERROR', e.message); process.exit(1); });
