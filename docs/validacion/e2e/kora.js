// Helpers para manejar la app Flutter web por su arbol de semantica.
const { chromium } = require('playwright');
const SHOTS = __dirname + '/shots';

async function open(profile, { width = 390, height = 844, reducedMotion, fresh } = {}) {
  const ctx = await chromium.launchPersistentContext(__dirname + '/profiles/' + profile,
      { viewport: { width, height }, deviceScaleFactor: 1, reducedMotion: reducedMotion ? 'reduce' : 'no-preference' });
  const p = ctx.pages()[0] || await ctx.newPage();
  p.on('console', m => { if (m.type() === 'error') console.log('  [console]', m.text().slice(0, 200)); });
  p.on('requestfailed', r => console.log('  [reqfail]', r.method(), r.url().replace('http://localhost:8080/api/v1', ''), r.failure()?.errorText));
  p.on('response', r => { if (r.url().includes(':8080/')) console.log('  [api]', r.request().method(), r.url().replace('http://localhost:8080/api/v1', ''), r.status()); });
  await p.goto('http://localhost:5050/');
  await semantics(p);
  return { ctx, p };
}

async function semantics(p) {
  await p.waitForSelector('flt-semantics-placeholder, flt-semantics', { state: 'attached', timeout: 30000 });
  await p.waitForTimeout(1500);
  await p.evaluate(() => document.querySelector('flt-semantics-placeholder')?.click());
  await p.waitForTimeout(800);
}

/** Nodos visibles: [rol, etiqueta, texto]. */
async function tree(p) {
  return p.$$eval('flt-semantics', ns => ns.filter(n => n.children.length === 0 || n.getAttribute('role'))
      .map(n => [n.getAttribute('role') || '', (n.getAttribute('aria-label') || '').slice(0, 80), (n.textContent || '').trim().replace(/\s+/g, ' ').slice(0, 80)])
      .filter(x => x[0] || x[1] || x[2]));
}

async function dump(p, name) {
  const t = await tree(p);
  const seen = new Set();
  console.log(`--- ${name}`);
  for (const [r, l, x] of t) { const k = r + '|' + l + '|' + x; if (seen.has(k)) continue; seen.add(k); console.log(`   ${r.padEnd(9)} ${l} ${l && x ? '·' : ''} ${x}`); }
  const inputs = await p.$$eval('input, textarea', ns => ns.map(n => n.getAttribute('aria-label') || n.placeholder || n.type));
  if (inputs.length) console.log('   inputs:', JSON.stringify(inputs));
}

async function shot(p, name) { await p.screenshot({ path: `${SHOTS}/${name}.png` }); }

function locate(p, text, role) {
  const sel = role ? `flt-semantics[role="${role}"]` : 'flt-semantics';
  return p.locator(sel).filter({ hasText: text }).last();
}

/** Toca el nodo con ese texto/etiqueta (prefiere botones). */
async function tap(p, text, { role, exact } = {}) {
  const deadline = Date.now() + 15000;
  while (Date.now() < deadline) {
    const ids = await p.$$eval('flt-semantics', (ns, [text, role, exact]) => {
      const match = n => { const s = ((n.getAttribute('aria-label') || '') + ' ' + (n.textContent || '')).replace(/\s+/g, ' ').trim();
        return exact ? (n.getAttribute('aria-label') === text || (n.textContent || '').trim() === text) : s.toLowerCase().includes(text.toLowerCase()); };
      const cands = ns.filter(n => match(n) && (!role || n.getAttribute('role') === role));
      const clickable = cands.filter(n => ['button', 'link', 'tab', 'checkbox', 'radio', 'switch', 'menuitem', 'option'].includes(n.getAttribute('role')) || n.hasAttribute('flt-tappable'));
      const pick = (clickable.length ? clickable : cands);
      // el mas interno
      const inner = pick.filter(n => !pick.some(m => m !== n && n.contains(m)));
      return inner.map(n => { const r = n.getBoundingClientRect(); return [r.x + r.width / 2, r.y + r.height / 2, r.width, r.height]; }).filter(r => r[2] > 0);
    }, [text, role, exact]);
    if (ids.length) {
      const [x, y] = ids[ids.length - 1];
      const vh = p.viewportSize().height, vw = p.viewportSize().width;
      if (y > vh - 8 || y < 8) {
        await p.mouse.move(vw / 2, vh / 2);
        await p.mouse.wheel(0, y > vh ? Math.min(y - vh / 2, 600) : Math.max(y - vh / 2, -600));
        await p.waitForTimeout(500);
        continue;
      }
      await p.mouse.click(x, y); await p.waitForTimeout(600); return;
    }
    await p.waitForTimeout(400);
  }
  await dump(p, 'NO ENCONTRADO: ' + text);
  throw new Error('No encontrado: ' + text);
}

async function fill(p, label, value) {
  const deadline = Date.now() + 15000;
  while (Date.now() < deadline) {
    const r = await p.$$eval('flt-semantics, input, textarea', (ns, label) => {
      const n = ns.find(n => (n.getAttribute('aria-label') || '').toLowerCase().includes(label.toLowerCase()) && (n.tagName === 'INPUT' || n.tagName === 'TEXTAREA' || n.getAttribute('role') === 'textbox' || n.querySelector('input,textarea')));
      if (!n) return null; const b = n.getBoundingClientRect(); return [b.x + b.width / 2, b.y + b.height / 2];
    }, label);
    if (r && (r[1] > p.viewportSize().height - 8 || r[1] < 8)) {
      await p.mouse.move(p.viewportSize().width / 2, p.viewportSize().height / 2);
      await p.mouse.wheel(0, r[1] > p.viewportSize().height ? Math.min(r[1] - p.viewportSize().height / 2, 600) : Math.max(r[1] - p.viewportSize().height / 2, -600));
      await p.waitForTimeout(500); continue;
    }
    if (r) {
      await p.mouse.click(r[0], r[1]); await p.waitForTimeout(300);
      await p.keyboard.press('Control+A'); await p.keyboard.type(value, { delay: 5 }); await p.waitForTimeout(200);
      return;
    }
    await p.waitForTimeout(400);
  }
  await dump(p, 'SIN CAMPO: ' + label);
  throw new Error('Sin campo: ' + label);
}

async function waitText(p, text, timeout = 30000) {
  const deadline = Date.now() + timeout;
  while (Date.now() < deadline) {
    const found = await p.$$eval('flt-semantics', (ns, t) => ns.some(n => ((n.getAttribute('aria-label') || '') + ' ' + (n.textContent || '')).toLowerCase().includes(t.toLowerCase())), text);
    if (found) return true;
    await p.waitForTimeout(500);
  }
  return false;
}

module.exports = { open, semantics, tree, dump, shot, tap, fill, waitText, SHOTS };
