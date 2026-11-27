// F01–F09 con la cuenta Demo Kora en la COPIA LOCAL del dataset (fitsense_av48), app Kora real (web profile, generation
// 76dcf34) contra el Backend real 77b9df3 (IA apagada). Solo lectura: se registra cada petición y se exige que, aparte del
// login, todas sean GET. No se pulsa nada que escriba (ni registrar, ni omitir, ni «Ya no me duele», ni generar).
const fs = require('fs');
const k0 = require('./kora');
const B = 'http://localhost:8091/api/v1';
const log = (...a) => console.log(new Date().toISOString().slice(11, 19), ...a);
const results = [];
function check(id, what, ok, detail = '') { results.push({ id, what, ok: !!ok, detail }); log(`${ok ? 'OK  ' : 'FALLA'} [${id}] ${what}${detail ? ' — ' + detail : ''}`); }
const texts = async p => (await p.$$eval('flt-semantics', ns => ns.map(n => ((n.getAttribute('aria-label') || '') + ' ' + (n.textContent || '')).replace(/\s+/g, ' ').trim()).filter(Boolean))).join(' | ');
const shot = (p, n) => p.screenshot({ path: __dirname + '/shots/' + n + '.png' });
async function alInicio(p) { await p.mouse.move(195, 420); for (let i = 0; i < 25; i++) await p.mouse.wheel(0, -800); await p.waitForTimeout(700); }
async function todo(p, pasos = 30) {
  const seen = new Set(); await alInicio(p);
  for (let i = 0; i < pasos; i++) { for (const t of (await texts(p)).split(' | ')) seen.add(t); await p.mouse.wheel(0, 350); await p.waitForTimeout(200); }
  await alInicio(p); return [...seen].join(' | ');
}
async function volver(p) { await alInicio(p); await k0.tap(p, 'Volver').catch(() => p.keyboard.press('Escape')); await p.waitForTimeout(1500); }

