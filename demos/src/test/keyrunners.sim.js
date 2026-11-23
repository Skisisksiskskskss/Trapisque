// Headless bot-vs-bot games for Keyrunners: rule invariants, game length, win types and level strength.
// Usage: node demos/src/test/keyrunners.sim.js [games] [levelA] [levelB] [deckA] [deckB]
// Decks are preset ids (runners, fortress, tricksters, allround) or "random".
const KR = require("../keyrunners/logic.js");
// Optional rule overrides for experiments, e.g. CFG='{"firstIncome":5}'
if (process.env.CFG) Object.assign(KR.CFG, JSON.parse(process.env.CFG));

function check(st) {
  const seen = {};
  st.units.forEach((u) => {
    if (st.board[u.pos] !== u.id) throw new Error("board out of sync for unit " + u.id);
    if (seen[u.pos]) throw new Error("two units on tile " + u.pos);
    seen[u.pos] = 1;
  });
  let n = 0;
  for (let t = 0; t < KR.N; t++) if (st.board[t] >= 0) { n++; if (!KR.unit(st, st.board[t])) throw new Error("ghost id on board"); }
  if (n !== st.units.length) throw new Error("board count mismatch");
  st.keys.forEach((K, k) => {
    if (K.h >= 0) { if (!KR.unit(st, K.h)) throw new Error("key " + k + " held by a missing unit"); }
    else if (K.at < 0 || st.board[K.at] >= 0) throw new Error("key " + k + " on the ground in a bad place " + K.at);
  });
  [0, 1].forEach((s) => {
    if (st.mana[s] < -KR.CFG.debt) throw new Error("mana below the debt limit");
    if (st.mana[s] > KR.CFG.cap) throw new Error("mana above cap");
    if (KR.crewCount(st, s) > KR.CFG.maxCrew) throw new Error("too many crew");
    if (st.hands[s].length > 4) throw new Error("hand too big");
  });
}

function deckFor(id, rand) {
  if (id === "random") return KR.randomDeck(rand);
  const p = KR.PRESETS.find((x) => x.id === id) || KR.PRESETS[Math.floor(rand() * KR.PRESETS.length)];
  return { leader: p.leader, crew: p.crew.slice(), gadgets: p.gadgets.slice() };
}

function play(seed, la, lb, da, db, usage) {
  const rand = KR.rng(seed);
  const st = KR.newGame({ decks: [deckFor(da, rand), deckFor(db, rand)], seed: seed * 7 + 3 });
  const lv = [la, lb];
  let maxMs = 0, totalMs = 0, plans = 0, illegal = 0, firstSteal = 0;
  const keyRows = [[], []];
  while (st.winner == null) {
    let guard = 0;
    for (let pass = 0; pass < 3 && st.winner == null; pass++) {
      const t0 = Date.now();
      const plan = KR.bots.plan(st, lv[st.side], rand);
      const ms = Date.now() - t0;
      maxMs = Math.max(maxMs, ms); totalMs += ms; plans++;
      let replan = false;
      for (const a of plan) {
        if (st.winner != null) break;
        if (!KR.isLegal(st, a)) { illegal++; replan = true; break; }
        const ev = KR.apply(st, a, []);
        if (usage) {
          if (a.t === "deploy") usage["deploy " + ev[0].type] = (usage["deploy " + ev[0].type] || 0) + 1;
          if (a.t === "gadget") usage["gadget " + ev[0].g] = (usage["gadget " + ev[0].g] || 0) + 1;
          if (a.t === "ab") usage["ability " + ev[0].ab] = (usage["ability " + ev[0].ab] || 0) + 1;
          usage["act " + a.t] = (usage["act " + a.t] || 0) + 1;
          ev.forEach((e) => { if (e.e === "trap" || e.e === "bounce" || e.e === "slam" || e.e === "bribe") usage["event " + e.e] = (usage["event " + e.e] || 0) + 1; });
        }
        if (!firstSteal && ev.some((e) => (e.e === "capture" && e.keys.length) || (e.e === "pass" && e.how === "swipe") || (e.e === "throw" && e.by >= 0 && KR.unit(st, e.by) && KR.unit(st, e.by).side !== st.side))) firstSteal = st.ply;
        check(st);
        if (st.revealed || st.drew) { st.revealed = false; st.drew = false; replan = true; break; }
      }
      if (!replan) break;
      if (++guard > 3) break;
    }
    if (st.winner != null) break;
    KR.endTurn(st, []);
    check(st);
    for (let k = 0; k < 2; k++) { const K = st.keys[k]; const u = K.h >= 0 ? KR.unit(st, K.h) : null; keyRows[k].push(u ? KR.rOf(u.pos) : KR.rOf(K.at)); }
  }
  return { winner: st.winner, how: st.how, plies: st.ply, maxMs, avgMs: totalMs / Math.max(1, plans), illegal, stats: st.stats, firstSteal };
}

const games = +(process.argv[2] || 10);
const pairs = process.argv[3] ? [[process.argv[3], process.argv[4] || process.argv[3]]] : [["normal", "easy"], ["hard", "normal"], ["normal", "normal"]];
const da = process.argv[5] || "random", db = process.argv[6] || da;
for (const [a, b] of pairs) {
  let wa = 0, wb = 0, d = 0, plies = 0, maxMs = 0, avgMs = 0, illegal = 0, blueWins = 0, steals = 0, caps = 0;
  const how = {}, usage = {};
  for (let g = 1; g <= games; g++) {
    const flip = g % 2 === 0;
    const r = play(g * 131 + 17 + (+process.env.SEED_OFFSET || 0), flip ? b : a, flip ? a : b, flip ? db : da, flip ? da : db, usage);
    const aSide = flip ? 1 : 0;
    if (r.winner === "draw") d++; else if (r.winner === aSide) wa++; else wb++;
    if (r.winner === 0) blueWins++;
    how[r.how] = (how[r.how] || 0) + 1;
    plies += r.plies; maxMs = Math.max(maxMs, r.maxMs); avgMs += r.avgMs; illegal += r.illegal;
    steals += r.stats[0].steals + r.stats[1].steals; caps += r.stats[0].caps + r.stats[1].caps;
    if (process.env.VERBOSE) console.log(`  game ${g}: winner ${r.winner} by ${r.how} in round ${Math.ceil(r.plies / 2)}  caps ${r.stats[0].caps}/${r.stats[1].caps}  steals ${r.stats[0].steals}/${r.stats[1].steals}  first steal ply ${r.firstSteal}`);
  }
  console.log(`${a.padEnd(6)} vs ${b.padEnd(6)}: A ${wa}  B ${wb}  draws ${d}  | Blue wins ${blueWins}/${games - d} | rounds ${(plies / games / 2).toFixed(1)} | ${JSON.stringify(how)} | caps/game ${(caps / games).toFixed(1)} steals/game ${(steals / games).toFixed(1)} | plan avg ${(avgMs / games).toFixed(0)}ms max ${maxMs}ms | illegal ${illegal}`);
  if (process.env.USAGE) console.log("   ", Object.entries(usage).sort((x, y) => y[1] - x[1]).map(([k, v]) => k + " " + v).join(", "));
}
