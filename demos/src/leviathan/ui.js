/* Leviathan Hunt: interface, animation and turn flow. */
(function () {
  "use strict";
  var L = window.Leviathan, K = window.Kit, h = K.h, sv = K.s;
  var R = 20, HW = Math.sqrt(3) * R, PAD = 6;
  var VBW = PAD * 2 + HW * (L.COLS + 0.5), VBH = PAD * 2 + 2 * R + (L.ROWS - 1) * 1.5 * R;
  function cx(i) { var r = L.rOf(i); return PAD + HW / 2 + L.cOf(i) * HW + (r & 1 ? HW / 2 : 0); }
  function cy(i) { return PAD + R + L.rOf(i) * 1.5 * R; }
  function hexPts(i, rr) {
    var x = cx(i), y = cy(i), out = [];
    for (var k = 0; k < 6; k++) {
      var a = Math.PI / 180 * (60 * k - 30);
      out.push((x + rr * Math.cos(a)).toFixed(2) + "," + (y + rr * Math.sin(a)).toFixed(2));
    }
    return out.join(" ");
  }

  var ICON = {
    ping: '<circle cx="12" cy="15.5" r="1.8" fill="currentColor" stroke="none"/><path d="M8.2 11.6a5.4 5.4 0 0 1 7.6 0"/><path d="M5.2 8.4a9.6 9.6 0 0 1 13.6 0"/>',
    harpoon: '<path d="M5 19L17.5 6.5"/><path d="M18.5 5.5l-6.2 1.3 4.9 4.9z" fill="currentColor"/><path d="M7.5 18.8l-2.3-2.3"/>',
    net: '<path d="M4 12l8-8 8 8-8 8z"/><path d="M8 8l8 8M16 8l-8 8"/>',
    beam: '<path d="M10.2 20h3.6l-.8-11h-2z" fill="currentColor"/><path d="M9 9h6M12 5.5V9"/><path d="M15.5 10l4.5-2.2M15.5 12.5l4.5 1.8"/>',
    hits: '<path d="M4 20L18 6"/><path d="M19.5 4.5l-6.5 1.4 5.1 5.1z" fill="currentColor"/>',
    kills: '<path d="M12 3c-4.4 0-8 3.2-8 7.3 0 2.4 1.2 4.4 3 5.7V20h10v-4c1.8-1.3 3-3.3 3-5.7C20 6.2 16.4 3 12 3z"/><circle cx="9" cy="11" r="1.6" fill="currentColor"/><circle cx="15" cy="11" r="1.6" fill="currentColor"/>'
  };
  function iconSvg(name, cls) {
    return '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="' + (cls || "") + '">' + ICON[name] + "</svg>";
  }

  var TITLE_ART = '<svg viewBox="0 0 260 170" role="img" aria-label="A sea serpent rising beside a hunter ship">' +
    '<defs><radialGradient id="ta-glow" cx="50%" cy="50%" r="50%"><stop offset="0" stop-color="#ff4f6d" stop-opacity=".55"/><stop offset="1" stop-color="#ff4f6d" stop-opacity="0"/></radialGradient></defs>' +
    '<circle cx="150" cy="58" r="56" fill="url(#ta-glow)"/>' +
    '<path d="M118 132c-6-34 6-64 34-78 18-9 36-4 42 8 4 9-2 18-12 17-9-1-12-9-20-8-14 2-22 26-18 61z" fill="#d61f52" stroke="#3d0614" stroke-width="3" stroke-linejoin="round"/>' +
    '<ellipse cx="178" cy="62" rx="9" ry="6" fill="#ffd166"/><ellipse cx="179" cy="62" rx="2" ry="5" fill="#2a0610"/>' +
    '<path d="M186 73l4 7 3-6 4 6 2-7" fill="none" stroke="#ffe9c2" stroke-width="2.4" stroke-linejoin="round"/>' +
    '<path d="M60 118l18 8h28l10-10z" fill="#f2b84b" stroke="#2a1a02" stroke-width="3" stroke-linejoin="round"/><path d="M84 116V86M84 90l18 14H84" fill="none" stroke="#e9f1f7" stroke-width="3" stroke-linejoin="round"/>' +
    '<path d="M98 108l40-36" stroke="#e9f1f7" stroke-width="3" stroke-linecap="round"/><path d="M141 69l-9 2 7 7z" fill="#e9f1f7"/>' +
    '<path d="M10 136c14-8 26-8 40 0s26 8 40 0 26-8 40 0 26 8 40 0 26-8 40 0 26 8 40 0" fill="none" stroke="#4fd1c5" stroke-width="4" stroke-linecap="round"/>' +
    '<path d="M24 152c14-8 26-8 40 0s26 8 40 0 26-8 40 0 26 8 40 0 26-8 40 0" fill="none" stroke="#2a6f8f" stroke-width="4" stroke-linecap="round"/>' +
    "</svg>";

  var RULES = [
    "<h3>The goal</h3>",
    "<p><b>Hunters</b> win with <b>3 harpoon hits</b>, or by holding out until dawn at the end of round 20.</p>",
    "<p>The <b>Leviathan</b> wins by destroying <b>4 targets</b> (buoys or ships). Sinking the Harpoon ship wins on the spot.</p>",
    "<h3>The Leviathan's turn</h3><ul>",
    "<li><b>Swim</b> 1 tile, or stay put. Silent.</li>",
    "<li><b>Dash</b> 2 tiles. Fast, but it leaves a wake where it started.</li>",
    "<li><b>Strike</b> a ship next to it for 1 damage. Ships have 2 health.</li>",
    "<li>Ending a move on a buoy devours it.</li>",
    "<li>Striking, devouring and the end of every 6th round reveal where it is.</li></ul>",
    "<h3>The hunters' turn: 3 orders</h3>",
    "<p>Each ship can move once (up to 2 tiles) and use its tool once. Each costs 1 order.</p>",
    '<dl class="kv"><dt>Sonar</dt><dd>Pings everything within 2 tiles: contact or clear.</dd>',
    "<dt>Harpoon</dt><dd>Throws at one tile up to 2 away. The only way to wound the Leviathan.</dd>",
    "<dt>Net</dt><dd>Drops a net on a tile next to it. Snags the Leviathan if it's there (no dashing next turn). Otherwise the tile is blocked for 3 rounds.</dd>",
    "<dt>Lighthouse</dt><dd>Lights a straight line 4 tiles long.</dd></dl>",
    "<p>Sailing through the Leviathan's tile bumps into it and reveals it.</p>",
    "<h3>The map</h3><ul><li><b>Islands</b> block everything.</li><li><b>Reefs</b> block ships, but the Leviathan can hide in them.</li><li>It starts somewhere in the <b>northern waters</b> (the top 4 rows).</li></ul>",
    "<h3>The red haze</h3><p>Shows every tile the Leviathan could be on, worked out from every clue so far. Turn it off for a harder hunt.</p>",
    '<div class="tip"><b>Hunters:</b> keep the Harpoon ship central, ping before you throw, and keep damaged ships away from the haze.<br><b>Leviathan:</b> feed far from the Harpoon ship, dash to break a closing net, and remember you surface every 6th round.</div>'
  ].join("");

  var G = {
    state: null, cfg: null, rand: null, viewer: "hunters", locked: false,
    humanMonster: false, humanHunters: false, level: "normal",
    sel: 1, shipMode: "move", pending: null, haze: true, recap: "", review: false,
    resolver: null, monsterOpts: null, startPick: false, token: 0, svg: null, layers: {}
  };

  /* ---------- Board construction ---------- */
  function buildBoard() {
    var stage = K.$("#stage");
    stage.innerHTML = "";
    var svg = sv("svg", { id: "board", viewBox: "0 0 " + VBW.toFixed(1) + " " + VBH.toFixed(1), role: "img", "aria-label": "Hex sea board" });
    svg.appendChild(sv("defs", null,
      sv("pattern", { id: "mesh", width: "6", height: "6", patternUnits: "userSpaceOnUse", patternTransform: "rotate(45)" },
        sv("path", { d: "M0 0H6M0 0V6", stroke: "rgba(233,241,247,.55)", "stroke-width": "1", fill: "none" })),
      sv("pattern", { id: "reefdots", width: "7", height: "7", patternUnits: "userSpaceOnUse" },
        sv("circle", { cx: "2", cy: "2", r: "1", fill: "rgba(140,230,220,.35)" }),
        sv("circle", { cx: "5.5", cy: "5.5", r: ".8", fill: "rgba(140,230,220,.25)" }))));
    var tiles = sv("g", { class: "tiles" });
    var st = G.state;
    for (var i = 0; i < L.N; i++) {
      var t = st.terrain[i];
      var cls = t === L.ISLAND ? "t-island" : t === L.REEF ? "t-reef" : "t-sea" + ((L.cOf(i) + L.rOf(i)) % 3 === 0 ? " alt" : "");
      tiles.appendChild(sv("polygon", { points: hexPts(i, R - 0.9), class: cls }));
      if (t === L.REEF) tiles.appendChild(sv("polygon", { points: hexPts(i, R - 2.5), fill: "url(#reefdots)" }));
      if (t === L.ISLAND) tiles.appendChild(sv("path", { d: "M" + (cx(i) - 6).toFixed(1) + " " + (cy(i) + 4).toFixed(1) + "q6 -9 12 0", fill: "none", stroke: "#8d8559", "stroke-width": "1.6", "stroke-linecap": "round" }));
    }
    svg.appendChild(tiles);
    ["marks", "units", "over", "fx"].forEach(function (name) {
      var g = sv("g", { class: name });
      G.layers[name] = g;
      svg.appendChild(g);
    });
    var hit = sv("g", { class: "hit-layer" });
    for (var j = 0; j < L.N; j++) hit.appendChild(sv("polygon", { points: hexPts(j, R), "data-i": String(j) }));
    hit.addEventListener("click", function (e) {
      var target = e.target.closest ? e.target.closest("polygon") : e.target;
      if (!target || target.getAttribute("data-i") == null) return;
      onTile(+target.getAttribute("data-i"));
    });
    svg.appendChild(hit);
    G.layers.hit = hit;
    stage.appendChild(svg);
    G.svg = svg;
    buildUnits();
  }

  function shipNode(k) {
    var sh = G.state.ships[k];
    var g = sv("g", { class: "unit ship", "data-ship": String(k) });
    g.appendChild(sv("circle", { class: "sel-ring", r: "17.5" }));
    g.appendChild(sv("circle", { class: "ship-body", r: "13" }));
    var icon = sv("g", { class: "ship-icon", transform: "translate(-9 -9) scale(.75)" });
    icon.innerHTML = ICON[sh.ability];
    g.appendChild(icon);
    var hp = sv("g", { class: "hp" });
    for (var q = 0; q < L.CFG.shipHP; q++) hp.appendChild(sv("rect", { class: "ship-hp", x: String(-7 + q * 8), y: "-21", width: "6", height: "4", rx: "1" }));
    g.appendChild(hp);
    return g;
  }

  function monsterNode() {
    var g = sv("g", { class: "unit monster" });
    g.appendChild(sv("circle", { class: "monster-glow", r: "19" }));
    g.appendChild(sv("path", { class: "monster-body", d: "M-13 3c0-9 6-15 13-15s13 6 13 15c0 4-2 7-5 9l-2-4-3 5-3-5-3 5-3-5-2 4c-3-2-5-5-5-9z" }));
    g.appendChild(sv("ellipse", { class: "monster-eye", cx: "0", cy: "-2", rx: "6.5", ry: "4.3" }));
    g.appendChild(sv("ellipse", { class: "monster-pupil", cx: "0.6", cy: "-2", rx: "1.5", ry: "3.6" }));
    return g;
  }

  function buildUnits() {
    var u = G.layers.units;
    u.innerHTML = "";
    G.shipNodes = G.state.ships.map(function (sh, k) { var n = shipNode(k); u.appendChild(n); return n; });
    G.monsterNode = monsterNode();
    u.appendChild(G.monsterNode);
    placeUnits(true);
  }

  function setPos(node, i, instant) {
    if (instant) node.style.transition = "none";
    node.style.transform = "translate(" + cx(i).toFixed(2) + "px," + cy(i).toFixed(2) + "px)";
    if (instant) { void node.getBoundingClientRect(); node.style.transition = ""; }
  }

  function placeUnits(instant) {
    var st = G.state;
    st.ships.forEach(function (sh, k) {
      var n = G.shipNodes[k];
      setPos(n, sh.pos, instant);
      n.classList.toggle("sunk", sh.sunk);
      var hp = n.querySelectorAll(".ship-hp");
      for (var q = 0; q < hp.length; q++) hp[q].classList.toggle("lost", q >= sh.hp);
    });
    var m = G.monsterNode;
    var show = monsterVisible();
    m.style.display = show ? "" : "none";
    if (show && st.monster.pos >= 0) setPos(m, st.monster.pos, instant);
    m.classList.toggle("hidden-from-hunters", G.viewer === "monster" && st.revealedAt !== st.monster.pos && !st.winner);
  }

  function monsterVisible() {
    var st = G.state;
    if (st.monster.pos < 0) return false;
    if (st.winner || G.review) return true;
    if (G.viewer === "monster") return true;
    return st.revealedAt >= 0 && st.revealedAt === st.monster.pos;
  }

  /* ---------- Rendering ---------- */
  function hexEl(i, cls, rr) { return sv("polygon", { points: hexPts(i, rr || R - 1.6), class: cls }); }

  function render() {
    var st = G.state;
    if (!st) return;
    var marks = G.layers.marks;
    marks.innerHTML = "";
    var phaseStart = st.phase === "start";
    if (phaseStart && G.viewer === "monster" && G.startPick) {
      L.startZone(st).forEach(function (t) { marks.appendChild(hexEl(t, "hl-start")); });
    }
    var showHaze = !phaseStart && G.haze && !st.winner && !G.review && (G.viewer === "hunters" || G.humanMonster);
    if (showHaze && !(st.revealedAt >= 0 && G.viewer === "hunters")) {
      var weak = st.P.length > 30;
      st.P.forEach(function (t) { marks.appendChild(hexEl(t, "haze" + (weak ? " weak" : ""))); });
    }
    st.nets.forEach(function (n) {
      marks.appendChild(hexEl(n.pos, "net-mesh", R - 3));
      marks.appendChild(sv("text", { x: (cx(n.pos) + 8).toFixed(1), y: (cy(n.pos) + 13).toFixed(1), class: "net-ttl", "text-anchor": "middle", text: String(n.ttl) }));
    });
    if (st.wake >= 0 && !st.winner) {
      var wg = sv("g", { class: "wake" });
      wg.appendChild(sv("circle", { cx: cx(st.wake).toFixed(1), cy: cy(st.wake).toFixed(1), r: "6" }));
      wg.appendChild(sv("circle", { cx: cx(st.wake).toFixed(1), cy: cy(st.wake).toFixed(1), r: "11" }));
      wg.appendChild(sv("circle", { cx: cx(st.wake).toFixed(1), cy: cy(st.wake).toFixed(1), r: "16", opacity: ".5" }));
      marks.appendChild(wg);
    }
    st.buoys.forEach(function (b) {
      var x = cx(b.pos), y = cy(b.pos);
      if (b.alive) {
        marks.appendChild(sv("circle", { cx: x.toFixed(1), cy: y.toFixed(1), r: "10", class: "buoy-ring" }));
        marks.appendChild(sv("path", { d: "M" + (x - 5).toFixed(1) + " " + (y + 3).toFixed(1) + "h10l-2 -8h-6z", class: "buoy" }));
        marks.appendChild(sv("circle", { cx: x.toFixed(1), cy: (y - 7).toFixed(1), r: "2.4", class: "buoy" }));
      } else {
        marks.appendChild(sv("path", { d: "M" + (x - 5) + " " + (y - 5) + "l10 10M" + (x + 5) + " " + (y - 5) + "l-10 10", class: "buoy-dead" }));
      }
    });
    renderHighlights(marks);
    G.layers.over.innerHTML = "";
    if (G.review || st.winner) renderTrail(G.layers.over);
    placeUnits(false);
    G.shipNodes.forEach(function (n, k) {
      var sh = st.ships[k];
      var selectable = G.resolver && G.mode === "hunters" && !sh.sunk;
      n.classList.toggle("selected", selectable && G.sel === k);
      n.classList.toggle("done", !sh.sunk && st.phase === "hunters" && sh.moved && sh.acted);
      var strikable = G.mode === "monster" && G.monsterOpts && G.monsterOpts.some(function (o) { return o.type === "strike" && o.ship === k; });
      n.classList.toggle("target-ring", !!strikable);
    });
    renderStatus();
    renderBar();
  }

  function renderHighlights(marks) {
    var st = G.state;
    if (G.mode === "hunters" && G.resolver && !G.locked) {
      var sh = st.ships[G.sel];
      if (sh && !sh.sunk) {
        if (G.shipMode === "move" && !sh.moved) {
          var mv = L.shipMoves(st, G.sel);
          Object.keys(mv).forEach(function (t) { marks.appendChild(hexEl(+t, "hl-move")); });
        } else if (G.shipMode === "ability" && !sh.acted) {
          if (sh.ability === "beam") {
            L.abilityTargets(st, G.sel).forEach(function (d) {
              L.beamTiles(st, sh.pos, d).forEach(function (t) { marks.appendChild(hexEl(t, "hl-beam")); });
            });
          } else if (sh.ability === "ping") {
            L.disk(sh.pos, L.CFG.sonarRange).forEach(function (t) { if (st.terrain[t] !== L.ISLAND) marks.appendChild(hexEl(t, "hl-ability")); });
          } else {
            L.abilityTargets(st, G.sel).forEach(function (t) { marks.appendChild(hexEl(t, "hl-ability")); });
          }
        }
      }
      if (G.pending) {
        var p = G.pending;
        if (p.type === "move") {
          (p.path || [p.to]).forEach(function (t) { marks.appendChild(hexEl(t, "hl-pending", R - 3)); });
        } else if (p.type === "beam") {
          L.beamTiles(st, st.ships[p.ship].pos, p.dir).forEach(function (t) { marks.appendChild(hexEl(t, "hl-pending", R - 3)); });
        } else if (p.type === "ping") {
          L.disk(st.ships[p.ship].pos, L.CFG.sonarRange).forEach(function (t) { if (st.terrain[t] !== L.ISLAND) marks.appendChild(hexEl(t, "hl-pending", R - 3)); });
        } else if (p.target != null) {
          marks.appendChild(hexEl(p.target, "hl-pending", R - 2));
        }
      }
    }
    if (G.mode === "monster" && G.resolver && !G.locked && G.monsterOpts) {
      G.monsterOpts.forEach(function (o) {
        if (o.type === "swim" && o.to !== st.monster.pos) marks.appendChild(hexEl(o.to, "hl-swim"));
        if (o.type === "dash") marks.appendChild(hexEl(o.to, "hl-dash"));
      });
      if (G.pending) {
        var tile = G.pending.type === "strike" ? st.ships[G.pending.ship].pos : G.pending.to;
        marks.appendChild(hexEl(tile, "hl-pending", R - 2));
      }
    }
    if (G.mode === "start" && G.pending != null) marks.appendChild(hexEl(G.pending, "hl-pending", R - 2));
  }

  function renderTrail(marks) {
    var tr = G.state.monster.trail;
    if (!tr.length) return;
    var d = "";
    tr.forEach(function (p, k) { d += (k ? "L" : "M") + cx(p.pos).toFixed(1) + " " + cy(p.pos).toFixed(1); });
    marks.appendChild(sv("path", { d: d, class: "trail" }));
    var seen = {};
    tr.forEach(function (p) {
      if (seen[p.pos]) return;
      seen[p.pos] = 1;
      marks.appendChild(sv("circle", { cx: cx(p.pos).toFixed(1), cy: cy(p.pos).toFixed(1), r: "6", class: "trail-dot" }));
      marks.appendChild(sv("text", { x: cx(p.pos).toFixed(1), y: (cy(p.pos) + 3).toFixed(1), "text-anchor": "middle", class: "trail-num", text: String(p.round) }));
    });
  }

  function renderStatus() {
    var st = G.state;
    var main = "", sub = "";
    if (st.winner) {
      main = st.winner === "hunters" ? "Hunters win" : "Leviathan wins";
      sub = G.review ? "Its whole path is drawn in red. Numbers are rounds." : st.reason;
    } else if (st.phase === "start") {
      main = "The hunt begins";
      sub = G.viewer === "monster" ? "Choose where the Leviathan starts" : "The Leviathan is choosing where to start";
    } else {
      var surf = L.CFG.surfaceEvery - (st.round % L.CFG.surfaceEvery);
      if (surf === L.CFG.surfaceEvery) surf = 0;
      main = st.phase === "monster" ? "Leviathan's turn" : "Hunters' turn";
      sub = "Round " + st.round + "/" + L.CFG.roundLimit + (surf === 0 ? " · it surfaces now" : " · surfaces in " + surf);
    }
    K.$("#st-main").textContent = main;
    K.$("#st-sub").textContent = sub;
    var sc = K.$("#scores");
    sc.innerHTML = "";
    sc.appendChild(h("span", { class: "chip hits", title: "Harpoon hits", html: iconSvg("hits") + "<span>" + st.monster.wounds + "/" + L.CFG.woundsToWin + "</span>" }));
    sc.appendChild(h("span", { class: "chip kills", title: "Targets destroyed", html: iconSvg("kills") + "<span>" + st.monster.kills + "/" + L.CFG.killsToWin + "</span>" }));
  }

  /* ---------- Action bar ---------- */
  function hazeToggle() {
    return h("button", { class: "toggle", type: "button", "aria-pressed": G.haze ? "true" : "false", onclick: function () {
      G.haze = !G.haze; K.store.set("haze", G.haze); K.Sound.play("tap"); render();
    }, html: K.ICONS.eye + "<span>" + (G.viewer === "monster" ? "Hunters' view" : "Haze") + (G.state && G.state.phase !== "start" ? " · " + G.state.P.length : "") + "</span>" });
  }

  function renderBar() {
    var bar = K.$("#actionbar");
    bar.innerHTML = "";
    var st = G.state;
    if (G.review) {
      bar.appendChild(h("p", { class: "hint-line" }, "The red line is where the Leviathan went. Numbers are rounds."));
      bar.appendChild(h("div", { class: "action-row" },
        h("button", { class: "btn btn-primary", type: "button", onclick: function () { K.Sound.play("select"); restart(); } }, "Rematch"),
        h("button", { class: "btn", type: "button", onclick: function () { K.quit(); } }, "Main menu")));
      return;
    }
    if (G.mode === "start" && G.resolver) {
      bar.appendChild(h("p", { class: "hint-line" }, G.pending == null ? "Tap a tile in the shaded northern waters to hide there." : "Tap it again, or press Hide here."));
      bar.appendChild(h("button", { class: "btn btn-primary btn-wide", type: "button", disabled: G.pending == null, onclick: function () { confirmStart(); } }, "Hide here"));
      return;
    }
    if (G.mode === "monster" && G.resolver) { renderMonsterBar(bar); return; }
    if (G.mode === "hunters" && G.resolver) { renderHunterBar(bar); return; }
    bar.appendChild(h("p", { class: "recap", html: G.recap || "&nbsp;" }));
    var row = h("div", { class: "bar-row" }, h("span", { class: "orders" }, G.state.phase === "hunters" ? "Hunters are acting" : st.phase === "monster" ? "The Leviathan moves" : ""));
    if (!st.winner && (G.viewer === "hunters" || G.humanMonster)) row.appendChild(hazeToggle());
    bar.appendChild(row);
  }

  function renderMonsterBar(bar) {
    var st = G.state;
    var p = G.pending;
    var msg;
    if (!p) msg = "Green: swim (silent). Gold: dash 2 (leaves a wake). Red ring: strike that ship.";
    else if (p.type === "strike") msg = "Strike the " + st.ships[p.ship].name + " ship? You'll be revealed.";
    else if (p.type === "dash") msg = "Dash here? A wake will mark where you started." + (L.buoyAt(st, p.to) ? " You'll devour the buoy and be revealed." : "");
    else if (p.to === st.monster.pos) msg = "Lurk where you are.";
    else msg = "Swim here." + (L.buoyAt(st, p.to) ? " You'll devour the buoy and be revealed." : "");
    if (st.round % L.CFG.surfaceEvery === 0) msg += " You surface at the end of this turn.";
    if (st.monster.snagged) msg = "Snagged: you can't dash this turn. " + msg;
    bar.appendChild(h("p", { class: "hint-line" }, msg));
    var row = h("div", { class: "confirm-row" });
    row.appendChild(h("button", { class: "btn", type: "button", onclick: function () {
      K.Sound.play("tap");
      G.pending = { type: "swim", to: st.monster.pos };
      render();
    } }, "Lurk here"));
    row.appendChild(h("button", { class: "btn btn-primary", type: "button", disabled: !p, onclick: confirmMonster },
      !p ? "Choose a move" : p.type === "strike" ? "Strike!" : p.type === "dash" ? "Dash" : p.to === st.monster.pos ? "Lurk" : "Swim"));
    bar.appendChild(row);
    var tools = h("div", { class: "bar-row" },
      h("div", { class: "legend" },
        h("span", null, h("i", { style: "background:#6ee7b7" }), "Swim"),
        h("span", null, h("i", { style: "background:#fbbf24" }), "Dash"),
        h("span", null, h("i", { style: "background:#ff4f6d" }), "Strike")),
      hazeToggle());
    bar.appendChild(tools);
  }

  function abilityHint(sh) {
    if (sh.ability === "ping") return "Ping all tiles within 2 of the Sonar ship.";
    if (sh.ability === "harpoon") return "Tap a tile up to 2 away to throw the harpoon.";
    if (sh.ability === "net") return "Tap a tile next to the Net ship to drop a net.";
    return "Tap any lit tile to shine the beam that way.";
  }

  function renderHunterBar(bar) {
    var st = G.state;
    var rowShips = h("div", { class: "shiprow" });
    st.ships.forEach(function (sh, k) {
      var st2 = h("span", { class: "st" }, h("i", { class: sh.moved ? "used" : "", title: "Move" }), h("i", { class: sh.acted ? "used" : "", title: sh.verb }));
      rowShips.appendChild(h("button", {
        class: "shipcard" + (sh.sunk ? " sunk" : ""), type: "button", "aria-pressed": G.sel === k ? "true" : "false", disabled: sh.sunk,
        onclick: function () { selectShip(k); }
      }, h("span", { html: iconSvg(sh.ability) }), h("span", { class: "nm" }, sh.name), sh.sunk ? h("span", { class: "nm" }, "sunk") : st2,
        h("span", { class: "hp" }, sh.sunk ? "" : "♥" + sh.hp)));
    });
    bar.appendChild(rowShips);
    var sh = st.ships[G.sel];
    var p = G.pending;
    var hint;
    if (p) hint = describeOrder(p);
    else if (sh.moved && sh.acted) hint = "The " + sh.name + " ship is done this turn. Pick another ship.";
    else if (G.shipMode === "move") hint = sh.moved ? "Already moved. Switch to " + sh.verb + "." : "Tap a teal tile to sail there (up to 2).";
    else hint = sh.acted ? "Already used. Switch to Move." : abilityHint(sh);
    bar.appendChild(h("p", { class: "hint-line" }, hint));
    if (p) {
      bar.appendChild(h("div", { class: "confirm-row" },
        h("button", { class: "btn", type: "button", onclick: function () { K.Sound.play("tap"); G.pending = null; render(); } }, "Cancel"),
        h("button", { class: "btn btn-primary", type: "button", onclick: confirmHunter }, confirmLabel(p))));
    } else {
      bar.appendChild(h("div", { class: "modes" },
        h("button", { class: "btn btn-sm", type: "button", "aria-pressed": G.shipMode === "move" ? "true" : "false", disabled: sh.moved || st.orders < 1, onclick: function () { G.shipMode = "move"; K.Sound.play("tap"); render(); } }, "Move"),
        h("button", { class: "btn btn-sm", type: "button", "aria-pressed": G.shipMode === "ability" ? "true" : "false", disabled: sh.acted || st.orders < 1, onclick: function () {
          G.shipMode = "ability"; K.Sound.play("tap");
          if (sh.ability === "ping") G.pending = { type: "ping", ship: G.sel };
          render();
        } }, sh.verb)));
    }
    var pips = h("span", { class: "orders" }, "Orders");
    for (var q = 0; q < L.CFG.orders; q++) pips.appendChild(h("i", { class: q < st.orders ? "" : "used" }));
    bar.appendChild(h("div", { class: "bar-row" }, pips, hazeToggle(),
      h("button", { class: "btn btn-sm", type: "button", onclick: function () { K.Sound.play("tap"); finishHunterTurn(); } }, st.orders > 0 ? "End turn" : "Done")));
  }

  function confirmLabel(p) {
    if (p.type === "move") return "Sail here";
    if (p.type === "ping") return "Ping";
    if (p.type === "harpoon") return "Throw harpoon";
    if (p.type === "net") return "Drop net";
    return "Shine beam";
  }
  function describeOrder(p) {
    var sh = G.state.ships[p.ship];
    if (p.type === "move") return "Sail the " + sh.name + " ship here.";
    if (p.type === "ping") return "Ping within 2 tiles of the Sonar ship.";
    if (p.type === "harpoon") return "Throw the harpoon at the marked tile.";
    if (p.type === "net") return "Drop a net on the marked tile.";
    return "Shine the beam along the marked line.";
  }

  function selectShip(k) {
    var st = G.state, sh = st.ships[k];
    if (sh.sunk) return;
    K.Sound.play("tap");
    G.sel = k;
    G.pending = null;
    G.shipMode = !sh.moved ? "move" : "ability";
    if (G.shipMode === "ability" && sh.ability === "ping" && !sh.acted) G.pending = { type: "ping", ship: k };
    render();
  }

  /* ---------- Input ---------- */
  function onTile(i) {
    if (G.locked || !G.resolver) return;
    var st = G.state;
    if (G.mode === "start") {
      if (L.startZone(st).indexOf(i) < 0) { K.Sound.play("error"); K.toast("Start in the shaded northern waters."); return; }
      if (G.pending === i) { confirmStart(); return; }
      G.pending = i; K.Sound.play("tap"); render(); return;
    }
    if (G.mode === "monster") {
      var opt = null;
      G.monsterOpts.forEach(function (o) {
        if (o.type === "strike" && st.ships[o.ship].pos === i) opt = o;
        else if ((o.type === "swim" || o.type === "dash") && o.to === i && !opt) opt = o;
      });
      if (!opt) { K.Sound.play("error"); return; }
      if (G.pending && samePending(G.pending, opt)) { confirmMonster(); return; }
      G.pending = opt; K.Sound.play("tap"); render(); return;
    }
    if (G.mode === "hunters") {
      var shipHere = L.shipAt(st, i);
      if (shipHere >= 0 && shipHere !== G.sel && !(G.shipMode === "ability" && st.ships[G.sel].ability === "beam")) { selectShip(shipHere); return; }
      var sh = st.ships[G.sel];
      var order = null;
      if (G.shipMode === "move" && !sh.moved) {
        var mv = L.shipMoves(st, G.sel);
        if (mv[i]) order = { type: "move", ship: G.sel, to: i, path: mv[i] };
      } else if (G.shipMode === "ability" && !sh.acted) {
        if (sh.ability === "ping") order = { type: "ping", ship: G.sel };
        else if (sh.ability === "beam") {
          L.abilityTargets(st, G.sel).forEach(function (d) { if (L.beamTiles(st, sh.pos, d).indexOf(i) >= 0) order = { type: "beam", ship: G.sel, dir: d }; });
        } else if (L.abilityTargets(st, G.sel).indexOf(i) >= 0) order = { type: sh.ability, ship: G.sel, target: i };
      }
      if (!order) {
        if (shipHere === G.sel) return;
        K.Sound.play("error");
        return;
      }
      if (G.pending && samePending(G.pending, order)) { confirmHunter(); return; }
      G.pending = order; K.Sound.play("tap"); render();
    }
  }

  function samePending(a, b) {
    return a.type === b.type && a.to === b.to && a.ship === b.ship && a.target === b.target && a.dir === b.dir;
  }

  function confirmStart() {
    if (G.pending == null || !G.resolver) return;
    K.Sound.play("select");
    var r = G.resolver; G.resolver = null;
    var pos = G.pending; G.pending = null;
    r(pos);
  }
  function confirmMonster() {
    if (!G.pending || !G.resolver) return;
    K.Sound.play("select");
    var r = G.resolver; G.resolver = null;
    var act = G.pending; G.pending = null;
    G.monsterOpts = null;
    r(act);
  }
  function confirmHunter() {
    if (!G.pending || !G.resolver || G.locked) return;
    var order = G.pending;
    G.pending = null;
    runHunterOrder(order);
  }

  /* ---------- Animations ---------- */
  function fx(node, ms) {
    G.layers.fx.appendChild(node);
    setTimeout(function () { node.remove(); }, ms || 900);
    return node;
  }
  function animate(node, frames, ms) {
    if (K.reduceMotion || !node.animate) return K.sleep(ms);
    try { node.animate(frames, { duration: ms, easing: "ease-out", fill: "forwards" }); } catch (e) {}
    return K.sleep(ms);
  }

  async function slideShip(k, path) {
    var n = G.shipNodes[k];
    for (var q = 0; q < path.length; q++) {
      setPos(n, path[q], false);
      K.Sound.play("slide");
      await K.sleep(230);
    }
  }

  async function pingFx(pos, contact) {
    K.Sound.play("ping");
    var c = sv("circle", { cx: "0", cy: "0", r: (2.6 * HW).toFixed(1), class: "fx-ping" });
    fx(sv("g", { transform: "translate(" + cx(pos).toFixed(1) + " " + cy(pos).toFixed(1) + ")" }, c), 1100);
    await animate(c, [{ transform: "scale(.08)", opacity: 1 }, { transform: "scale(1)", opacity: 0.2 }], 700);
    if (contact) { K.Sound.play("contact"); await K.banner("CONTACT", { tone: "bad", sub: "It's within 2 tiles of the Sonar ship", ms: 1300 }); }
    else await K.banner("CLEAR", { tone: "good", sub: "Nothing within 2 tiles", ms: 1000 });
  }

  async function beamFx(from, tiles, found) {
    K.Sound.play("zap");
    if (!tiles.length) return;
    var last = tiles[tiles.length - 1];
    var ln = fx(sv("line", { x1: cx(from).toFixed(1), y1: cy(from).toFixed(1), x2: cx(last).toFixed(1), y2: cy(last).toFixed(1), class: "fx-beam" }), 1200);
    await animate(ln, [{ opacity: 0 }, { opacity: 0.8 }, { opacity: 0.35 }], 600);
    if (found) { K.Sound.play("reveal"); await K.banner("SPOTTED", { tone: "bad", sub: "The beam caught it", ms: 1200 }); }
    else await K.banner("NOTHING", { tone: "good", sub: "The beam lit empty water", ms: 900 });
  }

  async function harpoonFx(from, target, hit) {
    K.Sound.play("whoosh");
    var ln = fx(sv("line", { x1: cx(from).toFixed(1), y1: cy(from).toFixed(1), x2: cx(from).toFixed(1), y2: cy(from).toFixed(1), class: "fx-harpoon" }), 900);
    if (!K.reduceMotion) {
      var steps = 8;
      for (var q = 1; q <= steps; q++) {
        ln.setAttribute("x2", (cx(from) + (cx(target) - cx(from)) * q / steps).toFixed(1));
        ln.setAttribute("y2", (cy(from) + (cy(target) - cy(from)) * q / steps).toFixed(1));
        await K.sleep(28);
      }
    }
    if (hit) {
      K.Sound.play("hit");
      fx(sv("circle", { cx: cx(target).toFixed(1), cy: cy(target).toFixed(1), r: "18", class: "fx-hit" }), 900);
      K.shake(K.$("#stage"));
      K.haptic(40);
      await K.banner("HIT!", { tone: "accent", sub: G.state.monster.wounds + " of " + L.CFG.woundsToWin + " hits", ms: 1300 });
    } else {
      K.Sound.play("splash");
      var sp = sv("circle", { cx: "0", cy: "0", r: "16", class: "fx-splash" });
      fx(sv("g", { transform: "translate(" + cx(target).toFixed(1) + " " + cy(target).toFixed(1) + ")" }, sp), 900);
      await animate(sp, [{ transform: "scale(.25)", opacity: 1 }, { transform: "scale(1)", opacity: 0 }], 500);
      K.toast("Splash. Nothing there.");
    }
  }

  async function netFx(target, snag) {
    K.Sound.play("whoosh");
    await K.sleep(250);
    if (snag) { K.Sound.play("roar"); K.shake(K.$("#stage")); await K.banner("SNAGGED", { tone: "accent", sub: "It can't dash next turn", ms: 1300 }); }
    else K.toast("Net set. That tile is blocked for 3 rounds.");
  }

  function revealSound(why) { if (why === "surface" || why === "bump" || why === "net") K.Sound.play("roar"); }

  /* Hunter events, seen by whoever is looking. */
  async function animateHunterEvents(ev) {
    for (var q = 0; q < ev.length; q++) {
      var e = ev[q];
      if (e.t === "move") { await slideShip(e.ship, e.path); }
      else if (e.t === "bump") {
        render();
        K.Sound.play("roar"); K.shake(K.$("#stage")); K.haptic(30);
        await K.banner("BUMP!", { tone: "bad", sub: "Something huge is right there", ms: 1300 });
      } else if (e.t === "ping") { render(); await pingFx(e.at, e.contact); }
      else if (e.t === "beam") { render(); await beamFx(e.from, e.tiles, e.found); }
      else if (e.t === "harpoon") { await harpoonFx(e.from, e.target, e.hit); }
      else if (e.t === "net") { render(); await netFx(e.target, e.snag); }
      render();
    }
  }

  /* Monster events. publicOnly: show only what the hunters can see. */
  async function animateMonsterEvents(ev, publicOnly) {
    var st = G.state;
    var lines = [];
    var revealed = ev.some(function (e) { return e.t === "reveal"; });
    for (var q = 0; q < ev.length; q++) {
      var e = ev[q];
      if (e.t === "swim") {
        if (!publicOnly) { setPos(G.monsterNode, e.to, false); K.Sound.play("move"); await K.sleep(320); }
        else if (!revealed) lines.push("The Leviathan swam somewhere. The haze spreads.");
      } else if (e.t === "dash") {
        if (!publicOnly) { setPos(G.monsterNode, e.to, false); K.Sound.play("whoosh"); await K.sleep(380); }
        else { if (!revealed) lines.push("<b>A wake!</b> It dashed 2 tiles away from the rings."); render(); K.Sound.play("splash"); await K.sleep(500); }
      } else if (e.t === "strike") {
        render();
        K.Sound.play("hit"); K.shake(K.$("#stage")); K.haptic(50);
        await K.banner("STRIKE!", { tone: "bad", sub: "The " + st.ships[e.ship].name + " ship is hit", ms: 1300 });
      } else if (e.t === "sunk") {
        render();
        K.Sound.play("splash");
        await K.banner("SUNK", { tone: "bad", sub: "The " + st.ships[e.ship].name + " ship went down", ms: 1300 });
      } else if (e.t === "devour") {
        render();
        K.Sound.play("roar"); K.shake(K.$("#stage"));
        await K.banner("DEVOURED", { tone: "bad", sub: "A buoy is gone", ms: 1300 });
      } else if (e.t === "reveal" && e.why === "surface") {
        render();
        revealSound("surface");
        await K.banner("SURFACED", { tone: "bad", sub: "Every 6th round it must breathe", ms: 1300 });
      }
    }
    G.recap = lines.join(" ");
    if (publicOnly && lines.length) K.toast(lines.join(" ").replace(/<[^>]+>/g, ""), 2600);
    render();
  }

  /* ---------- Turn flow ---------- */
  function waitFor(mode, setup) {
    return new Promise(function (resolve) {
      G.mode = mode;
      G.pending = null;
      if (setup) setup();
      G.resolver = resolve;
      render();
    });
  }

  async function humanStart() {
    G.startPick = true;
    var pos = await waitFor("start");
    G.startPick = false;
    return pos;
  }

  async function humanMonsterTurn() {
    var act = await waitFor("monster", function () { G.monsterOpts = L.monsterOptions(G.state); });
    G.mode = null;
    return act;
  }

  function finishHunterTurn() {
    if (!G.resolver || G.mode !== "hunters" || G.locked) return;
    var r = G.resolver; G.resolver = null; G.mode = null; G.pending = null;
    r();
  }

  async function runHunterOrder(order) {
    var token = G.token;
    G.locked = true;
    render();
    var ev = L.applyHunter(G.state, order);
    await animateHunterEvents(ev);
    if (token !== G.token) return;
    G.locked = false;
    var st = G.state;
    if (st.winner || st.orders < 1 || !L.hasAnyOrder(st)) {
      await K.sleep(350);
      if (token !== G.token) return;
      finishHunterTurn();
      return;
    }
    var sh = st.ships[G.sel];
    if (sh.moved && sh.acted) {
      for (var k = 0; k < st.ships.length; k++) {
        var o = st.ships[k];
        if (!o.sunk && (!o.moved || !o.acted)) { G.sel = k; break; }
      }
    }
    sh = st.ships[G.sel];
    G.shipMode = sh.moved ? "ability" : (order.type === "move" && order.ship === G.sel ? "ability" : "move");
    if (G.shipMode === "ability" && sh.acted) G.shipMode = "move";
    render();
  }

  async function humanHunterTurn() {
    var st = G.state;
    G.sel = 1;
    if (st.ships[1].sunk) G.sel = st.ships.findIndex(function (x) { return !x.sunk; });
    G.shipMode = "move";
    await waitFor("hunters");
  }

  async function botHunterTurn(token) {
    var st = G.state;
    G.mode = null;
    render();
    await K.sleep(500);
    var n = 0;
    while (!st.winner && st.orders > 0 && n++ < 6) {
      if (token !== G.token) return;
      var o = L.bots.hunterOrder(st, G.level, G.rand);
      if (o.type === "end") break;
      K.$("#st-sub").textContent = "Round " + st.round + " · " + describeBot(o);
      await K.sleep(420);
      if (token !== G.token) return;
      var ev = L.applyHunter(st, o);
      await animateHunterEvents(ev);
      await K.sleep(220);
    }
  }
  function describeBot(o) {
    var sh = G.state.ships[o.ship];
    if (o.type === "move") return "the " + sh.name + " ship sails";
    if (o.type === "ping") return "sonar ping";
    if (o.type === "harpoon") return "harpoon throw";
    if (o.type === "net") return "dropping a net";
    return "lighthouse beam";
  }

  async function botMonsterTurn(token) {
    G.mode = null;
    render();
    await K.sleep(650);
    if (token !== G.token) return;
    var act = L.bots.monsterMove(G.state, G.level, G.rand);
    var ev = L.applyMonster(G.state, act);
    await animateMonsterEvents(ev, true);
  }

  async function passTo(viewer) {
    G.viewer = viewer;
    G.pending = null;
    render();
    if (viewer === "monster") {
      await K.cover({ className: "monster-cover", kicker: "Round " + G.state.round, title: "Leviathan's turn", text: "Hunters, look away. Leviathan player, take the phone.", cta: "I'm the Leviathan", badge: '<svg viewBox="0 0 24 24" fill="#d61f52"><circle cx="12" cy="12" r="9"/><ellipse cx="12" cy="11" rx="4" ry="2.8" fill="#ffd166"/><ellipse cx="12.4" cy="11" rx="1" ry="2.4" fill="#2a0610"/></svg>' });
    } else {
      await K.cover({ className: "hunter-cover", kicker: "Round " + G.state.round, title: "Hunters' turn", text: "Leviathan player, hand the phone over.", cta: "We're the hunters", badge: '<svg viewBox="0 0 24 24" fill="none" stroke="#f2b84b" stroke-width="2" stroke-linecap="round">' + ICON.harpoon + "</svg>" });
    }
  }

  async function runGame(token) {
    var st = G.state;
    var local = G.cfg.mode === "local";
    if (G.humanMonster) {
      if (local) await passTo("monster");
      else { G.viewer = "monster"; render(); }
      if (token !== G.token) return;
      var pos = await humanStart();
      if (token !== G.token) return;
      L.setMonsterStart(st, pos);
    } else {
      L.setMonsterStart(st, L.bots.monsterStart(st, G.level, G.rand));
    }
    render();
    while (!st.winner) {
      if (token !== G.token) return;
      if (st.phase === "monster") {
        if (G.humanMonster) {
          if (local && G.viewer !== "monster") { await passTo("monster"); if (token !== G.token) return; }
          var act = await humanMonsterTurn();
          if (token !== G.token) return;
          G.locked = true;
          var ev = L.applyMonster(st, act);
          await animateMonsterEvents(ev, false);
          G.locked = false;
          if (local && !st.winner) {
            await passTo("hunters");
            if (token !== G.token) return;
            G.recap = "";
            await animateMonsterEvents(ev, true);
          }
        } else {
          await botMonsterTurn(token);
        }
      } else if (st.phase === "hunters") {
        if (G.humanHunters) {
          await humanHunterTurn();
        } else {
          await botHunterTurn(token);
        }
        if (token !== G.token) return;
        G.recap = "";
        L.endHunterTurn(st);
        render();
      } else break;
    }
    if (token !== G.token) return;
    await endGame(token);
  }

  async function endGame(token) {
    var st = G.state;
    G.mode = null; G.resolver = null;
    render();
    var youWon = null;
    if (G.cfg.mode === "bot") youWon = (st.winner === "hunters") === (G.cfg.side === "hunters");
    await K.banner(st.winner === "hunters" ? "HUNTERS WIN" : "LEVIATHAN WINS", { tone: st.winner === "hunters" ? "accent" : "bad", ms: 1500 });
    if (token !== G.token) return;
    var title = G.cfg.mode === "bot" ? (youWon ? "You win!" : "You lose") : (st.winner === "hunters" ? "The hunters win" : "The Leviathan wins");
    var choice = await K.gameOver({
      title: title,
      tone: youWon === false ? "bad" : "good",
      text: st.reason,
      stats: [["Harpoon hits", st.monster.wounds + " / " + L.CFG.woundsToWin], ["Targets destroyed", st.monster.kills + " / " + L.CFG.killsToWin], ["Rounds played", st.round]],
      reviewLabel: "See the Leviathan's path"
    });
    if (token !== G.token) return;
    if (choice === "rematch") restart();
    else if (choice === "review") { G.review = true; render(); }
  }

  /* ---------- Lifecycle ---------- */
  function start(cfg) {
    G.cfg = cfg;
    G.level = cfg.difficulty || "normal";
    G.haze = cfg.haze !== "off";
    var local = cfg.mode === "local";
    G.humanMonster = local || cfg.side === "monster";
    G.humanHunters = local || cfg.side !== "monster";
    G.viewer = G.humanHunters && !local ? "hunters" : G.humanMonster && !local ? "monster" : "monster";
    newMatch();
  }

  function newMatch() {
    G.token++;
    var seed = (Date.now() ^ Math.floor(Math.random() * 1e9)) >>> 0;
    G.state = L.newGame(seed);
    G.rand = L.rng(seed ^ 0x5bd1e995);
    G.review = false; G.pending = null; G.resolver = null; G.mode = null; G.locked = false; G.recap = "";
    if (G.cfg.mode === "local") G.viewer = "monster";
    else G.viewer = G.cfg.side === "monster" ? "monster" : "hunters";
    K.showScreen("game");
    buildBoard();
    render();
    runGame(G.token);
  }

  function restart() {
    K.$all(".cover,.modal-wrap,.banner").forEach(function (n) { n.remove(); });
    newMatch();
  }

  function quit() {
    G.token++;
    G.resolver = null; G.mode = null;
  }

  window.__leviathanDebug = { G: G, runHunterOrder: runHunterOrder };

  K.init({
    ns: "leviathan-hunt",
    title: "Leviathan Hunt",
    tagline: "One hidden sea monster. Four hunter ships. Deduction against deception.",
    art: TITLE_ART,
    rules: RULES,
    options: [
      { id: "mode", label: "Opponent", default: "bot", choices: [{ v: "bot", t: "Bot" }, { v: "local", t: "Friend, same phone" }] },
      { id: "side", label: "You play", default: "hunters", choices: [{ v: "hunters", t: "Hunters" }, { v: "monster", t: "Leviathan" }], showIf: function (c) { return c.mode === "bot"; } },
      { id: "difficulty", label: "Bot level", default: "normal", choices: [{ v: "easy", t: "Easy" }, { v: "normal", t: "Normal" }, { v: "hard", t: "Hard" }], showIf: function (c) { return c.mode === "bot"; },
        note: function (c) { return c.difficulty === "hard" ? "Hard bots plan a move ahead and read your habits." : c.difficulty === "easy" ? "Easy bots make mistakes. Good for learning." : "A fair fight."; } },
      { id: "haze", label: "Red haze (where it could be)", default: "on", choices: [{ v: "on", t: "Show" }, { v: "off", t: "Hide" }],
        note: function (c) { return c.mode === "local" ? "Pass the phone between the Leviathan and the hunters. Cover screens hide the monster." : null; } }
    ],
    onStart: start,
    onRestart: restart,
    onQuit: quit,
    menuNote: function () { return G.state ? "Round " + G.state.round + " of " + L.CFG.roundLimit + "." : ""; }
  });
})();
