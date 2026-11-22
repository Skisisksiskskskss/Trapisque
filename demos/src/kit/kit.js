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
    cover: cover, modal: modal, banner: banner, toast: toast, shake: shake, init: init, showScreen: showScreen,
    showRules: showRules, openMenu: openMenu, confirm: confirmAsk, quit: quit, gameOver: gameOver, ICONS: ICONS, rng: rng,
    get reduceMotion() { return reduceMotion; },
    get choice() { return choice; }
  };
})(typeof window !== "undefined" ? window : globalThis);
