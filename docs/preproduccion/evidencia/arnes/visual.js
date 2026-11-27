// Auditoria Mobile (preproduccion): capturas de la app real (Flutter web release) contra el Backend LOCAL
// (IA apagada, base aislada). Solo cuentas sinteticas @audit.local. Nunca el usuario 48 ni produccion.
// Uso: AUDIT_PASSWORD=... ACCOUNT_PLAN=<correo con plan> SHOTS=<dir> node visual.js
const { chromium } = require('playwright');
const fs = require('fs');
const PASS = process.env.AUDIT_PASSWORD;
const SHOTS = process.env.SHOTS;
const APP = 'http://localhost:5050/';
const API = 'http://localhost:8080/api/v1';
fs.mkdirSync(SHOTS, { recursive: true });
const log = (...a) => console.log(new Date().toISOString().slice(11, 19), ...a);

async function open({ width = 390, height = 844, blockGifs = false } = {}) {
  const browser = await chromium.launch({ proxy: process.env.HTTPS_PROXY ? { server: process.env.HTTPS_PROXY, bypass: 'localhost,127.0.0.1' } : undefined });
  const ctx = await browser.newContext({ viewport: { width, height }, deviceScaleFactor: 2, locale: 'es-PE' });
  const p = await ctx.newPage();
  // Entorno de la auditoria: gstatic.com no es accesible; CanvasKit se sirve desde la propia compilacion web.
  await p.route(/gstatic\.com\/flutter-canvaskit\/[^/]+\/(.*)$/, async r => {
    const rel = r.request().url().match(/flutter-canvaskit\/[^/]+\/(.*)$/)[1];
    const file = (process.env.WEB_DIR || '') + '/canvaskit/' + rel;
    if (!fs.existsSync(file)) return r.abort();
    await r.fulfill({ body: fs.readFileSync(file), contentType: rel.endsWith('.wasm') ? 'application/wasm' : 'text/javascript' });
  });
  if (blockGifs) await p.route(/raw\.githubusercontent\.com/, r => r.abort('internetdisconnected'));
  p.on('response', r => { if (r.url().startsWith(API)) log('  [api]', r.request().method(), r.url().replace(API, ''), r.status()); });
  p.on('requestfailed', r => { if (!r.url().includes('localhost:5050')) log('  [falla]', r.url().slice(0, 110), r.failure()?.errorText); });
  await p.goto(APP);
  await p.waitForSelector('flt-semantics-placeholder, flt-semantics', { state: 'attached', timeout: 60000 });
  await p.waitForTimeout(1500);
  await p.evaluate(() => document.querySelector('flt-semantics-placeholder')?.click());
  await p.waitForTimeout(800);
  return { browser, p };
}

async function nodes(p) {
  return p.$$eval('flt-semantics', ns => ns.map(n => ((n.getAttribute('aria-label') || '') + ' ' + (n.textContent || '')).replace(/\s+/g, ' ').trim()).filter(Boolean));
}
async function waitText(p, text, timeout = 30000) {
  const end = Date.now() + timeout;
  while (Date.now() < end) {
    if ((await nodes(p)).some(s => s.toLowerCase().includes(text.toLowerCase()))) return true;
    await p.waitForTimeout(400);
  }
  return false;
}
async function tap(p, text, { role, exact } = {}) {
  const end = Date.now() + 15000;
  while (Date.now() < end) {
    const hits = await p.$$eval('flt-semantics', (ns, [text, role, exact]) => {
      const m = n => { const s = ((n.getAttribute('aria-label') || '') + ' ' + (n.textContent || '')).replace(/\s+/g, ' ').trim();
        return exact ? (n.getAttribute('aria-label') === text || (n.textContent || '').trim() === text) : s.toLowerCase().includes(text.toLowerCase()); };
      const c = ns.filter(n => m(n) && (!role || n.getAttribute('role') === role));
      const cl = c.filter(n => ['button', 'link', 'tab', 'checkbox', 'radio', 'switch', 'menuitem', 'option'].includes(n.getAttribute('role')) || n.hasAttribute('flt-tappable'));
      const pick = cl.length ? cl : c;
      return pick.filter(n => !pick.some(o => o !== n && n.contains(o))).map(n => { const r = n.getBoundingClientRect(); return [r.x + r.width / 2, r.y + r.height / 2, r.width]; }).filter(r => r[2] > 0);
    }, [text, role, exact]);
    if (hits.length) {
      const [x, y] = hits[hits.length - 1]; const { width: vw, height: vh } = p.viewportSize();
      if (y > vh - 8 || y < 8) { await p.mouse.move(vw / 2, vh / 2); await p.mouse.wheel(0, y > vh ? Math.min(y - vh / 2, 600) : Math.max(y - vh / 2, -600)); await p.waitForTimeout(500); continue; }
      await p.mouse.click(x, y); await p.waitForTimeout(700); return;
    }
    await p.waitForTimeout(400);
  }
  throw new Error('No encontrado: ' + text);
}
async function fill(p, label, value) {
  const end = Date.now() + 15000;
  while (Date.now() < end) {
    const r = await p.$$eval('flt-semantics, input, textarea', (ns, label) => {
      const n = ns.find(n => (n.getAttribute('aria-label') || '').toLowerCase().includes(label.toLowerCase()) && (n.tagName === 'INPUT' || n.tagName === 'TEXTAREA' || n.getAttribute('role') === 'textbox' || n.querySelector('input,textarea')));
      if (!n) return null; const b = n.getBoundingClientRect(); return [b.x + b.width / 2, b.y + b.height / 2];
    }, label);
    const vh = p.viewportSize().height;
    if (r && (r[1] > vh - 8 || r[1] < 8)) { await p.mouse.move(p.viewportSize().width / 2, vh / 2); await p.mouse.wheel(0, r[1] > vh ? 500 : -500); await p.waitForTimeout(500); continue; }
    if (r) { await p.mouse.click(r[0], r[1]); await p.waitForTimeout(300); await p.keyboard.press('Control+A'); await p.keyboard.type(value, { delay: 5 }); await p.waitForTimeout(200); return; }
    await p.waitForTimeout(400);
  }
  throw new Error('Sin campo: ' + label);
}
async function scroll(p, dy) { await p.mouse.move(p.viewportSize().width / 2, p.viewportSize().height / 2); await p.mouse.wheel(0, dy); await p.waitForTimeout(700); }
async function shot(p, name) { await p.screenshot({ path: `${SHOTS}/${name}.png` }); log('  captura', name); }
async function login(p, email) {
  await tap(p, 'INICIA SESIÓN'); await fill(p, 'Correo', email); await fill(p, 'Contraseña', PASS);
  await tap(p, 'INICIAR SESIÓN');
}

