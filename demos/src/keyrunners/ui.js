/* Keyrunners: interface, crew builder, turn flow, bot playback and pass-the-phone play. */
(function () {
  "use strict";
  var KR = window.Keyrunners, K = window.Kit, h = K.h, sv = K.s;
  var S = 48, PAD = 4, VBW = KR.W * S + PAD * 2, VBH = KR.H * S + PAD * 2;
  var NAME = KR.NAMES, T = KR.TYPES, GD = KR.GADGETS;

  var ICON = {
    boss: '<path d="M4 18.5h16"/><path d="M5 18.5L4 8l5 4 3-6.5L15 12l5-4-1 10.5"/>',
    fixer: '<rect x="3.5" y="8" width="17" height="11" rx="2"/><path d="M9 8V6.2A1.2 1.2 0 0110.2 5h3.6A1.2 1.2 0 0115 6.2V8M3.5 13h17"/>',
    ghost: '<path d="M6 20v-8a6 6 0 0112 0v8l-2-1.6-2 1.6-2-1.6-2 1.6-2-1.6z"/><path d="M10 11v1.5M14 11v1.5"/>',
    lookout: '<circle cx="7" cy="15" r="3.5"/><circle cx="17" cy="15" r="3.5"/><path d="M4.5 12.5L6 6h3l.8 6.5M19.5 12.5L18 6h-3l-.8 6.5M10.5 14h3"/>',
    decoy: '<circle cx="12" cy="12" r="8"/><circle cx="12" cy="12" r="4"/><circle cx="12" cy="12" r=".7"/>',
    runner: '<path d="M5 6l6 6-6 6"/><path d="M12 6l6 6-6 6"/>',
    catcher: '<path d="M7 12.5V7.5a1.5 1.5 0 013 0V11M10 11V5.5a1.5 1.5 0 013 0V11M13 11V6.5a1.5 1.5 0 013 0v5M16 11.5V9.5a1.5 1.5 0 013 0V14a7 7 0 01-7 7h-.5a6 6 0 01-5-2.7l-2.6-4a1.5 1.5 0 012.4-1.8L7 14"/>',
    pickpocket: '<path d="M2.5 10.5c2.5-2 6-2.5 9.5-.5 3.5-2 7-1.5 9.5.5-.5 4-2.6 5.5-5 5.5-2 0-3.2-1-4.5-2.3C10.7 15 9.5 16 7.5 16c-2.4 0-4.5-1.5-5-5.5z"/><path d="M6.5 11.8h2.5M15 11.8h2.5"/>',
    acrobat: '<path d="M5 18.5c0-7 4-12.5 9-12.5a4.5 4.5 0 010 9H9"/><path d="M11.5 12.5L9 15l2.5 2.5"/>',
    guard: '<path d="M2 12s3.6-6.5 10-6.5S22 12 22 12s-3.6 6.5-10 6.5S2 12 2 12z"/><circle cx="12" cy="12" r="3"/>',
    brute: '<path d="M4.5 9v6M7.5 6.5v11M16.5 6.5v11M19.5 9v6M7.5 12h9"/>',
    sniper: '<circle cx="12" cy="12" r="7"/><path d="M12 3v5M12 16v5M3 12h5M16 12h5"/>',
    bodyguard: '<path d="M12 3l7.5 3v5.5c0 4.8-3.2 8-7.5 9.5-4.3-1.5-7.5-4.7-7.5-9.5V6z"/>',
    hacker: '<path d="M8 7l-5 5 5 5M16 7l5 5-5 5M13.5 5l-3 14"/>',
    driver: '<circle cx="12" cy="12" r="8.5"/><circle cx="12" cy="12" r="2.2"/><path d="M12 14.2v6.3M10 11.2L4 9.5M14 11.2l6-1.7"/>',
    smoke: '<path d="M7 18.5a4 4 0 01-.4-8 5.5 5.5 0 0110.6-1.2 3.7 3.7 0 01.3 9.2z"/>',
    hook: '<path d="M12 3v11M8 6h8"/><path d="M5 12a7 7 0 0014 0"/><path d="M5 12l-1.5 2M19 12l1.5 2"/>',
    tripwire: '<path d="M3 16l3-4 3 4 3-4 3 4 3-4 3 4"/><path d="M3 20h18"/>',
    emp: '<path d="M13 2.5L5 13.5h6l-1.5 8 8-11h-6z"/>',
    alarm: '<path d="M6 16.5V11a6 6 0 0112 0v5.5l2 2H4z"/><path d="M10 20.5a2 2 0 004 0"/>',
    bribe: '<rect x="3" y="7" width="18" height="10" rx="2"/><circle cx="12" cy="12" r="2.4"/><path d="M6.5 10v4M17.5 10v4"/>',
    key: '<circle cx="7.5" cy="12" r="4"/><path d="M11.5 12h9M17.5 12v3M20.5 12v3"/>',
    safe: '<rect x="3" y="3" width="18" height="18" rx="3"/><circle cx="12" cy="12" r="4.5"/><path d="M12 7.5v1.8M12 14.7v1.8M7.5 12h1.8M14.7 12h1.8"/>'
  };
  function iconSvg(name, color) {
    return '<svg viewBox="0 0 24 24" fill="none" stroke="' + (color || "currentColor") + '" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">' + ICON[name] + "</svg>";
  }

  var TITLE_ART = '<svg viewBox="0 0 260 160" role="img" aria-label="A blue crew passing a gold key toward a red safe">' +
    '<g stroke="#2d3746" stroke-width="1">' + [0, 1, 2, 3, 4, 5, 6].map(function (k) { return '<path d="M' + (20 + k * 37) + ' 8v144"/>'; }).join("") +
    [0, 1, 2, 3, 4].map(function (k) { return '<path d="M20 ' + (8 + k * 36) + 'h222"/>'; }).join("") + "</g>" +
    '<rect x="172" y="12" width="48" height="48" rx="9" fill="rgba(255,90,76,.16)" stroke="#ff5a4c" stroke-width="2.6"/>' +
    '<circle cx="196" cy="36" r="12" fill="none" stroke="#f2b840" stroke-width="2.6"/>' +
    '<path d="M196 21v5M196 46v5M181 36h5M206 36h5" stroke="#f2b840" stroke-width="2.4" stroke-linecap="round"/>' +
    '<path d="M74 118 Q 96 80 116 86" fill="none" stroke="#f2b840" stroke-width="2.6" stroke-dasharray="5 5" stroke-linecap="round"/>' +
    '<path d="M140 74 Q 156 46 168 46" fill="none" stroke="#f2b840" stroke-width="2.6" stroke-dasharray="5 5" stroke-linecap="round"/>' +
    '<circle cx="58" cy="124" r="17" fill="#3d8bff"/><circle cx="58" cy="124" r="17" fill="none" stroke="#f2b840" stroke-width="3"/>' +
    '<path d="M50 129h16M51 129l-1-8 4 3 4-6 4 6 4-3-1 8" fill="none" stroke="#fff" stroke-width="2" stroke-linejoin="round" stroke-linecap="round"/>' +
    '<circle cx="128" cy="82" r="17" fill="#3d8bff"/><path d="M121 76l6 6-6 6M128 76l6 6-6 6" fill="none" stroke="#fff" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/>' +
    '<g transform="translate(140 62) rotate(-35)"><rect x="1" y="-2.4" width="15" height="4.8" rx="1.5" fill="#f2b840" stroke="#1b1305" stroke-width="1.2"/><rect x="11" y="0" width="3" height="6" fill="#f2b840" stroke="#1b1305" stroke-width="1"/><circle cx="-2" cy="0" r="6" fill="#9cc3ff" stroke="#1b1305" stroke-width="1.4"/></g>' +
    '<circle cx="216" cy="118" r="15" fill="#ff5a4c" opacity=".9"/><path d="M216 109v18M207 118h18" stroke="#fff" stroke-width="2" stroke-linecap="round" opacity=".9"/>' +
    "</svg>";

  function glossary() {
    var rows = [];
    function row(name, inner) { rows.push('<div class="gl"><span class="badge">' + iconSvg(name, "#eef2f7") + "</span><p>" + inner + "</p></div>"); }
    KR.LEADERS.forEach(function (t) { var d = T[t]; row(t, "<b>" + d.name + "</b> (leader). <b>" + d.pname + ":</b> " + d.ptext + " <b>" + d.aname + '</b><span class="cost">' + d.ac + "</span> " + d.atext); });
    KR.CREW.forEach(function (t) { var d = T[t]; row(t, "<b>" + d.name + '</b><span class="cost">' + d.cost + "</span>. <b>" + d.pname + ":</b> " + d.ptext + " <b>" + d.aname + '</b><span class="cost">' + d.ac + "</span> " + d.atext); });
    KR.GADGET_LIST.forEach(function (g) { var d = GD[g]; row(g, "<b>" + d.name + '</b><span class="cost">' + d.cost + "</span> " + d.text); });
    return '<div class="glossary">' + rows.join("") + "</div>";
  }

  var RULES = [
    "<h3>The goal</h3>",
    "<p>Both crews have a <b>safe</b> and a <b>key</b>. Your key opens <b>their</b> safe. You win at the start of your turn if:</p><ul>",
    "<li><b>Crack:</b> one of your units holding your key is on or next to their safe.</li>",
    "<li><b>Stash:</b> one of your units holding <b>their</b> key is standing on your own safe.</li></ul>",
    "<p>Wins land at the start of a turn, so the other side always gets one last turn to stop it.</p>",
    "<h3>A turn</h3>",
    "<p>You get <b>5 mana</b> every turn. Unspent mana carries over, up to 10. You can go into debt down to −3, and the debt comes out of your next turn.</p>",
    '<dl class="kv"><dt>Deploy</dt><dd>Play a crew card onto your two home rows, or next to one of your Lookouts or Getaway Drivers. Your leader never counts. New crew can\'t move or use abilities until your next turn. Up to 6 crew at once.</dd>',
    "<dt>Move · 1</dt><dd>Each unit moves once a turn, in its own pattern. Moving onto an enemy captures it and takes any key it holds.</dd>",
    "<dt>Pass · 1</dt><dd>Hand your key to a teammate up to 2 tiles away.</dd>",
    "<dt>Throw · 2</dt><dd>Throw your key up to 3 tiles in a straight line. The first unit in the way catches it, friend or foe. If nobody does, it lands on the floor for anyone to pick up.</dd>",
    "<dt>Ability</dt><dd>Each unit can use its ability once a turn, at the cost shown.</dd>",
    "<dt>Gadget</dt><dd>One card in your hand is always a gadget.</dd></dl>",
    "<h3>Keys</h3><ul>",
    "<li>Your leader starts the match holding your key.</li>",
    "<li>Keys are heavy. A unit carrying one moves only 1 tile and can't use movement abilities. The Runner and the Ghost ignore this.</li>",
    "<li>You can only pass or throw <b>your own</b> key, and not on a turn it changed hands. A stolen key has to be walked home.</li>",
    "<li>A unit that catches a pass or throw can't move again that turn (the Catcher can).</li>",
    "<li>Nobody can stand on their own safe, except to lock a stolen key away.</li></ul>",
    "<h3>Your deck</h3>",
    "<p>Before the match, pick a leader, 6 crew and 2 gadgets. You hold 3 crew and 1 gadget, and you only get the next 4 cards once you've used all 4. A card you can't use can be discarded for 1 mana.</p>",
    "<h3>Every card</h3>",
    "[[glossary]]",
    '<div class="tip">Keep your key moving, and keep friends next to whoever carries it. A carrier alone in the middle of the board is the easiest steal in the game. A red <b>!</b> on a unit means the enemy can reach it next turn.</div>'
  ].join("");

  var G = {
    st: null, cfg: null, level: "normal", human: [true, false], viewer: 0, decks: [null, null], rand: null,
    sel: -1, card: -1, mode: null, hookUnit: -1, areaPick: -1, inspect: -1,
    undo: [], busy: true, token: 0, nodes: {}, layers: {}, say: "", sayCls: "", trails: [], resolver: null, review: false, targets: null, paused: false
  };
  async function waitUnpaused(token) { while (G.paused && token === G.token) await K.sleep(150); }

  /* ---------- Geometry (the board turns around for Red in pass-and-play) ---------- */
  function disp(t) { return G.viewer === 1 ? KR.N - 1 - t : t; }
  function cx(t) { return PAD + KR.cOf(disp(t)) * S + S / 2; }
  function cy(t) { return PAD + KR.rOf(disp(t)) * S + S / 2; }
  function sideWord(s) { return '<b style="color:var(--' + (s ? "red" : "blue") + ')">' + NAME[s] + "</b>"; }
  function shortName(t) { return T[t].leader ? T[t].name.replace(/^The /, "") : T[t].name; }
  function uName(u) { return sideWord(u.side) + " " + shortName(u.type); }
  function isHumanTurn() { return G.st && G.st.winner == null && G.human[G.st.side] && !G.busy && !!G.resolver; }
  function mySide() { return G.cfg && G.cfg.mode === "local" ? G.st.side : (G.human[0] ? 0 : 1); }

  /* ---------- Board ---------- */
  function keyGlyph(k, x, y, scale, cls) {
    var g = sv("g", { class: cls || "", transform: "translate(" + x + " " + y + ") rotate(-35) scale(" + (scale || 1) + ")" });
    g.appendChild(sv("rect", { class: "key-shaft", x: "1", y: "-1.8", width: "10", height: "3.6", rx: "1.2" }));
    g.appendChild(sv("rect", { class: "key-shaft", x: "8", y: "0", width: "2.2", height: "4.4" }));
    g.appendChild(sv("circle", { class: "key-bow k" + k, cx: "-1.8", cy: "0", r: "4.4" }));
    return g;
  }

  function buildBoard() {
    var stage = K.$("#stage");
    stage.innerHTML = "";
    var svg = sv("svg", { id: "board", viewBox: "0 0 " + VBW + " " + VBH, role: "img", "aria-label": "Heist floor, 7 by 10 tiles" });
    var tiles = sv("g");
    for (var t = 0; t < KR.N; t++) {
      var x = cx(t) - S / 2, y = cy(t) - S / 2;
      tiles.appendChild(sv("rect", { x: x, y: y, width: S, height: S, class: (KR.cOf(t) + KR.rOf(t)) % 2 ? "tl-b" : "tl-a" }));
      if (KR.IS_HOME[0][t]) tiles.appendChild(sv("rect", { x: x, y: y, width: S, height: S, class: "home0" }));
      if (KR.IS_HOME[1][t]) tiles.appendChild(sv("rect", { x: x, y: y, width: S, height: S, class: "home1" }));
    }
    for (var k = 0; k <= KR.W; k++) tiles.appendChild(sv("path", { d: "M" + (PAD + k * S) + " " + PAD + "V" + (PAD + KR.H * S), class: "gridl" }));
    for (var r = 0; r <= KR.H; r++) tiles.appendChild(sv("path", { d: "M" + PAD + " " + (PAD + r * S) + "H" + (PAD + KR.W * S), class: "gridl" }));
    [0, 1].forEach(function (s) {
      var sf = KR.SAFE[s], zone = [];
      for (var q = 0; q < KR.N; q++) if (KR.cheb(q, sf) <= KR.CFG.crackRange) zone.push(q);
      var xs = zone.map(function (q) { return cx(q); }), ys = zone.map(function (q) { return cy(q); });
      var x0 = Math.min.apply(null, xs) - S / 2 + 2, x1 = Math.max.apply(null, xs) + S / 2 - 2;
      var y0 = Math.min.apply(null, ys) - S / 2 + 2, y1 = Math.max.apply(null, ys) + S / 2 - 2;
      tiles.appendChild(sv("rect", { x: x0, y: y0, width: x1 - x0, height: y1 - y0, rx: 8, class: "zone s" + s }));
      var X = cx(sf), Y = cy(sf);
      tiles.appendChild(sv("rect", { x: X - 19, y: Y - 19, width: 38, height: 38, rx: 7, class: "safe-box s" + s }));
      tiles.appendChild(sv("circle", { cx: X, cy: Y, r: 9.5, class: "safe-dial" }));
      tiles.appendChild(sv("path", { d: "M" + X + " " + (Y - 15) + "v4M" + X + " " + (Y + 11) + "v4M" + (X - 15) + " " + Y + "h4M" + (X + 11) + " " + Y + "h4", class: "safe-tick" }));
    });
    svg.appendChild(tiles);
    ["marks", "hl", "units", "fx"].forEach(function (n) { var g = sv("g", { class: n }); G.layers[n] = g; svg.appendChild(g); });
    var hit = sv("g", { class: "hit-layer" });
    for (var j = 0; j < KR.N; j++) hit.appendChild(sv("rect", { x: cx(j) - S / 2, y: cy(j) - S / 2, width: S, height: S, "data-t": String(j) }));
    hit.addEventListener("click", function (e) { var el = e.target; if (el && el.getAttribute("data-t") != null) onTile(+el.getAttribute("data-t")); });
    svg.appendChild(hit);
    stage.appendChild(svg);
    G.nodes = {};
  }

  function tokNode(u) {
    var n = G.nodes[u.id];
    if (n && n.__side !== u.side) { n.remove(); n = null; }
    if (n) return n;
    n = sv("g", { class: "tok" });
    n.__side = u.side;
    n.appendChild(sv("circle", { class: "tok-ring", r: "22" }));
    n.appendChild(sv("circle", { class: "tok-ready", r: "22" }));
    n.appendChild(sv("circle", { class: "tok-brace", r: "23.5" }));
    n.appendChild(sv("circle", { class: "tok-carry", r: "22.5" }));
    n.appendChild(sv("circle", { class: "tok-body s" + u.side, r: "18" }));
    if (u.leader) n.appendChild(sv("circle", { class: "tok-lead", r: "15.2" }));
    n.appendChild(sv("circle", { class: "tok-glitch", r: "20.5" }));
    var ic = sv("g", { class: "tok-icon", transform: "translate(-10.2 -10.2) scale(.85)" });
    ic.innerHTML = ICON[u.type];
    n.appendChild(ic);
    n.appendChild(sv("rect", { class: "tok-armor", x: "-7", y: "13", width: "14", height: "6", rx: "2" }));
    var stunG = sv("g", { class: "tok-stun" });
    stunG.appendChild(sv("path", { d: "M-9 -22l3-3 3 3 3-3 3 3 3-3 3 3" }));
    n.appendChild(stunG);
    n.appendChild(keyGlyph(0, 13, -13, 1.25, "tok-key k0"));
    n.appendChild(keyGlyph(1, 13, 14, 1.25, "tok-key k1"));
    var dg = sv("g", { class: "tok-danger", transform: "translate(-14 -14)" });
    dg.appendChild(sv("circle", { r: "7" }));
    dg.appendChild(sv("text", { x: "0", y: "4", "text-anchor": "middle", text: "!" }));
    n.appendChild(dg);
    var fr = sv("g", { class: "tok-fresh", transform: "translate(0 22)" });
    fr.appendChild(sv("rect", { x: "-11", y: "-5.5", width: "22", height: "11", rx: "5.5" }));
    fr.appendChild(sv("text", { x: "0", y: "3", "text-anchor": "middle", text: "NEW" }));
    n.appendChild(fr);
    G.layers.units.appendChild(n);
    G.nodes[u.id] = n;
    n.style.transform = "translate(" + cx(u.pos) + "px," + cy(u.pos) + "px)";
    return n;
  }

  function canDoAnything(st, u) {
    if (u.side !== st.side) return false;
    if (KR.canMove(st, u) && KR.moveTargets(st, u).length) return true;
    if (KR.canAct(st, u) && KR.abilityTargets(st, u).length) return true;
    if (KR.passTargets(st, u).length || KR.throwOptions(st, u).length) return true;
    return false;
  }

  function placeUnits() {
    var st = G.st, live = {}, human = isHumanTurn();
    var danger = human ? KR.dangerTo(st, st.side) : {};
    st.units.forEach(function (u) {
      live[u.id] = 1;
      var n = tokNode(u);
      var mine = u.side === st.side;
      n.classList.toggle("sel", u.id === G.sel || u.id === G.inspect);
      n.classList.toggle("k0", st.keys[0].h === u.id);
      n.classList.toggle("k1", st.keys[1].h === u.id);
      n.classList.toggle("carrier", st.keys[0].h === u.id || st.keys[1].h === u.id);
      n.classList.toggle("stunned", KR.stunned(st, u) || (st.ply + 1 < u.st && !mine));
      n.classList.toggle("braced", KR.braced(st, u));
      n.classList.toggle("glitched", KR.glitched(st, u));
      n.classList.toggle("armored", !!u.armor);
      n.classList.toggle("fresh", mine && u.fr === st.ply);
      n.classList.toggle("danger", human && mine && !!danger[u.id]);
      var ready = human && mine && canDoAnything(st, u);
      n.classList.toggle("ready", ready && u.id !== G.sel);
      n.classList.toggle("spent", human && mine && !ready);
      n.style.transform = "translate(" + cx(u.pos) + "px," + cy(u.pos) + "px)";
    });
    Object.keys(G.nodes).forEach(function (id) {
      if (live[id]) return;
      var n = G.nodes[id];
      delete G.nodes[id];
      n.classList.add("dying");
      setTimeout(function () { n.remove(); }, 420);
    });
  }

  function renderMarks() {
    var g = G.layers.marks, st = G.st;
    g.innerHTML = "";
    st.smokes.forEach(function (sm) {
      if (st.ply >= sm.until) return;
      var xs = [], ys = [];
      for (var t = 0; t < KR.N; t++) if (KR.cheb(t, sm.c) <= 1) { xs.push(cx(t)); ys.push(cy(t)); }
      var x0 = Math.min.apply(null, xs) - S / 2 + 3, y0 = Math.min.apply(null, ys) - S / 2 + 3;
      g.appendChild(sv("rect", { x: x0, y: y0, width: Math.max.apply(null, xs) + S / 2 - 3 - x0, height: Math.max.apply(null, ys) + S / 2 - 3 - y0, rx: 14, class: "smoke" }));
    });
    var viewer = mySide();
    st.traps.forEach(function (tr) {
      if (tr.side !== viewer || (G.cfg.mode === "local" && !isHumanTurn() && !G.review)) return;
      var X = cx(tr.t), Y = cy(tr.t);
      g.appendChild(sv("path", { d: "M" + (X - 9) + " " + (Y - 9) + "l18 18M" + (X + 9) + " " + (Y - 9) + "l-18 18", class: "trap" }));
    });
    G.trails.forEach(function (tr) {
      g.appendChild(sv("path", { d: "M" + cx(tr.from) + " " + cy(tr.from) + "L" + cx(tr.to) + " " + cy(tr.to), class: "trail s" + tr.side }));
    });
    for (var k = 0; k < 2; k++) {
      var K0 = st.keys[k];
      if (K0.h < 0) g.appendChild(keyGlyph(k, cx(K0.at) - 4, cy(K0.at), 1.6, "gkey pulse"));
    }
  }

  /* ---------- Targets for whatever is selected ---------- */
  function computeTargets() {
    var st = G.st, out = { list: [], map: {} };
    if (!isHumanTurn()) return out;
    var s = st.side, u = G.sel >= 0 ? KR.unit(st, G.sel) : null;
    function add(t, cls, act) { out.list.push({ t: t, cls: cls }); if (act) out.map[t] = act; }
    var spend = st.mana[s] + KR.CFG.debt;
    if (u && G.mode === "move" && spend >= KR.CFG.moveCost) {
      KR.moveTargets(st, u).forEach(function (t) { add(t, st.board[t] >= 0 ? "cap" : "move", { t: "move", u: u.id, to: t }); });
    } else if (u && G.mode === "ab" && spend >= T[u.type].ac) {
      KR.abilityTargets(st, u).forEach(function (t) { add(t, "ab", { t: "ab", u: u.id, to: t }); });
    } else if (u && G.mode === "pass" && spend >= KR.CFG.passCost) {
      KR.passTargets(st, u).forEach(function (t) { add(t, "pass", { t: "pass", u: u.id, to: t }); });
    } else if (u && G.mode === "throw" && spend >= KR.CFG.throwCost) {
      KR.throwOptions(st, u).forEach(function (o) {
        var by = o.by >= 0 ? KR.unit(st, o.by) : null;
        add(o.to, by ? (by.side === s ? "throw-ok" : "throw-bad") : "throw-ground", { t: "throw", u: u.id, to: o.to });
      });
    } else if (G.card >= 0) {
      var card = st.hands[s][G.card];
      if (!card) return out;
      if (card.k === "crew" && spend >= T[card.t].cost) {
        KR.deployTiles(st, s).forEach(function (t) { add(t, "deploy", { t: "deploy", c: G.card, to: t }); });
      } else if (card.k === "gadget" && spend >= GD[card.t].cost) {
        var gt = KR.gadgetTargets(st, s, card.t);
        if (card.t === "hook") {
          if (G.hookUnit < 0) {
            var seen = {};
            gt.forEach(function (x) { if (!seen[x.u]) { seen[x.u] = 1; var hu = KR.unit(st, x.u); add(hu.pos, "pick", { hook: x.u }); } });
          } else {
            gt.forEach(function (x) { if (x.u === G.hookUnit) add(x.to, "ab", { t: "gadget", c: G.card, u: x.u, to: x.to }); });
          }
        } else if (card.t === "smoke" || card.t === "emp") {
          gt.forEach(function (t) { add(t, "dim", G.areaPick === t ? { t: "gadget", c: G.card, to: t } : { area: t }); });
        } else if (card.t !== "alarm") {
          gt.forEach(function (t) { add(t, "ab", { t: "gadget", c: G.card, to: t }); });
        }
      }
    }
    return out;
  }

  function enemyReach(u) {
    var c = KR.cloneState(G.st);
    c.ply += 1; c.side = u.side;
    var cu = KR.unit(c, u.id);
    return KR.moveTargets(c, cu, false, true);
  }

  function renderHL() {
    var g = G.layers.hl;
    g.innerHTML = "";
    var tg = G.targets = computeTargets();
    if (G.inspect >= 0) {
      var eu = KR.unit(G.st, G.inspect);
      if (eu) enemyReach(eu).forEach(function (t) { g.appendChild(sv("rect", { x: cx(t) - S / 2 + 3, y: cy(t) - S / 2 + 3, width: S - 6, height: S - 6, rx: 6, class: "hl-reach" })); });
    }
    tg.list.forEach(function (x) {
      var X = cx(x.t), Y = cy(x.t);
      if (x.cls === "move") g.appendChild(sv("circle", { cx: X, cy: Y, r: 6.5, class: "hl-move" }));
      else if (x.cls === "cap") g.appendChild(sv("circle", { cx: X, cy: Y, r: 21, class: "hl-cap" }));
      else if (x.cls === "pass") g.appendChild(sv("circle", { cx: X, cy: Y, r: 23, class: "hl-pass" }));
      else if (x.cls === "pick") g.appendChild(sv("circle", { cx: X, cy: Y, r: 23, class: "hl-pick" }));
      else if (x.cls === "deploy") g.appendChild(sv("rect", { x: X - S / 2 + 4, y: Y - S / 2 + 4, width: S - 8, height: S - 8, rx: 7, class: "hl-deploy s" + G.st.side }));
      else if (x.cls === "dim") g.appendChild(sv("rect", { x: X - S / 2 + 2, y: Y - S / 2 + 2, width: S - 4, height: S - 4, rx: 5, class: "hl-dim" }));
      else if (x.cls.indexOf("throw") === 0) {
        g.appendChild(sv("circle", { cx: X, cy: Y, r: 9, class: "hl-" + x.cls }));
      } else g.appendChild(sv("rect", { x: X - S / 2 + 4, y: Y - S / 2 + 4, width: S - 8, height: S - 8, rx: 7, class: "hl-ab" }));
    });
    if (G.areaPick >= 0) {
      for (var t = 0; t < KR.N; t++) if (KR.cheb(t, G.areaPick) <= 1) g.appendChild(sv("rect", { x: cx(t) - S / 2 + 2, y: cy(t) - S / 2 + 2, width: S - 4, height: S - 4, rx: 5, class: "hl-area" }));
    }
  }

  /* ---------- Top bar and action bar ---------- */
  function renderTop() {
    var st = G.st, main, sub;
    var round = "Round " + KR.round(st) + " of " + KR.CFG.rounds;
    if (st.winner != null) { main = st.winner === "draw" ? "Draw" : NAME[st.winner] + " wins"; sub = st.reason; }
    else if (G.human[st.side]) { main = G.cfg.mode === "local" ? NAME[st.side] + "'s turn" : "Your turn"; sub = round; }
    else { main = NAME[st.side] + " is planning"; sub = round; }
    K.$("#st-main").textContent = main;
    K.$("#st-sub").textContent = sub;
    var foe = K.$("#foe");
    foe.innerHTML = "";
    var o = G.cfg.mode === "local" ? 1 - st.side : 1 - mySide();
    var L = KR.leaderOf(st, o), lt = L ? L.type : G.decks[o].leader;
    var m = st.mana[o];
    foe.appendChild(h("div", { class: "foe", title: NAME[o] + "'s mana and cards" },
      h("span", { class: "dot s" + o, html: iconSvg(lt, "#fff") }),
      h("b", null, String(m)), h("small", null, "mana"),
      h("b", null, String(st.hands[o].length)), h("small", null, st.hands[o].length === 1 ? "card" : "cards")));
  }

  function statusChips(st, u) {
    var c = [];
    if (u.fr === st.ply && u.side === st.side) c.push("just arrived");
    if (KR.stunned(st, u)) c.push("stunned");
    if (KR.glitched(st, u)) c.push("glitched");
    if (KR.braced(st, u)) c.push("braced");
    if (u.armor) c.push("armored");
    if (u.side === st.side && u.mv === st.ply && u.fr !== st.ply) c.push("moved");
    if (u.side === st.side && u.ac === st.ply) c.push("ability used");
    return c;
  }

  function fullText(kind, t) {
    var d = kind === "gadget" ? GD[t] : T[t];
    var body = kind === "gadget" ? "<p>" + d.text + "</p><p>Costs " + d.cost + " mana.</p>" :
      "<p><b>" + d.pname + ":</b> " + d.ptext + "</p><p><b>" + d.aname + " (" + d.ac + " mana):</b> " + d.atext + "</p>" + (d.cost ? "<p>Deploys for " + d.cost + " mana.</p>" : "<p>Your leader starts the match holding your key.</p>");
    K.modal({ title: d.name, body: body, bodyClass: "rules", actions: [{ label: "Close", value: null, kind: "primary" }] });
  }

  function unitInfo(u) {
    var d = T[u.type], st = G.st;
    var chips = statusChips(st, u).map(function (x) { return h("span", { class: "st" }, x); });
    var keys = KR.keysOf(st, u).map(function (k) { return h("span", { class: "tag" }, k === u.side ? "has the key" : "has " + NAME[k] + "'s key"); });
    var txt = h("div", { class: "txt" },
      h("div", { class: "nm" }, h("b", null, d.name), u.leader ? h("span", { class: "tag" }, "leader") : null, keys, chips),
      h("p", { html: "<b>" + d.pname + ":</b> " + d.ps }),
      h("p", { html: "<b>" + d.aname + " (" + d.ac + "):</b> " + d.as }));
    return h("button", { class: "info", type: "button", "aria-label": d.name + ": read the full card", onclick: function () { K.Sound.play("tap"); fullText("unit", u.type); } },
      h("span", { class: "badge s" + u.side, html: iconSvg(u.type, "#fff") }), txt, h("span", { class: "more", "aria-hidden": "true" }, "i"));
  }

  function cardInfo(card) {
    var d = card.k === "crew" ? T[card.t] : GD[card.t];
    var txt = card.k === "crew"
      ? h("div", { class: "txt" }, h("div", { class: "nm" }, h("b", null, d.name), h("span", { class: "tag" }, "crew · " + d.cost + " mana")),
          h("p", { html: "<b>" + d.pname + ":</b> " + d.ps }), h("p", { html: "<b>" + d.aname + " (" + d.ac + "):</b> " + d.as }))
      : h("div", { class: "txt" }, h("div", { class: "nm" }, h("b", null, d.name), h("span", { class: "tag" }, "gadget · " + d.cost + " mana")), h("p", null, d.text));
    return h("button", { class: "info", type: "button", "aria-label": d.name + ": read the full card", onclick: function () { K.Sound.play("tap"); fullText(card.k === "crew" ? "unit" : "gadget", card.t); } },
      h("span", { class: "badge g", html: iconSvg(card.t, "#f2b840") }), txt, h("span", { class: "more", "aria-hidden": "true" }, "i"));
  }

  function keyLine(k, viewer) {
    var st = G.st, K0 = st.keys[k];
    var who = k === viewer ? "Your key" : NAME[k] + "'s key";
    if (K0.h < 0) return "<b>" + who + ":</b> on the floor";
    var u = KR.unit(st, K0.h), mine = u.side === viewer;
    var where;
    if (u.side === k) where = KR.cheb(u.pos, KR.SAFE[1 - k]) + " tiles from " + (k === viewer ? "their" : "your") + " safe";
    else where = "stolen, " + KR.cheb(u.pos, KR.SAFE[u.side]) + " tiles from " + (mine ? "your" : "their") + " safe";
    return "<b>" + who + ":</b> " + (mine ? "your " : NAME[u.side] + " ") + shortName(u.type) + ", " + where;
  }

  function statusCard() {
    var v = mySide();
    return h("div", { class: "info static" }, h("span", { class: "badge g", html: iconSvg("key", "#f2b840") }),
      h("div", { class: "txt" }, h("p", { html: keyLine(v, v) }), h("p", { html: keyLine(1 - v, v) }),
        h("p", { class: "dim" }, "Crack: your key next to their safe. Stash: their key on your safe.")));
  }

  function btn(label, cost, opts) {
    opts = opts || {};
    return h("button", { class: "btn btn-sm" + (opts.primary ? " btn-primary" : ""), type: "button", disabled: opts.disabled ? true : null, "aria-pressed": opts.pressed == null ? null : (opts.pressed ? "true" : "false"), onclick: opts.onclick },
      label, cost != null ? h("span", { class: "c" }, String(cost)) : null);
  }

  function hint() {
    var st = G.st, s = st.side, o = 1 - s;
    var their = st.keys[o].h >= 0 ? KR.unit(st, st.keys[o].h) : null;
    var mine = st.keys[s].h >= 0 ? KR.unit(st, st.keys[s].h) : null;
    if (their && their.side === o && KR.cheb(their.pos, KR.SAFE[s]) <= KR.CFG.crackRange) return { t: NAME[o] + "'s key is at your safe. Move it or take it out this turn, or " + NAME[o] + " cracks it.", c: "warn" };
    if (mine && mine.side === o && mine.pos === KR.SAFE[o]) return { t: NAME[o] + " is locking your key away. Win it back this turn or lose.", c: "warn" };
    if (mine && mine.side === s && KR.cheb(mine.pos, KR.SAFE[o]) <= KR.CFG.crackRange) return { t: "Your key is at their safe. If it's still there when your next turn starts, you crack it.", c: "good" };
    if (their && their.side === s && their.pos === KR.SAFE[s]) return { t: "Their key is on your safe. Keep it there until your next turn to lock it away.", c: "good" };
    if (st.mana[s] + KR.CFG.debt < 1) return { t: "You're out of mana. End your turn.", c: "" };
    if (KR.round(st) === 1 && st.units.filter(function (u) { return u.side === s; }).length === 1) return { t: "Your leader holds your key. Deploy crew from your hand first: tap a card, then a lit tile.", c: "" };
    return { t: "Tap a unit to act or a card to play.", c: "" };
  }

  function modeTip() {
    var st = G.st, u = G.sel >= 0 ? KR.unit(st, G.sel) : null;
    if (u) {
      if (G.mode === "move") return "Dots: move there. Red rings: capture.";
      if (G.mode === "ab") return "Tap a gold tile to use " + T[u.type].aname + ".";
      if (G.mode === "pass") return "Tap a teammate within 2 tiles to hand over your key.";
      if (G.mode === "throw") return "Green: a teammate catches it. Red: intercepted. Grey: lands on the floor.";
      return KR.canMove(st, u) ? "" : "This unit can't move again this turn.";
    }
    if (G.card >= 0) {
      var card = st.hands[st.side][G.card];
      if (!card) return "";
      var c = card.k === "crew" ? T[card.t].cost : GD[card.t].cost, spend = st.mana[st.side] + KR.CFG.debt;
      if (spend < c) return "Not enough mana. You can go down to −" + KR.CFG.debt + ".";
      if (card.k === "crew") return KR.crewCount(st, st.side) >= KR.CFG.maxCrew ? "You already have 6 crew out." : "Tap a lit tile to deploy. New crew act from your next turn.";
      if (card.t === "hook") return G.hookUnit < 0 ? "Pick the unit to zip." : "Pick where it lands.";
      if (card.t === "smoke" || card.t === "emp") return G.areaPick < 0 ? "Tap the middle of the 3×3 area." : "Tap the same tile again to confirm.";
      if (card.t === "tripwire") return "Tap a tile to hide the trap. Only you can see it.";
      if (card.t === "bribe") return "Tap an enemy crew member next to your leader.";
      if (card.t === "alarm") return "Pushes every enemy within 2 tiles of your safe back 1 tile.";
    }
    return "";
  }

  function renderBar() {
    var bar = K.$("#actionbar"), st = G.st;
    bar.innerHTML = "";
    if (G.review || st.winner != null) {
      bar.appendChild(h("p", { class: "say" }, h("span", { html: G.say || st.reason || "&nbsp;" })));
      bar.appendChild(h("div", { class: "ctx" }, statusCard()));
      bar.appendChild(h("div", { class: "bottom" },
        h("button", { class: "btn btn-primary", type: "button", style: "flex:1", onclick: function () { restart(); } }, "Rematch"),
        h("button", { class: "btn", type: "button", style: "flex:1", onclick: function () { K.quit(); } }, "Main menu")));
      return;
    }
    var human = isHumanTurn(), s = human ? st.side : mySide();
    var say = h("p", { class: "say" + (G.sayCls ? " " + G.sayCls : "") }), line = h("span");
    say.appendChild(line);
    var tip = human ? modeTip() : "";
    if (tip) { say.className = "say"; line.textContent = tip; }
    else if (G.say) line.innerHTML = G.say;
    else if (human) { var hn = hint(); say.className = "say" + (hn.c ? " " + hn.c : ""); line.textContent = hn.t; }
    else line.innerHTML = "&nbsp;";
    bar.appendChild(say);

    var spend = st.mana[s] + KR.CFG.debt;
    var ctx = h("div", { class: "ctx" });
    var u = G.sel >= 0 ? KR.unit(st, G.sel) : null;
    if (human && u) {
      var d = T[u.type], acts = h("div", { class: "acts" });
      var abT = KR.abilityTargets(st, u);
      acts.appendChild(btn("Move", 1, { pressed: G.mode === "move", disabled: !KR.canMove(st, u) || spend < 1 || !KR.moveTargets(st, u).length, onclick: function () { setMode("move"); } }));
      var abReady = KR.canAct(st, u) && spend >= d.ac && abT.length > 0;
      var noTarget = d.ab === "brace" || d.ab === "insideman";
      acts.appendChild(btn(d.aname, d.ac, { pressed: G.mode === "ab", disabled: !abReady, onclick: function () {
        if (noTarget) doHuman({ t: "ab", u: u.id, to: abT[0] }); else setMode("ab");
      } }));
      if (KR.looseKeys(st, u).length) {
        acts.appendChild(btn("Pass", KR.CFG.passCost, { pressed: G.mode === "pass", disabled: spend < KR.CFG.passCost || !KR.passTargets(st, u).length, onclick: function () { setMode("pass"); } }));
        acts.appendChild(btn("Throw", KR.CFG.throwCost, { pressed: G.mode === "throw", disabled: spend < KR.CFG.throwCost || !KR.throwOptions(st, u).length, onclick: function () { setMode("throw"); } }));
      }
      ctx.appendChild(unitInfo(u));
      ctx.appendChild(acts);
    } else if (G.inspect >= 0 && KR.unit(st, G.inspect)) {
      ctx.appendChild(unitInfo(KR.unit(st, G.inspect)));
      ctx.appendChild(h("p", { class: "note" }, "Shaded tiles: where it can move or capture on its next turn."));
    } else if (human && G.card >= 0 && st.hands[s][G.card]) {
      var card = st.hands[s][G.card], row = h("div", { class: "acts" });
      var c = card.k === "crew" ? T[card.t].cost : GD[card.t].cost;
      if (card.t === "alarm") row.appendChild(btn("Sound the alarm", c, { primary: true, disabled: spend < c, onclick: function () { doHuman({ t: "gadget", c: G.card, to: -1 }); } }));
      row.appendChild(btn("Discard", KR.CFG.burnCost, { disabled: spend < KR.CFG.burnCost, onclick: function () { doHuman({ t: "burn", c: G.card }); } }));
      ctx.appendChild(cardInfo(card));
      ctx.appendChild(row);
    } else {
      ctx.appendChild(statusCard());
    }
    bar.appendChild(ctx);

    var hand = h("div", { class: "hand" }), cards = st.hands[s];
    var showHand = G.cfg.mode !== "local" || human;
    for (var i = 0; i < 4; i++) {
      var cd = showHand ? cards[i] : null;
      if (!cd) { hand.appendChild(h("div", { class: "card empty", "aria-hidden": "true" })); continue; }
      (function (idx, cd2) {
        var cost = cd2.k === "crew" ? T[cd2.t].cost : GD[cd2.t].cost;
        hand.appendChild(h("button", {
          class: "card" + (cd2.k === "gadget" ? " gadget" : "") + (st.mana[s] + KR.CFG.debt < cost ? " poor" : ""), type: "button",
          "aria-pressed": G.card === idx && human ? "true" : "false", disabled: human ? null : true,
          "aria-label": (cd2.k === "crew" ? T[cd2.t].name : GD[cd2.t].name) + ", " + cost + " mana",
          onclick: function () { selectCard(idx); }
        }, h("span", { class: "cost" }, String(cost)), h("span", { html: iconSvg(cd2.t, cd2.k === "gadget" ? "#f2b840" : "#eef2f7") }), h("span", { class: "nm" }, cd2.k === "crew" ? T[cd2.t].name : GD[cd2.t].name)));
      })(i, cd);
    }
    bar.appendChild(hand);
    var nx = st.pend[s];
    bar.appendChild(h("p", { class: "next" }, !showHand ? "\u00a0" : nx ? "Up next: " + nx.map(function (c2) { return c2.k === "crew" ? T[c2.t].name : GD[c2.t].name; }).join(" · ") : "Up next: a fresh shuffle of your 8 cards"));

    var m = st.mana[s];
    var pips = h("div", { class: "pips", "aria-hidden": "true" });
    for (var p = 0; p < KR.CFG.cap; p++) pips.appendChild(h("i", { class: "pip" + (m > 0 && p < m ? " on" : "") + (m < 0 && p < -m ? " debt" : "") }));
    var L = KR.leaderOf(st, s), inc = KR.CFG.income + (L && L.type === "fixer" && !KR.glitched(st, L) ? 1 : 0);
    var mana = h("div", { class: "mana" },
      h("div", { class: "lbl" }, h("span", null, m < 0 ? "Debt" : "Mana"), h("b", { class: m < 0 ? "neg" : "" }, (m < 0 ? "−" + (-m) : String(m)) + " / " + KR.CFG.cap), h("span", null, "+" + inc + " next")), pips);
    var undo = h("button", { class: "btn", id: "btn-undo", type: "button", disabled: human && G.undo.length ? null : true, onclick: function () { doUndo(); } }, "Undo");
    var end = h("button", { class: "btn btn-primary", id: "btn-end", type: "button", disabled: human ? null : true, onclick: function () { endTurnClicked(); } }, "End turn");
    bar.appendChild(h("div", { class: "bottom" }, mana, undo, end));
  }

  function render() {
    if (!G.st) return;
    renderMarks();
    renderHL();
    placeUnits();
    renderTop();
    renderBar();
  }

  /* ---------- Input ---------- */
  function clearSel() { G.sel = -1; G.card = -1; G.mode = null; G.hookUnit = -1; G.areaPick = -1; G.inspect = -1; }
  function selectUnit(id) {
    var keepCard = false;
    clearSel();
    G.sel = id;
    var u = KR.unit(G.st, id);
    G.mode = KR.canMove(G.st, u) && KR.moveTargets(G.st, u).length ? "move" : null;
    if (!keepCard) G.say = "";
    G.sayCls = "";
    K.Sound.play("select");
    render();
  }
  function selectCard(i) {
    if (!isHumanTurn()) return;
    var was = G.card === i;
    clearSel();
    if (!was) { G.card = i; K.Sound.play("select"); } else K.Sound.play("tap");
    G.say = "";
    render();
  }
  function setMode(m) {
    if (!isHumanTurn()) return;
    G.mode = G.mode === m ? (m === "move" ? "move" : "move") : m;
    var u = KR.unit(G.st, G.sel);
    if (G.mode === "move" && u && !KR.canMove(G.st, u)) G.mode = null;
    K.Sound.play("tap");
    render();
  }

  function onTile(t) {
    var st = G.st;
    if (!st) return;
    var u = KR.at(st, t);
    if (!isHumanTurn()) {
      if (u && u.side !== mySide() && !G.review) { G.inspect = G.inspect === u.id ? -1 : u.id; render(); }
      return;
    }
    var act = G.targets && G.targets.map[t];
    if (act) {
      if (act.hook != null) { G.hookUnit = act.hook; K.Sound.play("tap"); render(); return; }
      if (act.area != null) { G.areaPick = act.area; K.Sound.play("tap"); render(); return; }
      doHuman(act);
      return;
    }
    if (u && u.side === st.side) { if (G.sel === u.id) { clearSel(); render(); } else selectUnit(u.id); return; }
    if (u) { clearSel(); G.inspect = u.id; K.Sound.play("tap"); render(); return; }
    if (G.sel >= 0 || G.card >= 0 || G.inspect >= 0) { clearSel(); render(); }
  }

  async function doHuman(a) {
    if (!isHumanTurn()) return;
    if (!KR.isLegal(G.st, a)) { K.Sound.play("error"); K.toast("That move isn't allowed right now."); return; }
    G.busy = true;
    G.undo.push({ st: KR.cloneState(G.st), say: G.say });
    if (G.undo.length > 40) G.undo.shift();
    G.trails = [];
    G.st.revealed = false; G.st.drew = false;
    var keepSel = a.t === "move" || a.t === "ab" || a.t === "pass" || a.t === "throw" ? a.u : -1;
    clearSel();
    await perform(a, G.token);
    if (G.st.revealed || G.st.drew) G.undo = [];
    G.busy = false;
    if (keepSel >= 0) {
      var u = KR.unit(G.st, keepSel);
      if (u && u.side === G.st.side && canDoAnything(G.st, u)) { G.sel = keepSel; G.mode = KR.canMove(G.st, u) && KR.moveTargets(G.st, u).length ? "move" : null; }
    }
    render();
  }

  function doUndo() {
    if (!isHumanTurn() || !G.undo.length) return;
    var snap = G.undo.pop();
    G.st = snap.st;
    G.say = snap.say || "";
    G.sayCls = "";
    clearSel();
    K.Sound.play("slide");
    render();
  }

  function endTurnClicked() {
    if (!isHumanTurn()) return;
    var r = G.resolver;
    G.resolver = null;
    G.busy = true;
    clearSel();
    K.Sound.play("tap");
    r();
  }

  /* ---------- Performing actions, with words and effects ---------- */
  function describe(a, ev, before, side) {
    var st = G.st;
    function nm(id) { var u = KR.unit(st, id) || KR.unit(before, id); return u ? uName(u) : "a unit"; }
    var parts = [], cls = "";
    var hidden = G.cfg.mode !== "local" && side !== mySide();
    ev.forEach(function (e) {
      switch (e.e) {
        case "deploy": parts.push(sideWord(e.side) + " deploys a " + shortName(e.type) + "."); break;
        case "capture":
          var took = e.keys && e.keys.length;
          parts.push(nm(e.u) + " captures " + sideWord(e.side) + " " + shortName(e.type) + (took ? (e.keys[0] === side ? " and wins the key back!" : " and steals the key!") : "."));
          if (took) cls = e.keys[0] === mySide() && G.cfg.mode !== "local" ? "warn" : "good";
          break;
        case "bounce": parts.push(nm(e.o) + "'s armor stops " + nm(e.u) + "."); break;
        case "out": if (e.cause !== "capture") parts.push(sideWord(e.side) + " " + shortName(e.type) + " is taken out" + (e.cause === "trap" ? " by a tripwire!" : "!")); break;
        case "armor": parts.push(nm(e.u) + "'s armor takes the hit."); break;
        case "trap": parts.push("Tripwire!"); break;
        case "pass":
          if (e.how === "swipe") parts.push(nm(e.to) + " swipes the key from " + nm(e.from) + "!");
          else if (e.how === "call") parts.push(nm(e.to) + " calls for the key.");
          else parts.push(nm(e.from) + " passes the key to " + nm(e.to) + ".");
          break;
        case "throw":
          if (e.by < 0) parts.push("The key lands on the floor.");
          else { var c = KR.unit(st, e.by); parts.push(c && c.side !== side ? "Intercepted! " + nm(e.by) + " grabs the key." : nm(e.by) + " catches the key."); }
          break;
        case "pickup": parts.push(nm(e.u) + " picks up the key."); break;
        case "ability":
          var ab = T[(KR.unit(st, e.u) || KR.unit(before, e.u)).type].aname;
          var tgt = KR.unit(before, before.board[e.at]);
          if (e.ab === "brace") parts.push(nm(e.u) + " braces.");
          else if (e.ab === "glitch") parts.push(nm(e.u) + " glitches " + (tgt ? uName(tgt) : "a unit") + ".");
          else if (e.ab === "orders") parts.push(nm(e.u) + " orders " + (tgt ? uName(tgt) : "a unit") + " to move again.");
          else if (e.ab === "insideman") parts.push(nm(e.u) + ": deploy next to any crew this turn.");
          else if (e.ab === "switch" || e.ab === "vanish") parts.push(nm(e.u) + " swaps places with " + (tgt ? uName(tgt) : "a unit") + ".");
          else if (e.ab === "shove") parts.push(nm(e.u) + " shoves " + (tgt ? uName(tgt) : "a unit") + ".");
          else if (e.ab === "longshot") parts.push(nm(e.u) + " lines up a Long Shot.");
          else if (e.ab !== "call" && e.ab !== "swipe") parts.push(nm(e.u) + " uses " + ab + ".");
          break;
        case "stun": parts.push(nm(e.u) + " is stunned."); break;
        case "gadget":
          if (e.g === "tripwire") parts.push(hidden ? sideWord(e.side) + " hides a tripwire somewhere." : "You hide a tripwire. Only you can see it.");
          else if (e.g === "bribe") parts.push(sideWord(e.side) + " pays a Bribe.");
          else parts.push(sideWord(e.side) + " uses " + GD[e.g].name + ".");
          break;
        case "bribe": parts.push(nm(e.u) + " switches sides!"); break;
        case "burn": parts.push(sideWord(e.side) + " discards " + (hidden ? "a card" : (e.card.k === "crew" ? T[e.card.t].name : GD[e.card.t].name)) + "."); break;
        case "draw": if (e.side === side && !hidden) parts.push("New hand."); break;
      }
    });
    if (!parts.length && a.t === "move") parts.push(nm(a.u) + " moves.");
    return { html: parts.join(" "), cls: cls };
  }

  function addTrails(ev, side) {
    ev.forEach(function (e) { if (e.e === "move" && e.how !== "push") G.trails.push({ from: e.from, to: e.to, side: side }); });
  }

  function fxAt(node, ms) { G.layers.fx.appendChild(node); setTimeout(function () { node.remove(); }, ms || 600); return node; }
  function anim(node, frames, opts) { if (K.reduceMotion || !node.animate) return; try { node.animate(frames, opts); } catch (e) {} }

  function keyFlight(a, b, k, path) {
    var g = keyGlyph(k, 0, 0, 1.6, "gkey");
    var holder = sv("g");
    holder.appendChild(g);
    fxAt(holder, 520);
    var ax = cx(a), ay = cy(a), bx = cx(b), by = cy(b), mx = (ax + bx) / 2, my = (ay + by) / 2 - 22;
    holder.style.transform = "translate(" + bx + "px," + by + "px)";
    anim(holder, [{ transform: "translate(" + ax + "px," + ay + "px)" }, { transform: "translate(" + mx + "px," + my + "px)" }, { transform: "translate(" + bx + "px," + by + "px)" }], { duration: 460, easing: "ease-out" });
  }

  async function effects(ev, before, side) {
    var wait = 260;
    ev.forEach(function (e) {
      switch (e.e) {
        case "move": K.Sound.play(e.how === "push" ? "slide" : "move"); break;
        case "capture": case "out":
          var X = cx(e.at), Y = cy(e.at);
          var c = fxAt(sv("circle", { cx: X, cy: Y, r: 14, class: "fx-hit" }), 520);
          anim(c, [{ opacity: 1 }, { opacity: 0 }], { duration: 520 });
          K.Sound.play("hit"); K.haptic(20); K.shake(K.$("#stage"));
          wait = Math.max(wait, 420);
          break;
        case "bounce": case "armor": K.Sound.play("error"); break;
        case "pass": if (e.keys && e.keys.length) { keyFlight(e.a, e.b, e.keys[0]); K.Sound.play("whoosh"); wait = Math.max(wait, 480); } break;
        case "throw": if (e.keys && e.keys.length) { keyFlight(e.from, e.at, e.keys[0]); K.Sound.play("whoosh"); wait = Math.max(wait, 480); } break;
        case "pickup": K.Sound.play("score"); break;
        case "ability":
          if (e.ab === "longshot") {
            fxAt(sv("path", { d: "M" + cx(e.from) + " " + cy(e.from) + "L" + cx(e.at) + " " + cy(e.at), class: "fx-shot" }), 360);
            K.Sound.play("zap");
          } else if (e.ab === "glitch" || e.ab === "brace" || e.ab === "orders" || e.ab === "insideman") K.Sound.play("zap");
          break;
        case "stun":
          var st = sv("text", { x: cx(e.at), y: cy(e.at) - 26, class: "fx-text", fill: "#ffe2a0", text: "stunned" });
          fxAt(st, 900);
          anim(st, [{ transform: "translateY(0)", opacity: 1 }, { transform: "translateY(-10px)", opacity: 0 }], { duration: 900, fill: "forwards" });
          break;
        case "deploy":
          K.Sound.play("select");
          var n = G.nodes[e.u];
          if (n) anim(n, [{ opacity: 0 }, { opacity: 1 }], { duration: 300 });
          break;
        case "gadget":
          K.Sound.play(e.g === "emp" ? "zap" : e.g === "smoke" ? "splash" : e.g === "alarm" ? "contact" : "whoosh");
          if (e.g === "emp" || e.g === "alarm") {
            var at0 = e.g === "alarm" ? KR.SAFE[e.side] : e.at;
            var ring = fxAt(sv("circle", { cx: cx(at0), cy: cy(at0), r: 20, class: "fx-ring" + (e.g === "alarm" ? " alarm" : "") }), 700);
            anim(ring, [{ transform: "scale(.4)", opacity: 1 }, { transform: "scale(2.4)", opacity: 0 }], { duration: 700, easing: "ease-out" });
            ring.style.transformOrigin = cx(at0) + "px " + cy(at0) + "px";
          }
          break;
        case "trap": K.Sound.play("liar"); break;
        case "bribe": K.Sound.play("score"); break;
      }
    });
    await K.sleep(wait);
  }

  async function perform(a, token) {
    var before = KR.cloneState(G.st), side = G.st.side;
    var ev = KR.apply(G.st, a, []);
    var d = describe(a, ev, before, side);
    G.say = d.html; G.sayCls = d.cls;
    addTrails(ev, side);
    render();
    await effects(ev, before, side);
  }

  /* ---------- Turn flow ---------- */
  function humanTurn() {
    return new Promise(function (resolve) {
      G.resolver = resolve;
      G.busy = false;
      G.undo = [];
      clearSel();
      render();
    });
  }

  async function botTurn(token) {
    var st = G.st;
    G.busy = true;
    G.resolver = null;
    G.say = NAME[st.side] + " is planning…"; G.sayCls = "";
    render();
    await K.sleep(380);
    await waitUnpaused(token);
    await K.frame();
    for (var tries = 0; tries < 4 && G.st.winner == null; tries++) {
      if (token !== G.token) return;
      var plan = KR.bots.plan(G.st, G.level, G.rand);
      var replan = false;
      for (var i = 0; i < plan.length; i++) {
        if (token !== G.token) return;
        if (G.st.winner != null) break;
        await waitUnpaused(token);
        if (token !== G.token) return;
        if (!KR.isLegal(G.st, plan[i])) { replan = true; break; }
        G.st.revealed = false; G.st.drew = false;
        await perform(plan[i], token);
        if (token !== G.token) return;
        await K.sleep(G.cfg.speed === "fast" ? 160 : 460);
        if (G.st.revealed || G.st.drew) { replan = true; break; }
      }
      if (!replan) break;
    }
  }

  async function passCover(side) {
    G.viewer = side;
    G.busy = true;
    buildBoard();
    var cards = G.st.hands[side].length;
    await K.cover({ className: "s" + side, kicker: "Round " + KR.round(G.st), title: NAME[side] + "'s turn", text: "Hand the phone to " + NAME[side] + ". " + NAME[1 - side] + ", no peeking at the " + cards + " cards in " + NAME[side] + "'s hand.", cta: "I'm " + NAME[side] });
  }

  function threatsAtStart() {
    var st = G.st, s = st.side, o = 1 - s;
    var their = st.keys[o].h >= 0 ? KR.unit(st, st.keys[o].h) : null;
    var mine = st.keys[s].h >= 0 ? KR.unit(st, st.keys[s].h) : null;
    if (their && their.side === o && KR.cheb(their.pos, KR.SAFE[s]) <= KR.CFG.crackRange) return "STOP THEM";
    if (mine && mine.side === o && mine.pos === KR.SAFE[o]) return "LAST CHANCE";
    return null;
  }

  async function runGame(token) {
    var local = G.cfg.mode === "local";
    while (G.st.winner == null) {
      if (token !== G.token) return;
      var side = G.st.side;
      G.say = ""; G.sayCls = "";
      if (G.human[side]) {
        if (local) { await passCover(side); if (token !== G.token) return; }
        G.busy = false;
        var alarm = threatsAtStart();
        render();
        if (alarm) { K.Sound.play("ping"); await K.banner(alarm, { tone: "bad", sub: hint().t, ms: 1500 }); }
        else if (!local) { await K.banner("YOUR TURN", { tone: side ? "red" : "blue", ms: 650 }); }
        if (token !== G.token) return;
        await humanTurn();
      } else {
        await botTurn(token);
      }
      if (token !== G.token) return;
      if (G.st.winner != null) break;
      var ev = KR.endTurn(G.st, []);
      if (local && G.st.winner == null) G.trails = G.trails.filter(function (t) { return t.side !== G.st.side; });
      if (!G.human[G.st.side] && !local) G.trails = [];
      if (ev.some(function (e) { return e.e === "crack" || e.e === "stash"; })) break;
    }
    if (token !== G.token) return;
    await endGame(token);
  }

  async function endGame(token) {
    var st = G.st;
    G.busy = true;
    G.resolver = null;
    clearSel();
    if (G.cfg.mode === "local") { G.viewer = st.winner === 1 ? 1 : 0; buildBoard(); }
    G.say = st.reason;
    render();
    var word = st.how === "crack" ? "SAFE CRACKED" : st.how === "stash" ? "KEY STOLEN" : "TIME'S UP";
    await K.banner(word, { tone: st.winner === "draw" ? "accent" : st.winner ? "red" : "blue", sub: st.reason, ms: 1800 });
    if (token !== G.token) return;
    var youWon = G.cfg.mode === "bot" ? st.winner === mySide() : null;
    var s0 = st.stats[0], s1 = st.stats[1];
    var choice = await K.gameOver({
      title: G.cfg.mode === "bot" ? (st.winner === "draw" ? "A draw" : youWon ? "You pulled it off" : "Busted") : (st.winner === "draw" ? "A draw" : NAME[st.winner] + " wins"),
      tone: youWon === false ? "bad" : "good",
      text: st.reason,
      stats: [["Rounds", KR.round(st)], ["Captures (Blue – Red)", s0.caps + " – " + s1.caps], ["Keys stolen", s0.steals + " – " + s1.steals], ["Crew deployed", s0.deploys + " – " + s1.deploys]],
      reviewLabel: "Look at the board"
    });
    if (token !== G.token) return;
    if (choice === "rematch") restart();
    else if (choice === "review") { G.review = true; render(); }
  }

  /* ---------- Crew builder ---------- */
  function presetDeck(id) { var p = KR.PRESETS.filter(function (x) { return x.id === id; })[0] || KR.PRESETS[0]; return { leader: p.leader, crew: p.crew.slice(), gadgets: p.gadgets.slice() }; }

  function chooseDeck(side, opts) {
    return new Promise(function (resolve) {
      var saved = K.store.get("deck" + side, null) || K.store.get("deck0", null);
      var d = KR.validDeck(saved) ? { leader: saved.leader, crew: saved.crew.slice(), gadgets: saved.gadgets.slice() } : presetDeck(side ? "fortress" : "runners");
      var focus = { k: "leader", t: d.leader };
      var host = K.$("#screen-deck");
      function cardBtn(kind, t, on) {
        var cost = kind === "crew" ? T[t].cost : kind === "gadget" ? GD[t].cost : null;
        var name = kind === "gadget" ? GD[t].name : T[t].name;
        return h("button", { class: "card" + (kind === "gadget" ? " gadget" : ""), type: "button", "aria-pressed": on ? "true" : "false", "aria-label": name,
          onclick: function () { toggle(kind, t); } },
          h("span", { class: "tick" }), cost != null ? h("span", { class: "cost" }, String(cost)) : null,
          h("span", { html: iconSvg(t, kind === "gadget" ? "#f2b840" : "#eef2f7") }), h("span", { class: "nm" }, name));
      }
      function toggle(kind, t) {
        K.Sound.play("tap");
        focus = { k: kind, t: t };
        if (kind === "leader") d.leader = t;
        else {
          var list = kind === "crew" ? d.crew : d.gadgets, max = kind === "crew" ? 6 : 2, at = list.indexOf(t);
          if (at >= 0) list.splice(at, 1);
          else if (list.length < max) list.push(t);
          else { list.shift(); list.push(t); }
        }
        draw();
      }
      function done() {
        if (!KR.validDeck(d)) { K.Sound.play("error"); return; }
        K.Sound.play("select");
        K.store.set("deck" + side, d);
        resolve(d);
      }
      function draw() {
        var scroll = host.scrollTop;
        host.innerHTML = "";
        var inner = h("div", { class: "deck-inner" });
        inner.appendChild(h("div", { class: "deck-head" }, h("h2", { class: "s" + side }, opts.title), h("p", null, opts.sub)));
        var pre = h("div", { class: "presets" });
        KR.PRESETS.forEach(function (p) {
          pre.appendChild(h("button", { class: "btn btn-sm", type: "button", title: p.note, onclick: function () { d = presetDeck(p.id); focus = { k: "leader", t: d.leader }; K.Sound.play("tap"); draw(); } }, p.name));
        });
        pre.appendChild(h("button", { class: "btn btn-sm", type: "button", onclick: function () { d = KR.randomDeck(Math.random); focus = { k: "leader", t: d.leader }; K.Sound.play("tap"); draw(); } }, "Random"));
        inner.appendChild(pre);
        function section(label, count, max, grid) {
          inner.appendChild(h("div", null, h("div", { class: "sec-h" }, h("span", null, label), max ? h("b", null, count + " / " + max) : null), grid));
        }
        var lg = h("div", { class: "pick lead" });
        KR.LEADERS.forEach(function (t) { lg.appendChild(cardBtn("leader", t, d.leader === t)); });
        section("Leader", null, null, lg);
        var cg = h("div", { class: "pick" });
        KR.CREW.forEach(function (t) { cg.appendChild(cardBtn("crew", t, d.crew.indexOf(t) >= 0)); });
        section("Crew", d.crew.length, 6, cg);
        var gg = h("div", { class: "pick gad" });
        KR.GADGET_LIST.forEach(function (t) { gg.appendChild(cardBtn("gadget", t, d.gadgets.indexOf(t) >= 0)); });
        section("Gadgets", d.gadgets.length, 2, gg);
        var info;
        if (focus.k === "gadget") info = cardInfo({ k: "gadget", t: focus.t });
        else if (focus.k === "crew") info = cardInfo({ k: "crew", t: focus.t });
        else {
          var L = T[focus.t];
          info = h("div", { class: "info" }, h("span", { class: "badge s" + side, html: iconSvg(focus.t, "#fff") }),
            h("div", { class: "txt" }, h("div", { class: "nm" }, h("b", null, L.name), h("span", { class: "tag" }, "leader · starts with your key")),
              h("p", { html: "<b>" + L.pname + ":</b> " + L.ptext }), h("p", { html: "<b>" + L.aname + " (" + L.ac + "):</b> " + L.atext })));
        }
        var ok = KR.validDeck(d);
        var detail = h("div", { class: "detail" }, info, h("div", { class: "row" },
          h("button", { class: "btn", type: "button", onclick: function () { K.Sound.play("tap"); K.quit(); } }, "Back"),
          h("button", { class: "btn btn-primary", type: "button", id: "btn-ready", disabled: ok ? null : true, onclick: done }, ok ? opts.cta : "Pick " + (6 - d.crew.length > 0 ? 6 - d.crew.length + " more crew" : 2 - d.gadgets.length + " more gadget" + (2 - d.gadgets.length === 1 ? "" : "s")))));
        inner.appendChild(detail);
        host.appendChild(inner);
        host.scrollTop = scroll;
      }
      K.showScreen("deck");
      host.scrollTop = 0;
      draw();
    });
  }

  /* ---------- Lifecycle ---------- */
  async function start(cfg) {
    G.cfg = cfg;
    G.level = cfg.difficulty || "normal";
    var token = ++G.token;
    if (cfg.mode === "local") {
      G.human = [true, true];
      var d0 = await chooseDeck(0, { title: "Blue crew", sub: "Blue picks a leader, 6 crew and 2 gadgets. Red, look away.", cta: "Blue is ready" });
      if (token !== G.token) return;
      await K.cover({ className: "s1", kicker: "Crew select", title: "Red's pick", text: "Hand the phone to Red.", cta: "I'm Red" });
      if (token !== G.token) return;
      var d1 = await chooseDeck(1, { title: "Red crew", sub: "Red picks a leader, 6 crew and 2 gadgets.", cta: "Red is ready" });
      if (token !== G.token) return;
      G.decks = [d0, d1];
    } else {
      var me = cfg.side === "red" ? 1 : 0;
      G.human = [me === 0, me === 1];
      var dh = await chooseDeck(me, { title: "Your crew", sub: "Pick a leader, 6 crew and 2 gadgets, or start from a ready-made crew.", cta: "Start the heist" });
      if (token !== G.token) return;
      var p = KR.PRESETS[Math.floor(Math.random() * KR.PRESETS.length)];
      var db = { leader: p.leader, crew: p.crew.slice(), gadgets: p.gadgets.slice() };
      G.decks = me === 0 ? [dh, db] : [db, dh];
    }
    newMatch();
  }

  function newMatch() {
    G.token++;
    G.st = KR.newGame({ decks: G.decks, seed: (Date.now() ^ Math.floor(Math.random() * 1e9)) >>> 0 });
    G.rand = KR.rng((Date.now() * 7 + Math.floor(Math.random() * 1e6)) >>> 0);
    G.viewer = G.cfg.mode === "local" ? 0 : mySide();
    G.review = false; G.trails = []; G.say = ""; G.sayCls = ""; G.undo = []; G.resolver = null; G.busy = true;
    clearSel();
    K.showScreen("game");
    buildBoard();
    render();
    runGame(G.token);
  }
  function restart() { K.$all(".cover,.modal-wrap,.banner").forEach(function (n) { n.remove(); }); newMatch(); }
  function quit() { G.token++; G.resolver = null; G.busy = true; }

  window.__krDebug = { G: G, KR: KR, doHuman: doHuman, endTurn: endTurnClicked };

  K.init({
    ns: "keyrunners",
    title: "Keyrunners",
    tagline: "Run your key into their safe. Lose it, and they lock it away.",
    art: TITLE_ART,
    rules: RULES.replace("[[glossary]]", glossary()),
    options: [
      { id: "mode", label: "Opponent", default: "bot", choices: [{ v: "bot", t: "Bot" }, { v: "local", t: "Friend, same phone" }],
        note: function (c) { return c.mode === "local" ? "Cover screens hide each player's hand and traps between turns." : null; } },
      { id: "difficulty", label: "Bot level", default: "normal", choices: [{ v: "easy", t: "Easy" }, { v: "normal", t: "Normal" }, { v: "hard", t: "Hard" }], showIf: function (c) { return c.mode === "bot"; },
        note: function (c) { return c.difficulty === "hard" ? "Plans its turn and checks your best reply before it commits." : c.difficulty === "easy" ? "Often forgets to guard its key." : "Guards its key and punishes a lonely carrier."; } },
      { id: "side", label: "You play", default: "blue", choices: [{ v: "blue", t: "Blue, first" }, { v: "red", t: "Red, second" }], showIf: function (c) { return c.mode === "bot"; } },
      { id: "speed", label: "Bot speed", default: "normal", choices: [{ v: "normal", t: "Watch each move" }, { v: "fast", t: "Fast" }], showIf: function (c) { return c.mode === "bot"; } }
    ],
    onStart: start,
    onRestart: restart,
    onQuit: quit,
    menuNote: function () { return G.st ? "Round " + KR.round(G.st) + ". Blue " + G.st.mana[0] + " mana, Red " + G.st.mana[1] + " mana." : "Pick your crew to start."; }
  });
  // Opening the menu pauses the bot between moves.
  var menuBtn = K.$("#btn-menu");
  if (menuBtn) menuBtn.onclick = function () {
    K.Sound.play("tap");
    G.paused = true;
    K.openMenu().then(function () { G.paused = false; }, function () { G.paused = false; });
  };
})();
