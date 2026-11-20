// Eliminación sobre el Mobile integrado. Uso: node fin-eliminar.js <modo> (ok | corte | pendiente | bloqueo)
const { k, db, terminarTour, log } = require('./lib'); const { abrir, intentar, texto } = require('./eliminar-lib');
const { spawn } = require('child_process');
const PASS = process.env.E2E_PASSWORD;
const modo = process.argv[2];
const cuenta = { ok: ['diag', 'fin1@e2e.local', 'Hola, Fina'], corte: ['fin3', 'fin3@e2e.local', 'Hola, Sintetico'], pendiente: ['fin4', 'fin4@e2e.local', 'Hola, Sintetico'], bloqueo: ['fin5', 'fin5@e2e.local', 'Hola, Sintetico'] }[modo];
const [perfil, E, saludo] = cuenta;
const frase = async (p, re) => ((await texto(p)).match(re) || ['(no visible)'])[0].slice(0, 160);
(async () => {
  const uid = db.q(`SELECT user_id FROM users WHERE email='${E}'`);
  const { ctx, p } = await k.open(perfil);
  let deletes = []; p.on('response', r => { if (r.request().method() === 'DELETE') deletes.push(r.status()); });
  p.on('requestfailed', r => { if (r.method() === 'DELETE') deletes.push('cortada'); });
  if (!await k.waitText(p, saludo, 6000)) {
    if (await k.waitText(p, 'COMENZAR AHORA', 8000)) { await k.tap(p, 'INICIA SESIÓN', { role: 'button' }); await p.waitForTimeout(1000); await k.fill(p, 'Correo', E); await k.fill(p, 'Contraseña', PASS); await k.tap(p, 'INICIAR SESIÓN'); await p.waitForTimeout(3000); }
    if (await k.waitText(p, 'de 10', 5000)) await terminarTour(p);
    if (await k.waitText(p, 'Ver mi plan', 5000)) await k.tap(p, 'Ver mi plan', { role: 'button' });
    await k.waitText(p, saludo, 20000);
  }
  await abrir(p);
  if (modo === 'ok') {
    await intentar(p, 'incorrecta-1'); log('403 →', await frase(p, /La contraseña no es correcta[^|]*/)); await k.shot(p, 'X-del-403');
    await k.tap(p, 'Entiendo que esta acción no se puede deshacer').catch(() => {});
    if ((await p.$$eval('flt-semantics[role=checkbox]', ns => ns.map(n => n.getAttribute('aria-checked'))))[0] !== 'true') await k.tap(p, 'Entiendo que esta acción no se puede deshacer');
    await intentar(p, PASS, { dobleToque: true, marcar: false });
    log('pantalla:', await frase(p, /Tu cuenta fue eliminada[^|]*/)); await k.shot(p, 'X-del-200');
  } else if (modo === 'corte') {
    // El servidor recibe y procesa el DELETE, pero la respuesta no llega: la conexión se corta.
    await p.route('**/api/v1/users/me', async route => {
      if (route.request().method() !== 'DELETE') return route.continue();
      const r = await route.fetch(); log('el servidor respondió', r.status(), 'pero la app no lo recibe');
      await route.abort('connectionreset');
    });
    await intentar(p, PASS);
    log('mensaje tras el corte:', await frase(p, /No pudimos comunicarnos[^|]*|No recibimos[^|]*|No hay conexión[^|]*|No se eliminó nada[^|]*/));
    log('¿dice «No se eliminó nada»?', (await texto(p)).includes('No se eliminó nada'));
    await k.shot(p, 'X-del-corte');
    log('BD:', db.q(`SELECT coalesce((SELECT status FROM users WHERE user_id=${uid}),'(fila borrada)')||' · eliminaciones='||(SELECT string_agg(status,',') FROM account_deletions WHERE requested_at > now()-interval '2 minutes')`));
    const antes = await p.evaluate(id => Object.keys(localStorage).filter(x => x.includes('_' + id)), uid);
    log('datos locales de la cuenta antes del reintento:', JSON.stringify(antes));
    await p.unroute('**/api/v1/users/me');
    await k.tap(p, 'Eliminar mi cuenta', { role: 'button' }).catch(() => {}); await p.waitForTimeout(800);
    await k.tap(p, 'Eliminar', { role: 'button', exact: true }).catch(() => {}); await p.waitForTimeout(3000);
    log('reintento:', await frase(p, /Tu cuenta probablemente ya se eliminó[^|]*|Tu sesión ya no es válida[^|]*|PORTAL DE ACCESO/));
    await k.shot(p, 'X-del-corte-reintento');
    const despues = await p.evaluate(id => Object.keys(localStorage).filter(x => x.includes('_' + id)), uid);
    log('datos locales de la cuenta después:', JSON.stringify(despues));
  } else if (modo === 'pendiente') {
    const lock = spawn('psql', ['-h', 'localhost', '-U', 'postgres', '-d', 'fitsense_final', '-c', `BEGIN; SELECT plan_id FROM weekly_training_plans WHERE user_id=${uid} FOR UPDATE; SELECT pg_sleep(40); COMMIT;`], { env: process.env, stdio: 'ignore' });
    await p.waitForTimeout(1500);
    await intentar(p, PASS); await p.waitForTimeout(6000);
    log('pantalla:', await frase(p, /Solicitud recibida[^|]*/)); await k.shot(p, 'X-del-202');
    log('BD:', db.q(`SELECT a.status||' users.status='||coalesce(u.status,'(borrado)') FROM account_deletions a LEFT JOIN users u USING(user_id) ORDER BY a.requested_at DESC LIMIT 1`));
    lock.kill();
  } else if (modo === 'bloqueo') {
    for (let i = 1; i <= 7 && deletes[deletes.length - 1] !== 429; i++) {
      await intentar(p, 'incorrecta-' + i, { marcar: i === 1 });
    }
    log('429 →', await frase(p, /Demasiados[^|]*/)); await k.shot(p, 'X-del-429');
    log('botón desactivado:', JSON.stringify(await p.$$eval('flt-semantics[role=button]', ns => ns.filter(n => (n.textContent || '').trim() === 'Eliminar mi cuenta').map(n => n.getAttribute('aria-disabled')))));
    log('cuenta:', db.q(`SELECT status FROM users WHERE user_id=${uid}`));
  }
  log('DELETE vistos:', JSON.stringify(deletes));
  await ctx.close(); process.exit(0);
})().catch(e => { console.log('ERROR', e.message); process.exit(1); });
