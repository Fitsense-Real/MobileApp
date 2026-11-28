// Mobile-C1: opción A y consentimientos en la app real (Flutter web release) contra el Backend 41c498a LOCAL con documentos SINTÉTICOS.
// Uso: AUDIT_PASSWORD=... WEB_DIR=<build/web> SHOTS=<dir> BACKEND_SCRIPT=backend_41c.sh BACKEND_LOG=<log> ACCOUNT_NOPART=... ACCOUNT_WITHDRAWN=... ACCOUNT_LIMIT=... node escenarios_c1.js todo|rechazo|acepta|perfil|version|conexion|estados|limite|cerrado
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
  const browser = await chromium.launch({ proxy: process.env.HTTPS_PROXY ? { server: process.env.HTTPS_PROXY, bypass: 'localhost,127.0.0.1,localhost:8443' } : undefined });
  const ctx = await browser.newContext({ viewport: { width, height }, deviceScaleFactor: 2, locale: 'es-PE', ignoreHTTPSErrors: true });
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


const steps = JSON.parse(fs.readFileSync(__dirname + '/../../../cierre_preproduccion/evidencia/arnes/perfil.json', 'utf8'));
async function perfil(p) {
  for (const a of steps) {
    if (a.tap) await tap(p, a.tap, a); else if (a.fill) await fill(p, a.fill, a.value);
    else if (a.wait) await p.waitForTimeout(a.wait); else if (a.scroll) await scroll(p, a.scroll);
  }
}

// ---- Mobile-C1: opción A y consentimientos en la app real ----
const { execSync } = require('child_process');
const ok = (name, cond) => { log(cond ? 'OK   ' : 'FALLA', name); if (!cond) process.exitCode = 1; };
async function toBottomLocal(p, text, n = 16) { for (let i = 0; i < n && !(await waitText(p, text, 300)); i++) await scroll(p, 600); }
async function tour(p, wait = 8000) {
  if (await waitText(p, 'Soy Kapi', wait)) { for (let i = 0; i < 12 && !(await waitText(p, 'Terminar', 400)); i++) { const t = (await nodes(p)).join('|'); const n = ['Empezar', 'Ir a Rutinas', 'Ir a Progreso', 'Ir a Perfil', 'Siguiente'].find(x => t.includes(x)); if (n) await tap(p, n, { role: 'button' }); await p.waitForTimeout(700); } await tap(p, 'Terminar', { role: 'button' }); }
  if (await waitText(p, 'Ver mi plan', 8000)) await tap(p, 'Ver mi plan');
}
/** Taps the button [label] on the same row as the text [anchor]. */
async function tapNear(p, anchor, label) {
  for (let k = 0; k < 12; k++) {
    const r = await p.$$eval('flt-semantics', (ns, [anchor, label]) => {
      const txt = n => ((n.getAttribute('aria-label') || '') + ' ' + (n.textContent || '')).replace(/\s+/g, ' ').trim();
      const a = ns.filter(n => txt(n).includes(anchor)).map(n => n.getBoundingClientRect()).filter(b => b.width > 0).sort((x, y) => x.height - y.height)[0];
      if (!a) return null;
      const b = ns.filter(n => txt(n) === label && n.getAttribute('role') === 'button').map(n => n.getBoundingClientRect()).filter(r => r.width > 0 && Math.abs((r.y + r.height / 2) - (a.y + a.height / 2)) < 50)[0];
      return b ? [b.x + b.width / 2, b.y + b.height / 2] : 'sin-boton';
    }, [anchor, label]);
    const vh = p.viewportSize().height;
    if (r === null) { await scroll(p, 500); continue; }
    if (r === 'sin-boton') { await scroll(p, 150); continue; }
    if (r[1] > vh - 60) { await scroll(p, 300); continue; } if (r[1] < 40) { await scroll(p, -300); continue; }
    await p.mouse.click(r[0], r[1]); await p.waitForTimeout(900); return;
  }
  await shot(p, 'debug-tapnear'); log('  nodos:', (await nodes(p)).filter(t => t.length < 120).join(' | '));
  throw new Error('No encontrado: ' + label + ' junto a ' + anchor);
}
/** Opens a document from its row and reads it to the end. */
async function readDoc(p, anchor) {
  await tapNear(p, anchor, 'Leer');
  if (!await waitText(p, 'Desplázate hasta el final', 15000) && !await waitText(p, 'He leído el documento', 500)) { await shot(p, 'debug-lector'); log('  nodos:', (await nodes(p)).slice(0, 40).join(' | ')); throw new Error('el lector no muestra el documento ' + anchor); }
  for (let i = 0; i < 25 && !(await waitText(p, 'He leído el documento', 300)); i++) await scroll(p, 900);
  await tap(p, 'He leído el documento'); await p.waitForTimeout(900);
}
async function fillAccount(p, email) {
  await fill(p, 'Nombres', 'Auditoria'); await fill(p, 'Apellidos', 'Opcion A');
  await fill(p, 'Correo', email); await fill(p, 'Contraseña', PASS); await fill(p, 'Confirmar', PASS);
}
async function openRegister(p) { await tap(p, 'COMENZAR AHORA'); await p.waitForTimeout(1500); }
async function acceptAll(p) {
  await readDoc(p, 'Condiciones de uso · versión'); await tap(p, 'Acepto las condiciones de uso');
  await readDoc(p, 'Politica de privacidad · versión'); await tap(p, 'Acepto la política de privacidad');
  await readDoc(p, 'Consentimiento informado · versión'); await tap(p, 'Acepto participar voluntariamente');
}
const SH = process.env.BACKEND_SCRIPT;
function restartBackend(terms, docs) {
  execSync(`pkill -f '[f]itsense-backend-0.0.1-SNAPSHOT.jar' || true; sleep 2; (nohup ${SH} ${terms} ${docs} > ${process.env.BACKEND_LOG} 2>&1 &); for i in $(seq 1 60); do curl -sf http://localhost:8080/api/v1/legal-documents >/dev/null && break; sleep 2; done`, { stdio: 'ignore', shell: '/bin/bash' });
  log('  Backend reiniciado: términos', terms, 'documentos', docs);
}

