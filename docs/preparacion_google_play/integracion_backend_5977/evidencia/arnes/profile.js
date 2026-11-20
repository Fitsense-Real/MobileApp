// Completa el perfil (5 pasos) desde el paso 1, ya con sesion iniciada.
const k = require('./kora');
module.exports = async function perfil(p, shots = false) {
  const steps = require(process.env.P1 || './p1.json');
  for (const a of steps) {
    if (a.tap) await k.tap(p, a.tap, a); else if (a.fill) await k.fill(p, a.fill, a.value);
    else if (a.wait) await p.waitForTimeout(a.wait);
    else if (a.scroll) { await p.mouse.move(195, 400); await p.mouse.wheel(0, a.scroll); await p.waitForTimeout(500); }
    else if (a.shot && shots) await k.shot(p, a.shot);
  }
  if (shots) await k.shot(p, '06-perfil-5');
};
