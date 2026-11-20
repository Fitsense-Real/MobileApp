// María: contraseña incorrecta (403), cancelar, y bloqueo tras varios intentos (429): botón desactivado y sin más envíos.
const { k, db, log } = require('./lib'); const { abrir, intentar, texto } = require('./eliminar-lib');
(async () => {
  const { ctx, p } = await k.open('maria');
  let deletes = 0; p.on('request', r => { if (r.method() === 'DELETE') deletes++; });
  await k.waitText(p, 'María', 20000);
  await abrir(p); await k.shot(p, 'F-eliminar-pantalla');
  // cancelar en el diálogo
  await k.fill(p, 'Tu contraseña', 'Kora12345'); await k.tap(p, 'Entiendo que esta acción no se puede deshacer');
  await k.tap(p, 'Eliminar mi cuenta', { role: 'button' }); await p.waitForTimeout(800); await k.shot(p, 'F-eliminar-confirmar');
  await k.tap(p, 'Cancelar', { role: 'button', exact: true }); await p.waitForTimeout(800);
  log('cancelar → DELETE enviados:', deletes);
  await k.tap(p, 'Entiendo que esta acción no se puede deshacer'); await p.waitForTimeout(300);
  for (let i = 1; i <= 7; i++) {
    await intentar(p, 'ClaveMala' + i);
    const t = await texto(p);
    const m = t.match(/(La contraseña no es correcta[^|]*|Demasiados[^|]*|espera[^|]*)/i);
    log(`intento ${i}: DELETE=${deletes} →`, m ? m[1].slice(0, 140) : t.slice(0, 200));
    if (i === 1) await k.shot(p, 'F-eliminar-403');
    if (/espera|Demasiados/i.test(t)) { await k.shot(p, 'F-eliminar-429'); break; }
    await k.tap(p, 'Entiendo que esta acción no se puede deshacer'); await p.waitForTimeout(300);
  }
  const antes = deletes;
  await k.fill(p, 'Tu contraseña', 'Kora12345');
  const btn = await p.$$eval('flt-semantics[role=button]', ns => ns.filter(n => (n.textContent || '').trim() === 'Eliminar mi cuenta').map(n => n.getAttribute('aria-disabled')));
  log('botón tras 429 (aria-disabled):', JSON.stringify(btn));
  try { await k.tap(p, 'Eliminar mi cuenta', { role: 'button' }); await p.waitForTimeout(1200); } catch (e) {}
  log('DELETE extra tras el bloqueo:', deletes - antes);
  log('BD:', db.q(`SELECT status FROM users WHERE email='maria+d20@e2e.local'`));
  await ctx.close(); process.exit(0);
})().catch(e => { console.log('ERROR', e.message); process.exit(1); });
