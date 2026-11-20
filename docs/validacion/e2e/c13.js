// 13 · reinicio del backend durante la generacion. SENAL=TERM (despliegue) o KILL (caida).
const { k, db, nuevo, terminarTour, log } = require('./lib'); const { execSync, spawn } = require('child_process');
const fs = require('fs');
(async () => {
  const senal = process.env.SENAL || 'TERM'; const e = `c13${senal.toLowerCase()}${process.env.SUF||''}+d40@e2e.local`;
  const { ctx, p } = await nuevo('c13' + senal + (process.env.SUF||''), 'Trece', e);
  await p.waitForTimeout(8000);
  log('c13 BD antes de detener:', db.op(e));
  const pid = execSync("pgrep -f 'fitsense.FitsenseApplication' | head -1").toString().trim();
  execSync(`kill -${senal} ${pid}`); log('c13 backend detenido con SIG' + senal, pid);
  for (let i = 0; i < 30; i++) { try { execSync(`kill -0 ${pid} 2>/dev/null`); await p.waitForTimeout(500); } catch { break; } }
  log('c13 BD con el backend caido:', db.op(e));
  await terminarTour(p);
  await p.waitForTimeout(6000);
  await k.dump(p, 'c13 backend caido'); await k.shot(p, `c13${senal}-backend-caido`);
  const out = fs.openSync(__dirname + '/backend.log', 'a');
  spawn(__dirname + '/run-backend.sh', [], { detached: true, stdio: ['ignore', out, out] }).unref();
  log('c13 backend arrancando de nuevo');
  let ultimo = ''; const fin = Date.now() + 240000;
  while (Date.now() < fin) {
    const s = db.op(e); if (s !== ultimo) { log('c13 BD:', s, '|', db.counts(e)); ultimo = s; }
    if (/^(COMPLETED|FAILED|NO_FACTIBLE)/.test(s)) break; await p.waitForTimeout(3000);
  }
  await p.waitForTimeout(8000);
  await k.dump(p, 'c13 final'); await k.shot(p, `c13${senal}-final`);
  log('c13 final:', db.op(e), '|', db.counts(e));
  await ctx.close(); process.exit(0);
})().catch(e => { console.log('ERROR', e.message); process.exit(1); });
