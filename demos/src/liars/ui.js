/* Liar's Gambit: interface, animation and turn flow. */
(function () {
  "use strict";
  var LG = window.Liars, K = window.Kit, h = K.h, sv = K.s;
  var S = 54, TRAY = 30, GAP = 8;
  var BW = LG.COLS * S, BH = LG.ROWS * S;
  var BY = TRAY + GAP;
  var VBW = BW, VBH = TRAY + GAP + BH + GAP + TRAY;
  var SIDE_CLASS = ["gold", "ruby"];

  var ICON = {
    C: '<path d="M3.5 18.5h17v2h-17zM4.2 16.8L3 7.5l5 3.8L12 4l4 7.3 5-3.8-1.2 9.3z"/>',
    T: '<path d="M5 20.5h14v-2.2H5zM7 18.3l1.1-8.6h7.8l1.1 8.6zM6.5 9.7V4h2.4v2.2h1.8V4h2.6v2.2h1.8V4h2.4v5.7z"/>',
    B: '<path d="M20.5 3.5l-1.3 5.6-8.4 8.4-4.3-4.3 8.4-8.4z"/><path d="M5.3 12.4l6.3 6.3-1.4 1.4-6.3-6.3zM6.9 16.6l1.4 1.4-3.6 3.6-1.4-1.4z"/>',
    J: '<path d="M6 3.5h3v12.8h7.2v-3.1l5 4.6-5 4.6v-3.1H6z"/>',
    G: '<path d="M12 2.8l8 3.2v5.6c0 5-3.3 8.8-8 10.6-4.7-1.8-8-5.6-8-10.6V6z"/>',
    mask: '<path fill-rule="evenodd" d="M1.8 9.2C4.6 7.6 8 7.2 12 8.8c4-1.6 7.4-1.2 10.2.4-.3 5.3-3.6 8.3-6.8 8.3-1.5 0-2.6-.9-3.4-2.2-.8 1.3-1.9 2.2-3.4 2.2-3.2 0-6.5-3-6.8-8.3zM6.6 12.2c0 .9 1 1.5 2.1 1.5s2.1-.6 2.1-1.5-1-1.5-2.1-1.5-2.1.6-2.1 1.5zm6.6 0c0 .9 1 1.5 2.1 1.5s2.1-.6 2.1-1.5-1-1.5-2.1-1.5-2.1.6-2.1 1.5z"/>'
  };
  function iconSvg(type, fill) {
    return '<svg viewBox="0 0 24 24" fill="' + (fill || "currentColor") + '">' + ICON[type] + "</svg>";
  }

  var TITLE_ART = '<svg viewBox="0 0 260 150" role="img" aria-label="A gold mask and a ruby mask behind a crown">' +
    '<g transform="translate(30 22) rotate(-10 60 50) scale(4.2)"><path fill="#e9c46a" fill-rule="evenodd" d="' + 'M1.8 9.2C4.6 7.6 8 7.2 12 8.8c4-1.6 7.4-1.2 10.2.4-.3 5.3-3.6 8.3-6.8 8.3-1.5 0-2.6-.9-3.4-2.2-.8 1.3-1.9 2.2-3.4 2.2-3.2 0-6.5-3-6.8-8.3zM6.6 12.2c0 .9 1 1.5 2.1 1.5s2.1-.6 2.1-1.5-1-1.5-2.1-1.5-2.1.6-2.1 1.5zm6.6 0c0 .9 1 1.5 2.1 1.5s2.1-.6 2.1-1.5-1-1.5-2.1-1.5-2.1.6-2.1 1.5z"/></g>' +
    '<g transform="translate(118 30) rotate(12 60 50) scale(4.2)"><path fill="#d94a63" fill-rule="evenodd" d="' + 'M1.8 9.2C4.6 7.6 8 7.2 12 8.8c4-1.6 7.4-1.2 10.2.4-.3 5.3-3.6 8.3-6.8 8.3-1.5 0-2.6-.9-3.4-2.2-.8 1.3-1.9 2.2-3.4 2.2-3.2 0-6.5-3-6.8-8.3zM6.6 12.2c0 .9 1 1.5 2.1 1.5s2.1-.6 2.1-1.5-1-1.5-2.1-1.5-2.1.6-2.1 1.5zm6.6 0c0 .9 1 1.5 2.1 1.5s2.1-.6 2.1-1.5-1-1.5-2.1-1.5-2.1.6-2.1 1.5z"/></g>' +
    '<g transform="translate(103 2) scale(2.3)" fill="#f6ece2"><path d="M3.5 18.5h17v2h-17zM4.2 16.8L3 7.5l5 3.8L12 4l4 7.3 5-3.8-1.2 9.3z"/></g>' +
    "</svg>";

  var RULES = [
    "<h3>The goal</h3>",
    "<p>Capture the enemy <b>Crown</b>, or catch it lying.</p>",
    "<h3>The pieces</h3>",
    '<div class="icon-row" style="margin-bottom:8px">',
    "<span>" + iconSvg("C") + "Crown ×1</span><span>" + iconSvg("T") + "Tower ×2</span><span>" + iconSvg("B") + "Blade ×2</span><span>" + iconSvg("J") + "Jumper ×1</span><span>" + iconSvg("G") + "Guard ×2</span></div>",
    '<dl class="kv"><dt>Crown</dt><dd>1 step in any direction.</dd><dt>Tower</dt><dd>Up to 3 squares straight.</dd><dt>Blade</dt><dd>Up to 3 squares diagonally.</dd><dt>Jumper</dt><dd>An L-shaped jump, over anything.</dd><dt>Guard</dt><dd>1 step straight.</dd></dl>',
    "<p>Towers and Blades can't pass through pieces. Land on an enemy piece to capture it.</p>",
    "<h3>The masks</h3>",
    "<p>You see your own pieces. Your opponent only sees masks.</p>",
    "<p>On your turn, move <b>any</b> piece in <b>any</b> of those patterns. The way it moves is your claim. A 3-square diagonal slide claims a Blade, even if it's really a Guard.</p>",
    "<h3>Calling “Liar!”</h3>",
    "<p>At the start of your turn you can call Liar on your opponent's last move.</p><ul>",
    "<li><b>If they lied</b>, their piece is destroyed and the move is undone.</li>",
    "<li><b>If they told the truth</b>, their piece is revealed, you spend one accusation, and you give up a piece of your choice.</li></ul>",
    "<p>You have <b>3 accusations</b>. If they capture your Crown you can always call Liar, even with none left.</p>",
    "<p>Revealed pieces can only move honestly. Captured pieces are revealed.</p>",
    "<h3>Winning</h3>",
    "<p>Capture their Crown (and survive the call), or catch their Crown lying. After 100 moves, the side with more pieces wins, then the side with more accusations left.</p>",
    "<h3>Badges</h3>",
    "<p>A letter on a masked piece shows what all its moves so far are consistent with. A red <b>!</b> means it has contradicted itself, so it has lied at least once. An orange letter on your own piece is the cover story you've been telling with it.</p>",
    '<div class="tip">Short moves are your Crown\'s best disguise: a 1-step straight move could be a Crown, a Tower or a Guard. With 2 Towers and 2 Blades on each side, big claims are believable. Save your accusations for the moves that matter.</div>'
  ].join("");

  var G = {
    state: null, cfg: null, rand: null, level: "normal", viewer: 0, human: [true, false],
    mode: null, sel: -1, pending: null, resolver: null, token: 0, review: false, setupArr: null, setupSide: 0,
    nodes: {}, layers: {}, svg: null, prompt: null
  };

  /* ---------- Geometry ---------- */
  function dispRC(sq) {
    var r = LG.rowOf(sq), c = LG.colOf(sq);
    if (G.viewer === 1) { r = LG.ROWS - 1 - r; c = LG.COLS - 1 - c; }
    return { r: r, c: c };
  }
  function sqXY(sq) { var d = dispRC(sq); return { x: d.c * S + S / 2, y: BY + d.r * S + S / 2 }; }
  function sqFromDisp(r, c) {
    if (G.viewer === 1) { r = LG.ROWS - 1 - r; c = LG.COLS - 1 - c; }
    return r * LG.COLS + c;
  }

  /* ---------- Board ---------- */
  function buildBoard() {
    var stage = K.$("#stage");
    stage.innerHTML = "";
    var svg = sv("svg", { id: "board", viewBox: "0 0 " + VBW + " " + VBH, role: "img", "aria-label": "Masquerade board" });
    var sq = sv("g", { class: "squares" });
    for (var r = 0; r < LG.ROWS; r++) for (var c = 0; c < LG.COLS; c++) {
      sq.appendChild(sv("rect", { x: c * S, y: BY + r * S, width: S, height: S, class: (r + c) % 2 ? "sq-b" : "sq-a" }));
    }
    sq.appendChild(sv("rect", { x: 0, y: BY, width: BW, height: 2 * S, class: "home-tint" }));
    sq.appendChild(sv("rect", { x: 0, y: BY + BH - 2 * S, width: BW, height: 2 * S, class: "home-tint" }));
    sq.appendChild(sv("rect", { x: 1, y: BY + 1, width: BW - 2, height: BH - 2, rx: 3, class: "board-frame" }));
    svg.appendChild(sq);
    ["trays", "marks", "pieces", "badges", "fx"].forEach(function (n) { var g = sv("g", { class: n }); G.layers[n] = g; svg.appendChild(g); });
    var hit = sv("g", { class: "hit-layer" });
    for (var r2 = 0; r2 < LG.ROWS; r2++) for (var c2 = 0; c2 < LG.COLS; c2++) {
      hit.appendChild(sv("rect", { x: c2 * S, y: BY + r2 * S, width: S, height: S, "data-r": String(r2), "data-c": String(c2) }));
    }
    hit.addEventListener("click", function (e) {
      var t = e.target;
      if (!t || t.getAttribute("data-r") == null) return;
      onSquare(sqFromDisp(+t.getAttribute("data-r"), +t.getAttribute("data-c")));
    });
    svg.appendChild(hit);
    stage.appendChild(svg);
    G.svg = svg;
    G.nodes = {};
  }

  function pieceNode(p) {
    var n = G.nodes[p.id];
    if (n) return n;
    n = sv("g", { class: "piece" });
    G.layers.pieces.appendChild(n);
    G.nodes[p.id] = n;
    return n;
  }

  function knownTo(p, viewer) { return p.owner === viewer || p.revealed || G.review || G.state.winner != null; }

  function drawPieceContent(n, p) {
    var cls = SIDE_CLASS[p.owner];
    var known = knownTo(p, G.viewer);
    var key = cls + "|" + (known ? p.type : "?") + "|" + (p.revealed ? 1 : 0);
    if (n.getAttribute("data-key") === key) return;
    n.setAttribute("data-key", key);
    n.innerHTML = "";
    n.appendChild(sv("circle", { r: "21", class: "pc-body " + cls }));
    if (p.revealed) n.appendChild(sv("circle", { r: "24.5", class: "pc-public" }));
    var g = sv("g", { transform: "translate(-13 -13) scale(1.083)", class: known ? "pc-icon " + cls : "pc-mask " + cls });
    g.innerHTML = ICON[known ? p.type : "mask"];
    n.appendChild(g);
  }

  function setXY(n, sq, instant) {
    var p = sqXY(sq);
    if (instant) n.style.transition = "none";
    n.style.transform = "translate(" + p.x + "px," + p.y + "px)";
    if (instant) { void n.getBoundingClientRect(); n.style.transition = ""; }
  }

  function render(instant) {
    var st = G.state;
    if (!st || !G.svg) return;
    st.pieces.forEach(function (p) {
      var n = pieceNode(p);
      if (!p.alive || p.sq < 0) { n.style.display = "none"; return; }
      n.style.display = "";
      drawPieceContent(n, p);
      setXY(n, p.sq, instant);
      n.classList.toggle("ghost", false);
    });
    renderMarks();
    renderBadges();
    renderTrays();
    renderStatus();
    renderBar();
  }

  function cellRect(sq, cls, inset) {
    var d = dispRC(sq);
    inset = inset || 0;
    return sv("rect", { x: d.c * S + inset, y: BY + d.r * S + inset, width: S - 2 * inset, height: S - 2 * inset, rx: 4, class: cls });
  }

  function renderMarks() {
    var st = G.state, m = G.layers.marks;
    m.innerHTML = "";
    var lm = st.lastMove;
    if (lm && G.mode !== "setup") {
      m.appendChild(cellRect(lm.from, "lm-from", 3));
      var pendingCall = !lm.resolved && lm.side !== G.viewer && G.human[G.viewer];
      m.appendChild(cellRect(lm.to, "lm-to" + (pendingCall ? " pending" : ""), 2));
    }
    if (G.mode === "setup") {
      if (G.sel >= 0) m.appendChild(cellRect(G.sel, "sel-sq", 2));
      return;
    }
    if (G.mode === "sacrifice") {
      st.pieces.forEach(function (p) { if (p.owner === G.viewer && p.alive && p.type !== "C") m.appendChild(cellRect(p.sq, "sac-sq", 3)); });
      if (G.pending != null && G.pending.sac != null) m.appendChild(cellRect(st.pieces[G.pending.sac].sq, "pend-sq", 2));
      return;
    }
    if (G.mode === "move" && G.sel >= 0) {
      var sp = st.pieces[G.sel];
      m.appendChild(cellRect(sp.sq, "sel-sq", 2));
      LG.legalMoves(st, G.viewer).forEach(function (mv) {
        if (mv.pid !== G.sel) return;
        var honest = LG.isHonest(st, mv);
        var c = sqXY(mv.to);
        if (mv.capture >= 0) m.appendChild(sv("circle", { cx: c.x, cy: c.y, r: "23", class: honest ? "dest-cap-honest" : "dest-cap-bluff" }));
        else if (honest) m.appendChild(sv("circle", { cx: c.x, cy: c.y, r: "7", class: "dest-honest" }));
        else m.appendChild(sv("circle", { cx: c.x, cy: c.y, r: "7.5", class: "dest-bluff" }));
      });
      if (G.pending && G.pending.mv) m.appendChild(cellRect(G.pending.mv.to, "pend-sq", 2));
    }
  }

  function renderBadges() {
    var st = G.state, b = G.layers.badges;
    b.innerHTML = "";
    if (G.mode === "setup") return;
    st.pieces.forEach(function (p) {
      if (!p.alive || p.sq < 0 || p.revealed || !p.claims.length) return;
      var story = LG.storyMask(p);
      var label = null, kind = "";
      if (p.owner !== G.viewer) {
        if (G.review || st.winner != null) return;
        if (story === 0) { label = "!"; kind = "warn"; }
        else { var names = LG.TYPES.filter(function (t) { return story & LG.BIT[t]; }); if (names.length <= 2) label = names.join(""); }
      } else {
        if (story === 0) { label = "!"; kind = "warn"; }
        else if (!(story & LG.BIT[p.type])) { var nm = LG.TYPES.filter(function (t) { return story & LG.BIT[t]; }); if (nm.length <= 2) { label = nm.join(""); kind = "cover"; } }
      }
      if (!label) return;
      var c = sqXY(p.sq);
      var w = 8 + 6 * label.length;
      b.appendChild(sv("rect", { x: c.x + 10, y: c.y - 25, width: w, height: 13, rx: 6.5, class: "badge-bg " + kind }));
      b.appendChild(sv("text", { x: c.x + 10 + w / 2, y: c.y - 15.5, "text-anchor": "middle", class: "badge-tx " + kind, text: label }));
    });
  }

  function renderTrays() {
    var st = G.state, t = G.layers.trays;
    t.innerHTML = "";
    if (G.mode === "setup") return;
    var top = 1 - G.viewer, bottom = G.viewer;
    [[top, 0], [bottom, BY + BH + GAP]].forEach(function (pair) {
      var side = pair[0], y = pair[1];
      var lost = st.pieces.filter(function (p) { return p.owner === side && !p.alive && !p.pending; });
      t.appendChild(sv("text", { x: 2, y: y + 19, class: "tray-label", text: (side === G.viewer ? "Your losses" : LG.sideName(side) + " lost") }));
      lost.forEach(function (p, k) {
        var x = 108 + k * 26, cy2 = y + 15;
        t.appendChild(sv("circle", { cx: x, cy: cy2, r: "11", class: "pc-body " + SIDE_CLASS[side] }));
        var g = sv("g", { transform: "translate(" + (x - 7.2) + " " + (cy2 - 7.2) + ") scale(.6)", class: "pc-icon " + SIDE_CLASS[side] });
        g.innerHTML = ICON[p.type];
        t.appendChild(g);
      });
    });
  }

  function renderStatus() {
    var st = G.state;
    var main = "", sub = "";
    var me = G.viewer;
    if (G.mode === "setup") {
      main = "Set up your masks";
      sub = G.cfg.mode === "local" ? LG.sideName(G.setupSide) + " is arranging pieces" : "Hide your Crown well";
    } else if (st.winner != null) {
      main = st.winner === "draw" ? "Draw" : LG.sideName(st.winner) + " wins";
      sub = st.reason;
    } else if (G.human[st.turn]) {
      main = G.cfg.mode === "local" ? LG.sideName(st.turn) + "'s turn" : "Your turn";
      sub = "Move " + (Math.floor(st.ply / 2) + 1) + " · " + (LG.PLY_LIMIT - st.ply) + " plies left";
    } else {
      main = LG.sideName(st.turn) + " is thinking";
      sub = "Move " + (Math.floor(st.ply / 2) + 1);
    }
    K.$("#st-main").textContent = main;
    K.$("#st-sub").textContent = sub;
    var sc = K.$("#scores");
    sc.innerHTML = "";
    if (G.mode === "setup") return;
    [me, 1 - me].forEach(function (side) {
      var tok = h("span", { class: "tok" });
      for (var q = 0; q < LG.TOKENS; q++) tok.appendChild(h("i", { class: q < st.tokens[side] ? "" : "spent" }));
      sc.appendChild(h("span", { class: "chip", title: LG.sideName(side) + ": pieces and accusations left" },
        h("span", { class: "dot", style: "background:var(--" + SIDE_CLASS[side] + ")" }),
        String(LG.alivePieces(st, side).length), tok));
    });
  }

  /* ---------- Descriptions ---------- */
  function moveWords(from, to) {
    var dr = Math.abs(LG.rowOf(to) - LG.rowOf(from)), dc = Math.abs(LG.colOf(to) - LG.colOf(from));
    if ((dr === 1 && dc === 2) || (dr === 2 && dc === 1)) return "jumped in an L";
    var n = Math.max(dr, dc);
    var dir = dr && dc ? "diagonally" : "straight";
    return (n === 1 ? "stepped 1 square " : "slid " + n + " squares ") + dir;
  }
  function pieceName(p, viewer) { return knownTo(p, viewer) ? LG.NAME[p.type] : "masked piece"; }

  /* ---------- Action bar ---------- */
  function renderBar() {
    var bar = K.$("#actionbar");
    bar.innerHTML = "";
    var st = G.state;
    if (G.review) {
      bar.appendChild(h("p", { class: "hint-line" }, "Every mask is off. Look at what they really were."));
      bar.appendChild(h("div", { class: "action-row" },
        h("button", { class: "btn btn-primary", type: "button", onclick: function () { restart(); } }, "Rematch"),
        h("button", { class: "btn", type: "button", onclick: function () { K.quit(); } }, "Main menu")));
      return;
    }
    if (G.mode === "setup" && G.resolver) {
      bar.appendChild(h("p", { class: "hint-line" }, G.sel >= 0 ? "Now tap where it should go (or another piece to swap)." : "Tap a piece, then another square in your two rows, to rearrange."));
      bar.appendChild(h("div", { class: "small-legend" }, "Your opponent will only ever see masks."));
      bar.appendChild(h("div", { class: "action-row" },
        h("button", { class: "btn", type: "button", onclick: function () { K.Sound.play("tap"); G.setupArr = LG.randomSetup(G.rand, G.setupSide, "normal"); applyArrangement(G.setupSide, G.setupArr); G.sel = -1; render(true); } }, "Shuffle"),
        h("button", { class: "btn btn-primary", type: "button", onclick: function () { K.Sound.play("select"); var r = G.resolver; G.resolver = null; G.sel = -1; r(); } }, "Ready")));
      return;
    }
    if (G.mode === "challenge" && G.prompt) { renderChallengeBar(bar); return; }
    if (G.mode === "sacrifice") {
      var p = G.pending && G.pending.sac != null ? st.pieces[G.pending.sac] : null;
      bar.appendChild(h("div", { class: "claim-card" }, h("span", { class: "k" }, "They told the truth"),
        h("span", { class: "v" }, p ? "Give up your " + LG.NAME[p.type] + "?" : "Give up one of your pieces. Tap it (not your Crown).")));
      bar.appendChild(h("button", { class: "btn btn-danger btn-wide", type: "button", disabled: !p, onclick: confirmSacrifice }, p ? "Give up this " + LG.NAME[p.type] : "Choose a piece"));
      return;
    }
    if (G.mode === "move" && G.resolver) {
      var pend = G.pending && G.pending.mv;
      if (pend) {
        var honest = LG.isHonest(st, pend);
        var mp = st.pieces[pend.pid];
        bar.appendChild(h("div", { class: "claim-card" },
          h("span", { class: "k" }, "This move claims"),
          h("span", { class: "v", html: "<b>" + cap(LG.claimText(pend.claim)) + "</b>" + (honest ? '<span class="tag honest">True</span>' : '<span class="tag bluff">Bluff: it\'s your ' + LG.NAME[mp.type] + "</span>") })));
        bar.appendChild(h("div", { class: "action-row" },
          h("button", { class: "btn", type: "button", onclick: function () { K.Sound.play("tap"); G.pending = null; render(); } }, "Cancel"),
          h("button", { class: "btn btn-primary", type: "button", onclick: confirmMove }, pend.capture >= 0 ? "Capture" : "Move")));
      } else {
        bar.appendChild(h("p", { class: "hint-line" }, G.sel >= 0 ? "Teal dots are honest moves. Orange rings are bluffs." : "Tap one of your pieces."));
        bar.appendChild(h("div", { class: "small-legend" },
          h("span", null, h("i", { style: "background:var(--honest)" }), "Honest"),
          h("span", null, h("i", { style: "border:2px solid var(--bluff)" }), "Bluff"),
          h("span", null, "Accusations left: " + st.tokens[G.viewer])));
      }
      return;
    }
    bar.appendChild(h("p", { class: "hint-line" }, st.winner != null ? "" : "Waiting for " + LG.sideName(st.turn) + "…"));
  }

  function cap(t) { return t.charAt(0).toUpperCase() + t.slice(1); }

  function renderChallengeBar(bar) {
    var st = G.state, lm = st.lastMove, pr = G.prompt;
    var mover = st.pieces[lm.pid];
    var who = G.cfg.mode === "local" ? LG.sideName(lm.side) : LG.sideName(lm.side);
    var capText = lm.captured >= 0 ? " and took your " + LG.NAME[st.pieces[lm.captured].type] : "";
    bar.appendChild(h("div", { class: "claim-card" },
      h("span", { class: "k" }, who + "'s last move"),
      h("span", { class: "v", html: "A " + pieceName(mover, G.viewer) + " " + moveWords(lm.from, lm.to) + capText + ". That claims <b>" + LG.claimText(lm.claim) + "</b>." })));
    if (pr.forced) {
      bar.appendChild(h("p", { class: "hint-line" }, "They took your Crown. Call Liar, it's your only hope."));
      bar.appendChild(h("button", { class: "btn btn-liar btn-wide", type: "button", onclick: function () { answerChallenge(true); } }, "LIAR!"));
      return;
    }
    bar.appendChild(h("p", { class: "hint-line" }, "Call it, or just make your move to let it go. " + st.tokens[G.viewer] + " accusation" + (st.tokens[G.viewer] === 1 ? "" : "s") + " left."));
    bar.appendChild(h("div", { class: "action-row" },
      h("button", { class: "btn", type: "button", onclick: function () { answerChallenge(false); } }, "Let it go"),
      h("button", { class: "btn btn-liar", type: "button", onclick: function () { answerChallenge(true); } }, "LIAR!")));
  }

  /* ---------- Input ---------- */
  function onSquare(sq) {
    var st = G.state;
    if (G.mode === "setup" && G.resolver) { setupTap(sq); return; }
    if (G.mode === "sacrifice") {
      var p = LG.pieceAt(st, sq);
      if (!p || p.owner !== G.viewer || p.type === "C") { K.Sound.play("error"); if (p && p.type === "C") K.toast("You can't give up your Crown."); return; }
      if (G.pending && G.pending.sac === p.id) { confirmSacrifice(); return; }
      G.pending = { sac: p.id }; K.Sound.play("tap"); render(); return;
    }
    if (G.mode === "challenge" && G.prompt && !G.prompt.forced) {
      var mine = LG.pieceAt(st, sq);
      if (mine && mine.owner === G.viewer) { answerChallenge(false, mine.id); return; }
      return;
    }
    if (G.mode !== "move" || !G.resolver) return;
    var here = LG.pieceAt(st, sq);
    if (G.pending && G.pending.mv && G.pending.mv.to === sq) { confirmMove(); return; }
    if (here && here.owner === G.viewer) {
      G.sel = here.id; G.pending = null; K.Sound.play("tap"); render(); return;
    }
    if (G.sel < 0) return;
    var mv = LG.legalMoves(st, G.viewer).filter(function (m) { return m.pid === G.sel && m.to === sq; })[0];
    if (!mv) { K.Sound.play("error"); return; }
    G.pending = { mv: mv }; K.Sound.play("tap"); render();
  }

  function setupTap(sq) {
    var side = G.setupSide, arr = G.setupArr;
    var homes = LG.homeRows(side);
    if (homes.indexOf(LG.rowOf(sq)) < 0) { K.Sound.play("error"); return; }
    var idxAt = arr.indexOf(sq);
    if (G.sel < 0) {
      if (idxAt < 0) return;
      G.sel = sq; K.Sound.play("tap"); render(); return;
    }
    var from = arr.indexOf(G.sel);
    if (sq === G.sel) { G.sel = -1; render(); return; }
    if (idxAt >= 0) { arr[idxAt] = G.sel; arr[from] = sq; }
    else arr[from] = sq;
    G.sel = -1;
    applyArrangement(side, arr);
    K.Sound.play("move");
    render();
  }

  function applyArrangement(side, arr) {
    var st = G.state;
    var mine = st.pieces.filter(function (p) { return p.owner === side; });
    mine.forEach(function (p) { if (p.sq >= 0) st.board[p.sq] = -1; });
    mine.forEach(function (p, k) { p.sq = arr[k]; p.home = arr[k]; st.board[p.sq] = p.id; });
  }

  function confirmMove() {
    if (!G.pending || !G.pending.mv || !G.resolver) return;
    var r = G.resolver; G.resolver = null;
    var mv = G.pending.mv; G.pending = null; G.sel = -1;
    K.Sound.play("select");
    r(mv);
  }
  function confirmSacrifice() {
    if (!G.pending || G.pending.sac == null || !G.resolver) return;
    var r = G.resolver; G.resolver = null;
    var id = G.pending.sac; G.pending = null;
    r(id);
  }
  function answerChallenge(call, thenSelect) {
    if (!G.resolver || G.mode !== "challenge") return;
    var r = G.resolver; G.resolver = null;
    K.Sound.play(call ? "liar" : "tap");
    r({ call: call, select: thenSelect });
  }

  function waitFor(mode, setup) {
    return new Promise(function (resolve) {
      G.mode = mode; G.pending = null;
      if (setup) setup();
      G.resolver = resolve;
      render();
    });
  }

  /* ---------- Resolution with animation ---------- */
  async function animateMove(mv) {
    var n = G.nodes[mv.pid];
    if (n) setXY(n, mv.to, false);
    K.Sound.play(mv.capture >= 0 ? "hit" : "slide");
    if (mv.capture >= 0) { var cn = G.nodes[mv.capture]; if (cn) cn.classList.add("ghost"); }
    await K.sleep(320);
  }

  async function flipPiece(pid) {
    var n = G.nodes[pid];
    if (!n || K.reduceMotion) return;
    if (n.animate) {
      try { n.animate([{ opacity: 1 }, { opacity: 0.2 }, { opacity: 1 }], { duration: 420 }); } catch (e) {}
    }
    await K.sleep(240);
  }

  async function resolveChallenge(caller) {
    var st = G.state, lm = st.lastMove;
    var mover = st.pieces[lm.pid];
    var res = LG.challenge(st);
    K.shake(K.$("#stage"));
    await K.banner("LIAR!", { tone: "bad", sub: LG.sideName(caller) + " calls it", ms: 1000 });
    await flipPiece(mover.id);
    render();
    if (!res.honest) {
      K.Sound.play("hit");
      await K.banner("CAUGHT", { tone: "good", sub: "It was really a " + LG.NAME[res.type] + (res.restored >= 0 ? ". The capture is undone." : "."), ms: 1500 });
    } else {
      K.Sound.play("reveal");
      await K.banner("TRUE", { tone: "accent", sub: "It really is a " + LG.NAME[res.type] + ". " + LG.sideName(caller) + " must give up a piece", ms: 1500 });
    }
    render();
    return res;
  }

  /* ---------- Turns ---------- */
  async function humanResolve(side) {
    var st = G.state;
    if (!LG.mustResolve(st)) return null;
    var lm = st.lastMove;
    if (!LG.canChallenge(st)) {
      LG.accept(st);
      if (!st.pieces[lm.pid].revealed && st.tokens[side] === 0) K.toast("No accusations left, so their move stands.");
      render();
      return null;
    }
    var forced = LG.crownTaken(st);
    G.prompt = { forced: forced };
    var ans = await waitFor("challenge");
    G.prompt = null;
    if (ans.call) {
      var res = await resolveChallenge(side);
      if (st.winner == null && st.needSacrifice === side) {
        var pid = await waitFor("sacrifice");
        LG.sacrifice(st, pid);
        K.Sound.play("splash");
        render();
      }
      return { select: -1 };
    }
    LG.accept(st);
    render();
    return { select: ans.select };
  }

  async function humanTurn(side, token) {
    var st = G.state;
    var r = await humanResolve(side);
    if (token !== G.token || st.winner != null) return;
    var mv = await waitFor("move", function () { G.sel = r && r.select >= 0 ? r.select : -1; });
    if (token !== G.token) return;
    G.mode = "anim";
    LG.applyMove(st, mv);
    await animateMove(mv);
    render();
  }

  async function botTurn(side, token) {
    var st = G.state;
    G.mode = "wait";
    render();
    await K.sleep(500);
    if (token !== G.token) return;
    if (LG.mustResolve(st)) {
      var call = LG.bots.challenge(st, side, G.level, G.rand);
      if (call) {
        K.Sound.play("liar");
        await resolveChallenge(side);
        if (token !== G.token) return;
        if (st.winner == null && st.needSacrifice === side) {
          var pid = LG.bots.sacrifice(st, side);
          var victim = st.pieces[pid];
          LG.sacrifice(st, pid);
          K.toast(LG.sideName(side) + " gives up its " + LG.NAME[victim.type] + ".", 2200);
          render();
          await K.sleep(700);
        }
      } else {
        LG.accept(st);
        K.toast(LG.sideName(side) + " lets your move stand.", 1500);
        render();
        await K.sleep(400);
      }
    }
    if (st.winner != null || token !== G.token) return;
    await K.sleep(350);
    var mv = LG.bots.move(st, side, G.level, G.rand);
    if (!mv) { LG.checkStuck(st); return; }
    LG.applyMove(st, mv);
    await animateMove(mv);
    render();
  }

  async function passTo(side, kicker) {
    G.viewer = side;
    G.mode = "cover";
    buildBoard();
    render(true);
    var st = G.state;
    await K.cover({
      className: side === 0 ? "gold-cover" : "ruby-cover",
      kicker: kicker || "Move " + (Math.floor(st.ply / 2) + 1),
      title: LG.sideName(side) + "'s turn",
      text: "Pass the phone to " + LG.sideName(side) + ". " + LG.sideName(1 - side) + ", no peeking.",
      cta: "I'm " + LG.sideName(side),
      badge: '<svg viewBox="0 0 24 24" fill="' + (side === 0 ? "#e9c46a" : "#d94a63") + '">' + ICON.mask + "</svg>"
    });
  }

  async function humanSetup(side, token) {
    G.setupSide = side;
    G.setupArr = LG.randomSetup(G.rand, side, "normal");
    var st = G.state;
    if (!st.pieces.some(function (p) { return p.owner === side; })) LG.placeSide(st, side, G.setupArr);
    else applyArrangement(side, G.setupArr);
    G.sel = -1;
    await waitFor("setup");
  }

  async function runGame(token) {
    var st = G.state;
    var local = G.cfg.mode === "local";
    if (local) {
      await passTo(0, "Setup");
      if (token !== G.token) return;
      await humanSetup(0, token);
      if (token !== G.token) return;
      await passTo(1, "Setup");
      if (token !== G.token) return;
      await humanSetup(1, token);
    } else {
      G.viewer = 0;
      buildBoard();
      await humanSetup(0, token);
      if (token !== G.token) return;
      LG.placeSide(st, 1, LG.bots.setup(G.rand, 1, G.level));
    }
    if (token !== G.token) return;
    LG.startPlay(st);
    G.mode = "anim";
    if (local) await passTo(0);
    else render(true);
    while (st.winner == null) {
      if (token !== G.token) return;
      var side = st.turn;
      if (G.human[side]) {
        if (local && G.viewer !== side) { await passTo(side); if (token !== G.token) return; }
        await humanTurn(side, token);
      } else {
        await botTurn(side, token);
      }
      if (token !== G.token) return;
      if (st.winner == null && st.ply >= LG.PLY_LIMIT && !LG.mustResolve(st)) LG.checkStuck(st);
    }
    if (token !== G.token) return;
    await endGame(token);
  }

  async function endGame(token) {
    var st = G.state;
    G.mode = "over"; G.resolver = null;
    render(true);
    var youWon = null;
    if (G.cfg.mode === "bot") youWon = st.winner === 0;
    var bannerText = st.winner === "draw" ? "DRAW" : LG.sideName(st.winner).toUpperCase() + " WINS";
    await K.banner(bannerText, { tone: st.winner === 0 ? "accent" : st.winner === 1 ? "bad" : "accent", ms: 1500 });
    if (token !== G.token) return;
    var title = G.cfg.mode === "bot" ? (st.winner === "draw" ? "A draw" : youWon ? "You win!" : "You lose") : (st.winner === "draw" ? "A draw" : LG.sideName(st.winner) + " wins");
    var lies = [0, 0];
    st.pieces.forEach(function (p) { p.claims.forEach(function (c) { if (!(c & LG.BIT[p.type])) lies[p.owner]++; }); });
    var choice = await K.gameOver({
      title: title,
      tone: youWon === false ? "bad" : "good",
      text: st.reason,
      stats: [["Gold bluffs", lies[0]], ["Ruby bluffs", lies[1]], ["Moves played", st.ply]],
      reviewLabel: "Unmask everything"
    });
    if (token !== G.token) return;
    if (choice === "rematch") restart();
    else if (choice === "review") { G.review = true; render(true); }
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
    var seed = (Date.now() ^ Math.floor(Math.random() * 1e9)) >>> 0;
    G.state = LG.newGame(seed);
    G.rand = LG.rng(seed ^ 0x2545f491);
    G.review = false; G.pending = null; G.resolver = null; G.mode = null; G.sel = -1; G.prompt = null; G.viewer = 0;
    K.showScreen("game");
    buildBoard();
    runGame(G.token);
  }
  function restart() {
    K.$all(".cover,.modal-wrap,.banner").forEach(function (n) { n.remove(); });
    newMatch();
  }
  function quit() { G.token++; G.resolver = null; G.mode = null; }

  window.__liarsDebug = { G: G };

  K.init({
    ns: "liars-gambit",
    title: "Liar's Gambit",
    tagline: "Chess where you're allowed to lie. Every piece wears a mask, and every move is a claim.",
    art: TITLE_ART,
    rules: RULES,
    options: [
      { id: "mode", label: "Opponent", default: "bot", choices: [{ v: "bot", t: "Bot" }, { v: "local", t: "Friend, same phone" }] },
      { id: "difficulty", label: "Bot level", default: "normal", choices: [{ v: "easy", t: "Easy" }, { v: "normal", t: "Normal" }, { v: "hard", t: "Hard" }], showIf: function (c) { return c.mode === "bot"; },
        note: function (c) { return c.difficulty === "easy" ? "Bluffs and calls almost at random. Good for learning." : c.difficulty === "hard" ? "Tracks every claim you make and rarely wastes a move." : "Reads your claims, bluffs about 1 move in 10."; } }
    ],
    onStart: start,
    onRestart: restart,
    onQuit: quit,
    menuNote: function () { return G.state && G.state.phase === "play" ? "Move " + (Math.floor(G.state.ply / 2) + 1) + "." : ""; }
  });
})();
