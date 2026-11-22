/* Echoes: interface, animation and turn flow. */
(function () {
  "use strict";
  var E = window.Echoes, K = window.Kit, h = K.h, sv = K.s;
  var S = 48, PAD = 4;
  var VB = E.COLS * S + PAD * 2;
  var SIDE = ["c0", "c1"];
  var COLORS = ["#36e2ff", "#ff4fd8"];

  var TITLE_ART = '<svg viewBox="0 0 260 150" role="img" aria-label="Two heroes followed by ghostly echoes of themselves">' +
    '<g fill="none" stroke-width="3" stroke-linecap="round"><path d="M28 118c30-6 40-40 70-44" stroke="#36e2ff" stroke-dasharray="3 7" opacity=".7"/><path d="M232 32c-30 6-40 40-70 44" stroke="#ff4fd8" stroke-dasharray="3 7" opacity=".7"/></g>' +
    '<circle cx="34" cy="116" r="13" fill="rgba(54,226,255,.15)" stroke="#36e2ff" stroke-width="2" stroke-dasharray="3 2"/><circle cx="64" cy="104" r="14" fill="rgba(54,226,255,.25)" stroke="#36e2ff" stroke-width="2" stroke-dasharray="3 2"/><circle cx="102" cy="76" r="17" fill="#36e2ff"/>' +
    '<circle cx="226" cy="34" r="13" fill="rgba(255,79,216,.15)" stroke="#ff4fd8" stroke-width="2" stroke-dasharray="3 2"/><circle cx="196" cy="46" r="14" fill="rgba(255,79,216,.25)" stroke="#ff4fd8" stroke-width="2" stroke-dasharray="3 2"/><circle cx="158" cy="74" r="17" fill="#ff4fd8"/>' +
    '<path d="M130 54l14 21-14 21-14-21z" fill="#ffd166"/><text x="130" y="80" text-anchor="middle" font-size="14" font-weight="800" fill="#1d1405" font-family="Manrope, sans-serif">2</text>' +
    "</svg>";

  var RULES = [
    "<h3>The goal</h3>",
    "<p>Hold gems at the end of each round. Most points after <b>5 rounds</b> wins.</p>",
    "<h3>Echoes</h3>",
    "<p>Each round lasts <b>6 ticks</b>, and each round you get a <b>new hero</b>. Every hero from an earlier round comes back as an <b>echo</b> and repeats exactly what it did. By round 5 you have 4 echoes and 1 live hero.</p>",
    "<p>Dotted lines show where every echo will go this round, with the tick numbers.</p>",
    "<h3>A tick</h3><ol>",
    "<li>All echoes act first, oldest first.</li>",
    "<li>Then each live hero takes its turn. Who goes first alternates every tick.</li></ol>",
    "<p>On your turn: <b>step</b> one square, <b>wait</b>, or <b>strike</b> an enemy live hero next to you. A struck hero is out for the rest of the round, and its echo will fade at that same tick in later rounds.</p>",
    "<h3>Paradox</h3>",
    "<p>Echoes can't be hit, because they're from the past. But if an enemy stands where an echo needs to step, or a door is shut in its face, the echo glitches out of that round. That's a <b>paradox</b>. Your own units can share a square, and enemies can't.</p>",
    "<h3>The map</h3>",
    '<dl class="kv"><dt>Gems</dt><dd>Your home gem and the two side gems are worth 1. The centre gem is worth 2.</dd>',
    "<dt>Vault</dt><dd>Worth <b>3</b>, behind a door next to your spawn.</dd>",
    "<dt>Plate</dt><dd>Your vault door is open only while somebody stands on its plate in the middle row. If the plate empties, the door slams and crushes anyone in the doorway.</dd></dl>",
    '<div class="tip">The classic combo: in round 1, walk a hero onto your plate and leave it there. From round 2 on, its echo holds the door open, so a later hero can reach the vault every round. Your opponent will try to stand in your plate-holder\'s path.</div>'
  ].join("");

  var G = { state: null, cfg: null, rand: null, level: "normal", human: [true, false], resolver: null, token: 0, nodes: {}, layers: {}, showPaths: true, acting: -1, say: "" };

  function cx(i) { return PAD + E.cOf(i) * S + S / 2; }
  function cy(i) { return PAD + E.rOf(i) * S + S / 2; }

  /* ---------- Board ---------- */
  function buildBoard() {
    var stage = K.$("#stage");
    stage.innerHTML = "";
    var svg = sv("svg", { id: "board", viewBox: "0 0 " + VB + " " + VB, role: "img", "aria-label": "Arena" });
    var tiles = sv("g", { class: "tiles" });
    for (var i = 0; i < E.N; i++) {
      var x = PAD + E.cOf(i) * S, y = PAD + E.rOf(i) * S, ch = E.TILE[i];
      if (ch === "#") {
        tiles.appendChild(sv("rect", { x: x + 1, y: y + 1, width: S - 2, height: S - 2, rx: 6, class: "wall" }));
        tiles.appendChild(sv("rect", { x: x + 4, y: y + 3, width: S - 8, height: S - 12, rx: 4, class: "wall-top" }));
        continue;
      }
      tiles.appendChild(sv("rect", { x: x + 1, y: y + 1, width: S - 2, height: S - 2, rx: 5, class: (E.cOf(i) + E.rOf(i)) % 2 ? "fl-b" : "fl-a" }));
      if (ch === "S" || ch === "s") tiles.appendChild(sv("circle", { cx: cx(i), cy: cy(i), r: "17", class: "spawn " + (ch === "S" ? "c0" : "c1") }));
    }
    Object.keys(E.PLATE_DOOR).forEach(function (pl) {
      var door = E.PLATE_DOOR[pl];
      tiles.appendChild(sv("path", { d: "M" + cx(+pl) + " " + cy(+pl) + "L" + cx(door) + " " + cy(door), class: "link" }));
    });
    svg.appendChild(tiles);
    ["marks", "forecast", "trails", "opts", "units", "fx"].forEach(function (n) { var g = sv("g", { class: n }); G.layers[n] = g; svg.appendChild(g); });
    var hit = sv("g", { class: "hit-layer" });
    for (var j = 0; j < E.N; j++) hit.appendChild(sv("rect", { x: PAD + E.cOf(j) * S, y: PAD + E.rOf(j) * S, width: S, height: S, "data-i": String(j) }));
    hit.addEventListener("click", function (e) {
      var t = e.target;
      if (t && t.getAttribute("data-i") != null) onTile(+t.getAttribute("data-i"));
    });
    svg.appendChild(hit);
    stage.appendChild(svg);
    G.nodes = {};
  }

  function unitNode(u) {
    var n = G.nodes[u.id];
    if (n) return n;
    n = sv("g", { class: "unit" });
    G.layers.units.appendChild(n);
    G.nodes[u.id] = n;
    return n;
  }

  function drawUnit(n, u) {
    var key = (u.live ? "L" : "E") + u.side + u.round;
    if (n.getAttribute("data-key") === key) return;
    n.setAttribute("data-key", key);
    n.innerHTML = "";
    n.appendChild(sv("circle", { r: "18", class: "u-halo" }));
    if (u.live) n.appendChild(sv("circle", { r: "15", class: "u-body " + SIDE[u.side] }));
    else n.appendChild(sv("circle", { r: "14", class: "u-echo " + SIDE[u.side] }));
    n.appendChild(sv("text", { y: "4", "text-anchor": "middle", class: "u-num " + SIDE[u.side] + (u.live ? " live" : " echo"), text: String(u.round) }));
  }

  /* ---------- Render ---------- */
  function render() {
    var st = G.state;
    if (!st) return;
    renderMarks();
    renderForecast();
    renderTrails();
    renderOpts();
    var stacks = {};
    st.units.forEach(function (u) {
      var n = unitNode(u);
      drawUnit(n, u);
      n.classList.toggle("dead", !u.alive);
      n.classList.toggle("acting", G.acting === u.id);
      if (!u.alive) return;
      var k = stacks[u.pos] || 0;
      stacks[u.pos] = k + 1;
      var off = k === 0 ? [0, 0] : [[7, -6], [-7, 6], [7, 6], [-7, -6]][(k - 1) % 4];
      n.style.transform = "translate(" + (cx(u.pos) + off[0]) + "px," + (cy(u.pos) + off[1]) + "px)";
    });
    renderTop();
    renderBar();
  }

  function renderMarks() {
    var st = G.state, m = G.layers.marks;
    m.innerHTML = "";
    E.PADS.forEach(function (p) {
      var x = cx(p), y = cy(p), r = 11 + E.PAD[p] * 1.5;
      m.appendChild(sv("circle", { cx: x, cy: y, r: String(r + 6), class: "gem-ring" }));
      m.appendChild(sv("path", { d: "M" + x + " " + (y - r) + "l" + r + " " + r + "l" + (-r) + " " + r + "l" + (-r) + " " + (-r) + "z", class: "gem" }));
      m.appendChild(sv("text", { x: x, y: y + 3.5, "text-anchor": "middle", class: "gem-val", text: String(E.PAD[p]) }));
    });
    E.PLATES.forEach(function (p) {
      var on = st.units.some(function (u) { return u.alive && u.pos === p; });
      m.appendChild(sv("circle", { cx: cx(p), cy: cy(p), r: "15", class: "plate" + (on ? " on" : "") }));
      m.appendChild(sv("circle", { cx: cx(p), cy: cy(p), r: "9", class: "plate-in" }));
    });
    E.DOORS.forEach(function (d) {
      var open = E.doorOpen(st, d);
      var x = PAD + E.cOf(d) * S, y = PAD + E.rOf(d) * S;
      var vertical = E.TILE[d - 1] === "V" || E.TILE[d + 1] === "V";
      if (open) m.appendChild(sv("rect", { x: x + 4, y: y + 4, width: S - 8, height: S - 8, rx: 4, class: "door-open" }));
      else if (vertical) m.appendChild(sv("rect", { x: x + S / 2 - 5, y: y + 3, width: 10, height: S - 6, rx: 3, class: "door-closed" }));
      else m.appendChild(sv("rect", { x: x + 3, y: y + S / 2 - 5, width: S - 6, height: 10, rx: 3, class: "door-closed" }));
    });
  }

  function renderForecast() {
    var g = G.layers.forecast;
    g.innerHTML = "";
    if (!G.showPaths || G.state.phase === "over") return;
    var fc = E.echoForecast(G.state);
    G.state.units.forEach(function (u) {
      var path = fc[u.id];
      if (!path || !path.length) return;
      var d = "M" + cx(u.pos) + " " + cy(u.pos);
      var last = u.pos;
      path.forEach(function (p) { if (p.pos !== last) { d += "L" + cx(p.pos) + " " + cy(p.pos); last = p.pos; } });
      g.appendChild(sv("path", { d: d, class: "fpath path-" + SIDE[u.side] }));
      var prev = u.pos;
      path.forEach(function (p) {
        if (p.pos === prev && !p.end) return;
        prev = p.pos;
        var off = u.side === 0 ? 10 : -10;
        g.appendChild(sv("circle", { cx: cx(p.pos) + off, cy: cy(p.pos) - 13, r: "7", class: "fdot " + SIDE[u.side] }));
        g.appendChild(sv("text", { x: cx(p.pos) + off, y: cy(p.pos) - 9.6, "text-anchor": "middle", class: "ftext", text: p.end ? "×" : String(p.t) }));
      });
    });
  }

  function renderTrails() {
    var g = G.layers.trails;
    g.innerHTML = "";
    var st = G.state;
    if (st.phase === "over") return;
    st.live.forEach(function (id) {
      var u = st.units[id];
      var pos = E.SPAWN[u.side], d = "M" + cx(pos) + " " + cy(pos);
      u.rec.forEach(function (a) { if (a.k === "move") { var t = E.step(pos, a.d); if (t >= 0) { pos = t; d += "L" + cx(pos) + " " + cy(pos); } } });
      if (u.rec.length) g.appendChild(sv("path", { d: d, class: "trail path-" + SIDE[u.side] }));
    });
  }

  function renderOpts() {
    var g = G.layers.opts;
    g.innerHTML = "";
    if (!G.resolver) return;
    var st = G.state, side = G.turnSide;
    var u = st.units[st.live[side]];
    E.liveOptions(st, side).forEach(function (a) {
      if (a.k === "move") {
        var t = E.step(u.pos, a.d);
        g.appendChild(sv("rect", { x: PAD + E.cOf(t) * S + 4, y: PAD + E.rOf(t) * S + 4, width: S - 8, height: S - 8, rx: 6, class: "opt-move" }));
      } else if (a.k === "strike") {
        var t2 = E.step(u.pos, a.d);
        g.appendChild(sv("circle", { cx: cx(t2), cy: cy(t2), r: "20", class: "opt-strike" }));
      }
    });
  }

  function renderTop() {
    var st = G.state;
    var main, sub;
    if (st.phase === "over") {
      main = st.winner === "draw" ? "Draw" : E.sideName(st.winner) + " wins";
      sub = st.reason;
    } else if (G.resolver) {
      main = G.cfg.mode === "local" ? E.sideName(G.turnSide) + "'s move" : "Your move";
      sub = "Round " + st.round + " of " + E.ROUNDS + " · tick " + st.tick + " of " + E.TICKS;
    } else {
      main = G.thinking != null ? E.sideName(G.thinking) + " is thinking" : "Round " + st.round + " of " + E.ROUNDS;
      sub = "Tick " + Math.max(1, st.tick) + " of " + E.TICKS;
    }
    K.$("#st-main").textContent = main;
    K.$("#st-sub").textContent = sub;
    var sc = K.$("#scores");
    sc.innerHTML = "";
    [0, 1].forEach(function (side) {
      sc.appendChild(h("span", { class: "chip", title: E.sideName(side) + " points" }, h("i", { style: "background:" + COLORS[side] }), String(st.scores[side])));
    });
    var tl = K.$("#timeline");
    tl.innerHTML = "";
    var ticks = h("div", { class: "ticks" });
    for (var t = 1; t <= E.TICKS; t++) ticks.appendChild(h("span", { class: t < st.tick ? "done" : t === st.tick ? "now" : "" }));
    var first = st.tick >= 1 ? (st.firstOfRound + st.tick - 1) % 2 : null;
    tl.appendChild(h("span", { class: "rnd" }, "R" + st.round + "/" + E.ROUNDS));
    tl.appendChild(ticks);
    if (first != null && st.phase !== "over") tl.appendChild(h("span", { class: "who", style: "color:" + COLORS[first] }, E.sideName(first) + " first"));
  }

  function pathToggle() {
    return h("button", { class: "toggle", type: "button", "aria-pressed": G.showPaths ? "true" : "false", onclick: function () {
      G.showPaths = !G.showPaths; K.store.set("paths", G.showPaths); K.Sound.play("tap"); render();
    }, html: K.ICONS.eye + "<span>Echo paths</span>" });
  }

  function renderBar() {
    var bar = K.$("#actionbar");
    bar.innerHTML = "";
    var st = G.state;
    bar.appendChild(h("p", { class: "say", html: G.say || "&nbsp;" }));
    if (st.phase === "over") {
      bar.appendChild(h("div", { class: "action-row" },
        h("button", { class: "btn btn-primary", type: "button", onclick: function () { restart(); } }, "Rematch"),
        h("button", { class: "btn", type: "button", onclick: function () { K.quit(); } }, "Main menu")));
      return;
    }
    if (G.resolver) {
      bar.appendChild(h("div", { class: "bar-row" },
        pathToggle(),
        h("button", { class: "btn", type: "button", style: "flex:1", onclick: function () { choose(E.act("wait")); } }, "Wait")));
      return;
    }
    bar.appendChild(h("div", { class: "bar-row" }, pathToggle(), h("span", { class: "legend" }, "Solid: live hero · Dashed: echo · Number: its round")));
  }

  /* ---------- Input ---------- */
  function onTile(i) {
    if (!G.resolver) return;
    var st = G.state, side = G.turnSide;
    var u = st.units[st.live[side]];
    var opts = E.liveOptions(st, side);
    var pick = null;
    opts.forEach(function (a) {
      if (a.k === "strike" && E.step(u.pos, a.d) === i) pick = a;
    });
    if (!pick) opts.forEach(function (a) { if (a.k === "move" && E.step(u.pos, a.d) === i) pick = a; });
    if (!pick && i === u.pos) pick = E.act("wait");
    if (!pick) { K.Sound.play("error"); return; }
    choose(pick);
  }
  function choose(a) {
    if (!G.resolver) return;
    var r = G.resolver; G.resolver = null;
    r(a);
  }

  /* ---------- Animation of events ---------- */
  async function showEvents(ev, label) {
    var moved = false, notes = [];
    for (var k = 0; k < ev.length; k++) {
      var e = ev[k];
      if (e.t === "move") moved = true;
      if (e.t === "strike" && e.hits.length) {
        var from = e.from, to = E.step(from, e.d);
        var ln = sv("line", { x1: cx(from), y1: cy(from), x2: cx(to), y2: cy(to), class: "fx-strike" });
        G.layers.fx.appendChild(ln);
        setTimeout(function (n) { return function () { n.remove(); }; }(ln), 350);
        K.Sound.play("hit");
      }
      if (e.t === "ko") {
        var u = G.state.units[e.id];
        var who = E.sideName(u.side) + "'s " + (u.live ? "hero" : "round-" + u.round + " echo");
        if (e.why === "paradox") { notes.push("<b>Paradox!</b> " + who + " was blocked and glitched out."); K.Sound.play("zap"); }
        else if (e.why === "struck") { notes.push("<b>Struck!</b> " + who + " is out for this round."); }
        else if (e.why === "crushed") { notes.push("<b>Crushed!</b> A door slammed on " + who + "."); K.Sound.play("hit"); K.shake(K.$("#stage")); }
        else if (e.why === "fades") { notes.push(who + " fades, as it did when it was struck."); }
      }
      if (e.t === "door") K.Sound.play(e.open ? "reveal" : "error");
    }
    if (notes.length) G.say = notes.join(" ");
    render();
    if (moved) { K.Sound.play("move"); await K.sleep(300); }
    if (notes.length) await K.sleep(650);
  }

  async function showScore(res) {
    G.say = "Round " + res.round + ": " + E.sideName(0) + " <b>+" + res.gained[0] + "</b> · " + E.sideName(1) + " <b>+" + res.gained[1] + "</b>";
    res.held.forEach(function (hd) {
      var t = sv("text", { x: cx(hd.pad), y: cy(hd.pad) - 18, "text-anchor": "middle", class: "float-pts", fill: COLORS[hd.side], text: "+" + hd.value });
      G.layers.fx.appendChild(t);
      if (t.animate) try { t.animate([{ transform: "translateY(0)", opacity: 1 }, { transform: "translateY(-16px)", opacity: 0 }], { duration: 1300, fill: "forwards" }); } catch (e2) {}
      setTimeout(function () { t.remove(); }, 1400);
    });
    K.Sound.play("score");
    render();
    await K.sleep(1400);
  }

  /* ---------- Turn flow ---------- */
  function waitHuman(side) {
    return new Promise(function (resolve) {
      G.turnSide = side;
      G.acting = G.state.live[side];
      G.resolver = resolve;
      render();
    });
  }

  async function runGame(token) {
    var st = G.state;
    var lastRound = 0;
    while (st.phase !== "over") {
      if (token !== G.token) return;
      if (st.round !== lastRound) {
        lastRound = st.round;
        render();
        await K.banner("ROUND " + st.round, { tone: "accent", sub: st.round === 1 ? "Six ticks. Grab gems." : "Your round-" + (st.round - 1) + " hero is now an echo", ms: 1300 });
        if (token !== G.token) return;
        if (st.round === 2) G.say = "Dotted lines show where every <b>echo</b> will go this round, with tick numbers.";
        else if (st.round === 1) G.say = G.cfg.mode === "local" ? "Cyan starts at the bottom, Magenta at the top." : "You are <b>Cyan</b>, at the bottom.";
      }
      var auto = E.stepAuto(st);
      if (auto) {
        if (auto.type === "echoes") await showEvents(auto.ev);
        else if (auto.type === "score") await showScore(auto.res);
        continue;
      }
      var who = E.nextActor(st);
      if (who !== 0 && who !== 1) continue;
      var a;
      if (G.human[who]) {
        if (G.cfg.mode === "local") G.say = "<b>" + E.sideName(who) + "</b>, your move.";
        a = await waitHuman(who);
        if (token !== G.token) return;
      } else {
        G.thinking = who; G.acting = st.live[who];
        render();
        await K.sleep(280);
        if (token !== G.token) return;
        a = E.bots.action(st, who, G.level, G.rand);
        G.thinking = null;
      }
      G.acting = st.live[who];
      var ev = E.applyLive(st, who, a);
      if (a.k === "wait") K.Sound.play("tick");
      await showEvents(ev);
      G.acting = -1;
    }
    if (token !== G.token) return;
    await endGame(token);
  }

  async function endGame(token) {
    var st = G.state;
    render();
    var youWon = G.cfg.mode === "bot" ? st.winner === 0 : null;
    await K.banner(st.winner === "draw" ? "DRAW" : E.sideName(st.winner).toUpperCase() + " WINS", { tone: st.winner === 1 ? "bad" : "accent", ms: 1500 });
    if (token !== G.token) return;
    var rows = st.roundScores.map(function (g, k) { return ["Round " + (k + 1), g[0] + " – " + g[1]]; });
    rows.push(["Total (Cyan – Magenta)", st.scores[0] + " – " + st.scores[1]]);
    var choice = await K.gameOver({
      title: G.cfg.mode === "bot" ? (st.winner === "draw" ? "A draw" : youWon ? "You win!" : "You lose") : (st.winner === "draw" ? "A draw" : E.sideName(st.winner) + " wins"),
      tone: youWon === false ? "bad" : "good",
      text: st.reason,
      stats: rows,
      reviewLabel: "Look at the board"
    });
    if (token !== G.token) return;
    if (choice === "rematch") restart();
  }

  /* ---------- Lifecycle ---------- */
  function start(cfg) {
    G.cfg = cfg;
    G.level = cfg.difficulty || "normal";
    G.human = cfg.mode === "local" ? [true, true] : [true, false];
    G.showPaths = K.store.get("paths", true);
    newMatch();
  }
  function newMatch() {
    G.token++;
    G.state = E.newGame();
    G.rand = E.rng((Date.now() ^ Math.floor(Math.random() * 1e9)) >>> 0);
    G.resolver = null; G.say = ""; G.acting = -1; G.thinking = null;
    K.showScreen("game");
    buildBoard();
    render();
    runGame(G.token);
  }
  function restart() {
    K.$all(".cover,.modal-wrap,.banner").forEach(function (n) { n.remove(); });
    newMatch();
  }
  function quit() { G.token++; G.resolver = null; }

  window.__echoesDebug = { G: G };

  K.init({
    ns: "echoes",
    title: "Echoes",
    tagline: "Your past turns come back to fight for you. Plan across time, and break your rival's.",
    art: TITLE_ART,
    rules: RULES,
    options: [
      { id: "mode", label: "Opponent", default: "bot", choices: [{ v: "bot", t: "Bot" }, { v: "local", t: "Friend, same phone" }],
        note: function (c) { return c.mode === "local" ? "Nothing is hidden, so just take turns on the same screen." : null; } },
      { id: "difficulty", label: "Bot level", default: "normal", choices: [{ v: "easy", t: "Easy" }, { v: "normal", t: "Normal" }, { v: "hard", t: "Hard" }], showIf: function (c) { return c.mode === "bot"; },
        note: function (c) { return c.difficulty === "hard" ? "Searches deep and plans across rounds." : c.difficulty === "easy" ? "Short-sighted. Good for learning how echoes work." : "Plans a few ticks ahead."; } }
    ],
    onStart: start,
    onRestart: restart,
    onQuit: quit,
    menuNote: function () { return G.state ? "Round " + G.state.round + ", tick " + G.state.tick + "." : ""; }
  });
})();
