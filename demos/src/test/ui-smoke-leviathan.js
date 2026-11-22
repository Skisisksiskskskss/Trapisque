// Drives the built Leviathan Hunt page in a headless phone browser.
// Usage: node demos/src/test/ui-smoke-leviathan.js OUTDIR
const { chromium } = require("playwright");
const path = require("path");
const OUT = process.argv[2] || ".";

async function clickCenter(page, handle) {
  const b = await handle.boundingBox();
  if (!b) return false;
  await page.mouse.click(b.x + b.width / 2, b.y + b.height / 2);
  return true;
}

async function quitToTitle(page) {
  await page.click("#btn-menu");
  await page.waitForTimeout(200);
  await page.click('.modal button:has-text("Quit to title")');
  await page.waitForTimeout(200);
  await page.click('.modal button:has-text("Yes")');
  await page.waitForTimeout(300);
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

  // Bot game, playing the hunters.
  await page.click("#btn-start");
  await page.waitForTimeout(1500);
  await page.screenshot({ path: OUT + "/lev-02-hunters-start.png" });
  for (let round = 0; round < 6; round++) {
    const cards = await page.$$(".shipcard");
    if (!cards.length) { await page.waitForTimeout(1500); continue; }
    await cards[0].click();
    await page.waitForTimeout(150);
    const mv = await page.$$(".marks .hl-move");
    if (mv.length) {
      await clickCenter(page, mv[Math.floor(mv.length / 2)]);
      await page.waitForTimeout(150);
      const confirm = await page.$(".confirm-row .btn-primary");
      if (confirm) await confirm.click();
      await page.waitForTimeout(900);
    }
    const pingBtn = await page.$('.modes button:has-text("Ping")');
    if (pingBtn && !(await pingBtn.isDisabled())) {
      await pingBtn.click();
      await page.waitForTimeout(150);
      const conf = await page.$(".confirm-row .btn-primary");
      if (conf) await conf.click();
      await page.waitForTimeout(1800);
    }
    if (round === 0) await page.screenshot({ path: OUT + "/lev-03-after-ping.png" });
    const end = await page.$('.bar-row button:has-text("End turn"), .bar-row button:has-text("Done")');
    if (end) await end.click();
    await page.waitForTimeout(2600);
  }
  await page.screenshot({ path: OUT + "/lev-04-midgame.png" });
  console.log("status after hunters run:", await page.textContent("#st-main"), "|", await page.textContent("#st-sub"));

  // Bot game, playing the Leviathan.
  await quitToTitle(page);
  await page.click('.seg button:has-text("Leviathan")');
  await page.click("#btn-start");
  await page.waitForTimeout(700);
  await page.screenshot({ path: OUT + "/lev-05-monster-start.png" });
  const starts = await page.$$(".marks .hl-start");
  console.log("start tiles highlighted:", starts.length);
  if (starts.length) {
    await clickCenter(page, starts[3]);
    await page.waitForTimeout(150);
    await page.click('button:has-text("Hide here")');
  }
  for (let t = 0; t < 8; t++) {
    await page.waitForTimeout(1200);
    const swim = await page.$$(".marks .hl-swim");
    if (!swim.length) { await page.waitForTimeout(2500); continue; }
    await clickCenter(page, swim[t % swim.length]);
    await page.waitForTimeout(150);
    const conf = await page.$(".confirm-row .btn-primary");
    if (conf) await conf.click();
    if (t === 0) { await page.waitForTimeout(300); await page.screenshot({ path: OUT + "/lev-06-monster-moved.png" }); }
    await page.waitForTimeout(4500);
  }
  await page.screenshot({ path: OUT + "/lev-07-monster-mid.png" });
  console.log("status as monster:", await page.textContent("#st-main"), "|", await page.textContent("#st-sub"));

  // Same-phone game: cover screens must hide the monster.
  await quitToTitle(page);
  await page.click('.seg button:has-text("Friend, same phone")');
  await page.click("#btn-start");
  await page.waitForTimeout(500);
  await page.screenshot({ path: OUT + "/lev-08-local-cover.png" });
  await page.click(".cover .btn");
  await page.waitForTimeout(300);
  const st2 = await page.$$(".marks .hl-start");
  await clickCenter(page, st2[5]);
  await page.click('button:has-text("Hide here")');
  await page.waitForTimeout(400);
  const sw = await page.$$(".marks .hl-swim");
  await clickCenter(page, sw[0]);
  await page.click(".confirm-row .btn-primary");
  await page.waitForTimeout(900);
  await page.screenshot({ path: OUT + "/lev-09-local-pass.png" });
  await page.click(".cover .btn");
  await page.waitForTimeout(1200);
  const monsterVisible = await page.evaluate(() => {
    const m = document.querySelector(".monster");
    return !!m && getComputedStyle(m).display !== "none";
  });
  console.log("monster visible to hunters after the pass (should be false):", monsterVisible);
  await page.screenshot({ path: OUT + "/lev-10-local-hunters.png" });
  console.log("errors:", errors.length ? errors : "none");
  await browser.close();
})();