(async () => {
  const sel = process.argv[2] || 'todo';
  const posts = [];
  const watch = p => p.on('request', r => { if (r.method() === 'POST' && r.url().includes('/auth/register')) posts.push(r.postData()); });

  if (sel === 'todo' || sel === 'rechazo') {
    log('UA1 (I-03) · Rechazar participar en la app');
    const { browser, p } = await open(); watch(p);
    await openRegister(p);
    ok('explica el estudio antes de escribir nada', await waitText(p, 'Kora es parte de un estudio', 15000));
    await shot(p, 'C1-01-registro-arriba');
    await fillAccount(p, `audit-ui-rechaza-${Date.now()}@audit.local`);
    await toBottomLocal(p, 'No deseo participar'); await shot(p, 'C1-02-documentos-sin-leer');
    await tap(p, 'No deseo participar'); await p.waitForTimeout(900);
    ok('mensaje respetuoso y claro', await waitText(p, 'no se creará ninguna cuenta', 5000)); await shot(p, 'C1-03-no-deseo-participar');
    await tap(p, 'Salir del registro'); await p.waitForTimeout(1500);
    ok('sale del registro', await waitText(p, 'COMENZAR AHORA', 10000));
    ok('ningún POST /auth/register', posts.length === 0);
    await browser.close();
  }
  if (sel === 'todo' || sel === 'acepta') {
    log('UA2 (I-04, I-09) · Aceptar con los documentos publicados, perfil, plan y Perfil › Documentos');
    const email = `audit-ui-acepta-${Date.now()}@audit.local`;
    const { browser, p } = await open(); watch(p);
    await openRegister(p); await fillAccount(p, email);
    await acceptAll(p); await toBottomLocal(p, 'CREAR CUENTA'); await shot(p, 'C1-04-todo-aceptado');
    await tap(p, 'CREAR CUENTA');
    ok('entra al perfil', await waitText(p, 'Paso 1 de 5', 25000));
    const body = JSON.parse(posts[posts.length - 1] || '{}'); delete body.password;
    log('  cuerpo enviado:', JSON.stringify(body));
    ok('envía las cuatro versiones leídas', body.acceptsStudyParticipation === true && body.acceptedTermsVersion === 'T-QA-1' && body.acceptedPrivacyVersion === 'P-QA-1' && body.acceptedStudyConsentVersion === 'C-QA-1');
    await perfil(p); await toBottomLocal(p, 'Generar mi plan'); await tap(p, 'Generar mi plan');
    await tour(p, 40000);
    for (let i = 0; i < 60 && !(await waitText(p, 'Ver mi plan', 500)) && (await waitText(p, 'se está preparando', 500)); i++) await p.waitForTimeout(1500);
    if (await waitText(p, 'Ver mi plan', 3000)) await tap(p, 'Ver mi plan');
    ok('plan visible', await waitText(p, 'Hola', 30000));
    await tap(p, 'Perfil'); await p.waitForTimeout(1200); await tap(p, 'Cuenta'); await p.waitForTimeout(1800); await toBottomLocal(p, 'Consentimiento del estudio');
    ok('Perfil muestra el consentimiento con su versión', await waitText(p, 'aceptado', 5000) && await waitText(p, 'C-QA-1', 2000));
    ok('distingue condiciones y privacidad', await waitText(p, 'Condiciones de uso: aceptada', 2000) && await waitText(p, 'Política de privacidad: aceptada', 2000));
    await scroll(p, 200); await shot(p, 'C1-05-perfil-documentos');
    fs.writeFileSync(process.env.SHOTS + '/cuenta-acepta.txt', email);
    await browser.close();
  }
  if (sel === 'perfil') {
    log('UA2b (I-09) · Perfil › Cuenta › Documentos de la cuenta creada en UA2');
    const { browser, p } = await open();
    await login(p, fs.readFileSync(process.env.SHOTS + '/cuenta-acepta.txt', 'utf8').trim()); await tour(p);
    await waitText(p, 'Hola', 30000);
    await tap(p, 'Perfil'); await p.waitForTimeout(1200); await tap(p, 'Cuenta'); await p.waitForTimeout(1800); await toBottomLocal(p, 'Consentimiento del estudio');
    ok('Perfil muestra el consentimiento con su versión', await waitText(p, 'Consentimiento del estudio: aceptado', 5000) && await waitText(p, 'C-QA-1', 2000));
    ok('distingue condiciones y privacidad', await waitText(p, 'Condiciones de uso: aceptada', 2000) && await waitText(p, 'Política de privacidad: aceptada', 2000));
    await shot(p, 'C1-05-perfil-documentos');
    await browser.close();
  }
  if (sel === 'todo' || sel === 'version') {
    log('UA3 (§5.4) · La versión cambia mientras la persona se registra');
    const { browser, p } = await open(); watch(p);
    const before = posts.length;
    await openRegister(p); await fillAccount(p, `audit-ui-version-${Date.now()}@audit.local`);
    await acceptAll(p);
    restartBackend('T-QA-2', 'si');
    await toBottomLocal(p, 'CREAR CUENTA'); await tap(p, 'CREAR CUENTA'); await p.waitForTimeout(2500);
    ok('explica el cambio', await waitText(p, 'Los documentos cambiaron', 10000)); await shot(p, 'C1-06-documentos-cambiaron');
    ok('no envía la versión desactualizada', posts.length === before);
    await tap(p, 'Entendido'); await p.waitForTimeout(2500);
    ok('muestra la versión vigente', await waitText(p, 'T-QA-2', 10000));
    await readDoc(p, 'Condiciones de uso · versión'); await tap(p, 'Acepto las condiciones de uso');
    await readDoc(p, 'Politica de privacidad · versión'); await tap(p, 'Acepto la política de privacidad');
    await readDoc(p, 'Consentimiento informado · versión'); await tap(p, 'Acepto participar voluntariamente');
    await toBottomLocal(p, 'CREAR CUENTA'); await tap(p, 'CREAR CUENTA');
    ok('con la versión vigente sí se crea', await waitText(p, 'Paso 1 de 5', 25000));
    ok('envía T-QA-2', JSON.parse(posts[posts.length - 1]).acceptedTermsVersion === 'T-QA-2');
    await browser.close();
    restartBackend('T-QA-1', 'si');
  }
  if (sel === 'todo' || sel === 'conexion') {
    log('UA4 (I-15) · Se pierde la conexión al crear la cuenta');
    const email = `audit-ui-conexion-${Date.now()}@audit.local`;
    const { browser, p } = await open(); watch(p);
    await openRegister(p); await fillAccount(p, email); await acceptAll(p);
    const cut = /localhost:8080\/api\/v1\/auth\/register/;
    await p.route(cut, r => r.abort('internetdisconnected'));
    await toBottomLocal(p, 'CREAR CUENTA'); await tap(p, 'CREAR CUENTA'); await p.waitForTimeout(2500);
    ok('sigue en el registro con un mensaje', await waitText(p, 'CREAR CUENTA', 3000) && !(await waitText(p, 'Paso 1 de 5', 1000)));
    await shot(p, 'C1-07-sin-conexion-al-crear');
    await p.unroute(cut);
    await p.waitForTimeout(6000); // el aviso tapa el botón: esperar a que se cierre
    await scroll(p, 900); await tap(p, 'CREAR CUENTA', { exact: true });
    ok('con conexión, mismo formulario, se crea una sola cuenta', await waitText(p, 'Paso 1 de 5', 25000));
    const n = execSync(`PGPASSWORD=x psql -h localhost -U postgres -d kora_integracion_final -Atc "select count(*) from users where email='${email}'"`).toString().trim();
    ok(`una sola cuenta en la base (${n})`, n === '1');
    await browser.close();
  }
  if (sel === 'todo' || sel === 'estados') {
    log('UA5 (I-10, I-12) · Cuenta sin participación y cuenta retirada en la app');
    for (const [who, expected, name] of [[process.env.ACCOUNT_NOPART, 'no está inscrita como participante', 'C1-08-sin-participacion'],
                                         [process.env.ACCOUNT_WITHDRAWN, 'Te retiraste del estudio', 'C1-09-retirada']]) {
      const { browser, p } = await open();
      let gens = 0; p.on('request', r => { if (r.url().includes('/plan/generation') && r.method() === 'POST') gens++; });
      await login(p, who);
      ok(`${name}: estado correcto`, await waitText(p, expected, 20000));
      ok(`${name}: sin «Reintentar generación» ni error genérico`, !(await waitText(p, 'Reintentar generación', 500)) && !(await waitText(p, 'Error inesperado', 500)));
      await p.waitForTimeout(4000);
      ok(`${name}: ninguna petición de generación (${gens})`, gens === 0);
      await shot(p, name); await browser.close();
    }
  }
  if (sel === 'todo' || sel === 'limite') {
    log('UA6 (I-13) · 429 al iniciar sesión con la clave mal repetida');
    const { browser, p } = await open();
    await tap(p, 'INICIA SESIÓN'); await fill(p, 'Correo', process.env.ACCOUNT_LIMIT);
    for (let i = 0; i < 7; i++) { await fill(p, 'Contraseña', 'clave-incorrecta-' + i); await tap(p, 'INICIAR SESIÓN'); await p.waitForTimeout(1300); if (await waitText(p, 'Podrás intentarlo de nuevo', 400)) break; }
    // En el navegador, CORS oculta Retry-After (el Backend no lo expone): el tiempo solo aparece en Android.
    ok('mensaje del Backend, sin códigos internos', await waitText(p, 'Demasiados intentos', 3000) && !(await waitText(p, 'DEMASIADOS_', 300)) && !(await waitText(p, 'DEMASIADAS_', 300)));
    await shot(p, 'C1-10-limite-429'); await browser.close();
  }
  if (sel === 'todo' || sel === 'cerrado') {
    log('UA7 (I-02) · Sin documentos publicados el registro queda cerrado');
    restartBackend('T-QA-1', 'no');
    const { browser, p } = await open(); watch(p);
    const before = posts.length;
    await openRegister(p);
    ok('registro cerrado con explicación', await waitText(p, 'El registro todavía no está abierto', 15000));
    const t = (await nodes(p)).join('|');
    ok('sin formulario ni casilla de participación', !t.includes('CREAR CUENTA') && !t.includes('Acepto participar') && !t.includes('Correo electrónico'));
    ok('ningún POST', posts.length === before);
    await shot(p, 'C1-11-registro-cerrado'); await browser.close();
    restartBackend('T-QA-1', 'si');
  }
  log('fin');
})().catch(e => { console.error('ERROR', e.message); process.exit(1); });
