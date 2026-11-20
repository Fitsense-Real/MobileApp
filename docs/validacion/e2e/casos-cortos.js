const { k, db, nuevo, avanzar, pasoActual, terminarTour, log } = require('./lib');
const perfil = require('./profile'); const registrar = require('./register');
const casos = {
  // 1 · la rutina termina antes que el tour
  async c01() {
    const e = 'c01b@e2e.local'; const { ctx, p } = await nuevo('c01b', 'Uno', e);
    await p.waitForTimeout(4000);
    log('c01 en el paso', await pasoActual(p), 'BD:', db.op(e));
    await terminarTour(p);
    const lista = await k.waitText(p, 'Tu primera rutina está lista', 10000);
    log('c01 al terminar el tour, rutina lista en pantalla:', lista, '| BD:', db.op(e), db.counts(e));
    await p.waitForTimeout(1500); await k.shot(p, 'c01-lista'); await ctx.close();
  },
  // 11 · tocar "Generar mi plan" varias veces
  async c11() {
    const e = 'c11b+d20@e2e.local'; const { ctx, p } = await k.open('c11b');
    await registrar(p, 'Once', e); await perfil(p);
    await p.mouse.move(195, 400); await p.mouse.wheel(0, 3000); await p.waitForTimeout(800);
    const r = await p.$$eval('flt-semantics[role=button]', ns => { const n = ns.filter(n => (n.textContent || '').includes('Generar mi plan')).pop(); const b = n.getBoundingClientRect(); return [b.x + b.width / 2, b.y + b.height / 2]; });
    for (let i = 0; i < 5; i++) await p.mouse.click(r[0], r[1], { delay: 10 });
    await k.waitText(p, 'Soy Kapi', 20000); await p.waitForTimeout(3000);
    log('c11 tras 5 toques:', db.counts(e), '| BD:', db.op(e));
    await terminarTour(p); await k.waitText(p, 'Tu primera rutina está lista', 60000); await p.waitForTimeout(1500);
    log('c11 final:', db.counts(e), '| BD:', db.op(e)); await ctx.close();
  },
  // 9 · error tecnico, reintento a pedido del usuario
  async c09() {
    const e = 'c09+fallo1@e2e.local'; const { ctx, p } = await nuevo('c09', 'Nueve', e);
    await terminarTour(p);
    const fallo = await k.waitText(p, 'Algo salió mal', 20000); await p.waitForTimeout(1000);
    log('c09 fallo visible:', fallo, '| BD:', db.op(e), db.counts(e)); await k.dump(p, 'c09 fallo'); await k.shot(p, 'c09-fallo');
    await p.waitForTimeout(8000); log('c09 sin reintento automatico:', db.counts(e));
    await k.tap(p, 'Intentar de nuevo', { role: 'button' });
    const ok = await k.waitText(p, 'Tu primera rutina está lista', 60000); await p.waitForTimeout(1500);
    log('c09 tras reintentar:', ok, '| BD:', db.op(e), db.counts(e)); await k.shot(p, 'c09-reintento-ok'); await ctx.close();
  },
  // 10 · NO_FACTIBLE
  async c10() {
    const e = 'c10+nofactible@e2e.local'; const { ctx, p } = await nuevo('c10', 'Diez', e);
    await terminarTour(p);
    const nf = await k.waitText(p, 'No encontramos una rutina compatible', 20000); await p.waitForTimeout(1000);
    log('c10 visible:', nf, '| BD:', db.op(e), db.counts(e)); await k.dump(p, 'c10'); await k.shot(p, 'c10-no-factible');
    await k.tap(p, 'Contactar al equipo', { role: 'button' }); await p.waitForTimeout(800); await k.shot(p, 'c10-contacto'); await ctx.close();
  },
  // 8 · sin conexion mientras espera; 3 · 30 s
  async c08() {
    const e = process.env.C08 || 'c08+d30@e2e.local'; const { ctx, p } = await nuevo(process.env.C08P || 'c08', 'Ocho', e);
    await ctx.setOffline(true); log('c08 sin conexion; BD:', db.op(e));
    await terminarTour(p);
    const aviso = await k.waitText(p, 'No hay conexión', 30000); await p.waitForTimeout(1000);
    log('c08 aviso de conexion visible:', aviso, '| BD:', db.op(e)); await k.dump(p, 'c08 sin conexion'); await k.shot(p, 'c08-sin-conexion');
    await p.waitForTimeout(25000); log('c08 offline 25 s mas; BD (el servidor sigue):', db.op(e));
    await ctx.setOffline(false); log('c08 conexion restablecida');
    const ok = await k.waitText(p, 'Tu primera rutina está lista', 60000); await p.waitForTimeout(1500);
    log('c08 final:', ok, '| BD:', db.op(e), db.counts(e)); await k.shot(p, 'c08-recuperado'); await ctx.close();
  },
  // 6, 7 · cerrar la app a mitad del tour y volver a abrir; 4 · 90 s
  async c06() {
    const e = 'c06+d90@e2e.local'; let { ctx, p } = await nuevo('c06', 'Seis', e);
    for (let i = 0; i < 4; i++) await avanzar(p);
    const antes = await pasoActual(p); const opAntes = db.op(e);
    log('c06 cierro la app en el paso', antes, '| BD:', opAntes); await k.shot(p, 'c06-antes-de-cerrar');
    await ctx.close();
    await new Promise(r => setTimeout(r, 15000));
    log('c06 app cerrada 15 s; BD:', db.op(e));
    ({ ctx, p } = await k.open('c06'));
    await k.waitText(p, 'Paso', 20000); await p.waitForTimeout(2500);
    const despues = await pasoActual(p);
    log('c06 reabierta en el paso', despues, '| BD:', db.op(e), db.counts(e)); await k.shot(p, 'c06-reabierta');
    await terminarTour(p);
    const ok = await k.waitText(p, 'Tu primera rutina está lista', 120000); await p.waitForTimeout(1500);
    log('c06 final:', ok, '| BD:', db.op(e), db.counts(e)); await ctx.close();
  },
  // cerrar Flutter durante la espera (pantalla de resultado) y volver a abrir
  async cEspera() {
    const e = 'espera+d60@e2e.local'; let { ctx, p } = await nuevo('cEspera', 'Espera', e);
    await terminarTour(p);
    log('cEspera en la espera; BD:', db.op(e)); await k.shot(p, 'cEspera-antes');
    await ctx.close(); await new Promise(r => setTimeout(r, 20000));
    log('cEspera app cerrada 20 s; BD:', db.op(e));
    ({ ctx, p } = await k.open('cEspera'));
    await p.waitForTimeout(4000);
    const enTour = await k.waitText(p, 'Paso 1 de 10', 500);
    const espera = await k.waitText(p, 'Ya conoces Kora', 3000) || await k.waitText(p, 'Tu primera rutina está lista', 1000);
    log('cEspera reabierta: tour otra vez:', enTour, '| pantalla de resultado:', espera, '| BD:', db.op(e), db.counts(e)); await k.shot(p, 'cEspera-reabierta');
    const ok = await k.waitText(p, 'Tu primera rutina está lista', 90000); await p.waitForTimeout(1500);
    log('cEspera final:', ok, '| BD:', db.op(e), db.counts(e)); await ctx.close();
  },
  // 12 · dos usuarios a la vez
  async c12() {
    const ea = 'c12a+d25@e2e.local', eb = 'c12b+d25@e2e.local';
    const [a, b] = await Promise.all([nuevo('c12a', 'Doce A', ea), nuevo('c12b', 'Doce B', eb)]);
    log('c12 BD A:', db.op(ea), '| B:', db.op(eb));
    await Promise.all([terminarTour(a.p), terminarTour(b.p)]);
    const [oa, ob] = await Promise.all([k.waitText(a.p, 'Tu primera rutina está lista', 90000), k.waitText(b.p, 'Tu primera rutina está lista', 90000)]);
    log('c12 listas:', oa, ob, '| A:', db.op(ea), db.counts(ea), '| B:', db.op(eb), db.counts(eb));
    const own = db.q(`SELECT u.email, p.plan_id FROM weekly_training_plans p JOIN users u USING (user_id) WHERE u.email IN ('${ea}','${eb}')`);
    log('c12 planes por usuario:', own.replace(/\n/g, ' ; '));
    await a.ctx.close(); await b.ctx.close();
  },
  // 15 · ya tiene rutina publicada: otro dispositivo (navegador limpio) entra directo al inicio
  async c15() {
    const e = 'lucia+d45@e2e.local'; const { ctx, p } = await k.open('c15-otro-dispositivo');
    await k.tap(p, 'INICIA SESIÓN'); await k.fill(p, 'Correo', e); await k.fill(p, 'Contraseña', 'Kora12345'); await k.tap(p, 'INICIAR SESIÓN');
    await p.waitForTimeout(5000);
    const tour = await k.waitText(p, 'Soy Kapi', 1000), inicio = await k.waitText(p, 'Hola, Lucía', 5000);
    log('c15 tour mostrado:', tour, '| inicio con plan:', inicio, '|', db.counts(e)); await k.shot(p, 'c15-inicio'); await ctx.close();
  },
};
(async () => {
  for (const n of process.argv.slice(2)) {
    log('==== ', n);
    try { await casos[n](); } catch (e) { console.log('ERROR', n, e.message); }
  }
  process.exit(0);
})();
