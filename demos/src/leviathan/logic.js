/* Leviathan Hunt: rules engine and bots. No DOM, so it runs in Node for tests. */
(function (root) {
  "use strict";

  var COLS = 9, ROWS = 11, N = COLS * ROWS;
  var SEA = 0, REEF = 1, ISLAND = 2;
  var CFG = {
    orders: 4, roundLimit: 20, surfaceEvery: 6, killsToWin: 4, woundsToWin: 3,
    shipHP: 2, netTTL: 3, maxNets: 2, buoys: 6,
    sonarRange: 2, harpoonRange: 3, harpoonMin: 2, harpoonMove: 1, beamRange: 4, beamMin: 3, shipMove: 2, startRows: 4
  };
  var SHIP_DEFS = [
    { id: "sonar", name: "Sonar", ability: "ping", verb: "Ping" },
    { id: "harpoon", name: "Harpoon", ability: "harpoon", verb: "Harpoon" },
    { id: "net", name: "Net", ability: "net", verb: "Net" },
    { id: "light", name: "Lighthouse", ability: "beam", verb: "Beam" }
  ];

  /* ---------- Hex grid (pointy-top, odd rows shifted right) ---------- */
  function cOf(i) { return i % COLS; }
  function rOf(i) { return (i / COLS) | 0; }
  var NB_EVEN = [[1, 0], [0, -1], [-1, -1], [-1, 0], [-1, 1], [0, 1]];
  var NB_ODD = [[1, 0], [1, -1], [0, -1], [-1, 0], [0, 1], [1, 1]];
  function stepDir(i, d) {
    var c = cOf(i), r = rOf(i);
    var o = (r & 1 ? NB_ODD : NB_EVEN)[d];
    var nc = c + o[0], nr = r + o[1];
    if (nc < 0 || nc >= COLS || nr < 0 || nr >= ROWS) return -1;
    return nr * COLS + nc;
  }
  var NEI = [], DIRN = [];
  for (var i0 = 0; i0 < N; i0++) {
    DIRN[i0] = [];
    NEI[i0] = [];
    for (var d0 = 0; d0 < 6; d0++) {
      var t0 = stepDir(i0, d0);
      DIRN[i0].push(t0);
      if (t0 >= 0) NEI[i0].push(t0);
    }
  }
  function cube(i) {
    var c = cOf(i), r = rOf(i);
    var x = c - ((r - (r & 1)) >> 1);
    return [x, -x - r, r];
  }
  var DIST = new Uint8Array(N * N);
  (function () {
    var cs = [];
    for (var a = 0; a < N; a++) cs.push(cube(a));
    for (var a2 = 0; a2 < N; a2++) for (var b = 0; b < N; b++) {
      var A = cs[a2], B = cs[b];
      DIST[a2 * N + b] = Math.max(Math.abs(A[0] - B[0]), Math.abs(A[1] - B[1]), Math.abs(A[2] - B[2]));
    }
  })();
  function dist(a, b) { return DIST[a * N + b]; }
  function disk(center, radius) {
    var out = [];
    for (var t = 0; t < N; t++) if (dist(center, t) <= radius) out.push(t);
    return out;
  }

  /* ---------- RNG ---------- */
  function rng(seed) {
    var a = (seed >>> 0) || 0x9e3779b9;
    return function () {
      a |= 0; a = (a + 0x6D2B79F5) | 0;
      var t = Math.imul(a ^ (a >>> 15), 1 | a);
      t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
      return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
    };
  }
  function pick(rand, arr) { return arr[Math.floor(rand() * arr.length)]; }
  function shuffle(rand, arr) {
    for (var k = arr.length - 1; k > 0; k--) { var j = Math.floor(rand() * (k + 1)); var tmp = arr[k]; arr[k] = arr[j]; arr[j] = tmp; }
    return arr;
  }

  /* ---------- Map generation ---------- */
  function connected(terrain, passable) {
    var start = -1, total = 0;
    for (var t = 0; t < N; t++) if (passable(terrain[t])) { total++; if (start < 0) start = t; }
    if (start < 0) return false;
    var seen = new Uint8Array(N), stack = [start], count = 0;
    seen[start] = 1;
    while (stack.length) {
      var x = stack.pop(); count++;
      for (var k = 0; k < NEI[x].length; k++) {
        var y = NEI[x][k];
        if (!seen[y] && passable(terrain[y])) { seen[y] = 1; stack.push(y); }
      }
    }
    return count === total;
  }

  function genMap(rand) {
    for (var attempt = 0; attempt < 400; attempt++) {
      var terrain = new Uint8Array(N);
      var clusters = 4 + Math.floor(rand() * 2);
      for (var k = 0; k < clusters; k++) {
        var seed = (1 + Math.floor(rand() * 7)) * COLS + Math.floor(rand() * COLS);
        terrain[seed] = ISLAND;
        var size = 1 + Math.floor(rand() * 3);
        var cur = seed;
        for (var g = 1; g < size; g++) {
          var nb = pick(rand, NEI[cur]);
          if (rOf(nb) >= 1 && rOf(nb) <= 8) { terrain[nb] = ISLAND; cur = nb; }
        }
      }
      var reefs = 0, guard = 0;
      while (reefs < 7 && guard++ < 200) {
        var rt = (1 + Math.floor(rand() * 8)) * COLS + Math.floor(rand() * COLS);
        if (terrain[rt] === SEA) { terrain[rt] = REEF; reefs++; }
      }
      var ok = true;
      for (var hb = 9 * COLS; hb < N; hb++) if (terrain[hb] !== SEA) { ok = false; break; }
      if (!ok) continue;
      var islands = 0;
      for (var q = 0; q < N; q++) if (terrain[q] === ISLAND) islands++;
      if (islands < 6 || islands > 12) continue;
      if (!connected(terrain, function (v) { return v === SEA; })) continue;
      if (!connected(terrain, function (v) { return v !== ISLAND; })) continue;
      var shipStarts = [1, 3, 5, 7].map(function (c) { return 10 * COLS + c; });
      var cand = [];
      for (var b = 2 * COLS; b < 9 * COLS; b++) if (terrain[b] === SEA) cand.push(b);
      shuffle(rand, cand);
      var buoys = [];
      for (var bi = 0; bi < cand.length && buoys.length < CFG.buoys; bi++) {
        var p = cand[bi];
        var far = buoys.every(function (o) { return dist(o, p) >= 3; });
        if (far) buoys.push(p);
      }
      if (buoys.length < CFG.buoys) continue;
      var spread = { left: 0, right: 0, top: 0, bottom: 0 };
      buoys.forEach(function (p) {
        if (cOf(p) <= 3) spread.left++; if (cOf(p) >= 5) spread.right++;
        if (rOf(p) <= 4) spread.top++; if (rOf(p) >= 5) spread.bottom++;
      });
      if (!spread.left || !spread.right || !spread.top || !spread.bottom) continue;
      if (zoneFor(terrain, buoys, 3).length < 10) continue;
      return { terrain: terrain, buoys: buoys, shipStarts: shipStarts };
    }
    throw new Error("map generation failed");
  }

  /* ---------- State ---------- */
  function newGame(seed) {
    var rand = rng(seed);
    var map = genMap(rand);
    var s = {
      seed: seed,
      terrain: map.terrain,
      round: 1,
      phase: "start",
      monster: { pos: -1, wounds: 0, kills: 0, snagged: false, trail: [] },
      ships: SHIP_DEFS.map(function (d, k) {
        return { id: d.id, name: d.name, ability: d.ability, verb: d.verb, pos: map.shipStarts[k], hp: CFG.shipHP, sunk: false, moved: false, acted: false };
      }),
      buoys: map.buoys.map(function (p) { return { pos: p, alive: true }; }),
      nets: [],
      wake: -1,
      orders: CFG.orders,
      P: [],
      revealedAt: -1,
      winner: null,
      reason: "",
      log: []
    };
    s.P = startZone(s);
    return s;
  }

  function clone(s) {
    return {
      seed: s.seed, terrain: s.terrain, round: s.round, phase: s.phase,
      monster: { pos: s.monster.pos, wounds: s.monster.wounds, kills: s.monster.kills, snagged: s.monster.snagged, trail: s.monster.trail.slice() },
      ships: s.ships.map(function (x) { return { id: x.id, name: x.name, ability: x.ability, verb: x.verb, pos: x.pos, hp: x.hp, sunk: x.sunk, moved: x.moved, acted: x.acted }; }),
      buoys: s.buoys.map(function (b) { return { pos: b.pos, alive: b.alive }; }),
      nets: s.nets.map(function (n) { return { pos: n.pos, ttl: n.ttl }; }),
      wake: s.wake, orders: s.orders, P: s.P.slice(), revealedAt: s.revealedAt,
      winner: s.winner, reason: s.reason, log: []
    };
  }

  /* The Leviathan starts in the northern waters, at least 3 tiles from every buoy,
     so it can't feed on the very first turn. */
  function zoneFor(terrain, buoys, minGap) {
    var out = [];
    for (var t = 0; t < CFG.startRows * COLS; t++) {
      if (terrain[t] === ISLAND) continue;
      var ok = true;
      for (var k = 0; k < buoys.length; k++) if (dist(buoys[k], t) < minGap) { ok = false; break; }
      if (ok) out.push(t);
    }
    return out;
  }
  function startZone(s) {
    var bp = s.buoys.map(function (b) { return b.pos; });
    var z = zoneFor(s.terrain, bp, 3);
    return z.length >= 8 ? z : zoneFor(s.terrain, bp, 2);
  }

  function shipAt(s, t) {
    for (var k = 0; k < s.ships.length; k++) if (!s.ships[k].sunk && s.ships[k].pos === t) return k;
    return -1;
  }
  function buoyAt(s, t) {
    for (var k = 0; k < s.buoys.length; k++) if (s.buoys[k].alive && s.buoys[k].pos === t) return s.buoys[k];
    return null;
  }
  function netAt(s, t) {
    for (var k = 0; k < s.nets.length; k++) if (s.nets[k].pos === t) return s.nets[k];
    return null;
  }
  function harpoonIdx(s) { return 1; }
  function aliveShips(s) { return s.ships.filter(function (x) { return !x.sunk; }); }

  function monsterCanEnter(s, t) {
    return t >= 0 && s.terrain[t] !== ISLAND && !netAt(s, t) && shipAt(s, t) < 0;
  }
  function shipCanEnter(s, t, k) {
    if (t < 0 || s.terrain[t] !== SEA) return false;
    var o = shipAt(s, t);
    if (o >= 0 && o !== k) return false;
    if (buoyAt(s, t)) return false;
    if (s.revealedAt === t && s.ships[k].id !== "harpoon") return false;
    return true;
  }
  function netTiles(s, pos) { return NEI[pos].filter(function (t) { return s.terrain[t] !== ISLAND; }); }
  function harpoonRing(s, pos) {
    var out = [];
    for (var t = 0; t < N; t++) { var d = dist(pos, t); if (d >= CFG.harpoonMin && d <= CFG.harpoonRange && s.terrain[t] !== ISLAND) out.push(t); }
    return out;
  }

  /* Public belief updates: what the hunters can deduce. */
  function expandPublic(s, P) {
    var mark = new Uint8Array(N), out = [];
    for (var k = 0; k < P.length; k++) {
      var t = P[k];
      if (!mark[t]) { mark[t] = 1; out.push(t); }
      var nb = NEI[t];
      for (var j = 0; j < nb.length; j++) {
        var u = nb[j];
        if (!mark[u] && monsterCanEnter(s, u)) { mark[u] = 1; out.push(u); }
      }
    }
    return out;
  }
  function reach2(s, from) {
    var mark = new Uint8Array(N), out = [];
    var nb = NEI[from];
    for (var j = 0; j < nb.length; j++) {
      var mid = nb[j];
      if (!monsterCanEnter(s, mid)) continue;
      var nb2 = NEI[mid];
      for (var q = 0; q < nb2.length; q++) {
        var t = nb2[q];
        if (mark[t] || t === from || dist(from, t) !== 2 || !monsterCanEnter(s, t)) continue;
        mark[t] = 1; out.push(t);
      }
    }
    return out;
  }
  function removeTiles(P, tiles) {
    var mark = new Uint8Array(N);
    tiles.forEach(function (t) { if (t >= 0) mark[t] = 1; });
    return P.filter(function (t) { return !mark[t]; });
  }
  function keepTiles(P, tiles) {
    var mark = new Uint8Array(N);
    tiles.forEach(function (t) { if (t >= 0) mark[t] = 1; });
    return P.filter(function (t) { return mark[t]; });
  }

  function reveal(s, pos, why, ev) {
    s.revealedAt = pos;
    s.P = [pos];
    ev.push({ t: "reveal", pos: pos, why: why });
  }
  function win(s, who, reason) {
    if (s.winner) return;
    s.winner = who;
    s.reason = reason;
    s.phase = "over";
  }

  /* ---------- Leviathan ---------- */
  function setMonsterStart(s, pos) {
    s.monster.pos = pos;
    s.monster.trail = [{ round: 0, pos: pos, how: "start" }];
    s.phase = "monster";
  }

  function monsterOptions(s) {
    var m = s.monster.pos, opts = [{ type: "swim", to: m }];
    NEI[m].forEach(function (t) { if (monsterCanEnter(s, t)) opts.push({ type: "swim", to: t }); });
    if (!s.monster.snagged) {
      var seen = new Uint8Array(N);
      NEI[m].forEach(function (mid) {
        if (!monsterCanEnter(s, mid)) return;
        NEI[mid].forEach(function (t) {
          if (seen[t] || t === m || dist(m, t) !== 2 || !monsterCanEnter(s, t)) return;
          seen[t] = 1;
          opts.push({ type: "dash", to: t, via: mid });
        });
      });
    }
    s.ships.forEach(function (sh, k) {
      if (!sh.sunk && dist(m, sh.pos) === 1) opts.push({ type: "strike", ship: k });
    });
    return opts;
  }

  function applyMonster(s, act) {
    var ev = [];
    var m = s.monster, from = m.pos;
    s.wake = -1;
    s.revealedAt = -1;
    if (act.type === "strike") {
      var sh = s.ships[act.ship];
      sh.hp -= 1;
      ev.push({ t: "strike", ship: act.ship, from: from });
      reveal(s, from, "strike", ev);
      if (sh.hp <= 0) {
        sh.sunk = true;
        m.kills += 1;
        ev.push({ t: "sunk", ship: act.ship });
        if (sh.id === "harpoon") win(s, "monster", "The Harpoon ship sank, so nothing can wound the Leviathan now.");
      }
    } else {
      m.pos = act.to;
      if (act.type === "dash") {
        s.wake = from;
        ev.push({ t: "dash", from: from, to: act.to });
        s.P = reach2(s, from);
      } else {
        ev.push({ t: "swim", from: from, to: act.to });
        s.P = expandPublic(s, s.P);
      }
      var b = buoyAt(s, m.pos);
      if (b) {
        b.alive = false;
        m.kills += 1;
        ev.push({ t: "devour", pos: m.pos });
        reveal(s, m.pos, "devour", ev);
      }
    }
    m.snagged = false;
    m.trail.push({ round: s.round, pos: m.pos, how: act.type });
    if (!s.winner && s.round % CFG.surfaceEvery === 0 && s.revealedAt !== m.pos) reveal(s, m.pos, "surface", ev);
    if (!s.winner && m.kills >= CFG.killsToWin) win(s, "monster", "The Leviathan destroyed " + m.kills + " targets.");
    if (!s.winner) {
      s.phase = "hunters";
      s.orders = CFG.orders;
      s.ships.forEach(function (x) { x.moved = false; x.acted = false; });
    }
    s.log.push({ side: "monster", round: s.round, act: act, ev: ev });
    return ev;
  }

  /* ---------- Hunters ---------- */
  function shipMovesRaw(s, k) {
    var sh = s.ships[k], res = {};
    var prev = {}; prev[sh.pos] = -1;
    var frontier = [sh.pos];
    var steps = sh.id === "harpoon" ? CFG.harpoonMove : CFG.shipMove;
    for (var step = 0; step < steps; step++) {
      var next = [];
      frontier.forEach(function (x) {
        NEI[x].forEach(function (y) {
          if (prev[y] !== undefined || !shipCanEnter(s, y, k)) return;
          prev[y] = x;
          next.push(y);
        });
      });
      frontier = next;
    }
    Object.keys(prev).forEach(function (key) {
      var t = +key;
      if (t === sh.pos) return;
      var path = [], cur = t;
      while (cur !== sh.pos) { path.unshift(cur); cur = prev[cur]; }
      res[t] = path;
    });
    return res;
  }
  function shipMoves(s, k) {
    var sh = s.ships[k];
    if (sh.sunk || sh.moved || s.orders < 1) return {};
    return shipMovesRaw(s, k);
  }

  function abilityTargets(s, k) {
    var sh = s.ships[k], out = [];
    if (sh.sunk || sh.acted || s.orders < 1) return out;
    if (sh.ability === "ping") return [sh.pos];
    if (sh.ability === "harpoon") return harpoonRing(s, sh.pos).filter(function (t) { return shipAt(s, t) < 0; });
    if (sh.ability === "net") return [sh.pos];
    if (sh.ability === "beam") {
      for (var d = 0; d < 6; d++) if (beamTiles(s, sh.pos, d).length >= CFG.beamMin) out.push(d);
      return out;
    }
    return out;
  }

  function beamTiles(s, from, d) {
    var out = [], cur = from;
    for (var k = 0; k < CFG.beamRange; k++) {
      cur = DIRN[cur][d];
      if (cur < 0 || s.terrain[cur] === ISLAND) break;
      out.push(cur);
    }
    return out;
  }

  function applyHunter(s, o) {
    var ev = [];
    var sh = s.ships[o.ship];
    var m = s.monster;
    var path = o.type === "move" ? (shipMovesRaw(s, o.ship)[o.to] || [o.to]) : null;
    s.orders -= 1;
    if (o.type === "move") {
      var from = sh.pos, walked = [];
      for (var k = 0; k < path.length; k++) {
        if (path[k] === m.pos) {
          if (sh.id === "harpoon") {
            m.wounds += 1;
            ev.push({ t: "ram", ship: o.ship, at: path[k], stop: sh.pos, from: from, path: walked.slice(), hit: true });
            reveal(s, m.pos, "ram", ev);
            if (m.wounds >= CFG.woundsToWin) win(s, "hunters", "Three harpoons found their mark.");
          } else {
            ev.push({ t: "bump", ship: o.ship, at: path[k], stop: sh.pos, from: from, path: walked.slice() });
            reveal(s, m.pos, "bump", ev);
          }
          break;
        }
        sh.pos = path[k];
        walked.push(path[k]);
      }
      sh.moved = true;
      ev.unshift({ t: "move", ship: o.ship, from: from, path: walked });
      if (s.revealedAt !== m.pos) s.P = removeTiles(s.P, walked);
    } else if (o.type === "ping") {
      var area = disk(sh.pos, CFG.sonarRange);
      var contact = dist(sh.pos, m.pos) <= CFG.sonarRange;
      ev.push({ t: "ping", ship: o.ship, at: sh.pos, contact: contact });
      if (s.revealedAt !== m.pos) s.P = contact ? keepTiles(s.P, area) : removeTiles(s.P, area);
      sh.acted = true;
    } else if (o.type === "harpoon") {
      var hit = o.target === m.pos;
      ev.push({ t: "harpoon", ship: o.ship, from: sh.pos, target: o.target, hit: hit });
      sh.acted = true;
      if (hit) {
        m.wounds += 1;
        reveal(s, m.pos, "harpoon", ev);
        if (m.wounds >= CFG.woundsToWin) win(s, "hunters", "Three harpoons found their mark.");
      } else if (s.revealedAt !== m.pos) {
        s.P = removeTiles(s.P, [o.target]);
      }
    } else if (o.type === "net") {
      var ring = netTiles(s, sh.pos);
      var snag = ring.indexOf(m.pos) >= 0;
      ev.push({ t: "net", ship: o.ship, at: sh.pos, tiles: ring, snag: snag });
      sh.acted = true;
      if (snag) { m.snagged = true; reveal(s, m.pos, "net", ev); }
      else if (s.revealedAt !== m.pos) s.P = removeTiles(s.P, ring);
    } else if (o.type === "beam") {
      var tiles = beamTiles(s, sh.pos, o.dir);
      var found = tiles.indexOf(m.pos) >= 0;
      ev.push({ t: "beam", ship: o.ship, from: sh.pos, dir: o.dir, tiles: tiles, found: found });
      sh.acted = true;
      if (found) reveal(s, m.pos, "beam", ev);
      else if (s.revealedAt !== m.pos) s.P = removeTiles(s.P, tiles);
    }
    s.log.push({ side: "hunters", round: s.round, act: o, ev: ev });
    return ev;
  }

  function endHunterTurn(s) {
    var ev = [];
    s.nets.forEach(function (n) { n.ttl -= 1; });
    s.nets = s.nets.filter(function (n) { return n.ttl > 0; });
    if (s.winner) return ev;
    if (s.round >= CFG.roundLimit) {
      win(s, "hunters", "Dawn broke before the Leviathan could feed, and it sank back into the deep.");
      return ev;
    }
    s.round += 1;
    s.phase = "monster";
    s.orders = 0;
    return ev;
  }

  function hasAnyOrder(s) {
    if (s.orders < 1) return false;
    for (var k = 0; k < s.ships.length; k++) {
      var sh = s.ships[k];
      if (sh.sunk) continue;
      if (!sh.acted && abilityTargets(s, k).length) return true;
      if (!sh.moved && Object.keys(shipMoves(s, k)).length) return true;
    }
    return false;
  }

  /* ---------- Bots ---------- */
  var LEVELS = {
    easy: { noise: 0.9, lookahead: false, track: "sloppy", greed: 1.3, caution: 0.35, mistakes: 0.3 },
    normal: { noise: 0.15, lookahead: false, track: "exact", greed: 1.0, caution: 1.0, mistakes: 0.04 },
    hard: { noise: 0.03, lookahead: true, track: "weighted", greed: 1.0, caution: 1.2, mistakes: 0 }
  };

  function beliefWeights(s, level) {
    var P = s.P, w = new Float64Array(N), total = 0;
    var weighted = LEVELS[level].track === "weighted";
    var hp = s.ships[1];
    P.forEach(function (t) {
      var v = 1;
      if (weighted && P.length > 1) {
        var nearB = 99;
        s.buoys.forEach(function (b) { if (b.alive) nearB = Math.min(nearB, dist(b.pos, t)); });
        v *= 1 + 0.6 / (1 + nearB);
        if (!hp.sunk) v *= 0.7 + 0.08 * Math.min(6, dist(hp.pos, t));
        if (s.terrain[t] === REEF) v *= 1.15;
      }
      w[t] = v; total += v;
    });
    return { w: w, total: total || 1 };
  }

  function harpoonReachTiles(s, ordersLeft) {
    var hk = 1, h = s.ships[hk];
    if (h.sunk || h.acted || ordersLeft < 1) return null;
    var spots = [h.pos];
    var mark = new Uint8Array(N);
    if (!h.moved) {
      var mv = shipMovesRaw(s, hk);
      Object.keys(mv).forEach(function (t) { mark[+t] = 1; if (ordersLeft >= 2) spots.push(+t); });
    }
    spots.forEach(function (p) { harpoonRing(s, p).forEach(function (t) { mark[t] = 1; }); });
    return mark;
  }

  function bestShot(P, w, total, mark) {
    if (!mark) return 0;
    var best = 0;
    for (var k = 0; k < P.length; k++) { var t = P[k]; if (mark[t] && w[t] > best) best = w[t]; }
    return best / total;
  }

  function entropy(P, w) {
    var tot = 0, k;
    for (k = 0; k < P.length; k++) tot += w[P[k]];
    if (tot <= 0) return 0;
    var hsum = 0;
    for (k = 0; k < P.length; k++) { var p = w[P[k]] / tot; if (p > 0) hsum -= p * Math.log(p); }
    return hsum;
  }

  function splitValue(s, B, region, ordersAfter) {
    var P = s.P, mark = new Uint8Array(N);
    region.forEach(function (t) { mark[t] = 1; });
    var inP = [], outP = [], mi = 0, mo = 0;
    P.forEach(function (t) { if (mark[t]) { inP.push(t); mi += B.w[t]; } else { outP.push(t); mo += B.w[t]; } });
    var tot = mi + mo || 1;
    var pin = mi / tot;
    var reach = harpoonReachTiles(s, ordersAfter);
    var u0 = bestShot(P, B.w, B.total, reach);
    var uin = mi > 0 ? bestShot(inP, B.w, mi, reach) : 0;
    var uout = mo > 0 ? bestShot(outP, B.w, mo, reach) : 0;
    var eu = pin * uin + (1 - pin) * uout;
    var h0 = entropy(P, B.w);
    var eh = pin * entropy(inP, B.w) + (1 - pin) * entropy(outP, B.w);
    return { gain: Math.max(0, eu - u0), info: Math.max(0, h0 - eh), pin: pin };
  }

  function riskAt(s, B, pos, k) {
    var sh = s.ships[k], r = 0;
    NEI[pos].forEach(function (t) { r += B.w[t] / B.total; });
    var factor = sh.hp >= 2 ? 0.25 : 0.9;
    if (sh.id === "harpoon") factor = sh.hp >= 2 ? 0.9 : 3.5;
    return r * factor;
  }

  function posValue(s, B, k, pos) {
    var sh = s.ships[k], v = 0, t;
    if (sh.id === "harpoon") {
      var near = 0, mid = 0;
      for (var q = 0; q < s.P.length; q++) {
        t = s.P[q];
        var dd = dist(pos, t);
        if (dd <= 4) near += B.w[t];
        if (dd <= 6) mid += B.w[t];
      }
      v += 1.2 * near / B.total + 0.4 * mid / B.total;
      var cover = 0;
      s.buoys.forEach(function (b) { if (b.alive && dist(b.pos, pos) <= 4) cover++; });
      s.ships.forEach(function (o, j) { if (j !== k && !o.sunk && dist(o.pos, pos) <= 4) cover += 0.5; });
      v += 0.08 * cover;
    } else if (sh.id === "sonar") {
      var mi = 0;
      for (var q2 = 0; q2 < s.P.length; q2++) { t = s.P[q2]; if (dist(pos, t) <= CFG.sonarRange + 1) mi += B.w[t]; }
      var frac = mi / B.total;
      v += 0.6 - Math.abs(frac - 0.5);
    } else if (sh.id === "light") {
      var best = 0;
      for (var d = 0; d < 6; d++) {
        var m = 0;
        beamTiles(s, pos, d).forEach(function (x) { m += B.w[x] || 0; });
        best = Math.max(best, m);
      }
      v += 0.8 * best / B.total;
    } else if (sh.id === "net") {
      var close = 0;
      for (var q3 = 0; q3 < s.P.length; q3++) { t = s.P[q3]; if (dist(pos, t) <= 2) close += B.w[t]; }
      v += 0.6 * close / B.total;
      var bcover = 0;
      s.buoys.forEach(function (b) { if (b.alive && dist(b.pos, pos) <= 2) bcover++; });
      v += 0.05 * bcover;
    }
    return v - riskAt(s, B, pos, k);
  }

  function candidateOrders(s) {
    var out = [];
    s.ships.forEach(function (sh, k) {
      if (sh.sunk) return;
      if (!sh.moved) {
        var mv = shipMoves(s, k);
        Object.keys(mv).forEach(function (t) { out.push({ type: "move", ship: k, to: +t, path: mv[t] }); });
      }
      if (!sh.acted) {
        abilityTargets(s, k).forEach(function (tg) {
          if (sh.ability === "ping") out.push({ type: "ping", ship: k });
          else if (sh.ability === "harpoon") out.push({ type: "harpoon", ship: k, target: tg });
          else if (sh.ability === "net") out.push({ type: "net", ship: k, target: tg });
          else if (sh.ability === "beam") out.push({ type: "beam", ship: k, dir: tg });
        });
      }
    });
    return out;
  }

  function scoreOrder(s, B, o) {
    var after = s.orders - 1;
    var sh = s.ships[o.ship];
    var known = s.revealedAt >= 0;
    if (o.type === "harpoon") {
      var p = (B.w[o.target] || 0) / B.total;
      return 100 * p;
    }
    if (o.type === "ping") {
      if (known) return -1;
      var sp = splitValue(s, B, disk(sh.pos, CFG.sonarRange), after);
      return 100 * sp.gain + 9 * sp.info;
    }
    if (o.type === "beam") {
      if (known) return -1;
      var sb = splitValue(s, B, beamTiles(s, sh.pos, o.dir), after);
      return 100 * sb.gain + 9 * sb.info;
    }
    if (o.type === "net") {
      var ring = netTiles(s, sh.pos);
      if (known) return ring.indexOf(s.revealedAt) >= 0 && !s.monster.snagged ? 6 : -1;
      var sn = splitValue(s, B, ring, after);
      var pn = 0;
      ring.forEach(function (t) { pn += B.w[t] || 0; });
      return 100 * sn.gain + 9 * sn.info + 25 * pn / B.total;
    }
    if (o.type === "move") {
      var before = posValue(s, B, o.ship, sh.pos);
      var oldPos = sh.pos;
      sh.pos = o.to;
      var afterV = posValue(s, B, o.ship, o.to);
      var gainNow = 0;
      if (sh.id === "harpoon" && !sh.acted && after >= 1) {
        var mark = new Uint8Array(N);
        harpoonRing(s, o.to).forEach(function (t) { mark[t] = 1; });
        gainNow = bestShot(s.P, B.w, B.total, mark);
        var markOld = new Uint8Array(N);
        harpoonRing(s, oldPos).forEach(function (t) { markOld[t] = 1; });
        gainNow -= bestShot(s.P, B.w, B.total, markOld);
      }
      sh.pos = oldPos;
      if (sh.id === "harpoon") {
        var ram = (o.path || [o.to]).reduce(function (a, t4) { return a + (B.w[t4] || 0); }, 0) / B.total;
        if (ram > 0) return 100 * ram + 40 * (afterV - before);
      }
      var sweep = 0;
      (o.path || [o.to]).forEach(function (t3) { sweep += (B.w[t3] || 0) / B.total; });
      return 100 * Math.max(0, gainNow) + 40 * (afterV - before) + 25 * sweep;
    }
    return 0;
  }

  function sloppyP(s) {
    if (s.revealedAt >= 0 || s.P.length > 40) return s.P;
    return expandPublic(s, s.P);
  }

  function hunterOrder(s, level, rand) {
    var L = LEVELS[level] || LEVELS.normal;
    if (s.orders < 1) return { type: "end" };
    var view = s;
    if (L.track === "sloppy") { view = clone(s); view.P = sloppyP(s); }
    var B = beliefWeights(view, level);
    var cands = candidateOrders(view);
    if (!cands.length) return { type: "end" };
    var scored = cands.map(function (o) {
      var v = scoreOrder(view, B, o);
      return { o: o, v: v + (rand() - 0.5) * 20 * L.noise };
    });
    if (L.lookahead) {
      scored.sort(function (a, b) { return b.v - a.v; });
      var top = scored.slice(0, 10);
      top.forEach(function (c) { c.v += 0.6 * lookaheadValue(view, B, c.o, level); });
    }
    scored.sort(function (a, b) { return b.v - a.v; });
    if (L.mistakes && rand() < L.mistakes) {
      var alt = scored.slice(0, Math.min(5, scored.length));
      return pick(rand, alt).o;
    }
    if (scored[0].v < 0.5 && scored[0].o.type !== "harpoon") {
      var mv = scored.filter(function (c) { return c.o.type === "move"; })[0];
      if (!mv || mv.v < 0.2) return { type: "end" };
      return mv.o;
    }
    return scored[0].o;
  }

  function lookaheadValue(s, B, o, level) {
    if (s.orders < 2) return 0;
    if (o.type === "move") {
      var s2 = clone(s);
      var sh = s2.ships[o.ship];
      sh.pos = o.to; sh.moved = true; s2.orders -= 1;
      s2.P = removeTiles(s2.P, o.path || [o.to]);
      var B2 = beliefWeights(s2, level);
      var best = 0;
      candidateOrders(s2).forEach(function (o2) { if (o2.type !== "move") best = Math.max(best, scoreOrder(s2, B2, o2)); });
      return best;
    }
    if (o.type === "ping" || o.type === "beam" || o.type === "net") {
      var region = o.type === "ping" ? disk(s.ships[o.ship].pos, CFG.sonarRange) : o.type === "net" ? netTiles(s, s.ships[o.ship].pos) : beamTiles(s, s.ships[o.ship].pos, o.dir);
      var mark = new Uint8Array(N);
      region.forEach(function (t) { mark[t] = 1; });
      var mi = 0;
      s.P.forEach(function (t) { if (mark[t]) mi += B.w[t]; });
      var pin = mi / B.total;
      var total = 0;
      [true, false].forEach(function (inside) {
        var pr = inside ? pin : 1 - pin;
        if (pr <= 0) return;
        var s3 = clone(s);
        s3.ships[o.ship].acted = true; s3.orders -= 1;
        s3.P = inside ? keepTiles(s.P, region) : removeTiles(s.P, region);
        if (!s3.P.length) return;
        var B3 = beliefWeights(s3, level);
        var best = 0;
        candidateOrders(s3).forEach(function (o2) { if (o2.type === "harpoon" || o2.type === "move") best = Math.max(best, scoreOrder(s3, B3, o2)); });
        total += pr * best;
      });
      return total;
    }
    return 0;
  }

  /* Leviathan bot */
  function harpoonThreatMark(s) {
    var h = s.ships[1], mark = new Uint8Array(N);
    if (h.sunk) return mark;
    var spots = [h.pos];
    var mv = shipMovesRaw(Object.assign({}, s, { revealedAt: -1 }), 1);
    Object.keys(mv).forEach(function (t) { spots.push(+t); });
    spots.forEach(function (p) {
      for (var t = 0; t < N; t++) { var d = dist(p, t); if ((p === h.pos && d === 1) || (d >= CFG.harpoonMin && d <= CFG.harpoonRange)) mark[t] = 1; }
    });
    return mark;
  }

  function monsterStart(s, level, rand) {
    var L = LEVELS[level] || LEVELS.normal;
    var zone = startZone(s).filter(function (t) { return s.terrain[t] !== ISLAND; });
    if (level === "easy") return pick(rand, zone);
    var best = null, bv = -1e9;
    zone.forEach(function (t) {
      var v = 0;
      s.buoys.forEach(function (b) { v -= 0.35 * Math.min(6, dist(b.pos, t)); });
      v += 0.2 * dist(s.ships[1].pos, t);
      if (s.terrain[t] === REEF) v += 0.5;
      v += (rand() - 0.5) * 3 * (L.noise + 0.4);
      if (v > bv) { bv = v; best = t; }
    });
    return best;
  }

  /* How likely is a harpoon hit next turn if the Leviathan does this? Plays the
     hunters' Normal bot against the real position a few times to find out. */
  function simulateExposure(s, act, sims, rand, hunterLevel) {
    var hits = 0;
    for (var k = 0; k < sims; k++) {
      var c = clone(s);
      applyMonster(c, act);
      if (c.winner) return c.winner === "monster" ? -1 : 1;
      var n = 0;
      while (!c.winner && c.orders > 0 && n++ < 4) {
        var o = hunterOrder(c, hunterLevel || "normal", rand);
        if (o.type === "end") break;
        var ev = applyHunter(c, o);
        if (ev.some(function (e) { return (e.t === "harpoon" && e.hit) || e.t === "ram"; })) { hits++; break; }
      }
    }
    return hits / sims;
  }

  function monsterMove(s, level, rand) {
    var L = LEVELS[level] || LEVELS.normal;
    var opts = monsterOptions(s);
    var threat = harpoonThreatMark(s);
    var m = s.monster;
    var surfacing = s.round % CFG.surfaceEvery === 0;
    var nextSurface = (s.round + 1) % CFG.surfaceEvery === 0;
    var woundsLeft = CFG.woundsToWin - m.wounds;
    var killsLeft = CFG.killsToWin - m.kills;
    var roundsLeft = Math.max(1, CFG.roundLimit - s.round + 1);
    var urgency = Math.min(1.5, killsLeft / roundsLeft * 2.2);
    var greed = L.greed * (1 + 1.6 * urgency);
    var caution = L.caution * Math.max(0.35, 1 - 0.45 * urgency);
    var woundCost = woundsLeft <= 1 ? 6 : 2.2;
    var h = s.ships[1];
    var safeBuoys = s.buoys.filter(function (b) { return b.alive && (h.sunk || dist(h.pos, b.pos) >= 5); });
    var scored = opts.map(function (o) {
      var pos = o.type === "strike" ? m.pos : o.to;
      var revealed = surfacing;
      var gain = 0, Pafter;
      if (o.type === "strike") {
        revealed = true;
        var sh = s.ships[o.ship];
        var sinks = sh.hp <= 1;
        gain += sinks ? 1 : 0.45;
        if (sinks && sh.id === "harpoon") gain += 50;
        if (sinks && killsLeft <= 1) gain += 50;
      } else if (buoyAt(s, o.to)) {
        revealed = true;
        gain += 1;
        if (killsLeft <= 1) gain += 50;
      }
      if (revealed) Pafter = [pos];
      else if (o.type === "dash") Pafter = reach2(s, m.pos);
      else Pafter = expandPublic(s, s.P);
      var inReach = !h.sunk && threat[pos];
      var exposed = 0;
      if (inReach) {
        var cnt = 0;
        Pafter.forEach(function (t) { if (threat[t]) cnt++; });
        exposed = revealed ? 0.92 : Math.min(0.9, 2.2 / Math.max(1, cnt));
      } else if (revealed && !h.sunk) {
        exposed = dist(h.pos, pos) <= 6 ? 0.12 : 0.03;
      }
      var base = greed * 2.2 * gain;
      var dh = h.sunk ? 8 : dist(h.pos, pos);
      base += 0.09 * Math.min(dh, 7);
      var nb = 99;
      s.buoys.forEach(function (b) { if (b.alive && b.pos !== pos) nb = Math.min(nb, dist(b.pos, pos)); });
      if (nb < 99) base += (0.12 + 0.25 * urgency) * (6 - Math.min(6, nb));
      if (L.lookahead || level === "normal") {
        var ns = 99;
        safeBuoys.forEach(function (b) { if (b.pos !== pos) ns = Math.min(ns, dist(b.pos, pos)); });
        if (ns < 99) base += 0.22 * (6 - Math.min(6, ns));
      }
      base += 0.12 * Math.log(1 + Pafter.length);
      if (s.terrain[pos] === REEF) base += 0.08;
      if (nextSurface && !h.sunk) base += 0.06 * Math.min(dh, 8);
      s.ships.forEach(function (o2) {
        if (o2.sunk) return;
        if (dist(o2.pos, pos) === 1 && o2.id !== "harpoon" && dist(h.pos, pos) > 5) base += 0.1;
      });
      if (o.type === "dash" && !revealed && s.revealedAt < 0 && s.P.length > 14) base -= 0.25;
      return { o: o, base: base, exposed: exposed, v: base - caution * woundCost * exposed + (rand() - 0.5) * 1.2 * L.noise };
    });
    scored.sort(function (a, b) { return b.v - a.v; });
    if (level !== "easy" && !h.sunk) {
      var K = L.lookahead ? 10 : 5, sims = L.lookahead ? 3 : 1;
      var top = scored.slice(0, K);
      top.forEach(function (c) {
        var e = simulateExposure(s, c.o, sims, rand, L.lookahead ? "hard" : "normal");
        if (e < 0) { c.v = 1e6; return; }
        var blended = L.lookahead ? 0.75 * e + 0.25 * c.exposed : 0.5 * e + 0.5 * c.exposed;
        c.v = c.base - caution * woundCost * blended + (rand() - 0.5) * 1.2 * L.noise;
      });
      top.sort(function (a, b) { return b.v - a.v; });
      scored = top.concat(scored.slice(K));
    }
    if (L.mistakes && rand() < L.mistakes) return pick(rand, scored.slice(0, Math.min(4, scored.length))).o;
    return scored[0].o;
  }

  var API = {
    COLS: COLS, ROWS: ROWS, N: N, SEA: SEA, REEF: REEF, ISLAND: ISLAND, CFG: CFG, SHIP_DEFS: SHIP_DEFS,
    cOf: cOf, rOf: rOf, NEI: NEI, DIRN: DIRN, dist: dist, disk: disk, rng: rng,
    newGame: newGame, clone: clone, startZone: startZone, setMonsterStart: setMonsterStart,
    monsterOptions: monsterOptions, applyMonster: applyMonster, shipMoves: shipMoves, shipMovesRaw: shipMovesRaw, abilityTargets: abilityTargets,
    beamTiles: beamTiles, applyHunter: applyHunter, endHunterTurn: endHunterTurn, hasAnyOrder: hasAnyOrder,
    shipAt: shipAt, buoyAt: buoyAt, netAt: netAt, reach2: reach2, expandPublic: expandPublic, netTiles: netTiles, harpoonRing: harpoonRing,
    bots: { hunterOrder: hunterOrder, monsterMove: monsterMove, monsterStart: monsterStart }, LEVELS: LEVELS
  };
  root.Leviathan = API;
  if (typeof module !== "undefined" && module.exports) module.exports = API;
})(typeof window !== "undefined" ? window : globalThis);
