/* Trapisque Tools: the four tabs (Game, Dice, Wheels, Rules), the sheets and the app plumbing. */
(function () {
  'use strict';

  var D = window.TQ_DATA;
  var L = window.TQ_LOGIC;
  var FAM = D.FAMILIES;

  var STORE_KEY = 'trapisque-tools:v1';
  var TABS = ['game', 'dice', 'wheels', 'rules'];
  var motion = window.matchMedia('(prefers-reduced-motion: reduce)');
  var reduced = function () { return motion.matches; };
  // Embedded copies (inside another page, or a host that sets TQ_EMBEDDED) can't be installed or work offline.
  var inFrame = window.TQ_EMBEDDED === true ||
    (function () { try { return window.self !== window.top; } catch (e) { return true; } })();
  var standalone = window.navigator.standalone === true || window.matchMedia('(display-mode: standalone)').matches;
  var isIOS = /iPad|iPhone|iPod/.test(navigator.userAgent) ||
    (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1);

  /* ---------- small helpers ---------- */

  function $(sel, root) { return (root || document).querySelector(sel); }
  function $$(sel, root) { return Array.prototype.slice.call((root || document).querySelectorAll(sel)); }
  var ESC = { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' };
  function esc(v) { return String(v).replace(/[&<>"']/g, function (c) { return ESC[c]; }); }
  function plural(n, one, many) { return n + ' ' + (n === 1 ? one : (many || one + 's')); }
  function joinNames(list) {
    if (list.length < 2) return list.join('');
    return list.slice(0, -1).join(', ') + ' and ' + list[list.length - 1];
  }
  function clamp(n, lo, hi) { return Math.max(lo, Math.min(hi, n)); }
  function focusQuietly(el) { if (el && el.focus) { try { el.focus({ preventScroll: true }); } catch (e) { el.focus(); } } }

  function ico(body) { return '<svg class="ico" viewBox="0 0 24 24" aria-hidden="true">' + body + '</svg>'; }
  var ICON = {
    chevron: ico('<path d="m9 6 6 6-6 6"/>'),
    down: ico('<path d="m6 9 6 6 6-6"/>'),
    plus: ico('<path d="M12 5v14M5 12h14"/>'),
    minus: ico('<path d="M5 12h14"/>'),
    close: ico('<path d="M6 6l12 12M18 6 6 18"/>'),
    check: ico('<path d="m5 12.5 4.5 4.5L19 7.5"/>'),
    next: ico('<path d="M5 12h14M13 6l6 6-6 6"/>'),
    die: ico('<rect x="3.5" y="3.5" width="17" height="17" rx="4.5"/><circle class="fill" cx="8.6" cy="8.6" r="1.5"/><circle class="fill" cx="12" cy="12" r="1.5"/><circle class="fill" cx="15.4" cy="15.4" r="1.5"/>'),
  };
  var PAWN = '<svg viewBox="0 0 24 24" aria-hidden="true"><circle cx="12" cy="6.2" r="3.5"/><path d="M9.1 10.4h5.8l2 7.6H7.1z"/><rect x="5.2" y="17.6" width="13.6" height="3.6" rx="1.8"/></svg>';

  /* ---------- state ---------- */

  function freshState() {
    return {
      v: 1,
      tab: 'game',
      game: L.sampleGame(),
      actor: null, // null: whoever's turn it is; 'none': free roll; or a player id
      dice: { mode: 'move', boost: false, half: false, last: null, history: [] },
      wheel: { family: 'trap', last: null },
      prefs: { hintClosed: false, awake: false },
    };
  }

  function loadState() {
    var base = freshState();
    var saved = null;
    try { saved = JSON.parse(localStorage.getItem(STORE_KEY) || 'null'); } catch (e) { saved = null; }
    if (!saved || saved.v !== 1) return base;
    var game = base.game;
    if (saved.game === null) game = null;
    else if (saved.game && Array.isArray(saved.game.players) && saved.game.players.length > 1) game = saved.game;
    var dice = Object.assign(base.dice, saved.dice || {});
    if (!Array.isArray(dice.history)) dice.history = [];
    return {
      v: 1,
      tab: TABS.indexOf(saved.tab) >= 0 ? saved.tab : 'game',
      game: game,
      actor: typeof saved.actor === 'string' ? saved.actor : null,
      dice: dice,
      wheel: Object.assign(base.wheel, saved.wheel || {}),
      prefs: Object.assign(base.prefs, saved.prefs || {}),
    };
  }

  var state = loadState();
  var saveTimer = 0;

  function saveNow() {
    clearTimeout(saveTimer);
    try { localStorage.setItem(STORE_KEY, JSON.stringify(state)); } catch (e) { /* storage blocked: keep playing in memory */ }
  }
  function save() {
    clearTimeout(saveTimer);
    saveTimer = setTimeout(saveNow, 150);
  }
  document.addEventListener('visibilitychange', function () { if (document.visibilityState === 'hidden') saveNow(); });
  window.addEventListener('pagehide', saveNow);

  // Undo keeps snapshots of the game (plus the wheel result, which can point into it).
  var undoStack = [];
  function snapshot() { return JSON.stringify({ game: state.game, wheelLast: state.wheel.last, actor: state.actor }); }
  function restore(snap) {
    var s = JSON.parse(snap);
    state.game = s.game;
    state.wheel.last = s.wheelLast;
    state.actor = s.actor;
  }

  // Every change to the game goes through here. Return false from fn when nothing changed.
  function change(fn, opts) {
    opts = opts || {};
    var track = opts.undo !== false && !!state.game;
    if (track) {
      undoStack.push(snapshot());
      if (undoStack.length > 60) undoStack.shift();
    }
    var out = fn(state.game, state);
    if (out === false && track) undoStack.pop();
    save();
    render();
    return out;
  }

  function undo() {
    if (!undoStack.length) return;
    restore(undoStack.pop());
    save();
    render();
    toast('Undid the last change');
  }

  function log(g, text) {
    g.log.push({ r: g.round, t: Date.now(), text: text });
    if (g.log.length > 100) g.log.splice(0, g.log.length - 100);
  }

  function logEvents(g, events) {
    events.forEach(function (e) {
      var p = L.player(g, e.pid);
      if (!p) return;
      if (e.type === 'skip') log(g, p.name + ' was snared and skipped a turn');
      if (e.type === 'recharged') log(g, p.name + "'s " + charOf(p).name + ' ability is ready again');
    });
  }

  /* ---------- lookups ---------- */

  function charOf(p) { return L.character(p.character) || D.CHARACTERS[0]; }
  function current() { return state.game ? state.game.players[state.game.turn] : null; }
  function actor() {
    var g = state.game;
    if (!g || state.actor === 'none') return null;
    return (state.actor && L.player(g, state.actor)) || current();
  }
  function mapId() { return state.game ? state.game.map : 'blissful'; }
  function item(id) { return L.itemView(id, mapId()); }
  function activeStatuses(p) { return D.STATUSES.filter(function (s) { return p.status[s.id]; }); }

  /* ---------- shared markup ---------- */

  function pawn(p, size) {
    return '<span class="pawn' + (size ? ' ' + size : '') + '" style="--pawn: var(--pawn-' + ((p.color || 0) % 6) + ')">' + PAWN + '</span>';
  }
  function statusChip(s) { return '<span class="chip status">' + s.icon + ' ' + esc(s.name) + '</span>'; }

  function abilityChip(g, p) {
    var a = L.abilityInfo(g, p);
    if (a.state === 'ready') return '<span class="chip ready">Ability ready</span>';
    if (a.state === 'always') return '<span class="chip ready">Ability: no cooldown</span>';
    if (a.state === 'cooldown') return '<span class="chip">Ability back in ' + plural(a.left, a.unit) + '</span>';
    if (a.state === 'spent') return '<span class="chip">Ability used</span>';
    return '';
  }

  function handChip(p) {
    if (!p.items.length) return '';
    var shown = p.items.slice(0, p.items.length > 4 ? 3 : 4).map(function (id) { return item(id).icon; }).join('');
    var more = p.items.length > 4 ? ' +' + (p.items.length - 3) : '';
    return '<span class="chip" aria-label="' + plural(p.items.length, 'item card') + '">' + shown + more + '</span>';
  }

  function winnerText(g, w) {
    if (w.kind === 'player') {
      var p = L.player(g, w.id);
      return { title: (p ? p.name : 'A player') + ' wins!', detail: 'First to ' + plural(g.target, 'treasure') + ' · Round ' + w.round };
    }
    var t = L.teams(g)[w.id];
    var names = t.members.map(function (m) { return m.name; });
    return {
      title: t.name + ' wins!',
      detail: joinNames(names) + ' each reached the treasure ' + plural(g.target, 'time') + ' · Round ' + w.round,
    };
  }

  /* ---------- tabs ---------- */

  var scrollMemo = {};

  function setTab(tab) {
    if (TABS.indexOf(tab) < 0) tab = 'game';
    var view = $('#view-' + tab);
    if (tab === state.tab && !view.hidden) {
      window.scrollTo({ top: 0, behavior: reduced() ? 'auto' : 'smooth' });
      return;
    }
    scrollMemo[state.tab] = window.scrollY;
    state.tab = tab;
    save();
    TABS.forEach(function (t) { $('#view-' + t).hidden = t !== tab; });
    renderTabs();
    window.scrollTo(0, scrollMemo[tab] || 0);
    syncNav(view);
  }

  function renderTabs() {
    $$('.tab').forEach(function (b) {
      if (b.dataset.tab === state.tab) b.setAttribute('aria-current', 'page');
      else b.removeAttribute('aria-current');
    });
  }

  /* ---------- game tab ---------- */

  function renderGame() {
    var g = state.game;
    var body = $('#game-body');
    $('#game-undo').disabled = !g || !undoStack.length;
    if (!g) {
      $('#game-sub').textContent = 'No game in progress';
      body.innerHTML = installBanner() + emptyGame();
      return;
    }
    var m = L.mode(g.mode);
    $('#game-sub').textContent = m.name + ' · ' + L.map(g.map).name + ' · Round ' + g.round;
    body.innerHTML = [
      installBanner(),
      g.sample ? sampleBanner() : '',
      g.winner ? winnerBanner(g) : '',
      turnCard(g),
      m.teams ? L.teams(g).map(function (t) { return teamSection(g, t); }).join('') : playersSection(g),
      logSection(g),
    ].join('');
  }

  function installBanner() {
    if (!isIOS || standalone || inFrame || state.prefs.hintClosed) return '';
    return '<div class="banner plain"><div class="row-text"><b>Add Trapisque to your Home Screen</b>' +
      '<span class="sub">Tap Share, then Add to Home Screen. It opens full screen and works offline.</span></div>' +
      '<button class="icon-btn" data-act="close-hint" aria-label="Dismiss">' + ICON.close + '</button></div>';
  }

  function sampleBanner() {
    return '<div class="banner"><div class="row-text"><b>This is a sample game</b>' +
      '<span class="sub">Ava, Ben and Cleo are example players. Start a game with your own group.</span></div>' +
      '<button class="btn btn-gold btn-sm" data-act="new-game">New game</button></div>';
  }

  function winnerBanner(g) {
    var t = winnerText(g, g.winner);
    return '<div class="banner"><span class="trophy" aria-hidden="true">🏆</span><div class="row-text"><b>' + esc(t.title) + '</b>' +
      '<span class="sub">' + esc(t.detail) + '</span></div>' +
      '<button class="btn btn-gold btn-sm" data-act="new-game">New game</button></div>';
  }

  function emptyGame() {
    var pawns = [0, 1, 2].map(function (i) { return pawn({ color: i }, 'lg'); }).join('');
    return '<div class="empty card"><div class="pawn-row" aria-hidden="true">' + pawns + '</div>' +
      '<h2>No game in progress</h2>' +
      '<p>Add your players and characters to track treasures, turns, statuses and item cards.</p>' +
      '<button class="btn btn-gold btn-block" data-act="new-game">New game</button>' +
      '<button class="btn btn-block" data-act="load-sample">Show the sample game</button></div>';
  }

  function turnCard(g) {
    var p = g.players[g.turn];
    var c = charOf(p);
    var statuses = activeStatuses(p);
    var n = g.players.length;
    var next = [];
    for (var k = 1; k < Math.min(n, 4); k++) next.push(g.players[(g.turn + k) % n]);
    return '<section class="turn card" aria-labelledby="turn-name">' +
      '<div class="turn-head">' + pawn(p, 'lg') + '<div class="row-text">' +
        '<span class="eyebrow">Round ' + g.round + ' · Now playing</span>' +
        '<h2 class="turn-name" id="turn-name">' + esc(p.name) + '</h2>' +
        '<span class="sub">' + c.icon + ' ' + esc(c.name) + '</span>' +
      '</div></div>' +
      (statuses.length ? '<div class="chips">' + statuses.map(statusChip).join('') + '</div>' : '') +
      '<div class="turn-actions">' +
        '<button class="btn" data-act="go-dice">' + ICON.die + 'Roll</button>' +
        '<button class="btn btn-gold" data-act="next-turn">Next turn' + ICON.next + '</button>' +
      '</div>' +
      (next.length ? '<div class="turn-next"><span class="eyebrow">Up next</span>' + next.map(function (x) {
        return '<span>' + pawn(x, 'xs') + esc(x.name) + (x.status.snared ? ' <em>skips</em>' : '') + '</span>';
      }).join('') + '</div>' : '') +
    '</section>';
  }

  function playersSection(g) {
    return '<section aria-labelledby="players-title"><div class="section-head"><h2 class="section-title" id="players-title">Players</h2>' +
      '<span class="section-note">Tap a player for more</span></div>' +
      '<div class="players">' + g.players.map(function (p) { return playerCard(g, p); }).join('') + '</div></section>';
  }

  function teamSection(g, t) {
    var total = t.members.reduce(function (s, p) { return s + Math.min(p.treasures, g.target); }, 0);
    var max = g.target * t.members.length;
    var won = !!(g.winner && g.winner.kind === 'team' && g.winner.id === t.id);
    var pct = max ? (100 * total / max).toFixed(1) : 0;
    return '<section class="team-block' + (won ? ' won' : '') + '" aria-label="' + t.name + '">' +
      '<div class="section-head"><h2 class="section-title">' + t.name + (won ? ' <span class="pill pill-done">Winner</span>' : '') + '</h2>' +
      '<span class="section-note">' + total + ' of ' + max + ' treasures</span></div>' +
      '<div class="bar" aria-hidden="true"><i style="width:' + pct + '%"></i></div>' +
      '<div class="players">' + t.members.map(function (p) { return playerCard(g, p); }).join('') + '</div></section>';
  }

  function pips(n, target) {
    var out = '';
    for (var i = 0; i < target; i++) out += '<i class="' + (i < n ? 'on' : '') + '"></i>';
    return '<span class="pips" aria-hidden="true">' + out + '</span>';
  }

  function playerCard(g, p) {
    var c = charOf(p);
    var now = g.players[g.turn] === p;
    var done = L.isDone(g, p);
    var tags = activeStatuses(p).map(statusChip).join('') + abilityChip(g, p) + handChip(p);
    return '<article class="player card' + (now ? ' is-now' : '') + '">' +
      '<button class="player-main" data-act="open-player" data-id="' + p.id + '">' + pawn(p) +
        '<span class="player-id"><strong>' + esc(p.name) + '</strong><span>' + c.icon + ' ' + esc(c.name) + '</span></span>' +
        (now ? '<span class="pill pill-now">Now</span>' : done ? '<span class="pill pill-done">Done</span>' : '') +
        '<span class="chev">' + ICON.chevron + '</span>' +
      '</button>' +
      '<div class="player-treasure">' + pips(p.treasures, g.target) +
        '<span class="count"><b>' + p.treasures + '</b>/' + g.target + '<span class="sr"> treasures</span></span>' +
        '<button class="btn btn-gold btn-sm" data-act="treasure" data-id="' + p.id + '"' + (done ? ' disabled' : '') +
          ' aria-label="' + esc(p.name) + ' reached the treasure">+1</button>' +
      '</div>' +
      (tags ? '<div class="chips">' + tags + '</div>' : '') +
    '</article>';
  }

  function logSection(g) {
    var entries = g.log.slice(-8).reverse();
    if (!entries.length) return '';
    return '<section aria-labelledby="log-title"><div class="section-head"><h2 class="section-title" id="log-title">Recent</h2></div>' +
      '<ol class="list log">' + entries.map(function (e) {
        return '<li class="row"><span class="round-tag" title="Round ' + e.r + '">R' + e.r + '</span><span class="row-text">' + esc(e.text) + '</span></li>';
      }).join('') + '</ol></section>';
  }

  function treasure(id, delta) {
    var res = null;
    change(function (g) {
      var p = L.player(g, id);
      if (!p) return false;
      res = L.changeTreasure(g, id, delta);
      if (!res.changed) return false;
      if (delta > 0) log(g, p.name + ' reached the treasure (' + p.treasures + '/' + g.target + ')');
      else log(g, p.name + ' is back to ' + p.treasures + '/' + g.target + ' treasures');
      logEvents(g, res.events);
    });
    if (res && res.win) celebrate(res.win);
  }

  function nextTurn() {
    var events = [];
    change(function (g, s) {
      events = L.nextTurn(g);
      s.actor = null;
      logEvents(g, events);
    });
    var g = state.game;
    var skipped = events.filter(function (e) { return e.type === 'skip'; }).map(function (e) { return L.player(g, e.pid).name; });
    var p = current();
    toast(skipped.length ? joinNames(skipped) + ' skipped (snared). ' + p.name + "'s turn" : p.name + "'s turn");
  }

  function endGame() {
    var snap = snapshot();
    state.game = null;
    state.actor = null;
    undoStack.length = 0;
    save();
    render();
    toast('Game ended', { label: 'Undo', run: function () { restore(snap); save(); render(); } });
  }

  function openMenu() {
    var items = [{ label: 'New game', run: openSetup }];
    if ('wakeLock' in navigator) {
      items.push({ label: state.prefs.awake ? 'Let the screen sleep' : 'Keep the screen on', run: toggleAwake });
    }
    if (state.game) items.push({ label: state.game.sample ? 'Clear the sample game' : 'End game', destructive: true, run: endGame });
    actionSheet('Game', items);
  }

  /* ---------- player sheet ---------- */

  function openPlayer(id) {
    openSheet({
      id: 'player',
      title: function () { var p = state.game && L.player(state.game, id); return p ? p.name : ''; },
      body: function () { return playerBody(id); },
    });
  }

  function playerBody(id) {
    var g = state.game;
    var p = g && L.player(g, id);
    if (!p) return null;
    var c = charOf(p);
    var a = L.abilityInfo(g, p);
    var cyc = L.cycleOf(g, p);
    var now = g.players[g.turn] === p;
    var team = p.team != null ? ' · ' + L.teamName(p.team) : '';

    var abilityState = {
      ready: '<span class="chip ready">Ready</span>',
      always: '<span class="chip ready">No cooldown</span>',
      cooldown: '<span class="chip">Back in ' + plural(a.left || 1, a.unit || 'round') + '</span>',
      spent: '<span class="chip">Used</span>',
    }[a.state] || '';
    var abilityButton = '';
    if (a.state === 'ready' || a.state === 'always') {
      abilityButton = '<button class="btn btn-gold btn-sm" data-act="use-ability" data-id="' + p.id + '">Use ability</button>';
    } else if (a.state === 'cooldown' || a.state === 'spent') {
      abilityButton = '<button class="btn btn-sm" data-act="regen" data-id="' + p.id + '">Recharge now</button>';
    }

    var hand = p.items.map(function (iid, k) {
      var v = L.itemView(iid, g.map);
      return '<div class="row item-row"><span class="token token-' + v.family + '" aria-hidden="true">' + v.icon + '</span>' +
        '<span class="row-text"><b>' + esc(v.name) + '</b><span class="sub clamp">' + esc(v.effect) + '</span></span>' +
        '<button class="btn btn-sm" data-act="use-item" data-id="' + p.id + '" data-index="' + k + '">Use</button>' +
        '<button class="icon-btn sm" data-act="drop-item" data-id="' + p.id + '" data-index="' + k + '" aria-label="Discard ' + esc(v.name) + '">' + ICON.close + '</button></div>';
    }).join('');

    return '<div class="ps-hero">' + pawn(p, 'xl') + '<div class="row-text"><h3>' + esc(p.name) + '</h3>' +
        '<span class="sub">' + c.icon + ' ' + esc(c.name) + team + '</span></div>' +
        (now ? '<span class="pill pill-now">Now</span>' : '') + '</div>' +

      '<section class="group"><h4 class="group-title">Treasures</h4>' +
        '<div class="list"><div class="row big-stepper">' +
          '<button class="round-btn" data-act="treasure-minus" data-id="' + p.id + '"' + (p.treasures <= 0 ? ' disabled' : '') + ' aria-label="Take away a treasure">' + ICON.minus + '</button>' +
          '<span class="count" aria-live="polite"><b>' + p.treasures + '</b> of ' + g.target + '</span>' +
          '<button class="round-btn gold" data-act="treasure" data-id="' + p.id + '"' + (cyc.done ? ' disabled' : '') + ' aria-label="Add a treasure">' + ICON.plus + '</button>' +
        '</div></div>' +
        '<p class="group-foot">' + (cyc.done
          ? esc(p.name) + ' has finished all ' + g.target + ' cycles.'
          : 'Cycle ' + cyc.cycle + ' is ' + (cyc.even ? 'even' : 'odd') + ', so Shifting Sands move ' + esc(p.name) + ' ' + (cyc.even ? 'forward' : 'backward') + '.') + '</p>' +
      '</section>' +

      '<section class="group"><h4 class="group-title">Ability</h4>' +
        '<div class="list icons"><div class="row ability-row"><span class="token" aria-hidden="true">' + c.icon + '</span>' +
          '<span class="row-text"><b>' + esc(c.name) + '</b><span class="sub">' + esc(c.ability) + '</span><span class="fine">' + esc(c.recharge) + '</span></span></div>' +
          (a.state === 'passive' ? '' : '<div class="row"><span class="row-text"><span>' + abilityState + '</span></span>' + abilityButton + '</div>') + '</div>' +
      '</section>' +

      '<section class="group"><h4 class="group-title">Status</h4><div class="list icons">' +
        D.STATUSES.map(function (s) {
          return '<div class="row"><span class="token" aria-hidden="true">' + s.icon + '</span>' +
            '<span class="row-text"><b id="status-' + s.id + '">' + esc(s.name) + '</b><span class="sub">' + esc(s.hint) + '</span></span>' +
            '<button class="switch" role="switch" aria-checked="' + !!p.status[s.id] + '" aria-labelledby="status-' + s.id + '" data-act="status" data-id="' + p.id + '" data-key="' + s.id + '"></button></div>';
        }).join('') +
      '</div></section>' +

      '<section class="group"><h4 class="group-title">Item cards</h4><div class="list icons">' + hand +
        '<button class="row" data-act="add-item" data-id="' + p.id + '"><span class="token add" aria-hidden="true">' + ICON.plus + '</span><span class="row-text"><b>Add item card</b></span></button>' +
      '</div>' + (p.items.length ? '' : '<p class="group-foot">No cards yet. Spin a wheel when ' + esc(p.name) + ' lands on a token.</p>') + '</section>' +

      (now ? '' : '<button class="btn btn-block" data-act="make-turn" data-id="' + p.id + '">Make it ' + esc(p.name) + "'s turn</button>");
  }

  function useMessage(p, v, effect) {
    if (effect === 'shield') return p.name + ' is shielded from the next trap';
    if (effect === 'boost') return p.name + "'s next roll is doubled";
    if (effect === 'regen') return p.name + "'s ability is ready again";
    if (effect === 'regen-none') return 'The ' + charOf(p).name + ' has no ability to regenerate';
    if (v.id === 'teleporter') return 'Place it at least 8 tiles from the treasure';
    if (v.use) return v.use;
    return 'Place the ' + v.name + ' on the board';
  }

  function openItemPicker(pid) {
    openSheet({
      id: 'items',
      title: 'Add item card',
      done: 'Cancel',
      body: function () {
        var g = state.game;
        var p = g && L.player(g, pid);
        if (!p) return null;
        return '<div class="sheet-lead-row"><p class="sheet-lead">Pick the card ' + esc(p.name) + ' drew.</p>' +
            '<button class="btn btn-sm" data-act="spin-for" data-id="' + p.id + '">Spin a wheel</button></div>' +
          ['trap', 'assist', 'neutral'].map(function (f) {
            return '<section class="group"><h4 class="group-title">' + FAM[f].title + '</h4><div class="item-grid">' +
              L.itemsOf(f).map(function (i) {
                var v = L.itemView(i.id, g.map);
                return '<button class="item-tile" data-act="give-item" data-id="' + p.id + '" data-key="' + i.id + '">' +
                  '<span class="token token-' + f + '" aria-hidden="true">' + v.icon + '</span><span>' + esc(v.name) + '</span></button>';
              }).join('') + '</div></section>';
          }).join('');
      },
    });
  }

  /* ---------- new game sheet ---------- */

  var draft = null;

  function resizeDraft(n, names) {
    names = names || [];
    var ps = draft.players;
    while (ps.length > n) ps.pop();
    while (ps.length < n) {
      var usedColors = ps.map(function (p) { return p.color; });
      var usedChars = ps.map(function (p) { return p.character; });
      var color = [0, 1, 2, 3, 4, 5].filter(function (c) { return usedColors.indexOf(c) < 0; })[0];
      var free = L.shuffle(D.CHARACTERS.map(function (c) { return c.id; }).filter(function (id) { return usedChars.indexOf(id) < 0; }));
      ps.push({ name: names[ps.length] || '', character: free[0], color: color, team: null });
    }
    var teams = L.defaultTeams(draft.mode, n);
    ps.forEach(function (p, i) { p.team = teams[i]; });
  }

  function openSetup() {
    var g = state.game && !state.game.sample ? state.game : null;
    var modeId = g ? g.mode : 'chaos';
    var names = g ? g.players.slice().sort(function (a, b) { return a.color - b.color; }).map(function (p) { return p.name; }) : [];
    draft = { mode: modeId, map: g ? g.map : 'blissful', target: g ? g.target : L.mode(modeId).target, players: [] };
    resizeDraft(g ? g.players.length : 3, names);
    openSheet({ id: 'setup', title: 'New game', cancel: true, done: 'Start', tall: true, body: setupBody, onDone: startGame });
  }

  function stepper(act, value, min, max, label) {
    return '<div class="stepper" role="group" aria-label="' + label + '">' +
      '<button data-act="' + act + '" data-delta="-1"' + (value <= min ? ' disabled' : '') + ' aria-label="Fewer ' + label + '">' + ICON.minus + '</button>' +
      '<output aria-live="polite">' + value + '</output>' +
      '<button data-act="' + act + '" data-delta="1"' + (value >= max ? ' disabled' : '') + ' aria-label="More ' + label + '">' + ICON.plus + '</button></div>';
  }

  function radioRow(act, key, on, title, sub, extra) {
    extra = extra || {};
    return '<button class="row radio-row" role="radio" aria-checked="' + on + '" data-act="' + act + '" data-key="' + key + '">' +
      (extra.icon ? '<span class="token" aria-hidden="true">' + extra.icon + '</span>' : '') +
      '<span class="row-text"><b>' + esc(title) + (extra.tag ? ' <span class="tag">' + extra.tag + '</span>' : '') + '</b>' +
      '<span class="sub">' + esc(sub) + '</span></span><span class="check">' + (on ? ICON.check : '') + '</span></button>';
  }

  function setupBody() {
    if (!draft) return null;
    var m = L.mode(draft.mode);
    var problem = L.teamProblem(draft.mode, draft.players.map(function (p) { return p.team; }));
    return '<section class="group"><h3 class="group-title" id="setup-mode">Mode</h3>' +
        '<div class="list" role="radiogroup" aria-labelledby="setup-mode">' + D.MODES.map(function (x) {
          return radioRow('setup-mode', x.id, x.id === draft.mode, x.name, x.summary);
        }).join('') + '</div></section>' +

      '<section class="group"><h3 class="group-title" id="setup-map">Map</h3>' +
        '<div class="list icons" role="radiogroup" aria-labelledby="setup-map">' + D.MAPS.map(function (x) {
          return radioRow('setup-map', x.id, x.id === draft.map, x.name, x.blurb, { icon: x.icon, tag: x.available ? '' : 'Coming soon' });
        }).join('') + '</div></section>' +

      '<section class="group"><h3 class="group-title">Players</h3><div class="list">' +
        (m.min !== m.max ? '<div class="row"><span class="row-text"><b>Number of players</b><span class="sub">' + m.min + ' to ' + m.max + '</span></span>' +
          stepper('setup-count', draft.players.length, m.min, m.max, 'players') + '</div>' : '') +
        draft.players.map(function (p, i) {
          var c = L.character(p.character);
          var letter = p.team != null ? 'ABC'.charAt(p.team) : '';
          return '<div class="row setup-player">' + pawn(p, 'sm') +
            '<input class="name-input" id="setup-name-' + i + '" data-index="' + i + '" type="text" value="' + esc(p.name) + '" placeholder="Player ' + (i + 1) + '"' +
              ' maxlength="16" autocomplete="off" autocapitalize="words" enterkeyhint="next" aria-label="Name of player ' + (i + 1) + '">' +
            '<button class="char-btn" data-act="setup-char" data-index="' + i + '" aria-label="Character: ' + esc(c.name) + '. Change">' + c.icon + ' ' + esc(c.name) + '</button>' +
            (m.teams ? '<button class="team-btn" data-act="setup-team" data-index="' + i + '" aria-label="Team ' + letter + '. Change team">' + letter + '</button>' : '') +
          '</div>';
        }).join('') +
      '</div>' +
      (problem ? '<p class="group-foot error" role="alert">' + problem + ' Tap a team letter to move a player.</p>' : '') +
      '<div class="group-foot setup-tools"><button class="btn btn-sm" data-act="setup-redraw">Redraw characters</button>' +
        '<span>Players take turns in this order. The Overseer always goes first.</span></div></section>' +

      '<section class="group"><h3 class="group-title">Winning</h3><div class="list"><div class="row">' +
        '<span class="row-text"><b>Treasures to win</b><span class="sub">' + (m.win === 'first' ? 'The first player to reach it wins' : 'Every player on a team must reach it') + '</span></span>' +
        stepper('setup-target', draft.target, 1, 9, 'treasures') + '</div></div></section>' +

      '<button class="btn btn-gold btn-block" data-act="setup-start"' + (problem ? ' disabled' : '') + '>Start game</button>';
  }

  function openCharPicker(i) {
    openSheet({
      id: 'char',
      title: 'Character',
      body: function () {
        if (!draft || !draft.players[i]) return null;
        var me = draft.players[i];
        var label = function (k) { return draft.players[k].name || 'Player ' + (k + 1); };
        return '<p class="sheet-lead">For ' + esc(label(i)) + '. Each character can only be drawn once.</p><div class="list icons">' +
          D.CHARACTERS.map(function (c) {
            var holder = draft.players.findIndex(function (p) { return p.character === c.id; });
            var taken = holder >= 0 && holder !== i;
            return '<button class="row rule-row" data-act="setup-pick-char" data-index="' + i + '" data-key="' + c.id + '">' +
              '<span class="token" aria-hidden="true">' + c.icon + '</span><span class="row-text"><b>' + esc(c.name) +
              (taken ? ' <span class="tag">Swap with ' + esc(label(holder)) + '</span>' : '') + '</b>' +
              '<span class="sub">' + esc(c.ability) + '</span></span><span class="check">' + (me.character === c.id ? ICON.check : '') + '</span></button>';
          }).join('') + '</div>';
      },
    });
  }

  function startGame() {
    if (!draft) return;
    if (L.teamProblem(draft.mode, draft.players.map(function (p) { return p.team; }))) return;
    var spec = {
      mode: draft.mode,
      map: draft.map,
      target: draft.target,
      players: draft.players.map(function (p, i) {
        return { name: p.name.trim() || 'Player ' + (i + 1), character: p.character, team: p.team, color: p.color };
      }),
    };
    var go = function () {
      var g = L.createGame(spec);
      log(g, L.mode(g.mode).name + ' on ' + L.map(g.map).name + ' started');
      var first = g.players[0];
      if (charOf(first).goesFirst) log(g, first.name + ' goes first as the Overseer');
      g.players.forEach(function (p) {
        if (charOf(p).startItems && p.items.length) {
          log(g, p.name + ' starts with ' + joinNames(p.items.map(function (id) { return L.itemView(id, g.map).name; })));
        }
      });
      undoStack.length = 0;
      state.game = g;
      state.actor = null;
      state.wheel.last = null;
      state.dice.last = null;
      state.dice.history = [];
      draft = null;
      closeSheet('char', true);
      closeSheet('setup');
      saveNow();
      setTab('game');
      window.scrollTo(0, 0);
      render();
      toast(first.name + ' goes first');
    };
    var old = state.game;
    if (old && !old.sample && !old.winner) {
      confirmBox({ title: 'Start a new game?', message: 'The game in progress will be replaced.', confirm: 'Start new game', destructive: true })
        .then(function (ok) { if (ok) go(); });
    } else {
      go();
    }
  }

  /* ---------- dice tab ---------- */

  var rolling = false;
  var FACE_TURN = { 1: [0, 0], 2: [0, -90], 3: [-90, 0], 4: [90, 0], 5: [0, 90], 6: [0, 180] };
  var dieTurn = { x: 0, y: 0 };
  var STEP_LABEL = { boost: '×2 Speed Boost', half: '÷2 Ice', 'half-odd': '−1 Ice (odd roll)' };

  function nextAngle(from, target, spins) {
    var m = ((target % 360) + 360) % 360;
    var a = Math.floor(from / 360) * 360 + m;
    if (a < from) a += 360;
    return a + 360 * spins;
  }

  function showFace(n, spins) {
    var t = FACE_TURN[n] || FACE_TURN[1];
    dieTurn.x = nextAngle(dieTurn.x, t[0], spins ? spins[0] : 0);
    dieTurn.y = nextAngle(dieTurn.y, t[1], spins ? spins[1] : 0);
    $('#die').style.transform = 'rotateX(' + dieTurn.x + 'deg) rotateY(' + dieTurn.y + 'deg)';
  }

  function tumble(n) {
    return new Promise(function (resolve) {
      var die = $('#die');
      var stage = $('#die-stage');
      if (reduced()) {
        die.style.transition = 'none';
        showFace(n);
        resolve();
        return;
      }
      die.style.transition = '';
      stage.classList.remove('hop');
      void stage.offsetWidth;
      stage.classList.add('hop');
      showFace(n, [1 + L.randomInt(2), 1 + L.randomInt(2)]);
      setTimeout(resolve, 1050);
    });
  }

  function autoMods(a) { return { boost: !!(a && a.status.boost), half: !!(a && a.status.frozen) }; }

  function roll() {
    if (rolling) return;
    var a = actor();
    var mode = state.dice.mode;
    var value = L.rollDie();
    var entry;
    if (mode === 'move') {
      var auto = autoMods(a);
      var res = L.moveFor(value, { boost: state.dice.boost || auto.boost, half: state.dice.half || auto.half });
      entry = { mode: mode, roll: value, value: res.value, steps: res.steps };
    } else {
      entry = { mode: mode, roll: value, value: value, ok: L.passes(mode, value), steps: [] };
    }
    entry.pid = a ? a.id : null;
    entry.name = a ? a.name : null;
    entry.color = a ? a.color : null;
    entry.t = Date.now();

    rolling = true;
    $('#dice-readout').classList.add('is-rolling');
    $('#roll-btn').disabled = true;
    tumble(value).then(function () {
      rolling = false;
      $('#dice-readout').classList.remove('is-rolling');
      $('#roll-btn').disabled = false;
      change(function (g, s) {
        s.dice.last = entry;
        s.dice.history.unshift(entry);
        if (s.dice.history.length > 12) s.dice.history.length = 12;
        if (mode === 'move') { s.dice.boost = false; s.dice.half = false; }
        var p = g && entry.pid ? L.player(g, entry.pid) : null;
        if (p) {
          if (mode === 'move' && p.status.boost) p.status.boost = false;
          log(g, rollText(p, entry));
        }
      }, { undo: false });
    });
  }

  function rollText(p, e) {
    if (e.mode === 'grog') return p.name + ' rolled ' + e.roll + ' against the Grog and ' + (e.ok ? 'escaped' : 'was caught');
    if (e.mode === 'wall') return p.name + ' rolled ' + e.roll + ' at the wall and ' + (e.ok ? 'got over' : 'was stopped');
    if (e.steps.length) return p.name + ' rolled ' + e.roll + ' and moves ' + plural(e.value, 'tile');
    return p.name + ' rolled ' + e.roll;
  }

  function renderDice() {
    var a = actor();
    var g = state.game;
    $('#dice-sub').textContent = g ? 'Round ' + g.round + ' · ' + current().name + "'s turn" : 'One six-sided die';
    $('#dice-actor').innerHTML = actorButton(a, 'Rolling for', 'Free roll');
    $$('#dice-mode button').forEach(function (b) { b.setAttribute('aria-pressed', String(b.dataset.mode === state.dice.mode)); });
    var mods = $('#dice-mods');
    mods.hidden = state.dice.mode !== 'move';
    mods.innerHTML = modsMarkup(a);
    if (!rolling) $('#dice-readout').innerHTML = readoutMarkup();
    $('#dice-history').innerHTML = historyMarkup();
    $('#roll-btn').textContent = { move: 'Roll', grog: 'Roll against the Grog', wall: 'Roll at the wall' }[state.dice.mode];
  }

  function actorButton(a, label, none) {
    if (!state.game) return '';
    return '<button class="actor" data-act="pick-actor">' +
      (a ? pawn(a, 'sm') : '<span class="pawn sm ghost">' + PAWN + '</span>') +
      '<span class="actor-text"><span class="eyebrow">' + label + '</span><b>' + (a ? esc(a.name) : none) + '</b></span>' +
      (a ? '<span class="actor-tags" aria-hidden="true">' + activeStatuses(a).map(function (s) { return s.icon; }).join('') + '</span>' : '') +
      '<span class="chev">' + ICON.down + '</span></button>';
  }

  function modsMarkup(a) {
    var auto = autoMods(a);
    function mod(id, icon, title, note) {
      var on = !!(state.dice[id] || auto[id]);
      var why = auto[id] ? (id === 'half' ? esc(a.name) + ' is Frozen' : esc(a.name) + ' has a Speed Boost') : note;
      return '<button class="mod" data-act="mod" data-mod="' + id + '" aria-pressed="' + on + '">' +
        '<span class="em" aria-hidden="true">' + icon + '</span><span><b>' + title + '</b><small>' + why + '</small></span></button>';
    }
    return mod('boost', '⚡', 'Speed Boost', 'Doubles the roll') + mod('half', '🧊', 'Ice or Slime', 'Halves it, odd rolls lose 1');
  }

  function readoutMarkup() {
    var e = state.dice.last;
    if (!e) return '<p class="readout-hint">Tap the die to roll</p>';
    var who = e.name ? '<span class="who">' + esc(e.name) + '</span>' : '';
    if (e.mode === 'move') {
      var math = ['Rolled ' + e.roll].concat(e.steps.map(function (s) { return STEP_LABEL[s.id] + ' = ' + s.value; })).join(' · ');
      return who + '<div class="readout"><span class="big">' + e.value + '</span><span class="unit">' + (e.value === 1 ? 'tile' : 'tiles') + '</span></div>' +
        '<p class="math">' + math + (e.value === 0 ? ' · no move this turn' : '') + '</p>';
    }
    var text = e.mode === 'grog' ? (e.ok ? 'Escapes the Grog' : 'Caught by the Grog') : (e.ok ? 'Over the wall' : 'Stopped at the wall');
    var need = e.mode === 'grog' ? 'Needs 4 or more' : 'Needs more than 4';
    return who + '<div class="readout verdict ' + (e.ok ? 'ok' : 'bad') + '"><span class="big">' + e.roll + '</span>' +
      '<span class="verdict-text">' + text + '</span></div><p class="math">' + need + '</p>';
  }

  function historyMarkup() {
    var h = state.dice.history;
    if (!h.length) return '';
    return '<div class="section-head"><h2 class="section-title">Recent rolls</h2><button class="btn-text small" data-act="clear-rolls">Clear</button></div>' +
      '<ol class="history">' + h.map(function (e) {
        var shown = e.mode === 'move' ? e.value : e.roll;
        var desc = (e.name ? e.name + ': ' : '') + (e.mode === 'move' ? 'rolled ' + e.roll + ', moves ' + e.value
          : (e.mode === 'grog' ? 'Grog check ' : 'Wall check ') + e.roll + (e.ok ? ', passed' : ', failed'));
        var cls = e.mode === 'move' ? '' : (e.ok ? ' ok' : ' bad');
        var style = e.color != null ? ' style="--pawn: var(--pawn-' + (e.color % 6) + ')"' : '';
        return '<li class="hist' + cls + '"' + style + ' title="' + esc(desc) + '"><span class="sr">' + esc(desc) + '</span><span aria-hidden="true">' + shown + '</span></li>';
      }).join('') + '</ol>';
  }

  /* ---------- wheels tab ---------- */

  var spinning = false;
  var wheelAngle = 0;
  var wheelKey = '';

  function setRotor(a) { $('#wheel-rotor').setAttribute('transform', 'rotate(' + a.toFixed(3) + ' 100 100)'); }

  function drawWheel(fam) {
    var items = L.itemsOf(fam).map(function (i) { return item(i.id); });
    var n = items.length;
    var seg = 360 / n;
    var R = 92;
    var C = 100;
    function at(deg, r) {
      var rad = deg * Math.PI / 180;
      return [(C + r * Math.sin(rad)).toFixed(2), (C - r * Math.cos(rad)).toFixed(2)];
    }
    var paths = '';
    var labels = '';
    var pegs = '';
    items.forEach(function (it, i) {
      var a0 = i * seg;
      var p0 = at(a0, R);
      var p1 = at(a0 + seg, R);
      var mid = (a0 + seg / 2).toFixed(2);
      paths += '<path class="' + (i % 2 ? 'seg-b' : 'seg-a') + '" d="M' + C + ' ' + C + 'L' + p0[0] + ' ' + p0[1] + 'A' + R + ' ' + R + ' 0 0 1 ' + p1[0] + ' ' + p1[1] + 'Z"/>';
      labels += '<g transform="rotate(' + mid + ' ' + C + ' ' + C + ')"><text class="seg-icon" x="' + C + '" y="' + (C - 70) + '">' + it.icon + '</text>' +
        '<text class="seg-name" x="' + C + '" y="' + (C - 50) + '">' + esc(it.name) + '</text></g>';
      var pg = at(a0, R);
      pegs += '<circle class="peg" cx="' + pg[0] + '" cy="' + pg[1] + '" r="2.6"/>';
    });
    $('#wheel-svg').setAttribute('data-family', fam);
    $('#wheel-rotor').innerHTML = '<circle class="rim" cx="' + C + '" cy="' + C + '" r="' + (R + 5) + '"/>' + paths +
      '<circle class="ring" cx="' + C + '" cy="' + C + '" r="' + R + '"/>' + labels + pegs;
    setRotor(wheelAngle);
  }

  function spin() {
    if (spinning) return;
    var fam = state.wheel.family;
    var items = L.itemsOf(fam);
    var n = items.length;
    var seg = 360 / n;
    var pick = L.randomInt(n);
    // Land somewhere inside the chosen segment, clear of the pegs.
    var inside = (0.2 + Math.random() * 0.6) * seg;
    var want = ((-(pick * seg + inside)) % 360 + 360) % 360;
    var from = wheelAngle;
    var to = Math.floor(from / 360) * 360 + want;
    if (to <= from) to += 360;
    var quick = reduced();
    to += 360 * (quick ? 0 : 4 + L.randomInt(2));
    var duration = quick ? 300 : 4200 + Math.random() * 700;
    var a = actor();
    var pointer = $('#wheel-pointer');

    spinning = true;
    $('#spin-btn').disabled = true;
    $('#wheel-result').innerHTML = '<p class="readout-hint">Spinning…</p>';
    var start = performance.now();
    var lastPeg = Math.floor(from / seg);

    function frame(now) {
      var t = Math.min(1, (now - start) / duration);
      var eased = 1 - Math.pow(1 - t, 4);
      var ang = from + (to - from) * eased;
      setRotor(ang);
      var peg = Math.floor(ang / seg);
      if (peg !== lastPeg && !quick) {
        lastPeg = peg;
        pointer.classList.remove('tick');
        void pointer.getBoundingClientRect();
        pointer.classList.add('tick');
      }
      if (t < 1) { requestAnimationFrame(frame); return; }
      wheelAngle = ((to % 360) + 360) % 360;
      setRotor(wheelAngle);
      spinning = false;
      $('#spin-btn').disabled = false;
      var won = items[pick];
      change(function (g, s) {
        s.wheel.last = { family: fam, item: won.id, pid: a ? a.id : null, given: null, t: Date.now() };
        var p = g && a ? L.player(g, a.id) : null;
        if (p) log(g, p.name + ' spun the ' + FAM[fam].name + ' wheel: ' + L.itemView(won.id, g.map).name);
      }, { undo: false });
    }
    requestAnimationFrame(frame);
  }

  function renderWheels() {
    var fam = state.wheel.family;
    $$('#wheel-family button').forEach(function (b) { b.setAttribute('aria-pressed', String(b.dataset.family === fam)); });
    var key = fam + ':' + mapId();
    if (key !== wheelKey && !spinning) {
      drawWheel(fam);
      wheelKey = key;
    }
    $('#wheel-actor').innerHTML = actorButton(actor(), 'Spinning for', 'No one');
    $('#spin-btn').textContent = 'Spin the ' + FAM[fam].name + ' wheel';
    if (!spinning) $('#wheel-result').innerHTML = resultMarkup();
    $('#wheel-legend').innerHTML = legendMarkup(fam);
  }

  function resultMarkup() {
    var last = state.wheel.last;
    if (!last || last.family !== state.wheel.family) {
      return '<p class="readout-hint">Tap the wheel to see which card you draw</p>';
    }
    var it = item(last.item);
    if (!it) return '';
    var g = state.game;
    var owner = g && last.pid ? L.player(g, last.pid) : null;
    var giveTo = owner || actor();
    var naturalist = !!(giveTo && it.family === 'assist' && giveTo.character === 'naturalist');
    var note = '';
    if (naturalist) {
      var m = L.map(g.map);
      note = '<p class="note">Naturalist rule: ' + esc(giveTo.name) + ' receives a natural trap instead of an assist item (' + esc(m.naturalTraps) + ' on ' + esc(m.name) + ').</p>';
    }
    var actions = '';
    if (g) {
      if (last.given) {
        var gp = L.player(g, last.given);
        actions = '<p class="done-line">' + ICON.check + 'In ' + esc(gp ? gp.name : 'a player') + "'s hand</p>";
      } else {
        var main = giveTo && !naturalist
          ? '<button class="btn btn-gold" data-act="give-last" data-id="' + giveTo.id + '">Add to ' + esc(giveTo.name) + "'s hand</button>"
          : '';
        actions = '<div class="result-actions">' + main + '<button class="btn" data-act="give-pick">' + (main ? 'Someone else' : 'Give to a player') + '</button></div>';
      }
    }
    return '<article class="result card"><div class="result-head"><span class="token token-' + it.family + ' lg" aria-hidden="true">' + it.icon + '</span>' +
        '<div class="row-text"><span class="eyebrow">' + FAM[it.family].name + ' card</span><h2>' + esc(it.name) + '</h2></div></div>' +
      '<p class="result-effect">' + esc(it.effect) + '</p>' +
      (it.note ? '<p class="note">' + esc(it.note) + '</p>' : '') + note + actions + '</article>';
  }

  function legendMarkup(fam) {
    var items = L.itemsOf(fam).map(function (i) { return item(i.id); });
    return '<div class="section-head"><h2 class="section-title">On this wheel</h2><span class="section-note">' + plural(items.length, 'card') + ', equal chances</span></div>' +
      '<ul class="list icons">' + items.map(function (it) {
        return '<li class="row rule-row"><span class="token token-' + fam + '" aria-hidden="true">' + it.icon + '</span>' +
          '<span class="row-text"><b>' + esc(it.name) + '</b><span class="sub">' + esc(it.effect) + '</span></span></li>';
      }).join('') + '</ul>';
  }

  function giveLast(pid) {
    var last = state.wheel.last;
    if (!last || !state.game) return;
    var msg = '';
    change(function (g, s) {
      var p = L.player(g, pid);
      if (!p || !L.giveItem(g, pid, last.item)) return false;
      s.wheel.last.given = pid;
      var v = L.itemView(last.item, g.map);
      log(g, p.name + ' drew ' + v.name);
      msg = v.name + ' added to ' + p.name + "'s hand";
    });
    if (msg) toast(msg, { label: 'Undo', run: undo });
  }

  /* ---------- rules tab ---------- */

  function rulesData() {
    var R = D.RULES;
    var pairs = function (list) { return list.map(function (x) { return { title: x[0], text: x[1] }; }); };
    var tokens = function (f) {
      return L.itemsOf(f).map(function (i) {
        return { icon: i.icon, fam: f, title: i.name, text: i.effect + (i.note ? ' ' + i.note : '') };
      });
    };
    return [
      { title: 'Overview', rows: [{ title: 'The game', text: R.overview }, { title: 'Objective', text: R.objective }] },
      { title: 'On your turn', steps: true, rows: pairs(R.turn) },
      { title: 'Trap tokens', rows: tokens('trap') },
      { title: 'Assist tokens', rows: tokens('assist') },
      { title: 'Neutral tokens', rows: tokens('neutral') },
      { title: 'Characters', rows: D.CHARACTERS.map(function (c) { return { icon: c.icon, title: c.name, text: c.ability + ' ' + c.recharge }; }) },
      { title: 'Winning', rows: [{ title: 'Five treasures', text: R.winning }, { title: 'Team play', text: R.teamPlay }] },
      { title: 'Special rules', rows: pairs(R.special) },
      { title: 'Game modes', rows: D.MODES.map(function (m) { return { title: m.name, text: m.summary + '. ' + m.rules }; }) },
      { title: 'Maps', rows: D.MAPS.map(function (m) {
        var bits = [m.theme && m.theme + '.', m.tiles && m.tiles + ' tiles.', m.feature].filter(Boolean);
        return { icon: m.icon, title: m.name + (m.available ? '' : ' (coming soon)'), text: bits.join(' ') };
      }) },
      { title: 'Setup', steps: true, rows: pairs(R.setup) },
      { title: 'In the box', rows: pairs(R.components) },
    ];
  }

  function highlight(text, q) {
    if (!q) return esc(text);
    var lower = text.toLowerCase();
    var out = '';
    var i = 0;
    var j;
    while ((j = lower.indexOf(q, i)) >= 0) {
      out += esc(text.slice(i, j)) + '<mark>' + esc(text.slice(j, j + q.length)) + '</mark>';
      i = j + q.length;
    }
    return out + esc(text.slice(i));
  }

  function installHelp() {
    if (standalone || inFrame) return '';
    return '<section class="rules-section"><div class="section-head"><h2 class="section-title">Add to Home Screen</h2></div><ol class="list steps">' +
      '<li class="row rule-row"><span class="step" aria-hidden="true">1</span><span class="row-text"><b>Open this page in Safari</b><span class="sub">On iPhone or iPad.</span></span></li>' +
      '<li class="row rule-row"><span class="step" aria-hidden="true">2</span><span class="row-text"><b>Tap Share</b><span class="sub">The square with an arrow pointing up.</span></span></li>' +
      '<li class="row rule-row"><span class="step" aria-hidden="true">3</span><span class="row-text"><b>Choose Add to Home Screen</b><span class="sub">Trapisque Tools then opens full screen and works without a connection.</span></span></li>' +
      '</ol></section>';
  }

  function renderRules() {
    var q = $('#rules-search').value.trim().toLowerCase();
    var sections = rulesData().map(function (s) {
      var all = s.title.toLowerCase().indexOf(q) >= 0;
      var rows = s.rows.map(function (r, i) { return Object.assign({ n: i + 1 }, r); }).filter(function (r) {
        return !q || all || (r.title + ' ' + r.text).toLowerCase().indexOf(q) >= 0;
      });
      return Object.assign({}, s, { rows: rows });
    }).filter(function (s) { return s.rows.length; });

    if (!sections.length) {
      $('#rules-body').innerHTML = '<div class="empty card"><h2>Nothing found</h2><p>No rules mention “' + esc(q) + '”. Try a token or character name.</p></div>';
      return;
    }
    $('#rules-body').innerHTML = sections.map(function (s) {
      var icons = s.rows.some(function (r) { return r.icon; });
      return '<section class="rules-section"><div class="section-head"><h2 class="section-title">' + highlight(s.title, q) + '</h2></div>' +
        '<ul class="list' + (icons ? ' icons' : s.steps ? ' steps' : '') + '">' + s.rows.map(function (r) {
          var lead = r.icon ? '<span class="token' + (r.fam ? ' token-' + r.fam : '') + '" aria-hidden="true">' + r.icon + '</span>'
            : s.steps ? '<span class="step" aria-hidden="true">' + r.n + '</span>' : '';
          return '<li class="row rule-row">' + lead + '<span class="row-text"><b>' + highlight(r.title, q) + '</b><span class="sub">' + highlight(r.text, q) + '</span></span></li>';
        }).join('') + '</ul></section>';
    }).join('') + (q ? '' : installHelp());
  }

  /* ---------- sheets ---------- */

  var sheets = [];
  var pickHandler = null;

  function openSheet(opts) {
    closeSheet(opts.id, true);
    var layer = document.createElement('div');
    layer.className = 'sheet-layer';
    layer.innerHTML = '<div class="sheet-backdrop" data-act="sheet-close" data-sheet="' + opts.id + '"></div>' +
      '<section class="sheet' + (opts.tall ? ' tall' : '') + '" role="dialog" aria-modal="true" aria-labelledby="sheet-' + opts.id + '-title">' +
        '<div class="sheet-top"><div class="sheet-grab" aria-hidden="true"></div>' +
          '<header class="sheet-head gutter">' +
            '<span class="sheet-side">' + (opts.cancel ? '<button class="btn-text" data-act="sheet-close" data-sheet="' + opts.id + '">Cancel</button>' : '') + '</span>' +
            '<h2 class="sheet-title" id="sheet-' + opts.id + '-title" tabindex="-1"></h2>' +
            '<span class="sheet-side right"><button class="btn-text strong" data-act="sheet-done" data-sheet="' + opts.id + '">' + esc(opts.done || 'Done') + '</button></span>' +
          '</header></div>' +
        '<div class="sheet-body gutter"></div>' +
      '</section>';
    $('#sheets').appendChild(layer);
    var entry = { id: opts.id, opts: opts, layer: layer, back: document.activeElement };
    sheets.push(entry);
    paintSheet(entry);
    document.documentElement.classList.add('has-sheet');
    requestAnimationFrame(function () { requestAnimationFrame(function () { layer.classList.add('open'); }); });
    setTimeout(function () { focusQuietly($('.sheet-title', layer)); }, 60);
    dragToClose(entry);
    return entry;
  }

  function paintSheet(entry) {
    var o = entry.opts;
    var html = o.body();
    if (html === null) { closeSheet(entry.id); return; }
    $('.sheet-title', entry.layer).textContent = typeof o.title === 'function' ? o.title() : o.title;
    $('.sheet-body', entry.layer).innerHTML = html;
  }

  function repaint(id) {
    var entry = sheets.filter(function (s) { return s.id === id; })[0];
    if (entry) paintSheet(entry);
  }

  function renderSheets() { sheets.slice().forEach(paintSheet); }

  function closeSheet(id, instant) {
    var i = sheets.findIndex(function (s) { return s.id === id; });
    if (i < 0) return;
    var entry = sheets.splice(i, 1)[0];
    entry.layer.classList.remove('open');
    if (instant || reduced()) entry.layer.remove();
    else setTimeout(function () { entry.layer.remove(); }, 380);
    if (!sheets.length) document.documentElement.classList.remove('has-sheet');
    if (!instant && entry.back && document.contains(entry.back)) focusQuietly(entry.back);
  }

  function dragToClose(entry) {
    var sheet = $('.sheet', entry.layer);
    var handle = $('.sheet-top', entry.layer);
    var y0 = null;
    var dy = 0;
    var t0 = 0;
    handle.addEventListener('pointerdown', function (e) {
      if (e.target.closest('button')) return;
      y0 = e.clientY;
      dy = 0;
      t0 = performance.now();
      sheet.style.transition = 'none';
      try { handle.setPointerCapture(e.pointerId); } catch (err) { /* older browsers */ }
    });
    handle.addEventListener('pointermove', function (e) {
      if (y0 === null) return;
      dy = Math.max(0, e.clientY - y0);
      sheet.style.transform = 'translateY(' + dy + 'px)';
    });
    function end() {
      if (y0 === null) return;
      var fast = dy / Math.max(1, performance.now() - t0) > 0.6;
      y0 = null;
      sheet.style.transition = '';
      sheet.style.transform = '';
      if (dy > 110 || (fast && dy > 30)) closeSheet(entry.id);
    }
    handle.addEventListener('pointerup', end);
    handle.addEventListener('pointercancel', end);
  }

  function pickPlayer(opts) {
    pickHandler = opts.onPick;
    openSheet({
      id: 'pick',
      title: opts.title,
      done: 'Cancel',
      body: function () {
        var g = state.game;
        if (!g) return null;
        var cur = current();
        var rows = g.players.map(function (p) {
          var c = charOf(p);
          return '<button class="row" data-act="picked" data-id="' + p.id + '">' + pawn(p, 'sm') +
            '<span class="row-text"><b>' + esc(p.name) + '</b><span class="sub">' + c.icon + ' ' + esc(c.name) + (p === cur ? ' · Now playing' : '') + '</span></span>' +
            '<span class="check">' + (opts.selected === p.id ? ICON.check : '') + '</span></button>';
        });
        if (opts.none) {
          rows.push('<button class="row" data-act="picked" data-id="none"><span class="pawn sm ghost">' + PAWN + '</span>' +
            '<span class="row-text"><b>' + esc(opts.none) + '</b></span><span class="check">' + (opts.selected === 'none' ? ICON.check : '') + '</span></button>');
        }
        return '<div class="list">' + rows.join('') + '</div>';
      },
    });
  }

  function actionSheet(title, actions) {
    var layer = document.createElement('div');
    layer.className = 'action-layer';
    layer.innerHTML = '<div class="action-wrap gutter" role="dialog" aria-modal="true" aria-label="' + esc(title) + '">' +
      '<div class="action-group"><p class="action-title">' + esc(title) + '</p>' + actions.map(function (a, i) {
        return '<button data-i="' + i + '" class="' + (a.destructive ? 'destructive' : '') + '">' + esc(a.label) + '</button>';
      }).join('') + '</div><div class="action-group"><button class="strong" data-close>Cancel</button></div></div>';
    document.body.appendChild(layer);
    var back = document.activeElement;
    requestAnimationFrame(function () { requestAnimationFrame(function () { layer.classList.add('open'); }); });
    function close() {
      layer.classList.remove('open');
      setTimeout(function () { layer.remove(); }, reduced() ? 0 : 300);
      focusQuietly(back);
    }
    layer.addEventListener('click', function (e) {
      var b = e.target.closest('[data-i]');
      if (b) { close(); actions[Number(b.dataset.i)].run(); return; }
      if (e.target === layer || e.target.closest('[data-close]')) close();
    });
    layer.addEventListener('keydown', function (e) { if (e.key === 'Escape') close(); });
    focusQuietly($('button', layer));
  }

  function confirmBox(o) {
    return new Promise(function (resolve) {
      var layer = document.createElement('div');
      layer.className = 'alert-layer';
      layer.innerHTML = '<div class="alert" role="alertdialog" aria-modal="true" aria-labelledby="alert-title" aria-describedby="alert-text">' +
        '<h2 id="alert-title">' + esc(o.title) + '</h2><p id="alert-text">' + esc(o.message) + '</p>' +
        '<div class="alert-actions"><button data-r="0">Cancel</button><button data-r="1" class="' + (o.destructive ? 'destructive' : 'strong') + '">' + esc(o.confirm) + '</button></div></div>';
      document.body.appendChild(layer);
      requestAnimationFrame(function () { requestAnimationFrame(function () { layer.classList.add('open'); }); });
      function done(ok) { layer.remove(); resolve(ok); }
      layer.addEventListener('click', function (e) {
        var b = e.target.closest('[data-r]');
        if (b) done(b.dataset.r === '1');
      });
      layer.addEventListener('keydown', function (e) { if (e.key === 'Escape') done(false); });
      focusQuietly($('[data-r="1"]', layer));
    });
  }

  var toastTimer = 0;
  var toastClear = 0;
  var toastAction = null;
  function toast(text, action) {
    var el = $('#toast');
    toastAction = action || null;
    el.innerHTML = '<span>' + esc(text) + '</span>' + (action ? '<button type="button" data-toast>' + esc(action.label) + '</button>' : '');
    el.classList.add('show');
    clearTimeout(toastTimer);
    clearTimeout(toastClear);
    toastTimer = setTimeout(function () {
      el.classList.remove('show');
      toastAction = null;
      toastClear = setTimeout(function () { el.innerHTML = ''; }, 300);
    }, action ? 4500 : 2600);
  }
  $('#toast').addEventListener('click', function (e) {
    if (!e.target.closest('[data-toast]') || !toastAction) return;
    var a = toastAction;
    toastAction = null;
    $('#toast').classList.remove('show');
    a.run();
  });

  function celebrate(w) {
    var g = state.game;
    if (!g) return;
    var t = winnerText(g, w);
    var colors = ['--gold', '--trap', '--assist', '--neutral', '--pawn-0', '--pawn-5'];
    var bits = '';
    if (!reduced()) {
      for (var i = 0; i < 42; i++) {
        bits += '<i style="--x:' + (Math.random() * 100).toFixed(1) + '%;--d:' + (Math.random() * 0.8).toFixed(2) + 's;--t:' +
          (2.2 + Math.random() * 1.6).toFixed(2) + 's;--r:' + Math.floor(Math.random() * 360) + 'deg;--c:var(' + colors[i % colors.length] + ')"></i>';
      }
    }
    var layer = document.createElement('div');
    layer.className = 'win-layer';
    layer.innerHTML = '<div class="confetti" aria-hidden="true">' + bits + '</div>' +
      '<div class="win-card" role="alertdialog" aria-modal="true" aria-labelledby="win-title" aria-describedby="win-text">' +
        '<div class="trophy" aria-hidden="true">🏆</div><h2 id="win-title">' + esc(t.title) + '</h2><p id="win-text">' + esc(t.detail) + '</p>' +
        '<div class="win-actions"><button class="btn btn-gold btn-block" data-win="new">New game</button>' +
        '<button class="btn btn-block" data-win="keep">Keep playing</button></div></div>';
    document.body.appendChild(layer);
    layer.addEventListener('click', function (e) {
      var b = e.target.closest('[data-win]');
      if (!b) return;
      layer.remove();
      if (b.dataset.win === 'new') openSetup();
    });
    focusQuietly($('[data-win="new"]', layer));
  }

  /* ---------- screen wake lock ---------- */

  var wakeLock = null;
  function applyWake() {
    if (!('wakeLock' in navigator)) return;
    if (state.prefs.awake && document.visibilityState === 'visible') {
      if (wakeLock) return;
      navigator.wakeLock.request('screen').then(function (lock) {
        wakeLock = lock;
        lock.addEventListener('release', function () { wakeLock = null; });
      }).catch(function () { /* not allowed right now */ });
    } else if (wakeLock) {
      wakeLock.release().catch(function () {});
      wakeLock = null;
    }
  }
  function toggleAwake() {
    state.prefs.awake = !state.prefs.awake;
    save();
    applyWake();
    toast(state.prefs.awake ? 'The screen stays on while Trapisque is open' : 'The screen can sleep again');
  }
  document.addEventListener('visibilitychange', applyWake);

  /* ---------- actions ---------- */

  var actions = {
    tab: function (el) { setTab(el.dataset.tab); },
    undo: undo,
    menu: openMenu,
    'close-hint': function () { state.prefs.hintClosed = true; save(); render(); },
    'new-game': openSetup,
    'load-sample': function () {
      undoStack.length = 0;
      state.game = L.sampleGame();
      state.actor = null;
      save();
      render();
    },
    'go-dice': function () { state.actor = null; setTab('dice'); render(); },
    'next-turn': nextTurn,
    treasure: function (el) { treasure(el.dataset.id, 1); },
    'treasure-minus': function (el) { treasure(el.dataset.id, -1); },
    'open-player': function (el) { openPlayer(el.dataset.id); },
    status: function (el) {
      change(function (g) {
        var p = L.player(g, el.dataset.id);
        if (!p) return false;
        p.status[el.dataset.key] = !p.status[el.dataset.key];
      });
    },
    'use-ability': function (el) {
      var label = '';
      change(function (g) {
        var p = L.player(g, el.dataset.id);
        if (!p || !L.useAbility(g, p.id)) return false;
        label = charOf(p).name + ' ability used';
        log(g, p.name + ' used the ' + charOf(p).name + ' ability');
      });
      if (label) toast(label, { label: 'Undo', run: undo });
    },
    regen: function (el) {
      change(function (g) {
        var p = L.player(g, el.dataset.id);
        if (!p || !L.regenerate(g, p.id)) return false;
        log(g, p.name + "'s " + charOf(p).name + ' ability was recharged');
      });
    },
    'make-turn': function (el) {
      change(function (g, s) {
        var i = g.players.findIndex(function (p) { return p.id === el.dataset.id; });
        if (i < 0) return false;
        g.turn = i;
        s.actor = null;
        log(g, 'Turn moved to ' + g.players[i].name);
      });
      closeSheet('player');
    },
    'add-item': function (el) { openItemPicker(el.dataset.id); },
    'give-item': function (el) {
      var msg = '';
      change(function (g) {
        var p = L.player(g, el.dataset.id);
        if (!p || !L.giveItem(g, p.id, el.dataset.key)) return false;
        var v = L.itemView(el.dataset.key, g.map);
        log(g, p.name + ' drew ' + v.name);
        msg = v.name + ' added to ' + p.name + "'s hand";
      });
      closeSheet('items');
      if (msg) toast(msg);
    },
    'use-item': function (el) {
      var msg = '';
      change(function (g) {
        var p = L.player(g, el.dataset.id);
        if (!p) return false;
        var res = L.useItem(g, p.id, Number(el.dataset.index));
        if (!res) return false;
        var v = L.itemView(res.item, g.map);
        log(g, p.name + ' used ' + v.name);
        msg = useMessage(p, v, res.effect);
      });
      if (msg) toast(msg, { label: 'Undo', run: undo });
    },
    'drop-item': function (el) {
      var name = '';
      change(function (g) {
        var p = L.player(g, el.dataset.id);
        var id = p && L.discardItem(g, p.id, Number(el.dataset.index));
        if (!id) return false;
        name = L.itemView(id, g.map).name;
        log(g, p.name + ' discarded ' + name);
      });
      if (name) toast(name + ' discarded', { label: 'Undo', run: undo });
    },
    'spin-for': function (el) {
      closeSheet('items', true);
      closeSheet('player', true);
      state.actor = el.dataset.id;
      setTab('wheels');
      render();
    },
    'pick-actor': function () {
      var a = actor();
      pickPlayer({
        title: state.tab === 'dice' ? 'Rolling for' : 'Spinning for',
        none: state.tab === 'dice' ? 'No one (free roll)' : 'No one',
        selected: state.actor === 'none' ? 'none' : (a ? a.id : null),
        onPick: function (id) {
          var cur = current();
          state.actor = id === 'none' ? 'none' : (cur && cur.id === id ? null : id);
          save();
          render();
        },
      });
    },
    picked: function (el) {
      var fn = pickHandler;
      pickHandler = null;
      closeSheet('pick');
      if (fn) fn(el.dataset.id);
    },
    'dice-mode': function (el) {
      if (rolling) return;
      state.dice.mode = el.dataset.mode;
      save();
      render();
    },
    mod: function (el) {
      var id = el.dataset.mod;
      var a = actor();
      if (autoMods(a)[id]) {
        toast(id === 'half' ? a.name + ' is Frozen. Change it in ' + a.name + "'s player card." : a.name + "'s Speed Boost doubles this roll");
        return;
      }
      state.dice[id] = !state.dice[id];
      save();
      render();
    },
    roll: roll,
    'clear-rolls': function () { state.dice.history = []; save(); render(); },
    family: function (el) {
      if (spinning) return;
      state.wheel.family = el.dataset.family;
      save();
      render();
    },
    spin: spin,
    'give-last': function (el) { giveLast(el.dataset.id); },
    'give-pick': function () { pickPlayer({ title: 'Give the card to', onPick: giveLast }); },
    'sheet-close': function (el) { closeSheet(el.dataset.sheet); },
    'sheet-done': function (el) {
      var entry = sheets.filter(function (s) { return s.id === el.dataset.sheet; })[0];
      if (entry && entry.opts.onDone) entry.opts.onDone();
      else closeSheet(el.dataset.sheet);
    },
    'setup-mode': function (el) {
      var m = L.mode(el.dataset.key);
      draft.mode = m.id;
      draft.target = m.target;
      resizeDraft(clamp(draft.players.length, m.min, m.max));
      repaint('setup');
    },
    'setup-map': function (el) { draft.map = el.dataset.key; repaint('setup'); },
    'setup-count': function (el) {
      var m = L.mode(draft.mode);
      resizeDraft(clamp(draft.players.length + Number(el.dataset.delta), m.min, m.max));
      repaint('setup');
    },
    'setup-target': function (el) { draft.target = clamp(draft.target + Number(el.dataset.delta), 1, 9); repaint('setup'); },
    'setup-team': function (el) {
      var p = draft.players[Number(el.dataset.index)];
      p.team = (p.team + 1) % L.mode(draft.mode).teams;
      repaint('setup');
    },
    'setup-redraw': function () {
      var deal = L.dealCharacters(draft.players.length);
      draft.players.forEach(function (p, i) { p.character = deal[i]; });
      repaint('setup');
      toast('Characters redrawn');
    },
    'setup-char': function (el) { openCharPicker(Number(el.dataset.index)); },
    'setup-pick-char': function (el) {
      var i = Number(el.dataset.index);
      var id = el.dataset.key;
      var holder = draft.players.findIndex(function (p) { return p.character === id; });
      if (holder >= 0 && holder !== i) draft.players[holder].character = draft.players[i].character;
      draft.players[i].character = id;
      closeSheet('char');
      repaint('setup');
    },
    'setup-start': startGame,
  };

  document.addEventListener('click', function (e) {
    var el = e.target.closest('[data-act]');
    if (!el || el.disabled) return;
    var fn = actions[el.dataset.act];
    if (fn) fn(el, e);
  });

  document.addEventListener('input', function (e) {
    if (e.target.classList.contains('name-input') && draft) {
      var p = draft.players[Number(e.target.dataset.index)];
      if (p) p.name = e.target.value;
    }
    if (e.target.id === 'rules-search') renderRules();
  });

  document.addEventListener('keydown', function (e) {
    if (e.key === 'Escape' && sheets.length) {
      closeSheet(sheets[sheets.length - 1].id);
      return;
    }
    if (e.key === 'Enter' && e.target.classList.contains('name-input')) {
      e.preventDefault();
      var nextInput = $('#setup-name-' + (Number(e.target.dataset.index) + 1));
      if (nextInput) nextInput.focus();
      else e.target.blur();
    }
  });

  /* ---------- large titles collapse into the nav bar ---------- */

  var navLine = 44;

  // Shows the small nav title once the large title has scrolled under the nav bar.
  function syncNav(view) {
    if (!view || view.hidden) return;
    var title = $('[data-large-title] h1', view);
    $('[data-nav]', view).classList.toggle('compact', title.getBoundingClientRect().bottom <= navLine);
  }

  function watchTitles() {
    var probe = document.createElement('div');
    probe.style.cssText = 'position:fixed;top:0;height:env(safe-area-inset-top, 0px);visibility:hidden;pointer-events:none';
    document.body.appendChild(probe);
    navLine = 44 + probe.offsetHeight;
    probe.remove();
    $$('.view').forEach(function (view) {
      syncNav(view);
      if (!('IntersectionObserver' in window)) return;
      new IntersectionObserver(function () {
        syncNav(view); // hidden views are skipped, so switching tabs never flashes the small title
      }, { rootMargin: '-' + navLine + 'px 0px 0px 0px' }).observe($('[data-large-title] h1', view));
    });
  }

  /* ---------- offline support ---------- */

  function registerWorker() {
    if (inFrame || !('serviceWorker' in navigator)) return;
    var secure = location.protocol === 'https:' || location.hostname === 'localhost' || location.hostname === '127.0.0.1';
    if (!secure) return;
    window.addEventListener('load', function () {
      navigator.serviceWorker.register('sw.js').catch(function () { /* offline mode unavailable */ });
    });
  }

  /* ---------- start ---------- */

  function render() {
    renderTabs();
    renderGame();
    renderDice();
    renderWheels();
    renderSheets();
  }

  function init() {
    var die = $('#die');
    die.style.transition = 'none';
    showFace(state.dice.last ? state.dice.last.roll : 5);
    void die.offsetWidth;
    die.style.transition = '';
    TABS.forEach(function (t) { $('#view-' + t).hidden = t !== state.tab; });
    renderRules();
    render();
    watchTitles();
    applyWake();
    registerWorker();
  }

  init();
})();
