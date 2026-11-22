// Etapa 3: repaso del recorrido de Kapi, recordatorios (preferencias), cerrar e iniciar sesión, y eliminación.
const A = require('./aud-lib'); const { k, db, check, shot } = A;
const { abrir, intentar } = require('./eliminar-lib');
const st = JSON.parse(require('fs').readFileSync(__dirname + '/aud-state.json'));
const E = st.E, N = st.N;
const uid = db.q(`SELECT user_id FROM users WHERE email='${E}'`);
const ops = () => db.q(`SELECT count(*) FROM plan_generation_operations WHERE user_id=${uid}`);
let CTX = null;
(async () => {
  let { ctx, p } = await k.open('aud-' + E); CTX = ctx;
  await k.waitText(p, `Hola, ${N}`, 20000); await p.waitForTimeout(1200);
  // 1. Kapi: repaso del recorrido desde Perfil, sin generar nada.
  const antes = ops();
  await k.tap(p, 'Perfil', { role: 'tab' }); await p.waitForTimeout(1500);
  await k.tap(p, 'Ver recorrido de Kora'); await p.waitForTimeout(1500);
  check('Kapi', 'el repaso del recorrido abre con Kapi', await k.waitText(p, 'Soy Kapi', 10000));
  await shot(p, 'A3-repaso-kapi');
  await A.terminarTour(p).catch(() => {});
  check('Kapi', 'al terminar el repaso vuelve a la app y no pide otra generación', ops() === antes && (await A.texts(p)).join(' ').includes('Perfil'), `operaciones ${antes} → ${ops()}`);
  // 2. Recordatorios: la hoja guarda las preferencias (la programación nativa se prueba en Android).
  await k.tap(p, 'Perfil', { role: 'tab' }).catch(() => {}); await p.waitForTimeout(1200);
  await k.tap(p, 'Recordatorios'); await p.waitForTimeout(1500); await shot(p, 'A3-recordatorios');
  const rec = (await A.texts(p)).join(' ');
  check('Notificaciones', 'la hoja de recordatorios muestra la hora del aviso y el aviso de vencimiento', rec.includes('Recordarme mis entrenamientos') && rec.includes('Hora del aviso') && rec.includes('si sigue pendiente'));
  await p.keyboard.press('Escape'); await p.waitForTimeout(800);
  // 3. Cerrar sesión e iniciar sesión otra vez: va al inicio, no al perfil inicial.
  await k.tap(p, 'Perfil', { role: 'tab' }).catch(() => {}); await p.waitForTimeout(1200);
  await p.mouse.move(195, 420); for (let i = 0; i < 12; i++) await p.mouse.wheel(0, 500); await p.waitForTimeout(600);
  await k.tap(p, 'Cerrar sesión'); await p.waitForTimeout(1200);
  if ((await A.texts(p)).join(' ').includes('¿Cerrar sesión?')) { await k.tap(p, 'Cerrar sesión', { role: 'button', exact: true }); await p.waitForTimeout(1500); }
  check('Sesión', 'cerrar sesión lleva al inicio de sesión', await k.waitText(p, 'INICIAR SESIÓN', 15000));
  await k.fill(p, 'Correo', E); await k.fill(p, 'Contraseña', A.PASS); await k.tap(p, 'INICIAR SESIÓN');
  check('Sesión', 'volver a iniciar sesión entra al inicio con su plan (sin repetir el perfil ni el recorrido)', await k.waitText(p, `Hola, ${N}`, 20000) && !(await A.texts(p)).join(' ').includes('Soy Kapi'));
  // 4. Eliminación de la cuenta con contraseña y confirmación.
  await abrir(p); await shot(p, 'A3-eliminar');
  await intentar(p, A.PASS);
  await shot(p, 'A3-eliminada');
  const quedan = db.q(`SELECT count(*) FROM users WHERE email='${E}'`);
  const confirmada = await k.waitText(p, 'Tu cuenta fue eliminada', 10000);
  await k.tap(p, 'Salir', { role: 'button' }).catch(() => {}); await p.waitForTimeout(1500);
  check('Cuenta', 'eliminar mi cuenta: «Tu cuenta fue eliminada», «Salir» lleva al inicio de sesión y la cuenta ya no existe en PostgreSQL', confirmada && quedan === '0' && await k.waitText(p, 'INICIAR SESIÓN', 15000), `usuarios con ese correo: ${quedan}`);
  check('Cuenta', 'sus planes y sesiones tampoco quedan', db.q(`SELECT (SELECT count(*) FROM weekly_training_plans WHERE user_id=${uid}) + (SELECT count(*) FROM workout_sessions WHERE user_id=${uid}) + (SELECT count(*) FROM plan_generation_operations WHERE user_id=${uid})`) === '0');
  A.save(__dirname + '/aud3.json'); await ctx.close();
})().catch(async e => { console.log('ERROR', e.message); A.save(__dirname + '/aud3.json'); await CTX?.close().catch(() => {}); process.exit(1); });
