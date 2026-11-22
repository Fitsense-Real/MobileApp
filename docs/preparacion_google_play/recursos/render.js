// Renders Kora's launcher icon (same shapes as android/app/src/main/res/drawable/kora_icon.xml) to PNG.
const { chromium } = require('playwright');
const svg = n => `<svg xmlns="http://www.w3.org/2000/svg" width="${n}" height="${n}" viewBox="0 0 108 108">
<path fill="#D9FF59" d="M28,8 H80 Q100,8 100,28 V80 Q100,100 80,100 H28 Q8,100 8,80 V28 Q8,8 28,8 Z"/>
<path fill="#0F2E25" d="M64,26 A8,8 0,1 1,64,42 A8,8 0,1 1,64,26 Z"/>
<path fill="none" stroke="#0F2E25" stroke-width="13" stroke-linecap="round" stroke-linejoin="round" d="M42,45 L35,74 L65,53 M50,64 L70,78"/></svg>`;
(async () => {
  const b = await chromium.launch(); const out = process.argv[2];
  for (const [dir, n] of [['mdpi', 48], ['hdpi', 72], ['xhdpi', 96], ['xxhdpi', 144], ['xxxhdpi', 192], ['play', 512]]) {
    const p = await b.newPage({ viewport: { width: n, height: n }, deviceScaleFactor: 1 });
    await p.setContent(`<html><body style="margin:0;background:transparent">${svg(n)}</body></html>`);
    await p.screenshot({ path: `${out}/${dir}.png`, omitBackground: true, clip: { x: 0, y: 0, width: n, height: n } });
    await p.close();
  }
  await b.close();
})();
