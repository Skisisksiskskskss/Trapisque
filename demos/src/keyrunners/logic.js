/* Keyrunners: rules engine and bot. No DOM, so it runs in Node for tests.
   Side 0 (Blue) plays from the bottom (home rows 8-9), side 1 (Red) from the top (home rows 0-1).
   Key k belongs to side k and opens the other side's safe. A side wins at the start of its turn if
   its own key is on or next to the enemy safe (crack) or the enemy's key is on its own safe (stash).
   The board is 9 wide in each side's two home rows and 7 wide between them, with pits in the
   middle. Units can't stand on pits, but keys fly over them. */
(function (root) {
  "use strict";

  var W = 9, H = 10, N = W * H;
  var CFG = {
    firstIncome: 5, income: 5, cap: 10, debt: 3, maxCrew: 6, rounds: 30,
    moveCost: 1, throwCost: 2, burnCost: 1, passRange: 1, throwRange: 3, hookRange: 4,
    stashTo: "safe", crackRange: 1, heavyOwn: true
  };
  var BACK = [9, 0];
  var FWD = [-1, 1];
  var NAMES = ["Blue", "Red"];

  function idx(c, r) { return r * W + c; }
  function cOf(i) { return i % W; }
  function rOf(i) { return (i / W) | 0; }
  function cheb(a, b) { return Math.max(Math.abs(cOf(a) - cOf(b)), Math.abs(rOf(a) - rOf(b))); }
  function inB(c, r) { return c >= 0 && c < W && r >= 0 && r < H; }

  var SAFE = [idx(4, 9), idx(4, 0)];
  /* FLOOR: tiles units can stand on. Columns 0 and 8 only exist in the home rows; PIT tiles are holes. */
  var PITS = [[2, 3], [6, 3], [4, 4], [4, 5], [2, 6], [6, 6]];
  var FLOOR = new Uint8Array(N), IS_PIT = new Uint8Array(N);
  for (var ft = 0; ft < N; ft++) { var fr = (ft / W) | 0, fc = ft % W; FLOOR[ft] = (fr <= 1 || fr >= H - 2 || (fc >= 1 && fc <= W - 2)) ? 1 : 0; }
  PITS.forEach(function (pp) { var t = pp[1] * W + pp[0]; FLOOR[t] = 0; IS_PIT[t] = 1; });
  var HOME_ROWS = [[8, 9], [0, 1]];
  var IS_SAFE = new Uint8Array(N);
  IS_SAFE[SAFE[0]] = 1; IS_SAFE[SAFE[1]] = 1;
  var IS_HOME = [new Uint8Array(N), new Uint8Array(N)];
  for (var hs = 0; hs < 2; hs++) HOME_ROWS[hs].forEach(function (r) { for (var c = 0; c < W; c++) if (FLOOR[idx(c, r)]) IS_HOME[hs][idx(c, r)] = 1; });

  var D8 = [[0, -1], [1, 0], [0, 1], [-1, 0], [1, -1], [1, 1], [-1, 1], [-1, -1]];
  var KNIGHT = [[1, 2], [2, 1], [-1, 2], [-2, 1], [1, -2], [2, -1], [-1, -2], [-2, -1]];
  var NB = [], RAY = [], KNT = [];
  for (var i0 = 0; i0 < N; i0++) {
    var c0 = cOf(i0), r0 = rOf(i0), nb = [], rays = [], kn = [];
    for (var d0 = 0; d0 < 8; d0++) {
      var ray = [], cc = c0 + D8[d0][0], rr = r0 + D8[d0][1];
      while (inB(cc, rr)) { ray.push(idx(cc, rr)); cc += D8[d0][0]; rr += D8[d0][1]; }
      rays.push(ray);
      if (ray.length && FLOOR[ray[0]]) nb.push(ray[0]);
      var kc = c0 + KNIGHT[d0][0], kr = r0 + KNIGHT[d0][1];
      if (inB(kc, kr) && FLOOR[idx(kc, kr)]) kn.push(idx(kc, kr));
    }
    NB.push(nb); RAY.push(rays); KNT.push(kn);
  }

  /* ---------- Cards ---------- */
  var TYPES = {
    boss: { name: "The Boss", ps: "Can't be captured with 2+ crew next to it.", as: "A crew that moved may move again.", leader: true, move: "step", passive: "untouchable", pname: "Untouchable", ptext: "Can't be captured while 2 or more of your crew stand next to it.",
      ab: "orders", aname: "Orders", ac: 2, atext: "One of your crew that already moved this turn may move again." },
    fixer: { name: "The Fixer", ps: "+1 mana every turn.", as: "Deploy next to any of your crew this turn.", leader: true, move: "step", passive: "connected", pname: "Connected", ptext: "You get +1 mana every turn.",
      ab: "insideman", aname: "Inside Man", ac: 1, atext: "This turn you may deploy next to any of your crew, not just Hideouts." },
    ghost: { name: "The Ghost", ps: "Moves 2 tiles any way, even with a key.", as: "Swap with one of your crew up to 3 away.", leader: true, move: "king2", carrier: true, passive: "phantom", pname: "Phantom", ptext: "Moves up to 2 tiles in any direction, even carrying a key.",
      ab: "vanish", aname: "Vanish", ac: 2, atext: "Swap places with one of your crew up to 3 tiles away." },

    wobbler: { name: "Wobbler", ps: "Moves 1 tile in any direction.", as: "Hand your key to a teammate next to you.", cost: 1, move: "step", passive: "wobbly", pname: "Wobbly", ptext: "Moves 1 tile in any direction.",
      ab: "handoff", aname: "Pass", ac: 1, atext: "Hand your key to a teammate right next to it. Nothing can intercept it." },
    greaser: { name: "Greaser", ps: "Moves any distance diagonally.", as: "If attacked with a key, it flies to the nearest teammate.", cost: 2, move: "bishop", passive: "greased", pname: "Slick Moves", ptext: "Moves any distance diagonally, like a chess bishop. One diagonal step while carrying a key.",
      ab: "slip", aname: "Slippery", ac: 1, atext: "Until your next turn, if anyone captures it, takes it out or grabs its key, the key flies to your nearest teammate instead." },
    lookout: { name: "Lookout", ps: "You can deploy next to it.", as: "Run up to 3 straight. No captures.", cost: 1, move: "step", passive: "hideout", pname: "Hideout", ptext: "You can deploy crew next to it.",
      ab: "dash", aname: "Dash", ac: 1, atext: "Run up to 3 tiles in a straight line. No captures, and not while carrying a key." },
    decoy: { name: "Decoy", ps: "Whoever captures it is stunned.", as: "Swap with an ally up to 2 away.", cost: 1, move: "step", passive: "bait", pname: "Bait", ptext: "Whoever captures it is stunned on their next turn.",
      ab: "switch", aname: "Switch", ac: 1, atext: "Swap places with an ally up to 2 tiles away." },
    runner: { name: "Runner", ps: "Moves up to 3 straight, even with a key.", as: "Step 1 tile left or right.", cost: 2, move: "rook3", carrier: true, passive: "breakaway", pname: "Breakaway", ptext: "Moves up to 3 tiles straight (no diagonals), even carrying a key.",
      ab: "juke", aname: "Juke", ac: 1, atext: "Step 1 tile left or right." },
    catcher: { name: "Catcher", ps: "Catches throws near it, even enemy ones.", as: "Take the key from an ally up to 3 away.", cost: 2, move: "step", passive: "softhands", pname: "Soft Hands", ptext: "Catches your throws that land next to it and steals enemy throws that fly next to it. Can still move after a catch.",
      ab: "call", aname: "Call for It", ac: 1, atext: "Take the key from an ally up to 3 tiles away." },
    pickpocket: { name: "Pickpocket", ps: "Moves up to 2 tiles any way.", as: "Take the key from an enemy next to it.", cost: 2, move: "king2", passive: "nimble", pname: "Nimble", ptext: "Moves up to 2 tiles in any direction.",
      ab: "swipe", aname: "Swipe", ac: 2, atext: "Take the key from an enemy next to it." },
    acrobat: { name: "Acrobat", ps: "Moves in an L, jumping over units.", as: "Jump a unit next to it. Stuns an enemy.", cost: 2, move: "knight", passive: "leaper", pname: "Leaper", ptext: "Moves in an L like a chess knight, jumping over anything.",
      ab: "vault", aname: "Vault", ac: 1, atext: "Jump over a unit next to it. An enemy jumped over is stunned. Not while carrying a key." },
    guard: { name: "Guard", ps: "Enemy key carriers can't stop next to it.", as: "Can't be captured until your next turn.", cost: 2, move: "step", passive: "watchful", pname: "Watchful", ptext: "Enemies carrying a key can't stop next to it.",
      ab: "brace", aname: "Brace", ac: 1, atext: "Can't be captured until your next turn." },
    brute: { name: "Brute", ps: "Survives the first hit.", as: "Push an enemy 2 tiles. Stuns it if it hits something.", cost: 3, move: "step", passive: "armored", pname: "Armored", ptext: "Survives the first time it would be captured or taken out.",
      ab: "shove", aname: "Shove", ac: 2, atext: "Push an enemy next to it 2 tiles away. If it hits something, it's stunned." },
    sniper: { name: "Sniper", ps: "Can't capture by moving.", as: "Take out an enemy 2-3 tiles away in a clear line.", cost: 3, move: "step", passive: "scope", pname: "Scope", ptext: "Can't capture by moving.",
      ab: "longshot", aname: "Long Shot", ac: 3, atext: "Take out an enemy 2 or 3 tiles away in a clear straight line. Its key drops." },
    bodyguard: { name: "Bodyguard", ps: "Your units next to it can't be captured.", as: "Jump next to an ally up to 3 away.", cost: 3, move: "step", passive: "shield", pname: "Shield", ptext: "Your units next to it can't be captured.",
      ab: "rushin", aname: "Rush In", ac: 1, atext: "Jump next to an ally up to 3 tiles away. Not while carrying a key." },
    hacker: { name: "Hacker", ps: "Your units within 2 ignore enemy gadgets.", as: "An enemy within 3 loses its passive and abilities.", cost: 3, move: "step", passive: "firewall", pname: "Firewall", ptext: "Your units within 2 tiles of it ignore enemy gadgets.",
      ab: "glitch", aname: "Glitch", ac: 2, atext: "An enemy up to 3 tiles away loses its passive and can't use abilities until your next turn." },
    driver: { name: "Getaway Driver", ps: "Moves 3 straight. You can deploy next to it.", as: "Move again after it moves.", cost: 4, move: "rook3", passive: "van", pname: "Getaway Van", ptext: "Moves up to 3 tiles straight. You can deploy crew next to it.",
      ab: "floorit", aname: "Floor It", ac: 2, atext: "After it moves, move it again. Not while carrying a key." }
  };
  var GADGETS = {
    smoke: { name: "Smoke Bomb", cost: 2, text: "No one in a 3×3 area can be captured until your next turn." },
    hook: { name: "Grappling Hook", cost: 2, text: "One of your units zips up to 4 tiles in a straight line, even carrying a key or after moving." },
    tripwire: { name: "Tripwire", cost: 1, text: "Hide a trap on an empty tile outside the enemy home rows. The first enemy to land on it is taken out." },
    emp: { name: "EMP", cost: 2, text: "Stun every enemy in a 3×3 area." },
    alarm: { name: "Alarm", cost: 1, text: "Push every enemy within 2 tiles of your safe 1 tile away from it." },
    bribe: { name: "Bribe", cost: 4, text: "An enemy crew member next to your leader joins your side, keys and all." }
  };
  var LEADERS = ["boss", "fixer", "ghost"];
  var CREW = ["wobbler", "greaser", "lookout", "decoy", "runner", "catcher", "pickpocket", "acrobat", "guard", "brute", "sniper", "bodyguard", "hacker", "driver"];
  var GADGET_LIST = ["smoke", "hook", "tripwire", "emp", "alarm", "bribe"];
  var PRESETS = [
    { id: "runners", name: "Runners", note: "Fast relays and a phantom leader.", leader: "ghost", crew: ["runner", "catcher", "wobbler", "acrobat", "greaser", "bodyguard"], gadgets: ["hook", "smoke"] },
    { id: "fortress", name: "Fortress", note: "Hold the line, then punish.", leader: "boss", crew: ["guard", "brute", "bodyguard", "sniper", "wobbler", "catcher"], gadgets: ["alarm", "emp"] },
    { id: "tricksters", name: "Tricksters", note: "Forward spawns, traps and bribes.", leader: "fixer", crew: ["lookout", "driver", "hacker", "pickpocket", "greaser", "decoy"], gadgets: ["tripwire", "bribe"] },
    { id: "allround", name: "All-rounders", note: "A bit of everything.", leader: "boss", crew: ["wobbler", "runner", "catcher", "guard", "sniper", "lookout"], gadgets: ["smoke", "emp"] }
  ];

  function validDeck(d) {
    if (!d || LEADERS.indexOf(d.leader) < 0) return false;
    if (!d.crew || d.crew.length !== 6 || !d.gadgets || d.gadgets.length !== 2) return false;
    var seen = {};
    for (var i = 0; i < 6; i++) { if (CREW.indexOf(d.crew[i]) < 0 || seen[d.crew[i]]) return false; seen[d.crew[i]] = 1; }
    if (GADGET_LIST.indexOf(d.gadgets[0]) < 0 || GADGET_LIST.indexOf(d.gadgets[1]) < 0 || d.gadgets[0] === d.gadgets[1]) return false;
    return true;
  }

  /* ---------- Seeded random ---------- */
  function rng(seed) {
    var a = (seed >>> 0) || 0x9e3779b9;
    return function () {
      a |= 0; a = (a + 0x6D2B79F5) | 0;
      var t = Math.imul(a ^ (a >>> 15), 1 | a);
      t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
      return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
    };
  }
  function rnd(st) {
    st.seed = (st.seed + 0x6D2B79F5) | 0;
    var t = Math.imul(st.seed ^ (st.seed >>> 15), 1 | st.seed);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  }
  function shuffle(arr, f) {
    for (var i = arr.length - 1; i > 0; i--) { var j = Math.floor(f() * (i + 1)); var t = arr[i]; arr[i] = arr[j]; arr[j] = t; }
    return arr;
  }
  function randomDeck(f) {
    var crew = shuffle(CREW.slice(), f).slice(0, 6), gad = shuffle(GADGET_LIST.slice(), f).slice(0, 2);
    return { leader: LEADERS[Math.floor(f() * LEADERS.length)], crew: crew, gadgets: gad };
  }

  /* ---------- State helpers ---------- */
  var NOEV = { push: function () {} };
  function mkStats() { return { caps: 0, steals: 0, deploys: 0, passes: 0, throws: 0, gadgets: 0, kos: 0 }; }

  function unit(st, id) {
    var us = st.units;
    for (var i = 0; i < us.length; i++) if (us[i].id === id) return us[i];
    return null;
  }
  function at(st, t) { var id = st.board[t]; return id < 0 ? null : unit(st, id); }
  function holds(st, u) { return st.keys[0].h === u.id || st.keys[1].h === u.id; }
  function keysOf(st, u) { var o = []; if (st.keys[0].h === u.id) o.push(0); if (st.keys[1].h === u.id) o.push(1); return o; }
  /* Keys u may pass or throw right now: only its own side's key, and not on a turn that key changed hands. */
  function looseKeys(st, u) {
    var K = st.keys[u.side];
    return K.h === u.id && K.lk !== st.ply ? [u.side] : [];
  }
  function stunned(st, u) { return st.ply < u.st; }
  function glitched(st, u) { return st.ply < u.gl; }
  function braced(st, u) { return st.ply < u.br; }
  function slippery(st, u) { return st.ply < (u.sl || 0); }
  function passiveOn(st, u, p) { return TYPES[u.type].passive === p && !glitched(st, u); }
  function inSmoke(st, t) {
    for (var i = 0; i < st.smokes.length; i++) { var s = st.smokes[i]; if (st.ply < s.until && cheb(s.c, t) <= 1) return true; }
    return false;
  }
  function immune(st, u) {
    var us = st.units;
    for (var i = 0; i < us.length; i++) { var b = us[i]; if (b.side === u.side && b.type === "hacker" && !glitched(st, b) && cheb(b.pos, u.pos) <= 2) return true; }
    return false;
  }
  function crewCount(st, s) { var n = 0; for (var i = 0; i < st.units.length; i++) if (st.units[i].side === s && !st.units[i].leader) n++; return n; }
  function leaderOf(st, s) { for (var i = 0; i < st.units.length; i++) if (st.units[i].side === s && st.units[i].leader) return st.units[i]; return null; }
  function afford(st, cost) { return st.mana[st.side] - cost >= -CFG.debt; }
  function canMove(st, u) { return u.side === st.side && u.mv !== st.ply && u.fr !== st.ply && !stunned(st, u); }
  function canAct(st, u) { return u.side === st.side && u.ac !== st.ply && u.fr !== st.ply && !stunned(st, u) && !glitched(st, u); }
  function canHandle(st, u) { return u.side === st.side && !stunned(st, u); }
  function round(st) { return Math.ceil(st.ply / 2); }

  function stun(st, u, ev) {
    var until = st.ply + (u.side === st.side ? 3 : 2);
    if (u.st < until) u.st = until;
    ev.push({ e: "stun", u: u.id, at: u.pos });
  }

  /* Watchful: is tile t next to a Guard that opposes unit u? */
  function watched(st, u, t, ignoreId) {
    var us = st.units;
    for (var i = 0; i < us.length; i++) {
      var g = us[i];
      if (g.side !== u.side && g.type === "guard" && g.id !== ignoreId && !glitched(st, g) && cheb(g.pos, t) === 1) return true;
    }
    return false;
  }

  /* Nobody stands on their own safe, except a unit bringing the enemy's stolen key home. */
  function home(st, u) { return CFG.stashTo === "safe" ? SAFE[u.side] : -1; }
  function canEnter(st, u, t) { return t !== SAFE[u.side] || st.keys[1 - u.side].h === u.id; }
  function stashed(st, s, u) { return CFG.stashTo === "safe" ? u.pos === SAFE[s] : rOf(u.pos) === BACK[s]; }

  function canCapture(st, a, o) {
    if (o.side === a.side) return false;
    if (passiveOn(st, a, "scope")) return false;
    if (braced(st, o) || inSmoke(st, o.pos)) return false;
    var us = st.units, adjCrew = 0;
    for (var i = 0; i < us.length; i++) {
      var b = us[i];
      if (b.side !== o.side || b === o || cheb(b.pos, o.pos) !== 1) continue;
      if (b.type === "bodyguard" && !glitched(st, b)) return false;
      if (!b.leader) adjCrew++;
    }
    if (o.type === "boss" && !glitched(st, o) && adjCrew >= 2) return false;
    return true;
  }

  function pattern(st, u) {
    var T = TYPES[u.type];
    if (glitched(st, u)) return "step";
    if (!T.carrier && (st.keys[1 - u.side].h === u.id || (CFG.heavyOwn && st.keys[u.side].h === u.id))) return T.move === "bishop" ? "diag1" : "step";
    return T.move;
  }

  /* Tiles unit u may move to this turn (empty tiles and capturable enemies).
     With `clear`, its own side's units don't block the way (they could step aside first). */
  function moveTargets(st, u, ignoreFlags, clear) {
    var out = [];
    if (!ignoreFlags && !canMove(st, u)) return out;
    var pat = pattern(st, u), keyed = holds(st, u), b = st.board, p = u.pos;
    function consider(t) {
      var oid = b[t];
      if (oid >= 0) {
        var o = unit(st, oid);
        if (o.side !== u.side && canCapture(st, u, o) && !(keyed && watched(st, u, t, oid))) out.push(t);
        return;
      }
      if (!canEnter(st, u, t) || (keyed && watched(st, u, t, -1))) return;
      out.push(t);
    }
    function blocks(t) { var oid = b[t]; return oid >= 0 && !(clear && unit(st, oid).side === u.side); }
    var j, t, d, ray;
    if (pat === "step") { for (j = 0; j < NB[p].length; j++) consider(NB[p][j]); }
    else if (pat === "knight") { for (j = 0; j < KNT[p].length; j++) consider(KNT[p][j]); }
    else if (pat === "diag1") { for (d = 4; d < 8; d++) { ray = RAY[p][d]; if (ray.length && FLOOR[ray[0]]) consider(ray[0]); } }
    else if (pat === "rook3" || pat === "bishop") {
      var d0 = pat === "rook3" ? 0 : 4, len = pat === "rook3" ? 3 : 99;
      for (d = d0; d < d0 + 4; d++) {
        ray = RAY[p][d];
        for (j = 0; j < len && j < ray.length; j++) { t = ray[j]; if (!FLOOR[t]) break; consider(t); if (blocks(t)) break; }
      }
    } else if (pat === "king2") {
      var seen = {};
      for (j = 0; j < NB[p].length; j++) {
        var n1 = NB[p][j];
        if (!seen[n1]) { seen[n1] = 1; consider(n1); }
        if (blocks(n1)) continue;
        for (var q = 0; q < NB[n1].length; q++) { var n2 = NB[n1][q]; if (n2 !== p && !seen[n2]) { seen[n2] = 1; consider(n2); } }
      }
    }
    return out;
  }

  /* Every tile a unit could land on if an enemy stood there (for threat and coverage maps). */
  function reach(st, u, out) {
    var pat = pattern(st, u), b = st.board, p = u.pos, j, d, ray;
    if (pat === "step") { for (j = 0; j < NB[p].length; j++) out[NB[p][j]]++; }
    else if (pat === "knight") { for (j = 0; j < KNT[p].length; j++) out[KNT[p][j]]++; }
    else if (pat === "diag1") { for (d = 4; d < 8; d++) { ray = RAY[p][d]; if (ray.length && FLOOR[ray[0]]) out[ray[0]]++; } }
    else if (pat === "rook3" || pat === "bishop") {
      var d0 = pat === "rook3" ? 0 : 4, len = pat === "rook3" ? 3 : 99;
      for (d = d0; d < d0 + 4; d++) { ray = RAY[p][d]; for (j = 0; j < len && j < ray.length; j++) { if (!FLOOR[ray[j]]) break; out[ray[j]]++; if (b[ray[j]] >= 0) break; } }
    } else {
      var seen = {};
      for (j = 0; j < NB[p].length; j++) {
        var n1 = NB[p][j];
        if (!seen[n1]) { seen[n1] = 1; out[n1]++; }
        if (b[n1] >= 0) continue;
        for (var q = 0; q < NB[n1].length; q++) { var n2 = NB[n1][q]; if (n2 !== p && !seen[n2]) { seen[n2] = 1; out[n2]++; } }
      }
    }
  }


  /* Where a throw from u's tile in direction d over dist tiles ends up. */
  function throwResolve(st, u, d, dist) {
    var ray = RAY[u.pos][d];
    if (ray.length < dist) return null;
    if (!FLOOR[ray[dist - 1]]) return null;
    for (var j = 0; j < dist; j++) {
      var t = ray[j];
      if (!FLOOR[t]) continue;
      if (st.board[t] >= 0) return { to: ray[dist - 1], path: ray.slice(0, j + 1), by: st.board[t], at: t };
      for (var i = 0; i < st.units.length; i++) {
        var c = st.units[i];
        if (c.side !== u.side && c.type === "catcher" && !glitched(st, c) && cheb(c.pos, t) === 1)
          return { to: ray[dist - 1], path: ray.slice(0, j + 1), by: c.id, at: t, picked: true };
      }
    }
    var land = ray[dist - 1];
    for (var k = 0; k < st.units.length; k++) {
      var f = st.units[k];
      if (f !== u && f.side === u.side && f.type === "catcher" && !glitched(st, f) && cheb(f.pos, land) === 1)
        return { to: land, path: ray.slice(0, dist), by: f.id, at: land, picked: true };
    }
    return { to: land, path: ray.slice(0, dist), by: -1, at: land };
  }
  function throwOptions(st, u) {
    var out = [];
    if (!canHandle(st, u) || !looseKeys(st, u).length) return out;
    for (var d = 0; d < 8; d++) for (var dist = 1; dist <= CFG.throwRange; dist++) {
      if (RAY[u.pos][d].length < dist) break;
      var res = throwResolve(st, u, d, dist);
      if (!res) continue;
      res.d = d; res.dist = dist;
      out.push(res);
    }
    return out;
  }
  function findThrow(st, u, to) {
    for (var d = 0; d < 8; d++) { var ray = RAY[u.pos][d]; for (var j = 0; j < CFG.throwRange && j < ray.length; j++) if (ray[j] === to) return throwResolve(st, u, d, j + 1); }
    return null;
  }

  function swapOk(st, a, b) {
    if (!canEnter(st, a, b.pos) || !canEnter(st, b, a.pos)) return false;
    if (holds(st, a) && watched(st, a, b.pos, -1)) return false;
    if (holds(st, b) && watched(st, b, a.pos, -1)) return false;
    return true;
  }

  function abilityTargets(st, u) {
    var out = [];
    if (!canAct(st, u)) return out;
    var T = TYPES[u.type], p = u.pos, b = st.board, us = st.units, d, j, t, o, i, ray;
    switch (T.ab) {
      case "dash":
        if (holds(st, u)) break;
        for (d = 0; d < 8; d++) { ray = RAY[p][d]; for (j = 0; j < 3 && j < ray.length; j++) { t = ray[j]; if (!FLOOR[t] || b[t] >= 0) break; if (canEnter(st, u, t)) out.push(t); } }
        break;
      case "switch":
        for (i = 0; i < us.length; i++) { o = us[i]; if (o !== u && o.side === u.side && cheb(o.pos, p) <= 2 && swapOk(st, u, o)) out.push(o.pos); }
        break;
      case "vanish":
        for (i = 0; i < us.length; i++) { o = us[i]; if (o !== u && o.side === u.side && !o.leader && cheb(o.pos, p) <= 3 && swapOk(st, u, o)) out.push(o.pos); }
        break;
      case "juke":
        [-1, 1].forEach(function (dc) {
          var c = cOf(p) + dc;
          if (!inB(c, rOf(p))) return;
          var tt = idx(c, rOf(p));
          if (FLOOR[tt] && b[tt] < 0 && canEnter(st, u, tt) && !(holds(st, u) && watched(st, u, tt, -1))) out.push(tt);
        });
        break;
      case "call":
        for (i = 0; i < us.length; i++) { o = us[i]; if (o !== u && o.side === u.side && cheb(o.pos, p) <= 3 && looseKeys(st, o).length) out.push(o.pos); }
        break;
      case "handoff":
        if (!looseKeys(st, u).length) break;
        for (j = 0; j < NB[p].length; j++) { o = at(st, NB[p][j]); if (o && o.side === u.side) out.push(o.pos); }
        break;
      case "slip":
        if (!slippery(st, u)) out.push(p);
        break;
      case "swipe":
        for (j = 0; j < NB[p].length; j++) { o = at(st, NB[p][j]); if (o && o.side !== u.side && holds(st, o)) out.push(o.pos); }
        break;
      case "vault":
        if (holds(st, u)) break;
        for (d = 0; d < 8; d++) { ray = RAY[p][d]; if (ray.length >= 2 && b[ray[0]] >= 0 && FLOOR[ray[1]] && b[ray[1]] < 0 && canEnter(st, u, ray[1])) out.push(ray[1]); }
        break;
      case "brace":
        out.push(p);
        break;
      case "shove":
        for (j = 0; j < NB[p].length; j++) { o = at(st, NB[p][j]); if (o && o.side !== u.side) out.push(o.pos); }
        break;
      case "longshot":
        for (d = 0; d < 8; d++) {
          ray = RAY[p][d];
          for (j = 0; j < 3 && j < ray.length; j++) {
            t = ray[j];
            if (b[t] >= 0) { o = at(st, t); if (j >= 1 && o.side !== u.side) out.push(t); break; }
          }
        }
        break;
      case "rushin":
        if (holds(st, u)) break;
        var mark = {};
        for (i = 0; i < us.length; i++) {
          o = us[i];
          if (o === u || o.side !== u.side || cheb(o.pos, p) > 3) continue;
          for (j = 0; j < NB[o.pos].length; j++) { t = NB[o.pos][j]; if (b[t] < 0 && !mark[t] && canEnter(st, u, t)) { mark[t] = 1; out.push(t); } }
        }
        break;
      case "glitch":
        for (i = 0; i < us.length; i++) { o = us[i]; if (o.side !== u.side && cheb(o.pos, p) <= 3) out.push(o.pos); }
        break;
      case "floorit":
        if (holds(st, u) || u.mv !== st.ply) break;
        out = moveTargets(st, u, true);
        break;
      case "orders":
        for (i = 0; i < us.length; i++) { o = us[i]; if (o.side === u.side && !o.leader && o.mv === st.ply && o.fr !== st.ply && !stunned(st, o)) out.push(o.pos); }
        break;
      case "insideman":
        if (st.inside[u.side] !== st.ply) out.push(p);
        break;
    }
    return out;
  }

  function deployTiles(st, s) {
    var out = [], ok = new Uint8Array(N), b = st.board, t, i, j;
    if (crewCount(st, s) >= CFG.maxCrew) return out;
    for (t = 0; t < N; t++) if (IS_HOME[s][t] && b[t] < 0 && !IS_SAFE[t]) ok[t] = 1;
    var inside = st.inside[s] === st.ply;
    for (i = 0; i < st.units.length; i++) {
      var u = st.units[i];
      if (u.side !== s || u.leader) continue;
      if (!(inside || passiveOn(st, u, "hideout") || passiveOn(st, u, "van"))) continue;
      for (j = 0; j < NB[u.pos].length; j++) { t = NB[u.pos][j]; if (b[t] < 0 && !IS_SAFE[t]) ok[t] = 1; }
    }
    for (t = 0; t < N; t++) if (ok[t]) out.push(t);
    return out;
  }

  /* Targets for a gadget card. Hook targets are {u, to}; Alarm has the single target -1. */
  function gadgetTargets(st, s, g) {
    var out = [], b = st.board, us = st.units, i, t, o;
    switch (g) {
      case "smoke": case "emp":
        for (t = 0; t < N; t++) if (FLOOR[t]) out.push(t);
        break;
      case "hook":
        for (i = 0; i < us.length; i++) {
          var u = us[i];
          if (u.side !== s || stunned(st, u) || u.fr === st.ply) continue;
          var keyed = holds(st, u);
          for (var d = 0; d < 8; d++) {
            var ray = RAY[u.pos][d];
            for (var j = 0; j < CFG.hookRange && j < ray.length; j++) {
              t = ray[j];
              if (!FLOOR[t]) continue;
              if (b[t] >= 0) break;
              if (!canEnter(st, u, t) || (keyed && watched(st, u, t, -1))) continue;
              out.push({ u: u.id, to: t });
            }
          }
        }
        break;
      case "tripwire":
        for (t = 0; t < N; t++) {
          if (!FLOOR[t] || b[t] >= 0 || IS_SAFE[t] || IS_HOME[1 - s][t]) continue;
          var mine = false;
          for (i = 0; i < st.traps.length; i++) if (st.traps[i].t === t && st.traps[i].side === s) mine = true;
          if (!mine) out.push(t);
        }
        break;
      case "alarm":
        out.push(-1);
        break;
      case "bribe":
        var L = leaderOf(st, s);
        if (!L || crewCount(st, s) >= CFG.maxCrew) break;
        for (i = 0; i < NB[L.pos].length; i++) { o = at(st, NB[L.pos][i]); if (o && o.side !== s && !o.leader && !immune(st, o)) out.push(o.pos); }
        break;
    }
    return out;
  }

  /* ---------- Effects ---------- */
  function setWin(st, s, how) {
    st.winner = s; st.how = how;
    st.reason = how === "crack" ? NAMES[s] + " cracked " + NAMES[1 - s] + "'s safe." : how === "stash" ? NAMES[s] + " locked " + NAMES[1 - s] + "'s key away." : "Out of time.";
  }

  function landed(st, u, ev) {
    for (var k = 0; k < 2; k++) {
      var K = st.keys[k];
      if (K.h < 0 && K.at === u.pos) { K.h = u.id; K.at = -1; ev.push({ e: "pickup", u: u.id, k: k, at: u.pos }); }
    }
    for (var i = 0; i < st.traps.length; i++) {
      var tr = st.traps[i];
      if (tr.t !== u.pos || tr.side === u.side) continue;
      if (immune(st, u)) break;
      st.traps.splice(i, 1);
      st.revealed = true;
      ev.push({ e: "trap", u: u.id, at: u.pos, side: tr.side });
      takeOut(st, u, ev, "trap");
      break;
    }
  }
  function relocate(st, u, t, ev, how) {
    var from = u.pos;
    st.board[from] = -1; u.pos = t; st.board[t] = u.id;
    ev.push({ e: "move", u: u.id, from: from, to: t, how: how || "move" });
    landed(st, u, ev);
  }
  /* A slippery unit that is attacked flings its keys to its nearest teammate. Returns true if it did. */
  function fling(st, o, ev) {
    if (!slippery(st, o)) return false;
    var ks = keysOf(st, o);
    if (!ks.length) return false;
    var best = null, bd = 99, us = st.units;
    for (var i = 0; i < us.length; i++) {
      var m = us[i];
      if (m === o || m.side !== o.side) continue;
      var d = cheb(m.pos, o.pos);
      if (!best || d < bd || (d === bd && cheb(m.pos, SAFE[1 - o.side]) < cheb(best.pos, SAFE[1 - o.side]))) { best = m; bd = d; }
    }
    for (var k = 0; k < ks.length; k++) {
      var K = st.keys[ks[k]];
      K.lk = st.ply;
      if (best) K.h = best.id; else { K.h = -1; K.at = o.pos; }
    }
    ev.push({ e: "fling", u: o.id, from: o.pos, to: best ? best.pos : o.pos, by: best ? best.id : -1, keys: ks });
    return true;
  }
  function flingTarget(st, o) {
    var best = null, bd = 99, us = st.units;
    for (var i = 0; i < us.length; i++) {
      var m = us[i];
      if (m === o || m.side !== o.side) continue;
      var d = cheb(m.pos, o.pos);
      if (!best || d < bd || (d === bd && cheb(m.pos, SAFE[1 - o.side]) < cheb(best.pos, SAFE[1 - o.side]))) { best = m; bd = d; }
    }
    return best;
  }
  function removeUnit(st, o, ev, cause) {
    fling(st, o, ev);
    st.board[o.pos] = -1;
    st.units.splice(st.units.indexOf(o), 1);
    for (var k = 0; k < 2; k++) if (st.keys[k].h === o.id) { st.keys[k].h = -1; st.keys[k].at = o.pos; ev.push({ e: "drop", k: k, at: o.pos }); }
    ev.push({ e: "out", u: o.id, at: o.pos, cause: cause, type: o.type, side: o.side, leader: o.leader });
  }
  function takeOut(st, o, ev, cause) {
    if (o.type === "brute" && o.armor && !glitched(st, o)) { o.armor = false; ev.push({ e: "armor", u: o.id, at: o.pos, cause: cause }); return false; }
    st.stats[1 - o.side].kos++;
    removeUnit(st, o, ev, cause);
    return true;
  }
  function moveInto(st, u, t, ev, how) {
    var oid = st.board[t];
    if (oid >= 0) {
      var o = unit(st, oid);
      if (o.type === "brute" && o.armor && !glitched(st, o)) {
        o.armor = false;
        ev.push({ e: "bounce", u: u.id, o: o.id, from: u.pos, at: t });
        return;
      }
      var bait = passiveOn(st, o, "bait"), took = [];
      fling(st, o, ev);
      for (var k = 0; k < 2; k++) if (st.keys[k].h === o.id) { st.keys[k].h = u.id; st.keys[k].lk = st.ply; took.push(k); }
      st.board[t] = -1;
      st.units.splice(st.units.indexOf(o), 1);
      st.stats[u.side].caps++;
      if (took.length) st.stats[u.side].steals++;
      ev.push({ e: "capture", u: u.id, o: o.id, at: t, type: o.type, side: o.side, leader: o.leader, keys: took });
      relocate(st, u, t, ev, how);
      if (bait && unit(st, u.id)) stun(st, u, ev);
      return;
    }
    relocate(st, u, t, ev, how);
  }
  function push(st, o, dc, dr, n, ev, slam) {
    for (var i = 0; i < n; i++) {
      var c = cOf(o.pos) + dc, r = rOf(o.pos) + dr;
      if (inB(c, r) && IS_PIT[idx(c, r)]) {
        ev.push({ e: "fall", u: o.id, from: o.pos, at: idx(c, r) });
        takeOut(st, o, ev, "pit");
        return;
      }
      if (!inB(c, r) || !FLOOR[idx(c, r)] || st.board[idx(c, r)] >= 0 || idx(c, r) === SAFE[o.side]) { if (slam) { ev.push({ e: "slam", u: o.id, at: o.pos }); stun(st, o, ev); } return; }
      relocate(st, o, idx(c, r), ev, "push");
      if (!unit(st, o.id)) return;
    }
  }
  function swapUnits(st, a, b, ev) {
    var pa = a.pos, pb = b.pos;
    a.pos = pb; b.pos = pa; st.board[pa] = b.id; st.board[pb] = a.id;
    ev.push({ e: "swap", a: a.id, b: b.id, pa: pa, pb: pb });
  }
  function giveKeys(st, from, to, ev, how) {
    var ks = looseKeys(st, from);
    for (var j = 0; j < ks.length; j++) { st.keys[ks[j]].h = to.id; st.keys[ks[j]].lk = st.ply; }
    ev.push({ e: "pass", from: from.id, to: to.id, a: from.pos, b: to.pos, keys: ks, how: how });
    return ks;
  }

  /* ---------- Hands ---------- */
  function refill(st, s, ev) {
    if (st.hands[s].length || st.sim) return;
    if (st.pend[s]) { st.hands[s] = st.pend[s]; st.pend[s] = null; ev.push({ e: "draw", side: s }); return; }
    var d = st.decks[s], f = function () { return rnd(st); };
    var crew = shuffle(d.crew.slice(), f), gad = shuffle(d.gadgets.slice(), f);
    function card(t) { return { k: "crew", t: t }; }
    st.hands[s] = [card(crew[0]), card(crew[1]), card(crew[2]), { k: "gadget", t: gad[0] }];
    st.pend[s] = [card(crew[3]), card(crew[4]), card(crew[5]), { k: "gadget", t: gad[1] }];
    st.drew = true;
    ev.push({ e: "draw", side: s, shuffle: true });
  }

  /* ---------- Game flow ---------- */
  function newGame(opts) {
    var st = {
      ply: 1, side: 0, winner: null, how: null, reason: "", units: [], nextId: 1, board: new Int16Array(N),
      keys: [], mana: [0, 0], decks: opts.decks, hands: [[], []], pend: [null, null], smokes: [], traps: [], inside: [0, 0],
      seed: (opts.seed >>> 0) || 1, stats: [mkStats(), mkStats()], sim: false, revealed: false, drew: false
    };
    for (var t = 0; t < N; t++) st.board[t] = -1;
    for (var s = 0; s < 2; s++) {
      var L = { id: st.nextId++, side: s, type: opts.decks[s].leader, leader: true, pos: idx(4, s === 0 ? 8 : 1), mv: 0, ac: 0, fr: 0, st: 0, gl: 0, br: 0, sl: 0, armor: false };
      st.units.push(L); st.board[L.pos] = L.id;
      st.keys.push({ h: L.id, at: -1, lk: 0 });
    }
    refill(st, 0, NOEV); refill(st, 1, NOEV);
    st.drew = false;
    startTurn(st, NOEV);
    return st;
  }

  function startTurn(st, ev) {
    var s = st.side, K = st.keys[s], E = st.keys[1 - s], u;
    if (K.h >= 0) {
      u = unit(st, K.h);
      if (u && u.side === s && cheb(u.pos, SAFE[1 - s]) <= CFG.crackRange) { setWin(st, s, "crack"); ev.push({ e: "crack", side: s, u: u.id, at: u.pos }); return; }
    }
    if (E.h >= 0) {
      u = unit(st, E.h);
      if (u && u.side === s && stashed(st, s, u)) { setWin(st, s, "stash"); ev.push({ e: "stash", side: s, u: u.id, at: u.pos }); return; }
    }
    var inc = st.ply === 1 ? CFG.firstIncome : CFG.income;
    var L = leaderOf(st, s);
    if (L && passiveOn(st, L, "connected")) inc += 1;
    st.mana[s] = Math.min(CFG.cap, st.mana[s] + inc);
    st.smokes = st.smokes.filter(function (x) { return st.ply < x.until; });
    refill(st, s, ev);
    ev.push({ e: "turn", side: s, ply: st.ply, income: inc });
  }

  function endTurn(st, ev) {
    ev = ev || NOEV;
    if (st.winner != null) return ev;
    st.ply++; st.side = 1 - st.side;
    if (st.ply > CFG.rounds * 2) { st.winner = "draw"; st.how = "draw"; st.reason = "Round " + CFG.rounds + " ended with both safes shut."; ev.push({ e: "draw-game" }); return ev; }
    startTurn(st, ev);
    return ev;
  }

  function cost(st, a) {
    switch (a.t) {
      case "move": return CFG.moveCost;
      case "throw": return CFG.throwCost;
      case "burn": return CFG.burnCost;
      case "ab": return TYPES[unit(st, a.u).type].ac;
      case "deploy": return TYPES[st.hands[st.side][a.c].t].cost;
      case "gadget": return GADGETS[st.hands[st.side][a.c].t].cost;
    }
    return 0;
  }

  /* Apply a legal action. Returns the list of events it caused. */
  function apply(st, a, ev) {
    ev = ev || [];
    var s = st.side, u = a.u != null ? unit(st, a.u) : null, T, o, card;
    st.mana[s] -= cost(st, a);
    switch (a.t) {
      case "move":
        u.mv = st.ply;
        moveInto(st, u, a.to, ev, "move");
        break;
      case "throw":
        var res = findThrow(st, u, a.to), ks = looseKeys(st, u);
        st.stats[s].throws++;
        ev.push({ e: "throw", u: u.id, from: u.pos, to: a.to, at: res.at, by: res.by, path: res.path, keys: ks, picked: !!res.picked });
        for (var j = 0; j < ks.length; j++) {
          var K = st.keys[ks[j]];
          K.lk = st.ply;
          if (res.by >= 0) K.h = res.by; else { K.h = -1; K.at = res.at; }
        }
        if (res.by >= 0) {
          o = unit(st, res.by);
          if (o.side === s && !passiveOn(st, o, "softhands")) o.mv = st.ply;
          if (o.side !== s) st.stats[o.side].steals++;
        }
        break;
      case "ab":
        T = TYPES[u.type];
        u.ac = st.ply;
        ev.push({ e: "ability", u: u.id, ab: T.ab, from: u.pos, at: a.to });
        doAbility(st, u, T.ab, a.to, ev);
        break;
      case "deploy":
        card = st.hands[s][a.c];
        st.hands[s].splice(a.c, 1);
        var nu = { id: st.nextId++, side: s, type: card.t, leader: false, pos: a.to, mv: 0, ac: 0, fr: st.ply, st: 0, gl: 0, br: 0, sl: 0, armor: card.t === "brute" };
        st.units.push(nu); st.board[a.to] = nu.id;
        st.stats[s].deploys++;
        ev.push({ e: "deploy", u: nu.id, at: a.to, type: card.t, side: s });
        landed(st, nu, ev);
        refill(st, s, ev);
        break;
      case "gadget":
        card = st.hands[s][a.c];
        st.hands[s].splice(a.c, 1);
        st.stats[s].gadgets++;
        ev.push({ e: "gadget", g: card.t, side: s, at: a.to, u: a.u });
        doGadget(st, s, card.t, a, ev);
        refill(st, s, ev);
        break;
      case "burn":
        card = st.hands[s][a.c];
        st.hands[s].splice(a.c, 1);
        ev.push({ e: "burn", side: s, card: card });
        refill(st, s, ev);
        break;
    }
    return ev;
  }

  function doAbility(st, u, ab, t, ev) {
    var o = at(st, t), p = u.pos;
    switch (ab) {
      case "dash": case "juke": case "rushin": relocate(st, u, t, ev, ab); break;
      case "floorit": moveInto(st, u, t, ev, ab); break;
      case "switch": case "vanish": swapUnits(st, u, o, ev); break;
      case "call": giveKeys(st, o, u, ev, "call"); break;
      case "handoff":
        giveKeys(st, u, o, ev, "pass");
        if (!passiveOn(st, o, "softhands")) o.mv = st.ply;
        st.stats[u.side].passes++;
        break;
      case "slip": u.sl = st.ply + 2; break;
      case "swipe":
        if (fling(st, o, ev)) break;
        var took = keysOf(st, o);
        for (var k = 0; k < took.length; k++) { st.keys[took[k]].h = u.id; st.keys[took[k]].lk = st.ply; }
        st.stats[u.side].steals++;
        ev.push({ e: "pass", from: o.id, to: u.id, a: o.pos, b: u.pos, keys: took, how: "swipe" });
        break;
      case "vault":
        var mid = at(st, idx((cOf(p) + cOf(t)) / 2, (rOf(p) + rOf(t)) / 2));
        relocate(st, u, t, ev, "vault");
        if (mid && mid.side !== u.side) stun(st, mid, ev);
        break;
      case "brace": u.br = st.ply + 2; break;
      case "shove":
        push(st, o, Math.sign(cOf(t) - cOf(p)), Math.sign(rOf(t) - rOf(p)), 2, ev, true);
        break;
      case "longshot": takeOut(st, o, ev, "longshot"); break;
      case "glitch": o.gl = st.ply + 2; break;
      case "orders": o.mv = 0; break;
      case "insideman": st.inside[u.side] = st.ply; break;
    }
  }

  function doGadget(st, s, g, a, ev) {
    var us, i, o;
    switch (g) {
      case "smoke": st.smokes.push({ side: s, c: a.to, until: st.ply + 2 }); break;
      case "hook": relocate(st, unit(st, a.u), a.to, ev, "hook"); break;
      case "tripwire": st.traps.push({ side: s, t: a.to }); break;
      case "emp":
        us = st.units.slice();
        for (i = 0; i < us.length; i++) { o = us[i]; if (o.side !== s && cheb(o.pos, a.to) <= 1 && !immune(st, o)) stun(st, o, ev); }
        break;
      case "alarm":
        var safe = SAFE[s];
        us = st.units.filter(function (x) { return x.side !== s && cheb(x.pos, safe) <= 2 && !immune(st, x); });
        us.sort(function (x, y) { return cheb(y.pos, safe) - cheb(x.pos, safe); });
        for (i = 0; i < us.length; i++) {
          o = us[i];
          if (!unit(st, o.id)) continue;
          var dc = Math.sign(cOf(o.pos) - cOf(safe)), dr = Math.sign(rOf(o.pos) - rOf(safe));
          if (!dc && !dr) dr = FWD[s];
          push(st, o, dc, dr, 1, ev, false);
        }
        break;
      case "bribe":
        o = at(st, a.to);
        fling(st, o, ev);
        o.side = s; o.mv = st.ply; o.ac = st.ply; o.fr = st.ply;
        for (var k = 0; k < 2; k++) if (st.keys[k].h === o.id) st.keys[k].lk = st.ply;
        ev.push({ e: "bribe", u: o.id, at: o.pos, side: s });
        break;
    }
  }

  /* ---------- Legality (used to check bot plans against the real state) ---------- */
  function has(list, t) { for (var i = 0; i < list.length; i++) if (list[i] === t) return true; return false; }
  function isLegal(st, a) {
    if (st.winner != null) return false;
    var s = st.side, u = a.u != null ? unit(st, a.u) : null;
    if (a.t === "deploy" || a.t === "gadget" || a.t === "burn") {
      var card = st.hands[s][a.c];
      if (!card) return false;
      if (a.t === "burn") return afford(st, CFG.burnCost);
      if (a.t === "deploy") return card.k === "crew" && afford(st, TYPES[card.t].cost) && has(deployTiles(st, s), a.to);
      if (card.k !== "gadget" || !afford(st, GADGETS[card.t].cost)) return false;
      var gt = gadgetTargets(st, s, card.t);
      if (card.t === "hook") return gt.some(function (x) { return x.u === a.u && x.to === a.to; });
      return has(gt, a.to);
    }
    if (!u || u.side !== s) return false;
    if (a.t === "move") return afford(st, CFG.moveCost) && has(moveTargets(st, u), a.to);
    if (a.t === "throw") return afford(st, CFG.throwCost) && throwOptions(st, u).some(function (x) { return x.to === a.to; });
    if (a.t === "ab") return afford(st, TYPES[u.type].ac) && has(abilityTargets(st, u), a.to);
    return false;
  }

  /* ---------- Threats: what side X could do on its next turn ---------- */
  /* Captures unit u could make if it first stood on tile q (used for two-step threats). */
  function capturesFrom(st, u, q, out) {
    var p0 = u.pos, b = st.board;
    if (q !== p0 && b[q] >= 0) return;
    b[p0] = -1; u.pos = q; b[q] = u.id;
    var mt = moveTargets(st, u, true, true);
    b[q] = -1; u.pos = p0; b[p0] = u.id;
    for (var j = 0; j < mt.length; j++) if (b[mt[j]] >= 0 && mt[j] !== p0) out.push(mt[j]);
  }

  /* Tiles from which unit u could still make its normal move after using a movement ability. */
  function abilitySpots(st, u) {
    var ab = TYPES[u.type].ab;
    if (ab === "dash" || ab === "juke" || ab === "rushin" || ab === "vault") return abilityTargets(st, u);
    if (ab === "floorit") {
      if (holds(st, u)) return [];
      var mt = moveTargets(st, u, true, true), out = [];
      for (var j = 0; j < mt.length; j++) if (st.board[mt[j]] < 0) out.push(mt[j]);
      return out;
    }
    return [];
  }

  function scanThreats(st, X) {
    var sp = st.ply, ss = st.side;
    if (ss !== X) { st.ply = sp + 1; st.side = X; }
    // stash: X can get the enemy key into its back row; crack: X's own key can reach the enemy safe.
    var R = { cap: {}, ko: {}, swipe: {}, shove: {}, stash: false, crack: false };
    var us = st.units, enemyKey = st.keys[1 - X], ownKey = st.keys[X], target = SAFE[1 - X], i, j, t, v;
    for (i = 0; i < us.length; i++) {
      var u = us[i];
      if (u.side !== X || stunned(st, u)) continue;
      var carrying = enemyKey.h === u.id, own = ownKey.h === u.id;
      var mt = moveTargets(st, u, false, true);
      for (j = 0; j < mt.length; j++) {
        t = mt[j];
        var vid = st.board[t];
        if (vid >= 0) {
          (R.cap[vid] || (R.cap[vid] = [])).push(u.id);
          if ((CFG.stashTo === "safe" ? t === SAFE[X] : rOf(t) === BACK[X]) && (carrying || enemyKey.h === vid)) R.stash = true;
          if (cheb(t, target) <= CFG.crackRange && (own || ownKey.h === vid)) R.crack = true;
        } else {
          if ((CFG.stashTo === "safe" ? t === SAFE[X] : rOf(t) === BACK[X]) && (carrying || (enemyKey.h < 0 && enemyKey.at === t))) R.stash = true;
          if (cheb(t, target) <= CFG.crackRange && own) R.crack = true;
        }
      }
      if (canAct(st, u)) {
        var ab = TYPES[u.type].ab;
        if (st.mana[X] + CFG.income + CFG.debt >= TYPES[u.type].ac + CFG.moveCost) {
          var spots = abilitySpots(st, u), extra = [];
          for (j = 0; j < spots.length; j++) capturesFrom(st, u, spots[j], extra);
          for (j = 0; j < extra.length; j++) {
            var xv = st.board[extra[j]];
            if (xv >= 0 && (!R.cap[xv] || R.cap[xv].indexOf(u.id) < 0)) (R.cap[xv] || (R.cap[xv] = [])).push(u.id);
          }
        }
        if (ab === "longshot" || ab === "swipe" || ab === "shove" || ab === "call") {
          var at2 = abilityTargets(st, u);
          for (j = 0; j < at2.length; j++) {
            v = at(st, at2[j]);
            if (ab === "longshot") R.ko[v.id] = true;
            else if (ab === "shove") R.shove[v.id] = true;
            else if (ab === "swipe") { R.swipe[v.id] = u.pos; if (stashed(st, X, u) && enemyKey.h === v.id) R.stash = true; }
          }
        }
      }
    }
    st.ply = sp; st.side = ss;
    return R;
  }

  /* Units of `side` the other side could capture or take out on its next turn (for the danger badge). */
  function dangerTo(st, side) {
    var R = scanThreats(st, 1 - side), out = {};
    Object.keys(R.cap).forEach(function (k) { out[k] = true; });
    Object.keys(R.ko).forEach(function (k) { out[k] = true; });
    Object.keys(R.swipe).forEach(function (k) { out[k] = true; });
    return out;
  }

  /* ---------- Evaluation ---------- */
  var EV = { keyRow: 2.2, keyBase: 14, keyLost: 3.2, mana: 0.45, debt: 0.7, adv: 0.2, hide: 0.3, guard: 0.7, lane: 0.6, chase: 0.7, hang: 0.55, safeCover: 1.1, lonely: 1.0 };

  function val(u) { return u.leader ? 6 : TYPES[u.type].cost + 2; }
  function advance(u) { return u.side === 0 ? 9 - rOf(u.pos) : rOf(u.pos); }
  function isHideout(u) { return u.type === "lookout" || u.type === "driver"; }

  /* Value to `me` of key k when held by a unit of `side` at pos (side -1: lying on the ground). */
  function keyValAt(me, k, side, pos) {
    var opp = 1 - me;
    var mineV, theirsV;
    var safeStash = CFG.stashTo === "safe";
    if (k === me) {
      mineV = EV.keyRow * (9 - cheb(pos, SAFE[opp]));
      theirsV = -(EV.keyBase + EV.keyLost * (9 - (safeStash ? cheb(pos, SAFE[opp]) : Math.abs(rOf(pos) - BACK[opp]))));
    } else {
      mineV = EV.keyBase + EV.keyLost * (9 - (safeStash ? cheb(pos, SAFE[me]) : Math.abs(rOf(pos) - BACK[me])));
      theirsV = -EV.keyRow * (9 - cheb(pos, SAFE[me]));
    }
    if (side === me) return mineV;
    if (side === opp) return theirsV;
    return side === -2 ? 0.3 * mineV + 0.7 * theirsV : 0.65 * mineV + 0.35 * theirsV;
  }
  function keyTerm(st, me, k) {
    var K = st.keys[k];
    if (K.h >= 0) { var u = unit(st, K.h); return keyValAt(me, k, u.side, u.pos); }
    var dm = 99, dt = 99;
    for (var i = 0; i < st.units.length; i++) {
      var v = st.units[i], d = cheb(v.pos, K.at);
      if (v.side === me) { if (d < dm) dm = d; } else if (d < dt) dt = d;
    }
    return keyValAt(me, k, dt <= dm ? -2 : -1, K.at);
  }

  function handValue(st, me) {
    var hand = st.hands[me];
    if (!hand.length) return 3.2;
    var v = 0, room = crewCount(st, me) < CFG.maxCrew, crew = 0;
    for (var i = 0; i < hand.length; i++) {
      var c = hand[i];
      if (c.k === "crew") { crew++; v += room ? 0.6 + 0.15 * TYPES[c.t].cost : 0.2; } else v += 0.9;
    }
    if (!crew && room) v -= 1.2 * hand.length;
    return v;
  }

  /* How far each unit can usually strike in one turn, counting its movement ability. */
  var STRIKE = { wobbler: 1, greaser: 6, boss: 1, fixer: 1, ghost: 4, lookout: 4, decoy: 2, runner: 4, catcher: 1, pickpocket: 3, acrobat: 4, guard: 1, brute: 1, sniper: 3, bodyguard: 4, hacker: 1, driver: 6 };
  /* Rough danger to a key carrier: enemies that could reach it, minus friends close enough to help. */
  function exposure(st, h) {
    var foes = 0, mates = 0, us = st.units;
    for (var i = 0; i < us.length; i++) {
      var u = us[i];
      if (u === h) continue;
      var d = cheb(u.pos, h.pos);
      if (u.side !== h.side) { if (d <= STRIKE[u.type] + 1 && !(st.ply + 1 < u.st)) foes++; }
      else if (d <= 2) mates++;
    }
    return Math.max(0, foes - mates);
  }

  function evaluate(st, me, L) {
    if (st.winner != null) return st.winner === me ? 1e6 : (st.winner === "draw" ? 0 : -1e6);
    var opp = 1 - me, us = st.units, sc = 0, i, u, v, tw = L ? L.threat : 1;
    for (i = 0; i < us.length; i++) {
      u = us[i];
      v = val(u) + (u.armor ? 1 : 0);
      if (!u.leader) v += Math.min(advance(u), 7) * (isHideout(u) ? EV.hide : EV.adv);
      sc += u.side === me ? v : -v;
    }
    var m = st.mana[me];
    sc += m >= 0 ? EV.mana * Math.min(m, CFG.cap - CFG.income) : EV.debt * m;
    sc += handValue(st, me);
    sc += keyTerm(st, me, me) + keyTerm(st, me, opp);

    var KM = st.keys[me], KT = st.keys[opp];
    var hM = KM.h >= 0 ? unit(st, KM.h) : null, hT = KT.h >= 0 ? unit(st, KT.h) : null;
    // Wins land at the start of a turn: if theirs is already set up, my turn can't stop it any more.
    if (hT && hT.side === opp && cheb(hT.pos, SAFE[me]) <= CFG.crackRange) return -1e5;
    if (hM && hM.side === opp && stashed(st, opp, hM)) return -1e5;

    var T = scanThreats(st, opp);
    if (T.stash) sc -= 10;
    if (T.crack) sc -= 6;
    var cover = null;
    function covered(t) {
      if (!cover) { cover = new Uint8Array(N); for (var q = 0; q < us.length; q++) if (us[q].side === me && !(st.ply + 2 < us[q].st)) reach(st, us[q], cover); }
      return cover[t] > 0;
    }

    // Risk to every key one of my units carries.
    var carriers = [];
    if (hM && hM.side === me) carriers.push(hM);
    if (hT && hT.side === me && carriers.indexOf(hT) < 0) carriers.push(hT);
    for (i = 0; i < carriers.length; i++) {
      var Hc = carriers[i], ks = keysOf(st, Hc), now = 0, risk = 0;
      for (var a = 0; a < ks.length; a++) now += keyValAt(me, ks[a], me, Hc.pos);
      if (T.cap[Hc.id]) {
        var lostC = now;
        for (a = 0; a < ks.length; a++) lostC -= keyValAt(me, ks[a], opp, Hc.pos);
        risk = Math.max(risk, lostC * (covered(Hc.pos) ? 0.5 : 1));
      }
      if (T.swipe.hasOwnProperty(Hc.id)) {
        var P = T.swipe[Hc.id], lostS = now;
        for (a = 0; a < ks.length; a++) lostS -= keyValAt(me, ks[a], opp, P);
        risk = Math.max(risk, lostS * (covered(P) ? 0.55 : 1));
      }
      if (T.ko[Hc.id]) {
        var lostK = now;
        for (a = 0; a < ks.length; a++) lostK -= keyValAt(me, ks[a], -2, Hc.pos);
        risk = Math.max(risk, lostK * 0.8);
      }
      if (st.ply + 1 < (Hc.sl || 0) && flingTarget(st, Hc)) risk *= 0.3;
      sc -= tw * 0.9 * risk;
      var pending = (Hc === hM && cheb(Hc.pos, SAFE[opp]) <= CFG.crackRange) || (Hc === hT && stashed(st, me, Hc));
      if (pending && !risk && !T.shove[Hc.id]) sc += 2.5e4;
    }

    // Hanging pieces: the opponent usually takes the best one.
    var hang = [];
    for (i = 0; i < us.length; i++) {
      u = us[i];
      if (u.side !== me || carriers.indexOf(u) >= 0) continue;
      if (T.cap[u.id] || T.ko[u.id]) hang.push((val(u) + (u.armor ? 1 : 0)) * (covered(u.pos) ? 0.45 : 1) * (u.armor && !T.ko[u.id] ? 0.3 : 1));
    }
    hang.sort(function (x, y) { return y - x; });
    if (hang.length) sc -= tw * EV.hang * (hang[0] + 0.3 * (hang[1] || 0));

    // Support for my carrier, pressure on theirs, and a guard on my safe.
    var adj, lane, near, dH;
    if (hM && hM.side === me) {
      adj = 0; lane = 0; dH = cheb(hM.pos, SAFE[opp]);
      for (i = 0; i < us.length; i++) {
        u = us[i];
        if (u === hM) continue;
        var dd = cheb(u.pos, hM.pos);
        if (u.side === me) { if (dd === 1) adj++; if (dd <= CFG.passRange && cheb(u.pos, SAFE[opp]) < dH) lane++; }
      }
      sc += EV.guard * Math.min(adj, 3) + EV.lane * Math.min(lane, 2);
    }
    for (i = 0; i < carriers.length; i++) sc -= tw * EV.lonely * exposure(st, carriers[i]);
    if (hT && hT.side === opp) {
      adj = 0; near = 0;
      for (i = 0; i < us.length; i++) {
        u = us[i];
        if (u === hT) continue;
        var de = cheb(u.pos, hT.pos);
        if (u.side === opp && de === 1) adj++;
        if (u.side === me && de <= 2) near++;
      }
      sc -= EV.guard * 0.6 * Math.min(adj, 3);
      sc += EV.chase * Math.min(near, 3);
      var ds = cheb(hT.pos, SAFE[me]);
      if (ds <= 3) {
        var guards = 0;
        for (i = 0; i < us.length; i++) if (us[i].side === me && cheb(us[i].pos, SAFE[me]) <= 1) guards++;
        sc += EV.safeCover * Math.min(guards, 3) * (4 - ds) / 3;
        if (ds === 1 && !covered(SAFE[me])) sc -= 6;
      }
    }
    if (hM && hM.side === opp) {
      near = 0;
      for (i = 0; i < us.length; i++) if (us[i].side === me && cheb(us[i].pos, hM.pos) <= 2) near++;
      sc += EV.chase * Math.min(near, 3);
    }
    if (KM.h < 0 || KT.h < 0) {
      // A loose key: be near it.
      [KM, KT].forEach(function (K) {
        if (K.h >= 0) return;
        var best = 9;
        for (var q = 0; q < us.length; q++) if (us[q].side === me) best = Math.min(best, cheb(us[q].pos, K.at));
        sc += 0.8 * (9 - best) / 3;
      });
    }
    return sc;
  }

  /* ---------- Bot ---------- */
  var LEVELS = {
    easy: { beam: 2, depth: 3, noise: 5, threat: 0.3, careless: 0.35, reply: 0, smart: false },
    normal: { beam: 5, depth: 4, noise: 0.6, threat: 0.9, reply: 0, smart: true },
    hard: { beam: 10, depth: 7, noise: 0.05, threat: 1, reply: 8, rbeam: 5, rdepth: 6, rmix: 0.85, smart: true }
  };

  function hashState(st) {
    var s = st.mana[0] + "," + st.mana[1] + "|" + st.hands[st.side].length + "|" + (st.inside[st.side] === st.ply ? 1 : 0) + "|" + st.smokes.length + "," + st.traps.length + "|";
    for (var k = 0; k < 2; k++) { var K = st.keys[k]; s += K.h + ":" + K.at + ":" + (K.lk === st.ply ? 1 : 0) + "|"; }
    var us = st.units;
    for (var i = 0; i < us.length; i++) {
      var u = us[i];
      s += u.id + "@" + u.pos + u.side + (u.mv === st.ply ? "m" : "") + (u.ac === st.ply ? "a" : "") + (st.ply < u.st ? "s" : "") + (st.ply < u.gl ? "g" : "") + (st.ply < u.br ? "b" : "") + (st.ply < (u.sl || 0) ? "l" : "") + (u.armor ? "A" : "") + ",";
    }
    return s;
  }

  function cloneState(st) {
    var us = st.units, nu = new Array(us.length);
    for (var i = 0; i < us.length; i++) {
      var u = us[i];
      nu[i] = { id: u.id, side: u.side, type: u.type, leader: u.leader, pos: u.pos, mv: u.mv, ac: u.ac, fr: u.fr, st: u.st, gl: u.gl, br: u.br, sl: u.sl, armor: u.armor };
    }
    return {
      ply: st.ply, side: st.side, winner: st.winner, how: st.how, reason: st.reason, units: nu, nextId: st.nextId, board: st.board.slice(),
      keys: [{ h: st.keys[0].h, at: st.keys[0].at, lk: st.keys[0].lk }, { h: st.keys[1].h, at: st.keys[1].at, lk: st.keys[1].lk }],
      mana: st.mana.slice(), decks: st.decks, hands: [st.hands[0].slice(), st.hands[1].slice()],
      pend: [st.pend[0] ? st.pend[0].slice() : null, st.pend[1] ? st.pend[1].slice() : null],
      smokes: st.smokes.slice(), traps: st.traps.slice(), inside: st.inside.slice(), seed: st.seed,
      stats: st.sim ? st.stats : [Object.assign({}, st.stats[0]), Object.assign({}, st.stats[1])], sim: st.sim, revealed: false, drew: false
    };
  }

  /* Candidate actions for the search, with obviously pointless targets pruned. */
  function searchActions(st, L) {
    var s = st.side, opp = 1 - s, out = [], us = st.units, i, j, u, list;
    var spend = st.mana[s] + CFG.debt;
    var KM = st.keys[s], KT = st.keys[opp];
    var hM = KM.h >= 0 ? unit(st, KM.h) : null, hT = KT.h >= 0 ? unit(st, KT.h) : null;
    for (i = 0; i < us.length; i++) {
      u = us[i];
      if (u.side !== s) continue;
      if (spend >= CFG.moveCost) { list = moveTargets(st, u); for (j = 0; j < list.length; j++) out.push({ t: "move", u: u.id, to: list[j] }); }
      if (spend >= CFG.throwCost) {
        list = throwOptions(st, u);
        for (j = 0; j < list.length; j++) { var r = list[j]; if (r.by >= 0 && unit(st, r.by).side === s && r.by !== u.id) out.push({ t: "throw", u: u.id, to: r.to }); }
      }
      var T = TYPES[u.type];
      if (spend >= T.ac) {
        list = abilityTargets(st, u);
        if (T.ab === "glitch" && L.smart) list = list.filter(function (t) { var o = at(st, t); return o && !glitched(st, o) && (o.type !== "sniper"); });
        for (j = 0; j < list.length; j++) out.push({ t: "ab", u: u.id, to: list[j] });
      }
    }
    var hand = st.hands[s], tiles = null;
    for (var c = 0; c < hand.length; c++) {
      var card = hand[c], used = false;
      if (card.k === "crew") {
        if (spend >= TYPES[card.t].cost) {
          if (!tiles) tiles = deployTiles(st, s);
          for (j = 0; j < tiles.length; j++) out.push({ t: "deploy", c: c, to: tiles[j] });
          used = tiles.length > 0;
        }
      } else if (spend >= GADGETS[card.t].cost) {
        var gl = gadgetTargets(st, s, card.t);
        gl = pruneGadget(st, s, card.t, gl, hM, hT);
        for (j = 0; j < gl.length; j++) {
          if (card.t === "hook") out.push({ t: "gadget", c: c, u: gl[j].u, to: gl[j].to });
          else out.push({ t: "gadget", c: c, to: gl[j] });
        }
        used = gl.length > 0;
      }
      if (!used && spend >= CFG.burnCost) out.push({ t: "burn", c: c });
      else if (card.k === "gadget" && spend >= CFG.burnCost && hand.length === 1) out.push({ t: "burn", c: c });
    }
    return out;
  }

  function pruneGadget(st, s, g, list, hM, hT) {
    var opp = 1 - s, out = [], i, t;
    var myCarrier = hM && hM.side === s ? hM : null, theirCarrier = hT && hT.side === opp ? hT : null;
    var thief = hM && hM.side === opp ? hM : null;
    switch (g) {
      case "smoke":
        if (!myCarrier) return out;
        for (i = 0; i < list.length; i++) if (cheb(list[i], myCarrier.pos) <= 1) out.push(list[i]);
        return out;
      case "emp":
        for (i = 0; i < list.length; i++) {
          t = list[i];
          var n = 0, key = false;
          for (var j = 0; j < st.units.length; j++) {
            var o = st.units[j];
            if (o.side === opp && cheb(o.pos, t) <= 1) { n++; if (holds(st, o)) key = true; }
          }
          if (n >= 2 || key) out.push(t);
        }
        return out;
      case "hook":
        for (i = 0; i < list.length; i++) {
          var x = list[i], uu = unit(st, x.u);
          if (myCarrier && uu === myCarrier) { if (cheb(x.to, SAFE[opp]) < cheb(uu.pos, SAFE[opp])) out.push(x); continue; }
          var tgt = theirCarrier || thief;
          if (tgt && cheb(x.to, tgt.pos) === 1) out.push(x);
        }
        return out;
      case "tripwire":
        var foe = theirCarrier || thief;
        for (i = 0; i < list.length; i++) {
          t = list[i];
          if ((foe && cheb(t, foe.pos) <= 2) || cheb(t, SAFE[s]) === 1) out.push(t);
        }
        return out.slice(0, 16);
      case "alarm":
        for (i = 0; i < st.units.length; i++) if (st.units[i].side === opp && cheb(st.units[i].pos, SAFE[s]) <= 2) return list;
        return out;
      default:
        return list;
    }
  }

  function beamSearch(root, me, L, rand, B, D) {
    var noise = function () { return L.noise ? (rand() - 0.5) * L.noise : 0; };
    var start = { st: root, acts: [], score: evaluate(root, me, L) + noise() };
    var cands = [start], beam = [start], seen = {};
    seen[hashState(root)] = 1;
    for (var depth = 0; depth < D; depth++) {
      var next = [];
      for (var b = 0; b < beam.length; b++) {
        var node = beam[b], acts = searchActions(node.st, L);
        for (var j = 0; j < acts.length; j++) {
          var c = cloneState(node.st);
          apply(c, acts[j], NOEV);
          var path = node.acts.concat([acts[j]]);
          if (c.winner === me) return [{ st: c, acts: path, score: 1e6 }];
          if (c.winner != null) continue;
          var hsh = hashState(c);
          if (seen[hsh]) continue;
          seen[hsh] = 1;
          next.push({ st: c, acts: path, score: evaluate(c, me, L) + noise() });
        }
      }
      if (!next.length) break;
      next.sort(function (x, y) { return y.score - x.score; });
      beam = next.slice(0, B);
      cands = cands.concat(beam);
    }
    cands.sort(function (x, y) { return y.score - x.score; });
    return cands;
  }

  /* What the bot can see: its own traps, not the enemy's hand or traps. */
  function botView(st, me) {
    var v = cloneState(st);
    v.sim = true;
    v.stats = [mkStats(), mkStats()];
    v.traps = v.traps.filter(function (t) { return t.side === me; });
    v.hands[1 - me] = []; v.pend[1 - me] = null;
    return v;
  }

  function replyScore(cst, me, L, rand) {
    var c = cloneState(cst), opp = 1 - me;
    endTurn(c, NOEV);
    if (c.winner != null) return c.winner === me ? 1e6 : c.winner === "draw" ? 0 : -1e6;
    var rc = beamSearch(c, opp, { noise: 0, threat: 1, smart: true }, rand, L.rbeam, L.rdepth);
    var best = rc[0];
    if (best.st.winner != null) return best.st.winner === me ? 1e6 : -1e6;
    return -best.score;
  }

  /* Plan a whole turn for the side to move. Returns a list of actions (possibly empty). */
  function botPlan(st, level, rand) {
    var L = LEVELS[level] || LEVELS.normal, me = st.side;
    if (L.careless && rand() < L.careless) L = Object.assign({}, L, { threat: 0 });
    var root = botView(st, me);
    var cands = beamSearch(root, me, L, rand, L.beam, L.depth);
    if (cands[0].score >= 1e6) return cands[0].acts;
    if (L.reply) {
      // Check the most promising plans that differ in where the key ends up or how the turn starts.
      var top = [], sigs = {};
      for (var c = 0; c < cands.length && top.length < L.reply; c++) {
        var cs = cands[c].st, kh = cs.keys[me].h, a0 = cands[c].acts[0];
        var sig = (kh >= 0 ? unit(cs, kh).pos : "g" + cs.keys[me].at) + "|" + (a0 ? a0.t + a0.u + ":" + a0.to + ":" + a0.c : "none");
        if (sigs[sig]) continue;
        sigs[sig] = 1;
        top.push(cands[c]);
      }
      var best = null;
      for (var i = 0; i < top.length; i++) {
        var r = replyScore(top[i].st, me, L, rand);
        var v = L.rmix * r + (1 - L.rmix) * top[i].score;
        if (!best || v > best.v) best = { v: v, acts: top[i].acts };
      }
      return best.acts;
    }
    return cands[0].acts;
  }

  var API = {
    W: W, H: H, N: N, CFG: CFG, BACK: BACK, FWD: FWD, SAFE: SAFE, HOME_ROWS: HOME_ROWS, IS_HOME: IS_HOME, IS_SAFE: IS_SAFE, NAMES: NAMES,
    TYPES: TYPES, GADGETS: GADGETS, LEADERS: LEADERS, CREW: CREW, GADGET_LIST: GADGET_LIST, PRESETS: PRESETS, LEVELS: LEVELS, RAY: RAY, NB: NB,
    idx: idx, cOf: cOf, rOf: rOf, cheb: cheb, rng: rng, validDeck: validDeck, randomDeck: randomDeck,
    newGame: newGame, cloneState: cloneState, unit: unit, at: at, holds: holds, keysOf: keysOf, looseKeys: looseKeys,
    stunned: stunned, glitched: glitched, braced: braced, inSmoke: inSmoke, immune: immune, canMove: canMove, canAct: canAct, canHandle: canHandle,
    afford: afford, crewCount: crewCount, leaderOf: leaderOf, round: round, cost: cost,
    moveTargets: moveTargets, throwOptions: throwOptions, flingTarget: flingTarget, slippery: slippery, FLOOR: FLOOR, IS_PIT: IS_PIT, PITS: PITS, findThrow: findThrow, abilityTargets: abilityTargets,
    deployTiles: deployTiles, gadgetTargets: gadgetTargets, apply: apply, endTurn: endTurn, isLegal: isLegal, dangerTo: dangerTo,
    evaluate: evaluate, bots: { plan: botPlan }
  };
  root.Keyrunners = API;
  if (typeof module !== "undefined" && module.exports) module.exports = API;
})(typeof window !== "undefined" ? window : globalThis);
