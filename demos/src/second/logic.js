/* Second Guess: rules engine and bot. No DOM, so it runs in Node for tests.
   Side 0 (Blue) starts at the bottom, side 1 (Red) at the top. Everyone plans in
   secret, then every order resolves at the same time. */
(function (root) {
  "use strict";

  var COLS = 7, ROWS = 7, N = COLS * ROWS;
  var MAP = [
    ".......",
    ".#...#.",
    "...#...",
    ".P.P.P.",
    "...#...",
    ".#...#.",
    "......."
  ];
  var WIN_POINTS = 10, TURN_LIMIT = 20;
  var KINDS = {
    brute: { name: "Brute", hp: 4, move: 1, min: 1, max: 1, dmg: 2, blast: false },
    archer: { name: "Archer", hp: 2, move: 1, min: 2, max: 3, dmg: 1, blast: false },
    scout: { name: "Scout", hp: 2, move: 2, min: 1, max: 1, dmg: 1, blast: false },
    mage: { name: "Mage", hp: 2, move: 1, min: 1, max: 2, dmg: 1, blast: true }
  };
  var ORDER = ["brute", "archer", "scout", "mage"];
  var START = [
    { brute: [3, 5], archer: [2, 6], mage: [4, 6], scout: [6, 5] },
    { brute: [3, 1], archer: [4, 0], mage: [2, 0], scout: [0, 1] }
  ];

  function idx(c, r) { return r * COLS + c; }
  function cOf(i) { return i % COLS; }
  function rOf(i) { return (i / COLS) | 0; }
  function cheb(a, b) { return Math.max(Math.abs(cOf(a) - cOf(b)), Math.abs(rOf(a) - rOf(b))); }
  var WALL = new Uint8Array(N), POINTS = [];
  for (var r0 = 0; r0 < ROWS; r0++) for (var c0 = 0; c0 < COLS; c0++) {
    var ch = MAP[r0][c0];
    if (ch === "#") WALL[idx(c0, r0)] = 1;
    if (ch === "P") POINTS.push(idx(c0, r0));
  }
  var IS_POINT = new Uint8Array(N);
  POINTS.forEach(function (p) { IS_POINT[p] = 1; });
  var NB8 = [];
  for (var i0 = 0; i0 < N; i0++) {
    var list = [];
    for (var dr = -1; dr <= 1; dr++) for (var dc = -1; dc <= 1; dc++) {
      if (!dr && !dc) continue;
      var c = cOf(i0) + dc, r = rOf(i0) + dr;
      if (c < 0 || c >= COLS || r < 0 || r >= ROWS) continue;
      list.push(idx(c, r));
    }
    NB8.push(list);
  }

  function rng(seed) {
    var a = (seed >>> 0) || 0x9e3779b9;
    return function () {
      a |= 0; a = (a + 0x6D2B79F5) | 0;
      var t = Math.imul(a ^ (a >>> 15), 1 | a);
      t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
      return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
    };
  }
  function sideName(side) { return side === 0 ? "Blue" : "Red"; }

  /* ---------- State ---------- */
  function newGame() {
    var s = { turn: 1, units: [], scores: [0, 0], winner: null, reason: "", phase: "plan", history: [] };
    [0, 1].forEach(function (side) {
      ORDER.forEach(function (kind) {
        var at = START[side][kind];
        s.units.push({ id: s.units.length, side: side, kind: kind, pos: idx(at[0], at[1]), hp: KINDS[kind].hp, alive: true });
      });
    });
    return s;
  }
  function cloneState(s) {
    return { turn: s.turn, units: s.units.map(function (u) { return { id: u.id, side: u.side, kind: u.kind, pos: u.pos, hp: u.hp, alive: u.alive }; }),
      scores: s.scores.slice(), winner: s.winner, reason: s.reason, phase: s.phase, history: [] };
  }
  function unitAt(s, t) {
    for (var k = 0; k < s.units.length; k++) if (s.units[k].alive && s.units[k].pos === t) return s.units[k];
    return null;
  }

  /* Tiles a unit could plan to move to (walls block; units may be gone by then, so they don't). */
  function moveTargets(s, u) {
    var steps = KINDS[u.kind].move;
    var seen = {}; seen[u.pos] = 0;
    var frontier = [u.pos], out = [];
    for (var k = 0; k < steps; k++) {
      var nx = [];
      frontier.forEach(function (x) {
        NB8[x].forEach(function (y) {
          if (seen[y] != null || WALL[y]) return;
          var occ = unitAt(s, y);
          if (occ && occ.side === u.side && k < steps - 1) { seen[y] = k + 1; nx.push(y); return; }
          seen[y] = k + 1;
          nx.push(y);
          out.push(y);
        });
      });
      frontier = nx;
    }
    return out.filter(function (t) { var occ = unitAt(s, t); return !(occ && occ.side === u.side); });
  }

  function attackTargets(s, u) {
    var K = KINDS[u.kind], out = [];
    for (var t = 0; t < N; t++) {
      if (WALL[t]) continue;
      var d = cheb(u.pos, t);
      if (d >= K.min && d <= K.max) out.push(t);
    }
    return out;
  }
  function blastTiles(t) {
    var out = [t], c = cOf(t), r = rOf(t);
    [[1, 0], [-1, 0], [0, 1], [0, -1]].forEach(function (o) {
      var cc = c + o[0], rr = r + o[1];
      if (cc >= 0 && cc < COLS && rr >= 0 && rr < ROWS && !WALL[idx(cc, rr)]) out.push(idx(cc, rr));
    });
    return out;
  }
  function hitTiles(kind, target) { return KINDS[kind].blast ? blastTiles(target) : [target]; }

  /* orders: { [unitId]: {k:"hold"} | {k:"brace"} | {k:"move", to} | {k:"attack", to} } */
  function resolve(s, orders) {
    var ev = { moves: [], bumps: [], attacks: [], damage: {}, deaths: [], points: [0, 0], held: [] };
    var alive = s.units.filter(function (u) { return u.alive; });
    var dest = {};
    alive.forEach(function (u) {
      var o = orders[u.id];
      dest[u.id] = (o && o.k === "move") ? o.to : u.pos;
    });
    var fail = {};
    var changed = true, guard = 0;
    while (changed && guard++ < 30) {
      changed = false;
      var count = {};
      alive.forEach(function (u) { var d = fail[u.id] ? u.pos : dest[u.id]; count[d] = (count[d] || 0) + 1; });
      alive.forEach(function (u) {
        if (fail[u.id] || dest[u.id] === u.pos) return;
        var d = dest[u.id];
        if (count[d] > 1) { fail[u.id] = true; changed = true; return; }
        var swap = alive.some(function (v) { return v !== u && !fail[v.id] && v.pos === d && dest[v.id] === u.pos; });
        if (swap) { fail[u.id] = true; changed = true; }
      });
    }
    alive.forEach(function (u) {
      var o = orders[u.id];
      if (!o || o.k !== "move") return;
      if (fail[u.id]) ev.bumps.push({ id: u.id, from: u.pos, to: o.to });
      else { ev.moves.push({ id: u.id, from: u.pos, to: o.to }); }
    });
    alive.forEach(function (u) { if (!fail[u.id]) u.pos = dest[u.id]; });
    var dmg = {};
    alive.forEach(function (u) {
      var o = orders[u.id];
      if (!o || o.k !== "attack") return;
      var K = KINDS[u.kind];
      var tiles = hitTiles(u.kind, o.to);
      var hits = [];
      tiles.forEach(function (t) {
        var v = unitAt(s, t);
        if (!v) return;
        var braced = orders[v.id] && orders[v.id].k === "brace";
        var amount = Math.max(0, K.dmg - (braced ? 1 : 0));
        dmg[v.id] = (dmg[v.id] || 0) + amount;
        hits.push({ id: v.id, amount: amount, friendly: v.side === u.side });
      });
      ev.attacks.push({ id: u.id, from: u.pos, to: o.to, tiles: tiles, hits: hits });
    });
    Object.keys(dmg).forEach(function (id) {
      var v = s.units[+id];
      v.hp -= dmg[id];
      ev.damage[id] = dmg[id];
      if (v.hp <= 0) { v.alive = false; v.hp = 0; ev.deaths.push(v.id); }
    });
    POINTS.forEach(function (p) {
      var v = unitAt(s, p);
      if (v) { ev.points[v.side] += 1; ev.held.push({ pt: p, side: v.side }); }
    });
    s.scores[0] += ev.points[0];
    s.scores[1] += ev.points[1];
    s.history.push({ turn: s.turn, orders: orders, ev: ev });
    checkEnd(s);
    if (s.winner == null) s.turn += 1;
    return ev;
  }

  function checkEnd(s) {
    if (s.winner != null) return;
    var alive = [0, 1].map(function (side) { return s.units.filter(function (u) { return u.alive && u.side === side; }).length; });
    var hp = [0, 1].map(function (side) { return s.units.reduce(function (a, u) { return a + (u.alive && u.side === side ? u.hp : 0); }, 0); });
    if (!alive[0] && !alive[1]) { finish(s, "draw", "Both armies fell in the same moment."); return; }
    if (!alive[0]) { finish(s, 1, "Red wiped out the Blue army."); return; }
    if (!alive[1]) { finish(s, 0, "Blue wiped out the Red army."); return; }
    var a = s.scores[0] >= WIN_POINTS, b = s.scores[1] >= WIN_POINTS;
    if (a || b) {
      if (s.scores[0] !== s.scores[1]) { var w = s.scores[0] > s.scores[1] ? 0 : 1; finish(s, w, sideName(w) + " reached " + WIN_POINTS + " points first."); return; }
    }
    if (s.turn >= TURN_LIMIT) {
      if (s.scores[0] !== s.scores[1]) { var w2 = s.scores[0] > s.scores[1] ? 0 : 1; finish(s, w2, "Time ran out with " + sideName(w2) + " ahead on points."); return; }
      if (hp[0] !== hp[1]) { var w3 = hp[0] > hp[1] ? 0 : 1; finish(s, w3, "Tied on points. " + sideName(w3) + " had more health left."); return; }
      finish(s, "draw", "Dead even when time ran out.");
    }
  }
  function finish(s, w, reason) { s.winner = w; s.reason = reason; s.phase = "over"; }

  /* ---------- Bot ---------- */
  var LEVELS = {
    easy: { plans: 8, replies: 6, temp: 2.2, iterate: 0, mix: 1.0, smart: false },
    normal: { plans: 60, replies: 24, temp: 0.9, iterate: 0, mix: 0.25, smart: true },
    hard: { plans: 140, replies: 40, temp: 0.6, iterate: 1, mix: 0.12, smart: true }
  };

  function pointNeed(s, side) {
    var lead = s.scores[side] - s.scores[1 - side];
    return 1 + Math.max(0, -lead) * 0.08 + (s.scores[1 - side] >= WIN_POINTS - 3 ? 0.6 : 0);
  }

  /* A cheap guess at how valuable a tile is for a unit to stand on. */
  function tileValue(s, u, t, threat) {
    var v = 0;
    if (IS_POINT[t]) v += 1.6 * pointNeed(s, u.side);
    var dp = 9;
    POINTS.forEach(function (p) { dp = Math.min(dp, cheb(p, t)); });
    v -= 0.25 * dp;
    if (u.kind === "archer") {
      var good = 0;
      s.units.forEach(function (e) { if (e.alive && e.side !== u.side) { var d = cheb(e.pos, t); if (d >= 2 && d <= 3) good++; } });
      v += 0.25 * good;
      if (IS_POINT[t]) v -= 0.9;
    }
    if (u.kind === "mage" && IS_POINT[t]) v -= 0.5;
    v -= (threat ? threat[t] : 0) * (u.kind === "brute" ? 0.35 : 0.8);
    return v;
  }

  /* How many enemy attacks could land on each tile next resolution (rough). */
  function threatMap(s, side) {
    var m = new Float64Array(N);
    s.units.forEach(function (e) {
      if (!e.alive || e.side === side) return;
      var K = KINDS[e.kind];
      var reach = [e.pos].concat(e.kind === "scout" ? [] : []);
      for (var t = 0; t < N; t++) {
        var d = cheb(e.pos, t);
        if (d >= K.min && d <= K.max + (K.blast ? 1 : 0)) m[t] += K.dmg * (K.blast ? 0.5 : 0.6);
      }
    });
    return m;
  }

  /* Rough chance an enemy unit ends this turn on each tile. */
  function positionGuess(s, e, smart) {
    var probs = {};
    var opts = [e.pos].concat(moveTargets(s, e));
    var w = opts.map(function (t) {
      var v = 0;
      if (t === e.pos) v += 0.6;
      if (smart) {
        if (IS_POINT[t]) v += 1.2;
        var dp = 9;
        POINTS.forEach(function (p) { dp = Math.min(dp, cheb(p, t)); });
        v -= 0.2 * dp;
      }
      return Math.exp(v);
    });
    var tot = w.reduce(function (a, b) { return a + b; }, 0);
    opts.forEach(function (t, k) { probs[t] = (probs[t] || 0) + w[k] / tot; });
    return probs;
  }

  function candidateOrders(s, u, guesses, threat, smart) {
    var out = [];
    var hold = tileValue(s, u, u.pos, threat);
    out.push({ o: { k: "hold" }, v: hold });
    out.push({ o: { k: "brace" }, v: hold + (threat[u.pos] > 0.5 ? 0.45 * Math.min(2, threat[u.pos]) : -0.3) });
    moveTargets(s, u).forEach(function (t) { out.push({ o: { k: "move", to: t }, v: tileValue(s, u, t, threat) + 0.05 }); });
    attackTargets(s, u).forEach(function (t) {
      var K = KINDS[u.kind], exp = 0, ff = 0;
      hitTiles(u.kind, t).forEach(function (x) {
        s.units.forEach(function (e) {
          if (!e.alive) return;
          if (e.side !== u.side) {
            var p = guesses[e.id] ? (guesses[e.id][x] || 0) : (e.pos === x ? 1 : 0);
            exp += p * K.dmg * (e.hp <= K.dmg ? 1.7 : 1);
          } else if (e.pos === x && e.id !== u.id) ff += 0.6;
        });
      });
      var v = hold + (smart ? 1.6 : 1.0) * exp - ff * K.dmg;
      if (exp > 0.02) out.push({ o: { k: "attack", to: t }, v: v });
    });
    return out;
  }

  function softPick(cands, temp, rand) {
    var mx = -Infinity;
    cands.forEach(function (c) { if (c.v > mx) mx = c.v; });
    var w = cands.map(function (c) { return Math.exp((c.v - mx) / temp); });
    var tot = w.reduce(function (a, b) { return a + b; }, 0);
    var r = rand() * tot;
    for (var k = 0; k < cands.length; k++) { r -= w[k]; if (r <= 0) return cands[k].o; }
    return cands[cands.length - 1].o;
  }

  function samplePlan(s, side, temp, rand, smart, guesses) {
    var threat = threatMap(s, side);
    var g = guesses || {};
    if (!guesses) s.units.forEach(function (e) { if (e.alive && e.side !== side) g[e.id] = positionGuess(s, e, smart); });
    var plan = {}, claimed = {};
    s.units.forEach(function (u) {
      if (!u.alive || u.side !== side) return;
      var cands = candidateOrders(s, u, g, threat, smart).filter(function (c) { return !(c.o.k === "move" && claimed[c.o.to]); });
      var o = softPick(cands, temp, rand);
      if (o.k === "move") claimed[o.to] = true;
      plan[u.id] = o;
    });
    return plan;
  }

  function evaluateOutcome(before, after, ev, side) {
    if (after.winner != null) return after.winner === side ? 100 : after.winner === "draw" ? 0 : -100;
    var v = 2.2 * (ev.points[side] - ev.points[1 - side]);
    var hpBefore = [0, 0], hpAfter = [0, 0];
    before.units.forEach(function (u) { if (u.alive) hpBefore[u.side] += u.hp; });
    after.units.forEach(function (u) { if (u.alive) hpAfter[u.side] += u.hp; });
    v += 1.0 * ((hpBefore[1 - side] - hpAfter[1 - side]) - (hpBefore[side] - hpAfter[side]));
    ev.deaths.forEach(function (id) { v += (after.units[id].side === side ? -2.5 : 2.5); });
    var pos = 0;
    after.units.forEach(function (u) {
      if (!u.alive) return;
      var dp = 9;
      POINTS.forEach(function (p) { dp = Math.min(dp, cheb(p, u.pos)); });
      pos += (u.side === side ? 1 : -1) * (IS_POINT[u.pos] ? 0.7 : 0.25 - 0.1 * dp);
    });
    return v + pos;
  }

  function merge(a, b) { var m = {}; for (var k in a) m[k] = a[k]; for (var j in b) m[j] = b[j]; return m; }

  function botPlan(s, side, level, rand) {
    var L = LEVELS[level] || LEVELS.normal;
    var opp = 1 - side;
    var myPlans = [];
    for (var k = 0; k < L.plans; k++) myPlans.push(samplePlan(s, side, L.temp, rand, L.smart));
    var oppPlans = [];
    for (var j = 0; j < L.replies; j++) oppPlans.push(samplePlan(s, opp, 0.9, rand, true));
    function score(plan, replies) {
      var tot = 0;
      replies.forEach(function (rp) {
        var c = cloneState(s);
        var ev = resolve(c, merge(plan, rp));
        tot += evaluateOutcome(s, c, ev, side);
      });
      return tot / replies.length;
    }
    var scored = myPlans.map(function (p) { return { p: p, v: score(p, oppPlans) }; });
    scored.sort(function (a, b) { return b.v - a.v; });
    if (L.iterate) {
      /* Let the opponent answer our favourite plans, then re-score against that mix. */
      var tops = scored.slice(0, 6).map(function (x) { return x.p; });
      var counters = [];
      for (var q = 0; q < 16; q++) {
        var cand = samplePlan(s, opp, 0.7, rand, true);
        var v = 0;
        tops.forEach(function (tp) {
          var c2 = cloneState(s);
          var ev2 = resolve(c2, merge(tp, cand));
          v += evaluateOutcome(s, c2, ev2, opp);
        });
        counters.push({ p: cand, v: v });
      }
      counters.sort(function (a, b) { return b.v - a.v; });
      var mixReplies = oppPlans.concat(counters.slice(0, 8).map(function (x) { return x.p; }));
      scored = scored.slice(0, 25).map(function (x) { return { p: x.p, v: score(x.p, mixReplies) }; });
      scored.sort(function (a, b) { return b.v - a.v; });
    }
    /* Don't be perfectly predictable: sometimes take a close second. */
    if (scored.length > 1 && rand() < L.mix && scored[1].v > scored[0].v - 0.8) return scored[1].p;
    return scored[0].p;
  }

  var API = {
    COLS: COLS, ROWS: ROWS, N: N, MAP: MAP, WALL: WALL, POINTS: POINTS, IS_POINT: IS_POINT, KINDS: KINDS, ORDER: ORDER, WIN_POINTS: WIN_POINTS, TURN_LIMIT: TURN_LIMIT,
    idx: idx, cOf: cOf, rOf: rOf, cheb: cheb, rng: rng, sideName: sideName,
    newGame: newGame, cloneState: cloneState, unitAt: unitAt, moveTargets: moveTargets, attackTargets: attackTargets, hitTiles: hitTiles, resolve: resolve,
    bots: { plan: botPlan }, LEVELS: LEVELS
  };
  root.SecondGuess = API;
  if (typeof module !== "undefined" && module.exports) module.exports = API;
})(typeof window !== "undefined" ? window : globalThis);
