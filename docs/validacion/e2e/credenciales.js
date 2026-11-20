// Credenciales de las cuentas sintéticas del arnés: se leen del entorno, nunca se escriben aquí.
// Ejemplo: E2E_PASSWORD=... E2E_NEW_PASSWORD=... node recuperar.js
function req(name) { const v = process.env[name]; if (!v) throw new Error(`Define ${name} (contraseña de las cuentas sintéticas locales)`); return v; }
module.exports = {
  get E2E_PASSWORD() { return req('E2E_PASSWORD'); },
  get E2E_NEW_PASSWORD() { return req('E2E_NEW_PASSWORD'); },
};
