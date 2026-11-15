// node caso-largo.js <perfil> <email> <segundosMax> : sigue un usuario hasta estado terminal en la pantalla de resultado.
const { k, db, nuevo, terminarTour, log } = require('./lib');
(async () => {
  const [prof, email, max] = process.argv.slice(2);
  const { ctx, p } = await nuevo(prof, prof, email);
  const t0 = Date.now();
  await terminarTour(p);
  log(prof, 'tour terminado; BD:', db.op(email));
  await k.shot(p, `${prof}-esperando`);
  const fin = Date.now() + max * 1000; let ultimo = '';
  while (Date.now() < fin) {
    const estado = db.op(email);
    if (estado !== ultimo) { log(prof, 'BD:', estado, '|', db.counts(email)); ultimo = estado; }
    if (/^(COMPLETED|FAILED|NO_FACTIBLE)/.test(estado)) break;
    await p.waitForTimeout(5000);
  }
  await p.waitForTimeout(6000);
  log(prof, `fin a los ${((Date.now() - t0) / 1000).toFixed(0)} s:`, db.op(email), '|', db.counts(email));
  await k.dump(p, prof + ' pantalla final'); await k.shot(p, `${prof}-final`);
  if (process.argv[5]) { log('esperando', process.argv[5], 's mas para ver si se publica tarde'); await p.waitForTimeout(+process.argv[5] * 1000); log(prof, 'despues:', db.op(email), '|', db.counts(email)); }
  await ctx.close();
})().catch(e => { console.log('ERROR', e.message); process.exit(1); });