(async () => {
  // Navegador nuevo apuntando a la web del puerto 5052 (Backend 8091).
  const { chromium } = require('playwright');
  const ctx = await chromium.launchPersistentContext(__dirname + '/profiles/demo48-' + Date.now(), { viewport: { width: 390, height: 844 }, deviceScaleFactor: 1 });
  const p = ctx.pages()[0] || await ctx.newPage();
  const reqs = [];
  p.on('request', r => { if (r.url().startsWith(B)) reqs.push({ m: r.method(), path: r.url().slice(B.length), t: Date.now() }); });
  await p.goto('http://localhost:5052/'); await k0.semantics(p);

  // F01 · inicio de sesión
  await k0.waitText(p, 'COMENZAR AHORA', 20000); await k0.tap(p, 'INICIA SESIÓN', { role: 'button' }); await k0.waitText(p, 'INICIAR SESIÓN', 15000);
  await k0.fill(p, 'Correo', 'usuario.demo.kora@example.com'); await k0.fill(p, 'Contraseña', process.env.KORA_DEMO_PASSWORD); await k0.tap(p, 'INICIAR SESIÓN');
  const entra = await k0.waitText(p, 'Hola, Usuario', 20000); await p.waitForTimeout(3000);
  let t = await todo(p); await shot(p, 'F01-inicio');
  check('F01', 'Inicio de sesión: entra a Inicio con su nombre', entra && t.includes('Hola, Usuario'));
  check('F06', 'Inicio · «Tu progreso» con la última semana medida (100 %, 5/5)', /100\s?%/.test(t) && t.includes('5/5'), (t.match(/[^|]{0,40}Tu progreso[^|]{0,80}/) || [''])[0]);

  // F03 · rutina vigente
  await k0.tap(p, 'Rutinas', { role: 'tab' }); await p.waitForTimeout(2500);
  t = await todo(p); await shot(p, 'F03-rutinas');
  const focos = ['Empuje', 'Traccion', 'Piernas', 'Tren superior', 'Tren inferior'].filter(f => t.includes(f));
  check('F03', 'Rutina vigente: los 5 entrenamientos de la semana del 23/11', focos.length === 5, focos.join(', '));
  check('F08', 'Ningún entrenamiento vigente contiene el ejercicio excluido (1025) ni aparece «No disponible por ahora»', !t.includes('Aperturas de pecho sentado con palanca') && !t.includes('No disponible por ahora'));

  // F06/F07 · Progreso: adherencia e historial de adaptaciones
  await k0.tap(p, 'Progreso', { role: 'tab' }); await p.waitForTimeout(3000);
  t = await todo(p, 40); await shot(p, 'F06-progreso');
  check('F06', 'Progreso: adherencia de la última semana medida (100 %)', /100\s?%/.test(t));
  const p2 = ['Tu rutina avanzó un paso', 'Tu rutina se mantiene igual', 'Se sustituyó un ejercicio por seguridad'].filter(x => t.includes(x));
  check('F07', 'P2: «Historial de adaptaciones» con las 3 semanas en lenguaje natural', /historial de adaptaciones/i.test(t) && p2.length === 3, p2.join(' · '));
  check('F07', 'Sin códigos técnicos en Progreso (ADAPT_LOCALIZED, NO_CHANGE…)', !/\b[A-Z]{2,}_[A-Z_]{2,}\b/.test(t), (t.match(/\b[A-Z]{2,}_[A-Z_]{2,}\b/) || [''])[0]);

  // F02 · perfil
  await k0.tap(p, 'Perfil', { role: 'tab' }); await p.waitForTimeout(2500);
  t = await todo(p); await shot(p, 'F02-perfil');
  const cabecera = t.includes('Usuario Demo Kora') && t.includes('usuario.demo.kora@example.com');
  await k0.tap(p, 'Cuenta'); await p.waitForTimeout(2500); t = await todo(p, 20); await shot(p, 'F02-cuenta');
  check('F02', 'Perfil: nombre y correo; en «Cuenta», objetivo, altura y peso', cabecera && /176/.test(t) && /74/.test(t) && (t.includes('Ganar masa muscular') || t.includes('GANAR MASA')), (t.match(/[^|]{0,30}(Ganar masa|GANAR MASA)[^|]{0,60}/i) || [''])[0]);

  await volver(p); if (!(await k0.waitText(p, 'Historial de planes', 2000))) { await k0.tap(p, 'Perfil', { role: 'tab' }).catch(() => {}); await p.waitForTimeout(1500); }
  // F04/F05 · historial de planes y de sesiones
  await k0.tap(p, 'Historial de planes'); await p.waitForTimeout(3000);
  t = await todo(p); await shot(p, 'F04-historial-planes');
  const etiquetas = ['Vigente · 5 días · Progresión', 'Completado · 5 días · Sin cambios', 'Completado · 5 días · Sustitución por seguridad'].filter(x => t.includes(x));
  const semanas = ['23/11/2026', '16/11/2026', '09/11/2026', '02/11/2026'].filter(x => t.includes(x));
  check('F04', 'Historial de planes: 4 semanas con etiquetas comprensibles', semanas.length === 4 && etiquetas.length === 3, `${semanas.length} semanas; ${etiquetas.join(' | ')}`);
  check('F07', 'Historial de planes sin códigos (ADAPT_LOCALIZED)', !t.includes('ADAPT_') && !/\b[A-Z]{2,}_[A-Z_]{2,}\b/.test(t));
  await k0.tap(p, 'Semana del 02/11/2026'); await p.waitForTimeout(3000);
  t = await todo(p); await shot(p, 'F05-semana-02-11');
  const cuenta = s => (t.split(' | ').filter(x => x.includes(s)).length);
  check('F05', 'Sesiones de la semana del 02/11: completados, parcial y omitido', t.includes('Completado') && t.includes('Parcial') && t.includes('Omitido'), `Completado×${cuenta('Completado')} Parcial×${cuenta('Parcial')} Omitido×${cuenta('Omitido')}`);
  await volver(p); await volver(p);

  // F08 · exclusión O20
  if (!(await k0.waitText(p, 'Ejercicios excluidos por dolor', 2000))) { await k0.tap(p, 'Perfil', { role: 'tab' }).catch(() => {}); await p.waitForTimeout(1500); }
  await k0.tap(p, 'Ejercicios excluidos por dolor'); await p.waitForTimeout(3000);
  t = await todo(p, 15); await shot(p, 'F08-exclusiones');
  check('F08', 'O20: el 1025 aparece excluido por dolor (05/11/2026)', t.includes('Aperturas de pecho sentado con palanca') && t.includes('05/11/2026'), (t.match(/[^|]{0,30}Aperturas de pecho[^|]{0,80}/) || [''])[0]);
  await p.keyboard.press('Escape'); await p.waitForTimeout(800); await volver(p).catch(() => {});

  // F09 · al volver del segundo plano, la app vuelve a pedir la rutina y las exclusiones
  await k0.tap(p, 'Rutinas', { role: 'tab' }).catch(() => {}); await p.waitForTimeout(2000);
  const antes = Date.now();
  await p.evaluate(() => { Object.defineProperty(document, 'visibilityState', { value: 'hidden', configurable: true }); Object.defineProperty(document, 'hidden', { value: true, configurable: true }); document.dispatchEvent(new Event('visibilitychange')); });
  await p.waitForTimeout(3000);
  await p.evaluate(() => { Object.defineProperty(document, 'visibilityState', { value: 'visible', configurable: true }); Object.defineProperty(document, 'hidden', { value: false, configurable: true }); document.dispatchEvent(new Event('visibilitychange')); });
  await p.waitForTimeout(4000);
  const tras = reqs.filter(r => r.t > antes).map(r => r.m + ' ' + r.path);
  check('F09', 'Al volver del segundo plano se vuelven a pedir la rutina vigente y las exclusiones', tras.some(x => x.includes('/users/me/plan/current')) && tras.some(x => x.includes('/pain-exclusions')), [...new Set(tras)].join(', '));

  // Solo lectura: aparte del login, ninguna petición que no sea GET.
  const escrituras = reqs.filter(r => r.m !== 'GET' && r.m !== 'OPTIONS' && r.path !== '/auth/login');
  check('F01-F09', 'Solo lectura: ninguna petición de escritura (aparte del login)', escrituras.length === 0, `${reqs.length} peticiones; métodos: ${[...new Set(reqs.map(r => r.m))].join(', ')}${escrituras.length ? '; ESCRITURAS: ' + escrituras.map(r => r.m + ' ' + r.path).join(', ') : ''}`);
  await ctx.close();
  fs.writeFileSync(__dirname + '/resultados-demo48.json', JSON.stringify({ results, peticiones: reqs.map(r => r.m + ' ' + r.path) }, null, 1));
  log(`${results.filter(r => r.ok).length}/${results.length} comprobaciones superadas`);
  process.exit(results.every(r => r.ok) ? 0 : 1);
})().catch(e => { console.log('ERROR', e.message); fs.writeFileSync(__dirname + '/resultados-demo48.json', JSON.stringify({ results }, null, 1)); process.exit(2); });
