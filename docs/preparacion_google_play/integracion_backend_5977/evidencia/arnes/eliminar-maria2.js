// María ya bloqueada por el backend: el primer intento recibe 429; la app lo explica y no deja reenviar.
const { k, db, log } = require('./lib'); const { abrir, intentar, texto } = require('./eliminar-lib');
(async () => {
  const { ctx, p } = await k.open('maria');
  let deletes = 0; p.on('request', r => { if (r.method() === 'DELETE') deletes++; });
  await k.waitText(p, 'María', 20000);
  await abrir(p);
  await intentar(p, 'Kora12345');
  const t = await texto(p);
  log('mensaje:', (t.match(/Demasiados[^|]*/) || ['(no visible)'])[0]);
  await k.shot(p, 'F-eliminar-429');
  await k.fill(p, 'Tu contraseña', 'Kora12345x'); await k.fill(p, 'Tu contraseña', 'Kora12345');
  const btn = await p.$$eval('flt-semantics[role=button]', ns => ns.filter(n => (n.textContent || '').trim() === 'Eliminar mi cuenta').map(n => n.getAttribute('aria-disabled')));
  log('botón (aria-disabled):', JSON.stringify(btn));
  try { await k.tap(p, 'Eliminar mi cuenta', { role: 'button' }); await p.waitForTimeout(1200); } catch (e) {}
  log('DELETE enviados en total:', deletes, '· BD:', db.q(`SELECT status FROM users WHERE email='maria+d20@e2e.local'`));
  await ctx.close(); process.exit(0);
})().catch(e => { console.log('ERROR', e.message); process.exit(1); });
