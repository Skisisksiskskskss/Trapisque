// Drives the built Liar's Gambit page in a headless phone browser.
const { chromium } = require("playwright");
const path = require("path");
const OUT = process.argv[2] || ".";

async function clickSq(page, r, c) {
  const el = await page.$(`.hit-layer rect[data-r="${r}"][data-c="${c}"]`);
  const b = await el.boundingBox();
  await page.mouse.click(b.x + b.width / 2, b.y + b.height / 2);
}

async function humanAct(page, k) {
  // Answer a pending call prompt, give up a piece if asked, then make a move.
  const mode = await page.evaluate(() => window.__liarsDebug.G.mode);
  if (mode === "challenge") {
    const liar = await page.$('.actionbar button:has-text("LIAR!")');
    const letgo = await page.$('.actionbar button:has-text("Let it go")');
    if (letgo && k % 4 !== 3) await letgo.click(); else if (liar) await liar.click();
    await page.waitForTimeout(400);
    return "answered";
  }
  if (mode === "sacrifice") {
    const sq = await page.evaluate(() => {
      const { G } = window.__liarsDebug; const st = G.state;
      const p = st.pieces.find((q) => q.owner === G.viewer && q.alive && q.type !== "C");
      const r = Math.floor(p.sq / 6), c = p.sq % 6;
      return G.viewer === 1 ? [6 - r, 5 - c] : [r, c];
    });
    await clickSq(page, sq[0], sq[1]);
    await page.waitForTimeout(150);
    await page.click('.actionbar .btn-danger');
    await page.waitForTimeout(400);
    return "sacrificed";
  }
  if (mode === "move") {
    const mv = await page.evaluate((k) => {
      const { G } = window.__liarsDebug; const st = G.state;
      const LG = window.Liars;
      const moves = LG.legalMoves(st, G.viewer);
      const honest = moves.filter((m) => LG.isHonest(st, m));
      const pool = (k % 5 === 4 ? moves : honest.length ? honest : moves);
      const m = pool[(k * 7) % pool.length];
      const conv = (sq) => { const r = Math.floor(sq / 6), c = sq % 6; return G.viewer === 1 ? [6 - r, 5 - c] : [r, c]; };
      return { from: conv(m.from), to: conv(m.to) };
    }, k);
    await clickSq(page, mv.from[0], mv.from[1]);
    await page.waitForTimeout(120);
    await clickSq(page, mv.to[0], mv.to[1]);
    await page.waitForTimeout(120);
    if (k === 2) await page.screenshot({ path: OUT + "/liar-04-pending.png" });
    const conf = await page.$('.actionbar .btn-primary');
    if (conf) await conf.click();
    await page.waitForTimeout(500);
    return "moved";
  }
  return mode;
}

(async () => {
  const browser = await chromium.launch();
  const page = await (await browser.newContext({ viewport: { width: 390, height: 844 }, deviceScaleFactor: 1 })).newPage();
  const errors = [];
  page.on("pageerror", (e) => errors.push("pageerror: " + e.message));
  page.on("console", (m) => { if (m.type() === "error" && !/fonts\.g/.test(m.text())) errors.push("console: " + m.text()); });
  await page.goto("file://" + path.resolve("demos/liars/index.html"));
  await page.waitForTimeout(400);
  await page.screenshot({ path: OUT + "/liar-01-title.png" });
  await page.click("#btn-start");
  await page.waitForTimeout(500);
  await page.screenshot({ path: OUT + "/liar-02-setup.png" });
  await page.click('.actionbar button:has-text("Ready")');
  await page.waitForTimeout(600);
  await page.screenshot({ path: OUT + "/liar-03-start.png" });
  let k = 0, safety = 0;
  while (safety++ < 200) {
    const st = await page.evaluate(() => { const G = window.__liarsDebug.G; return { winner: G.state.winner, mode: G.mode, turn: G.state.turn, ply: G.state.ply }; });
    if (st.winner != null || st.mode === "over") break;
    if (st.mode === "move" || st.mode === "challenge" || st.mode === "sacrifice") {
      const r = await humanAct(page, k++);
      if (k === 6) await page.screenshot({ path: OUT + "/liar-05-mid.png" });
    } else {
      await page.waitForTimeout(400);
    }
    if (k > 60) break;
  }
  await page.waitForTimeout(2500);
  await page.screenshot({ path: OUT + "/liar-06-end.png" });
  const fin = await page.evaluate(() => { const G = window.__liarsDebug.G; return { winner: G.state.winner, reason: G.state.reason, ply: G.state.ply, mode: G.mode }; });
  console.log("bot game:", JSON.stringify(fin), "human actions:", k);

  // Same-phone game: two setups with covers, then a couple of turns.
  await page.evaluate(() => { document.querySelectorAll(".modal-wrap").forEach((n) => n.remove()); });
  const quit = await page.$("#btn-menu");
  await quit.click(); await page.waitForTimeout(200);
  await page.click('.modal button:has-text("Quit to title")'); await page.waitForTimeout(200);
  await page.click('.modal button:has-text("Yes")'); await page.waitForTimeout(300);
  await page.click('.seg button:has-text("Friend, same phone")');
  await page.click("#btn-start");
  await page.waitForTimeout(300);
  await page.screenshot({ path: OUT + "/liar-07-local-cover.png" });
  await page.click(".cover .btn"); await page.waitForTimeout(200);
  await page.click('.actionbar button:has-text("Ready")'); await page.waitForTimeout(200);
  await page.click(".cover .btn"); await page.waitForTimeout(200);
  await page.click('.actionbar button:has-text("Ready")'); await page.waitForTimeout(200);
  await page.click(".cover .btn"); await page.waitForTimeout(300);
  for (let t = 0; t < 4; t++) {
    const mode = await page.evaluate(() => window.__liarsDebug.G.mode);
    if (await page.$(".cover .btn")) { await page.click(".cover .btn"); await page.waitForTimeout(250); continue; }
    await humanAct(page, t);
    await page.waitForTimeout(300);
    if (t === 1) await page.screenshot({ path: OUT + "/liar-08-local-mid.png" });
  }
  const leak = await page.evaluate(() => {
    const { G } = window.__liarsDebug; const st = G.state;
    // every visible enemy piece that is not revealed must show a mask
    return st.pieces.filter((p) => p.owner !== G.viewer && p.alive && !p.revealed).length;
  });
  console.log("hidden enemy pieces for current viewer:", leak);
  console.log("errors:", errors.length ? errors : "none");
  await browser.close();
})();
