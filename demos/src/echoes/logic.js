/* Echoes: rules engine and bot. No DOM, so it runs in Node for tests.
   Side 0 (Cyan) spawns at the bottom, side 1 (Magenta) at the top. */
(function (root) {
  "use strict";

  var COLS = 7, ROWS = 7, N = COLS * ROWS;
  var TICKS = 6, ROUNDS = 5;
  /* # wall, . floor, s/S spawns (Magenta/Cyan), P gem (1), X centre gem (2),
     V vault gem (2), D door, O plate */
  var MAP = [
    "#..s...",
    "VD...P.",
    "#......",
    "PO#X#OP",
    "......#",
    ".P...DV",
    "...S..#"
  ];
  var DIRS = [[0, -1], [1, 0], [0, 1], [-1, 0]]; /* N E S W */
  var DIR_NAMES = ["north", "east", "south", "west"];

  function idx(c, r) { return r * COLS + c; }
  function cOf(i) { return i % COLS; }
  function rOf(i) { return (i / COLS) | 0; }
  function step(i, d) {
    var c = cOf(i) + DIRS[d][0], r = rOf(i) + DIRS[d][1];
    if (c < 0 || c >= COLS || r < 0 || r >= ROWS) return -1;
    return idx(c, r);
  }

  var TILE = [], PAD = new Int8Array(N), SPAWN = [-1, -1], PLATE_DOOR = {}, DOOR_PLATE = {};
  (function parse() {
    for (var r = 0; r < ROWS; r++) for (var c = 0; c < COLS; c++) {
      var ch = MAP[r][c], i = idx(c, r);
      TILE[i] = ch;
      if (ch === "P") PAD[i] = 1;
      if (ch === "X") PAD[i] = 2;
      if (ch === "V") PAD[i] = 3;
      if (ch === "S") SPAWN[0] = i;
      if (ch === "s") SPAWN[1] = i;
    }
    PLATE_DOOR[idx(1, 3)] = idx(5, 5); DOOR_PLATE[idx(5, 5)] = idx(1, 3);
    PLATE_DOOR[idx(5, 3)] = idx(1, 1); DOOR_PLATE[idx(1, 1)] = idx(5, 3);
  })();
  var PADS = [], PLATES = [], DOORS = [];
  for (var q0 = 0; q0 < N; q0++) {
    if (PAD[q0]) PADS.push(q0);
    if (TILE[q0] === "O") PLATES.push(q0);
    if (TILE[q0] === "D") DOORS.push(q0);
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

  /* Actions: {k:"move",d}, {k:"wait"}, {k:"strike",d}. Records may end with {k:"ko"}. */
  function act(k, d) { return d == null ? { k: k } : { k: k, d: d }; }

  /* ---------- State ---------- */
  function newGame() {
    var s = { round: 0, tick: 0, units: [], live: [-1, -1], scores: [0, 0], roundScores: [], queue: [], phase: "ready", winner: null, reason: "", log: [], firstOfRound: 0 };
    startRound(s);
    return s;
  }

  function cloneState(s) {
    return {
      round: s.round, tick: s.tick,
      units: s.units.map(function (u) { return { id: u.id, side: u.side, round: u.round, pos: u.pos, alive: u.alive, live: u.live, rec: u.rec.slice(), fate: u.fate }; }),
      live: s.live.slice(), scores: s.scores.slice(), roundScores: s.roundScores.slice(), queue: s.queue.slice(),
      phase: s.phase, winner: s.winner, reason: s.reason, log: [], firstOfRound: s.firstOfRound
    };
  }

  function startRound(s) {
    s.round += 1;
    s.tick = 0;
    s.units.forEach(function (u) { u.pos = SPAWN[u.side]; u.alive = true; u.live = false; u.fate = null; });
    s.live = [0, 1].map(function (side) {
      var u = { id: s.units.length, side: side, round: s.round, pos: SPAWN[side], alive: true, live: true, rec: [], fate: null };
      s.units.push(u);
      return u.id;
    });
    s.firstOfRound = (s.round - 1) % 2;
    s.phase = "tick";
    beginTick(s);
  }

  /* Who acts next inside the current tick: "echoes" first, then each live hero by initiative. */
  function beginTick(s) {
    s.tick += 1;
    var first = (s.firstOfRound + s.tick - 1) % 2;
    s.queue = ["echoes", first, 1 - first];
  }

  function occupant(s, t, exceptId) {
    for (var k = 0; k < s.units.length; k++) {
      var u = s.units[k];
      if (u.alive && u.pos === t && u.id !== exceptId) return u;
    }
    return null;
  }
  function unitsAt(s, t) { return s.units.filter(function (u) { return u.alive && u.pos === t; }); }

  function doorOpen(s, door) {
    var plate = DOOR_PLATE[door];
    return s.units.some(function (u) { return u.alive && u.pos === plate; });
  }

  /* Walls, closed doors, the enemy spawn and enemy units block. Your own units can share a tile. */
  function canEnter(s, u, t) {
    if (t < 0) return false;
    var ch = TILE[t];
    if (ch === "#") return false;
    if (ch === "D" && !doorOpen(s, t)) return false;
    if (t === SPAWN[1 - u.side]) return false;
    for (var k = 0; k < s.units.length; k++) {
      var v = s.units[k];
      if (v.alive && v.pos === t && v.side !== u.side) return false;
    }
    return true;
  }

  /* Strikes only hit the enemy's live hero. Echoes are from the past and can't be hit,
     only blocked. */
  function strikeTargets(s, u, d) {
    var t = step(u.pos, d);
    if (t < 0) return [];
    return unitsAt(s, t).filter(function (v) { return v.side !== u.side && v.live; });
  }

  function knockOut(s, v, why, ev) {
    if (!v.alive) return;
    v.alive = false;
    v.fate = why;
    if (v.live) v.rec.push(act("ko"));
    ev.push({ t: "ko", id: v.id, why: why, at: v.pos });
  }

  /* After anything moves: doors whose plate emptied slam shut and crush whoever stands in them. */
  function settleDoors(s, ev, prevOpen) {
    DOORS.forEach(function (door) {
      var open = doorOpen(s, door);
      if (prevOpen && prevOpen[door] && !open) {
        ev.push({ t: "door", at: door, open: false });
        unitsAt(s, door).forEach(function (v) { knockOut(s, v, "crushed", ev); });
      } else if (prevOpen && !prevOpen[door] && open) {
        ev.push({ t: "door", at: door, open: true });
      }
    });
  }
  function doorSnapshot(s) {
    var m = {};
    DOORS.forEach(function (d) { m[d] = doorOpen(s, d); });
    return m;
  }

  function doAction(s, u, a, ev, isEcho) {
    var before = doorSnapshot(s);
    if (a.k === "move") {
      var t = step(u.pos, a.d);
      if (!canEnter(s, u, t)) {
        if (isEcho) { knockOut(s, u, "paradox", ev); settleDoors(s, ev, before); return false; }
        return false;
      }
      ev.push({ t: "move", id: u.id, from: u.pos, to: t });
      u.pos = t;
    } else if (a.k === "strike") {
      var hits = strikeTargets(s, u, a.d);
      ev.push({ t: "strike", id: u.id, from: u.pos, d: a.d, hits: hits.map(function (v) { return v.id; }) });
      hits.forEach(function (v) { knockOut(s, v, "struck", ev); });
    } else if (a.k === "wait") {
      ev.push({ t: "wait", id: u.id });
    } else if (a.k === "ko") {
      knockOut(s, u, "fades", ev);
    }
    settleDoors(s, ev, before);
    return true;
  }

  function runEchoes(s) {
    var ev = [];
    var echoes = s.units.filter(function (u) { return !u.live; }).sort(function (a, b) { return a.round - b.round || a.side - b.side; });
    echoes.forEach(function (u) {
      if (!u.alive) return;
      var a = u.rec[s.tick - 1];
      if (!a) return;
      doAction(s, u, a, ev, true);
    });
    s.queue.shift();
    return ev;
  }

  function liveOptions(s, side) {
    var u = s.units[s.live[side]];
    var out = [act("wait")];
    if (!u.alive) return out;
    for (var d = 0; d < 4; d++) {
      var t = step(u.pos, d);
      if (canEnter(s, u, t)) out.push(act("move", d));
      if (strikeTargets(s, u, d).length) out.push(act("strike", d));
    }
    return out;
  }

  /* Next decision: "echoes", 0, 1, "score" or null when the game is over. */
  function nextActor(s) {
    if (s.phase === "over") return null;
    if (!s.queue.length) return "score";
    var q = s.queue[0];
    if (q === "echoes") return "echoes";
    var u = s.units[s.live[q]];
    return u.alive ? q : "skip";
  }

  function applyLive(s, side, a) {
    var u = s.units[s.live[side]];
    var ev = [];
    if (u.alive) {
      var ok = doAction(s, u, a, ev, false);
      if (!ok) { a = act("wait"); ev.push({ t: "wait", id: u.id }); }
      if (u.alive) u.rec.push(a);
    }
    s.queue.shift();
    return ev;
  }

  function skipDead(s) {
    var q = s.queue[0];
    var u = s.units[s.live[q]];
    if (u.rec.length < s.tick && u.rec[u.rec.length - 1] && u.rec[u.rec.length - 1].k !== "ko") u.rec.push(act("ko"));
    s.queue.shift();
  }

  function endTick(s) {
    if (s.tick < TICKS) { beginTick(s); return null; }
    var gained = [0, 0], held = [];
    PADS.forEach(function (p) {
      var here = unitsAt(s, p);
      if (!here.length) return;
      var side = here[0].side;
      gained[side] += PAD[p];
      held.push({ pad: p, side: side, id: here[0].id, value: PAD[p] });
    });
    s.scores[0] += gained[0]; s.scores[1] += gained[1];
    s.roundScores.push(gained);
    var res = { gained: gained, held: held, round: s.round };
    if (s.round >= ROUNDS) {
      s.phase = "over";
      if (s.scores[0] !== s.scores[1]) {
        s.winner = s.scores[0] > s.scores[1] ? 0 : 1;
        s.reason = sideName(s.winner) + " held more gems over five rounds.";
      } else if (gained[0] !== gained[1]) {
        s.winner = gained[0] > gained[1] ? 0 : 1;
        s.reason = "Tied on points. " + sideName(s.winner) + " held more in the last round.";
      } else { s.winner = "draw"; s.reason = "Dead even after five rounds."; }
    } else {
      startRound(s);
    }
    return res;
  }

  function sideName(side) { return side === 0 ? "Cyan" : "Magenta"; }

  /* Drive the state forward through automatic steps until a live hero must decide. */
  function advance(s, sink) {
    var guard = 0;
    while (guard++ < 200) {
      var who = nextActor(s);
      if (who === null) return null;
      if (who === "echoes") { var ev = runEchoes(s); if (sink) sink({ type: "echoes", ev: ev }); continue; }
      if (who === "skip") { skipDead(s); continue; }
      if (who === "score") { var res = endTick(s); if (sink && res) sink({ type: "score", res: res }); else if (sink) sink({ type: "tick" }); continue; }
      return who;
    }
    return null;
  }

  /* One automatic step for the interface: echoes acting, a skipped (knocked-out) hero,
     or the end of a tick/round. Returns null when a live hero must decide. */
  function stepAuto(s) {
    var who = nextActor(s);
    if (who === "echoes") return { type: "echoes", ev: runEchoes(s) };
    if (who === "skip") { skipDead(s); return { type: "skip" }; }
    if (who === "score") {
      var tick = s.tick;
      var res = endTick(s);
      return res ? { type: "score", res: res } : { type: "tick", tick: tick };
    }
    return null;
  }

  /* ---------- Bot ---------- */
  var LEVELS = {
    easy: { depth: 2, noise: 3.5, future: 0.4, rollout: "wait" },
    normal: { depth: 5, noise: 0.6, future: 0.75, rollout: "greedy" },
    hard: { depth: 8, noise: 0.05, future: 0.85, rollout: "greedy" }
  };

  /* Shortest walking distance on the open map (doors treated as open). */
  var DIST = (function () {
    var D = [];
    for (var a = 0; a < N; a++) {
      var row = new Int8Array(N).fill(99);
      if (TILE[a] !== "#") {
        row[a] = 0;
        var qq = [a];
        while (qq.length) {
          var x = qq.shift();
          for (var d = 0; d < 4; d++) {
            var y = step(x, d);
            if (y < 0 || TILE[y] === "#" || row[y] !== 99) continue;
            row[y] = row[x] + 1;
            qq.push(y);
          }
        }
      }
      D.push(row);
    }
    return D;
  })();

  function greedyAction(s, side) {
    var u = s.units[s.live[side]];
    if (!u.alive) return act("wait");
    for (var d0 = 0; d0 < 4; d0++) if (strikeTargets(s, u, d0).length) return act("strike", d0);
    if (PAD[u.pos] && !s.units.some(function (v) { return v.alive && v.pos === u.pos && v.id !== u.id && v.side === side; })) return act("wait");
    if (u.pos === OWN_PLATE[side] && s.round <= ROUNDS - 2) return act("wait");
    var left = TICKS - s.tick + 1;
    var best = null, bv = -1e9;
    var targets = PADS.map(function (p) { return { p: p, val: PAD[p] }; });
    var mine = OWN_PLATE[side];
    var plateTaken = s.units.some(function (v) { return v.alive && v.side === side && v.id !== u.id && !v.live && v.rec.length && plateEnd(v) === mine; });
    if (!plateTaken && s.round <= ROUNDS - 2) targets.push({ p: mine, val: 2.6 });
    targets.forEach(function (tg) {
      var p = tg.p;
      var dd = DIST[u.pos][p];
      if (dd > left || dd === 0) return;
      var holder = occupant(s, p, u.id);
      var mineThere = holder && holder.side === side;
      var v = tg.val * 2 - dd * 0.3 - (holder ? (mineThere ? 3 : 1.5) : 0);
      if (v > bv) { bv = v; best = p; }
    });
    if (best == null && u.pos === mine && !plateTaken) return act("wait");
    if (best == null) return act("wait");
    for (var d = 0; d < 4; d++) {
      var t = step(u.pos, d);
      if (t >= 0 && DIST[t][best] < DIST[u.pos][best] && canEnter(s, u, t)) return act("move", d);
    }
    return act("wait");
  }
  function plateEnd(u) {
    var pos = SPAWN[u.side];
    for (var k = 0; k < u.rec.length; k++) { var a = u.rec[k]; if (a.k === "move") { var t = step(pos, a.d); if (t >= 0) pos = t; } }
    return pos;
  }
  function occupantOther(s, u) { return s.units.some(function (v) { return v.alive && v.pos === u.pos && v.id !== u.id; }); }

  /* Points the echoes alone would score in a round if everything replays untouched. */
  function echoOnlyRound(s) {
    var c = cloneState(s);
    c.units.forEach(function (u) { u.pos = SPAWN[u.side]; u.alive = true; u.live = false; u.fate = null; });
    var gained = [0, 0];
    for (var t = 1; t <= TICKS; t++) {
      c.tick = t;
      var echoes = c.units.slice().sort(function (a, b) { return a.round - b.round || a.side - b.side; });
      echoes.forEach(function (u) {
        if (!u.alive) return;
        var a = u.rec[t - 1];
        if (!a) return;
        doAction(c, u, a, [], true);
      });
    }
    PADS.forEach(function (p) { var here = unitsAt(c, p); if (here.length) gained[here[0].side] += PAD[p]; });
    return gained;
  }

  function finishRoundWith(s, policy) {
    var c = cloneState(s);
    var startRound0 = c.round;
    var guard = 0;
    while (c.phase !== "over" && c.round === startRound0 && guard++ < 100) {
      var who = nextActor(c);
      if (who === "echoes") { runEchoes(c); continue; }
      if (who === "skip") { skipDead(c); continue; }
      if (who === "score") {
        if (c.tick < TICKS) { beginTick(c); continue; }
        break;
      }
      var a = policy === "greedy" ? greedyAction(c, who) : act("wait");
      applyLive(c, who, a);
    }
    return c;
  }

  /* Value of a finished round from `me`'s point of view. */
  /* Each side's own plate is the one that opens the door next to its spawn. */
  var OWN_PLATE = [DOOR_PLATE[idx(5, 5)], DOOR_PLATE[idx(1, 1)]];
  var OWN_VAULT = [idx(6, 5), idx(0, 1)];

  function roundValue(c, me, L) {
    var gained = [0, 0];
    PADS.forEach(function (p) { var here = unitsAt(c, p); if (here.length) gained[here[0].side] += PAD[p]; });
    var left = ROUNDS - c.round;
    var v = gained[me] - gained[1 - me];
    if (left > 0) {
      var eo = echoOnlyRound(c);
      v += L.future * left * (eo[me] - eo[1 - me]);
      /* A plate held by an echo is worth something even before anyone uses the vault. */
      [me, 1 - me].forEach(function (side) {
        var plateHeld = c.units.some(function (u) { return u.alive && u.side === side && u.pos === OWN_PLATE[side]; });
        var vaultHeld = c.units.some(function (u) { return u.alive && u.side === side && u.pos === OWN_VAULT[side]; });
        if (plateHeld && !vaultHeld && left >= 2) v += (side === me ? 1 : -1) * L.future * 0.8 * PAD[OWN_VAULT[side]] * (left - 1);
      });
    }
    return v;
  }

  function search(s, me, depth, alpha, beta, L, deadline) {
    var who = advanceQuiet(s);
    var c = s;
    if (who === null || who === "score") {
      return roundValue(c, me, L);
    }
    if (depth <= 0 || Date.now() > deadline) {
      var fin = finishRoundWith(c, L.rollout);
      return roundValue(fin, me, L);
    }
    var opts = orderOptions(c, who, liveOptions(c, who));
    var maximizing = who === me;
    var best = maximizing ? -Infinity : Infinity;
    for (var k = 0; k < opts.length; k++) {
      var nx = cloneState(c);
      applyLive(nx, who, opts[k]);
      var val = search(nx, me, depth - 1, alpha, beta, L, deadline);
      if (maximizing) { if (val > best) best = val; if (best > alpha) alpha = best; }
      else { if (val < best) best = val; if (best < beta) beta = best; }
      if (beta <= alpha) break;
    }
    return best;
  }

  /* Like advance() but never crosses into the next round: stops at "score" on the last tick. */
  function advanceQuiet(s) {
    var guard = 0;
    while (guard++ < 60) {
      var who = nextActor(s);
      if (who === null) return null;
      if (who === "echoes") { runEchoes(s); continue; }
      if (who === "skip") { skipDead(s); continue; }
      if (who === "score") {
        if (s.tick < TICKS) { beginTick(s); continue; }
        return "score";
      }
      return who;
    }
    return null;
  }

  function orderOptions(s, side, opts) {
    var u = s.units[s.live[side]];
    return opts.map(function (a) {
      var pri = 0;
      if (a.k === "strike") pri = 3;
      else if (a.k === "move") {
        var t = step(u.pos, a.d);
        if (PAD[t]) pri = 2;
        else {
          var near = 99;
          PADS.forEach(function (p) { near = Math.min(near, DIST[t][p]); });
          pri = 1 - near * 0.05;
        }
      }
      return { a: a, pri: pri };
    }).sort(function (x, y) { return y.pri - x.pri; }).map(function (x) { return x.a; });
  }

  function botAction(s, side, level, rand) {
    var L = LEVELS[level] || LEVELS.normal;
    var opts = liveOptions(s, side);
    if (opts.length === 1) return opts[0];
    var deadline = Date.now() + (level === "hard" ? 900 : 400);
    var scored = opts.map(function (a) {
      var nx = cloneState(s);
      applyLive(nx, side, a);
      var v = search(nx, side, L.depth - 1, -Infinity, Infinity, L, deadline);
      return { a: a, v: v + (rand() - 0.5) * L.noise };
    });
    scored.sort(function (x, y) { return y.v - x.v; });
    return scored[0].a;
  }

  /* Where each echo will be after every remaining tick this round, if nothing interferes. */
  function echoForecast(s) {
    var out = {};
    s.units.forEach(function (u) {
      if (u.live || !u.alive) return;
      var path = [], pos = u.pos;
      for (var t = s.tick + (s.queue[0] === "echoes" ? 0 : 1); t <= TICKS; t++) {
        var a = u.rec[t - 1];
        if (!a || a.k === "ko") { path.push({ t: t, pos: pos, end: true }); break; }
        if (a.k === "move") { var nt = step(pos, a.d); if (nt >= 0) pos = nt; }
        path.push({ t: t, pos: pos, k: a.k, d: a.d });
      }
      out[u.id] = path;
    });
    return out;
  }

  var API = {
    COLS: COLS, ROWS: ROWS, N: N, TICKS: TICKS, ROUNDS: ROUNDS, MAP: MAP, TILE: TILE, PAD: PAD, PADS: PADS, PLATES: PLATES, DOORS: DOORS,
    SPAWN: SPAWN, PLATE_DOOR: PLATE_DOOR, DOOR_PLATE: DOOR_PLATE, DIRS: DIRS, DIR_NAMES: DIR_NAMES,
    idx: idx, cOf: cOf, rOf: rOf, step: step, rng: rng, act: act, sideName: sideName,
    newGame: newGame, cloneState: cloneState, nextActor: nextActor, advance: advance, stepAuto: stepAuto, liveOptions: liveOptions, applyLive: applyLive,
    doorOpen: doorOpen, canEnter: canEnter, strikeTargets: strikeTargets, echoForecast: echoForecast, echoOnlyRound: echoOnlyRound,
    bots: { action: botAction }, LEVELS: LEVELS
  };
  root.Echoes = API;
  if (typeof module !== "undefined" && module.exports) module.exports = API;
})(typeof window !== "undefined" ? window : globalThis);
