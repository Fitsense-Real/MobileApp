const { E2E_PASSWORD } = require('./credenciales');
const k = require('./kora');
module.exports = async function registrar(p, nombre, email) {
  await k.tap(p, 'COMENZAR AHORA');
  await k.fill(p, 'Nombres', nombre); await k.fill(p, 'Apellidos', 'E2E');
  await k.fill(p, 'Correo', email); await k.fill(p, 'Contraseña', E2E_PASSWORD); await k.fill(p, 'Confirmar', E2E_PASSWORD);
  await k.tap(p, 'Acepto participar', { role: 'checkbox' });
  await k.tap(p, 'CREAR CUENTA');
  if (!await k.waitText(p, 'INICIAR SESIÓN', 15000)) throw new Error('sin pantalla de login tras registro');
  await k.fill(p, 'Correo', email); await k.fill(p, 'Contraseña', E2E_PASSWORD);
  await k.tap(p, 'INICIAR SESIÓN');
  if (!await k.waitText(p, 'Paso 1 de 5', 20000)) throw new Error('no llego al perfil');
};
