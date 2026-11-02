// Renders HTML/SVG pages to PNG with headless Chromium (Playwright).
// usage: node render.js jobs.json
const { chromium } = require('playwright');
const fs = require('fs');
(async () => {
  const jobs = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
  const browser = await chromium.launch();
  const page = await browser.newPage();
  for (const j of jobs) {
    await page.setViewportSize({ width: j.w, height: j.h });
    await page.goto('file://' + j.html, { waitUntil: 'load' });
    await page.evaluate(() => document.fonts.ready);
    await page.waitForTimeout(150);
    await page.screenshot({ path: j.png, omitBackground: !!j.transparent, timeout: 300000, clip: { x: 0, y: 0, width: j.w, height: j.h } });
    console.log('rendered', j.png);
  }
  await browser.close();
})();
