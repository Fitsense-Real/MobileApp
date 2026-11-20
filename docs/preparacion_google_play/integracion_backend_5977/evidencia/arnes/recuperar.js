// Recuperación en Flutter con el correo simulado (servidor SMTP local que guarda los .eml).
const { k, db, log } = require('./lib'); const registrar = require('./register');
const { execFileSync } = require('child_process'); const fs = require('fs');
const e = 'rec3@e2e.local';
(async () => {
  // A: sesión abierta antes del cambio de contraseña.
  const A = await k.open('rec3-viejo');
  if (!await k.waitText(A.p, 'Paso 1 de 5', 4000)) await registrar(A.p, 'Rosa', e);
  log('A con sesión (paso 1 del perfil):', await k.waitText(A.p, 'Paso 1 de 5', 3000));
  // B: otro dispositivo, sin sesión.
  const B = await k.open('rec3-nuevo');
  await k.waitText(B.p, 'COMENZAR AHORA', 15000);
  await k.tap(B.p, 'INICIA SESIÓN', { role: 'button' }); await B.p.waitForTimeout(1000);
  await k.tap(B.p, '¿Olvidaste'); await B.p.waitForTimeout(1200);
  const antes = fs.readdirSync('correo').length;
  await k.fill(B.p, 'Correo electrónico', e); await k.shot(B.p, 'E-recuperar-correo');
  await k.tap(B.p, 'Enviar código', { role: 'button' }); await B.p.waitForTimeout(2500);
  await k.dump(B.p, 'tras enviar'); await k.shot(B.p, 'E-recuperar-codigo');
  log('correos nuevos:', fs.readdirSync('correo').length - antes);
  const code = execFileSync('python3', ['-I', 'codigo.py', 'correo', e]).toString().trim();
  log('código leído del .eml, longitud', code.length);
  // primero un código inválido
  await k.fill(B.p, 'Código de recuperación', 'codigo-invalido-123');
  await k.fill(B.p, 'Nueva contraseña', 'Nueva12345'); await k.fill(B.p, 'Confirmar contraseña', 'Nueva12345');
  await k.tap(B.p, 'Actualizar contraseña', { role: 'button' }); await B.p.waitForTimeout(1500);
  log('código inválido → aviso:', await k.waitText(B.p, 'no es válido', 2000)); await k.shot(B.p, 'E-recuperar-invalido');
  await B.p.waitForTimeout(4000);
  await k.fill(B.p, 'Código de recuperación', code);
  await k.tap(B.p, 'Actualizar contraseña', { role: 'button' }); await B.p.waitForTimeout(2000);
  log('tras el cambio → login:', await k.waitText(B.p, 'INICIAR SESIÓN', 4000)); await k.shot(B.p, 'E-recuperar-hecho');
  log('BD token:', db.q(`SELECT count(*)||' tokens, usados='||count(used_at) FROM password_reset_tokens t JOIN users u USING(user_id) WHERE u.email='${e}'`));
  // contraseña antigua y nueva
  await B.p.waitForTimeout(3000);
  await k.fill(B.p, 'Correo', e); await k.fill(B.p, 'Contraseña', 'Kora12345'); await k.tap(B.p, 'INICIAR SESIÓN'); await B.p.waitForTimeout(2000);
  log('contraseña antigua sigue en login:', !(await k.waitText(B.p, 'Paso 1 de 5', 1500))); await k.shot(B.p, 'E-login-antigua');
  await B.p.waitForTimeout(3500);
  await k.fill(B.p, 'Contraseña', 'Nueva12345'); await k.tap(B.p, 'INICIAR SESIÓN');
  log('contraseña nueva entra:', await k.waitText(B.p, 'Paso 1 de 5', 15000));
  // A: su JWT anterior ya no vale.
  await A.p.reload(); await k.semantics(A.p); await A.p.waitForTimeout(3000);
  log('A tras recargar → login:', await k.waitText(A.p, 'INICIAR SESIÓN', 8000) || await k.waitText(A.p, 'COMENZAR AHORA', 2000));
  await k.dump(A.p, 'A'); await k.shot(A.p, 'E-sesion-antigua');
  await A.ctx.close(); await B.ctx.close(); process.exit(0);
})().catch(e => { console.log('ERROR', e.message); process.exit(1); });
