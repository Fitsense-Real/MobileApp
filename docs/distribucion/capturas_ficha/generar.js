// Borradores de capturas para la ficha de Play: 1080×1920 (360×640 a ×3), cuenta sintética, backend local.
const { chromium } = require('playwright');
const k = require('./kora'); const registrar = require('./register'); const perfil = require('./profile');
const A = require('./aud-lib');
const out = n => __dirname + '/shots-play/' + n + '.png';
(async () => {
  const ctx = await chromium.launchPersistentContext(__dirname + '/profiles/play-' + Date.now(), { viewport: { width: 360, height: 640 }, deviceScaleFactor: 3 });
  const p = ctx.pages()[0] || await ctx.newPage();
  await p.goto('http://localhost:5050/'); await k.semantics(p);
  await p.waitForTimeout(1500); await p.screenshot({ path: out('1-bienvenida') });
  await registrar(p, 'Valeria', process.env.EMAIL);
  process.env.P1 = './p1-ux.json'; await perfil(p);
  await p.mouse.move(180, 320); await p.mouse.wheel(0, 3000); await p.waitForTimeout(400);
  await k.tap(p, 'Continuar'); await p.waitForTimeout(800); await p.mouse.wheel(0, 3000); await p.waitForTimeout(400);
  await k.tap(p, 'Generar mi plan', { role: 'button' }); await p.waitForTimeout(10500);
  await p.screenshot({ path: out('2-generando-kapi') });
  await k.waitText(p, 'Soy Kapi', 40000); await p.waitForTimeout(1200); await p.screenshot({ path: out('3-recorrido-kapi') });
  await A.terminarTour(p); await k.waitText(p, 'Ver mi plan', 30000); await k.tap(p, 'Ver mi plan', { role: 'button' });
  await k.waitText(p, 'Hola, Valeria', 20000); await p.waitForTimeout(2500); await p.screenshot({ path: out('4-inicio') });
  await k.tap(p, 'Rutinas', { role: 'tab' }); await p.waitForTimeout(1500);
  await p.mouse.move(180, 320); await p.mouse.wheel(0, 900); await p.waitForTimeout(1200); await p.screenshot({ path: out('5-rutinas') });
  const plan = A.api(process.env.EMAIL, '/users/me/plan/current');
  await A.abrirRutina(p, plan.workouts[0].scheduledDate, plan.workouts.map(w => w.scheduledDate)); await p.waitForTimeout(3500);
  await p.screenshot({ path: out('6-rutina-detalle') });
  await ctx.close();
})().catch(e => { console.log('ERROR', e.message); process.exit(1); });
