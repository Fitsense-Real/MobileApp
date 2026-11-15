// Recorrido principal real: perfil -> generar -> tour de Kapi durante la generacion -> resultado -> plan -> rutina.
const k = require('./kora'); const db = require('./db'); const perfil = require('./profile');
const EMAIL = 'ana+d45@e2e.local';
(async () => {
  const { ctx, p } = await k.open('u1');
  const T0 = Date.now(); const t = () => ((Date.now() - T0) / 1000).toFixed(1) + 's';
  try {
    await k.waitText(p, 'Paso 1 de 5', 20000);
    await perfil(p, true);
    console.log(t(), 'antes de generar:', db.counts(EMAIL));
    await k.tap(p, 'Generar mi plan');
    if (!await k.waitText(p, 'Soy Kapi', 20000)) throw new Error('no aparecio el tour');
    const tGen = Date.now();
    for (let i = 1; i <= 10; i++) {
      await p.waitForTimeout(1500);
      const tree = await k.tree(p);
      const paso = tree.map(x => x[1]).find(l => /^Paso \d+ de 10$/.test(l));
      console.log(t(), `tour ${paso} | operacion en BD: ${db.op(EMAIL)} | ${db.counts(EMAIL)}`);
      await k.shot(p, `10-tour-${String(i).padStart(2, '0')}`);
      if (i === 3) {           // el paso pide tocar la pestana real "Rutinas" dentro del hueco
        await k.tap(p, 'Rutinas', { role: 'tab' }).catch(async () => { console.log('   (sin rol tab, toco el texto)'); await k.tap(p, 'Ir a Rutinas'); });
        continue;
      }
      const next = ['Empezar', 'Ir a Rutinas', 'Ir a Progreso', 'Ir a Perfil', 'Terminar', 'Siguiente'];
      const labels = tree.map(x => x[2] + ' ' + x[1]).join(' | ');
      const label = next.find(n => labels.includes(n));
      await k.tap(p, label, { role: 'button' });
    }
    console.log(t(), 'tour terminado en', ((Date.now() - tGen) / 1000).toFixed(1), 's | BD:', db.op(EMAIL));
    await p.waitForTimeout(1500);
    await k.dump(p, 'resultado (esperando)');
    await k.shot(p, '20-resultado-esperando');
    if (!await k.waitText(p, 'Tu primera rutina está lista', 120000)) throw new Error('nunca llego COMPLETED');
    await p.waitForTimeout(2500);
    console.log(t(), 'rutina lista | BD:', db.op(EMAIL), '|', db.counts(EMAIL));
    await k.dump(p, 'resultado (lista)');
    await k.shot(p, '21-resultado-lista');
    await k.tap(p, 'Ver mi plan');
    await p.waitForTimeout(3500);
    await k.dump(p, 'inicio con plan');
    await k.shot(p, '22-inicio-con-plan');
    await k.tap(p, 'Rutinas', { role: 'tab' }).catch(() => k.tap(p, 'Rutinas'));
    await p.waitForTimeout(2500);
    await k.dump(p, 'rutinas');
    await k.shot(p, '23-rutinas');
  } catch (e) { console.log('ERROR', e.message); await k.shot(p, '_error'); }
  await ctx.close();
})();
