// «Peso corporal»: marcado por defecto, desmarcable; desmarcado no vuelve al cambiar de lugar y no se envía.
const k = require('./kora'); const db = require('./db'); const registrar = require('./register'); const perfil = require('./profile');
const shot = (p, n) => p.screenshot({ path: __dirname + '/shots-ux/' + n + '.png' });
const texts = async p => (await p.$$eval('flt-semantics', ns => ns.map(n => ((n.getAttribute('aria-label') || '') + ' ' + (n.textContent || '')).replace(/\s+/g, ' ').trim()))).join(' | ');
const marcado = p => p.$$eval('flt-semantics[role=checkbox]', ns => { const n = ns.find(n => (n.textContent || n.getAttribute('aria-label') || '').includes('Peso corporal')); return n ? n.getAttribute('aria-checked') : 'ausente'; });
const chipPeso = async p => /Peso corporal · Eliminar|Peso corporal Eliminar/.test(await texts(p)) || (await p.$$eval('flt-semantics', ns => ns.some(n => /^Peso corporal/.test((n.textContent || '').trim()) && (n.textContent || '').includes('Eliminar'))));
const E = process.env.EMAIL || 'uxpeso@e2e.local';
(async () => {
  const { ctx, p } = await k.open('uxpeso-' + Date.now());
  await registrar(p, 'Peso', E);
  process.env.P1 = './p1-ux.json'; await perfil(p);
  console.log('Casa por defecto: chip Peso corporal =', await chipPeso(p));
  await k.tap(p, 'Elegir equipamiento'); await p.waitForTimeout(1000);
  console.log('selector: Peso corporal marcado =', await marcado(p));
  await k.tap(p, 'Peso corporal', { role: 'checkbox' }); await p.waitForTimeout(500);
  console.log('tras desmarcar: marcado =', await marcado(p));
  await shot(p, 'U-peso-desmarcado-selector');
  await k.tap(p, 'LISTO'); await p.waitForTimeout(700);
  console.log('tarjeta:', (await texts(p)).match(/Sin equipo seleccionado|\d+ equipos? seleccionados?/)?.[0], '· chip =', await chipPeso(p));
  for (const lugar of ['Gimnasio', 'Ambos', 'Casa', 'Gimnasio']) {
    await p.mouse.move(195, 400); await p.mouse.wheel(0, -2000); await p.waitForTimeout(300);
    await k.tap(p, lugar, { exact: true }); await p.waitForTimeout(700);
    console.log(`tras ${lugar}: chip Peso corporal =`, await chipPeso(p));
  }
  await p.mouse.move(195, 400); await p.mouse.wheel(0, 400); await p.waitForTimeout(400);
  await shot(p, 'U-peso-desmarcado-gimnasio');
  await k.tap(p, 'Elegir equipamiento'); await p.waitForTimeout(1000);
  console.log('selector en Gimnasio: Peso corporal marcado =', await marcado(p));
  await k.tap(p, 'LISTO'); await p.waitForTimeout(700);
  await p.mouse.move(195, 400); await p.mouse.wheel(0, 3000); await p.waitForTimeout(400); await p.mouse.wheel(0, 3000); await p.waitForTimeout(400);
  await k.tap(p, 'Continuar'); await p.waitForTimeout(1000);
  await p.mouse.wheel(0, 3000); await p.waitForTimeout(500);
  await k.tap(p, 'Generar mi plan', { role: 'button' });
  await p.waitForTimeout(3000);
  const fila = db.q(`SELECT training_location, equipment_codes FROM user_profiles up JOIN users u USING(user_id) WHERE u.email='${E}'`);
  console.log('DB perfil:', fila, '· contiene body weight =', fila.includes('body weight'));
  await ctx.close();
})().catch(e => { console.error(e); process.exit(1); });
