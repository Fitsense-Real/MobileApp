// Edad mínima en Flutter con el backend real: cumple 18 mañana (rechazo) y cumple 18 hoy (acepta y crea el perfil).
const { k, db, log } = require('./lib'); const registrar = require('./register');
async function fecha(p, dia) {
  await k.tap(p, 'Elegir cumpleaños'); await p.waitForTimeout(800);
  const box = await p.$$eval('flt-semantics[role=button]', ns => { const n = ns.find(n => (n.textContent || '').trim() === '2008'); const b = n.getBoundingClientRect(); return [b.x + b.width / 2, b.y + b.height / 2]; });
  const dlg = await p.$$eval('flt-semantics[role=button]', ns => { const n = ns.find(n => (n.textContent || '').trim() === 'Elegir'); const b = n.getBoundingClientRect(); return [b.x, b.y]; });
  console.log('2008 en', box, 'Elegir en', dlg);
  await p.mouse.move(195, 420); await p.mouse.wheel(0, box[1] - 400); await p.waitForTimeout(700);
  const box2 = await p.$$eval('flt-semantics[role=button]', ns => { const n = ns.find(n => (n.textContent || '').trim() === '2008'); const b = n.getBoundingClientRect(); return [b.x + b.width / 2, b.y + b.height / 2]; });
  console.log('2008 ahora en', box2); await p.mouse.click(box2[0], box2[1]); await p.waitForTimeout(800); await k.shot(p, 'X-edad-anio');
  // el selector abre en noviembre del año elegido (la fecha inicial es la de hoy menos años)

  await k.tap(p, dia); await p.waitForTimeout(500);
  await k.tap(p, 'Elegir', { exact: true }); await p.waitForTimeout(500);
}
(async () => {
  const e = 'edadf3@e2e.local';
  const { ctx, p } = await k.open('edadf3');
  if (!await k.waitText(p, 'Paso 1 de 5', 4000)) { await k.waitText(p, 'COMENZAR AHORA', 15000); await k.tap(p, 'INICIA SESIÓN', { role: 'button' }); await p.waitForTimeout(1000); await k.fill(p, 'Correo', e); await k.fill(p, 'Contraseña', process.env.E2E_PASSWORD); await k.tap(p, 'INICIAR SESIÓN'); await k.waitText(p, 'Paso 1 de 5', 15000); }
  await p.waitForTimeout(1500);
  await k.tap(p, 'Mejorar condición'); await k.fill(p, 'Cuéntanos', 'Probar la edad'); await k.tap(p, 'Continuar'); await p.waitForTimeout(800);
  await fecha(p, '21, viernes, 21 de noviembre de 2008');
  await k.tap(p, 'Intermedio'); await k.fill(p, 'Estatura', '164'); await k.fill(p, 'Peso actual', '63');
  await k.tap(p, 'Continuar'); await p.waitForTimeout(1000);
  log('menor (cumple 18 mañana) muestra aviso:', await k.waitText(p, 'al menos 18 años', 2000), '· sigue en paso 2:', await k.waitText(p, 'Paso 2 de 5', 1000));
  await k.shot(p, 'X-edad-menor');
  await fecha(p, '20, jueves, 20 de noviembre de 2008');
  await k.tap(p, 'Continuar'); await p.waitForTimeout(1000);
  log('cumple 18 hoy, pasa al paso 3:', await k.waitText(p, 'Paso 3 de 5', 3000));
  await k.shot(p, 'X-edad-18-hoy');
  await ctx.close(); process.exit(0);
})().catch(e => { console.log('ERROR', e.message); process.exit(1); });
