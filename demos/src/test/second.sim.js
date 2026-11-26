// Headless bot-vs-bot games for Second Guess: invariants, timing and level strength.
// Usage: node demos/src/test/second.sim.js [games] [levelA] [levelB]
const SG = require("../second/logic.js");

function play(seed, la, lb) {
  const s = SG.newGame();
  const rand = SG.rng(seed);
  const lv = [la, lb];
  let maxMs = 0, bumps = 0, friendly = 0, hits = 0, attacks = 0;
  while (s.winner == null && s.turn <= 40) {
    const t0 = Date.now();
    const p0 = SG.bots.plan(s, 0, lv[0], rand);
    const p1 = SG.bots.plan(s, 1, lv[1], rand);
    maxMs = Math.max(maxMs, Date.now() - t0);
    const ev = SG.resolve(s, Object.assign({}, p0, p1));
    bumps += ev.bumps.length;
    ev.attacks.forEach((a) => { attacks++; a.hits.forEach((h) => { if (h.friendly) friendly++; else hits++; }); });
    const occ = {};
    s.units.forEach((u) => { if (!u.alive) return; if (occ[u.pos]) throw new Error("two units share a tile"); occ[u.pos] = 1; if (SG.WALL[u.pos]) throw new Error("unit in wall"); });
  }
  return { winner: s.winner, reason: s.reason, turns: s.turn, scores: s.scores, maxMs, bumps, friendly, hits, attacks };
}

const games = +(process.argv[2] || 20);
const pairs = process.argv[3] ? [[process.argv[3], process.argv[4] || process.argv[3]]] :
  [["normal", "easy"], ["hard", "normal"], ["normal", "normal"]];
for (const [a, b] of pairs) {
  let wa = 0, wb = 0, d = 0, turns = 0, maxMs = 0, acc = 0, att = 0, ff = 0, bumps = 0;
  const reasons = {};
  for (let g = 1; g <= games; g++) {
    const flip = g % 2 === 0;
    const r = play(g * 97 + 5, flip ? b : a, flip ? a : b);
    const aSide = flip ? 1 : 0;
    if (r.winner === "draw") d++; else if (r.winner === aSide) wa++; else wb++;
    turns += r.turns; maxMs = Math.max(maxMs, r.maxMs); acc += r.hits; att += r.attacks; ff += r.friendly; bumps += r.bumps;
    const key = r.reason.replace(/Blue|Red/g, "X");
    reasons[key] = (reasons[key] || 0) + 1;
  }
  console.log(`${a.padEnd(6)} vs ${b.padEnd(6)}: A ${wa}  B ${wb}  draws ${d}  turns ${(turns / games).toFixed(1)}  hit rate ${(100 * acc / Math.max(1, att)).toFixed(0)}%  friendly hits ${ff}  bumps ${bumps}  slowest plan ${maxMs}ms`);
  Object.entries(reasons).sort((x, y) => y[1] - x[1]).slice(0, 3).forEach(([k, v]) => console.log(`     ${v}  ${k}`));
}
