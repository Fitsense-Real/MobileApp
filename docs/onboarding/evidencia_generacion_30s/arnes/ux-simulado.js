// Estado pendiente (>30 s) y error, con respuestas SIMULADAS por Playwright: el backend no genera nada.
const k = require('./kora'); const db = require('./db'); const registrar = require('./register'); const perfil = require('./profile');
const shot = (p, n) => p.screenshot({ path: __dirname + '/shots-ux/' + n + '.png' });
const texts = async p => (await p.$$eval('flt-semantics', ns => ns.map(n => ((n.getAttribute('aria-label') || '') + ' ' + (n.textContent || '')).replace(/\s+/g, ' ').trim()))).join(' | ');
/** Clic directo en el botón y marca de tiempo en el mismo instante. */
async function clicGenerar(p) {
  for (let i = 0; i < 20; i++) {
    const r = await p.$$eval('flt-semantics[role=button]', ns => { const n = ns.find(n => (n.textContent || '').includes('Generar mi plan')); if (!n) return null; const b = n.getBoundingClientRect(); return [b.x + b.width / 2, b.y + b.height / 2]; });
    if (r) { await p.mouse.click(r[0], r[1]); return Date.now(); }
    await p.mouse.move(195, 400); await p.mouse.wheel(0, 600); await p.waitForTimeout(300);
  }
  throw new Error('sin botón Generar mi plan');
}
const OP = '00000000-0000-4000-8000-00000000e2e0';
async function hastaGenerar(nombre, email) {
  const { ctx, p } = await k.open('uxsim-' + nombre + Date.now());
  await registrar(p, nombre, email);
  process.env.P1 = './p1-ux.json'; await perfil(p);
  await p.mouse.move(195, 400); await p.mouse.wheel(0, 3000); await p.waitForTimeout(400);
  await k.tap(p, 'Continuar'); await p.waitForTimeout(1000);
  return { ctx, p };
}
(async () => {
  // 1) El backend sigue «PROCESSING» más allá de los 30 s.
  {
    const E = `uxpend${process.env.SUF || ''}@e2e.local`;
    const { ctx, p } = await hastaGenerar('Pend', E);
    let gets = 0;
    await p.route('**/users/me/plan/generation', r => r.fulfill({ status: 202, contentType: 'application/json', body: JSON.stringify({ operationId: OP, status: 'PENDING', pollAfterSeconds: 3 }) }));
    await p.route(`**/users/me/plan/generation/${OP}`, r => { gets++; r.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify({ operationId: OP, status: 'PROCESSING', pollAfterSeconds: 3 }) }); });
    const t0 = await clicGenerar(p);
    await p.waitForTimeout(28000);
    console.log('28 s: Generando visible =', (await texts(p)).includes('Generando'), '· consultas de estado =', gets);
    let pendiente = null;
    while (Date.now() - t0 < 40000) { if ((await texts(p)).includes('Tu plan sigue en camino')) { pendiente = (Date.now() - t0) / 1000; break; } await p.waitForTimeout(100); }
    await p.waitForTimeout(600);
    const t = await texts(p);
    console.log('estado pendiente a los', pendiente?.toFixed(1), 's · «lista» en pantalla =', /lista/i.test(t), '· tour =', t.includes('Soy Kapi'), '· botón Continuar =', t.includes('Continuar'));
    await shot(p, 'U-pendiente-31s');
    await k.tap(p, 'Continuar', { role: 'button' });
    console.log('tras «Continuar»: tour =', await k.waitText(p, 'Soy Kapi', 10000), '· DB:', db.counts(E));
    await ctx.close();
  }
  // 2) El backend rechaza la solicitud (422): el error espera a los 30 s.
  // 3) El backend responde 503: la app lo trata como fallo temporal y sigue
  //    intentándolo; a los 30 s muestra el pendiente con el aviso del servidor.
  for (const [n, status, buscar, foto] of [['Err', 422, 'perfil está guardado', 'U-error-422-tras-30s'], ['Srv', 503, 'El servidor no responde', 'U-pendiente-503-tras-30s']]) {
    const E = `ux${n.toLowerCase()}${process.env.SUF || ''}@e2e.local`;
    const { ctx, p } = await hastaGenerar(n, E);
    await p.route('**/users/me/plan/generation', r => r.fulfill({ status, contentType: 'application/json', body: JSON.stringify({ status, message: `Respuesta ${status} simulada` }) }));
    const t0 = await clicGenerar(p);
    await p.waitForTimeout(5000);
    const t5 = await texts(p);
    console.log(`${status} · 5 s: Generando =`, t5.includes('Generando'), '· aviso visible =', t5.includes(buscar));
    let visto = null;
    while (Date.now() - t0 < 40000) { if ((await texts(p)).includes(buscar)) { visto = (Date.now() - t0) / 1000; break; } await p.waitForTimeout(100); }
    console.log(`${status} · aviso «${buscar}» visible a los`, visto?.toFixed(1), 's');
    await p.waitForTimeout(500); await shot(p, foto);
    await ctx.close();
  }
})().catch(e => { console.error(e); process.exit(1); });
