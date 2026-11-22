// Google Play store icon: 512×512, full square (Play applies its own mask), no transparency.
const { chromium } = require('playwright');
const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512" viewBox="0 0 108 108">
<rect width="108" height="108" fill="#D9FF59"/>
<g transform="translate(54 54) scale(0.95) translate(-54 -54)">
<path fill="#0F2E25" d="M64,26 A8,8 0,1 1,64,42 A8,8 0,1 1,64,26 Z"/>
<path fill="none" stroke="#0F2E25" stroke-width="13" stroke-linecap="round" stroke-linejoin="round" d="M42,45 L35,74 L65,53 M50,64 L70,78"/></g></svg>`;
(async () => { const b = await chromium.launch(); const p = await b.newPage({ viewport: { width: 512, height: 512 } });
  await p.setContent(`<html><body style="margin:0">${svg}</body></html>`);
  await p.screenshot({ path: process.argv[2], clip: { x: 0, y: 0, width: 512, height: 512 } }); await b.close(); })();
