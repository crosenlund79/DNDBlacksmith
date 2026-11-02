// Renders HTML/SVG pages to PNG with headless Chromium (Playwright), N pages in parallel.
// usage: node render.js jobs.json [workers]
const { chromium } = require('playwright');
const fs = require('fs');
(async () => {
  const jobs = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
  const workers = parseInt(process.argv[3] || '4', 10);
  const browser = await chromium.launch();
  let next = 0;
  async function worker() {
    const page = await browser.newPage();
    while (next < jobs.length) {
      const j = jobs[next++];
      await page.setViewportSize({ width: j.w, height: j.h });
      await page.goto('file://' + j.html, { waitUntil: 'load' });
      await page.evaluate(() => document.fonts.ready);
      await page.waitForTimeout(60);
      await page.screenshot({ path: j.png, omitBackground: !!j.transparent, timeout: 300000,
                              clip: { x: 0, y: 0, width: j.w, height: j.h } });
    }
    await page.close();
  }
  await Promise.all(Array.from({ length: Math.min(workers, jobs.length) }, worker));
  await browser.close();
  console.log('rendered', jobs.length);
})();
