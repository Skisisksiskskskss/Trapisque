// Headless bot-vs-bot runs for Leviathan Hunt: rule invariants + balance numbers.
// Usage: node demos/src/test/leviathan.sim.js [games] [hunterLevel] [monsterLevel]
const L = require("../leviathan/logic.js");

function play(seed, hl, ml, check) {
  const s = L.newGame(seed);
  const rand = L.rng(seed * 7 + 3);
  L.setMonsterStart(s, L.bots.monsterStart(s, ml, rand));
  let guard = 0, harpoonHits = 0, shots = 0, reveals = 0;
  while (!s.winner && guard++ < 500) {
    if (s.phase === "monster") {
      const opts = L.monsterOptions(s);
      if (!opts.length) throw new Error("monster has no options");
      const act = L.bots.monsterMove(s, ml, rand);
      const ev = L.applyMonster(s, act);
      reveals += ev.filter((e) => e.t === "reveal").length;
      if (check && !s.P.includes(s.monster.pos)) throw new Error("P lost the monster after monster move " + JSON.stringify(act));
    } else if (s.phase === "hunters") {
      let n = 0;
      while (!s.winner && s.orders > 0 && n++ < 10) {
        const o = L.bots.hunterOrder(s, hl, rand);
        if (o.type === "end") break;
        const ev = L.applyHunter(s, o);
        ev.forEach((e) => { if (e.t === "harpoon") { shots++; if (e.hit) harpoonHits++; } });
        if (check && !s.winner && !s.P.includes(s.monster.pos)) throw new Error("P lost the monster after " + JSON.stringify(o));
      }
      if (!s.winner) L.endHunterTurn(s);
    }
  }
  return { winner: s.winner, reason: s.reason, rounds: s.round, kills: s.monster.kills, wounds: s.monster.wounds, shots, harpoonHits, reveals };
}

const games = +(process.argv[2] || 300);
const levels = process.argv[3] ? [[process.argv[3], process.argv[4] || process.argv[3]]] :
  [["easy", "easy"], ["normal", "normal"], ["hard", "hard"], ["hard", "normal"], ["normal", "hard"], ["easy", "normal"], ["normal", "easy"]];
for (const [hl, ml] of levels) {
  let hw = 0, rounds = 0, shots = 0, hits = 0, kills = 0, wounds = 0, reveals = 0;
  const reasons = {};
  const t0 = Date.now();
  for (let g = 1; g <= games; g++) {
    const r = play(g * 101 + 17, hl, ml, true);
    if (r.winner === "hunters") hw++;
    rounds += r.rounds; shots += r.shots; hits += r.harpoonHits; kills += r.kills; wounds += r.wounds; reveals += r.reveals;
    reasons[r.reason] = (reasons[r.reason] || 0) + 1;
  }
  console.log(`hunters=${hl.padEnd(6)} monster=${ml.padEnd(6)} hunterWin=${(100 * hw / games).toFixed(1)}%  rounds=${(rounds / games).toFixed(1)}  shots=${(shots / games).toFixed(1)} hits=${(hits / games).toFixed(2)} kills=${(kills / games).toFixed(2)} reveals=${(reveals / games).toFixed(1)}  ${((Date.now() - t0) / games).toFixed(0)}ms/game`);
  Object.entries(reasons).sort((a, b) => b[1] - a[1]).forEach(([k, v]) => console.log(`    ${v}  ${k}`));
}
