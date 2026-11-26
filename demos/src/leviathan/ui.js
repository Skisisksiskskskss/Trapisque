/* Leviathan Hunt: interface, characters, animation and turn flow. */
(function () {
  "use strict";
  /* Leviathan Hunt art: boats, the Leviathan, buoys and terrain decorations (SVG markup strings). */
  var LevArt = (function () {
    var OUT = "#0b1622";
    var COLORS = { sonar: "#5eead4", harpoon: "#f2b84b", net: "#c4a1ff", light: "#fff1c1" };
    function hull(c, wide) {
      var w = wide ? 17 : 15;
      return '<path d="M' + (-w) + ' 2h' + (2 * w) + 'l-4 8.5h' + (-2 * w + 8) + 'z" fill="' + c + '" stroke="' + OUT + '" stroke-width="1.8" stroke-linejoin="round"/>' +
        '<path d="M' + (-w + 2.5) + ' 5.6h' + (2 * w - 5) + '" stroke="rgba(11,22,34,.35)" stroke-width="1.4"/>';
    }
    function water() {
      return '<path d="M-17 10.5q4 -2.6 8.5 0t8.5 0t8.5 0t8.5 0" fill="none" stroke="rgba(233,241,247,.55)" stroke-width="1.4" stroke-linecap="round"/>';
    }
    var BOATS = {
      sonar: function () {
        return hull(COLORS.sonar) +
          '<rect x="-9" y="-6" width="11" height="8" rx="1.5" fill="#e9f1f7" stroke="' + OUT + '" stroke-width="1.6"/>' +
          '<rect x="-7" y="-4" width="3" height="3" rx=".8" fill="#2a6f8f"/><rect x="-2.5" y="-4" width="3" height="3" rx=".8" fill="#2a6f8f"/>' +
          '<path d="M7 2v-12" stroke="' + OUT + '" stroke-width="1.8"/>' +
          '<path d="M2 -13q5 7 10 0z" fill="#e9f1f7" stroke="' + OUT + '" stroke-width="1.6" stroke-linejoin="round"/>' +
          '<circle cx="7" cy="-11" r="1.4" fill="' + OUT + '"/>' + water();
      },
      harpoon: function () {
        return hull(COLORS.harpoon, true) +
          '<path d="M-17 2l3 3h28l3 -3" fill="none" stroke="#b3261e" stroke-width="1.6"/>' +
          '<rect x="-14" y="-7" width="10" height="9" rx="1.5" fill="#7a3b1e" stroke="' + OUT + '" stroke-width="1.6"/>' +
          '<rect x="-12" y="-5" width="3" height="3" rx=".8" fill="#ffd166"/>' +
          '<circle cx="8" cy="0" r="3" fill="#3b4a5c" stroke="' + OUT + '" stroke-width="1.5"/>' +
          '<path d="M8 0l9 -11" stroke="' + OUT + '" stroke-width="3.6" stroke-linecap="round"/>' +
          '<path d="M8 0l9 -11" stroke="#9fb3c8" stroke-width="1.8" stroke-linecap="round"/>' +
          '<path d="M19.5 -14l-6 1.6 3.6 3.4z" fill="#e9f1f7" stroke="' + OUT + '" stroke-width="1.2" stroke-linejoin="round"/>' + water();
      },
      net: function () {
        return hull(COLORS.net) +
          '<rect x="-12" y="-5" width="9" height="7" rx="1.5" fill="#e9f1f7" stroke="' + OUT + '" stroke-width="1.6"/>' +
          '<path d="M0 2v-15l12 4" fill="none" stroke="' + OUT + '" stroke-width="2" stroke-linejoin="round"/>' +
          '<path d="M12 -9v3" stroke="' + OUT + '" stroke-width="1.2"/>' +
          '<path d="M8 -6h8l-2 7h-4z" fill="rgba(233,241,247,.25)" stroke="#e9f1f7" stroke-width="1.1" stroke-linejoin="round"/>' +
          '<path d="M9 -3.5h6M10 -1h4M10 -6l2 7M14 -6l-2 7" stroke="#e9f1f7" stroke-width=".8"/>' + water();
      },
      light: function () {
        return hull(COLORS.light) +
          '<path d="M-4 2l1.5 -15h5l1.5 15z" fill="#e9f1f7" stroke="' + OUT + '" stroke-width="1.6" stroke-linejoin="round"/>' +
          '<path d="M-3.6 -2.5h7.2M-3 -8h6" stroke="#d61f52" stroke-width="2.4"/>' +
          '<rect x="-3.5" y="-18.5" width="7" height="5.5" rx="1.5" fill="#ffe08a" stroke="' + OUT + '" stroke-width="1.4"/>' +
          '<path d="M-4 -19h8l-4 -3.5z" fill="#d61f52" stroke="' + OUT + '" stroke-width="1.2" stroke-linejoin="round"/>' + water();
      }
    };
    function boat(kind) { return BOATS[kind](); }

    /* The Leviathan rising out of the water: two coils and a head. */
    function leviathan(opts) {
      opts = opts || {};
      var body = opts.color || "#d61f52", belly = "#ff8fa8", o = "";
      o += '<path d="M-19 9q4 -15 9 0" fill="none" stroke="' + OUT + '" stroke-width="7.5" stroke-linecap="round"/>';
      o += '<path d="M-19 9q4 -15 9 0" fill="none" stroke="' + body + '" stroke-width="4.5" stroke-linecap="round"/>';
      o += '<path d="M-17 -1l1 -4 2 3" fill="#ffd166" stroke="' + OUT + '" stroke-width="1" stroke-linejoin="round"/>';
      o += '<path d="M-6 10q-3 -21 10 -24q12 -2 13 9q1 7 -7 8l-2 7z" fill="' + body + '" stroke="' + OUT + '" stroke-width="1.9" stroke-linejoin="round"/>';
      o += '<path d="M-2 -10l-2 -6 4 3 1 -6 3 5 2 -5 2 5" fill="#ffd166" stroke="' + OUT + '" stroke-width="1.1" stroke-linejoin="round"/>';
      o += '<path d="M-3 9q-1 -9 4 -13" fill="none" stroke="' + belly + '" stroke-width="2.2" stroke-linecap="round" opacity=".8"/>';
      o += '<ellipse cx="8" cy="-6" rx="3.8" ry="3" fill="#ffd166" stroke="' + OUT + '" stroke-width="1.2"/>';
      o += '<ellipse cx="8.6" cy="-6" rx="1" ry="2.5" fill="' + OUT + '"/>';
      o += '<path d="M11 1.5l1.6 2.4 1.4 -2.2 1.4 2 1.2 -2.6" fill="none" stroke="#fff7e6" stroke-width="1.3" stroke-linejoin="round"/>';
      o += '<path d="M-20 10.5q4 -2.6 8.5 0t8.5 0t8.5 0t8.5 0t8.5 0" fill="none" stroke="rgba(233,241,247,.6)" stroke-width="1.4" stroke-linecap="round"/>';
      return o;
    }

    /* Big portrait of the Leviathan, 64x64. */
    function leviathanPortrait() {
      var body = "#d61f52", o = "";
      o += '<path d="M6 64q-2 -24 14 -36q16 -12 32 -4q12 7 8 20q-4 10 -16 9l-4 11z" fill="' + body + '" stroke="' + OUT + '" stroke-width="2.4" stroke-linejoin="round"/>';
      o += '<path d="M18 26l-4 -12 9 7 1 -13 7 11 4 -12 5 12 5 -9 1 11" fill="#ffd166" stroke="' + OUT + '" stroke-width="2" stroke-linejoin="round"/>';
      o += '<path d="M14 62q0 -18 10 -26" fill="none" stroke="#ff8fa8" stroke-width="3.5" stroke-linecap="round" opacity=".8"/>';
      o += '<ellipse cx="42" cy="33" rx="7" ry="5.5" fill="#ffd166" stroke="' + OUT + '" stroke-width="2"/>';
      o += '<ellipse cx="43.5" cy="33" rx="1.8" ry="4.6" fill="' + OUT + '"/>';
      o += '<path d="M33 27l12 -3" stroke="' + OUT + '" stroke-width="3" stroke-linecap="round"/>';
      o += '<path d="M44 49l3 5 3 -4 3 4 2 -6" fill="none" stroke="#fff7e6" stroke-width="2.4" stroke-linejoin="round"/>';
      o += '<circle cx="55" cy="40" r="1.6" fill="' + OUT + '"/>';
      return o;
    }

    function buoy() {
      return '<path d="M-6 6h12l-2.2 -11h-7.6z" fill="#e5484d" stroke="' + OUT + '" stroke-width="1.6" stroke-linejoin="round"/>' +
        '<path d="M-4.9 0.3h9.8" stroke="#fff7e6" stroke-width="2.6"/>' +
        '<path d="M0 -5v-4" stroke="' + OUT + '" stroke-width="1.6"/>' +
        '<circle class="buoy-light" cx="0" cy="-10.5" r="2.4" fill="#ffd166" stroke="' + OUT + '" stroke-width="1.2"/>' +
        '<path d="M-10 7.5q2.5 -2 5 0t5 0t5 0t5 0" fill="none" stroke="rgba(233,241,247,.55)" stroke-width="1.2" stroke-linecap="round"/>';
    }
    function wreck() {
      return '<path d="M-7 4l5 -5M1 5l6 -7M-2 6h7" stroke="#6d7d8c" stroke-width="2" stroke-linecap="round"/><circle cx="-4" cy="-4" r="1.2" fill="none" stroke="rgba(233,241,247,.5)"/><circle cx="3" cy="-7" r="1.6" fill="none" stroke="rgba(233,241,247,.5)"/>';
    }
    function palm(x, y) {
      return '<path d="M' + x + " " + (y + 6) + "q1 -6 -2 -11" + '" fill="none" stroke="#7a5230" stroke-width="2.2" stroke-linecap="round"/>' +
        '<path d="M' + (x - 2) + " " + (y - 5) + "q-6 -3 -9 2q5 -1 9 -2zM" + (x - 2) + " " + (y - 5) + "q5 -5 10 -1q-5 0 -10 1zM" + (x - 2) + " " + (y - 5) + "q-1 -7 4 -8q-2 3 -4 8z" + '" fill="#3fa66b" stroke="' + OUT + '" stroke-width="1" stroke-linejoin="round"/>';
    }
    function rocks(x, y) {
      return '<path d="M' + (x - 8) + " " + (y + 5) + "l3 -7 5 -2 4 4 4 -1 2 6z" + '" fill="#7d7a6a" stroke="' + OUT + '" stroke-width="1.2" stroke-linejoin="round"/><path d="M' + (x - 3) + " " + (y - 1) + "l2 3" + '" stroke="#a6a28c" stroke-width="1"/>';
    }
    function coral(x, y) {
      return '<path d="M' + (x - 6) + " " + (y + 6) + "v-5q0 -3 -2 -5M" + (x - 6) + " " + (y + 1) + "q2 -2 4 -5M" + (x + 3) + " " + (y + 6) + "v-7q0 -2 2 -4M" + (x + 3) + " " + (y + 1) + "q-2 -2 -3 -4" + '" fill="none" stroke="#ff8fa8" stroke-width="1.8" stroke-linecap="round"/>' +
        '<path d="M' + (x + 8) + " " + (y + 6) + "q-2 -5 1 -10" + '" fill="none" stroke="#4fd1c5" stroke-width="1.6" stroke-linecap="round"/>';
    }
    return { boat: boat, leviathan: leviathan, leviathanPortrait: leviathanPortrait, buoy: buoy, wreck: wreck, palm: palm, rocks: rocks, coral: coral, COLORS: COLORS, OUT: OUT };
  })();
  var ART = LevArt;

  var L = window.Leviathan, K = window.Kit, h = K.h, sv = K.s, B = K.blocky;
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

  /* ---------- The crew and the monster ---------- */
  var MONSTER = "Gnasher";
  var CREW = [
    { key: "pip", name: "Pip", boat: "Sonar boat", color: "#5eead4", tool: "Ping", toolTag: "TAP TO PING",
      spec: { skin: "#f2c9a0", shirt: "#1fa59a", collar: "#7ff0e1", hair: "#e0762b", hairStyle: "messy", hat: "headphones", hatColor: "#2f3b4a", hatColor2: "#5eead4", eyes: "wide", mouth: "grin", extras: ["freckles"] },
      blurb: "The youngest on the crew, glued to her headphones. Sails 2. Tap her boat to <b>ping</b>: she hears whether " + MONSTER + " is within 2 tiles.",
      lines: { sail: ["On my way!", "Full speed!", "Zooming!"], yes: ["Contact! It's close!", "Ping! Something BIG!"], no: ["Ping... all clear.", "Just fish down there."], bump: ["Wh-what was THAT?!"], hurt: ["Eek! We're hit!"], sunk: ["Glub glub..."] } },
    { key: "hask", name: "Captain Hask", short: "Hask", boat: "Whaler", color: "#f2b84b", tool: "Harpoon",
      spec: { skin: "#d9a27a", shirt: "#1f3b63", collar: "#f2b84b", buttons: "#f2b84b", hat: "captain", hatColor: "#1b2a44", hatColor2: "#f2b84b", eyes: "patch", brows: "angry", mouth: "smirk", beard: "stubble", beardColor: "#5b4636", extras: ["scar"] },
      blurb: "Lost an eye to " + MONSTER + " years ago and wants it back. His whaler is heavy: it sails only 1. He <b>throws the harpoon 2 or 3 tiles</b>, and sailing straight into " + MONSTER + " <b>rams it</b>, which counts as a hit.",
      lines: { sail: ["Steady as she goes.", "Bring her about."], yes: ["Got you, beast!", "Right in the hide!"], no: ["Blast! Missed.", "Next one's yours."], ram: ["RAMMING SPEED!", "Eat steel!"], bump: ["RAMMING SPEED!"], hurt: ["Is that all you've got?"], sunk: ["Not like this..."] } },
    { key: "marta", name: "Big Marta", short: "Marta", boat: "Trawler", color: "#c4a1ff", tool: "Nets", toolTag: "TAP TO CAST",
      spec: { skin: "#c98b62", shirt: "#7b5cd6", collar: "#c4a1ff", hair: "#f2c14e", hairStyle: "braids", hat: "beanie", hatColor: "#e2574c", hatColor2: "#ffb3a7", eyes: "dot", brows: "raised", mouth: "grin", extras: ["blush"] },
      blurb: "Can haul a net full of tuna one-handed. Sails 2. Tap her boat to <b>cast nets on every tile around her</b>. If " + MONSTER + " is there it's caught and shown, and it can't dash next turn.",
      lines: { sail: ["Heave ho!", "Coming through!"], yes: ["Gotcha, big fella!", "Caught a whopper!"], no: ["Nets came up empty.", "Just seaweed."], bump: ["Something's under us!"], hurt: ["Oi! Watch the paint!"], sunk: ["Save the nets!"] } },
    { key: "lumen", name: "Old Lumen", short: "Lumen", boat: "Lighthouse boat", color: "#fff1c1", tool: "Beam",
      spec: { skin: "#f0d2b6", shirt: "#f2c14e", collar: "#fff1c1", hat: "souwester", hatColor: "#f2c14e", eyes: "dot", brows: "thick", browColor: "#eef2f7", mouth: "smile", beard: "full", beardColor: "#eef2f7", extras: ["glasses"] },
      blurb: "Has kept the light for fifty years and talks to the sea. Sails 2. Tap a <b>lamp</b> to shine a beam 4 tiles in a straight line. " + MONSTER + " can't hide in the light.",
      lines: { sail: ["Mind the rocks.", "Slow and steady."], yes: ["There! In the light!", "I see you, old friend."], no: ["Only waves...", "Dark water. Nothing more."], bump: ["We struck something!"], hurt: ["My lamp!"], sunk: ["The light goes out..."] } }
  ];
  var MONSTER_LINES = { strike: ["RRRAAAH!", "CRUNCH!"], devour: ["*CHOMP*", "Mmm, buoy."], surface: ["*snort*", "*big breath*"], hit: ["GRAAWR?!", "OW! OW!"], snag: ["Grrr... nets!"], spotted: ["Hsss!"], bump: ["HEY!"], win: ["*BURP*"] };
  function pickLine(list) { return list[Math.floor(Math.random() * list.length)]; }
  function face(k) { return '<svg class="face" viewBox="0 0 64 64" aria-hidden="true">' + B.portrait(CREW[k].spec) + "</svg>"; }
  function monsterFace() { return '<svg class="face" viewBox="0 0 64 64" aria-hidden="true">' + ART.leviathanPortrait() + "</svg>"; }
  function crewName(k) { return CREW[k].short || CREW[k].name; }

  var ICON = {
    sail: '<path d="M4 15h16l-3 5H7z"/><path d="M12 3v11M12 4l6 8h-6"/>',
    ping: '<circle cx="12" cy="16" r="1.8" fill="currentColor" stroke="none"/><path d="M8.2 12a5.4 5.4 0 0 1 7.6 0"/><path d="M5.2 8.8a9.6 9.6 0 0 1 13.6 0"/>',
    harpoon: '<path d="M5 19L17.5 6.5"/><path d="M18.5 5.5l-6.2 1.3 4.9 4.9z" fill="currentColor"/><path d="M7.5 18.8l-2.3-2.3"/>',
    net: '<path d="M4 12l8-8 8 8-8 8z"/><path d="M8 8l8 8M16 8l-8 8"/>',
    beam: '<path d="M10.2 20h3.6l-.8-11h-2z" fill="currentColor"/><path d="M9 9h6M12 5.5V9"/><path d="M15.5 10l4.5-2.2M15.5 12.5l4.5 1.8"/>',
    hits: '<path d="M4 20L18 6"/><path d="M19.5 4.5l-6.5 1.4 5.1 5.1z" fill="currentColor"/>',
    kills: '<path d="M4 12c2-5 14-5 16 0-2 5-14 5-16 0z"/><path d="M7 12l2 2 2-2 2 2 2-2 2 2"/>',
    eye: '<path d="M2 12s3.5-7 10-7 10 7 10 7-3.5 7-10 7S2 12 2 12z"/><circle cx="12" cy="12" r="3"/>'
  };
  function icon(name) { return '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">' + ICON[name] + "</svg>"; }

  var TITLE_ART = (function () {
    var o = '<svg viewBox="0 0 300 170" role="img" aria-label="' + MONSTER + ' the Leviathan rising beside the four hunter boats">';
    o += '<defs><radialGradient id="ta-moon" cx="50%" cy="50%" r="50%"><stop offset="0" stop-color="#f4f1e1" stop-opacity=".9"/><stop offset=".35" stop-color="#f4f1e1" stop-opacity=".25"/><stop offset="1" stop-color="#f4f1e1" stop-opacity="0"/></radialGradient></defs>';
    o += '<circle cx="62" cy="40" r="46" fill="url(#ta-moon)"/><circle cx="62" cy="40" r="13" fill="#f4f1e1"/>';
    o += '<g transform="translate(176 98) scale(2.7)">' + ART.leviathan() + "</g>";
    ["sonar", "harpoon", "net", "light"].forEach(function (k, i) {
      o += '<g transform="translate(' + (38 + i * 46 - (i > 1 ? 0 : 0)) + " " + (134 + (i % 2) * 6) + ') scale(1.25)">' + ART.boat(k) + "</g>";
    });
    o += '<path d="M0 158q15-7 30 0t30 0 30 0 30 0 30 0 30 0 30 0 30 0 30 0 30 0" fill="none" stroke="#2a6f8f" stroke-width="3" stroke-linecap="round"/>';
    o += "</svg>";
    return o;
  })();

  var RULES = [
    "<h3>The hunt</h3>",
    "<p>" + MONSTER + " the Leviathan is hiding somewhere in the dark water, and it's hungry. Four hunters have until dawn to stop it.</p>",
    '<div class="crewlist">' + CREW.map(function (c, k) { return '<div class="who">' + face(k) + "<p><b>" + c.name + "</b> · " + c.boat + "<br>" + c.blurb + "</p></div>"; }).join("") + "</div>",
    "<h3>Your turn as the hunters</h3><ul>",
    "<li>Tap a boat, then tap where you want it to go or what you want it to do. That's it.</li>",
    "<li>You get <b>4 orders</b> a turn. Each boat can sail once and use its tool once.</li>",
    "<li>Sailing into " + MONSTER + "'s tile bumps it and shows where it is. If Hask's whaler does it, it's a ram, which counts as a harpoon hit.</li>",
    "<li><b>Undo</b> takes back a sail that didn't find anything.</li></ul>",
    "<h3>" + MONSTER + "'s turn</h3><ul>",
    "<li><b>Swim</b> 1 tile, or stay put. Silent.</li>",
    "<li><b>Dash</b> 2 tiles. Fast, but it leaves a wake where it started.</li>",
    "<li><b>Strike</b> a boat next to it. Boats can take 2 hits.</li>",
    "<li>Swimming onto a buoy eats it. Striking and eating give away where it is, and so does coming up for air every 6th round.</li></ul>",
    "<h3>Who wins</h3>",
    "<p><b>Hunters:</b> 3 harpoon hits, or keep " + MONSTER + " from winning until dawn (the end of round 20).</p>",
    "<p><b>" + MONSTER + ":</b> destroy 4 targets (buoys or boats), or sink Hask's whaler.</p>",
    "<h3>The map</h3><ul><li><b>Islands</b> block everything.</li><li><b>Reefs</b> block boats, but " + MONSTER + " can hide in them.</li><li>It starts somewhere in the top 4 rows.</li></ul>",
    "<h3>The red haze</h3><p>The red haze marks every tile " + MONSTER + " could be on, worked out from every clue so far. Use the eye button to hide it for a harder hunt.</p>",
    '<div class="tip"><b>Hunters:</b> ping or shine before you throw, and keep Hask in the middle of the haze.<br><b>' + MONSTER + ":</b> eat buoys far from Hask, dash to escape a closing trap, and remember you come up for air every 6th round.</div>"
  ].join("");

  var G = {
    state: null, cfg: null, rand: null, viewer: "hunters", locked: false,
    humanMonster: false, humanHunters: false, level: "normal",
    sel: 1, pending: null, haze: true, recap: "", review: false, undo: null, targets: null,
    resolver: null, monsterOpts: null, startPick: false, token: 0, svg: null, layers: {}, bubbles: {}
  };

  /* ---------- Board ---------- */
  function seaColor(i) {
    var r = L.rOf(i), t = r / (L.ROWS - 1);
    var a = [11, 32, 52], b = [16, 49, 76];
    var c = a.map(function (v, j) { return Math.round(v + (b[j] - v) * t + ((L.cOf(i) * 7 + r * 3) % 5 === 0 ? 3 : 0)); });
    return "rgb(" + c.join(",") + ")";
  }

  function buildBoard() {
    var stage = K.$("#stage");
    stage.innerHTML = "";
    var svg = sv("svg", { id: "board", viewBox: "0 0 " + VBW.toFixed(1) + " " + VBH.toFixed(1), role: "img", "aria-label": "The hunting grounds, a hex sea" });
    var tiles = sv("g", { class: "tiles" });
    var st = G.state;
    for (var i = 0; i < L.N; i++) {
      var t = st.terrain[i];
      if (t === L.ISLAND) {
        tiles.appendChild(sv("polygon", { points: hexPts(i, R - 0.6), class: "t-island" }));
      } else {
        tiles.appendChild(sv("polygon", { points: hexPts(i, R - 0.4), class: t === L.REEF ? "t-reef" : "t-sea", fill: t === L.REEF ? null : seaColor(i) }));
        if (t === L.SEA && (L.cOf(i) * 5 + L.rOf(i) * 3) % 7 === 0) {
          tiles.appendChild(sv("path", { d: "M" + (cx(i) - 7).toFixed(1) + " " + (cy(i) + 3).toFixed(1) + "q3.5 -3 7 0t7 0", class: "wave" }));
        }
      }
    }
    var deco = sv("g", { class: "deco" });
    for (var j = 0; j < L.N; j++) {
      var x = cx(j), y = cy(j), g = null;
      if (st.terrain[j] === L.ISLAND) g = sv("g", { transform: "translate(" + x.toFixed(1) + " " + y.toFixed(1) + ")" });
      if (st.terrain[j] === L.REEF) g = sv("g", { transform: "translate(" + x.toFixed(1) + " " + y.toFixed(1) + ") scale(.8)" });
      if (!g) continue;
      g.innerHTML = st.terrain[j] === L.REEF ? ART.coral(0, 0) : ((j * 7) % 3 === 0 ? ART.rocks(0, 2) : ART.palm(1, 0));
      deco.appendChild(g);
    }
    svg.appendChild(tiles);
    svg.appendChild(deco);
    ["marks", "units", "over", "fx", "talk"].forEach(function (name) {
      var g2 = sv("g", { class: name });
      G.layers[name] = g2;
      svg.appendChild(g2);
    });
    var hit = sv("g", { class: "hit-layer" });
    for (var q = 0; q < L.N; q++) hit.appendChild(sv("polygon", { points: hexPts(q, R), "data-i": String(q), fill: "transparent" }));
    hit.addEventListener("click", function (e) {
      var target = e.target.closest ? e.target.closest("polygon") : e.target;
      if (!target || target.getAttribute("data-i") == null) return;
      onTile(+target.getAttribute("data-i"));
    });
    svg.appendChild(hit);
    stage.appendChild(svg);
    G.svg = svg;
    G.bubbles = {};
    buildUnits();
  }

  function shipNode(k) {
    var sh = G.state.ships[k];
    var g = sv("g", { class: "unit ship", "data-ship": String(k) });
    g.appendChild(sv("polygon", { class: "sel", points: hexPts(-1, 0) }));
    var art = sv("g", { class: "boat-art", transform: "translate(0 -1) scale(.88)" });
    art.innerHTML = ART.boat(sh.ability === "ping" ? "sonar" : sh.ability === "beam" ? "light" : sh.ability);
    g.appendChild(art);
    var hp = sv("g", { class: "hp" });
    for (var q = 0; q < L.CFG.shipHP; q++) hp.appendChild(sv("rect", { class: "hp-pip", x: String(-9 + q * 10), y: "13.5", width: "8", height: "3.4", rx: "1.4", fill: CREW[k].color }));
    g.appendChild(hp);
    return g;
  }
  function selHex(node) {
    var pts = [];
    for (var k = 0; k < 6; k++) {
      var a = Math.PI / 180 * (60 * k - 30);
      pts.push(((R - 1.6) * Math.cos(a)).toFixed(2) + "," + ((R - 1.6) * Math.sin(a)).toFixed(2));
    }
    node.querySelector(".sel").setAttribute("points", pts.join(" "));
  }

  function monsterNode() {
    var g = sv("g", { class: "unit monster" });
    g.appendChild(sv("circle", { class: "glow", r: "17" }));
    var art = sv("g", { transform: "translate(0 -1) scale(.9)" });
    art.innerHTML = ART.leviathan();
    g.appendChild(art);
    return g;
  }

  function buildUnits() {
    var u = G.layers.units;
    u.innerHTML = "";
    G.shipNodes = G.state.ships.map(function (sh, k) { var n = shipNode(k); selHex(n); u.appendChild(n); return n; });
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
      var hp = n.querySelectorAll(".hp-pip");
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

  function hexEl(i, cls, rr) { return sv("polygon", { points: hexPts(i, rr || R - 1.6), class: cls }); }

  /* ---------- Speech bubbles ---------- */
  function say(who, pos, text) {
    if (pos < 0 || !G.layers.talk) return;
    var old = G.bubbles[who];
    if (old) old.remove();
    var w = Math.max(34, text.length * 4.7 + 12), bh = 16;
    var x = cx(pos), y = cy(pos) - 24;
    var bx = Math.max(2, Math.min(VBW - w - 2, x - w / 2));
    var flip = y - bh < 2;
    if (flip) y = cy(pos) + 24 + bh;
    var g = sv("g", { class: "bubble" + (who === "monster" ? " monster" : "") });
    g.style.transformOrigin = x.toFixed(1) + "px " + y.toFixed(1) + "px";
    g.appendChild(sv("rect", { x: bx.toFixed(1), y: (y - bh).toFixed(1), width: w.toFixed(1), height: bh, rx: "7" }));
    var tx = Math.max(bx + 8, Math.min(bx + w - 8, x));
    g.appendChild(sv("path", { d: flip ? "M" + (tx - 4) + " " + (y - bh + 0.8) + "l4 -5 4 5z" : "M" + (tx - 4) + " " + (y - 0.8) + "l4 5 4 -5z" }));
    g.appendChild(sv("text", { x: (bx + w / 2).toFixed(1), y: (y - 5).toFixed(1), "text-anchor": "middle", text: text }));
    G.layers.talk.appendChild(g);
    G.bubbles[who] = g;
    setTimeout(function () { if (G.bubbles[who] === g) { g.remove(); delete G.bubbles[who]; } }, 1900);
  }
  function crewSay(k, kind) {
    var c = CREW[k], list = c.lines[kind];
    if (list) say("c" + k, G.state.ships[k].pos, pickLine(list));
  }
  function monsterSay(kind) {
    var st = G.state;
    if (monsterVisible()) say("monster", st.monster.pos, pickLine(MONSTER_LINES[kind]));
  }

  /* ---------- What the selected boat can do ---------- */
  function hunterTargets() {
    var st = G.state, T = { sail: {}, tool: {}, self: null, beams: [], k: G.sel };
    if (G.mode !== "hunters" || !G.resolver || G.locked) return T;
    var k = G.sel, sh = st.ships[k];
    if (!sh || sh.sunk || st.orders < 1) return T;
    if (!sh.moved) {
      var mv = L.shipMoves(st, k);
      Object.keys(mv).forEach(function (t) { T.sail[t] = { type: "move", ship: k, to: +t, path: mv[t] }; });
    }
    if (!sh.acted) {
      var at = L.abilityTargets(st, k);
      if (sh.ability === "ping") T.self = { type: "ping", ship: k };
      else if (sh.ability === "net") T.self = { type: "net", ship: k, target: sh.pos };
      else if (sh.ability === "harpoon") at.forEach(function (t) { T.tool[t] = { type: "harpoon", ship: k, target: t }; });
      else if (sh.ability === "beam") at.forEach(function (d) {
        var tiles = L.beamTiles(st, sh.pos, d);
        T.beams.push({ d: d, tiles: tiles });
        tiles.forEach(function (t) { if (L.dist(sh.pos, t) >= 3 && !T.tool[t]) T.tool[t] = { type: "beam", ship: k, dir: d }; });
      });
    }
    return T;
  }

  function inHaze(t) { var st = G.state; return st.revealedAt >= 0 ? st.revealedAt === t : st.P.indexOf(t) >= 0; }

  function crossMark(g, t, dim) {
    var x = cx(t), y = cy(t);
    g.appendChild(sv("circle", { cx: x.toFixed(1), cy: y.toFixed(1), r: "8", class: "hl-cross-fill" }));
    g.appendChild(sv("circle", { cx: x.toFixed(1), cy: y.toFixed(1), r: "6.5", class: "hl-cross" + (dim ? " dim" : "") }));
    g.appendChild(sv("path", { d: "M" + x.toFixed(1) + " " + (y - 11).toFixed(1) + "v5M" + x.toFixed(1) + " " + (y + 6).toFixed(1) + "v5M" + (x - 11).toFixed(1) + " " + y.toFixed(1) + "h5M" + (x + 6).toFixed(1) + " " + y.toFixed(1) + "h5", class: "hl-cross" + (dim ? " dim" : "") }));
  }

  function tapTag(g, pos, text) {
    var w = text.length * 4.6 + 10, x = cx(pos), y = cy(pos) - 27;
    if (y < 8) y = cy(pos) + 30;
    var bx = Math.max(2, Math.min(VBW - w - 2, x - w / 2));
    var t = sv("g", { class: "tap-tag" });
    t.appendChild(sv("rect", { x: bx.toFixed(1), y: (y - 6).toFixed(1), width: w.toFixed(1), height: "12", rx: "6" }));
    t.appendChild(sv("text", { x: (bx + w / 2).toFixed(1), y: (y + 2.6).toFixed(1), "text-anchor": "middle", text: text }));
    g.appendChild(t);
  }

  /* ---------- Render ---------- */
  function render() {
    var st = G.state;
    if (!st) return;
    var marks = G.layers.marks;
    marks.innerHTML = "";
    var phaseStart = st.phase === "start";
    if (phaseStart && G.viewer === "monster" && G.startPick) L.startZone(st).forEach(function (t) { marks.appendChild(hexEl(t, "hl-start")); });
    var showHaze = !phaseStart && G.haze && !st.winner && !G.review && (G.viewer === "hunters" || G.humanMonster);
    if (showHaze && !(st.revealedAt >= 0 && G.viewer === "hunters")) {
      var weak = st.P.length > 30;
      st.P.forEach(function (t) { marks.appendChild(hexEl(t, "haze" + (weak ? " weak" : ""))); });
    }
    if (st.wake >= 0 && !st.winner) {
      var wg = sv("g", { class: "wake" });
      [6, 11, 16].forEach(function (r, q) { wg.appendChild(sv("circle", { cx: cx(st.wake).toFixed(1), cy: cy(st.wake).toFixed(1), r: String(r), opacity: q === 2 ? ".5" : null })); });
      marks.appendChild(wg);
    }
    st.buoys.forEach(function (b) {
      var g = sv("g", { transform: "translate(" + cx(b.pos).toFixed(1) + " " + (cy(b.pos) + 1).toFixed(1) + ") scale(.85)" });
      g.innerHTML = b.alive ? ART.buoy() : ART.wreck();
      marks.appendChild(g);
    });
    G.targets = hunterTargets();
    renderHighlights(marks);
    G.layers.over.innerHTML = "";
    if (G.review || st.winner) renderTrail(G.layers.over);
    placeUnits(false);
    G.shipNodes.forEach(function (n, k) {
      var sh = st.ships[k];
      var selectable = G.resolver && G.mode === "hunters" && !sh.sunk;
      n.classList.toggle("selected", !!(selectable && G.sel === k));
      n.classList.toggle("done", !sh.sunk && st.phase === "hunters" && sh.moved && sh.acted);
      var strikable = G.mode === "monster" && G.monsterOpts && G.monsterOpts.some(function (o) { return o.type === "strike" && o.ship === k; });
      n.classList.toggle("target-ring", !!strikable);
    });
    renderStatus();
    renderBar();
  }

  function renderHighlights(marks) {
    var st = G.state, T = G.targets;
    if (G.mode === "hunters" && G.resolver && !G.locked) {
      var sh = st.ships[G.sel];
      if (T.self) {
        var area = T.self.type === "ping" ? L.disk(sh.pos, L.CFG.sonarRange) : L.netTiles(st, sh.pos);
        area.forEach(function (t) { if (st.terrain[t] !== L.ISLAND && t !== sh.pos) marks.appendChild(hexEl(t, "hl-area" + (T.self.type === "net" ? " net" : ""), R - 2.2)); });
      }
      T.beams.forEach(function (b) {
        var last = b.tiles[b.tiles.length - 1];
        marks.appendChild(sv("line", { x1: cx(sh.pos).toFixed(1), y1: cy(sh.pos).toFixed(1), x2: cx(last).toFixed(1), y2: cy(last).toFixed(1), class: "hl-beam" }));
        b.tiles.forEach(function (t) { if (L.dist(sh.pos, t) >= 3) marks.appendChild(hexEl(t, "hl-beam-tile", R - 2.4)); });
        var lx = cx(last), ly = cy(last);
        marks.appendChild(sv("circle", { cx: lx.toFixed(1), cy: ly.toFixed(1), r: "6", class: "hl-lamp" }));
        marks.appendChild(sv("path", { d: "M" + (lx - 2.4).toFixed(1) + " " + (ly + 2).toFixed(1) + "h4.8M" + lx.toFixed(1) + " " + (ly - 3.6).toFixed(1) + "v3", stroke: "#0b1622", "stroke-width": "1.4", "stroke-linecap": "round" }));
      });
      var anyHaze = G.haze && st.revealedAt < 0;
      Object.keys(T.tool).forEach(function (t) {
        if (T.tool[t].type !== "harpoon") return;
        var useful = !anyHaze || inHaze(+t);
        if (st.revealedAt >= 0 && +t !== st.revealedAt) return;
        if (useful) crossMark(marks, +t, false);
      });
      Object.keys(T.sail).forEach(function (t) {
        var ram = sh.id === "harpoon" && (st.revealedAt >= 0 ? st.revealedAt === +t : anyHaze && inHaze(+t));
        if (ram) marks.appendChild(hexEl(+t, "hl-ram", R - 3));
        marks.appendChild(sv("circle", { cx: cx(+t).toFixed(1), cy: cy(+t).toFixed(1), r: ram ? "5.5" : "4.6", class: "hl-dot" + (ram ? " ram" : "") }));
      });
      if (T.self) {
        marks.appendChild(sv("circle", { cx: cx(sh.pos).toFixed(1), cy: cy(sh.pos).toFixed(1), r: String(R - 1), class: "hl-self" }));
        tapTag(marks, sh.pos, CREW[G.sel].toolTag);
      }
    }
    if (G.mode === "monster" && G.resolver && !G.locked && G.monsterOpts) {
      G.monsterOpts.forEach(function (o) {
        if (o.type === "swim" && o.to === st.monster.pos) marks.appendChild(sv("circle", { cx: cx(o.to).toFixed(1), cy: cy(o.to).toFixed(1), r: String(R - 2), class: "hl-lurk" }));
        else if (o.type === "swim") marks.appendChild(sv("circle", { cx: cx(o.to).toFixed(1), cy: cy(o.to).toFixed(1), r: "5", class: "hl-swim" }));
        if (o.type === "dash") marks.appendChild(sv("circle", { cx: cx(o.to).toFixed(1), cy: cy(o.to).toFixed(1), r: "5", class: "hl-dash" }));
      });
      if (G.pending) {
        var tile = G.pending.type === "strike" ? st.ships[G.pending.ship].pos : G.pending.to;
        marks.appendChild(hexEl(tile, "hl-pending", R - 2));
      }
    }
    if (G.mode === "start" && G.pending != null) marks.appendChild(hexEl(G.pending, "hl-pending", R - 2));
  }

  function renderTrail(layer) {
    var tr = G.state.monster.trail;
    if (!tr.length) return;
    var d = "";
    tr.forEach(function (p, k) { d += (k ? "L" : "M") + cx(p.pos).toFixed(1) + " " + cy(p.pos).toFixed(1); });
    layer.appendChild(sv("path", { d: d, class: "trail" }));
    var seen = {};
    tr.forEach(function (p) {
      if (seen[p.pos]) return;
      seen[p.pos] = 1;
      layer.appendChild(sv("circle", { cx: cx(p.pos).toFixed(1), cy: cy(p.pos).toFixed(1), r: "6", class: "trail-dot" }));
      layer.appendChild(sv("text", { x: cx(p.pos).toFixed(1), y: (cy(p.pos) + 2.5).toFixed(1), "text-anchor": "middle", class: "trail-num", text: String(p.round) }));
    });
  }

  function renderStatus() {
    var st = G.state;
    var main = "", sub = "";
    if (st.winner) {
      main = st.winner === "hunters" ? "The hunters win" : MONSTER + " wins";
      sub = G.review ? "The red line is " + MONSTER + "'s whole path. Numbers are rounds." : st.reason;
    } else if (st.phase === "start") {
      main = "The hunt begins";
      sub = G.viewer === "monster" ? "Choose where " + MONSTER + " hides" : MONSTER + " is choosing a hiding spot";
    } else {
      var surf = L.CFG.surfaceEvery - (st.round % L.CFG.surfaceEvery);
      if (surf === L.CFG.surfaceEvery) surf = 0;
      main = st.phase === "monster" ? MONSTER + "'s turn" : "Hunters' turn";
      sub = "Round " + st.round + "/" + L.CFG.roundLimit + (surf === 0 ? " · air now" : " · air in " + surf);
    }
    K.$("#st-main").textContent = main;
    K.$("#st-sub").textContent = sub;
    var sc = K.$("#scores");
    sc.innerHTML = "";
    sc.appendChild(h("span", { class: "chip hits", title: "Harpoon hits", html: icon("hits") + "<span>" + st.monster.wounds + "/" + L.CFG.woundsToWin + "</span>" }));
    sc.appendChild(h("span", { class: "chip kills", title: "Targets destroyed", html: icon("kills") + "<span>" + st.monster.kills + "/" + L.CFG.killsToWin + "</span>" }));
    var sky = K.$("#sky");
    if (sky) {
      var n = L.CFG.roundLimit, pct = function (r) { return (100 * (r - 0.5) / n).toFixed(2) + "%"; };
      var html = '<div class="done" style="width:' + pct(Math.min(st.round, n)) + '"></div>';
      for (var r = L.CFG.surfaceEvery; r <= n; r += L.CFG.surfaceEvery) html += '<i class="tick" style="left:' + pct(r) + '"></i>';
      html += '<i class="sun"></i><i class="now" style="left:' + pct(Math.max(1, Math.min(st.round, n))) + '"></i>';
      sky.innerHTML = html;
    }
  }

  /* ---------- Action bar ---------- */
  function hazeButton() {
    return h("button", { class: "eye", type: "button", "aria-pressed": G.haze ? "true" : "false", "aria-label": G.haze ? "Hide the red haze" : "Show the red haze", onclick: function () {
      G.haze = !G.haze; K.store.set("haze", G.haze); K.Sound.play("tap"); render();
    }, html: icon("eye") + "<span>" + (G.state && G.state.phase !== "start" ? G.state.P.length : "") + "</span>" });
  }

  function renderBar() {
    var bar = K.$("#actionbar");
    bar.innerHTML = "";
    var st = G.state;
    if (G.review) {
      bar.appendChild(h("p", { class: "hint-line" }, "The red line is where " + MONSTER + " went. Numbers are rounds."));
      bar.appendChild(h("div", { class: "action-row" },
        h("button", { class: "btn btn-primary", type: "button", onclick: function () { K.Sound.play("select"); restart(); } }, "Rematch"),
        h("button", { class: "btn", type: "button", onclick: function () { K.quit(); } }, "Main menu")));
      return;
    }
    if (G.mode === "start" && G.resolver) {
      bar.appendChild(h("div", { class: "who", html: monsterFace() + '<p class="hint-line" style="margin:0">' + (G.pending == null ? "Tap a red tile in the north to hide there." : "Tap it again, or press Hide here.") + "</p>" }));
      bar.appendChild(h("button", { class: "btn btn-primary btn-wide", type: "button", disabled: G.pending == null, onclick: function () { confirmStart(); } }, "Hide here"));
      return;
    }
    if (G.mode === "monster" && G.resolver) { renderMonsterBar(bar); return; }
    if (G.mode === "hunters" && G.resolver) { renderHunterBar(bar); return; }
    bar.appendChild(h("p", { class: "recap" }, h("span", { html: G.recap || "&nbsp;" })));
    bar.appendChild(crewRow(false));
    var row = h("div", { class: "bar-row" }, h("span", { class: "orders" }, st.phase === "hunters" ? "The hunters are moving" : st.phase === "monster" ? MONSTER + " is moving" : ""));
    if (!st.winner && (G.viewer === "hunters" || G.humanMonster)) row.appendChild(hazeButton());
    bar.appendChild(row);
  }

  function crewRow(active) {
    var st = G.state, row = h("div", { class: "crew" });
    st.ships.forEach(function (sh, k) {
      var c = CREW[k];
      var acts = h("span", { class: "acts" },
        h("i", { class: sh.moved ? "used" : "", title: "Sail", html: icon("sail") }),
        h("i", { class: sh.acted ? "used" : "", title: c.tool, html: icon(sh.ability) }));
      row.appendChild(h("button", {
        class: "crewcard" + (sh.sunk ? " sunk" : "") + (!sh.sunk && st.phase === "hunters" && sh.moved && sh.acted ? " done" : ""), type: "button",
        style: "--cc:" + c.color, "aria-pressed": active && G.sel === k ? "true" : "false", disabled: !active || sh.sunk ? true : null,
        "aria-label": c.name + ", " + c.boat,
        onclick: function () { selectShip(k); }
      }, h("span", { html: face(k) }), h("span", { class: "nm" }, crewName(k)), sh.sunk ? h("span", { class: "acts" }, "sunk") : acts,
        h("span", { class: "hp" }, sh.sunk ? "" : "♥" + sh.hp)));
    });
    return row;
  }

  function hunterHint() {
    var st = G.state, T = G.targets, k = G.sel, sh = st.ships[k], c = CREW[k], nm = crewName(k);
    if (G.recap) return G.recap;
    if (st.orders < 1) return "Out of orders.";
    if (sh.sunk) return "Pick another boat.";
    var canSail = Object.keys(T.sail).length > 0;
    var aim = Object.keys(T.tool).filter(function (t) { return T.tool[t].type !== "harpoon" || !G.haze || inHaze(+t); });
    var canTool = !!T.self || aim.length > 0;
    if (!canSail && !canTool) return "<b>" + nm + "</b> is done this turn. Tap another boat.";
    var parts = [];
    if (canSail) parts.push(sh.id === "harpoon" ? "Tap a dot to sail 1 (a gold dot rams if " + MONSTER + " is there)" : "Tap a dot to sail");
    if (canTool) {
      if (sh.ability === "ping") parts.push("tap Pip's boat to ping");
      else if (sh.ability === "net") parts.push("tap Marta's boat to cast her nets");
      else if (sh.ability === "harpoon") parts.push("tap a target to throw");
      else parts.push("tap a lamp to shine the beam");
    } else if (!sh.acted && sh.ability === "harpoon") parts.push("nothing to throw at from here");
    else if (!sh.acted) parts.push("no clear line for the beam from here");
    var s = parts.join(", ");
    return s.charAt(0).toUpperCase() + s.slice(1) + ".";
  }

  function renderHunterBar(bar) {
    var st = G.state;
    bar.appendChild(h("p", { class: "hint-line" }, h("span", { html: hunterHint() })));
    bar.appendChild(crewRow(true));
    var pips = h("span", { class: "orders" }, "Orders");
    for (var q = 0; q < L.CFG.orders; q++) pips.appendChild(h("i", { class: q < st.orders ? "" : "used" }));
    var right = h("span", { style: "display:flex;gap:6px;align-items:center" }, hazeButton());
    if (G.undo) right.appendChild(h("button", { class: "btn btn-sm", type: "button", onclick: doUndo }, "Undo"));
    right.appendChild(h("button", { class: "btn btn-sm" + (st.orders < 1 ? " btn-primary" : ""), type: "button", onclick: function () { K.Sound.play("tap"); finishHunterTurn(); } }, "End turn"));
    bar.appendChild(h("div", { class: "bar-row" }, pips, right));
  }

  function renderMonsterBar(bar) {
    var st = G.state;
    var p = G.pending;
    var msg;
    if (!p) msg = "Green dot: swim (silent). Gold dot: dash 2 (leaves a wake). Red ring: strike that boat. Ring on you: stay put.";
    else if (p.type === "strike") msg = "Strike " + CREW[p.ship].name + "'s boat? Everyone will see you.";
    else if (p.type === "dash") msg = "Dash here? A wake will show where you started." + (L.buoyAt(st, p.to) ? " You'll eat the buoy and be seen." : "");
    else if (p.to === st.monster.pos) msg = "Stay where you are and lurk.";
    else msg = "Swim here." + (L.buoyAt(st, p.to) ? " You'll eat the buoy and be seen." : "");
    if (st.round % L.CFG.surfaceEvery === 0) msg += " You come up for air after this move.";
    if (st.monster.snagged) msg = "You're tangled in nets: no dashing this turn. " + msg;
    bar.appendChild(h("div", { class: "who", html: monsterFace() + '<p class="hint-line" style="margin:0;text-align:left">' + msg + "</p>" }));
    var row = h("div", { class: "action-row" });
    row.appendChild(h("button", { class: "btn btn-primary", type: "button", disabled: !p, onclick: confirmMonster },
      !p ? "Tap a dot" : p.type === "strike" ? "Strike!" : p.type === "dash" ? "Dash" : p.to === st.monster.pos ? "Lurk" : "Swim"));
    bar.appendChild(row);
    bar.appendChild(h("div", { class: "bar-row" },
      h("div", { class: "legend" },
        h("span", null, h("i", { style: "background:#6ee7b7" }), "Swim"),
        h("span", null, h("i", { style: "background:#fbbf24" }), "Dash"),
        h("span", null, h("i", { style: "background:#ff4f6d" }), "Strike")),
      hazeButton()));
  }

  function selectShip(k) {
    var st = G.state, sh = st.ships[k];
    if (sh.sunk || G.locked) return;
    K.Sound.play("tap");
    G.sel = k;
    G.recap = "";
    render();
  }

  /* ---------- Input ---------- */
  function onTile(i) {
    if (G.locked || !G.resolver) return;
    var st = G.state;
    if (G.mode === "start") {
      if (L.startZone(st).indexOf(i) < 0) { K.Sound.play("error"); K.toast("Hide in the red tiles up north."); return; }
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
      var T = G.targets;
      if (T.tool[i]) { doHunter(T.tool[i]); return; }
      if (T.sail[i]) { doHunter(T.sail[i]); return; }
      var shipHere = L.shipAt(st, i);
      if (shipHere >= 0) {
        if (shipHere === G.sel && T.self) { doHunter(T.self); return; }
        if (shipHere !== G.sel) { selectShip(shipHere); return; }
        return;
      }
      K.Sound.play("error");
    }
  }

  function samePending(a, b) {
    return a.type === b.type && a.to === b.to && a.ship === b.ship;
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

  async function doHunter(order) {
    if (G.locked || !G.resolver) return;
    var snap = order.type === "move" ? L.clone(G.state) : null;
    G.undo = null;
    G.recap = "";
    var ev = await runHunterOrder(order);
    if (ev && snap && !ev.some(function (e) { return e.t === "reveal"; }) && G.resolver && G.mode === "hunters") { G.undo = snap; render(); }
  }

  function doUndo() {
    if (!G.undo || G.locked) return;
    var c = L.clone(G.undo);
    G.undo = null;
    Object.keys(c).forEach(function (key) { G.state[key] = c[key]; });
    K.Sound.play("slide");
    placeUnits(true);
    render();
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

  async function pingFx(k, pos, contact) {
    K.Sound.play("ping");
    var c = sv("circle", { cx: "0", cy: "0", r: (2.6 * HW).toFixed(1), class: "fx-ping" });
    fx(sv("g", { transform: "translate(" + cx(pos).toFixed(1) + " " + cy(pos).toFixed(1) + ")" }, c), 1100);
    await animate(c, [{ transform: "scale(.08)", opacity: 1 }, { transform: "scale(1)", opacity: 0.2 }], 700);
    crewSay(k, contact ? "yes" : "no");
    if (contact) { K.Sound.play("contact"); await K.banner("CONTACT", { tone: "bad", sub: MONSTER + " is within 2 tiles of Pip", ms: 1100 }); }
    else await K.sleep(500);
  }

  async function beamFx(k, from, tiles, found) {
    K.Sound.play("zap");
    if (!tiles.length) return;
    var last = tiles[tiles.length - 1];
    var ln = fx(sv("line", { x1: cx(from).toFixed(1), y1: cy(from).toFixed(1), x2: cx(last).toFixed(1), y2: cy(last).toFixed(1), class: "fx-beam" }), 1300);
    await animate(ln, [{ opacity: 0 }, { opacity: 0.8 }, { opacity: 0.4 }], 600);
    crewSay(k, found ? "yes" : "no");
    if (found) { K.Sound.play("reveal"); monsterSay("spotted"); await K.banner("SPOTTED", { tone: "bad", sub: "Lumen's beam caught " + MONSTER, ms: 1100 }); }
    else await K.sleep(500);
  }

  async function harpoonFx(k, from, target, hit) {
    K.Sound.play("whoosh");
    var ln = fx(sv("line", { x1: cx(from).toFixed(1), y1: cy(from).toFixed(1), x2: cx(from).toFixed(1), y2: cy(from).toFixed(1), class: "fx-harpoon" }), 900);
    if (!K.reduceMotion) {
      for (var q = 1; q <= 8; q++) {
        ln.setAttribute("x2", (cx(from) + (cx(target) - cx(from)) * q / 8).toFixed(1));
        ln.setAttribute("y2", (cy(from) + (cy(target) - cy(from)) * q / 8).toFixed(1));
        await K.sleep(28);
      }
    }
    if (hit) {
      K.Sound.play("hit");
      fx(sv("circle", { cx: cx(target).toFixed(1), cy: cy(target).toFixed(1), r: "18", class: "fx-hit" }), 900);
      K.shake(K.$("#stage")); K.haptic(40);
      crewSay(k, "yes"); monsterSay("hit");
      await K.banner("HIT!", { tone: "accent", sub: G.state.monster.wounds + " of " + L.CFG.woundsToWin + " hits", ms: 1200 });
    } else {
      K.Sound.play("splash");
      var sp = sv("circle", { cx: "0", cy: "0", r: "16", class: "fx-splash" });
      fx(sv("g", { transform: "translate(" + cx(target).toFixed(1) + " " + cy(target).toFixed(1) + ")" }, sp), 900);
      crewSay(k, "no");
      await animate(sp, [{ transform: "scale(.25)", opacity: 1 }, { transform: "scale(1)", opacity: 0 }], 500);
    }
  }

  async function netFx(k, tiles, snag) {
    K.Sound.play("whoosh");
    var g = sv("g");
    tiles.forEach(function (t) { g.appendChild(hexEl(t, "fx-net", R - 3)); });
    fx(g, 900);
    await animate(g, [{ opacity: 0 }, { opacity: 1 }, { opacity: 0.2 }], 700);
    crewSay(k, snag ? "yes" : "no");
    if (snag) { K.Sound.play("roar"); K.shake(K.$("#stage")); monsterSay("snag"); await K.banner("CAUGHT", { tone: "accent", sub: MONSTER + " can't dash next turn", ms: 1200 }); }
  }

  async function ramFx(k, at, from) {
    var n = G.shipNodes[k];
    var x0 = cx(from), y0 = cy(from), x1 = cx(at), y1 = cy(at);
    crewSay(k, "ram");
    await animate(n, [{ transform: "translate(" + x0 + "px," + y0 + "px)" }, { transform: "translate(" + (x0 + (x1 - x0) * 0.45) + "px," + (y0 + (y1 - y0) * 0.45) + "px)" }, { transform: "translate(" + x0 + "px," + y0 + "px)" }], 420);
    render();
    K.Sound.play("hit"); K.shake(K.$("#stage")); K.haptic(50);
    monsterSay("hit");
    await K.banner("RAMMED!", { tone: "accent", sub: G.state.monster.wounds + " of " + L.CFG.woundsToWin + " hits", ms: 1200 });
  }

  /* Hunter events, seen by whoever is looking. */
  async function animateHunterEvents(ev) {
    for (var q = 0; q < ev.length; q++) {
      var e = ev[q];
      if (e.t === "move") {
        if (e.path.length) { crewSay(e.ship, "sail"); await slideShip(e.ship, e.path); }
      } else if (e.t === "bump") {
        render();
        crewSay(e.ship, "bump"); monsterSay("bump");
        K.Sound.play("roar"); K.shake(K.$("#stage")); K.haptic(30);
        await K.banner("BUMP!", { tone: "bad", sub: "Something huge is right there", ms: 1200 });
      } else if (e.t === "ram") { await ramFx(e.ship, e.at, e.stop); }
      else if (e.t === "ping") { render(); await pingFx(e.ship, e.at, e.contact); }
      else if (e.t === "beam") { render(); await beamFx(e.ship, e.from, e.tiles, e.found); }
      else if (e.t === "harpoon") { await harpoonFx(e.ship, e.from, e.target, e.hit); }
      else if (e.t === "net") { render(); await netFx(e.ship, e.tiles, e.snag); }
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
        else if (!revealed) lines.push(MONSTER + " swam somewhere. The haze spreads.");
      } else if (e.t === "dash") {
        if (!publicOnly) { setPos(G.monsterNode, e.to, false); K.Sound.play("whoosh"); await K.sleep(380); }
        else { if (!revealed) lines.push("<b>A wake!</b> " + MONSTER + " dashed 2 tiles away from the rings."); render(); K.Sound.play("splash"); await K.sleep(500); }
      } else if (e.t === "strike") {
        render();
        K.Sound.play("hit"); K.shake(K.$("#stage")); K.haptic(50);
        monsterSay("strike");
        setTimeout(function () { crewSay(e.ship, "hurt"); }, 650);
        await K.banner("STRIKE!", { tone: "bad", sub: CREW[e.ship].name + "'s boat is hit", ms: 1300 });
      } else if (e.t === "sunk") {
        render();
        K.Sound.play("splash");
        crewSay(e.ship, "sunk");
        await K.banner("SUNK", { tone: "bad", sub: CREW[e.ship].name + "'s boat went down", ms: 1300 });
      } else if (e.t === "devour") {
        render();
        K.Sound.play("roar"); K.shake(K.$("#stage"));
        monsterSay("devour");
        await K.banner("CHOMP!", { tone: "bad", sub: MONSTER + " ate a buoy", ms: 1300 });
      } else if (e.t === "reveal" && e.why === "surface") {
        render();
        K.Sound.play("roar");
        monsterSay("surface");
        await K.banner("SURFACED", { tone: "bad", sub: "Every 6th round it comes up for air", ms: 1300 });
      }
    }
    G.recap = lines.join(" ");
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
    var r = G.resolver; G.resolver = null; G.mode = null; G.undo = null;
    r();
  }

  function shipHasWork(st, k) {
    var sh = st.ships[k];
    if (sh.sunk || st.orders < 1) return false;
    if (!sh.moved && Object.keys(L.shipMoves(st, k)).length) return true;
    if (!sh.acted && L.abilityTargets(st, k).length) return true;
    return false;
  }

  async function runHunterOrder(order) {
    var token = G.token;
    G.locked = true;
    render();
    var ev = L.applyHunter(G.state, order);
    await animateHunterEvents(ev);
    if (token !== G.token) return null;
    G.locked = false;
    var st = G.state;
    if (st.winner || st.orders < 1 || !L.hasAnyOrder(st)) {
      render();
      await K.sleep(500);
      if (token !== G.token) return ev;
      finishHunterTurn();
      return ev;
    }
    if (!shipHasWork(st, G.sel)) {
      for (var j = 1; j <= st.ships.length; j++) { var k = (G.sel + j) % st.ships.length; if (shipHasWork(st, k)) { G.sel = k; break; } }
    }
    render();
    return ev;
  }

  async function humanHunterTurn() {
    var st = G.state;
    G.sel = 1;
    if (!shipHasWork(st, 1)) { for (var k = 0; k < st.ships.length; k++) if (shipHasWork(st, k)) { G.sel = k; break; } }
    if (st.ships[G.sel].sunk) G.sel = st.ships.findIndex(function (x) { return !x.sunk; });
    G.undo = null;
    await waitFor("hunters");
  }

  async function botHunterTurn(token) {
    var st = G.state;
    G.mode = null;
    render();
    await K.sleep(500);
    var n = 0;
    while (!st.winner && st.orders > 0 && n++ < 8) {
      if (token !== G.token) return;
      var o = L.bots.hunterOrder(st, G.level, G.rand);
      if (o.type === "end") break;
      K.$("#st-sub").textContent = "Round " + st.round + " · " + describeBot(o);
      await K.sleep(380);
      if (token !== G.token) return;
      var ev = L.applyHunter(st, o);
      await animateHunterEvents(ev);
      await K.sleep(200);
    }
  }
  function describeBot(o) {
    var nm = crewName(o.ship);
    if (o.type === "move") return nm + " sails";
    if (o.type === "ping") return "Pip pings";
    if (o.type === "harpoon") return "Hask throws";
    if (o.type === "net") return "Marta casts her nets";
    return "Lumen shines the beam";
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
      await K.cover({ className: "monster-cover", kicker: "Round " + G.state.round, title: MONSTER + "'s turn", text: "Hunters, look away. " + MONSTER + "'s player, take the phone.", cta: "I'm " + MONSTER, badge: '<div class="badge-row">' + monsterFace() + "</div>" });
    } else {
      await K.cover({ className: "hunter-cover", kicker: "Round " + G.state.round, title: "Hunters' turn", text: MONSTER + "'s player, hand the phone over.", cta: "We're the hunters", badge: '<div class="badge-row">' + CREW.map(function (c, k) { return face(k); }).join("") + "</div>" });
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
    if (st.winner === "monster") monsterSay("win");
    else crewSay(1, "yes");
    var youWon = null;
    if (G.cfg.mode === "bot") youWon = (st.winner === "hunters") === (G.cfg.side === "hunters");
    await K.banner(st.winner === "hunters" ? "HUNTERS WIN" : MONSTER.toUpperCase() + " WINS", { tone: st.winner === "hunters" ? "accent" : "bad", ms: 1500 });
    if (token !== G.token) return;
    var title = G.cfg.mode === "bot" ? (youWon ? "You win!" : "You lose") : (st.winner === "hunters" ? "The hunters win" : MONSTER + " wins");
    var choice = await K.gameOver({
      title: title,
      tone: youWon === false ? "bad" : "good",
      text: st.reason,
      stats: [["Harpoon hits", st.monster.wounds + " / " + L.CFG.woundsToWin], ["Targets destroyed", st.monster.kills + " / " + L.CFG.killsToWin], ["Rounds played", st.round]],
      reviewLabel: "See " + MONSTER + "'s path"
    });
    if (token !== G.token) return;
    if (choice === "rematch") restart();
    else if (choice === "review") { G.review = true; render(); }
  }

  /* ---------- Lifecycle ---------- */
  function start(cfg) {
    G.cfg = cfg;
    G.level = cfg.difficulty || "normal";
    G.haze = K.store.get("haze", true) !== false;
    var local = cfg.mode === "local";
    G.humanMonster = local || cfg.side === "monster";
    G.humanHunters = local || cfg.side !== "monster";
    newMatch();
  }

  function newMatch() {
    G.token++;
    var seed = (Date.now() ^ Math.floor(Math.random() * 1e9)) >>> 0;
    G.state = L.newGame(seed);
    G.rand = L.rng(seed ^ 0x5bd1e995);
    G.review = false; G.pending = null; G.resolver = null; G.mode = null; G.locked = false; G.recap = ""; G.undo = null;
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

  window.__leviathanDebug = { G: G, runHunterOrder: runHunterOrder, doHunter: doHunter, CREW: CREW };

  K.init({
    ns: "leviathan-hunt",
    title: "Leviathan Hunt",
    tagline: "Four hunters. One hungry Leviathan. Find " + MONSTER + " before dawn.",
    art: TITLE_ART,
    rules: RULES,
    options: [
      { id: "mode", label: "Opponent", default: "bot", choices: [{ v: "bot", t: "Bot" }, { v: "local", t: "Friend, same phone" }],
        note: function (c) { return c.mode === "local" ? "One of you is " + MONSTER + ", the other runs the hunters. Cover screens keep " + MONSTER + " hidden." : null; } },
      { id: "side", label: "You play", default: "hunters", choices: [{ v: "hunters", t: "The hunters" }, { v: "monster", t: MONSTER }], showIf: function (c) { return c.mode === "bot"; } },
      { id: "difficulty", label: "Bot level", default: "normal", choices: [{ v: "easy", t: "Easy" }, { v: "normal", t: "Normal" }, { v: "hard", t: "Hard" }], showIf: function (c) { return c.mode === "bot"; },
        note: function (c) { return c.difficulty === "hard" ? "Hard bots think a move ahead and read your habits." : c.difficulty === "easy" ? "Easy bots make mistakes. Good for learning." : "A fair fight."; } }
    ],
    onStart: start,
    onRestart: restart,
    onQuit: quit,
    menuNote: function () { return G.state ? "Round " + G.state.round + " of " + L.CFG.roundLimit + "." : ""; }
  });
  (function crewOnTitle() {
    var inner = K.$(".title-inner .title-tag");
    if (!inner) return;
    var row = h("div", { class: "title-crew" });
    CREW.forEach(function (c, k) { row.appendChild(h("figure", { html: face(k) + "<figcaption>" + crewName(k) + "</figcaption>" })); });
    inner.insertAdjacentElement("afterend", row);
  })();
})();