const steps = JSON.parse(fs.readFileSync(__dirname + '/perfil.json', 'utf8'));
async function perfil(p) {
  for (const a of steps) {
    if (a.tap) await tap(p, a.tap, a); else if (a.fill) await fill(p, a.fill, a.value);
    else if (a.wait) await p.waitForTimeout(a.wait); else if (a.scroll) await scroll(p, a.scroll);
  }
}

(async () => {
  const which = process.argv[2] || 'todo';

  if (which === 'todo' || which === 'registro') {
    log('A · Registro, inicio de sesion y recuperacion');
    const { browser, p } = await open();
    await shot(p, 'A1-bienvenida');
    await tap(p, 'COMENZAR AHORA'); await p.waitForTimeout(800); await shot(p, 'A2-registro-arriba');
    await scroll(p, 900); await shot(p, 'A3-registro-abajo-participacion-zona');
    await tap(p, 'Iniciar sesión', { role: 'button' }); await p.waitForTimeout(800); await shot(p, 'A4-login');
    await tap(p, 'Olvidaste'); await p.waitForTimeout(900); await shot(p, 'A5-recuperar-correo');
    await browser.close();
    const s = await open({ width: 320, height: 568 });
    await tap(s.p, 'COMENZAR AHORA'); await s.p.waitForTimeout(800); await shot(s.p, 'A6-registro-320x568');
    await s.browser.close();
  }

  if (which === 'todo' || which === 'noparticipa') {
    log('B · Persona que deja desmarcada la casilla «Opcional» de participacion');
    const email = `audit-ui-noparticipa-${Date.now()}@audit.local`;
    const { browser, p } = await open();
    await tap(p, 'COMENZAR AHORA');
    await fill(p, 'Nombres', 'Auditoria'); await fill(p, 'Apellidos', 'Sin participar');
    await fill(p, 'Correo', email); await fill(p, 'Contraseña', PASS); await fill(p, 'Confirmar', PASS);
    await tap(p, 'CREAR CUENTA');
    if (!await waitText(p, 'INICIAR SESIÓN', 15000)) throw new Error('sin login tras registro');
    await p.waitForTimeout(1500); await fill(p, 'Correo', email); await fill(p, 'Contraseña', PASS); await shot(p, 'B0-login-tras-registro'); await tap(p, 'INICIAR SESIÓN');
    if (!await waitText(p, 'Paso 1 de 5', 20000)) { await shot(p, 'B0-error'); throw new Error('no llego al perfil'); }
    await perfil(p);
    await tap(p, 'Generar mi plan');
    if (await waitText(p, 'Ahora no', 6000)) { await shot(p, 'B1-explicacion-avisos'); await tap(p, 'Ahora no'); }
    await p.waitForTimeout(12000); await shot(p, 'B2-generando');
    await p.waitForTimeout(22000); await shot(p, 'B3-tras-30-segundos');
    await browser.close();
  }

  if (which === 'todo' || which === 'rutina') {
    log('C · Rutina, ejercicio, registro y progreso (cuenta sintetica con plan)');
    const email = process.env.ACCOUNT_PLAN;
    const { browser, p } = await open();
    await login(p, email);
    if (await waitText(p, 'Soy Kapi', 8000)) { for (let i = 0; i < 12 && !(await waitText(p, 'Terminar', 400)); i++) { const t = (await nodes(p)).join('|'); const n = ['Empezar', 'Ir a Rutinas', 'Ir a Progreso', 'Ir a Perfil', 'Siguiente'].find(x => t.includes(x)); if (n) await tap(p, n, { role: 'button' }); await p.waitForTimeout(700); } await tap(p, 'Terminar', { role: 'button' }); }
    if (await waitText(p, 'Ver mi plan', 8000)) await tap(p, 'Ver mi plan');
    await waitText(p, 'Hola', 20000); await p.waitForTimeout(1500);
    await shot(p, 'C1-inicio'); await scroll(p, 700); await shot(p, 'C2-inicio-abajo');
    await tap(p, 'Rutinas', { role: 'tab' }).catch(() => tap(p, 'Rutinas')); await p.waitForTimeout(1200); await shot(p, 'C3-rutinas');
    await scroll(p, 1100); await tap(p, 'Programado'); await p.waitForTimeout(5000); await shot(p, 'C4-rutina-arriba-gif');
    await scroll(p, 420); await shot(p, 'C5-rutina-primer-ejercicio-completo');
    await tap(p, 'Ver instrucciones'); await p.waitForTimeout(2500); await shot(p, 'C6-instrucciones');
    await p.mouse.click(195, 120); await p.waitForTimeout(1000);
    for (let i = 0; i < 14 && !(await waitText(p, 'Comenzar entrenamiento', 300)) && !(await waitText(p, 'Finalizar sesión', 300)); i++) await scroll(p, 900); await shot(p, 'C6b-final-de-la-rutina-botones'); if (await waitText(p, 'Comenzar entrenamiento', 500)) await tap(p, 'Comenzar entrenamiento'); await p.waitForTimeout(2500); await scroll(p, -9000); await scroll(p, -9000); await shot(p, 'C7-sesion-en-curso');
    await tap(p, 'Registrar ejercicio'); await p.waitForTimeout(2000); await shot(p, 'C8-dialogo-resultado');
    await tap(p, 'Lo hice parcialmente'); await p.waitForTimeout(600); await shot(p, 'C9-dialogo-parcial');
    await tap(p, 'Cancelar'); await p.waitForTimeout(600);
    for (let i = 0; i < 12 && !(await waitText(p, 'Finalizar sesión', 300)); i++) await scroll(p, 900); await shot(p, 'C9b-final-sesion-botones'); await tap(p, 'Finalizar sesión'); await p.waitForTimeout(1200); await scroll(p, -9000); await scroll(p, -9000); await shot(p, 'C10-finalizar-sin-registrar-todo');
    await browser.close();
  }
  if (which === 'resto') {
    const email = process.env.ACCOUNT_PLAN;
    const s = await open({ width: 320, height: 568 });
    await login(s.p, email); await waitText(s.p, 'Hola', 20000); await s.p.waitForTimeout(1200); await shot(s.p, 'D1-inicio-320x568');
    await tap(s.p, 'Rutinas'); await s.p.waitForTimeout(1000); await scroll(s.p, 1600); await tap(s.p, 'Programado'); await s.p.waitForTimeout(5000); await shot(s.p, 'D2-rutina-320x568');
    
    await s.browser.close();

    const g = await open({ blockGifs: true });
    await login(g.p, email); await waitText(g.p, 'Hola', 20000); await tap(g.p, 'Rutinas'); await g.p.waitForTimeout(1000);
    await scroll(g.p, 1100); await tap(g.p, 'Programado'); await g.p.waitForTimeout(3500); await scroll(g.p, 200); await shot(g.p, 'E1-gif-sin-conexion');
    await g.browser.close();

    const f = await open();
    await login(f.p, email); await waitText(f.p, 'Hola', 20000);
    await tap(f.p, 'Progreso'); await f.p.waitForTimeout(1500); await shot(f.p, 'F1-progreso');
    await tap(f.p, 'Perfil'); await f.p.waitForTimeout(1200); await shot(f.p, 'F2-perfil'); await scroll(f.p, 900); await shot(f.p, 'F3-perfil-abajo');
    await tap(f.p, 'Cuenta'); await f.p.waitForTimeout(1500); await shot(f.p, 'F4-cuenta');
    await f.browser.close();
  }
  log('fin');
})().catch(e => { console.error('ERROR', e.message); process.exit(1); });
