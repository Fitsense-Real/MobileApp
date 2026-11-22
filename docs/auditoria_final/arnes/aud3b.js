// Repetición aislada de la eliminación (cuenta sintética con perfil y plan creada por HTTP).
const A = require('./aud-lib'); const { k, db, check, shot } = A; const { abrir, intentar } = require('./eliminar-lib');
const E = process.env.EMAIL; const uid = db.q(`SELECT user_id FROM users WHERE email='${E}'`);
let CTX = null;
(async () => {
  const { ctx, p } = await k.open('aud-' + E); CTX = ctx;
  await k.tap(p, 'INICIA SESIÓN', { role: 'button' }); await p.waitForTimeout(1000);
  await k.fill(p, 'Correo', E); await k.fill(p, 'Contraseña', A.PASS); await k.tap(p, 'INICIAR SESIÓN');
  if (await k.waitText(p, 'Soy Kapi', 15000)) await A.terminarTour(p);
  if (await k.waitText(p, 'Ver mi plan', 15000)) await k.tap(p, 'Ver mi plan', { role: 'button' });
  await k.waitText(p, 'Hola', 15000);
  await abrir(p); await intentar(p, A.PASS);
  const confirmada = await k.waitText(p, 'Tu cuenta fue eliminada', 10000); await shot(p, 'A3-eliminada');
  await k.tap(p, 'Salir', { role: 'button' }); await p.waitForTimeout(1500);
  const quedan = db.q(`SELECT count(*) FROM users WHERE email='${E}'`);
  check('Cuenta', 'eliminar mi cuenta: «Tu cuenta fue eliminada», «Salir» lleva al inicio de sesión y la cuenta ya no existe en PostgreSQL', confirmada && quedan === '0' && await k.waitText(p, 'INICIAR SESIÓN', 15000), `usuarios con ese correo: ${quedan}`);
  check('Cuenta', 'sus planes, sesiones y operaciones tampoco quedan', db.q(`SELECT (SELECT count(*) FROM weekly_training_plans WHERE user_id=${uid}) + (SELECT count(*) FROM workout_sessions WHERE user_id=${uid}) + (SELECT count(*) FROM plan_generation_operations WHERE user_id=${uid})`) === '0');
  A.save(__dirname + '/aud3b.json'); await ctx.close();
})().catch(async e => { console.log('ERROR', e.message); A.save(__dirname + '/aud3b.json'); await CTX?.close().catch(() => {}); process.exit(1); });
