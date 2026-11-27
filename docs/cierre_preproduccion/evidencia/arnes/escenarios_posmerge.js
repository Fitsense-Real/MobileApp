// Escenarios integrales posmerge sobre la generation final (Flutter web release) contra el Backend LOCAL. Mismas ayudas que visual_cierre.js.
// Uso: AUDIT_PASSWORD=... WEB_DIR=<build/web> SHOTS=<dir> ACCOUNT_OTHER=<correo con plan> [ACCOUNT_FIRST=<correo con plan>] node escenarios_posmerge.js todo|cuenta|sinred
// Cierre de preproduccion (Mobile-M6): capturas «después» de la app real (Flutter web release) contra el Backend LOCAL
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
      const content = /^(Ver instrucciones|Registrar ejercicio|Tengo dolor|Programado|Ayuda y soporte|Cuenta)/.test(text);
      const [x, y] = content ? hits[0] : hits[hits.length - 1]; const { width: vw, height: vh } = p.viewportSize();
      // The fixed action bar and the navigation bar cover the bottom: never tap there unless it is the target bar itself.
      const bottom = vh - (/^(Ver instrucciones|Registrar ejercicio|Tengo dolor|Programado|Ayuda y soporte|Cuenta)/.test(text) ? 190 : 8);
      if (y > bottom || y < 8) { await p.mouse.move(vw / 2, vh / 2); await p.mouse.wheel(0, y > bottom ? Math.min(y - vh / 2, 600) : Math.max(y - vh / 2, -600)); await p.waitForTimeout(500); continue; }
      await p.mouse.click(x, y); await p.waitForTimeout(700); return;
    }
    // Content further down is not in the semantics tree until it is near the screen.
    if (/^(Ver instrucciones|Registrar ejercicio|Tengo dolor|Programado|Ayuda y soporte|Cuenta)/.test(text)) await scroll(p, 350);
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


const steps = JSON.parse(fs.readFileSync('/home/user/MobileApp/docs/cierre_preproduccion/evidencia/arnes/perfil.json', 'utf8'));
async function perfil(p) {
  for (const a of steps) {
    if (a.tap) await tap(p, a.tap, a); else if (a.fill) await fill(p, a.fill, a.value);
    else if (a.wait) await p.waitForTimeout(a.wait); else if (a.scroll) await scroll(p, a.scroll);
  }
}

