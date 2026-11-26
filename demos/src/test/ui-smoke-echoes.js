// Plays a whole Echoes match in a headless phone browser by tapping highlighted squares.
const { chromium } = require("playwright");
const path = require("path");
const OUT = process.argv[2] || ".";
(async () => {
  const browser = await chromium.launch();
  const page = await (await browser.newContext({ viewport: { width: 390, height: 844 }, deviceScaleFactor: 1 })).newPage();
  const errors = [];
  page.on("pageerror", (e) => errors.push("pageerror: " + e.message));
  page.on("console", (m) => { if (m.type() === "error" && !/fonts\.g/.test(m.text())) errors.push("console: " + m.text()); });
  await page.goto("file://" + path.resolve("demos/echoes/index.html"));
  await page.waitForTimeout(400);
  await page.screenshot({ path: OUT + "/echo-01-title.png" });
  await page.click("#btn-start");
  let k = 0, shots = 0;
  for (let i = 0; i < 400; i++) {
    const st = await page.evaluate(() => { const G = window.__echoesDebug.G; return { phase: G.state.phase, waiting: !!G.resolver, round: G.state.round, tick: G.state.tick }; });
    if (st.phase === "over") break;
    if (!st.waiting) { await page.waitForTimeout(250); continue; }
    if (st.round === 2 && st.tick === 2 && shots === 0) { await page.screenshot({ path: OUT + "/echo-02-round2.png" }); shots++; }
    if (st.round === 4 && st.tick === 3 && shots === 1) { await page.screenshot({ path: OUT + "/echo-03-round4.png" }); shots++; }
    // prefer moving toward the top-left plate in round 1, otherwise first highlighted option
    const opts = await page.$$(".opts rect, .opts circle");
    if (opts.length && k % 5 !== 4) {
      const pick = opts[(k * 3) % opts.length];
      const b = await pick.boundingBox();
      await page.mouse.click(b.x + b.width / 2, b.y + b.height / 2);
    } else {
      await page.click('.actionbar button:has-text("Wait")');
    }
    k++;
    await page.waitForTimeout(120);
  }
  await page.waitForTimeout(2500);
  await page.screenshot({ path: OUT + "/echo-04-end.png" });
  const fin = await page.evaluate(() => { const G = window.__echoesDebug.G; return { scores: G.state.scores, winner: G.state.winner, rounds: G.state.roundScores }; });
  console.log("result:", JSON.stringify(fin), "human moves:", k);
  console.log("errors:", errors.length ? errors : "none");
  await browser.close();
})();
