/* Optional browser regression: NODE_PATH=<Playwright installation> node tests/browser_ux.cjs
   Point ANALYTICS_TEST_URL at an isolated Analytics server. No data is written. */
const assert = require('node:assert/strict');
const { chromium } = require('playwright');
const base = process.env.ANALYTICS_TEST_URL || 'http://127.0.0.1:8877';
(async () => {
  const browser = await chromium.launch({channel: 'chrome', headless: true});
  try {
    const page = await browser.newPage({viewport: {width: 1440, height: 1000}});
    const errors = [];
    page.on('pageerror', error => errors.push(error.message));
    const waitView = name => page.waitForSelector(`#${name}[aria-busy=false]`);
    // Deliberately include a match beyond the first 30 and strings needing normalization/escaping.
    const artists = Array.from({length: 2000}, (_, i) => `Artist ${String(i).padStart(4,'0')}`);
    artists[1999] = 'ＺＥＬＤＡ <test> & ピアノ';
    await page.route('**/api/ranking-filters', route => route.fulfill({json: {artists, genres:['Rock', 'ピアノ']}}));
    await page.goto(`${base}/#rankings`);
    await waitView('rankings');
    const artist = page.locator('#ranking-artist-input');
    await artist.focus();
    assert.equal(await page.locator('#ranking-artist [role=option]').count(), 30);
    await artist.fill('zelda ピアノ');
    assert.equal(await page.locator('#ranking-artist [role=option]').count(), 1);
    await artist.press('ArrowDown');
    await artist.press('Enter');
    await waitView('rankings');
    assert.equal(await artist.inputValue(), artists[1999]);
    assert.match(await page.locator('#rankings .condition-summary').textContent(), /ＺＥＬＤＡ <test>/);
    assert.equal(await page.locator('#ranking-artist test').count(), 0);
    await artist.fill('no-such-artist');
    assert.match(await page.locator('#ranking-artist .picker-hint').textContent(), /一致する候補がありません/);
    await artist.press('Escape');
    assert.equal(await artist.inputValue(), artists[1999]);
    await page.locator('#ranking-artist .picker-clear').click();
    await waitView('rankings');
    assert.equal(await artist.inputValue(), '');
    await page.locator('[data-ranking-view=albums]').click();
    assert.equal(await page.locator('.ranking-panel:visible').count(), 1);
    await page.locator('[data-ranking-view=all]').click();
    // Newest request wins even when an older response arrives later.
    let releaseOld;
    const oldGate = new Promise(resolve => {releaseOld=resolve});
    let sawOld;
    const oldStarted = new Promise(resolve => {sawOld=resolve});
    await page.route('**/api/rankings?**', async route => {
      const url = new URL(route.request().url());
      const period = url.searchParams.get('period');
      if (period === '7d') {sawOld(); await oldGate;}
      await route.fulfill({json:{items:[{label:`result-${period}`, value:3}],legacyPlaybackCutoff:'2026-09-01'}}).catch(()=>{});
    });
    await page.locator('#rankings [data-period="7d"]').click();
    await oldStarted;
    await page.locator('#rankings [data-period="today"]').click();
    await waitView('rankings');
    releaseOld();
    await page.waitForTimeout(100);
    assert.match(await page.locator('#ranking-tracks').textContent(), /result-today/);
    assert.doesNotMatch(await page.locator('#ranking-tracks').textContent(), /result-7d/);
    await page.unroute('**/api/rankings?**');
    // Error is visible even with the date editor collapsed, and retry recovers.
    await page.route('**/api/rankings?**', route=>route.fulfill({status:503,json:{detail:'テスト通信エラー'}}));
    await page.locator('#rankings [data-period="30d"]').click();
    await waitView('rankings');
    assert.equal(await page.locator('#rankings .view-status').isVisible(),true);
    assert.match(await page.locator('#rankings .view-status').textContent(), /テスト通信エラー/);
    await page.unroute('**/api/rankings?**');
    await page.locator('#rankings .view-status button').click();
    await waitView('rankings');
    assert.equal(await page.locator('#rankings .view-status').isVisible(),false);
    await page.locator('#rankings [data-period="custom"]').click();
    await waitView('rankings');
    await page.locator('#rankings-start-date').fill('2026-09-05');
    await page.locator('#rankings-end-date').fill('2026-09-01');
    await page.locator('#rankings-end-date').press('Tab');
    await waitView('rankings');
    assert.match(await page.locator('#rankings .view-status').textContent(), /終了日は開始日以降/);
    await page.locator('#rankings [data-period="30d"]').click();
    await waitView('rankings');
    // Real API flow and layout at desktop, tablet and phone widths.
    for (const width of [1440, 768, 390]) {
      await page.setViewportSize({width, height:1000});
      for (const name of ['dashboard','history','insights','rankings','tracks','sources','import']) {
        await page.locator(`.nav-item[data-page=${name}]`).click();
        await waitView(name);
        assert.equal(await page.locator(`#${name}.load-failed`).count(),0,`${name} load`);
        assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth),true,`${name} overflow at ${width}`);
      }
    }
    await page.locator('[data-page=tracks]').click();
    await waitView('tracks');
    const tracksTableScroll = await page.locator('#tracks .table-wrap').evaluate(element => ({
      clientHeight: element.clientHeight,
      scrollHeight: element.scrollHeight,
      overflowY: getComputedStyle(element).overflowY,
      headerPosition: getComputedStyle(element.querySelector('thead th')).position,
      firstColumnPosition: getComputedStyle(element.querySelector('tbody td')).position,
    }));
    assert.equal(tracksTableScroll.scrollHeight, tracksTableScroll.clientHeight);
    assert.notEqual(tracksTableScroll.overflowY, 'scroll');
    assert.equal(tracksTableScroll.headerPosition, 'static');
    assert.equal(tracksTableScroll.firstColumnPosition, 'static');
    assert.equal(await page.locator('.tracks-table th').nth(8).isVisible(),false);
    await page.locator('#track-details').check();
    assert.equal(await page.locator('.tracks-table th').nth(8).isVisible(),true);
    await page.locator('#track-title').fill('UNMATCHABLE-UX-TEST');
    await page.waitForTimeout(350);
    await waitView('tracks');
    assert.match(await page.locator('#tracks-pagination').textContent(), /0件中 0–0件/);
    await page.locator('[data-page=sources]').click();
    await waitView('sources');
    const sourcesTableScroll = await page.locator('#sources .table-wrap').evaluate(element => ({
      clientHeight: element.clientHeight,
      scrollHeight: element.scrollHeight,
      headerPosition: getComputedStyle(element.querySelector('thead th')).position,
      firstColumnPosition: getComputedStyle(element.querySelector('tbody td')).position,
    }));
    assert.equal(sourcesTableScroll.scrollHeight, sourcesTableScroll.clientHeight);
    assert.equal(sourcesTableScroll.headerPosition, 'static');
    assert.equal(sourcesTableScroll.firstColumnPosition, 'static');
    await page.locator('#source-search').fill('UNMATCHABLE-UX-TEST');
    await page.waitForTimeout(350);
    await waitView('sources');
    assert.match(await page.locator('#sources-body').textContent(), /一致するデータがありません/);
    assert.match(await page.locator('#sources-pagination').textContent(), /0件中 0–0件/);
    await page.locator('#clear-source-search').click();
    await waitView('sources');
    assert.deepEqual(errors, []);
    console.log('PASS: 2,000 options, normalization, keyboard, no matches, clear, dimensions, stale response, retry, dates, details, global search, all 7 pages at 3 widths, no JS errors.');
  } finally {await browser.close();}
})().catch(error=>{console.error(error);process.exitCode=1});
