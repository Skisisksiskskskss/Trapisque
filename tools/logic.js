/* Trapisque Tools: game rules. No DOM access here, so the rules can be tested on their own.
   Loaded as a plain script in the browser (window.TQ_LOGIC) and with require() in tests. */
(function (root, factory) {
  var data = root.TQ_DATA || (typeof require === 'function' ? require('./data.js') : undefined);
  var api = factory(data);
  if (typeof module === 'object' && module.exports) module.exports = api;
  else root.TQ_LOGIC = api;
})(typeof window !== 'undefined' ? window : globalThis, function (D) {
  'use strict';

  function index(list) {
    var map = {};
    list.forEach(function (x) { map[x.id] = x; });
    return map;
  }
  var ITEM = index(D.ITEMS);
  var CHAR = index(D.CHARACTERS);
  var MODE = index(D.MODES);
  var MAP = index(D.MAPS);

  /* ---------- randomness ---------- */

  var cryptoApi = typeof globalThis !== 'undefined' && globalThis.crypto && globalThis.crypto.getRandomValues
    ? globalThis.crypto : null;

  // Unbiased integer in [0, n).
  function randomInt(n) {
    if (!cryptoApi) return Math.floor(Math.random() * n);
    var buf = new Uint32Array(1);
    var limit = Math.floor(0x100000000 / n) * n;
    do { cryptoApi.getRandomValues(buf); } while (buf[0] >= limit);
    return buf[0] % n;
  }
  function rollDie() { return randomInt(6) + 1; }
  function pick(list) { return list[randomInt(list.length)]; }
  function shuffle(list) {
    var a = list.slice();
    for (var i = a.length - 1; i > 0; i--) {
      var j = randomInt(i + 1);
      var t = a[i]; a[i] = a[j]; a[j] = t;
    }
    return a;
  }
  function uid() { return Date.now().toString(36) + randomInt(1e9).toString(36); }

  /* ---------- lookups ---------- */

  function itemsOf(family) { return D.ITEMS.filter(function (i) { return i.family === family; }); }
  function character(id) { return CHAR[id]; }
  function mode(id) { return MODE[id] || MODE.chaos; }
  function map(id) { return MAP[id] || MAP.blissful; }

  // The Bridge / Key / Boots card takes the name of the current map's item.
  function itemView(id, mapId) {
    var item = ITEM[id];
    if (!item) return null;
    if (!item.perMap) return item;
    var m = map(mapId);
    return Object.assign({}, item, {
      name: m.naturalItem.name,
      icon: m.naturalItem.icon,
      effect: item.effect + ' On ' + m.name + ': ' + m.naturalItem.use,
      use: m.naturalItem.use,
    });
  }

  /* ---------- dice ---------- */

  // Ice and slime: even rolls are halved, odd rolls lose 1 (rulebook wording).
  function halve(n) { return n % 2 === 0 ? n / 2 : n - 1; }

  // Speed Boost doubles first, then Ice halves, so the two cancel out.
  function moveFor(roll, mods) {
    mods = mods || {};
    var value = roll;
    var steps = [];
    if (mods.boost) {
      value = value * 2;
      steps.push({ id: 'boost', value: value });
    }
    if (mods.half) {
      var odd = value % 2 !== 0;
      value = halve(value);
      steps.push({ id: odd ? 'half-odd' : 'half', value: value });
    }
    return { roll: roll, value: value, steps: steps };
  }

  // Grog: survive on 4+. Wall: pass on more than 4.
  var CHECKS = { grog: 4, wall: 5 };
  function passes(check, roll) { return roll >= CHECKS[check]; }

  /* ---------- game setup ---------- */

  function emptyStatus() { return { shield: false, frozen: false, burning: false, snared: false, boost: false }; }
  function readyAbility() { return { used: false, round: null, cycle: null }; }

  function dealCharacters(count) {
    return shuffle(D.CHARACTERS.map(function (c) { return c.id; })).slice(0, count);
  }

  // Alternate teams so turns pass back and forth between them: A, B, A, B…
  function defaultTeams(modeId, count) {
    var m = mode(modeId);
    var out = [];
    for (var i = 0; i < count; i++) out.push(m.teams ? i % m.teams : null);
    return out;
  }

  function teamProblem(modeId, teams) {
    var m = mode(modeId);
    if (!m.teams) return null;
    var size = m.max / m.teams;
    var counts = [];
    for (var t = 0; t < m.teams; t++) counts.push(0);
    teams.forEach(function (t) { if (t != null) counts[t] += 1; });
    var wrong = counts.some(function (c) { return c !== size; });
    return wrong ? 'Each team needs ' + size + ' players.' : null;
  }

  function createGame(opts) {
    var m = mode(opts.mode);
    var players = opts.players.map(function (p, i) {
      return {
        id: 'p' + i + uid(),
        name: p.name,
        character: p.character,
        team: m.teams ? p.team : null,
        color: p.color != null ? p.color : i,
        treasures: 0,
        status: emptyStatus(),
        ability: readyAbility(),
        items: [],
      };
    });
    players.forEach(function (p) {
      var c = CHAR[p.character];
      if (!c || !c.startItems) return;
      if (c.startItems.ids) p.items = p.items.concat(c.startItems.ids);
      for (var k = 0; k < (c.startItems.count || 0); k++) p.items.push(pick(itemsOf(c.startItems.family)).id);
    });
    // The Overseer always rolls first. Play still passes around the table in the same order.
    var first = players.findIndex(function (p) { return CHAR[p.character] && CHAR[p.character].goesFirst; });
    if (first > 0) players = players.slice(first).concat(players.slice(0, first));
    return {
      v: 1,
      id: 'g' + uid(),
      mode: m.id,
      map: map(opts.map).id,
      target: opts.target || m.target,
      players: players,
      turn: 0,
      round: 1,
      winner: null,
      log: [],
      started: Date.now(),
      sample: false,
    };
  }

  function player(game, id) {
    return game.players.find(function (p) { return p.id === id; }) || null;
  }

  /* ---------- teams and winning ---------- */

  function teamName(i) { return 'Team ' + 'ABC'.charAt(i); }

  function teams(game) {
    var m = mode(game.mode);
    var out = [];
    for (var i = 0; i < m.teams; i++) {
      out.push({
        id: i,
        name: teamName(i),
        members: game.players.filter(function (p) { return p.team === i; }),
      });
    }
    return out;
  }

  function isDone(game, p) { return p.treasures >= game.target; }

  function stillWins(game, w) {
    if (!w) return false;
    if (w.kind === 'player') {
      var p = player(game, w.id);
      return !!p && isDone(game, p);
    }
    var t = teams(game)[w.id];
    return !!t && t.members.length > 0 && t.members.every(function (p) { return isDone(game, p); });
  }

  function findWinner(game) {
    if (mode(game.mode).win === 'first') {
      var p = game.players.find(function (x) { return isDone(game, x); });
      return p ? { kind: 'player', id: p.id } : null;
    }
    var t = teams(game).find(function (x) {
      return x.members.length > 0 && x.members.every(function (p) { return isDone(game, p); });
    });
    return t ? { kind: 'team', id: t.id } : null;
  }

  // Keeps game.winner in step with the scores. Returns the winner only when one was just decided.
  function updateWinner(game) {
    if (game.winner && !stillWins(game, game.winner)) game.winner = null;
    if (game.winner) return null;
    var w = findWinner(game);
    if (!w) return null;
    game.winner = Object.assign(w, { round: game.round });
    return game.winner;
  }

  /* ---------- abilities ---------- */

  function abilityInfo(game, p) {
    var c = CHAR[p.character];
    if (!c || c.kind === 'passive') return { state: 'passive', usable: false };
    if (c.kind === 'always') return { state: 'always', usable: true };
    if (!p.ability.used) return { state: 'ready', usable: true };
    if (c.rechargeRounds && p.ability.round != null) {
      return { state: 'cooldown', usable: false, unit: 'round',
        left: Math.max(1, p.ability.round + c.rechargeRounds - game.round) };
    }
    if (c.rechargeCycles && p.ability.cycle != null) {
      return { state: 'cooldown', usable: false, unit: 'cycle',
        left: Math.max(1, p.ability.cycle + c.rechargeCycles - p.treasures) };
    }
    return { state: 'spent', usable: false };
  }

  function useAbility(game, id) {
    var p = player(game, id);
    var c = p && CHAR[p.character];
    if (!c || c.kind === 'passive') return false;
    if (c.kind === 'always') return true;
    if (p.ability.used) return false;
    p.ability = { used: true, round: game.round, cycle: p.treasures };
    return true;
  }

  function regenerate(game, id) {
    var p = player(game, id);
    if (!p) return false;
    var c = CHAR[p.character];
    if (!c || c.kind !== 'active') return false;
    p.ability = readyAbility();
    return true;
  }

  // Mage: a cycle is one trip from Start to the treasure, so it recharges after 2 more treasures.
  function rechargeByCycle(p) {
    var c = CHAR[p.character];
    if (c && c.rechargeCycles && p.ability.used && p.ability.cycle != null &&
        p.treasures >= p.ability.cycle + c.rechargeCycles) {
      p.ability = readyAbility();
      return [{ type: 'recharged', pid: p.id }];
    }
    return [];
  }

  // Overseer: recharges 2 rounds after use.
  function rechargeByRound(game) {
    var events = [];
    game.players.forEach(function (p) {
      var c = CHAR[p.character];
      if (c && c.rechargeRounds && p.ability.used && p.ability.round != null &&
          game.round >= p.ability.round + c.rechargeRounds) {
        p.ability = readyAbility();
        events.push({ type: 'recharged', pid: p.id });
      }
    });
    return events;
  }

  /* ---------- turns and treasures ---------- */

  // Moves to the next player. Snared players lose that turn and the snare comes off.
  function nextTurn(game) {
    var n = game.players.length;
    var events = [];
    var i = game.turn;
    for (var guard = 0; guard <= n; guard++) {
      i = (i + 1) % n;
      if (i === 0) {
        game.round += 1;
        events = events.concat(rechargeByRound(game));
      }
      var p = game.players[i];
      if (p.status.snared) {
        p.status.snared = false;
        events.push({ type: 'skip', pid: p.id });
        continue;
      }
      break;
    }
    game.turn = i;
    return events;
  }

  function changeTreasure(game, id, delta) {
    var p = player(game, id);
    if (!p) return { changed: false, events: [], win: null };
    var before = p.treasures;
    p.treasures = Math.max(0, Math.min(game.target, before + delta));
    var events = p.treasures > before ? rechargeByCycle(p) : [];
    var win = updateWinner(game);
    return { changed: p.treasures !== before, events: events, win: win };
  }

  // The current trip from Start to the treasure. Shifting Sands push forward on even cycles.
  function cycleOf(game, p) {
    var done = isDone(game, p);
    var cycle = done ? game.target : p.treasures + 1;
    return { cycle: cycle, done: done, even: cycle % 2 === 0 };
  }

  /* ---------- item cards ---------- */

  function giveItem(game, id, itemId) {
    var p = player(game, id);
    if (!p || !ITEM[itemId]) return false;
    p.items.push(itemId);
    return true;
  }

  // Using a card removes it from the hand. A few cards also change the player's state.
  function useItem(game, id, at) {
    var p = player(game, id);
    if (!p || at < 0 || at >= p.items.length) return null;
    var itemId = p.items.splice(at, 1)[0];
    var effect = null;
    if (itemId === 'shield') { p.status.shield = true; effect = 'shield'; }
    else if (itemId === 'speed') { p.status.boost = true; effect = 'boost'; }
    else if (itemId === 'regeneration') { effect = regenerate(game, id) ? 'regen' : 'regen-none'; }
    return { item: itemId, effect: effect };
  }

  function discardItem(game, id, at) {
    var p = player(game, id);
    if (!p || at < 0 || at >= p.items.length) return null;
    return p.items.splice(at, 1)[0];
  }

  /* ---------- sample ---------- */

  // An example game so the tracker shows something useful on first launch.
  function sampleGame() {
    var g = createGame({
      mode: 'chaos', map: 'blissful', target: 5,
      players: [
        { name: 'Ava', character: 'mage', color: 0 },
        { name: 'Ben', character: 'overseer', color: 1 },
        { name: 'Cleo', character: 'trapper', color: 2 },
      ],
    });
    var named = function (name) { return g.players.filter(function (p) { return p.name === name; })[0]; };
    var ben = named('Ben');
    var ava = named('Ava');
    var cleo = named('Cleo');
    ben.treasures = 2;
    ben.ability = { used: true, round: 3, cycle: 2 };
    ava.treasures = 3;
    ava.items = ['shield', 'bounce'];
    ava.status.frozen = true;
    cleo.treasures = 1;
    cleo.items = ['spike', 'snare', 'mud'];
    g.round = 4;
    g.turn = g.players.indexOf(ava);
    g.sample = true;
    var t = Date.now();
    g.log = [
      { r: 1, t: t, text: 'Ben goes first as the Overseer' },
      { r: 3, t: t, text: 'Ben used the Overseer ability' },
      { r: 3, t: t, text: 'Ava reached the treasure (3/5)' },
      { r: 3, t: t, text: 'Cleo placed a Grog' },
      { r: 4, t: t, text: 'Ava stepped on Ice and is Frozen' },
      { r: 4, t: t, text: 'Ben rolled 4' },
    ];
    return g;
  }

  return {
    randomInt: randomInt,
    rollDie: rollDie,
    shuffle: shuffle,
    itemsOf: itemsOf,
    itemView: itemView,
    character: character,
    mode: mode,
    map: map,
    halve: halve,
    moveFor: moveFor,
    passes: passes,
    CHECKS: CHECKS,
    dealCharacters: dealCharacters,
    defaultTeams: defaultTeams,
    teamProblem: teamProblem,
    createGame: createGame,
    player: player,
    teamName: teamName,
    teams: teams,
    isDone: isDone,
    updateWinner: updateWinner,
    abilityInfo: abilityInfo,
    useAbility: useAbility,
    regenerate: regenerate,
    nextTurn: nextTurn,
    changeTreasure: changeTreasure,
    cycleOf: cycleOf,
    giveItem: giveItem,
    useItem: useItem,
    discardItem: discardItem,
    sampleGame: sampleGame,
  };
});
