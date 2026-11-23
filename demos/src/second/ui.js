/* Second Guess: interface, planning, reveal animation and turn flow. */
(function () {
  "use strict";
  var SG = window.SecondGuess, K = window.Kit, h = K.h, sv = K.s;
  var S = 48, PAD = 4, VB = SG.COLS * S + PAD * 2;
  var SC = ["s0", "s1"];
  var COLOR = ["#2f5fd0", "#cf3e33"];

  var ICON = {
    brute: '<path d="M5 19l7.5-7.5"/><path d="M11.5 4.5l8 8-3 3-8-8z"/>',
    archer: '<path d="M6 4c7 0 14 7 14 14"/><path d="M6 4l14 14"/><path d="M4 12l4 0M12 4l0 4"/>',
    scout: '<path d="M5 6l6 6-6 6"/><path d="M12 6l6 6-6 6"/>',
    mage: '<path d="M12 3.5l2 5.6 5.8 1.9-5.8 1.9-2 5.6-2-5.6-5.8-1.9 5.8-1.9z"/>'
  };
  function iconSvg(kind, color) {
    return '<svg viewBox="0 0 24 24" fill="none" stroke="' + (color || "currentColor") + '" stroke-width="2.1" stroke-linecap="round" stroke-linejoin="round">' + ICON[kind] + "</svg>";
  }

  var TITLE_ART = '<svg viewBox="0 0 260 150" role="img" aria-label="A blue and a red unit aiming at the same square">' +
    '<g stroke="#cbbd9f" stroke-width="1">' + [0, 1, 2, 3, 4, 5].map(function (k) { return '<path d="M' + (40 + k * 36) + ' 10v130"/><path d="M40 ' + (10 + k * 26) + 'h180"/>'; }).join("") + "</g>" +
    '<rect x="52" y="92" width="30" height="30" rx="7" fill="#2f5fd0"/><path d="M61 99c7 0 14 7 14 14M61 99l14 14" stroke="#fff" stroke-width="2.4" fill="none" stroke-linecap="round"/>' +
    '<rect x="178" y="22" width="30" height="30" rx="7" fill="#cf3e33"/><path d="M186 30l6 6-6 6M193 30l6 6-6 6" stroke="#fff" stroke-width="2.4" fill="none" stroke-linecap="round" stroke-linejoin="round"/>' +
    '<path d="M82 100L124 66" stroke="#2f5fd0" stroke-width="3" stroke-dasharray="5 4" stroke-linecap="round"/>' +
    '<path d="M178 46L142 66" stroke="#cf3e33" stroke-width="3" stroke-dasharray="5 4" stroke-linecap="round"/>' +
    '<circle cx="133" cy="68" r="13" fill="none" stroke="#1f1d1a" stroke-width="2.6"/><path d="M133 49v10M133 77v10M114 68h10M142 68h10" stroke="#1f1d1a" stroke-width="2.6" stroke-linecap="round"/>' +
    "</svg>";

  var RULES = [
    "<h3>The goal</h3>",
    "<p>First to <b>10 points</b>, or wipe out the other army. Every turn you score 1 point for each gold control point one of your units stands on.</p>",
    "<h3>A turn</h3><ol>",
    "<li>Both players secretly give <b>every unit one order</b>: Move, Attack, Brace or Hold.</li>",
    "<li>All moves happen at once. Two units heading for the same square both bounce back. So do two units trying to swap places.</li>",
    "<li>Then all attacks land at once, on the <b>squares</b> they were aimed at. If the enemy moved away, you hit nothing. If your own unit walked in, you hit it.</li>",
    "<li>Points are scored.</li></ol>",
    "<h3>Your army</h3>",
    '<dl class="kv"><dt>' + iconSvg("brute") + " Brute</dt><dd>4 health. Moves 1. Hits a square next to it for 2.</dd>",
    "<dt>" + iconSvg("archer") + " Archer</dt><dd>2 health. Moves 1. Shoots a square 2 to 3 away for 1.</dd>",
    "<dt>" + iconSvg("scout") + " Scout</dt><dd>2 health. Moves up to 2. Hits a square next to it for 1.</dd>",
    "<dt>" + iconSvg("mage") + " Mage</dt><dd>2 health. Moves 1. Blasts a plus shape up to 2 away for 1 on every square, friend or foe.</dd></dl>",
    "<p><b>Brace</b> takes 1 less damage from every hit this turn. <b>Hold</b> does nothing, which is fine if you're already on a point.</p>",
    '<div class="tip">You aren\'t shooting at units, you\'re shooting at where you think they\'ll be. Units on points are predictable, which makes them targets. Bracing on a point, or dodging off it, is the whole game.</div>'
  ].join("");

  var G = { state: null, cfg: null, rand: null, level: "normal", human: [true, false], viewer: 0, plans: [{}, {}], sel: -1, mode: "move", phase: "plan", resolver: null, token: 0, nodes: {}, layers: {}, timerEnd: 0, timerId: null, say: "" };

  function dispIdx(i) { return G.viewer === 1 ? SG.N - 1 - i : i; }
  function px(i) { var d = dispIdx(i); return PAD + SG.cOf(d) * S + S / 2; }
  function py(i) { var d = dispIdx(i); return PAD + SG.rOf(d) * S + S / 2; }
  function cellX(i) { var d = dispIdx(i); return PAD + SG.cOf(d) * S; }
  function cellY(i) { var d = dispIdx(i); return PAD + SG.rOf(d) * S; }

  /* ---------- Board ---------- */
  function buildBoard() {
    var stage = K.$("#stage");
    stage.innerHTML = "";
    var svg = sv("svg", { id: "board", viewBox: "0 0 " + VB + " " + VB, role: "img", "aria-label": "Battlefield" });
    var tiles = sv("g");
    for (var i = 0; i < SG.N; i++) {
      var x = cellX(i), y = cellY(i);
      if (SG.WALL[i]) {
        tiles.appendChild(sv("rect", { x: x + 1, y: y + 1, width: S - 2, height: S - 2, rx: 5, class: "wallb" }));
        tiles.appendChild(sv("rect", { x: x + 5, y: y + 4, width: S - 10, height: S - 12, rx: 3, class: "wallt" }));
      } else {
        tiles.appendChild(sv("rect", { x: x, y: y, width: S, height: S, class: (SG.cOf(i) + SG.rOf(i)) % 2 ? "tl-b" : "tl-a" }));
      }
    }
    for (var k = 0; k <= SG.COLS; k++) {
      tiles.appendChild(sv("path", { d: "M" + (PAD + k * S) + " " + PAD + "V" + (PAD + SG.ROWS * S), class: "grid-line" }));
      tiles.appendChild(sv("path", { d: "M" + PAD + " " + (PAD + k * S) + "H" + (PAD + SG.COLS * S), class: "grid-line" }));
    }
    svg.appendChild(tiles);
    ["points", "hl", "orders", "units", "fx"].forEach(function (n) { var g = sv("g", { class: n }); G.layers[n] = g; svg.appendChild(g); });
    var hit = sv("g", { class: "hit-layer" });
    for (var j = 0; j < SG.N; j++) hit.appendChild(sv("rect", { x: cellX(j), y: cellY(j), width: S, height: S, "data-i": String(j) }));
    hit.addEventListener("click", function (e) { var t = e.target; if (t && t.getAttribute("data-i") != null) onTile(+t.getAttribute("data-i")); });
    svg.appendChild(hit);
    stage.appendChild(svg);
    G.nodes = {};
  }

  function tokNode(u) {
    var n = G.nodes[u.id];
    if (n) return n;
    n = sv("g", { class: "tok" });
    n.appendChild(sv("rect", { class: "tok-sel", x: "-21", y: "-21", width: "42", height: "42", rx: "10" }));
    n.appendChild(sv("rect", { class: "tok-body " + SC[u.side], x: "-17", y: "-17", width: "34", height: "34", rx: "8" }));
    var ic = sv("g", { class: "tok-icon", transform: "translate(-10 -12) scale(.83)" });
    ic.innerHTML = ICON[u.kind];
    n.appendChild(ic);
    var hp = sv("g", { class: "hp" });
    var max = SG.KINDS[u.kind].hp;
    for (var q = 0; q < max; q++) hp.appendChild(sv("rect", { class: "tok-hp", x: String(-max * 3.5 + q * 7 + 0.5), y: "9", width: "6", height: "4", rx: "1" }));
    n.appendChild(hp);
    n.appendChild(sv("path", { class: "tok-shield", d: "M12 -20l7 3v4c0 4-3 6.5-7 8-4-1.5-7-4-7-8v-4z" }));
    G.layers.units.appendChild(n);
    G.nodes[u.id] = n;
    return n;
  }

  function placeTokens() {
    var st = G.state;
    st.units.forEach(function (u) {
      var n = tokNode(u);
      n.classList.toggle("dead", !u.alive);
      n.classList.toggle("selected", G.phase === "plan" && G.sel === u.id);
      var plan = G.plans[u.side] || {};
      var showPlan = G.phase === "reveal" || (G.phase === "plan" && u.side === G.planSide);
      n.classList.toggle("brace", showPlan && plan[u.id] && plan[u.id].k === "brace");
      var hp = n.querySelectorAll(".tok-hp");
      for (var q = 0; q < hp.length; q++) hp[q].classList.toggle("lost", q >= u.hp);
      if (u.alive) n.style.transform = "translate(" + px(u.pos) + "px," + py(u.pos) + "px)";
    });
  }

  /* ---------- Render ---------- */
  function render() {
    if (!G.state) return;
    renderPoints();
    renderHL();
    renderOrders();
    placeTokens();
    renderTop();
    renderBar();
  }

  function renderPoints() {
    var g = G.layers.points;
    g.innerHTML = "";
    SG.POINTS.forEach(function (p) {
      var u = SG.unitAt(G.state, p);
      g.appendChild(sv("circle", { cx: px(p), cy: py(p), r: "21", class: "pt-fill" + (u ? " " + SC[u.side] : "") }));
      g.appendChild(sv("circle", { cx: px(p), cy: py(p), r: "21", class: "pt-ring" }));
      g.appendChild(sv("path", { d: "M" + (px(p) + 13) + " " + (py(p) - 22) + "v12M" + (px(p) + 13) + " " + (py(p) - 22) + "l8 3-8 3", class: "pt-flag", stroke: "#7a5a0e", "stroke-width": "1.2" }));
    });
  }

  function renderHL() {
    var g = G.layers.hl;
    g.innerHTML = "";
    if (G.phase !== "plan" || G.sel < 0 || !G.resolver) return;
    var u = G.state.units[G.sel];
    if (G.mode === "move") SG.moveTargets(G.state, u).forEach(function (t) { g.appendChild(sv("rect", { x: cellX(t) + 4, y: cellY(t) + 4, width: S - 8, height: S - 8, rx: 6, class: "hl-move" })); });
    if (G.mode === "attack") SG.attackTargets(G.state, u).forEach(function (t) { g.appendChild(sv("rect", { x: cellX(t) + 6, y: cellY(t) + 6, width: S - 12, height: S - 12, rx: 6, class: "hl-attack" })); });
  }

  function arrow(g, from, to, cls) {
    var x1 = px(from), y1 = py(from), x2 = px(to), y2 = py(to);
    var dx = x2 - x1, dy = y2 - y1, L = Math.sqrt(dx * dx + dy * dy) || 1, ux = dx / L, uy = dy / L;
    var ex = x2 - ux * 14, ey = y2 - uy * 14;
    g.appendChild(sv("path", { d: "M" + (x1 + ux * 18) + " " + (y1 + uy * 18) + "L" + ex + " " + ey, class: "ord-move " + cls }));
    var hx = ex - ux * 7, hy = ey - uy * 7, nx = -uy, ny = ux;
    g.appendChild(sv("path", { d: "M" + ex + " " + ey + "L" + (hx + nx * 5) + " " + (hy + ny * 5) + "L" + (hx - nx * 5) + " " + (hy - ny * 5) + "z", class: "ord-head " + cls }));
  }
  function aim(g, kind, to, cls) {
    if (SG.KINDS[kind].blast) SG.hitTiles(kind, to).forEach(function (t) { g.appendChild(sv("rect", { x: cellX(t) + 3, y: cellY(t) + 3, width: S - 6, height: S - 6, rx: 5, class: "ord-blast " + cls })); });
    var x = px(to), y = py(to);
    g.appendChild(sv("circle", { cx: x, cy: y, r: "11", class: "ord-aim " + cls }));
    g.appendChild(sv("path", { d: "M" + x + " " + (y - 17) + "v8M" + x + " " + (y + 9) + "v8M" + (x - 17) + " " + y + "h8M" + (x + 9) + " " + y + "h8", class: "ord-aim " + cls }));
  }

  function friendlyRisk(side) {
    var st = G.state, plan = G.plans[side] || {}, risky = [];
    var ends = {};
    st.units.forEach(function (u) { if (u.alive && u.side === side) { var o = plan[u.id]; ends[u.id] = o && o.k === "move" ? o.to : u.pos; } });
    st.units.forEach(function (u) {
      var o = plan[u.id];
      if (!u.alive || u.side !== side || !o || o.k !== "attack") return;
      SG.hitTiles(u.kind, o.to).forEach(function (t) {
        Object.keys(ends).forEach(function (id) { if (ends[id] === t) risky.push(t); });
      });
    });
    return risky;
  }

  function renderOrders() {
    var g = G.layers.orders;
    g.innerHTML = "";
    var sides = G.phase === "reveal" ? [0, 1] : (G.phase === "plan" && G.planSide != null ? [G.planSide] : []);
    sides.forEach(function (side) {
      var plan = G.plans[side] || {};
      G.state.units.forEach(function (u) {
        var o = plan[u.id];
        if (!u.alive || u.side !== side || !o) return;
        if (o.k === "move") arrow(g, u.pos, o.to, SC[side]);
        if (o.k === "attack") aim(g, u.kind, o.to, SC[side]);
      });
      if (G.phase === "plan") friendlyRisk(side).forEach(function (t) {
        g.appendChild(sv("circle", { cx: px(t) - 14, cy: py(t) - 14, r: "7", class: "ord-warn" }));
        g.appendChild(sv("text", { x: px(t) - 14, y: py(t) - 10.5, "text-anchor": "middle", "font-size": "10", "font-weight": "800", fill: "#c43b30", text: "!" }));
      });
    });
  }

  function renderTop() {
    var st = G.state, main, sub;
    if (st.winner != null) { main = st.winner === "draw" ? "Draw" : SG.sideName(st.winner) + " wins"; sub = st.reason; }
    else if (G.phase === "plan" && G.resolver) { main = G.cfg.mode === "local" ? SG.sideName(G.planSide) + ": plan" : "Plan your orders"; sub = "Turn " + st.turn + " of " + SG.TURN_LIMIT + " · first to " + SG.WIN_POINTS; }
    else if (G.phase === "reveal") { main = "Reveal"; sub = "Turn " + st.turn; }
    else { main = "Turn " + st.turn; sub = ""; }
    K.$("#st-main").textContent = main;
    K.$("#st-sub").textContent = sub;
    var sc = K.$("#scores");
    sc.innerHTML = "";
    [0, 1].forEach(function (side) {
      sc.appendChild(h("span", { class: "chip", title: SG.sideName(side) + " points" }, h("i", { style: "background:" + COLOR[side] }), String(st.scores[side]), h("small", null, "/" + SG.WIN_POINTS)));
    });
  }

  function orderWord(o) {
    if (!o || o.k === "hold") return "Hold";
    return o.k === "move" ? "Move" : o.k === "attack" ? "Attack" : "Brace";
  }

  function renderBar() {
    var bar = K.$("#actionbar");
    bar.innerHTML = "";
    var st = G.state;
    if (st.winner != null) {
      bar.appendChild(h("p", { class: "say", html: G.say || "&nbsp;" }));
      bar.appendChild(h("div", { class: "bar-row" },
        h("button", { class: "btn btn-primary", type: "button", onclick: function () { restart(); } }, "Rematch"),
        h("button", { class: "btn", type: "button", onclick: function () { K.quit(); } }, "Main menu")));
      return;
    }
    if (G.phase !== "plan" || !G.resolver) {
      bar.appendChild(h("p", { class: "say", html: G.say || "&nbsp;" }));
      return;
    }
    var side = G.planSide, plan = G.plans[side];
    var row = h("div", { class: "unitrow" });
    st.units.forEach(function (u) {
      if (u.side !== side) return;
      row.appendChild(h("button", {
        class: "ucard" + (u.alive ? "" : " dead") + (plan[u.id] && plan[u.id].k !== "hold" ? " set" : ""), type: "button", disabled: !u.alive,
        "aria-pressed": G.sel === u.id ? "true" : "false", onclick: function () { selectUnit(u.id); }
      }, h("span", { html: iconSvg(u.kind, COLOR[side]) }), h("span", { class: "nm" }, SG.KINDS[u.kind].name), h("span", { class: "od" }, u.alive ? orderWord(plan[u.id]) : "down")));
    });
    bar.appendChild(row);
    var risky = friendlyRisk(side).length > 0;
    var hint = risky ? "Careful: one of your attacks lands on your own unit." : G.sel < 0 ? "Pick a unit, then tap the board to give it an order." :
      G.mode === "move" ? "Tap a square to move there." : G.mode === "attack" ? "Tap the square you think an enemy will be on." : "";
    bar.appendChild(h("p", { class: "say" + (risky ? " warn" : "") }, hint));
    if (G.sel >= 0) {
      var modes = h("div", { class: "modes" });
      [["move", "Move"], ["attack", "Attack"], ["brace", "Brace"], ["hold", "Hold"]].forEach(function (m) {
        var cur = plan[G.sel] ? plan[G.sel].k : "hold";
        var pressed = (m[0] === "move" || m[0] === "attack") ? G.mode === m[0] : cur === m[0];
        var isOrder = m[0] === "brace" || m[0] === "hold";
        modes.appendChild(h("button", { class: "btn btn-sm" + (isOrder ? " order" : ""), type: "button", "aria-pressed": pressed ? "true" : "false", onclick: function () { setMode(m[0]); } }, m[1]));
      });
      bar.appendChild(modes);
    }
    var ready = h("div", { class: "bar-row" });
    if (G.timerEnd) ready.appendChild(h("span", { class: "timer", id: "timer" }, Math.max(0, Math.ceil((G.timerEnd - Date.now()) / 1000)) + "s"));
    ready.appendChild(h("button", { class: "btn btn-primary", type: "button", onclick: function () { K.Sound.play("select"); commit(); } }, "Lock in orders"));
    bar.appendChild(ready);
  }

  /* ---------- Input ---------- */
  function selectUnit(id) {
    var u = G.state.units[id];
    if (!u.alive || u.side !== G.planSide) return;
    K.Sound.play("tap");
    G.sel = id;
    var o = G.plans[G.planSide][id];
    G.mode = o && o.k === "attack" ? "attack" : "move";
    render();
  }
  function setMode(m) {
    if (G.sel < 0) return;
    K.Sound.play("tap");
    if (m === "brace" || m === "hold") { G.plans[G.planSide][G.sel] = { k: m }; G.mode = "move"; nextUnit(); }
    else G.mode = m;
    render();
  }
  function nextUnit() {
    var side = G.planSide, plan = G.plans[side];
    var mine = G.state.units.filter(function (u) { return u.alive && u.side === side; });
    var k = mine.findIndex(function (u) { return u.id === G.sel; });
    for (var q = 1; q <= mine.length; q++) {
      var u = mine[(k + q) % mine.length];
      if (!plan[u.id] || plan[u.id].k === "hold") { G.sel = u.id; G.mode = "move"; return; }
    }
  }
  function onTile(i) {
    if (G.phase !== "plan" || !G.resolver) return;
    var st = G.state, side = G.planSide;
    var there = SG.unitAt(st, i);
    if (there && there.side === side && (G.mode !== "attack" || G.sel < 0)) { selectUnit(there.id); return; }
    if (G.sel < 0) return;
    var u = st.units[G.sel];
    if (G.mode === "move") {
      if (i === u.pos) { G.plans[side][u.id] = { k: "hold" }; K.Sound.play("tap"); render(); return; }
      if (SG.moveTargets(st, u).indexOf(i) < 0) { K.Sound.play("error"); return; }
      G.plans[side][u.id] = { k: "move", to: i };
    } else {
      if (SG.attackTargets(st, u).indexOf(i) < 0) { K.Sound.play("error"); return; }
      G.plans[side][u.id] = { k: "attack", to: i };
    }
    K.Sound.play("select");
    nextUnit();
    render();
  }

  function commit() {
    if (!G.resolver) return;
    stopTimer();
    var r = G.resolver; G.resolver = null;
    r();
  }

  function startTimer() {
    stopTimer();
    if (G.cfg.timer !== "30") { G.timerEnd = 0; return; }
    G.timerEnd = Date.now() + 30000;
    G.timerId = setInterval(function () {
      var left = Math.ceil((G.timerEnd - Date.now()) / 1000);
      var el = K.$("#timer");
      if (el) el.textContent = Math.max(0, left) + "s";
      if (left <= 5 && left > 0) K.Sound.play("tick");
      if (left <= 0) { K.toast("Time! Unset units hold."); commit(); }
    }, 250);
  }
  function stopTimer() { if (G.timerId) clearInterval(G.timerId); G.timerId = null; G.timerEnd = 0; }

  /* ---------- Turn flow ---------- */
  function plan(side) {
    return new Promise(function (resolve) {
      G.phase = "plan";
      G.planSide = side;
      G.plans[side] = {};
      G.state.units.forEach(function (u) { if (u.alive && u.side === side) G.plans[side][u.id] = { k: "hold" }; });
      var first = G.state.units.filter(function (u) { return u.alive && u.side === side; })[0];
      G.sel = first ? first.id : -1;
      G.mode = "move";
      G.resolver = resolve;
      startTimer();
      render();
    });
  }

  async function passTo(side, title, text) {
    G.viewer = side;
    G.phase = "cover";
    buildBoard();
    render();
    await K.cover({ className: SC[side], kicker: "Turn " + G.state.turn, title: title, text: text, cta: "I'm " + SG.sideName(side) });
  }

  async function reveal(token) {
    var st = G.state;
    G.phase = "reveal";
    G.sel = -1;
    render();
    await K.banner("REVEAL", { tone: "accent", ms: 700 });
    if (token !== G.token) return;
    await K.sleep(700);
    var before = SG.cloneState(st);
    var orders = Object.assign({}, G.plans[0], G.plans[1]);
    var ev = SG.resolve(st, orders);
    /* moves */
    var moved = ev.moves.length > 0;
    ev.bumps.forEach(function (b) {
      var n = G.nodes[b.id];
      if (n && n.animate) {
        var mx = (px(b.to) - px(b.from)) * 0.35, my = (py(b.to) - py(b.from)) * 0.35;
        try { n.animate([{ transform: "translate(" + px(b.from) + "px," + py(b.from) + "px)" }, { transform: "translate(" + (px(b.from) + mx) + "px," + (py(b.from) + my) + "px)" }, { transform: "translate(" + px(b.from) + "px," + py(b.from) + "px)" }], { duration: 420 }); } catch (e) {}
      }
    });
    var hpNow = st.units.map(function (u) { return u.hp; });
    var aliveNow = st.units.map(function (u) { return u.alive; });
    st.units.forEach(function (u, k) { u.hp = before.units[k].hp; u.alive = before.units[k].alive; });
    G.phase = "reveal-move";
    render();
    if (moved) K.Sound.play("slide");
    if (ev.bumps.length) { K.Sound.play("error"); G.say = "<b>Bump!</b> Units heading for the same square bounced back."; }
    await K.sleep(520);
    if (token !== G.token) return;
    /* attacks */
    G.layers.orders.innerHTML = "";
    ev.attacks.forEach(function (a) {
      var shot = sv("line", { x1: px(a.from), y1: py(a.from), x2: px(a.to), y2: py(a.to), class: "fx-shot" });
      G.layers.fx.appendChild(shot);
      a.tiles.forEach(function (t) {
        var boom = sv("circle", { cx: px(t), cy: py(t), r: "16", class: "fx-boom" });
        G.layers.fx.appendChild(boom);
        setTimeout(function () { boom.remove(); }, 650);
      });
      setTimeout(function () { shot.remove(); }, 450);
    });
    if (ev.attacks.length) K.Sound.play("whoosh");
    await K.sleep(300);
    st.units.forEach(function (u, k) { u.hp = hpNow[k]; u.alive = aliveNow[k]; });
    var any = false;
    Object.keys(ev.damage).forEach(function (id) {
      var u = st.units[+id], amount = ev.damage[id];
      if (!amount) return;
      any = true;
      var t = sv("text", { x: px(u.pos), y: py(u.pos) - 22, "text-anchor": "middle", class: "fx-dmg", fill: "#c43b30", text: "−" + amount });
      G.layers.fx.appendChild(t);
      if (t.animate) try { t.animate([{ transform: "translateY(0)", opacity: 1 }, { transform: "translateY(-14px)", opacity: 0 }], { duration: 1100, fill: "forwards" }); } catch (e) {}
      setTimeout(function () { t.remove(); }, 1150);
    });
    if (any) { K.Sound.play("hit"); K.shake(K.$("#stage")); }
    else if (ev.attacks.length) K.Sound.play("miss");
    render();
    var notes = [];
    var hitsOnEnemy = 0, friendly = 0, misses = 0;
    ev.attacks.forEach(function (a) { if (!a.hits.length) misses++; a.hits.forEach(function (x) { if (x.friendly) friendly++; else hitsOnEnemy++; }); });
    if (ev.deaths.length) notes.push(ev.deaths.map(function (id) { var u = st.units[id]; return SG.sideName(u.side) + " " + SG.KINDS[u.kind].name; }).join(", ") + " down.");
    if (misses) notes.push(misses + (misses === 1 ? " shot" : " shots") + " hit empty ground.");
    if (friendly) notes.push(friendly + " friendly " + (friendly === 1 ? "hit" : "hits") + "!");
    await K.sleep(800);
    if (token !== G.token) return;
    /* points */
    ev.held.forEach(function (hd) {
      var t = sv("text", { x: px(hd.pt), y: py(hd.pt) - 26, "text-anchor": "middle", class: "fx-dmg", fill: COLOR[hd.side], text: "+1" });
      G.layers.fx.appendChild(t);
      setTimeout(function () { t.remove(); }, 900);
    });
    if (ev.held.length) K.Sound.play("score");
    notes.unshift("Blue <b>+" + ev.points[0] + "</b> · Red <b>+" + ev.points[1] + "</b>.");
    G.say = notes.join(" ");
    G.plans = [{}, {}];
    G.phase = "after";
    render();
    await K.sleep(900);
  }

  async function runGame(token) {
    var st = G.state;
    var local = G.cfg.mode === "local";
    while (st.winner == null) {
      if (token !== G.token) return;
      if (local) {
        await passTo(0, "Blue's orders", "Red, look away while Blue plans.");
        if (token !== G.token) return;
        await plan(0);
        if (token !== G.token) return;
        await passTo(1, "Red's orders", "Blue, look away while Red plans.");
        if (token !== G.token) return;
        await plan(1);
        if (token !== G.token) return;
        G.viewer = 0;
        G.phase = "cover";
        buildBoard();
        render();
        await K.cover({ kicker: "Turn " + st.turn, title: "Reveal", text: "Both players, look at the board.", cta: "Show me" });
        if (token !== G.token) return;
      } else {
        G.viewer = 0;
        await plan(0);
        if (token !== G.token) return;
        G.plans[1] = SG.bots.plan(st, 1, G.level, G.rand);
      }
      await reveal(token);
    }
    if (token !== G.token) return;
    await endGame(token);
  }

  async function endGame(token) {
    var st = G.state;
    stopTimer();
    render();
    var youWon = G.cfg.mode === "bot" ? st.winner === 0 : null;
    await K.banner(st.winner === "draw" ? "DRAW" : SG.sideName(st.winner).toUpperCase() + " WINS", { tone: st.winner === 0 ? "accent" : "bad", ms: 1500 });
    if (token !== G.token) return;
    var choice = await K.gameOver({
      title: G.cfg.mode === "bot" ? (st.winner === "draw" ? "A draw" : youWon ? "You win!" : "You lose") : (st.winner === "draw" ? "A draw" : SG.sideName(st.winner) + " wins"),
      tone: youWon === false ? "bad" : "good",
      text: st.reason,
      stats: [["Points (Blue – Red)", st.scores[0] + " – " + st.scores[1]], ["Turns", st.turn]],
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
    newMatch();
  }
  function newMatch() {
    G.token++;
    stopTimer();
    G.state = SG.newGame();
    G.rand = SG.rng((Date.now() ^ Math.floor(Math.random() * 1e9)) >>> 0);
    G.plans = [{}, {}]; G.sel = -1; G.resolver = null; G.phase = "plan"; G.planSide = 0; G.viewer = 0;
    G.say = "";
    K.showScreen("game");
    buildBoard();
    render();
    runGame(G.token);
  }
  function restart() { K.$all(".cover,.modal-wrap,.banner").forEach(function (n) { n.remove(); }); newMatch(); }
  function quit() { G.token++; stopTimer(); G.resolver = null; }

  window.__secondDebug = { G: G };

  K.init({
    ns: "second-guess",
    title: "Second Guess",
    tagline: "Both players move at the same time. Aim where they'll be, not where they are.",
    art: TITLE_ART,
    rules: RULES,
    options: [
      { id: "mode", label: "Opponent", default: "bot", choices: [{ v: "bot", t: "Bot" }, { v: "local", t: "Friend, same phone" }] },
      { id: "difficulty", label: "Bot level", default: "normal", choices: [{ v: "easy", t: "Easy" }, { v: "normal", t: "Normal" }, { v: "hard", t: "Hard" }], showIf: function (c) { return c.mode === "bot"; },
        note: function (c) { return c.difficulty === "hard" ? "Predicts your likely plans and counters them." : c.difficulty === "easy" ? "Mostly shoots where you are, not where you'll be." : "Tries to guess where you'll move."; } },
      { id: "timer", label: "Planning timer", default: "off", choices: [{ v: "off", t: "Off" }, { v: "30", t: "30 seconds" }],
        note: function (c) { return c.mode === "local" ? "Cover screens hide each player's orders from the other." : null; } }
    ],
    onStart: start,
    onRestart: restart,
    onQuit: quit,
    menuNote: function () { return G.state ? "Turn " + G.state.turn + ". Blue " + G.state.scores[0] + ", Red " + G.state.scores[1] + "." : ""; }
  });
})();
