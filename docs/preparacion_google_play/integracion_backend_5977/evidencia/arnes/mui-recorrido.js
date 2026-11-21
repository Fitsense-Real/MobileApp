// Recorrido con la app migrada a material_ui (Flutter 3.50.1).
const { k, db, terminarTour, log } = require('./lib'); const perfil = require('./profile'); const { abrir } = require('./eliminar-lib');
const E = 'mui1@e2e.local';
const visibles = p => p.$$eval('flt-semantics[role=button]', ns => ns.filter(n => (n.textContent || '').trim() === 'Registrar ejercicio').map(n => { const b = n.getBoundingClientRect(); return [b.x + b.width / 2, b.y + b.height / 2]; }).filter(r => r[1] > 60 && r[1] < 800).sort((a, b) => a[1] - b[1]));
const dialogo = p => p.$$eval('flt-semantics[role=alertdialog]', ns => (ns[0]?.textContent || ''));
const fondo = async p => { await p.mouse.move(195, 420); for (let i = 0; i < 40; i++) { await p.mouse.wheel(0, 700); await p.waitForTimeout(50); } await p.waitForTimeout(800); };
(async () => {
  const { ctx, p } = await k.open('mui1');
  await k.waitText(p, 'COMENZAR AHORA', 15000); await k.shot(p, 'M-bienvenida');
  await k.tap(p, 'INICIA SESIÓN', { role: 'button' }); await p.waitForTimeout(1000);
  await k.fill(p, 'Correo', E); await k.fill(p, 'Contraseña', process.env.E2E_PASSWORD); await k.tap(p, 'INICIAR SESIÓN');
  log('perfil paso 1:', await k.waitText(p, 'Paso 1 de 5', 15000));
  await perfil(p); // incluye el calendario en español («10, sábado, 10 de noviembre»)
  await k.shot(p, 'M-perfil-restricciones');
  await k.tap(p, 'Generar mi plan');
  log('tour de Kapi:', await k.waitText(p, 'Soy Kapi', 20000)); await k.shot(p, 'M-tour');
  await terminarTour(p);
  log('rutina lista:', await k.waitText(p, 'Ver mi plan', 30000)); await k.shot(p, 'M-plan-listo'); await k.tap(p, 'Ver mi plan', { role: 'button' });
  log('dashboard:', await k.waitText(p, 'Hola, Mia', 20000)); await k.shot(p, 'M-dashboard');
  const [nombre, min] = db.q(`SELECT pw.workout_name||'|'||pw.expected_duration_minutes FROM planned_workouts pw JOIN weekly_training_plans w USING(plan_id) JOIN users u USING(user_id) WHERE u.email='${E}' AND pw.scheduled_date=current_date`).split('|');
  if (nombre) {
    await k.tap(p, `${nombre.toUpperCase()} ${min} MIN`); await p.waitForTimeout(2500);
    await k.tap(p, 'Registrar ejercicio', { role: 'button' }); await p.waitForTimeout(1200);
    await k.tap(p, 'Comenzar sesión y registrar'); await p.waitForTimeout(2500);
    if ((await dialogo(p)).length) { await k.tap(p, 'Cancelar', { role: 'button', exact: true }); await p.waitForTimeout(500); }
    const hechos = new Set(); let sin = 0;
    while (sin < 4) {
      let nuevo = false;
      for (const [x, y] of await visibles(p)) {
        await p.mouse.click(x, y); await p.waitForTimeout(900);
        const d = await dialogo(p); const n = d.split(/\d+ series/)[0].trim();
        if (!n || hechos.has(n)) { await k.tap(p, 'Cancelar', { role: 'button', exact: true }); await p.waitForTimeout(400); continue; }
        if (hechos.size === 1) {
          await k.tap(p, 'Lo hice parcialmente', { role: 'button' }); await p.waitForTimeout(300); await k.fill(p, 'Series realizadas', '1');
          const t = /\d+ s por serie/.test(d); await k.fill(p, t ? 'Duración total realizada (segundos, todas las series)' : 'Repeticiones totales (todas las series)', t ? '30' : '4');
          await k.tap(p, 'Motivo', { role: 'button', exact: true }); await p.waitForTimeout(500); await k.shot(p, 'M-motivo-desplegable'); await k.tap(p, 'Fatiga', { role: 'menuitem' });
        } else if (hechos.size === 2) {
          await k.tap(p, 'No lo hice', { role: 'button' }); await p.waitForTimeout(300); await k.tap(p, 'Motivo', { role: 'button', exact: true }); await p.waitForTimeout(500); await k.tap(p, 'Falta de tiempo', { role: 'menuitem' });
        } else await k.tap(p, 'Lo completé', { role: 'button' });
        await p.waitForTimeout(300); await k.tap(p, 'Guardar', { role: 'button', exact: true }); await p.waitForTimeout(1300);
        if ((await dialogo(p)).length) throw new Error('el diálogo no se cerró');
        hechos.add(n); nuevo = true; break;
      }
      if (!nuevo) { sin++; await p.mouse.move(195, 420); await p.mouse.wheel(0, 450); await p.waitForTimeout(700); } else sin = 0;
    }
    await fondo(p); await k.tap(p, 'Finalizar sesión', { role: 'button' }); await p.waitForTimeout(1200);
    await k.tap(p, 'Esfuerzo percibido', { role: 'button' }); await p.waitForTimeout(600); await k.tap(p, '7', { role: 'menuitem', exact: true }); await p.waitForTimeout(300);
    await k.tap(p, 'Finalizar', { role: 'button', exact: true }); await p.waitForTimeout(2500); await k.shot(p, 'M-sesion-finalizada');
    log(`sesión (${hechos.size} ejercicios):`, db.q(`SELECT s.status||' %='||s.completion_percentage||' rpe='||s.session_rpe FROM workout_sessions s JOIN users u USING(user_id) WHERE u.email='${E}'`));
    log('ejercicios:', db.q(`SELECT string_agg(r.status||coalesce('/'||r.skip_reason,''), ', ' ORDER BY r.session_exercise_id) FROM workout_session_exercises r JOIN workout_sessions s USING(session_id) JOIN users u USING(user_id) WHERE u.email='${E}'`));
    await k.tap(p, 'Volver', { role: 'button' }).catch(() => {}); await p.waitForTimeout(1500);
  } else log('sin entrenamiento hoy en el plan');
  await k.tap(p, 'Progreso', { role: 'tab' }); await p.waitForTimeout(2000); await k.shot(p, 'M-progreso');
  await abrir(p); log('pantalla de eliminación:', await k.waitText(p, 'Entiendo que esta acción no se puede deshacer', 5000)); await k.shot(p, 'M-eliminar');
  await k.tap(p, 'Volver', { role: 'button' }); await p.waitForTimeout(1500);
  await k.tap(p, 'Perfil', { role: 'tab' }); await p.waitForTimeout(1200); await p.mouse.move(195, 420); for (let i = 0; i < 15; i++) { await p.mouse.wheel(0, 500); await p.waitForTimeout(60); } await p.waitForTimeout(600);
  await k.shot(p, 'M-perfil'); await k.tap(p, 'Cerrar sesión', { role: 'button' }); await p.waitForTimeout(1500);
  log('tras cerrar sesión, login visible:', await k.waitText(p, 'INICIA', 8000) || await k.waitText(p, 'INICIAR SESIÓN', 3000));
  await ctx.close(); process.exit(0);
})().catch(e => { console.log('ERROR', e.message); process.exit(1); });
