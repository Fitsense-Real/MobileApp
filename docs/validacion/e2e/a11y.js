// Repaso del tour (Perfil -> Ver recorrido de Kora) en distintos tamanos; avanza con TECLADO.
const { k, log } = require('./lib');
(async () => {
  for (const [name, w, h, reduced] of [['320x568', 320, 568, false], ['horizontal-844x390', 844, 390, false], ['movimiento-reducido', 390, 844, true]]) {
    const { ctx, p } = await k.open('u1', { width: w, height: h, reducedMotion: reduced });
    try {
      await k.waitText(p, 'Hola, Ana', 20000);
      await k.tap(p, 'Perfil', { role: 'tab' }); await p.waitForTimeout(1200);
      await p.mouse.move(w / 2, h / 2); await p.mouse.wheel(0, 2000); await p.waitForTimeout(800); await k.tap(p, 'Ver recorrido de Kora'); await p.waitForTimeout(1500);
      for (let i = 1; i <= 10; i++) {
        await k.shot(p, `a11y-${name}-${String(i).padStart(2, '0')}`);
        // teclado: Tab hasta el boton principal de la tarjeta y Enter
        let ok = false;
        for (let t = 0; t < 8 && !ok; t++) {
          await p.keyboard.press('Tab'); await p.waitForTimeout(150);
          const f = await p.evaluate(() => { const a = document.activeElement; return a ? ((a.getAttribute('aria-label') || '') + ' ' + (a.textContent || '')).trim() : ''; });
          if (/Empezar|Siguiente|Ir a |Terminar/.test(f)) ok = f;
        }
        if (!ok) { log(name, 'paso', i, 'sin foco de teclado en el boton; uso clic'); await require('./lib').avanzar(p); continue; }
        await p.keyboard.press('Enter'); await p.waitForTimeout(1000);
        if (i === 1) log(name, 'teclado: foco en', JSON.stringify(ok));
      }
      log(name, 'fin; vuelve al inicio:', await k.waitText(p, 'Hola, Ana', 8000));
    } catch (e) { console.log('ERROR', name, e.message); await k.shot(p, `a11y-${name}-error`); }
    await ctx.close();
  }
  process.exit(0);
})();
