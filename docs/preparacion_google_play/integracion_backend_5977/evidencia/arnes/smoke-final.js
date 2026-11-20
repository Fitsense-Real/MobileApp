const { k, terminarTour, log } = require('./lib');
(async () => {
  const { ctx, p } = await k.open('smoke');
  if (await k.waitText(p, 'COMENZAR AHORA', 15000)) { await k.tap(p, 'INICIA SESIÓN', { role: 'button' }); await p.waitForTimeout(1000); await k.fill(p, 'Correo', 'fin5@e2e.local'); await k.fill(p, 'Contraseña', process.env.E2E_PASSWORD); await k.tap(p, 'INICIAR SESIÓN'); await p.waitForTimeout(3000); }
  if (await k.waitText(p, 'de 10', 5000)) { log('tour de Kapi visible'); await terminarTour(p); }
  if (await k.waitText(p, 'Ver mi plan', 5000)) await k.tap(p, 'Ver mi plan', { role: 'button' });
  log('dashboard:', await k.waitText(p, 'Hola, Sintetico', 20000)); await k.shot(p, 'X-smoke-final');
  await k.tap(p, 'Perfil', { role: 'tab' }); await p.waitForTimeout(1200); await p.mouse.move(195, 420); for (let i = 0; i < 15; i++) { await p.mouse.wheel(0, 500); await p.waitForTimeout(60); } await p.waitForTimeout(600); await k.dump(p, 'perfil'); await k.tap(p, 'Cerrar sesión', { role: 'button' }); await p.waitForTimeout(1500);
  log('tras cerrar sesión, login visible:', await k.waitText(p, 'INICIA', 8000) || await k.waitText(p, 'INICIAR SESIÓN', 3000));
  await ctx.close(); process.exit(0);
})().catch(e => { console.log('ERROR', e.message); process.exit(1); });
