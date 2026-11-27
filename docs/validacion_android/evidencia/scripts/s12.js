// S12 · 401 real: el Backend deja de aceptar el token (token_version + 1, lo mismo que al cambiar la contraseña o retirarse).
const { execFileSync } = require('child_process');
const fs = require('fs');
const k = require('./kora');
const [A] = fs.readFileSync(__dirname + '/cuentas-s12.txt', 'utf8').trim().split('\n');
const q = sql => execFileSync('psql', ['-h', 'localhost', '-U', 'postgres', '-d', 'fitsense_avs', '-At', '-c', sql], { env: { ...process.env, PGPASSWORD: 'x' } }).toString().trim();
const log = (...a) => console.log(new Date().toISOString().slice(11, 19), ...a);
(async () => {
  const { ctx, p } = await k.open('s12-' + Date.now());
  const st = []; p.on('response', r => { if (r.url().includes(':8092/')) st.push(r.status() + ' ' + r.request().method() + ' ' + r.url().split('/api/v1')[1]); });
  await k.waitText(p, 'COMENZAR AHORA', 20000); await k.tap(p, 'INICIA SESIÓN', { role: 'button' }); await k.waitText(p, 'INICIAR SESIÓN', 15000);
  await k.fill(p, 'Correo', A); await k.fill(p, 'Contraseña', 'Sintetica-av-x9'); await k.tap(p, 'INICIAR SESIÓN');
  await k.waitText(p, 'Hola, Sintetico', 20000); await p.waitForTimeout(2000);
  q(`update users set token_version = token_version + 1 where email='${A}'`);
  const desde = st.length;
  await k.tap(p, 'Rutinas', { role: 'tab' }); await p.waitForTimeout(1500);
  if (!(await k.waitText(p, 'INICIAR SESIÓN', 3000))) { await k.tap(p, 'Progreso', { role: 'tab' }).catch(() => {}); } await p.waitForTimeout(3000);
  await p.screenshot({ path: __dirname + '/shots/S12-401.png' });
  const t = (await k.tree(p)).map(x => x.join(' ')).join(' | ');
  const r401 = st.slice(desde).filter(s => s.startsWith('401'));
  const enLogin = t.includes('INICIAR SESIÓN');
  log(`${enLogin && r401.length ? 'OK  ' : 'FALLA'} [S12] 401 real → ${r401.length} respuestas 401 (${[...new Set(r401.map(s => s.slice(4)))].join(', ')}); pantalla de inicio de sesión: ${enLogin}`);
  log('mensaje visible:', (t.match(/[^|]{0,40}(sesi[oó]n[^|]{0,80}(expir|venci|caduc|inicia)|vuelve a)[^|]{0,60}/i) || ['(ninguno)'])[0]);
  fs.writeFileSync(__dirname + '/resultado-s12.json', JSON.stringify({ ok: enLogin && r401.length > 0, r401, enLogin }, null, 1));
  await ctx.close(); process.exit(enLogin && r401.length ? 0 : 1);
})().catch(e => { console.log('ERROR', e.message); process.exit(2); });
