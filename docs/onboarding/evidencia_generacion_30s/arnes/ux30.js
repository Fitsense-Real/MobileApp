// Pantalla «Generando» de 30 s, Kapi, peso corporal y retiro de «ejercicios a evitar» contra el backend local.
const k = require('./kora'); const db = require('./db'); const registrar = require('./register'); const perfil = require('./profile');
const shot = (p, n) => p.screenshot({ path: __dirname + '/shots-ux/' + n + '.png' });
const texts = p => p.$$eval('flt-semantics', ns => ns.map(n => ((n.getAttribute('aria-label') || '') + ' ' + (n.textContent || '')).replace(/\s+/g, ' ').trim()).filter(Boolean));
const E = process.env.EMAIL || 'ux30@e2e.local';
(async () => {
  const { ctx, p } = await k.open('ux30-' + Date.now());
  const api = [];
  let t0 = null;
  p.on('response', r => { if (r.url().includes('/plan/generation') || r.url().includes('/users/me/profile')) api.push([t0 ? ((Date.now() - t0) / 1000).toFixed(1) : '-', r.request().method(), r.url().replace(/.*api\/v1/, ''), r.status()]); });
  p.on('response', async r => { if (r.url().includes('/plan/generation')) { try { const j = await r.json(); api.push([t0 ? ((Date.now() - t0) / 1000).toFixed(1) : '-', 'body', j.status, j.planId ?? '-']); } catch {} } });
  await registrar(p, 'Ux', E);
  process.env.P1 = './p1-ux.json';
  await perfil(p);
  console.log('paso 4:', await k.waitText(p, 'Paso 4 de 5', 5000));
  for (const lugar of ['Casa', 'Gimnasio', 'Ambos']) {
    await k.tap(p, lugar, { exact: true }); await p.waitForTimeout(800);
    const t = (await texts(p)).join(' | ');
    console.log(`${lugar}: chip Peso corporal=${/Peso corporal/.test(t)} · ${(t.match(/\d+ equipos? seleccionados?/) || [''])[0]}`);
    await p.mouse.move(195, 400); await p.mouse.wheel(0, 400); await p.waitForTimeout(500);
    await shot(p, `U-equipo-${lugar.toLowerCase()}`);
    await k.tap(p, 'Elegir equipamiento'); await p.waitForTimeout(1000);
    const sel = (await texts(p)).join(' | ');
    console.log(`  selector ${lugar}: «Siempre incluido»=${sel.includes('Siempre incluido')}`);
    await shot(p, `U-selector-${lugar.toLowerCase()}`);
    if (lugar === 'Casa') { await k.tap(p, 'Mancuerna', { role: 'checkbox' }); await p.waitForTimeout(400); await shot(p, 'U-selector-casa-agrega-mancuerna'); }
    await k.tap(p, 'LISTO'); await p.waitForTimeout(700);
    await p.mouse.move(195, 400); await p.mouse.wheel(0, -2000); await p.waitForTimeout(400);
  }
  await p.mouse.move(195, 400); await p.mouse.wheel(0, 3000); await p.waitForTimeout(400); await p.mouse.wheel(0, 3000); await p.waitForTimeout(400);
  await k.tap(p, 'Continuar'); await p.waitForTimeout(1000);
  const paso5 = (await texts(p)).join(' | ');
  console.log('paso 5:', paso5.includes('Paso 5 de 5'), '· «ejercicios a evitar» presente:', /ejercicios a evitar|Ejercicios restringidos|excluidos/i.test(paso5));
  await shot(p, 'U-paso5-arriba');
  await p.mouse.move(195, 400); await p.mouse.wheel(0, 3000); await p.waitForTimeout(600);
  await shot(p, 'U-paso5-abajo');
  const paso5b = (await texts(p)).join(' | ');
  console.log('paso 5 (abajo) «ejercicios a evitar» presente:', /ejercicios a evitar|Ejercicios restringidos|excluidos/i.test(paso5b));
  for (let i = 0; i < 20 && !t0; i++) {
    const r = await p.$$eval('flt-semantics[role=button]', ns => { const n = ns.find(n => (n.textContent || '').includes('Generar mi plan')); if (!n) return null; const b = n.getBoundingClientRect(); return [b.x + b.width / 2, b.y + b.height / 2]; });
    if (r) { await p.mouse.click(r[0], r[1]); t0 = Date.now(); } else { await p.mouse.wheel(0, 600); await p.waitForTimeout(300); }
  }
  const linea = []; let tour = null, ultimo = '';
  const shots = new Set([2, 9, 16, 24, 29]);
  while ((Date.now() - t0) < 45000) {
    const s = (Date.now() - t0) / 1000;
    const t = await texts(p); const all = t.join(' | ');
    const kapi = t.find(x => /\?|!|\.$/.test(x) && !/Generando|Combinando|Toca a Kapi|Progreso/.test(x) && x.length > 20) || '';
    if (kapi !== ultimo) { linea.push([s.toFixed(1), kapi]); ultimo = kapi; }
    for (const at of [...shots]) if (s >= at) { shots.delete(at); await shot(p, `U-generando-${String(at).padStart(2, '0')}s`); }
    if (/Soy Kapi/.test(all)) { tour = s; break; }
    await p.waitForTimeout(100);
  }
  console.log('tour visible a los', tour?.toFixed(1), 's del toque');
  await shot(p, 'U-tour-tras-30s');
  console.log('mensajes de Kapi (s, texto):'); for (const l of linea) console.log('  ', l[0], l[1]);
  console.log('API (s desde el toque, método, ruta, estado):'); for (const a of api) console.log('  ', a.join(' '));
  console.log('DB perfil:', db.q(`SELECT training_location, equipment_codes, blocked_exercise_ids FROM user_profiles up JOIN users u USING(user_id) WHERE u.email='${E}'`));
  console.log('DB operaciones:', db.counts(E), '·', db.op(E));
  await ctx.close();
})().catch(e => { console.error(e); process.exit(1); });
