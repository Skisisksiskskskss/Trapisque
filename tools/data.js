/* Trapisque game content, taken from the Trapisque Rulebook (trapisquebooklet.html).
   Loaded as a plain script in the browser (window.TQ_DATA) and with require() in tests. */
(function (root, factory) {
  var data = factory();
  if (typeof module === 'object' && module.exports) module.exports = data;
  else root.TQ_DATA = data;
})(typeof window !== 'undefined' ? window : globalThis, function () {
  'use strict';

  var FAMILIES = {
    trap: { id: 'trap', name: 'Trap', title: 'Trap tokens' },
    assist: { id: 'assist', name: 'Assist', title: 'Assist tokens' },
    neutral: { id: 'neutral', name: 'Neutral', title: 'Neutral tokens' },
  };

  // Each wheel holds the items of one token family, in this order.
  var ITEMS = [
    { id: 'spike', family: 'trap', name: 'Spike', icon: '🗡️',
      effect: 'Kills the player, forcing them to repeat the current cycle.' },
    { id: 'fire', family: 'trap', name: 'Fire', icon: '🔥',
      effect: 'Makes the player repeat double the cycles on death, or move back double the amount, depending on the trap stepped on. Divides assist items by 2. Burns out after 1 cycle.' },
    { id: 'ice', family: 'trap', name: 'Ice', icon: '🧊',
      effect: "Divides the player's rolls by 2, or removes 1 from the roll if it's an odd number. Melts after 1 cycle." },
    { id: 'mudslide', family: 'trap', name: 'Mudslide', icon: '🛝',
      effect: 'Moves the player back 2 tiles.' },
    { id: 'mud', family: 'trap', name: 'Mud', icon: '🟤',
      effect: 'Moves the player back 1 tile.' },
    { id: 'wall', family: 'trap', name: 'Wall', icon: '🧱',
      effect: "The player can't move past unless they roll more than 4. A player standing exactly on the wall can jump off it." },
    { id: 'snare', family: 'trap', name: 'Snare', icon: '🪢',
      effect: "Skips the player's next turn." },
    { id: 'grog', family: 'trap', name: 'Grog', icon: '👹',
      effect: 'A monster that kills the player unless they roll 4 or more.' },

    { id: 'regeneration', family: 'assist', name: 'Regeneration', icon: '🔋',
      effect: "Regenerates the character's ability." },
    { id: 'bounce', family: 'assist', name: 'Bounce Pad', icon: '🦘',
      effect: 'Moves the player forward 2 tiles.', use: 'Move forward 2 tiles.' },
    { id: 'speed', family: 'assist', name: 'Speed Boost', icon: '⚡',
      effect: "Multiplies the player's roll by 2 when stood on." },
    { id: 'natural', family: 'assist', name: 'Bridge / Key / Boots', icon: '🔑', perMap: true,
      effect: 'Counters natural traps or helps the player in some way.' },
    { id: 'shield', family: 'assist', name: 'Shield', icon: '🛡️',
      effect: 'Makes the player invincible to any trap once.' },
    { id: 'moonwalk', family: 'assist', name: 'Moonwalk', icon: '🌙',
      effect: 'Move backward by any amount from 1 to 3 tiles.', use: 'Move back 1 to 3 tiles.' },

    { id: 'teleporter', family: 'neutral', name: 'Teleporter', icon: '🌀',
      effect: 'If two are placed, they transport the player to the other teleporter.',
      note: 'Cannot be placed within 8 tiles of the treasure.' },
    { id: 'spore', family: 'neutral', name: 'Spore Warper', icon: '🍄',
      effect: "Swaps the player's location with the nearest player." },
    { id: 'conveyor', family: 'neutral', name: 'Conveyor Belt', icon: '⏩',
      effect: 'Moves the player in the direction placed until they are off the conveyor tiles.' },
    { id: 'sands', family: 'neutral', name: 'Shifting Sands', icon: '⏳',
      effect: 'Moves the player forward on even cycles and backward on odd cycles.' },
  ];

  // kind: 'active' abilities are used up and come back; 'always' never run out; 'passive' are never "used".
  var CHARACTERS = [
    { id: 'mage', name: 'Mage', icon: '🧙', kind: 'active', rechargeCycles: 2,
      ability: 'Burns or freezes any player for a turn.',
      recharge: 'Regenerates every 2 cycles, or with a Regeneration card.' },
    { id: 'trapper', name: 'Trapper', icon: '🪤', kind: 'passive', startItems: { family: 'trap', count: 3 },
      ability: 'Starts with 3 random trap cards.',
      recharge: 'Does not regenerate.' },
    { id: 'firestarter', name: 'Fire Starter', icon: '🧨', kind: 'always', startItems: { ids: ['fire'] },
      ability: 'Starts with a Fire card and can burn any player on the same tile. The burn effect is infinite.',
      recharge: 'No cooldown.' },
    { id: 'naturalist', name: 'Naturalist', icon: '🌿', kind: 'passive',
      ability: 'Receives natural traps instead of assist items. Invincible to natural traps, but takes double damage from other traps.',
      recharge: 'Always on.' },
    { id: 'warper', name: 'Warper', icon: '🔮', kind: 'active',
      ability: 'Can swap places with any player once per game.',
      recharge: 'Regenerates with a Regeneration card.' },
    { id: 'overseer', name: 'Overseer', icon: '👁️', kind: 'active', rechargeRounds: 2, goesFirst: true,
      ability: 'Always rolls the dice first, and can move any player forward or backward by 1 tile.',
      recharge: 'Regenerates every 2 rounds.' },
  ];

  // win: 'first' = first player to the target wins; 'team' = a team wins when every member reaches the target.
  var MODES = [
    { id: 'chaos', name: 'Chaos Trapisque', min: 2, max: 6, teams: 0, target: 5, win: 'first',
      summary: '2–6 players, everyone for themselves',
      rules: 'All players race to be the first to reach the treasure 5 times.' },
    { id: 'assist', name: 'Assist Trapisque', min: 4, max: 4, teams: 2, target: 5, win: 'team',
      summary: '4 players in 2 teams of 2',
      rules: 'Teammates help each other. A team wins when both players have collected 5 treasures. After a player finishes, they use their abilities to help their teammate and hinder the other team.' },
    { id: 'factions', name: 'Factions', min: 6, max: 6, teams: 3, target: 5, win: 'team',
      summary: '6 players in 3 teams of 2',
      rules: 'Like Assist Trapisque with three teams. A team wins when both players reach the treasure 5 times. Players use their abilities to help their teammate and hinder the other teams.' },
    { id: 'ww4', name: 'World War Four', min: 6, max: 6, teams: 2, target: 4, win: 'team',
      summary: '6 players in 2 teams of 3, playing to 4',
      rules: 'The team wins when they collectively reach the treasure 4 times. Players use their abilities to help their teammates and hinder the opposing team.' },
  ];

  var MAPS = [
    { id: 'blissful', name: 'Blissful Tricks', icon: '🌊', available: true,
      blurb: 'Floating path on water, 36 tiles',
      theme: 'Floating path on a body of water', tiles: 36,
      feature: 'River traps that can be crossed with bridges.',
      naturalTraps: 'river traps',
      naturalItem: { name: 'Bridge', icon: '🌉', use: 'Cross a river trap.' } },
    { id: 'junction', name: 'Junction Dungeon', icon: '🏰', available: false,
      blurb: 'Spike traps and a gate opened with a key',
      feature: 'Spike traps and a gate that can be opened with a key.',
      naturalTraps: 'spike traps and the gate',
      naturalItem: { name: 'Key', icon: '🔑', use: 'Open the gate.' } },
    { id: 'slimy', name: 'Slimy Snares', icon: '🐌', available: false,
      blurb: 'Slime traps, crossed with boots',
      feature: "Slime traps that divide the player's move by 2, or remove 1 from the roll if it's an odd number. Boots can be used to cross the slime.",
      naturalTraps: 'slime traps',
      naturalItem: { name: 'Boots', icon: '🥾', use: 'Cross the slime.' } },
  ];

  // Player conditions the tracker can switch on and off.
  var STATUSES = [
    { id: 'shield', icon: '🛡️', name: 'Shield', hint: 'Safe from the next trap' },
    { id: 'frozen', icon: '🧊', name: 'Frozen', hint: 'Rolls are halved, odd rolls lose 1' },
    { id: 'burning', icon: '🔥', name: 'Burning', hint: 'Trap penalties are doubled' },
    { id: 'snared', icon: '🪢', name: 'Snared', hint: 'Skips the next turn' },
    { id: 'boost', icon: '⚡', name: 'Speed Boost', hint: 'Next roll is doubled' },
  ];

  var RULES = {
    overview: "Trapisque is a turn-based strategy board game where players must place and cross traps to reach the treasure. Players navigate a 40–50 tile board, collecting tokens and using their character's unique abilities to be the first to gather five treasures.",
    objective: 'Be the first player to collect five treasures by reaching the treasure tile five times.',
    components: [
      ['Game board', '1 double-sided board with different maps: Blissful Tricks, Junction Dungeon and Slimy Snares.'],
      ['Character cards', '6 unique characters.'],
      ['Tokens', 'Trap, Assist and Neutral tokens.'],
      ['Item cards', 'One for each kind of token.'],
      ['Dice', '1 six-sided die.'],
      ['Wheels', '1 for each type of token.'],
    ],
    setup: [
      ['Select a map', 'Choose which map to play on.'],
      ['Place tokens', 'Distribute the tokens on their designated spots on the board.'],
      ['Assign characters', 'Each player draws a Character Card at random.'],
      ['Starting position', 'All players place their characters on the Start tile.'],
      ['Prepare item cards', 'Shuffle the item cards and place them within reach.'],
    ],
    turn: [
      ['Roll the dice', 'Roll the six-sided die to find how many tiles you move.'],
      ['Move your character', 'Move forward the number of tiles rolled.'],
      ['Resolve the tile', 'If you land on a tile with a token, spin the matching wheel and draw the item card for that token.'],
      ['Use item cards', 'Use any item cards you have during your turn.'],
    ],
    winning: 'The first player to reach the treasure tile five times wins. Each time a player reaches the treasure, they return to the Start tile and continue until they gather five treasures.',
    teamPlay: "When a player completes all 5 cycles (4 in World War Four), they keep playing to assist their teammates. Their extra trips don't count toward a teammate's cycles and give no extra benefits.",
    special: [
      ['Teleporters', 'Cannot be placed within 8 tiles of the treasure.'],
      ['Item usage', 'Each turn, players must either move their character or use an item card.'],
      ['Natural traps', 'Each map has its own natural traps. Use items like bridges or keys to get past them.'],
    ],
  };

  return {
    FAMILIES: FAMILIES,
    ITEMS: ITEMS,
    CHARACTERS: CHARACTERS,
    MODES: MODES,
    MAPS: MAPS,
    STATUSES: STATUSES,
    RULES: RULES,
  };
});
