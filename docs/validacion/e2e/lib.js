const k = require('./kora'); const db = require('./db'); const perfil = require('./profile'); const registrar = require('./register');
const NEXT = ['Empezar', 'Ir a Rutinas', 'Ir a Progreso', 'Ir a Perfil', 'Terminar', 'Siguiente'];
async function pasoActual(p) {
  const t = await k.tree(p);
  const m = t.map(x => x[1] + ' ' + x[2]).join(' ').match(/Paso (\d+) de 10/i);
  return m ? +m[1] : null;
}
async function avanzar(p) {
  const t = await k.tree(p); const labels = t.map(x => x[2] + ' ' + x[1]).join(' | ');
  const label = NEXT.find(n => labels.includes(n)); if (!label) throw new Error('sin boton del tour');
  await k.tap(p, label, { role: 'button' }); await p.waitForTimeout(900);
}
/** Usuario nuevo: registro, perfil y "Generar mi plan". Devuelve contexto y pagina en el tour. */
async function nuevo(perfilNavegador, nombre, email, opts = {}) {
  const { ctx, p } = await k.open(perfilNavegador, opts);
  await registrar(p, nombre, email);
  await perfil(p);
  await k.tap(p, 'Generar mi plan');
  if (!await k.waitText(p, 'Soy Kapi', 20000)) throw new Error('no aparecio el tour');
  return { ctx, p };
}
async function terminarTour(p) { for (let i = 0; i < 12 && !(await k.waitText(p, 'Ya conoces Kora', 500) && await k.waitText(p, 'Terminar', 300)); i++) await avanzar(p); await k.tap(p, 'Terminar', { role: 'button' }); await p.waitForTimeout(1500); }
const log = (...a) => console.log(new Date().toISOString().slice(11, 19), ...a);
module.exports = { k, db, nuevo, avanzar, pasoActual, terminarTour, log };