// ---- Escenarios integrales posmerge (generation final) ----
async function tour(p, wait = 8000) {
  if (await waitText(p, 'Soy Kapi', wait)) { for (let i = 0; i < 12 && !(await waitText(p, 'Terminar', 400)); i++) { const t = (await nodes(p)).join('|'); const n = ['Empezar', 'Ir a Rutinas', 'Ir a Progreso', 'Ir a Perfil', 'Siguiente'].find(x => t.includes(x)); if (n) await tap(p, n, { role: 'button' }); await p.waitForTimeout(700); } await tap(p, 'Terminar', { role: 'button' }); }
  if (await waitText(p, 'Ver mi plan', 8000)) await tap(p, 'Ver mi plan');
}
const ok = (name, cond) => { log(cond ? 'OK   ' : 'FALLA', name); if (!cond) process.exitCode = 1; };
(async () => {
  const sel = process.argv[2] || 'todo';
  const email = `audit-ui-posmerge-participa-${Date.now()}@audit.local`;
  if (sel === 'todo' || sel === 'participa') {
    log('S1 · Registro con participación → perfil → generación (motor de reglas)');
    const { browser, p } = await open();
    await tap(p, 'COMENZAR AHORA'); await p.waitForTimeout(800);
    await fill(p, 'Nombres', 'Auditoria'); await fill(p, 'Apellidos', 'Participa');
    await fill(p, 'Correo', email); await fill(p, 'Contraseña', PASS); await fill(p, 'Confirmar', PASS);
    await toBottomLocal(p, 'Acepto participar'); await tap(p, 'Acepto participar en el estudio');
    await toBottomLocal(p, 'CREAR CUENTA'); await tap(p, 'CREAR CUENTA');
    ok('registro con participación entra directo al perfil (sin volver a escribir la clave)', await waitText(p, 'Paso 1 de 5', 25000));
    await perfil(p);
    await toBottomLocal(p, 'Generar mi plan'); await shot(p, 'P1-revision-perfil'); await tap(p, 'Generar mi plan');
    await tour(p, 40000);
    for (let i = 0; i < 60 && !(await waitText(p, 'Ver mi plan', 500)) && (await waitText(p, 'se está preparando', 500)); i++) await p.waitForTimeout(1500);
    if (await waitText(p, 'Ver mi plan', 3000)) await tap(p, 'Ver mi plan');
    ok('plan generado y visible (Inicio)', await waitText(p, 'Hola', 30000) && !(await waitText(p, 'se está preparando', 3000))); await p.waitForTimeout(1500); await shot(p, 'P2-inicio-tras-generar');

    log('S2 · Sesión completa por el camino rápido (Marcar varios + confirmación)');
    await tap(p, 'Rutinas'); await p.waitForTimeout(1500); await tap(p, 'Programado'); await p.waitForTimeout(4000);
    await tap(p, 'Comenzar entrenamiento'); await p.waitForTimeout(2500);
    await tap(p, 'Marcar varios como completados'); await p.waitForTimeout(1000);
    ok('nada viene marcado de antemano', await waitText(p, 'Seleccionar todos', 3000));
    await tap(p, 'Seleccionar todos'); await p.waitForTimeout(500); await shot(p, 'P3-marcar-varios-seleccionados');
    await tap(p, 'Confirmo que hice completos'); await p.waitForTimeout(8000);
    await tap(p, 'Finalizar sesión'); await p.waitForTimeout(1500); await shot(p, 'P4-finalizar-resumen');
    ok('el resumen dice lo registrado', await waitText(p, 'Completados', 3000));
    await tap(p, 'Esfuerzo percibido'); await p.waitForTimeout(800); await tap(p, '6', { exact: true }); await p.waitForTimeout(500);
    await tap(p, 'Finalizar', { exact: true }); await p.waitForTimeout(4000); await shot(p, 'P5-sesion-finalizada');

    log('S3 · P1: un resultado sin conexión queda pendiente y se reintenta');
    await p.goto(APP); await p.waitForTimeout(3000); await p.evaluate(() => document.querySelector('flt-semantics-placeholder')?.click()); await p.waitForTimeout(800);
    await waitText(p, 'Hola', 20000); await tap(p, 'Rutinas'); await p.waitForTimeout(1500);
    await tap(p, 'Programado'); await p.waitForTimeout(4000);
    await tap(p, 'Comenzar entrenamiento'); await p.waitForTimeout(2500);
    const cut = /localhost:8080\/api\/v1\/sessions\/\d+\/exercises\//;
    await p.route(cut, r => r.abort('internetdisconnected'));
    await tap(p, 'Registrar ejercicio'); await p.waitForTimeout(1000); await tap(p, 'Lo completé'); await p.waitForTimeout(500); await tap(p, 'Guardar', { exact: true });
    ok('queda «Pendiente de enviar» (P1)', await waitText(p, 'Pendiente de enviar', 20000)); await shot(p, 'P6-pendiente-de-enviar');
    await p.unroute(cut);
    await tap(p, 'Reintentar envío'); await p.waitForTimeout(6000);
    ok('tras el reintento ya no está pendiente', !(await waitText(p, 'Pendiente de enviar', 2000))); await shot(p, 'P7-tras-reintento');
    await tap(p, 'Abandonar sesión'); await p.waitForTimeout(1000); const t = (await nodes(p)).join('|'); if (/Abandonar/.test(t)) { try { await tap(p, 'Abandonar', { role: 'button' }); } catch (_) {} } await p.waitForTimeout(2000);

    log('S4 · Cierre de sesión y cambio de cuenta');
    await p.goto(APP); await p.waitForTimeout(3000); await p.evaluate(() => document.querySelector('flt-semantics-placeholder')?.click()); await p.waitForTimeout(800);
    await waitText(p, 'Hola', 20000); await tap(p, 'Perfil'); await p.waitForTimeout(1200);
    await toBottomLocal(p, 'Cerrar sesión'); await tap(p, 'Cerrar sesión'); await p.waitForTimeout(2500);
    ok('vuelve a la entrada', await waitText(p, 'INICIA SESIÓN', 15000));
    await login(p, process.env.ACCOUNT_OTHER); await tour(p);
    ok('la otra cuenta entra', await waitText(p, 'Hola', 30000));
    await tap(p, 'Rutinas'); await p.waitForTimeout(2000);
    ok('la otra cuenta no ve pendientes de la primera', !(await waitText(p, 'Pendiente de enviar', 2000)));
    await shot(p, 'P8-otra-cuenta'); await browser.close();
  }
  if (sel === 'cuenta') {
    log('S4 · Cierre de sesión y cambio de cuenta');
    const { browser, p } = await open();
    await login(p, process.env.ACCOUNT_FIRST); await tour(p);
    ok('primera cuenta entra', await waitText(p, 'Hola', 30000));
    await tap(p, 'Perfil'); await p.waitForTimeout(1200);
    await toBottomLocal(p, 'Cerrar sesión'); await tap(p, 'Cerrar sesión'); await p.waitForTimeout(2500);
    ok('vuelve al inicio de sesión', await waitText(p, 'INICIAR SESIÓN', 15000)); await shot(p, 'P8a-tras-cerrar-sesion');
    await fill(p, 'Correo', process.env.ACCOUNT_OTHER); await fill(p, 'Contraseña', PASS); await tap(p, 'INICIAR SESIÓN'); await tour(p);
    ok('la otra cuenta entra', await waitText(p, 'Hola', 30000));
    await tap(p, 'Perfil'); await p.waitForTimeout(1500);
    const txt = (await nodes(p)).join('|');
    ok('Perfil muestra el correo de la otra cuenta y no el de la primera', txt.includes(process.env.ACCOUNT_OTHER) && !txt.includes(process.env.ACCOUNT_FIRST));
    await shot(p, 'P8-otra-cuenta'); await browser.close();
  }
  if (sel === 'todo' || sel === 'sinred' || sel === 'cuenta') {
    log('S5 · Error de conexión al iniciar sesión');
    const { browser, p } = await open();
    await p.route(/localhost:8080/, r => r.abort('internetdisconnected'));
    await login(p, process.env.ACCOUNT_OTHER);
    ok('mensaje de conexión claro', await waitText(p, 'conexión', 15000)); await shot(p, 'P9-sin-conexion-login');
    await browser.close();
  }
  log('fin');
})().catch(e => { console.error('ERROR', e.message); process.exit(1); });
async function toBottomLocal(p, text, n = 14) { for (let i = 0; i < n && !(await waitText(p, text, 300)); i++) await scroll(p, 700); }
