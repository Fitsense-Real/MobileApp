const { k } = require('./lib');
async function abrir(p) {
  await k.tap(p, 'Perfil', { role: 'tab' }); await p.waitForTimeout(1500);
  await p.mouse.move(195, 420); for (let i = 0; i < 12; i++) { await p.mouse.wheel(0, 500); await p.waitForTimeout(60); } await p.waitForTimeout(600);
  await k.tap(p, 'Cuenta', { exact: true }); await p.waitForTimeout(1200);
  await k.tap(p, 'Eliminar mi cuenta', { role: 'button' }); await p.waitForTimeout(1500);
}
async function intentar(p, clave, { dobleToque = false, marcar = true } = {}) {
  await k.fill(p, 'Tu contraseña', clave);
  if (marcar) { await k.tap(p, 'Entiendo que esta acción no se puede deshacer'); await p.waitForTimeout(300); }
  await k.tap(p, 'Eliminar mi cuenta', { role: 'button' }); await p.waitForTimeout(800);
  if (dobleToque) {
    const b = await p.$$eval('flt-semantics[role=button]', ns => ns.filter(n => (n.textContent || '').trim() === 'Eliminar').map(n => { const r = n.getBoundingClientRect(); return [r.x + r.width / 2, r.y + r.height / 2]; }));
    const [x, y] = b[b.length - 1]; await p.mouse.click(x, y); await p.mouse.click(x, y); await p.mouse.click(x, y);
  } else await k.tap(p, 'Eliminar', { role: 'button', exact: true });
  await p.waitForTimeout(2500);
}
async function texto(p) { return p.evaluate(() => [...document.querySelectorAll('flt-semantics')].map(n => (n.getAttribute('aria-label') || '') + ' ' + [...n.childNodes].filter(c => c.nodeType === 3).map(c => c.textContent).join('')).join(' | ')); }
module.exports = { abrir, intentar, texto };
