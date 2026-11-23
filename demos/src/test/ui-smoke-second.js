// Plays Second Guess in a headless phone browser: plans orders by tapping, locks in, watches reveals.
const { chromium } = require("playwright");
const path = require("path");
const OUT = process.argv[2] || ".";
(async () => {
  const browser = await chromium.launch();
  const page = await (await browser.newContext({ viewport: { width: 390, height: 844 }, deviceScaleFactor: 1 })).newPage();
  const errors = [];
  page.on("pageerror", (e) => errors.push("pageerror: " + e.message));
  page.on("console", (m) => { if (m.type() === "error" && !/fonts\.g/.test(m.text())) errors.push("console: " + m.text()); });
  await page.goto("file://" + path.resolve("demos/second/index.html"));
  await page.waitForTimeout(400);
  await page.screenshot({ path: OUT + "/sg-01-title.png" });
  await page.click("#btn-start");
  await page.waitForTimeout(500);
  let turns = 0;
  for (let i = 0; i < 300 && turns < 25; i++) {
    const st = await page.evaluate(() => { const G = window.__secondDebug.G; return { over: G.state.winner != null, planning: G.phase === "plan" && !!G.resolver, turn: G.state.turn }; });
    if (st.over) break;
    if (!st.planning) { await page.waitForTimeout(300); continue; }
    // give each unit an order: alternate move / attack using highlighted squares
    for (let u = 0; u < 4; u++) {
      const cards = await page.$$(".ucard:not([disabled])");
      if (u >= cards.length) break;
      await cards[u].click();
      await page.waitForTimeout(60);
      if ((u + turns) % 3 === 1) {
        const atk = await page.$('.modes button:has-text("Attack")');
        if (atk) { await atk.click(); await page.waitForTimeout(60); }
        const tiles = await page.$$(".hl rect");
        if (tiles.length) { const b = await tiles[(turns * 5 + u) % tiles.length].boundingBox(); await page.mouse.click(b.x + b.width / 2, b.y + b.height / 2); }
      } else if ((u + turns) % 5 === 3) {
        await page.click('.modes button:has-text("Brace")');
      } else {
        const tiles = await page.$$(".hl rect");
        if (tiles.length) { const b = await tiles[(turns * 3 + u) % tiles.length].boundingBox(); await page.mouse.click(b.x + b.width / 2, b.y + b.height / 2); }
      }
      await page.waitForTimeout(60);
    }
    if (turns === 1) await page.screenshot({ path: OUT + "/sg-02-planned.png" });
    await page.click('.actionbar button:has-text("Lock in orders")');
    turns++;
    await page.waitForTimeout(1500);
    if (turns === 2) await page.screenshot({ path: OUT + "/sg-03-reveal.png" });
    await page.waitForTimeout(2200);
  }
  await page.waitForTimeout(2500);
  await page.screenshot({ path: OUT + "/sg-04-end.png" });
  const fin = await page.evaluate(() => { const G = window.__secondDebug.G; return { winner: G.state.winner, scores: G.state.scores, turn: G.state.turn, reason: G.state.reason }; });
  console.log("bot game:", JSON.stringify(fin), "turns planned:", turns);
  // same-phone flow
  await page.evaluate(() => document.querySelectorAll(".modal-wrap").forEach((n) => n.remove()));
  await page.click("#btn-menu"); await page.waitForTimeout(150);
  await page.click('.modal button:has-text("Quit to title")'); await page.waitForTimeout(150);
  await page.click('.modal button:has-text("Yes")'); await page.waitForTimeout(250);
  await page.click('.seg button:has-text("Friend, same phone")');
  await page.click("#btn-start"); await page.waitForTimeout(300);
  await page.click(".cover .btn"); await page.waitForTimeout(200);
  await page.click('.actionbar button:has-text("Lock in orders")'); await page.waitForTimeout(200);
  await page.screenshot({ path: OUT + "/sg-05-local-cover.png" });
  await page.click(".cover .btn"); await page.waitForTimeout(200);
  await page.screenshot({ path: OUT + "/sg-06-local-red.png" });
  await page.click('.actionbar button:has-text("Lock in orders")'); await page.waitForTimeout(200);
  await page.click(".cover .btn"); await page.waitForTimeout(2500);
  console.log("local turn after reveal:", await page.evaluate(() => window.__secondDebug.G.state.turn));
  console.log("errors:", errors.length ? errors : "none");
  await browser.close();
})();
