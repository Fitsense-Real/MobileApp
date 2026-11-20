const { E2E_PASSWORD } = require('./credenciales');
// 202 PENDING: cuenta nueva con rutina; psql retiene una fila de su plan 40 s, la fase 2 agota lock_timeout (5 s).
const { k, db, nuevo, terminarTour, log } = require('./lib'); const { abrir, intentar, texto } = require('./eliminar-lib');
const { spawn } = require('child_process');
const e = 'del4@e2e.local';
(async () => {
  const { ctx, p } = await k.open('del4');
  if (await k.waitText(p, 'Ver mi plan', 6000)) { await k.tap(p, 'Ver mi plan', { role: 'button' }); }
  await k.waitText(p, 'Hola, Diego', 30000);
  log('plan:', db.q(`SELECT count(*) FROM weekly_training_plans w JOIN users u USING(user_id) WHERE u.email='${e}'`));
  const lock = spawn('psql', ['-h', 'localhost', '-U', 'postgres', '-d', 'fitsense_int', '-c',
    `BEGIN; SELECT plan_id FROM weekly_training_plans WHERE user_id = (SELECT user_id FROM users WHERE email='${e}') FOR UPDATE; SELECT pg_sleep(40); COMMIT;`],
    { env: process.env, stdio: 'ignore' });
  await p.waitForTimeout(1500);
  await abrir(p);
  await intentar(p, E2E_PASSWORD);
  await p.waitForTimeout(6000);
  await k.dump(p, 'resultado'); await k.shot(p, 'F-eliminar-202');
  log('BD:', db.q(`SELECT a.status||' intentos='||a.attempts||' error='||coalesce(a.last_error,'-')||' users.status='||coalesce(u.status,'(borrado)') FROM account_deletions a LEFT JOIN users u USING(user_id) ORDER BY a.requested_at DESC LIMIT 1`));
  // otro intento de entrar mientras está pendiente
  await k.tap(p, 'Salir', { role: 'button' }).catch(() => {}); await p.waitForTimeout(1500);
  await k.fill(p, 'Correo', e); await k.fill(p, 'Contraseña', E2E_PASSWORD);
  await k.tap(p, 'INICIAR SESIÓN', { role: 'button' }); await p.waitForTimeout(2500);
  log('login con la eliminación pendiente → sigue en login:', !(await k.waitText(p, 'Hola, Diego', 2000)));
  await ctx.close(); lock.kill(); process.exit(0);
})().catch(e => { console.log('ERROR', e.message); process.exit(1); });
