// Headless bot-vs-bot games for Echoes: rule invariants, timing and level strength.
// Usage: node demos/src/test/echoes.sim.js [games] [levelA] [levelB]
const E = require("../echoes/logic.js");

function play(seed, la, lb) {
  const s = E.newGame();
  const rand = E.rng(seed);
  const lv = [la, lb];
  let guard = 0, maxMs = 0, events = { paradox: 0, struck: 0, crushed: 0 };
  const sink = (x) => { if (x.type === "echoes") x.ev.forEach((e) => { if (e.t === "ko") events[e.why === "fades" ? "struck" : e.why] = (events[e.why] || 0) + 1; }); };
  while (guard++ < 400) {
    const who = E.advance(s, sink);
    if (who === null) break;
    const t0 = Date.now();
    const a = E.bots.action(s, who, lv[who], rand);
    maxMs = Math.max(maxMs, Date.now() - t0);
    const ev = E.applyLive(s, who, a);
    ev.forEach((e) => { if (e.t === "ko") events[e.why] = (events[e.why] || 0) + 1; });
    // invariants: no two alive units share a non-spawn tile
    const seen = {};
    s.units.forEach((u) => {
      if (!u.alive) return;
      if (u.pos === E.SPAWN[u.side]) return;
      if (seen[u.pos] != null) if (s.units[seen[u.pos]].side !== u.side) throw new Error("enemies share tile " + u.pos);
      seen[u.pos] = u.id;
    });
  }
  return { winner: s.winner, scores: s.scores, maxMs, events };
}

const games = +(process.argv[2] || 10);
const pairs = process.argv[3] ? [[process.argv[3], process.argv[4] || process.argv[3]]] :
  [["normal", "easy"], ["hard", "normal"], ["normal", "normal"]];
for (const [a, b] of pairs) {
  let wa = 0, wb = 0, d = 0, maxMs = 0, pts = [0, 0];
  const ev = {};
  const t0 = Date.now();
  for (let g = 1; g <= games; g++) {
    const flip = g % 2 === 0;
    const r = play(g * 31 + 7, flip ? b : a, flip ? a : b);
    const aSide = flip ? 1 : 0;
    if (r.winner === "draw") d++; else if (r.winner === aSide) wa++; else wb++;
    pts[0] += r.scores[aSide]; pts[1] += r.scores[1 - aSide];
    maxMs = Math.max(maxMs, r.maxMs);
    for (const k in r.events) ev[k] = (ev[k] || 0) + r.events[k];
  }
  console.log(`${a.padEnd(6)} vs ${b.padEnd(6)}: A ${wa}  B ${wb}  draws ${d}  avg pts ${(pts[0] / games).toFixed(1)}-${(pts[1] / games).toFixed(1)}  slowest move ${maxMs}ms  ${((Date.now() - t0) / games / 1000).toFixed(1)}s/game  events ${JSON.stringify(ev)}`);
}
