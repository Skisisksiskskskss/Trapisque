// Plays Keyrunners in a headless phone browser: crew select, taps on the board, bot turns, then pass-and-play.
// Usage: node demos/src/test/ui-smoke-keyrunners.js OUTDIR [turns]
const { chromium } = require("playwright");
const path = require("path");
const OUT = process.argv[2] || ".";
const TURNS = +(process.argv[3] || 8);

async function tapTile(page, t) {
  const r = await page.$(`.hit-layer rect[data-t="${t}"]`);
  const b = await r.boundingBox();
  await page.mouse.click(b.x + b.width / 2, b.y + b.height / 2);
  await page.waitForTimeout(120);
}
async function waitHuman(page, ms) {
  const end = Date.now() + (ms || 30000);
  while (Date.now() < end) {
    const s = await page.evaluate(() => { const G = window.__krDebug.G; return { human: !!G.resolver && !G.busy, over: G.st && G.st.winner != null }; });
    if (s.over || s.human) return s;
    await page.waitForTimeout(200);
  }
  throw new Error("timed out waiting for the human turn");
}

(async () => {
  const browser = await chromium.launch();
  const ctx = await browser.newContext({ viewport: { width: 390, height: 844 }, deviceScaleFactor: 1 });
  const page = await ctx.newPage();
  const errors = [];
  page.on("pageerror", (e) => errors.push("pageerror: " + e.message));
  page.on("console", (m) => { if (m.type() === "error" && !/fonts\.g/.test(m.text())) errors.push("console: " + m.text()); });
  await page.goto("file://" + path.resolve("demos/keyrunners/index.html"));
  await page.waitForTimeout(400);
  await page.screenshot({ path: OUT + "/kr-01-title.png" });
  await page.click('.seg button:has-text("Fast")');
  await page.click("#btn-start");
  await page.waitForTimeout(300);
  await page.screenshot({ path: OUT + "/kr-02-crew.png" });
  await page.click('.presets button:has-text("All-rounders")');
  await page.click(".pick .card >> nth=5");
  await page.waitForTimeout(100);
  await page.screenshot({ path: OUT + "/kr-03-crew-edit.png" });
  // put it back to a full deck
  await page.click('.presets button:has-text("Runners")');
  await page.click("#btn-ready");
  await page.waitForTimeout(1200);
  await waitHuman(page);
  await page.screenshot({ path: OUT + "/kr-04-start.png" });

  // Turn 1 by hand: play the first affordable crew card on a lit tile, select the leader, look at its moves.
  await page.click(".hand .card >> nth=0");
  await page.waitForTimeout(150);
  await page.screenshot({ path: OUT + "/kr-05-card.png" });
  const deployT = await page.evaluate(() => { const G = window.__krDebug.G; const t = G.targets.list.find((x) => x.cls === "deploy"); return t ? t.t : -1; });
  if (deployT >= 0) await tapTile(page, deployT);
  await page.waitForTimeout(500);
  const leaderPos = await page.evaluate(() => { const G = window.__krDebug.G; return G.st.units.find((u) => u.leader && u.side === G.st.side).pos; });
  await tapTile(page, leaderPos);
  await page.waitForTimeout(200);
  await page.screenshot({ path: OUT + "/kr-06-leader.png" });
  await page.click("#btn-undo").catch(() => {});
  await page.waitForTimeout(200);
  await page.click("#btn-end");

  // Later turns: let the bot logic pick our moves, but play them through the interface's own action path.
  let turns = 1;
  for (; turns < TURNS; turns++) {
    const s = await waitHuman(page, 60000);
    if (s.over) break;
    if (turns === 2) await page.screenshot({ path: OUT + "/kr-07-after-bot.png" });
    const plan = await page.evaluate(() => { const D = window.__krDebug; return D.KR.bots.plan(D.G.st, "normal", Math.random); });
    for (const a of plan) {
      const ok = await page.evaluate((a) => window.__krDebug.KR.isLegal(window.__krDebug.G.st, a), a);
      if (!ok) break;
      await page.evaluate((a) => window.__krDebug.doHuman(a), a);
      await page.waitForTimeout(450);
    }
    if (turns === 3) {
      // inspect an enemy unit
      const foe = await page.evaluate(() => { const G = window.__krDebug.G; const u = G.st.units.find((x) => x.side !== G.st.side); return u ? u.pos : -1; });
      if (foe >= 0) { await tapTile(page, foe); await page.waitForTimeout(150); await page.screenshot({ path: OUT + "/kr-08-inspect.png" }); await tapTile(page, foe); }
    }
    const over = await page.evaluate(() => window.__krDebug.G.st.winner != null);
    if (over) break;
    await page.click("#btn-end");
  }
  await page.waitForTimeout(1500);
  await page.screenshot({ path: OUT + "/kr-09-midgame.png" });
  const st = await page.evaluate(() => { const G = window.__krDebug.G; return { ply: G.st.ply, winner: G.st.winner, how: G.st.how, mana: G.st.mana, units: G.st.units.length }; });
  console.log("bot game state:", JSON.stringify(st), "turns played:", turns);

  // Rules modal
  await page.evaluate(() => document.querySelectorAll(".modal-wrap").forEach((n) => n.remove()));
  await page.click("#btn-menu"); await page.waitForTimeout(150);
  await page.click('.modal button:has-text("How to play")'); await page.waitForTimeout(200);
  await page.screenshot({ path: OUT + "/kr-10-rules.png" });
  await page.click('.modal button:has-text("Got it")'); await page.waitForTimeout(200);
  await page.click('.modal button:has-text("Quit to title")'); await page.waitForTimeout(150);
  await page.click('.modal button:has-text("Yes")'); await page.waitForTimeout(250);

  // Pass and play
  await page.click('.seg button:has-text("Friend, same phone")');
  await page.click("#btn-start"); await page.waitForTimeout(300);
  await page.click("#btn-ready"); await page.waitForTimeout(200);
  await page.click(".cover .btn"); await page.waitForTimeout(200);
  await page.click('.presets button:has-text("Fortress")');
  await page.click("#btn-ready"); await page.waitForTimeout(300);
  await page.screenshot({ path: OUT + "/kr-11-local-cover.png" });
  await page.click(".cover .btn"); await page.waitForTimeout(400);
  for (let i = 0; i < 4; i++) {
    await waitHuman(page);
    if (i === 1) await page.screenshot({ path: OUT + "/kr-12-local-red.png" });
    const plan = await page.evaluate(() => { const D = window.__krDebug; return D.KR.bots.plan(D.G.st, "easy", Math.random); });
    for (const a of plan) {
      const ok = await page.evaluate((a) => window.__krDebug.KR.isLegal(window.__krDebug.G.st, a), a);
      if (!ok) break;
      await page.evaluate((a) => window.__krDebug.doHuman(a), a);
      await page.waitForTimeout(350);
    }
    await page.click("#btn-end");
    await page.waitForTimeout(300);
    if (await page.$(".cover")) await page.click(".cover .btn");
    await page.waitForTimeout(300);
  }
  console.log("local ply:", await page.evaluate(() => window.__krDebug.G.st.ply), "viewer:", await page.evaluate(() => window.__krDebug.G.viewer));
  console.log("errors:", errors.length ? errors : "none");
  await browser.close();
})();
