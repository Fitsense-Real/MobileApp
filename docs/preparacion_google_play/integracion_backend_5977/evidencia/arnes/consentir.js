const { E2E_PASSWORD } = require('./credenciales');
// Versiones de PRUEBA publicadas en el backend local (exigencia en el registro desactivada).
const { k, db, log } = require('./lib');
const e = 'con2@e2e.local';
(async () => {
  const { ctx, p } = await k.open('con2');
  let posts = []; p.on('request', r => { if (r.url().includes('/consents') && r.method() === 'POST') posts.push(r.postData()); });
  await k.waitText(p, 'COMENZAR AHORA', 15000); await k.tap(p, 'INICIA SESIÓN', { role: 'button' }); await p.waitForTimeout(1000);
  await k.waitText(p, 'INICIAR SESIÓN', 15000);
  await k.fill(p, 'Correo', e); await k.fill(p, 'Contraseña', E2E_PASSWORD); await k.tap(p, 'INICIAR SESIÓN');
  await p.waitForTimeout(4000);
  await k.dump(p, 'tras login'); await k.shot(p, 'G-consentimientos');
  const cbs = await p.$$eval('flt-semantics[role=checkbox]', ns => ns.map(n => (n.textContent || n.getAttribute('aria-label') || '').trim().slice(0, 60) + ' = ' + n.getAttribute('aria-checked')));
  log('casillas iniciales:', JSON.stringify(cbs));
  // continuar sin marcar
  const t0 = posts.length;
  await k.tap(p, 'Continuar', { role: 'button' }).catch(() => {}); await p.waitForTimeout(1000);
  log('continuar sin marcar → POST enviados:', posts.length - t0, '· sigue en la pantalla:', await k.waitText(p, 'condiciones de uso', 1000));
  await k.tap(p, 'Acepto las condiciones de uso', { role: 'checkbox' }); await k.tap(p, 'He leído la política de privacidad', { role: 'checkbox' });
  await k.shot(p, 'G-consentimientos-marcados');
  await k.tap(p, 'Continuar', { role: 'button' }); await p.waitForTimeout(3000);
  log('POST enviados:', JSON.stringify(posts));
  log('pasa al perfil:', await k.waitText(p, 'Paso 1 de 5', 8000));
  log('BD:', db.q(`SELECT string_agg(c.consent_type||' '||c.document_version, ', ' ORDER BY c.consent_type) FROM user_consents c JOIN users u USING(user_id) WHERE u.email='${e}'`));
  await ctx.close(); process.exit(0);
})().catch(e => { console.log('ERROR', e.message); process.exit(1); });
