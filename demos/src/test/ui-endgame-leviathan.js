// Forces a Leviathan Hunt match to its last harpoon to check the game-over and path review screens.
const { chromium } = require("playwright");
const path = require("path");
const OUT = process.argv[2] || ".";
(async () => {
  const browser = await chromium.launch();
  const page = await (await browser.newContext({ viewport: { width: 390, height: 844 }, deviceScaleFactor: 1 })).newPage();
  const errors = [];
  page.on("pageerror", (e) => errors.push(e.message));
  await page.goto("file://" + path.resolve("demos/leviathan/index.html"));
  await page.waitForTimeout(300);
  await page.click('.seg button:has-text("Bot")');
  await page.click('.seg button:has-text("Hunters")');
  await page.click("#btn-start");
  await page.waitForFunction(() => { const d = window.__leviathanDebug; return d && d.G.mode === "hunters" && d.G.resolver; }, null, { timeout: 15000 });
  await page.evaluate(() => {
    const { G, runHunterOrder } = window.__leviathanDebug;
    const st = G.state;
    st.monster.wounds = 2;
    const h = st.ships[1];
    // put the harpoon ship two tiles from the monster on open water if possible
    h.pos = st.ships[1].pos;
    runHunterOrder({ type: "harpoon", ship: 1, target: st.monster.pos });
  });
  await page.waitForSelector(".modal", { timeout: 15000 });
  await page.waitForTimeout(300);
  await page.screenshot({ path: OUT + "/lev-11-gameover.png" });
  await page.click('.modal button:has-text("See the Leviathan")');
  await page.waitForTimeout(500);
  await page.screenshot({ path: OUT + "/lev-12-review.png" });
  console.log("status:", await page.textContent("#st-main"), "|", await page.textContent("#st-sub"));
  console.log("errors:", errors.length ? errors : "none");
  await browser.close();
})();
