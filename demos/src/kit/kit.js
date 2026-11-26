/* Shared game kit: title screen, menus, pass-the-phone covers, banners, sound.
   Exposes window.Kit. No game logic lives here. */
(function (root) {
  "use strict";
  var doc = root.document;
  var NS = "game";
  var reduceMotion = false;
  try { reduceMotion = root.matchMedia("(prefers-reduced-motion: reduce)").matches; } catch (e) {}

  function $(sel, scope) { return (scope || doc).querySelector(sel); }
  function $all(sel, scope) { return Array.prototype.slice.call((scope || doc).querySelectorAll(sel)); }

  function h(tag, attrs) {
    var node = doc.createElement(tag);
    if (attrs) {
      for (var k in attrs) {
        if (!Object.prototype.hasOwnProperty.call(attrs, k)) continue;
        var v = attrs[k];
        if (v == null || v === false) continue;
        if (k === "class") node.className = v;
        else if (k === "html") node.innerHTML = v;
        else if (k === "text") node.textContent = v;
        else if (k.slice(0, 2) === "on" && typeof v === "function") node.addEventListener(k.slice(2), v);
        else node.setAttribute(k, v === true ? "" : v);
      }
    }
    for (var i = 2; i < arguments.length; i++) {
      var c = arguments[i];
      if (c == null || c === false) continue;
      if (Array.isArray(c)) c.forEach(function (x) { if (x != null) node.appendChild(typeof x === "string" ? doc.createTextNode(x) : x); });
      else node.appendChild(typeof c === "string" ? doc.createTextNode(c) : c);
    }
    return node;
  }

  var SVGNS = "http://www.w3.org/2000/svg";
  function s(tag, attrs) {
    var node = doc.createElementNS(SVGNS, tag);
    if (attrs) {
      for (var k in attrs) {
        if (!Object.prototype.hasOwnProperty.call(attrs, k)) continue;
        var v = attrs[k];
        if (v == null || v === false) continue;
        if (k === "text") node.textContent = v;
        else if (k.slice(0, 2) === "on" && typeof v === "function") node.addEventListener(k.slice(2), v);
        else node.setAttribute(k, v);
      }
    }
    for (var i = 2; i < arguments.length; i++) {
      var c = arguments[i];
      if (c == null || c === false) continue;
      if (Array.isArray(c)) c.forEach(function (x) { if (x) node.appendChild(x); });
      else node.appendChild(c);
    }
    return node;
  }

  var store = {
    get: function (k, d) {
      try { var v = root.localStorage.getItem(NS + ":" + k); return v == null ? d : JSON.parse(v); } catch (e) { return d; }
    },
    set: function (k, v) { try { root.localStorage.setItem(NS + ":" + k, JSON.stringify(v)); } catch (e) {} }
  };

  var speed = 1;
  function sleep(ms) {
    var t = reduceMotion ? Math.min(ms, 80) : ms * speed;
    return new Promise(function (r) { setTimeout(r, t); });
  }
  function frame() { return new Promise(function (r) { root.requestAnimationFrame(function () { r(); }); }); }

  /* ---------- Sound: tiny WebAudio synth, starts after the first tap ---------- */
  var Sound = (function () {
    var ctx = null, master = null, on = true;
    function ensure() {
      if (ctx) { if (ctx.state === "suspended") ctx.resume(); return ctx; }
      var AC = root.AudioContext || root.webkitAudioContext;
      if (!AC) return null;
      ctx = new AC();
      master = ctx.createGain();
      master.gain.value = 0.55;
      master.connect(ctx.destination);
      return ctx;
    }
    function tone(freq, dur, opts) {
      opts = opts || {};
      var c = ensure(); if (!c) return;
      var t0 = c.currentTime + (opts.delay || 0);
      var o = c.createOscillator();
      var g = c.createGain();
      o.type = opts.type || "sine";
      o.frequency.setValueAtTime(freq, t0);
      if (opts.to) o.frequency.exponentialRampToValueAtTime(Math.max(20, opts.to), t0 + dur);
      var peak = opts.gain == null ? 0.25 : opts.gain;
      g.gain.setValueAtTime(0.0001, t0);
      g.gain.exponentialRampToValueAtTime(peak, t0 + Math.min(0.02, dur / 4));
      g.gain.exponentialRampToValueAtTime(0.0001, t0 + dur);
      o.connect(g); g.connect(master);
      o.start(t0); o.stop(t0 + dur + 0.05);
    }
    function noise(dur, opts) {
      opts = opts || {};
      var c = ensure(); if (!c) return;
      var t0 = c.currentTime + (opts.delay || 0);
      var len = Math.max(1, Math.floor(c.sampleRate * dur));
      var buf = c.createBuffer(1, len, c.sampleRate);
      var data = buf.getChannelData(0);
      for (var i = 0; i < len; i++) data[i] = (Math.random() * 2 - 1) * (1 - i / len);
      var src = c.createBufferSource();
      src.buffer = buf;
      var f = c.createBiquadFilter();
      f.type = opts.filter || "lowpass";
      f.frequency.value = opts.freq || 1200;
      var g = c.createGain();
      g.gain.setValueAtTime(opts.gain == null ? 0.3 : opts.gain, t0);
      g.gain.exponentialRampToValueAtTime(0.0001, t0 + dur);
      src.connect(f); f.connect(g); g.connect(master);
      src.start(t0); src.stop(t0 + dur + 0.05);
    }
    var lib = {
      tap: function () { tone(660, 0.06, { type: "triangle", gain: 0.12 }); },
      select: function () { tone(520, 0.07, { type: "triangle", gain: 0.16 }); tone(780, 0.08, { type: "triangle", gain: 0.12, delay: 0.05 }); },
      move: function () { tone(300, 0.12, { type: "sine", to: 420, gain: 0.16 }); },
      slide: function () { noise(0.16, { freq: 900, gain: 0.12 }); },
      error: function () { tone(180, 0.16, { type: "square", gain: 0.08 }); },
      hit: function () { noise(0.22, { freq: 700, gain: 0.45 }); tone(140, 0.25, { type: "sawtooth", to: 60, gain: 0.22 }); },
      miss: function () { noise(0.3, { freq: 2400, filter: "bandpass", gain: 0.22 }); },
      splash: function () { noise(0.45, { freq: 1600, gain: 0.35 }); tone(220, 0.3, { to: 90, gain: 0.08 }); },
      ping: function () { tone(1320, 0.5, { type: "sine", gain: 0.2 }); tone(1320, 0.6, { type: "sine", gain: 0.07, delay: 0.32 }); },
      contact: function () { tone(880, 0.16, { type: "square", gain: 0.1 }); tone(880, 0.16, { type: "square", gain: 0.1, delay: 0.2 }); tone(1175, 0.3, { type: "square", gain: 0.1, delay: 0.4 }); },
      reveal: function () { tone(392, 0.12, { type: "triangle", gain: 0.16 }); tone(587, 0.18, { type: "triangle", gain: 0.16, delay: 0.1 }); },
      roar: function () { tone(110, 0.7, { type: "sawtooth", to: 55, gain: 0.25 }); noise(0.6, { freq: 400, gain: 0.25 }); },
      liar: function () { tone(220, 0.12, { type: "square", gain: 0.14 }); tone(165, 0.35, { type: "square", gain: 0.14, delay: 0.12 }); },
      win: function () { [523, 659, 784, 1047].forEach(function (f, i) { tone(f, 0.22, { type: "triangle", gain: 0.16, delay: i * 0.11 }); }); },
      lose: function () { [392, 330, 262, 196].forEach(function (f, i) { tone(f, 0.28, { type: "triangle", gain: 0.14, delay: i * 0.14 }); }); },
      tick: function () { tone(1000, 0.03, { type: "square", gain: 0.05 }); },
      whoosh: function () { noise(0.25, { freq: 3000, filter: "bandpass", gain: 0.18 }); },
      score: function () { tone(880, 0.09, { type: "triangle", gain: 0.14 }); tone(1320, 0.14, { type: "triangle", gain: 0.12, delay: 0.07 }); },
      zap: function () { tone(1400, 0.18, { type: "sawtooth", to: 300, gain: 0.1 }); }
    };
    return {
      play: function (name) { if (!on) return; try { var f = lib[name]; if (f) f(); } catch (e) {} },
      unlock: function () { if (on) { try { ensure(); } catch (e) {} } },
      get on() { return on; },
      set on(v) { on = !!v; store.set("sound", on); }
    };
  })();

  function haptic(ms) { try { if (root.navigator.vibrate) root.navigator.vibrate(ms || 12); } catch (e) {} }

  /* ---------- Overlays ---------- */
  var app = null;
  function appRoot() { return app || (app = $("#app")); }

  function cover(opts) {
    opts = opts || {};
    return new Promise(function (resolve) {
      var btn = h("button", { class: "btn btn-primary", type: "button" }, opts.cta || "Tap when ready");
      var node = h("div", { class: "cover" + (opts.className ? " " + opts.className : ""), role: "dialog", "aria-modal": "true" },
        opts.badge ? h("div", { class: "cover-badge", html: opts.badge }) : null,
        opts.kicker ? h("p", { class: "cover-kicker" }, opts.kicker) : null,
        h("h2", null, opts.title || "Pass the phone"),
        opts.text ? h("p", null, opts.text) : null,
        btn);
      btn.addEventListener("click", function () { Sound.unlock(); Sound.play("tap"); node.remove(); resolve(); });
      appRoot().appendChild(node);
      setTimeout(function () { try { btn.focus(); } catch (e) {} }, 30);
    });
  }

  function modal(opts) {
    opts = opts || {};
    return new Promise(function (resolve) {
      var wrap;
      function done(v) { wrap.remove(); doc.removeEventListener("keydown", onKey); resolve(v); }
      function onKey(e) { if (e.key === "Escape" && opts.dismissible !== false) done(null); }
      var body = h("div", { class: "modal-body" + (opts.bodyClass ? " " + opts.bodyClass : "") });
      if (typeof opts.body === "string") body.innerHTML = opts.body; else if (opts.body) body.appendChild(opts.body);
      var actions = h("div", { class: "modal-actions" });
      (opts.actions || [{ label: "Close", value: null }]).forEach(function (a) {
        actions.appendChild(h("button", {
          class: "btn btn-wide " + (a.kind === "primary" ? "btn-primary" : a.kind === "danger" ? "btn-danger" : "btn-ghost"),
          type: "button",
          onclick: function () { Sound.play("tap"); done(a.value); }
        }, a.label));
      });
      var closeBtn = opts.dismissible === false ? null : h("button", { class: "icon-btn", type: "button", "aria-label": "Close", onclick: function () { done(null); },
        html: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round"><path d="M6 6l12 12M18 6L6 18"/></svg>' });
      var panel = h("div", { class: "modal", role: "dialog", "aria-modal": "true", "aria-label": opts.title || "Dialog" },
        h("div", { class: "modal-head" }, h("h2", null, opts.title || ""), closeBtn),
        body,
        (opts.actions && opts.actions.length === 0) ? null : actions);
      wrap = h("div", { class: "modal-wrap", onclick: function (e) { if (e.target === wrap && opts.dismissible !== false) done(null); } }, panel);
      appRoot().appendChild(wrap);
      doc.addEventListener("keydown", onKey);
    });
  }

  function banner(text, opts) {
    opts = opts || {};
    var node = h("div", { class: "banner tone-" + (opts.tone || "accent"), "aria-live": "assertive" },
      h("div", { class: "banner-text" }, text),
      opts.sub ? h("div", { class: "banner-sub" }, opts.sub) : null);
    appRoot().appendChild(node);
    var ms = opts.ms || 1100;
    return sleep(ms).then(function () { node.remove(); });
  }

  var toastTimer = null, toastNode = null;
  function toast(text, ms) {
    if (toastNode) toastNode.remove();
    toastNode = h("div", { class: "toast", role: "status" }, text);
    appRoot().appendChild(toastNode);
    clearTimeout(toastTimer);
    var n = toastNode;
    toastTimer = setTimeout(function () { if (n) n.remove(); if (toastNode === n) toastNode = null; }, ms || 1900);
  }

  function shake(node) {
    if (!node || reduceMotion) return;
    node.classList.remove("shake");
    void node.getBoundingClientRect();
    node.classList.add("shake");
    setTimeout(function () { node.classList.remove("shake"); }, 420);
  }

  /* ---------- Title screen with option pickers ---------- */
  var ICONS = {
    menu: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round"><path d="M4 7h16M4 12h16M4 17h16"/></svg>',
    soundOn: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 9v6h4l5 4V5L8 9z"/><path d="M16.5 8.5a5 5 0 010 7M19 6a8.5 8.5 0 010 12"/></svg>',
    soundOff: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 9v6h4l5 4V5L8 9z"/><path d="M17 9l5 6M22 9l-5 6"/></svg>',
    phone: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="7" y="2.5" width="10" height="19" rx="2.5"/><path d="M11 18.5h2"/></svg>',
    eye: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M2 12s3.5-7 10-7 10 7 10 7-3.5 7-10 7S2 12 2 12z"/><circle cx="12" cy="12" r="3"/></svg>',
    help: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="9.5"/><path d="M9.5 9.3a2.6 2.6 0 015 1c0 1.8-2.5 2.2-2.5 3.9M12 17.2v.3"/></svg>'
  };

  var cfg = null;
  var choice = {};

  function visibleOptions() {
    return cfg.options.filter(function (o) { return !o.showIf || o.showIf(choice); });
  }

  function renderTitle() {
    var host = $("#title-options");
    host.innerHTML = "";
    visibleOptions().forEach(function (opt) {
      var seg = h("div", { class: "seg", role: "group", "aria-label": opt.label });
      opt.choices.forEach(function (c) {
        seg.appendChild(h("button", {
          type: "button",
          "aria-pressed": choice[opt.id] === c.v ? "true" : "false",
          onclick: function () {
            Sound.unlock(); Sound.play("tap");
            choice[opt.id] = c.v;
            store.set("choice", choice);
            renderTitle();
          }
        }, c.t));
      });
      var note = opt.note ? opt.note(choice) : null;
      host.appendChild(h("div", { class: "opt-group" },
        h("span", { class: "opt-label" }, opt.label), seg,
        note ? h("p", { class: "opt-note" }, note) : null));
    });
  }

  function showRules() {
    return modal({ title: "How to play", body: cfg.rules, bodyClass: "rules", actions: [{ label: "Got it", value: true, kind: "primary" }] });
  }

  function showScreen(name) {
    $all(".screen").forEach(function (sc) { sc.hidden = sc.id !== "screen-" + name; });
  }

  function init(config) {
    cfg = config;
    NS = config.ns || NS;
    Sound.on = store.get("sound", true);
    var saved = store.get("choice", {});
    choice = {};
    cfg.options.forEach(function (o) {
      var ok = o.choices.some(function (c) { return c.v === saved[o.id]; });
      choice[o.id] = ok ? saved[o.id] : o.default;
    });
    var title = $("#screen-title");
    title.innerHTML = "";
    title.appendChild(h("div", { class: "title-inner" },
      cfg.art ? h("div", { class: "title-art", html: cfg.art }) : null,
      h("h1", { class: "title-name" }, cfg.title),
      h("p", { class: "title-tag" }, cfg.tagline),
      h("div", { id: "title-options", class: "title-options", style: "display:flex;flex-direction:column;gap:14px" }),
      h("div", { class: "title-actions" },
        h("button", { class: "btn btn-primary btn-wide", type: "button", id: "btn-start", onclick: function () {
          Sound.unlock(); Sound.play("select");
          var c = {}; visibleOptions().forEach(function (o) { c[o.id] = choice[o.id]; });
          cfg.onStart(c);
        } }, "Play"),
        h("button", { class: "btn btn-ghost btn-wide", type: "button", onclick: function () { Sound.unlock(); Sound.play("tap"); showRules(); } }, "How to play"))));
    renderTitle();
    showScreen("title");
    var menuBtn = $("#btn-menu");
    if (menuBtn) {
      menuBtn.innerHTML = ICONS.menu;
      menuBtn.onclick = function () { Sound.play("tap"); openMenu(); };
    }
  }

  function openMenu() {
    return modal({
      title: "Paused",
      body: h("p", { style: "margin:0;color:var(--muted)" }, cfg.menuNote ? cfg.menuNote() : "The game is waiting for you."),
      actions: [
        { label: "Resume", value: "resume", kind: "primary" },
        { label: "How to play", value: "rules" },
        { label: Sound.on ? "Sound: on" : "Sound: off", value: "sound" },
        { label: "Restart this match", value: "restart" },
        { label: "Quit to title", value: "quit", kind: "danger" }
      ]
    }).then(function (v) {
      if (v === "rules") return showRules().then(openMenu);
      if (v === "sound") { Sound.on = !Sound.on; if (Sound.on) Sound.play("select"); return openMenu(); }
      if (v === "restart") return confirmAsk("Restart this match?", "The current match will be lost.").then(function (ok) { if (ok && cfg.onRestart) cfg.onRestart(); });
      if (v === "quit") return confirmAsk("Quit to the title screen?", "The current match will be lost.").then(function (ok) { if (ok) quit(); });
    });
  }

  function confirmAsk(title, text) {
    return modal({ title: title, body: h("p", { style: "margin:0;color:var(--muted)" }, text), actions: [
      { label: "Yes", value: true, kind: "danger" }, { label: "Cancel", value: false }] }).then(function (v) { return v === true; });
  }

  function quit() {
    if (cfg.onQuit) cfg.onQuit();
    $all(".cover,.modal-wrap,.banner,.toast").forEach(function (n) { n.remove(); });
    renderTitle();
    showScreen("title");
  }

  function gameOver(opts) {
    Sound.play(opts.tone === "bad" ? "lose" : "win");
    var body = h("div", null,
      opts.text ? h("p", { style: "margin:0 0 10px;color:var(--muted)" }, opts.text) : null,
      opts.stats ? (function () {
        var grid = h("div", { class: "result-stats" });
        opts.stats.forEach(function (row) { grid.appendChild(h("span", null, row[0])); grid.appendChild(h("span", null, String(row[1]))); });
        return grid;
      })() : null);
    return modal({ title: opts.title, body: body, dismissible: false, actions: [
      { label: "Rematch", value: "rematch", kind: "primary" },
      { label: opts.reviewLabel || "Look at the board", value: "review" },
      { label: "Main menu", value: "menu" }] }).then(function (v) {
        if (v === "menu") { quit(); return "menu"; }
        return v;
      });
  }


  /* ---------- Blocky characters: Roblox-style heads and figures drawn as SVG ----------
     portrait(spec) draws a head and shoulders in a 64x64 box.
     figure(spec) draws a whole standing figure in a 40x52 box (x -20..20, y -36..16).
     spec: skin, shirt, pants, hair, hairStyle, hat, hatColor, hatColor2, eyes, brows, mouth,
           beard, beardColor, extras (array), accent. Every part is optional. */
  var OUT = "#0b1622";
  function face(p, ox, oy, k) {
    // ox, oy: top-left of the head box; k: head size (34 for portraits)
    var o = "", sc = k / 34;
    function X(v) { return (ox + v * sc).toFixed(2); }
    function Y(v) { return (oy + v * sc).toFixed(2); }
    function S(v) { return (v * sc).toFixed(2); }
    var eyes = p.eyes || "dot", lx = 11, rx = 23, ey = 15;
    if (eyes === "wide") {
      o += '<circle cx="' + X(lx) + '" cy="' + Y(ey) + '" r="' + S(4.2) + '" fill="#fff" stroke="' + OUT + '" stroke-width="' + S(1.2) + '"/><circle cx="' + X(lx + 0.6) + '" cy="' + Y(ey + 0.4) + '" r="' + S(2.1) + '" fill="' + OUT + '"/>';
      o += '<circle cx="' + X(rx) + '" cy="' + Y(ey) + '" r="' + S(4.2) + '" fill="#fff" stroke="' + OUT + '" stroke-width="' + S(1.2) + '"/><circle cx="' + X(rx + 0.6) + '" cy="' + Y(ey + 0.4) + '" r="' + S(2.1) + '" fill="' + OUT + '"/>';
    } else if (eyes === "squint") {
      o += '<path d="M' + X(lx - 3) + " " + Y(ey) + "h" + S(6) + "M" + X(rx - 3) + " " + Y(ey) + "h" + S(6) + '" stroke="' + OUT + '" stroke-width="' + S(2.2) + '" stroke-linecap="round"/>';
    } else if (eyes === "mask") {
      o += '<rect x="' + X(4) + '" y="' + Y(ey - 4.5) + '" width="' + S(26) + '" height="' + S(8.5) + '" rx="' + S(3) + '" fill="' + (p.maskColor || OUT) + '"/>';
      o += '<ellipse cx="' + X(lx) + '" cy="' + Y(ey) + '" rx="' + S(2.6) + '" ry="' + S(2) + '" fill="#fff"/><ellipse cx="' + X(rx) + '" cy="' + Y(ey) + '" rx="' + S(2.6) + '" ry="' + S(2) + '" fill="#fff"/>';
    } else if (eyes === "shades") {
      o += '<path d="M' + X(4) + " " + Y(ey - 3.5) + "h" + S(26) + "v" + S(3) + "q" + S(-1) + " " + S(5) + " " + S(-6) + " " + S(5) + "q" + S(-5) + " 0 " + S(-6) + " " + S(-4.5) + "h" + S(-2) + "q" + S(-1) + " " + S(4.5) + " " + S(-6) + " " + S(4.5) + "q" + S(-5) + " 0 " + S(-6) + " " + S(-5) + 'z" fill="' + OUT + '"/>';
      o += '<path d="M' + X(7) + " " + Y(ey - 2) + "l" + S(3) + " 0" + '" stroke="#9fb3c8" stroke-width="' + S(1.2) + '" stroke-linecap="round"/>';
    } else {
      o += '<rect x="' + X(lx - 2.4) + '" y="' + Y(ey - 3) + '" width="' + S(4.8) + '" height="' + S(6) + '" rx="' + S(2) + '" fill="' + OUT + '"/>';
      if (eyes !== "patch") o += '<rect x="' + X(rx - 2.4) + '" y="' + Y(ey - 3) + '" width="' + S(4.8) + '" height="' + S(6) + '" rx="' + S(2) + '" fill="' + OUT + '"/>';
      else {
        o += '<path d="M' + X(0) + " " + Y(9) + "L" + X(34) + " " + Y(4) + '" stroke="' + OUT + '" stroke-width="' + S(1.6) + '"/>';
        o += '<rect x="' + X(rx - 4.5) + '" y="' + Y(ey - 4.5) + '" width="' + S(9) + '" height="' + S(9) + '" rx="' + S(3) + '" fill="' + OUT + '"/>';
      }
    }
    var brows = p.brows;
    var bc = p.browColor || OUT;
    if (brows === "angry") o += '<path d="M' + X(lx - 4) + " " + Y(ey - 7) + "L" + X(lx + 3) + " " + Y(ey - 5) + "M" + X(rx + 4) + " " + Y(ey - 7) + "L" + X(rx - 3) + " " + Y(ey - 5) + '" stroke="' + bc + '" stroke-width="' + S(2.4) + '" stroke-linecap="round"/>';
    else if (brows === "raised") o += '<path d="M' + X(lx - 4) + " " + Y(ey - 6) + "q" + S(4) + " " + S(-3) + " " + S(8) + " 0M" + X(rx - 4) + " " + Y(ey - 6) + "q" + S(4) + " " + S(-3) + " " + S(8) + ' 0" fill="none" stroke="' + bc + '" stroke-width="' + S(2) + '" stroke-linecap="round"/>';
    else if (brows === "thick") o += '<rect x="' + X(lx - 4.5) + '" y="' + Y(ey - 8) + '" width="' + S(9) + '" height="' + S(3) + '" rx="' + S(1.4) + '" fill="' + bc + '"/><rect x="' + X(rx - 4.5) + '" y="' + Y(ey - 8) + '" width="' + S(9) + '" height="' + S(3) + '" rx="' + S(1.4) + '" fill="' + bc + '"/>';
    var mouth = p.mouth || "smile", my = 24;
    if (mouth === "grin") o += '<path d="M' + X(10) + " " + Y(my - 1) + "h" + S(14) + "q" + S(-1) + " " + S(7) + " " + S(-7) + " " + S(7) + "q" + S(-6) + " 0 " + S(-7) + " " + S(-7) + 'z" fill="#fff" stroke="' + OUT + '" stroke-width="' + S(1.6) + '" stroke-linejoin="round"/>';
    else if (mouth === "frown") o += '<path d="M' + X(12) + " " + Y(my + 3) + "q" + S(5) + " " + S(-4) + " " + S(10) + ' 0" fill="none" stroke="' + OUT + '" stroke-width="' + S(2.2) + '" stroke-linecap="round"/>';
    else if (mouth === "flat") o += '<path d="M' + X(13) + " " + Y(my + 1) + "h" + S(8) + '" stroke="' + OUT + '" stroke-width="' + S(2.2) + '" stroke-linecap="round"/>';
    else if (mouth === "smirk") o += '<path d="M' + X(12) + " " + Y(my + 1) + "q" + S(6) + " " + S(2.5) + " " + S(10) + " " + S(-2) + '" fill="none" stroke="' + OUT + '" stroke-width="' + S(2.2) + '" stroke-linecap="round"/>';
    else if (mouth === "o") o += '<ellipse cx="' + X(17) + '" cy="' + Y(my + 1.5) + '" rx="' + S(2.6) + '" ry="' + S(3.2) + '" fill="' + OUT + '"/>';
    else if (mouth !== "none") o += '<path d="M' + X(11.5) + " " + Y(my) + "q" + S(5.5) + " " + S(5.5) + " " + S(11) + ' 0" fill="none" stroke="' + OUT + '" stroke-width="' + S(2.2) + '" stroke-linecap="round"/>';
    return o;
  }

  function beardSvg(p, ox, oy, k) {
    var sc = k / 34, b = p.beard, c = p.beardColor || "#6b4a2b";
    function X(v) { return (ox + v * sc).toFixed(2); }
    function Y(v) { return (oy + v * sc).toFixed(2); }
    function S(v) { return (v * sc).toFixed(2); }
    if (b === "full") return '<path d="M' + X(0) + " " + Y(17) + "v" + S(6) + "q0 " + S(14) + " " + S(17) + " " + S(14) + "q" + S(17) + " 0 " + S(17) + " " + S(-14) + "v" + S(-6) + "q" + S(-5) + " " + S(5) + " " + S(-17) + " " + S(5) + "q" + S(-12) + " 0 " + S(-17) + ' -5z" fill="' + c + '" stroke="' + OUT + '" stroke-width="' + S(1.6) + '" stroke-linejoin="round"/>' +
      '<path d="M' + X(10) + " " + Y(22.5) + "q" + S(7) + " " + S(-3.5) + " " + S(14) + ' 0" fill="none" stroke="' + OUT + '" stroke-width="' + S(1.8) + '" stroke-linecap="round"/>';
    if (b === "mustache") return '<path d="M' + X(8) + " " + Y(22.5) + "q" + S(9) + " " + S(-6) + " " + S(18) + " 0q" + S(-9) + " " + S(3) + " " + S(-18) + ' 0z" fill="' + c + '" stroke="' + OUT + '" stroke-width="' + S(1.2) + '" stroke-linejoin="round"/>';
    if (b === "stubble") {
      var o = "";
      [[8, 26], [11, 29], [15, 30.5], [19, 30.5], [23, 29], [26, 26], [10, 27.5], [24, 27.5]].forEach(function (d) { o += '<circle cx="' + X(d[0]) + '" cy="' + Y(d[1]) + '" r="' + S(0.8) + '" fill="' + c + '"/>'; });
      return o;
    }
    return "";
  }

  function hatSvg(p, ox, oy, k, layer) {
    var sc = k / 34, hat = p.hat, c1 = p.hatColor || "#2b3a55", c2 = p.hatColor2 || "#f2b84b", o = "";
    function X(v) { return (ox + v * sc).toFixed(2); }
    function Y(v) { return (oy + v * sc).toFixed(2); }
    function S(v) { return (v * sc).toFixed(2); }
    var st = ' stroke="' + OUT + '" stroke-width="' + S(1.8) + '" stroke-linejoin="round"';
    if (layer === "back") {
      if (p.hairStyle === "braids") {
        o += '<rect x="' + X(-4) + '" y="' + Y(12) + '" width="' + S(6) + '" height="' + S(24) + '" rx="' + S(2.5) + '" fill="' + (p.hair || "#f2c14e") + '"' + st + "/>";
        o += '<rect x="' + X(32) + '" y="' + Y(12) + '" width="' + S(6) + '" height="' + S(24) + '" rx="' + S(2.5) + '" fill="' + (p.hair || "#f2c14e") + '"' + st + "/>";
      }
      if (p.hairStyle === "long") o += '<path d="M' + X(-3) + " " + Y(6) + "q0 " + S(-8) + " " + S(20) + " " + S(-8) + "q" + S(20) + " 0 " + S(20) + " " + S(8) + "v" + S(28) + "h" + S(-40) + 'z" fill="' + (p.hair || "#3b2a1f") + '"' + st + "/>";
      if (hat === "hood") o += '<path d="M' + X(-5) + " " + Y(36) + "v" + S(-22) + "q0 " + S(-18) + " " + S(22) + " " + S(-18) + "q" + S(22) + " 0 " + S(22) + " " + S(18) + "v" + S(22) + 'z" fill="' + c1 + '"' + st + "/>";
      return o;
    }
    switch (p.hairStyle) {
      case "messy": o += '<path d="M' + X(0) + " " + Y(9) + "l" + S(2) + " " + S(-9) + "l" + S(5) + " " + S(5) + "l" + S(4) + " " + S(-8) + "l" + S(5) + " " + S(6) + "l" + S(5) + " " + S(-7) + "l" + S(4) + " " + S(7) + "l" + S(5) + " " + S(-4) + "l" + S(4) + " " + S(10) + 'z" fill="' + (p.hair || "#e0762b") + '"' + st + "/>"; break;
      case "flat": o += '<path d="M' + X(0) + " " + Y(9) + "v" + S(-4) + "q0 " + S(-5) + " " + S(5) + " " + S(-5) + "h" + S(24) + "q" + S(5) + " 0 " + S(5) + " " + S(5) + "v" + S(4) + 'z" fill="' + (p.hair || "#3b2a1f") + '"' + st + "/>"; break;
      case "pompadour": o += '<path d="M' + X(-1) + " " + Y(10) + "q" + S(-1) + " " + S(-12) + " " + S(14) + " " + S(-13) + "q" + S(16) + " " + S(-1) + " " + S(22) + " " + S(4) + "q" + S(-8) + " " + S(-1) + " " + S(-12) + " " + S(4) + "q" + S(9) + " " + S(1) + " " + S(12) + " " + S(5) + 'z" fill="' + (p.hair || "#1d1d24") + '"' + st + "/><path d=\"M" + X(8) + " " + Y(-1) + "q" + S(8) + " " + S(-3) + " " + S(16) + " " + S(1) + '" fill="none" stroke="#5b6b8a" stroke-width="' + S(1.3) + '" stroke-linecap="round"/>'; break;
      case "bald": break;
      case "spiky": o += '<path d="M' + X(0) + " " + Y(9) + "l" + S(3) + " " + S(-12) + "l" + S(6) + " " + S(7) + "l" + S(5) + " " + S(-11) + "l" + S(5) + " " + S(10) + "l" + S(6) + " " + S(-10) + "l" + S(3) + " " + S(11) + "l" + S(6) + " " + S(-5) + "v" + S(10) + 'z" fill="' + (p.hair || "#2b2b2b") + '"' + st + "/>"; break;
    }
    switch (hat) {
      case "captain":
        o += '<path d="M' + X(-1) + " " + Y(4) + "v" + S(-6) + "q0 " + S(-7) + " " + S(9) + " " + S(-8) + "h" + S(18) + "q" + S(9) + " " + S(1) + " " + S(9) + " " + S(8) + "v" + S(6) + 'z" fill="' + c1 + '"' + st + "/>";
        o += '<rect x="' + X(-1) + '" y="' + Y(0) + '" width="' + S(36) + '" height="' + S(4) + '" fill="' + OUT + '"/>';
        o += '<path d="M' + X(-3) + " " + Y(5) + "h" + S(40) + "q" + S(-2) + " " + S(4) + " " + S(-8) + " " + S(4) + "h" + S(-24) + "q" + S(-6) + " 0 " + S(-8) + ' -4z" fill="' + OUT + '"/>';
        o += '<circle cx="' + X(17) + '" cy="' + Y(-3) + '" r="' + S(3.4) + '" fill="' + c2 + '" stroke="' + OUT + '" stroke-width="' + S(1.2) + '"/>';
        break;
      case "headphones":
        o += '<path d="M' + X(-1) + " " + Y(16) + "q0 " + S(-21) + " " + S(18) + " " + S(-21) + "q" + S(18) + " 0 " + S(18) + " " + S(21) + '" fill="none" stroke="' + OUT + '" stroke-width="' + S(5) + '"/>';
        o += '<path d="M' + X(-1) + " " + Y(16) + "q0 " + S(-21) + " " + S(18) + " " + S(-21) + "q" + S(18) + " 0 " + S(18) + " " + S(21) + '" fill="none" stroke="' + c1 + '" stroke-width="' + S(2.4) + '"/>';
        o += '<rect x="' + X(-5) + '" y="' + Y(11) + '" width="' + S(8) + '" height="' + S(12) + '" rx="' + S(2.5) + '" fill="' + c2 + '"' + st + "/>";
        o += '<rect x="' + X(31) + '" y="' + Y(11) + '" width="' + S(8) + '" height="' + S(12) + '" rx="' + S(2.5) + '" fill="' + c2 + '"' + st + "/>";
        o += '<path d="M' + X(-1) + " " + Y(21) + "q" + S(2) + " " + S(8) + " " + S(10) + " " + S(7) + '" fill="none" stroke="' + OUT + '" stroke-width="' + S(1.6) + '" stroke-linecap="round"/><circle cx="' + X(9.5) + '" cy="' + Y(28) + '" r="' + S(1.7) + '" fill="' + OUT + '"/>';
        break;
      case "beanie":
        o += '<path d="M' + X(-1) + " " + Y(9) + "q0 " + S(-15) + " " + S(18) + " " + S(-15) + "q" + S(18) + " 0 " + S(18) + " " + S(15) + 'z" fill="' + c1 + '"' + st + "/>";
        o += '<rect x="' + X(-2) + '" y="' + Y(5) + '" width="' + S(38) + '" height="' + S(6) + '" rx="' + S(2) + '" fill="' + c2 + '"' + st + "/>";
        o += '<circle cx="' + X(17) + '" cy="' + Y(-7) + '" r="' + S(3.6) + '" fill="' + c2 + '"' + st + "/>";
        break;
      case "souwester":
        o += '<path d="M' + X(2) + " " + Y(4) + "q0 " + S(-12) + " " + S(15) + " " + S(-12) + "q" + S(15) + " 0 " + S(15) + " " + S(12) + 'z" fill="' + c1 + '"' + st + "/>";
        o += '<path d="M' + X(-7) + " " + Y(7) + "q" + S(24) + " " + S(-9) + " " + S(48) + " 0q" + S(2) + " " + S(4) + " " + S(-4) + " " + S(5) + "q" + S(-20) + " " + S(-5) + " " + S(-40) + " 0q" + S(-6) + " " + S(-1) + " " + S(-4) + ' -5z" fill="' + c1 + '"' + st + "/>";
        break;
      case "fedora":
        o += '<path d="M' + X(1) + " " + Y(6) + "q" + S(1) + " " + S(-12) + " " + S(16) + " " + S(-12) + "q" + S(15) + " 0 " + S(16) + " " + S(12) + 'z" fill="' + c1 + '"' + st + "/>";
        o += '<rect x="' + X(1) + '" y="' + Y(2) + '" width="' + S(32) + '" height="' + S(4) + '" fill="' + c2 + '"/>';
        o += '<path d="M' + X(-6) + " " + Y(8) + "q" + S(23) + " " + S(-6) + " " + S(46) + ' 0z" fill="' + c1 + '"' + st + "/>";
        break;
      case "cap":
        o += '<path d="M' + X(-1) + " " + Y(8) + "q0 " + S(-12) + " " + S(18) + " " + S(-12) + "q" + S(18) + " 0 " + S(18) + " " + S(12) + 'z" fill="' + c1 + '"' + st + "/>";
        o += '<path d="M' + X(14) + " " + Y(6) + "h" + S(30) + "q" + S(-2) + " " + S(4) + " " + S(-7) + " " + S(4) + "h" + S(-23) + 'z" fill="' + c2 + '"' + st + "/>";
        break;
      case "beret":
        o += '<ellipse cx="' + X(15) + '" cy="' + Y(3) + '" rx="' + S(19) + '" ry="' + S(7) + '" fill="' + c1 + '"' + st + "/>";
        o += '<rect x="' + X(14) + '" y="' + Y(-6) + '" width="' + S(2.5) + '" height="' + S(4) + '" fill="' + OUT + '"/>';
        break;
      case "headband":
        o += '<rect x="' + X(-1) + '" y="' + Y(3) + '" width="' + S(36) + '" height="' + S(5) + '" fill="' + c1 + '"' + st + "/>";
        o += '<path d="M' + X(34) + " " + Y(5) + "l" + S(6) + " " + S(-3) + "l" + S(-1) + " " + S(6) + 'z" fill="' + c1 + '"' + st + "/>";
        break;
      case "bucket":
        o += '<path d="M' + X(2) + " " + Y(6) + "l" + S(3) + " " + S(-11) + "h" + S(24) + "l" + S(3) + " " + S(11) + 'z" fill="' + c1 + '"' + st + "/>";
        o += '<path d="M' + X(-4) + " " + Y(9) + "h" + S(42) + "l" + S(-3) + " " + S(-4) + "h" + S(-36) + 'z" fill="' + c1 + '"' + st + "/>";
        break;
      case "hood":
        o += '<path d="M' + X(-3) + " " + Y(14) + "q0 " + S(-17) + " " + S(20) + " " + S(-17) + "q" + S(20) + " 0 " + S(20) + " " + S(17) + "q" + S(-4) + " " + S(-12) + " " + S(-20) + " " + S(-12) + "q" + S(-16) + " 0 " + S(-20) + ' 12z" fill="' + c1 + '"' + st + "/>";
        break;
      case "police":
        o += '<path d="M' + X(0) + " " + Y(6) + "l" + S(-2) + " " + S(-9) + "q" + S(19) + " " + S(-7) + " " + S(38) + " 0l" + S(-2) + " " + S(9) + 'z" fill="' + c1 + '"' + st + "/>";
        o += '<path d="M' + X(-1) + " " + Y(6) + "h" + S(36) + "l" + S(-3) + " " + S(4) + "h" + S(-30) + 'z" fill="' + OUT + '"/>';
        o += '<path d="M' + X(14) + " " + Y(-3) + "l" + S(3) + " " + S(-2) + "l" + S(3) + " " + S(2) + "l" + S(-3) + " " + S(4) + 'z" fill="' + c2 + '" stroke="' + OUT + '" stroke-width="' + S(1) + '"/>';
        break;
      case "tophat":
        o += '<rect x="' + X(4) + '" y="' + Y(-14) + '" width="' + S(26) + '" height="' + S(20) + '" rx="' + S(2) + '" fill="' + c1 + '"' + st + "/>";
        o += '<rect x="' + X(4) + '" y="' + Y(1) + '" width="' + S(26) + '" height="' + S(4) + '" fill="' + c2 + '"/>';
        o += '<rect x="' + X(-4) + '" y="' + Y(5) + '" width="' + S(42) + '" height="' + S(4) + '" rx="' + S(2) + '" fill="' + c1 + '"' + st + "/>";
        break;
    }
    return o;
  }

  function extrasSvg(p, ox, oy, k) {
    var sc = k / 34, o = "";
    function X(v) { return (ox + v * sc).toFixed(2); }
    function Y(v) { return (oy + v * sc).toFixed(2); }
    function S(v) { return (v * sc).toFixed(2); }
    (p.extras || []).forEach(function (e) {
      if (e === "freckles") [[6, 21], [8.5, 22.5], [5.5, 23.5], [28, 21], [25.5, 22.5], [28.5, 23.5]].forEach(function (d) { o += '<circle cx="' + X(d[0]) + '" cy="' + Y(d[1]) + '" r="' + S(0.85) + '" fill="#b4643a"/>'; });
      if (e === "blush") o += '<ellipse cx="' + X(6) + '" cy="' + Y(21) + '" rx="' + S(3) + '" ry="' + S(1.8) + '" fill="#ff8a8a" opacity=".55"/><ellipse cx="' + X(28) + '" cy="' + Y(21) + '" rx="' + S(3) + '" ry="' + S(1.8) + '" fill="#ff8a8a" opacity=".55"/>';
      if (e === "glasses") o += '<circle cx="' + X(11) + '" cy="' + Y(15) + '" r="' + S(4.8) + '" fill="rgba(200,230,255,.25)" stroke="' + OUT + '" stroke-width="' + S(1.6) + '"/><circle cx="' + X(23) + '" cy="' + Y(15) + '" r="' + S(4.8) + '" fill="rgba(200,230,255,.25)" stroke="' + OUT + '" stroke-width="' + S(1.6) + '"/><path d="M' + X(15.8) + " " + Y(15) + "h" + S(2.4) + '" stroke="' + OUT + '" stroke-width="' + S(1.6) + '"/>';
      if (e === "scar") o += '<path d="M' + X(25) + " " + Y(9) + "l" + S(4) + " " + S(10) + "M" + X(25.5) + " " + Y(12) + "l" + S(2.5) + " " + S(-1) + "M" + X(27) + " " + Y(15.5) + "l" + S(2.5) + " " + S(-1) + '" stroke="#9a4a3a" stroke-width="' + S(1.3) + '" stroke-linecap="round"/>';
      if (e === "cigar") o += '<rect x="' + X(20) + '" y="' + Y(24) + '" width="' + S(10) + '" height="' + S(2.6) + '" rx="' + S(1) + '" fill="#8a5a2b" stroke="' + OUT + '" stroke-width="' + S(1) + '"/><circle cx="' + X(30.5) + '" cy="' + Y(25.3) + '" r="' + S(1.3) + '" fill="#ff8a3d"/>';
      if (e === "earpiece") o += '<path d="M' + X(34) + " " + Y(15) + "q" + S(3) + " " + S(6) + " " + S(0) + " " + S(14) + '" fill="none" stroke="#c9d4e2" stroke-width="' + S(1.3) + '"/>';
      if (e === "bandana") o += '<path d="M' + X(0) + " " + Y(21) + "h" + S(34) + "v" + S(6) + "q" + S(-8) + " " + S(10) + " " + S(-17) + " " + S(10) + "q" + S(-9) + " 0 " + S(-17) + ' -10z" fill="' + (p.bandanaColor || "#3b3b46") + '" stroke="' + OUT + '" stroke-width="' + S(1.6) + '" stroke-linejoin="round"/>';
    });
    return o;
  }

  function portrait(p) {
    p = p || {};
    var skin = p.skin || "#f2c9a0", hx = 15, hy = 11, k = 34, o = "";
    o += '<path d="M5 64v-9q0-9 9-9h36q9 0 9 9v9z" fill="' + (p.shirt || "#3d6fb6") + '" stroke="' + OUT + '" stroke-width="2" stroke-linejoin="round"/>';
    if (p.collar) o += '<path d="M25 46l7 8 7-8z" fill="' + p.collar + '" stroke="' + OUT + '" stroke-width="1.6" stroke-linejoin="round"/>';
    if (p.buttons) o += '<circle cx="32" cy="58" r="1.6" fill="' + p.buttons + '"/><circle cx="32" cy="63" r="1.6" fill="' + p.buttons + '"/>';
    o += hatSvg(p, hx, hy, k, "back");
    o += '<rect x="27" y="40" width="10" height="8" fill="' + skin + '" stroke="' + OUT + '" stroke-width="2"/>';
    o += '<rect x="' + hx + '" y="' + hy + '" width="' + k + '" height="' + (k - 1) + '" rx="6" fill="' + skin + '" stroke="' + OUT + '" stroke-width="2"/>';
    o += face(p, hx, hy, k);
    o += beardSvg(p, hx, hy, k);
    o += extrasSvg(p, hx, hy, k);
    o += hatSvg(p, hx, hy, k, "front");
    return o;
  }

  /* A whole standing figure: legs, torso, arms and a big blocky head. Feet rest at y=14. */
  function figure(p) {
    p = p || {};
    var skin = p.skin || "#f2c9a0", shirt = p.shirt || "#3d6fb6", pants = p.pants || "#26324a", o = "";
    var big = p.build === "big", slim = p.build === "slim";
    var tw = big ? 22 : slim ? 14 : 18, tx = -tw / 2;
    o += '<ellipse cx="0" cy="14.5" rx="' + (tw / 2 + 4) + '" ry="3" fill="rgba(0,0,0,.35)"/>';
    o += '<rect x="' + (tx + 1) + '" y="2" width="' + (tw / 2 - 1.5) + '" height="12" rx="1.5" fill="' + pants + '" stroke="' + OUT + '" stroke-width="1.6"/>';
    o += '<rect x="' + 0.5 + '" y="2" width="' + (tw / 2 - 1.5) + '" height="12" rx="1.5" fill="' + pants + '" stroke="' + OUT + '" stroke-width="1.6"/>';
    var aw = big ? 7 : 5.5;
    o += '<rect x="' + (tx - aw + 0.5) + '" y="-12" width="' + aw + '" height="13" rx="2" fill="' + (p.sleeves || shirt) + '" stroke="' + OUT + '" stroke-width="1.6"/>';
    o += '<rect x="' + (-tx - 0.5) + '" y="-12" width="' + aw + '" height="13" rx="2" fill="' + (p.sleeves || shirt) + '" stroke="' + OUT + '" stroke-width="1.6"/>';
    o += '<rect x="' + (tx - aw + 1) + '" y="0" width="' + (aw - 1) + '" height="3.5" rx="1.5" fill="' + skin + '" stroke="' + OUT + '" stroke-width="1.2"/>';
    o += '<rect x="' + (-tx) + '" y="0" width="' + (aw - 1) + '" height="3.5" rx="1.5" fill="' + skin + '" stroke="' + OUT + '" stroke-width="1.2"/>';
    o += '<rect x="' + tx + '" y="-13" width="' + tw + '" height="16" rx="2.5" fill="' + shirt + '" stroke="' + OUT + '" stroke-width="1.8"/>';
    if (p.belt) o += '<rect x="' + tx + '" y="0" width="' + tw + '" height="3" fill="' + p.belt + '"/>';
    if (p.stripe) o += '<rect x="' + tx + '" y="-7" width="' + tw + '" height="3.5" fill="' + p.stripe + '"/>';
    if (p.collar) o += '<path d="M-3.5 -13l3.5 4 3.5-4z" fill="' + p.collar + '" stroke="' + OUT + '" stroke-width="1.2" stroke-linejoin="round"/>';
    var k = 24, hx = -12, hy = -37;
    o += hatSvg(p, hx, hy, k, "back");
    o += '<rect x="' + hx + '" y="' + hy + '" width="' + k + '" height="' + (k - 1) + '" rx="4" fill="' + skin + '" stroke="' + OUT + '" stroke-width="1.8"/>';
    o += face(p, hx, hy, k);
    o += beardSvg(p, hx, hy, k);
    o += extrasSvg(p, hx, hy, k);
    o += hatSvg(p, hx, hy, k, "front");
    if (p.prop) o += p.prop;
    return o;
  }

  /* Small seeded RNG so bots can be varied but testable. */
  function rng(seed) {
    var a = (seed >>> 0) || 0x9e3779b9;
    return function () {
      a |= 0; a = (a + 0x6D2B79F5) | 0;
      var t = Math.imul(a ^ (a >>> 15), 1 | a);
      t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
      return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
    };
  }

  root.Kit = {
    $: $, $all: $all, h: h, s: s, store: store, sleep: sleep, frame: frame, Sound: Sound, haptic: haptic,
    blocky: { portrait: portrait, figure: figure, OUT: OUT },
    cover: cover, modal: modal, banner: banner, toast: toast, shake: shake, init: init, showScreen: showScreen,
    showRules: showRules, openMenu: openMenu, confirm: confirmAsk, quit: quit, gameOver: gameOver, ICONS: ICONS, rng: rng,
    get reduceMotion() { return reduceMotion; },
    get choice() { return choice; }
  };
})(typeof window !== "undefined" ? window : globalThis);
