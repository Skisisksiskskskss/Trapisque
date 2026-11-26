// Drives the built Leviathan Hunt page in a headless phone browser, using only taps on the board and crew cards.
// Usage: node demos/src/test/ui-smoke-leviathan.js OUTDIR
const { chromium } = require("playwright");
const path = require("path");
const OUT = process.argv[2] || ".";

async function tapTile(page, i) {
  const el = await page.$(`.hit-layer polygon[data-i="${i}"]`);
  const b = await el.boundingBox();
  await page.mouse.click(b.x + b.width / 2, b.y + b.height / 2);
}
async function quitToTitle(page) {
  await page.evaluate(() => document.querySelectorAll(".modal-wrap,.cover").forEach((n) => n.remove()));
  await page.click("#btn-menu");
  await page.waitForTimeout(200);
  await page.click('.modal button:has-text("Quit to title")');
  await page.waitForTimeout(200);
  await page.click('.modal button:has-text("Yes")');
  await page.waitForTimeout(300);
}
async function waitFor(page, fn, ms) {
  const end = Date.now() + (ms || 20000);
  while (Date.now() < end) { if (await page.evaluate(fn)) return true; await page.waitForTimeout(150); }
  return false;
}

(async () => {
  const browser = await chromium.launch();
  const ctx = await browser.newContext({ viewport: { width: 390, height: 844 }, deviceScaleFactor: 1, hasTouch: true });
  const page = await ctx.newPage();
  const errors = [];
  page.on("pageerror", (e) => errors.push("pageerror: " + e.message));
  page.on("console", (m) => { if (m.type() === "error" && !/fonts\.g/.test(m.text())) errors.push("console: " + m.text()); });
  await page.goto("file://" + path.resolve("demos/leviathan/index.html"));
  await page.waitForTimeout(500);
  await page.screenshot({ path: OUT + "/lev-01-title.png" });

  // Bot game as the hunters: every order is a tap on the board.
  await page.click("#btn-start");
  const hunterTurn = () => { const G = window.__leviathanDebug.G; return (G.mode === "hunters" && !!G.resolver && !G.locked) || !!G.state.winner; };
  await waitFor(page, hunterTurn);
  await page.screenshot({ path: OUT + "/lev-02-hunters-start.png" });
  let orders = 0, undos = 0;
  for (let turn = 0; turn < 8; turn++) {
    if (!(await waitFor(page, hunterTurn, 30000))) break;
    if (await page.evaluate(() => !!window.__leviathanDebug.G.state.winner)) break;
    for (let n = 0; n < 6; n++) {
      const pick = await page.evaluate((n) => {
        const D = window.__leviathanDebug, G = D.G, T = G.targets;
        if (!(G.mode === "hunters" && G.resolver && !G.locked)) return null;
        const tool = Object.keys(T.tool).map(Number), sail = Object.keys(T.sail).map(Number);
        const st = G.state, sh = st.ships[G.sel];
        if (T.self && n % 2 === 0) return { tile: sh.pos, what: "self" };
        if (tool.length && n % 3 === 1) return { tile: tool[(n * 7) % tool.length], what: "tool" };
        if (sail.length) return { tile: sail[(n * 5) % sail.length], what: "sail" };
        if (T.self) return { tile: sh.pos, what: "self" };
        if (tool.length) return { tile: tool[0], what: "tool" };
        const other = st.ships.findIndex((s, k) => k !== G.sel && !s.sunk && (!s.moved || !s.acted));
        return other >= 0 ? { tile: st.ships[other].pos, what: "select" } : null;
      }, n);
      if (!pick) break;
      await tapTile(page, pick.tile);
      if (pick.what !== "select") orders++;
      await page.waitForTimeout(250);
      await waitFor(page, () => !window.__leviathanDebug.G.locked, 15000);
      if (turn === 0 && n === 0) await page.screenshot({ path: OUT + "/lev-03-first-order.png" });
      if (await page.$('.bar-row button:has-text("Undo")')) {
        if (turn === 1 && !undos) { await page.screenshot({ path: OUT + "/lev-04-undo.png" }); await page.click('.bar-row button:has-text("Undo")'); undos++; await page.waitForTimeout(250); }
      }
      if (!(await page.evaluate(() => { const G = window.__leviathanDebug.G; return G.mode === "hunters" && !!G.resolver; }))) break;
    }
    if (turn === 2) await page.screenshot({ path: OUT + "/lev-05-midturn.png" });
    const end = await page.$('.bar-row button:has-text("End turn")');
    if (end && await page.evaluate(() => { const G = window.__leviathanDebug.G; return G.mode === "hunters" && !!G.resolver; })) await end.click();
    await page.waitForTimeout(600);
  }
  await page.screenshot({ path: OUT + "/lev-06-later.png" });
  const st = await page.evaluate(() => { const s = window.__leviathanDebug.G.state; return { round: s.round, wounds: s.monster.wounds, kills: s.monster.kills, winner: s.winner }; });
  console.log("bot game:", JSON.stringify(st), "orders tapped:", orders, "undos:", undos);

  // Rules
  await page.evaluate(() => document.querySelectorAll(".modal-wrap").forEach((n) => n.remove()));
  await page.click("#btn-menu"); await page.waitForTimeout(150);
  await page.click('.modal button:has-text("How to play")'); await page.waitForTimeout(250);
  await page.screenshot({ path: OUT + "/lev-07-rules.png" });
  await page.click('.modal button:has-text("Got it")'); await page.waitForTimeout(200);
  await page.evaluate(() => document.querySelectorAll(".modal-wrap").forEach((n) => n.remove()));
  await quitToTitle(page);

  // Play the monster against the bot hunters.
  await page.click('.seg button:has-text("Gnasher")');
  await page.click("#btn-start");
  await waitFor(page, () => window.__leviathanDebug.G.mode === "start");
  const zone = await page.evaluate(() => { const G = window.__leviathanDebug.G; return window.Leviathan.startZone(G.state)[3]; });
  await tapTile(page, zone); await page.waitForTimeout(150);
  await page.screenshot({ path: OUT + "/lev-08-monster-start.png" });
  await tapTile(page, zone);
  for (let t = 0; t < 3; t++) {
    if (!(await waitFor(page, () => { const G = window.__leviathanDebug.G; return (G.mode === "monster" && !!G.resolver) || !!G.state.winner; }, 30000))) break;
    if (await page.evaluate(() => !!window.__leviathanDebug.G.state.winner)) break;
    const to = await page.evaluate(() => { const G = window.__leviathanDebug.G; const o = G.monsterOpts.find((x) => x.type === "swim" && x.to !== G.state.monster.pos) || G.monsterOpts[0]; return o.type === "strike" ? G.state.ships[o.ship].pos : o.to; });
    await tapTile(page, to); await page.waitForTimeout(120);
    if (t === 0) await page.screenshot({ path: OUT + "/lev-09-monster-turn.png" });
    await tapTile(page, to); await page.waitForTimeout(400);
  }
  console.log("monster game round:", await page.evaluate(() => window.__leviathanDebug.G.state.round));
  await quitToTitle(page);

  // Same phone: the first cover is for the monster.
  await page.click('.seg button:has-text("Friend, same phone")');
  await page.click("#btn-start"); await page.waitForTimeout(400);
  await page.screenshot({ path: OUT + "/lev-10-local-cover.png" });
  console.log("errors:", errors.length ? errors : "none");
  await browser.close();
})();
