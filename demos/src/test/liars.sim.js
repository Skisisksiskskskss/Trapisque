// Headless bot-vs-bot games for Liar's Gambit: rule invariants and level strength.
// Usage: node demos/src/test/liars.sim.js [games] [levelA] [levelB]
const G = require("../liars/logic.js");

function play(seed, la, lb) {
  const s = G.newGame(seed);
  const rand = G.rng(seed * 13 + 5);
  G.placeSide(s, 0, G.bots.setup(rand, 0, la));
  G.placeSide(s, 1, G.bots.setup(rand, 1, lb));
  G.startPlay(s);
  const lv = [la, lb];
  const st = { bluffs: 0, moves: 0, challenges: 0, caught: 0, plies: 0 };
  let guard = 0;
  while (s.winner == null && guard++ < 400) {
    const me = s.turn;
    if (G.mustResolve(s)) {
      if (G.bots.challenge(s, me, lv[me], rand)) {
        st.challenges++;
        const r = G.challenge(s);
        if (!r.honest) st.caught++;
        if (s.winner != null) break;
        if (s.needSacrifice >= 0) {
          const pid = G.bots.sacrifice(s, s.needSacrifice, lv[s.needSacrifice]);
          if (!G.sacrifice(s, pid)) throw new Error("bad sacrifice");
        }
      } else G.accept(s);
      if (s.winner != null) break;
    }
    const mv = G.bots.move(s, me, lv[me], rand);
    if (!mv) { G.checkStuck(s); break; }
    if (!G.legalMoves(s, me).some((m) => m.pid === mv.pid && m.to === mv.to)) throw new Error("illegal move");
    st.moves++;
    if (!G.isHonest(s, mv)) st.bluffs++;
    G.applyMove(s, mv);
    // invariants
    const onBoard = s.board.filter((x) => x >= 0).length;
    const alive = s.pieces.filter((p) => p.alive).length;
    if (onBoard !== alive) throw new Error("board/alive mismatch");
    if (s.ply >= G.PLY_LIMIT) { G.accept(s); G.checkStuck(s); }
  }
  st.plies = s.ply;
  return { winner: s.winner, reason: s.reason, st };
}

const games = +(process.argv[2] || 40);
const pairs = process.argv[3] ? [[process.argv[3], process.argv[4] || process.argv[3]]] :
  [["easy", "easy"], ["normal", "normal"], ["normal", "easy"], ["easy", "normal"], ["hard", "normal"], ["normal", "hard"], ["hard", "hard"]];
for (const [a, b] of pairs) {
  let w0 = 0, w1 = 0, d = 0;
  const tot = { bluffs: 0, moves: 0, challenges: 0, caught: 0, plies: 0 };
  const reasons = {};
  const t0 = Date.now();
  for (let g = 1; g <= games; g++) {
    // alternate who sits on which side so first-move advantage cancels out
    const flip = g % 2 === 0;
    const r = play(g * 977 + 3, flip ? b : a, flip ? a : b);
    const aWon = flip ? r.winner === 1 : r.winner === 0;
    const bWon = flip ? r.winner === 0 : r.winner === 1;
    if (r.winner === "draw") d++; else if (aWon) w0++; else if (bWon) w1++;
    for (const k in tot) tot[k] += r.st[k];
    const key = r.reason.replace(/Gold|Ruby/g, "X");
    reasons[key] = (reasons[key] || 0) + 1;
  }
  console.log(`${a.padEnd(6)} vs ${b.padEnd(6)}: A wins ${(100 * w0 / games).toFixed(0)}%  B wins ${(100 * w1 / games).toFixed(0)}%  draws ${d}  ` +
    `plies=${(tot.plies / games).toFixed(0)} bluff%=${(100 * tot.bluffs / tot.moves).toFixed(0)} challenges=${(tot.challenges / games).toFixed(1)} caught=${(tot.caught / games).toFixed(1)}  ${((Date.now() - t0) / games).toFixed(0)}ms/game`);
  Object.entries(reasons).sort((x, y) => y[1] - x[1]).slice(0, 4).forEach(([k, v]) => console.log(`     ${v}  ${k}`));
}
