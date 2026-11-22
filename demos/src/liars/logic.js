/* Liar's Gambit: rules engine and bot. No DOM, so it runs in Node for tests.
   6 columns x 7 rows. Side 0 (Gold) starts on rows 5-6, side 1 (Ruby) on rows 0-1. */
(function (root) {
  "use strict";

  var COLS = 6, ROWS = 7, N = COLS * ROWS;
  var TYPES = ["C", "T", "B", "J", "G"];
  var BIT = { C: 1, T: 2, B: 4, J: 8, G: 16 };
  var NAME = { C: "Crown", T: "Tower", B: "Blade", J: "Jumper", G: "Guard" };
  var VAL = { C: 0, T: 5, B: 4.5, J: 3.5, G: 1.8 };
  var SET = ["C", "T", "T", "B", "B", "J", "G", "G"];
  var COUNTS = { C: 1, T: 2, B: 2, J: 1, G: 2 };
  var RANGE = 3;          /* Towers and Blades slide at most this far */
  var TOKENS = 3;         /* accusations per player */
  var PLY_LIMIT = 100;
  var CROWN_BLUFF = 0.12; /* a Crown bluffs far less often: getting caught loses the game */

  function rowOf(sq) { return (sq / COLS) | 0; }
  function colOf(sq) { return sq % COLS; }
  function homeRows(side) { return side === 0 ? [ROWS - 2, ROWS - 1] : [0, 1]; }
  function backRow(side) { return side === 0 ? ROWS - 1 : 0; }
  function frontRow(side) { return side === 0 ? ROWS - 2 : 1; }

  function rng(seed) {
    var a = (seed >>> 0) || 0x9e3779b9;
    return function () {
      a |= 0; a = (a + 0x6D2B79F5) | 0;
      var t = Math.imul(a ^ (a >>> 15), 1 | a);
      t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
      return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
    };
  }
  function shuffle(rand, arr) {
    for (var k = arr.length - 1; k > 0; k--) { var j = Math.floor(rand() * (k + 1)); var t = arr[k]; arr[k] = arr[j]; arr[j] = t; }
    return arr;
  }

  function maskNames(mask) {
    var out = [];
    TYPES.forEach(function (t) { if (mask & BIT[t]) out.push(NAME[t]); });
    return out;
  }
  function claimText(mask) {
    var n = maskNames(mask);
    if (n.length === 1) return "a " + n[0];
    if (n.length === 2) return "a " + n[0] + " or a " + n[1];
    return n.slice(0, -1).map(function (x) { return "a " + x; }).join(", ") + " or a " + n[n.length - 1];
  }
  function sideName(side) { return side === 0 ? "Gold" : "Ruby"; }

  /* ---------- State ---------- */
  function newGame(seed) {
    return {
      seed: seed, board: new Array(N).fill(-1), pieces: [], turn: 0, ply: 0,
      phase: "setup", lastMove: null, needSacrifice: -1, winner: null, reason: "", graveyard: [],
      tokens: [TOKENS, TOKENS],
      stats: { chances: [0, 0], calls: [0, 0] }, log: []
    };
  }

  /* arrangement: 8 squares in SET order (C, T, T, B, B, J, G, G) */
  function placeSide(s, side, arrangement) {
    SET.forEach(function (type, k) {
      var sq = arrangement[k];
      var id = s.pieces.length;
      s.pieces.push({ id: id, owner: side, type: type, sq: sq, home: sq, alive: true, revealed: false, pending: false, claims: [] });
      s.board[sq] = id;
    });
  }

  function randomSetup(rand, side, style) {
    var rows = homeRows(side), back = backRow(side), front = frontRow(side);
    var squares = [];
    rows.forEach(function (r) { for (var c = 0; c < COLS; c++) squares.push(r * COLS + c); });
    if (style === "chaos") { shuffle(rand, squares); return squares.slice(0, 8); }
    var crownCol = 1 + Math.floor(rand() * 4);
    if (rand() < 0.18) crownCol = rand() < 0.5 ? 0 : COLS - 1;
    var crownSq = (rand() < 0.15 ? front : back) * COLS + crownCol;
    var guardSq = (rowOf(crownSq) === back ? front : back) * COLS + crownCol;
    var rest = shuffle(rand, squares.filter(function (q) { return q !== crownSq && q !== guardSq; }));
    return [crownSq, rest[0], rest[1], rest[2], rest[3], rest[4], guardSq, rest[5]];
  }

  function startPlay(s) { s.phase = "play"; s.turn = 0; }

  function pieceAt(s, sq) { var id = s.board[sq]; return id >= 0 ? s.pieces[id] : null; }
  function alivePieces(s, side) { return s.pieces.filter(function (p) { return p.owner === side && p.alive; }); }

  function pathClear(s, from, to) {
    var fr = rowOf(from), fc = colOf(from), tr = rowOf(to), tc = colOf(to);
    var dr = Math.sign(tr - fr), dc = Math.sign(tc - fc);
    var r = fr + dr, c = fc + dc;
    while (r !== tr || c !== tc) {
      if (s.board[r * COLS + c] >= 0) return false;
      r += dr; c += dc;
    }
    return true;
  }

  /* Which piece types could honestly make this move? */
  function claimMask(s, from, to) {
    var dr = rowOf(to) - rowOf(from), dc = colOf(to) - colOf(from);
    var ar = Math.abs(dr), ac = Math.abs(dc);
    if (!ar && !ac) return 0;
    var m = 0;
    if (ar <= 1 && ac <= 1) m |= BIT.C;
    if (ar + ac === 1) m |= BIT.G;
    if ((ar === 0) !== (ac === 0) && Math.max(ar, ac) <= RANGE && pathClear(s, from, to)) m |= BIT.T;
    if (ar === ac && ar <= RANGE && pathClear(s, from, to)) m |= BIT.B;
    if ((ar === 1 && ac === 2) || (ar === 2 && ac === 1)) m |= BIT.J;
    return m;
  }

  function legalMoves(s, side) {
    var out = [];
    for (var i = 0; i < s.pieces.length; i++) {
      var p = s.pieces[i];
      if (p.owner !== side || !p.alive) continue;
      for (var to = 0; to < N; to++) {
        var occ = s.board[to];
        if (occ >= 0 && s.pieces[occ].owner === side) continue;
        var m = claimMask(s, p.sq, to);
        if (!m) continue;
        if (p.revealed && !(m & BIT[p.type])) continue;
        out.push({ pid: p.id, from: p.sq, to: to, claim: m, capture: occ });
      }
    }
    return out;
  }

  function isHonest(s, mv) { return (mv.claim & BIT[s.pieces[mv.pid].type]) !== 0; }

  function end(s, winner, reason) {
    if (s.winner != null) return;
    s.winner = winner; s.reason = reason; s.phase = "over";
  }

  function applyMove(s, mv) {
    var p = s.pieces[mv.pid];
    var cap = s.board[mv.to];
    s.board[mv.from] = -1;
    s.board[mv.to] = mv.pid;
    p.sq = mv.to;
    if (cap >= 0) { var cp = s.pieces[cap]; cp.alive = false; cp.pending = true; cp.sq = -1; }
    p.claims.push(mv.claim);
    s.lastMove = { pid: mv.pid, side: p.owner, from: mv.from, to: mv.to, claim: mv.claim, captured: cap, ply: s.ply, resolved: false, challenged: false, honest: null };
    s.ply += 1;
    s.turn = 1 - p.owner;
  }

  function finalizeCapture(s, lm) {
    if (lm.captured < 0) return;
    var cp = s.pieces[lm.captured];
    if (!cp.pending) return;
    cp.pending = false;
    cp.revealed = true;
    s.graveyard.push(cp.id);
    if (cp.type === "C") end(s, lm.side, sideName(lm.side) + " captured the " + sideName(cp.owner) + " Crown.");
  }

  function mustResolve(s) { return !!(s.phase === "play" && s.lastMove && !s.lastMove.resolved && s.lastMove.side !== s.turn); }
  function crownTaken(s) {
    var lm = s.lastMove;
    return !!(lm && !lm.resolved && lm.captured >= 0 && s.pieces[lm.captured].type === "C");
  }
  /* You can always call Liar on a capture of your Crown, even with no accusations left. */
  function canChallenge(s) {
    if (!mustResolve(s)) return false;
    if (s.pieces[s.lastMove.pid].revealed) return false;
    return s.tokens[s.turn] > 0 || crownTaken(s);
  }

  function accept(s) {
    var lm = s.lastMove;
    if (!s.pieces[lm.pid].revealed) s.stats.chances[1 - lm.side] += 1;
    lm.resolved = true;
    finalizeCapture(s, lm);
    if (s.winner == null) checkStuck(s);
  }

  function challenge(s) {
    var lm = s.lastMove;
    var p = s.pieces[lm.pid];
    var challenger = 1 - lm.side;
    var honest = (lm.claim & BIT[p.type]) !== 0;
    s.stats.chances[challenger] += 1; s.stats.calls[challenger] += 1;
    lm.resolved = true; lm.challenged = true; lm.honest = honest;
    var res = { honest: honest, pid: p.id, type: p.type, restored: -1 };
    if (!honest) {
      s.board[lm.to] = -1;
      p.alive = false; p.sq = -1; p.revealed = true;
      s.graveyard.push(p.id);
      if (lm.captured >= 0) {
        var cp = s.pieces[lm.captured];
        cp.alive = true; cp.pending = false; cp.sq = lm.to;
        s.board[lm.to] = cp.id;
        res.restored = cp.id;
      }
      if (p.type === "C") end(s, challenger, "The " + sideName(lm.side) + " Crown was caught lying.");
    } else {
      p.revealed = true;
      if (s.tokens[challenger] > 0) s.tokens[challenger] -= 1;
      finalizeCapture(s, lm);
      if (s.winner == null) {
        var nonCrown = alivePieces(s, challenger).filter(function (q) { return q.type !== "C"; });
        if (!nonCrown.length) end(s, lm.side, sideName(challenger) + " had nothing left to give up but its Crown.");
        else s.needSacrifice = challenger;
      }
    }
    if (s.winner == null && s.needSacrifice < 0) checkStuck(s);
    return res;
  }

  function sacrifice(s, pid) {
    var p = s.pieces[pid];
    if (!p || p.owner !== s.needSacrifice || !p.alive || p.type === "C") return false;
    s.board[p.sq] = -1;
    p.alive = false; p.sq = -1; p.revealed = true;
    s.graveyard.push(p.id);
    s.needSacrifice = -1;
    if (s.winner == null) checkStuck(s);
    return true;
  }

  function checkStuck(s) {
    if (s.phase !== "play") return;
    if (s.ply >= PLY_LIMIT) {
      var a = alivePieces(s, 0).length, b = alivePieces(s, 1).length;
      if (a !== b) end(s, a > b ? 0 : 1, "Move limit reached. " + sideName(a > b ? 0 : 1) + " had more pieces left.");
      else if (s.tokens[0] !== s.tokens[1]) end(s, s.tokens[0] > s.tokens[1] ? 0 : 1, "Move limit reached with equal pieces. " + sideName(s.tokens[0] > s.tokens[1] ? 0 : 1) + " had more accusations left.");
      else end(s, "draw", "The move limit arrived with everything even.");
      return;
    }
    if (!legalMoves(s, s.turn).length) end(s, 1 - s.turn, sideName(s.turn) + " has no legal moves.");
  }

  /* ---------- Beliefs: what `viewer` can infer about the other side's hidden pieces ---------- */
  function beliefs(s, viewer, beta, opts) {
    opts = opts || {};
    var opp = 1 - viewer;
    var counts = Object.assign({}, COUNTS);
    var unknown = [];
    s.pieces.forEach(function (p) {
      if (p.owner !== opp) return;
      if (p.revealed) counts[p.type] -= 1;
      else unknown.push(p);
    });
    var LL = unknown.map(function (p) {
      return TYPES.map(function (t) {
        var bt = t === "C" ? beta * CROWN_BLUFF : beta;
        var lh = Math.log(1 - bt), ll = Math.log(bt);
        var v = 0;
        for (var k = 0; k < p.claims.length; k++) v += (p.claims[k] & BIT[t]) ? lh : ll;
        if (t === "C" && opts.crownPrior && rowOf(p.home) === backRow(opp)) v += Math.log(opts.crownPrior);
        return v;
      });
    });
    var cnt = TYPES.map(function (t) { return Math.max(0, counts[t]); });
    var marg = unknown.map(function () { return [0, 0, 0, 0, 0]; });
    var leaves = [], assign = new Array(unknown.length), maxLL = -Infinity;
    (function rec(k, acc) {
      if (k === unknown.length) {
        leaves.push({ a: assign.slice(), ll: acc });
        if (acc > maxLL) maxLL = acc;
        return;
      }
      for (var t = 0; t < 5; t++) {
        if (cnt[t] <= 0) continue;
        cnt[t]--; assign[k] = t;
        rec(k + 1, acc + LL[k][t]);
        cnt[t]++;
      }
    })(0, 0);
    var total = 0;
    leaves.forEach(function (lf) {
      lf.w = Math.exp(lf.ll - maxLL);
      total += lf.w;
      for (var k = 0; k < lf.a.length; k++) marg[k][lf.a[k]] += lf.w;
    });
    var probs = {};
    unknown.forEach(function (p, k) { probs[p.id] = marg[k].map(function (x) { return total > 0 ? x / total : 0; }); });
    s.pieces.forEach(function (p) {
      if (p.owner === opp && p.revealed) { var row = [0, 0, 0, 0, 0]; row[TYPES.indexOf(p.type)] = 1; probs[p.id] = row; }
    });
    return { probs: probs };
  }

  function flatBeliefs(s, viewer) {
    var opp = 1 - viewer, counts = Object.assign({}, COUNTS), unknown = [];
    s.pieces.forEach(function (p) {
      if (p.owner !== opp) return;
      if (p.revealed) counts[p.type]--; else unknown.push(p);
    });
    var tot = 0;
    TYPES.forEach(function (t) { tot += Math.max(0, counts[t]); });
    var probs = {};
    unknown.forEach(function (p) { probs[p.id] = TYPES.map(function (t) { return tot ? Math.max(0, counts[t]) / tot : 0; }); });
    s.pieces.forEach(function (p) { if (p.owner === opp && p.revealed) { var r = [0, 0, 0, 0, 0]; r[TYPES.indexOf(p.type)] = 1; probs[p.id] = r; } });
    return { probs: probs };
  }

  function probType(B, pid, t) { var row = B.probs[pid]; return row ? row[TYPES.indexOf(t)] : 0; }
  function probInMask(B, pid, mask) {
    var row = B.probs[pid];
    if (!row) return 0;
    var v = 0;
    for (var k = 0; k < 5; k++) if (mask & BIT[TYPES[k]]) v += row[k];
    return v;
  }
  function expVal(B, pid) {
    var row = B.probs[pid];
    if (!row) return 0;
    var v = 0;
    for (var k = 0; k < 5; k++) v += row[k] * VAL[TYPES[k]];
    return v;
  }
  function lieChance(B, pid, mask, beta) {
    var row = B.probs[pid];
    if (!row) return 0;
    var a = 0, b = 0;
    for (var k = 0; k < 5; k++) {
      var bt = TYPES[k] === "C" ? beta * CROWN_BLUFF : beta;
      if (mask & BIT[TYPES[k]]) b += row[k] * (1 - bt); else a += row[k] * bt;
    }
    return a + b > 0 ? a / (a + b) : 0;
  }
  function entropy5(row) {
    var hsum = 0;
    for (var k = 0; k < 5; k++) if (row[k] > 0) hsum -= row[k] * Math.log(row[k]);
    return hsum / Math.log(5);
  }

  /* How often has `side` lied so far? Lies among the moves of its pieces whose type is now known. */
  function estimateBeta(s, side) {
    var lies = 0, moves = 0;
    s.pieces.forEach(function (p) {
      if (p.owner !== side || !p.revealed) return;
      p.claims.forEach(function (c) { moves++; if (!(c & BIT[p.type])) lies++; });
    });
    return Math.max(0.04, Math.min(0.45, (lies + 1.5) / (moves + 9)));
  }

  /* ---------- Bot ---------- */
  var LEVELS = {
    easy: { beta: 0.25, track: false, noise: 4.0, bluffy: 0.8, appetite: 0, randomCall: 0.1, callMargin: 0, adaptive: false, deceive: false, crownPrior: 1 },
    normal: { beta: 0.12, track: true, noise: 0.5, bluffy: 0, appetite: 0.3, randomCall: 0, callMargin: 1.2, minLie: 0.3, bluffRate: 0.35, tolerance: 3.5, adaptive: true, adaptiveRate: false, deceive: false, crownPrior: 1.4 },
    hard: { beta: 0.12, track: true, noise: 0.1, bluffy: 0, appetite: 0.2, randomCall: 0, callMargin: 1.2, minLie: 0.3, bluffRate: 0.3, tolerance: 2.8, adaptive: true, adaptiveRate: false, deceive: false, crownPrior: 1.5 }
  };
  var WIN = 1000;
  var TOKEN_VALUE = [0, 6.5, 4, 2.8];
  var SEEN_BETA = 0.16; /* how often the opponent is assumed to think we bluff */

  function cloneState(s) {
    return {
      seed: s.seed, board: s.board.slice(),
      pieces: s.pieces.map(function (p) { return { id: p.id, owner: p.owner, type: p.type, sq: p.sq, home: p.home, alive: p.alive, revealed: p.revealed, pending: p.pending, claims: p.claims.slice() }; }),
      turn: s.turn, ply: s.ply, phase: s.phase, lastMove: s.lastMove ? Object.assign({}, s.lastMove) : null,
      needSacrifice: s.needSacrifice, winner: s.winner, reason: s.reason, graveyard: s.graveyard.slice(),
      tokens: s.tokens.slice(), stats: { chances: s.stats.chances.slice(), calls: s.stats.calls.slice() }, log: []
    };
  }

  /* The bot's picture of the game: enemy pieces it hasn't seen have type "?". */
  function maskedView(s, me) {
    var v = cloneState(s);
    v.pieces.forEach(function (p) { if (p.owner !== me && !p.revealed) p.type = "?"; });
    return v;
  }

  var DEFAULT_W = { danger: 55, hunt: 14, threatIn: 0.35, threatOut: 0.35 };
  function evaluate(s, me, Bopp, PUB, W) {
    W = W || DEFAULT_W;
    if (s.winner != null) return s.winner === me ? WIN : s.winner === "draw" ? 0 : -WIN;
    var v = 0, myCrown = null, mine = [], theirs = [];
    var urg = 1 + Math.max(0, s.ply - 40) / 30;
    s.pieces.forEach(function (p) {
      if (!p.alive) return;
      if (p.owner === me) { mine.push(p); if (p.type === "C") myCrown = p; }
      else theirs.push(p);
    });
    mine.forEach(function (p) {
      if (p.type === "C") return;
      v += VAL[p.type] * (p.revealed ? 0.85 : 1);
      v += 0.08 * urg * (me === 0 ? ROWS - 1 - rowOf(p.sq) : rowOf(p.sq));
    });
    theirs.forEach(function (q) { v -= expVal(Bopp, q.id) * (q.revealed ? 0.85 : 1); });
    v += 0.9 * (s.tokens[me] - s.tokens[1 - me]);
    if (myCrown) {
      var pi = myCrown.revealed ? 1 : probType(PUB, myCrown.id, "C");
      var attempt = Math.max(0.3, pi);
      var safe = 1;
      theirs.forEach(function (q) {
        var m = claimMask(s, q.sq, myCrown.sq);
        if (m) safe *= 1 - attempt * probInMask(Bopp, q.id, m);
      });
      v -= W.danger * (1 - safe);
      if (myCrown.revealed) v -= 4;
      v -= 7 * pi;
      var shield = 0, cr = rowOf(myCrown.sq), cc = colOf(myCrown.sq);
      mine.forEach(function (p) { if (p !== myCrown && Math.abs(rowOf(p.sq) - cr) <= 1 && Math.abs(colOf(p.sq) - cc) <= 1) shield++; });
      v += 0.25 * Math.min(shield, 3);
      v -= 0.15 * Math.abs(rowOf(myCrown.sq) - backRow(me));
    }
    var fog = 0;
    mine.forEach(function (p) { if (!p.revealed && PUB.probs[p.id]) fog += entropy5(PUB.probs[p.id]); });
    v += 0.3 * fog;
    var hunt = 0, threatOut = 0;
    theirs.forEach(function (q) {
      var can = false;
      mine.forEach(function (p) { if (claimMask(s, p.sq, q.sq) & BIT[p.type]) can = true; });
      if (can) { hunt = Math.max(hunt, probType(Bopp, q.id, "C")); threatOut += W.threatOut * expVal(Bopp, q.id); }
    });
    v += urg * (W.hunt * hunt + threatOut);
    var threatIn = 0;
    mine.forEach(function (p) {
      if (p.type === "C") return;
      var worst = 0;
      theirs.forEach(function (q) {
        var m = claimMask(s, q.sq, p.sq);
        if (m) worst = Math.max(worst, probInMask(Bopp, q.id, m));
      });
      threatIn += W.threatIn * worst * VAL[p.type];
    });
    return v - threatIn;
  }

  /* Which piece would `side` give up? Cheap pieces first, never a likely Crown. */
  function cheapestSacrifice(s, side, B) {
    var best = null, bv = 1e9;
    s.pieces.forEach(function (p) {
      if (p.owner !== side || !p.alive || p.type === "C") return;
      var v = (p.type === "?" && B) ? expVal(B, p.id) + 60 * probType(B, p.id, "C") : VAL[p.type] * (p.revealed ? 0.8 : 1);
      if (v < bv) { bv = v; best = p; }
    });
    return best;
  }

  /* How likely is the opponent to call Liar on this move of mine? */
  function challengeOdds(s, PUB, mv, beta, adaptive, me) {
    var opp = 1 - me;
    if (s.tokens[opp] <= 0) return 0;
    var lie = lieChance(PUB, mv.pid, mv.claim, beta);
    var rate = 0.3;
    if (adaptive) rate = (s.stats.calls[opp] + 1.2) / (s.stats.chances[opp] + 4);
    var c = rate * (0.4 + 1.8 * lie) + (mv.capture >= 0 ? 0.1 + 0.25 * lie : 0);
    if (s.tokens[opp] === 1) c *= 0.6;
    return Math.max(0.02, Math.min(0.92, c));
  }

  function scoreMove(s, view, me, mv, Bopp, PUB, L, myBeta) {
    var honest = (mv.claim & BIT[view.pieces[mv.pid].type]) !== 0;
    var pc = mv.capture >= 0 ? probType(Bopp, mv.capture, "C") : 0;
    var stand = cloneState(view);
    applyMove(stand, mv);
    accept(stand);
    var PUBafter = (L.deceive && stand.winner == null) ? beliefs(stand, 1 - me, myBeta) : PUB;
    var vStand = evaluate(stand, me, Bopp, PUBafter, L.W);
    var chal = cloneState(view);
    applyMove(chal, mv);
    challenge(chal);
    if (chal.winner == null && chal.needSacrifice >= 0) {
      var victim = cheapestSacrifice(chal, chal.needSacrifice, Bopp);
      if (victim) sacrifice(chal, victim.id);
    }
    var vChal = evaluate(chal, me, Bopp, PUB, L.W);
    var cn = challengeOdds(s, PUB, mv, myBeta, L.adaptiveRate, me);
    var crownBranch = honest ? WIN : vChal;
    var ev = pc * crownBranch + (1 - pc) * ((1 - cn) * vStand + cn * vChal);
    return { mv: mv, ev: ev, honest: honest, cn: cn, crown: view.pieces[mv.pid].type === "C" };
  }

  function botMove(s, me, level, rand) {
    var L = LEVELS[level] || LEVELS.normal;
    var oppBeta = L.adaptive ? estimateBeta(s, 1 - me) : L.beta;
    var myBeta = SEEN_BETA;
    var view = maskedView(s, me);
    var Bopp = L.track ? beliefs(s, me, oppBeta, { crownPrior: L.crownPrior }) : flatBeliefs(s, me);
    var PUB = beliefs(s, 1 - me, myBeta);
    var moves = legalMoves(view, me);
    if (!moves.length) return null;
    var best = null, bestHonest = null, bestBluff = null;
    moves.forEach(function (mv) {
      var sc = scoreMove(s, view, me, mv, Bopp, PUB, L, myBeta);
      if (!sc.honest && L.bluffy) sc.ev += L.bluffy * (rand() - 0.3) * 4;
      if (!sc.honest && L.appetite) sc.ev += L.appetite;
      sc.ev += (rand() - 0.5) * L.noise;
      if (!best || sc.ev > best.ev) best = sc;
      if (sc.honest) { if (!bestHonest || sc.ev > bestHonest.ev) bestHonest = sc; }
      else if (!sc.crown && sc.cn < 0.6 && (!bestBluff || sc.ev > bestBluff.ev)) bestBluff = sc;
    });
    /* Mixed strategy: a bot that never lies can simply be trusted, so now and then
       it takes a bluff that costs little next to its best honest move. */
    if (L.bluffRate && bestBluff && bestHonest && bestHonest.ev < 300 && bestBluff.ev >= bestHonest.ev - L.tolerance && rand() < L.bluffRate) return bestBluff.mv;
    return best.mv;
  }

  /* Should `me` call Liar on the opponent's last move? Compares the two futures. */
  function botChallenge(s, me, level, rand) {
    var L = LEVELS[level] || LEVELS.normal;
    if (!canChallenge(s)) return false;
    var lm = s.lastMove;
    if (crownTaken(s)) return true;
    var mover = s.pieces[lm.pid];
    if (L.randomCall) {
      var urge = L.randomCall + (lm.captured >= 0 ? 0.1 : 0);
      return rand() < urge;
    }
    var oppBeta = L.adaptive ? estimateBeta(s, 1 - me) : L.beta;
    var B = L.track ? beliefs(s, me, oppBeta, { crownPrior: L.crownPrior }) : flatBeliefs(s, me);
    var PUB = beliefs(s, 1 - me, SEEN_BETA);
    var row = B.probs[mover.id] || [0, 0, 0, 0, 0];
    var pLie = 0, crownOut = 0;
    for (var k = 0; k < 5; k++) if (!(lm.claim & BIT[TYPES[k]])) { pLie += row[k]; if (TYPES[k] === "C") crownOut += row[k]; }
    var view = maskedView(s, me);
    var acc = cloneState(view);
    accept(acc);
    var vAccept = evaluate(acc, me, B, PUB);
    var lie = cloneState(view);
    var lp = lie.pieces[lm.pid];
    lie.board[lm.to] = -1; lp.alive = false; lp.sq = -1; lp.revealed = true;
    if (lm.captured >= 0) { var cp = lie.pieces[lm.captured]; cp.alive = true; cp.pending = false; cp.sq = lm.to; lie.board[lm.to] = cp.id; }
    lie.lastMove = null;
    var crownGivenLie = pLie > 0 ? crownOut / pLie : 0;
    var vLie = crownGivenLie * WIN + (1 - crownGivenLie) * evaluate(lie, me, B, PUB);
    var tru = cloneState(acc);
    tru.pieces[lm.pid].revealed = true;
    tru.tokens[me] = Math.max(0, tru.tokens[me] - 1);
    var mine = cheapestSacrifice(tru, me, null);
    if (mine) { tru.board[mine.sq] = -1; tru.pieces[mine.id].alive = false; tru.pieces[mine.id].sq = -1; tru.pieces[mine.id].revealed = true; }
    var vTruth = mine ? evaluate(tru, me, B, PUB) + 0.5 : -WIN;
    vTruth -= TOKEN_VALUE[s.tokens[me]] || 0;
    var evChallenge = pLie * vLie + (1 - pLie) * vTruth;
    if (L.minLie && pLie < L.minLie && vAccept > -300) return false;
    var margin = L.callMargin + (rand() - 0.5) * L.noise * 2;
    return evChallenge > vAccept + margin;
  }

  function botSacrifice(s, me) {
    var p = cheapestSacrifice(s, me, null);
    return p ? p.id : -1;
  }

  function botSetup(rand, side, level) {
    return randomSetup(rand, side, level === "easy" ? "chaos" : "normal");
  }

  /* What a piece's moves so far are all consistent with (31 = no moves yet). */
  function storyMask(p) {
    var m = 31;
    p.claims.forEach(function (c) { m &= c; });
    return m;
  }

  var API = {
    COLS: COLS, ROWS: ROWS, N: N, TYPES: TYPES, BIT: BIT, NAME: NAME, VAL: VAL, SET: SET, COUNTS: COUNTS, RANGE: RANGE, TOKENS: TOKENS, PLY_LIMIT: PLY_LIMIT,
    rowOf: rowOf, colOf: colOf, homeRows: homeRows, backRow: backRow, rng: rng, maskNames: maskNames, claimText: claimText, sideName: sideName,
    newGame: newGame, placeSide: placeSide, randomSetup: randomSetup, startPlay: startPlay, pieceAt: pieceAt, alivePieces: alivePieces,
    claimMask: claimMask, legalMoves: legalMoves, isHonest: isHonest, applyMove: applyMove, mustResolve: mustResolve, crownTaken: crownTaken,
    canChallenge: canChallenge, accept: accept, challenge: challenge, sacrifice: sacrifice, checkStuck: checkStuck, storyMask: storyMask,
    beliefs: beliefs, lieChance: lieChance, cloneState: cloneState, estimateBeta: estimateBeta,
    bots: { move: botMove, challenge: botChallenge, sacrifice: botSacrifice, setup: botSetup }, LEVELS: LEVELS
  };
  root.Liars = API;
  if (typeof module !== "undefined" && module.exports) module.exports = API;
})(typeof window !== "undefined" ? window : globalThis);
