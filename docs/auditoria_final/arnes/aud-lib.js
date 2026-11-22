// Utilidades de la auditoría funcional (backend local 5977d28, IA apagada, sin Replicate).
const { execFileSync } = require('child_process');
const fs = require('fs');
const { k, db, terminarTour, log } = require('./lib');
const B = 'http://localhost:8080/api/v1';
const PASS = process.env.E2E_PASSWORD; // contraseña de las cuentas sintéticas, nunca en el repositorio
const shot = (p, n) => p.screenshot({ path: __dirname + '/shots-aud/' + n + '.png' });
const texts = async p => (await p.$$eval('flt-semantics, flt-semantics-img', ns => ns.map(n => ((n.getAttribute('aria-label') || '') + ' ' + (n.textContent || '')).replace(/\s+/g, ' ').trim()).filter(Boolean)));
/** Recorre toda la pantalla desplazable y junta los textos vistos. */
async function allTexts(p, steps = 30) {
  const seen = new Set();
  await p.mouse.move(195, 420);
  for (let i = 0; i < 40; i++) { await p.mouse.wheel(0, -800); } await p.waitForTimeout(500);
  for (let i = 0; i < steps; i++) { for (const t of await texts(p)) seen.add(t); await p.mouse.wheel(0, 350); await p.waitForTimeout(220); }
  for (let i = 0; i < 40; i++) { await p.mouse.wheel(0, -800); } await p.waitForTimeout(400);
  return [...seen].join(' | ');
}
function token(email) { return JSON.parse(execFileSync('curl', ['-s', B + '/auth/login', '-H', 'Content-Type: application/json', '-d', JSON.stringify({ email, password: PASS })]).toString()).token; }
function api(email, path, method = 'GET', body) {
  const args = ['-s', '-X', method, B + path, '-H', 'Authorization: Bearer ' + token(email)];
  if (body) args.push('-H', 'Content-Type: application/json', '-d', JSON.stringify(body));
  const out = execFileSync('curl', args).toString(); try { return JSON.parse(out); } catch { return out; }
}
const prescription = e => {
  const dur = e.prescriptionType === 'DURATION' || (e.prescriptionType == null && (e.plannedReps ?? 0) <= 0 && (e.plannedDurationSeconds ?? 0) > 0);
  return [e.plannedSets != null ? `${e.plannedSets} ${e.plannedSets === 1 ? 'serie' : 'series'}` : null,
    dur ? (e.plannedDurationSeconds > 0 ? `${e.plannedDurationSeconds} s por serie` : 'Duración no indicada en el plan')
        : (e.plannedReps > 0 ? `${e.plannedReps} repeticiones por serie` : 'Repeticiones no indicadas en el plan'),
    e.targetLoadKg != null ? `${e.targetLoadKg} kg` : null].filter(Boolean).join(' · ');
};
const DAYS = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];
const trainingDay = iso => { const [y, m, d] = iso.split('-').map(Number); const dt = new Date(Date.UTC(y, m - 1, d)); return `${DAYS[(dt.getUTCDay() + 6) % 7]} · ${String(d).padStart(2, '0')}/${String(m).padStart(2, '0')}/${y}`; };
const STATUS = { SCHEDULED: 'Programado', IN_PROGRESS: 'En curso', COMPLETED: 'Completado', PARTIAL: 'Parcial', SKIPPED: 'Omitido', REPLACED: 'Reemplazado' };
/** Abre desde Rutinas el entrenamiento de esa fecha (las tarjetas siguen el orden de las fechas del
 *  plan; la web agrupa las etiquetas de fecha) y comprueba en el detalle que es ese día. */
async function abrirRutina(p, iso, fechas) {
  const idx = [...fechas].sort().indexOf(iso);
  const [y, m, d] = iso.split('-'); const corto = `${trainingDay(iso).split(' · ')[0]} ${d}/${m}`;
  await p.mouse.move(195, 420); for (let i = 0; i < 30; i++) await p.mouse.wheel(0, -800); await p.waitForTimeout(500);
  const cards = async () => p.$$eval('flt-semantics', ns => ns.filter(n => n.hasAttribute('flt-tappable') && /\d+ MIN\s/.test(n.getAttribute('aria-label') || '')).map(n => { const b = n.getBoundingClientRect(); return [b.y + window.scrollY, b.height, b.x + b.width / 2]; }));
  for (let i = 0; i < 40; i++) {
    const c = (await cards()).sort((a, b) => a[0] - b[0]);
    const vis = c.filter(r => r[0] > 80 && r[0] + r[1] < 760); if (process.env.DEBUG_ABRIR) console.log('  tarjetas', JSON.stringify(c.map(r => r.map(Math.round))), 'idx', idx);
    // Desplazar hasta que la tarjeta pedida sea la visible correspondiente.
    if (c.length > idx && vis.includes(c[idx])) { await p.mouse.click(150, c[idx][0] + c[idx][1] / 2); await p.waitForTimeout(2500); break; }
    await p.mouse.move(195, 420); await p.mouse.wheel(0, 200); await p.waitForTimeout(350);
  }
  const head = (await texts(p)).join(' ');
  if (!head.includes(corto)) { await shot(p, 'X-abrir-fallo'); throw new Error(`no se abrió el entrenamiento del ${corto}: ${head.slice(0, 160)}`); }
}
const results = [];
function check(area, what, ok, detail = '') { results.push({ area, what, ok: !!ok, detail }); log(`${ok ? '✓' : '✗'} [${area}] ${what}${detail ? ' — ' + detail : ''}`); }
function save(file) { fs.writeFileSync(file, JSON.stringify(results, null, 1)); }
module.exports = { abrirRutina, k, db, log, terminarTour, shot, texts, allTexts, token, api, prescription, trainingDay, STATUS, check, save, PASS, results };
