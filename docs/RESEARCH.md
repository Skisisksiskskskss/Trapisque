# RESEARCH — The Sift canon

Every claim cites a source. The bestiary is in `RESEARCH_BESTIARY.md`; source metadata is in `research/`.

**Confidence** (one scale for this file and the bestiary):
- **H**: official Mojang/Microsoft/Xbox text or in-game text that we read ourselves, or an official image we looked at. `[OBS]` marks our own description of an image.
- **M**:
  - minecraft.wiki text with no conjecture, uncertain or delete flag;
  - first-hand press (tier B: reviews, hands-ons, developer interviews);
  - official words we could read only as quoted by the wiki.
- **L**:
  - flagged wiki text (conjecture, uncertain or delete);
  - lore found only in the novel, or fan tweets;
  - a single tier-C or tier-D press source;
  - a name with no page.

Press tiers A–D rate source quality and are defined in `research/press_sources_2026-09-30.md`; they are not confidence labels. Lines marked *Inference* are our reading of the evidence, not canon. Design decisions live in `DESIGN/`, not here.

**Tags:**
- `[W:Page]` = minecraft.wiki page `Dungeons II:Page`, fetched 2026-09-30.
- `[S-W…]` / `[V:Page]` = main-namespace (vanilla-plans) pages.

Titles and revisions are in `research/wiki_pages_2026-09-30.tsv`.

## 0. Official Java Sift content (§3.3 check, 2026-09-30)
- **Nothing shipped.** We searched the full contents of the 26.3, 26.4-snapshot-1 and 26.4-snapshot-2 client jars. They contain no Sift data, classes, lang keys or experimental packs; the only matches were false positives in base64 under `META-INF`. [S-J1] **H**
- 26.4 ("Fourth Drop 2026") is the ice caves, the frozen zombie and the Freezing effect, not the Sift. [S-W4] **M**
- The Planned versions page lists the Sift under the heading "Unnamed 2027 release": "A version number has not been made public, however an update is planned which will implement the Sift into the base game" [S-W3] **M**
- Announcement (Minecraft LIVE, 2026-09-26): "the newest Minecraft dimension isn’t just finding its home in Dungeons II, it’ll also be coming to Minecraft Java & Bedrock Edition next year." [MC1] **H**. Also: "Mojang Studios confirmed that the Sift will come to Minecraft in 2027" [XW1] **H**
- **Vanilla first look.** The audio description of the stream, quoted by the wiki (we could not open the video): "Under a teal blue sky, tufts of soft orange grasses sit on a hilltop. A tiny rabbitlike blub walks casually through the grasses." [S-W2] **M**
  - [OBS] of the still (S-I1): a flat turquoise sky, coral/salmon grass and ground, a small pale-blue box-bodied Blub with ear tufts, and pale grey-white trees with dark trunks on a distant rise. **H**
- **Blocks visible in that footage.** Only "blub" is an official name; the rest are wiki names:
  - "Green healthy sculk", "Orange healthy sculk";
  - the "Orange sculk grass block" (a "dark salmon colour"), a lighter "baby-pink" variant, and green, short and tall variants;
  - a white-leaved tree.

  Existence **M** / names **L**. [S-W1]
- Decision: not a §3.3 stop → D-002.

## 1. Canon table
| # | Fact | Conf. | vs. §3.1 seed |
|---|---|---|---|
| 1 | Dungeons II launched on 2026-09-29 [MC7]. The Sift comes to Java & Bedrock "next year" [MC1] / "in 2027" [XW1]; "A version number has not been made public" [S-W3] | H (version: M) | confirmed |
| 2 | **Dungeons II's portal is in the Ancient City.**<br>• The "Deep Dark portal", "also known as the Ancient Portal", is "a large structure located with the Ancient City that grants access to the Sift", "activated by the melody of the note block machine" [W:Deep Dark Portal].<br>• A review confirms illagers "head down into the Deep Dark and come across a large portal" [R-GT].<br>• [OBS] of two official images [S-I6, S-I7]: a large dark-stone frame with a wide opening at the centre of a Deep Dark city. A stepped platform in front carries eight note blocks with rainbow-coloured tops. When lit, the rim of the opening glows cyan.<br>• Internal name "Wellspring" (the official short was first titled "Wellspring Gameplay") [W:The Sift] | M (images: H) | confirmed |
| 3 | **Is it the vanilla Ancient City frame?**<br>• A wiki history line dated 2026-03-21: "The ancient city center frame is revealed to be a portal to a new dimension." [W:The Sift]. It is a single uncited line, and the official March recap never mentions a portal [MC4].<br>• The announce trailer "ends in front of the Deep Dark portal as it begins to show signs of activation" [W:Minecraft Dungeons II Announce Trailer].<br>• *Inference:* the Dungeons II portal resembles the vanilla city-centre frame in setting and shape [OBS S-I6, S-I7]. Its opening looks taller than vanilla's 20×6 opening, but perspective makes this uncertain.<br>• **No source says the vanilla frame is, or will be, the Sift's portal in Java** (§6, observation 2) | M (Dungeons II) / L (same structure as vanilla) | new |
| 4 | **The Note Block Machine.**<br>• The portal opens after the **Twisted Warden** is defeated and **three missing note blocks** from across the Overworld are returned.<br>• **Echo golems** use the machine to ignite it; eight note blocks stand before the portal [W:Note Block Machine], [W:Deep Dark Portal].<br>• "The sequence of notes used to activate the portal is shown in a promotional video" [W:Note Block Machine] (2026-05-30; not viewed) | M | expanded |
| 5 | **Rifts** are "temporary portals leading to and from the Sift" [W:Rift].<br>• They are the everyday way in: "there are lots of rifts that appear throughout the world. If you do stumble across and then into one, it will transport you to the Sift." [MC1].<br>• That the Grand Illusioner's staff makes them is novel-sourced [W:The Sift] | H (rifts) / L (the staff) | confirmed + expanded |
| 6 | The Sift is "comprised of red and orange stone, green vegetation, ichor, and sculk" [W:The Sift] | M | confirmed as the wiki's words; see §5 |
| 7 | **Three Sift Tides** (in-game text, S-I2, seen): "There are three tides in the Sift time cycle; Flow, Thrive, and Endure. Flow: No effect. Thrive: Faster Soul regeneration and artifact cooldowns. Endure: More pow[erf]ul mobs will spawn and your passive soul regeneration will stop." The punctuation is as on screen; the mouse cursor hides the letters in [erf] | H | **corrected**: the Tides are a *time cycle*, and their effects are now known |
| 8 | "Shifting tides within the Sift can affect your character and those around you" [XW1]; the Tides "affect soul gathering and traversing" (wiki wording, uncited) [W:The Sift] | H / M | confirmed |
| 9 | **Tide visuals.**<br>• Three official stills of the same view in three lightings [OBS S-I3]: bright pastel day; dark with glowing blue foliage and stars; warm golden light with orange stone.<br>• The *labels* Thrive/Endure/Flow exist only as wiki gallery captions. The official file pages say only "Ambience in the Sift" [S-I3], and another wiki page captions the third still "The Harmonizer in the Sift" [W:Harmonizer].<br>• Independent support that the look changes by Tide: the Sift "flips, visually and mechanically, between different states as you explore" [R-PCG] | images H; which Tide is which L–M | **new** |
| 10 | The official soundtrack gives Sift areas versions titled (Thrive), (Flow) and (Endure), where Overworld areas get (Sunrise), (Day), (Sunset) and (Night) [OST] | H (titles); *Inference* that the Tides stand in for times of day | **new** |
| 11 | **Souls:** a resource from defeated mobs that powers artifacts [W:Soul]. Thrive speeds passive soul regeneration and Endure stops it (row 7) | M / H | expanded |
| 12 | **Ichor:** "a multicolored, thick liquid" that "sets heroes alight with soul fire and drains their souls when they step in it. These effects do not apply to Sift-native mobs." [W:Ichor]<br>• A review: "the water in the Sift will set you on fire" [R-DS] | M | **new** (the named hazard) |
| 13 | **Soul blocks** are "powerful artifacts found in the Sift" [W:Soul Block].<br>• The source is the novel, and so is the idea that the High Council's powers come from them.<br>• That the **Singer** forms them from souls and places them on echo golems rests on a fan tweet in a section the wiki flags as Uncertain | L | **new** |
| 14 | **The Singer.**<br>• "Singers are passive and can only communicate through song, capable of both pacifying wardens and opening the Deep Dark portal with their song." [W:Singer] (cited to the novel; the citation is marked as reconstructed).<br>• The achievement "Friend of the Sift": "Receive the Singer's gift of song" [W:Achievement].<br>• The official short of 2026-08-20 shows its full appearance (not viewed) | L (behaviour) / M (achievement) | confirmed + expanded |
| 15 | **Sculk:** "Corrupted sculk was caused by a disease that originated in the Sift. Despite this, healthy sculk still lives and thrives in the Sift." [W:The Sift] (uncited) | M | confirmed |
| 16 | **Illagers.**<br>• Official: the "Illager High Council" (the Prime Enchanter, the Supreme Evoker and the Grand Illusioner) "possesses a new power" [MC7]. Laura De Llorens: "an environmental crisis, but also, that there was a clear thing you were fighting against" [XW2].<br>• A review: "The illagers take control of Souls" [R-GT].<br>• Wiki: "illagers have invaded the Sift to take advantage of its resources and souls" [W:The Sift].<br>• Achievement: "Drive off the illagers camped near the Echo Den" [W:Achievement] | H / M | confirmed + expanded |
| 17 | **Areas:** Singer's Meadow (the first area; the portal's exit), Lullaby Hills (echo golems), and The Carapace, with its sub-area the Echo Den. Humbler Huskland is a listed location. Eight more area names appear as Tide-suffixed soundtrack titles (§2) | M | expanded |
| 18 | The mobs are "both companions and threats, all unique" [XW1]. They form two hostile groups, **Sifters** (surface) and **Sculkers** (Carapace) [W:Sifter], [W:Sculker] | H / M | corrected: see the bestiary for renamed species |
| 19 | **Bosses:** the Monarch (a sculker), the Sculk Monstrosity, and the Harmonizer (a miniboss, later fought soul-corrupted); miniboss **Dartback** [boss pages].<br>• The final boss, the **Monstrous Opus**, is "battled after the Supreme Evoker is defeated" [W:Monstrous Opus]. No source ties it to the Sift | M | expanded |
| 20 | **Sift achievements:** Brave the Unknown (enter), Note Block Virtuoso (activate the machine), Friend of the Sift, Choir Conductor (wake echo golems), Carapace Explorer (enter a humbler husk), Guardian of the Golems, Wobble Watcher, Regicide (defeat a monarch) [W:Achievement] | M (Steam names) | **new** |
| 21 | *The Rift* (cited by the wiki) is a **novel** by Caleb Zane Huett (Random House Worlds, 2026-09-01). It calls the Sift "a wondrous dimension of peace and calm" [W:The Rift] | M (that the novel exists); its lore is L | **new** (lore source; lower authority than the game) |

## 1a. Seed briefing (mission §3.1) → verdicts
| Seed row | Verdict | Where |
|---|---|---|
| Release | Confirmed: 2026-09-29 [MC7]; "will come to Minecraft in 2027" [XW1]; no version number [S-W3]; access unannounced: "Mojang isn’t talking too much about how to access the Sift" [XW1] | canon #1, §9 |
| Tone & visuals | "colorful new look" [XW1] ✓<br>"breathtaking beauty": official, "an uncharted dimension of threats, mysteries, and breathtaking beauty" [MC3] ✓<br>"beautiful, vibrant, and teeming with souls" [MC1] ✓<br>"a vivid mix of neon blue and pink" is **press wording**, not Mojang's [P-GHACKS] | §5 |
| Materials | Confirmed as the wiki's words; true of one Dungeons II palette, not of the vanilla teaser | canon #6, §5 |
| Rules | Confirmed verbatim [XW1] | §9 |
| Tides | Names confirmed; effects now known (in-game text); they are a **time cycle** (corrected). "Change the look": the images differ, but which Tide is which comes from captions (L–M) | canon #7–10, §3 |
| Souls | Confirmed: "souls begin to fly through the world" [XW1]. In context this describes the Overworld being disrupted at the start of the story, not the Sift | canon #11, §4 |
| Areas | Confirmed: "The Sift contains new biomes – including Meadows and Carapace – but Mojang are keeping other areas a secret" [XW1]; eight more names come from the soundtrack | canon #17, §2 |
| Access (Dungeons II) | Confirmed and expanded: portal + machine (M), rifts (H); the staff is novel-sourced (L) | canon #2–5 |
| Mobs | Quote confirmed [XW1]. Seven listed names are old or variant names: Licker → Slabber, Sculk Mage → Scavenger, Sculk Slasher → Stalker, Snout Sifter → Bloombud, Groobler Sentinel → Pollinator; Grim Blub and Blubberfly are Blub variant captions | bestiary |
| Bosses | Confirmed; expanded with Dartback and the Monstrous Opus (Sift tie unknown) | canon #19, bestiary |
| Characters | Bubbles is a character from the novel. The Singer's "gift of song" is achievement text. Expanded with the novel's visitors | bestiary |
| Lore | Both quotes confirmed as wiki text (M). The invasion is confirmed officially in other words [MC7, XW2] | canon #15–16 |

## 2. Areas (Dungeons II): look and contents
- **Singer's Meadow** [W:Singer's Meadow] **M**:
  - Look: "red sculk, teal grass, and blue trees"; "red sculk blocks beneath tall blue grass"; "towering tree-like growths covered in pale-blue vines".
  - Terrain: "many pools of ichor, fracturing the terrain"; bounded by "walls of darker red sculk". The portal sits on a small hill of red sculk.
  - Inhabitants: the Singer and echo golems; passives Blub, Echo Golem, Slabber and Trill; hostiles Bloombud, Nester, Pollinator and Seedling, plus illagers.
  - The first visit unlocks the Tides tutorial.
  - [OBS] of the portal image [S-I4]: mauve/rose canyon walls, glowing cyan grass, icy-cyan drooping trees, a bright cyan portal and a blocky teal/pink aurora sky. **H**
- **The Carapace** [W:The Carapace], [W:Echo Den] **M**:
  - Look: "a flat, dry biome composed of dark blue stone and vast fields of sand and dust", "red and yellow grass patches".
  - Features: "bouncy slimes used to access higher areas"; "colossal fossils … the largest of these are the humbler husks, which can be entered".
  - Home of the sculkers.
  - Sub-area: the **Echo Den**.
  - [OBS] of [S-I5]: blue-teal stone pillars, pale sand, magenta and yellow coral-like grass, and the same aurora sky. **H**
- **Lullaby Hills**: "contains echo golems"; a quest wakes them ("Choir Conductor"). Nothing else is known. [W:Lullaby Hills] **M**
- **Humbler Huskland** has three kinds of evidence:
  - a listed location [W:Location];
  - its own Tide-suffixed tracks [OST];
  - a guide: "You will want to pass through the Musical Gate to reach Humbler Huskland" [P-SK3], on the Sculk Monstrosity questline in the Meadow.

  Whether it is part of the Carapace is **unknown** (§7).
- **Named only by soundtrack titles with Tide suffixes:** Wild Meadows, Ravaged Meadow, Radiant Ravines, Mites, Hollowed Islands, Humbler Huskland, Illager Stronghold, Illager Keep [OST]. The titles are **H**; that these are places is **L**.

## 3. Tides: what is known, what isn't
- **Known:**
  - Three Tides form a time cycle (**H**).
  - Flow has no effect.
  - Thrive speeds soul regeneration and artifact cooldowns.
  - Endure spawns more powerful mobs and stops passive soul regeneration (**H**).
  - They affect traversal (**M**, wiki wording).
  - The look changes between states (**H** images, plus [R-PCG] **M**).
  - Areas have Tide music variants (**H** titles).
- **Unknown:**
  - which still shows which Tide (the captions are L–M);
  - order and duration;
  - triggers other than time;
  - whether all areas shift together;
  - what "traversing" changes mean mechanically.

## 4. Souls, sculk, sound
- **Souls** are the Sift's key resource [W:Soul] **M**. Official text: souls power artifacts, and the illagers' new power drives the plot [MC7] **H**.
  - Ichor and soul fire drain them [W:Ichor] **M**.
  - Sculker attacks use them as soul projectiles, soul-fire pools and soul-flame charges [W:Scavenger], [W:Sculk Monstrosity] **M**.
  - The claim that the Singer gathers souls by singing and condenses them into soul blocks is **L** (canon #13).
- **Vanilla fact (not canon):** sculk catalysts already turn a nearby death's XP into sculk charge and bloom `sculk_soul` particles (VANILLA_ANALOGS E4, from the 26.3 source). **H**
- **Healthy vs corrupted sculk:** corrupted sculk is a disease of the Sift's healthy sculk (canon #15). The vanilla first look shows healthy sculk as green, orange and salmon/pink ground and grass (§0). No text describes gameplay differences. **M**
- **Sound and music are structural:**
  - The portal is opened by a melody (the note block machine) (**M**) or a Singer's song (**L**).
  - A "musical gate" is on the Monarch quest route [W:Wrath of the Sculkers].
  - The Harmonizer attacks with shockwave screeches [W:Harmonizer].
  - Reviewers hear creatures "seemingly conversing through melodies" [R-GA].
  - Many names are musical: Lullaby, Choir, Tuner, Harmonizer, Opus, Crescendo.

  → The owner's §3.2 observation 1 is **supported**.

## 5. Palette evidence and the colour contradiction
- **"Neon blue and pink" is press wording.** No official text we read contains it.
  - Earliest found: Game Rant, 2026-09-26 20:03 UTC: "The Sift is a vibrant mix of neon blue and pink that Mojang describes as beautiful, vibrant, and teeming with souls." [P-GRANT]
  - The seed's exact words match gHacks, 21:08 UTC: "The dimension uses a vivid mix of neon blue and pink" [P-GHACKS]
  - TechJuice attributes the phrase to Mojang: "Mojang describes the vanilla version of the Sift as a vibrant mix of neon blue and pink." [P-TJ] We found no official source for that.
  - The official recap says only "beautiful, vibrant, and teeming with souls" [MC1].
- **Press describes the vanilla teaser as pink and turquoise:** "tufts of pink grass beneath a turquoise sky" [P-PCGAMER]; "candy-colored pink and turquoise tones" [P-80LV].
- **The official audio description calls the same grass orange:** "tufts of soft orange grasses" [S-W2]. The wiki names the blocks "Orange healthy sculk" and "Orange sculk grass block", with a "dark salmon colour" [S-W1]. Our look at the still shows coral/salmon [OBS S-I1]. So "pink" versus "orange" is partly two names for one salmon colour.
- **"Red and orange stone, green vegetation, ichor, and sculk" is the wiki's line about the Dungeons II Sift** [W:The Sift], repeated by guides [P-SK1], which may be derived from the wiki.
- **Dungeons II shows at least two palettes in official images:**
  1. Rose/crimson stone, icy-turquoise foliage and an aurora sky. Official alt text: "Glowing blue portal surrounded by icy turquoise vegetation in a colorful canyon landscape." [MC1]
  2. Orange/terracotta stone, green vegetation, and purple and rainbow liquids (Xbox Wire screenshot `Wellspring_01` [XW3]).

  The three ambience stills add a pastel, an orange and a dark purple lighting of one view [OBS S-I3]. Images **H**; area attribution **M**; Tide attribution **L–M**.
- **Verdict on the contradiction:** the two seed descriptions mostly describe different things. One is press shorthand for the vanilla teaser (pink/turquoise, officially "soft orange"); the other is the wiki's summary of the Dungeons II Sift (red/orange stone). The palette also varies by area and by lighting state. **M**
- **Official adjectives:**
  - "colorful new look" [XW1]; "beautiful, vibrant, and teeming with souls" [MC1]; "unique hues and pastel-infused design" [XW3].
  - Reviewers: "blue-pink world" [R-KOT]; "almost looks like the Nether in the negative" [R-GT]; "coral-hued environments peppered with inviting yet corrosive pools" [R-GA].
- On the wiki, "neon" appears only for soul-corrupted Overworld mobs in the reveal trailer, never for Sift terrain [W:Minecraft Dungeons II Reveal Trailer].

## 6. The owner's §3.2 observations: verdicts
| # | Observation | Verdict | Evidence |
|---|---|---|---|
| 1 | Sound and music run through everything | **Supported** | §4 |
| 2 | The Deep Dark is the doorway; consider the Ancient City frame | **Supported for Dungeons II; open for Java.**<br>• In Dungeons II the story portal sits at the centre of the Ancient City and resembles the vanilla frame (M, canon #2–4).<br>• Rifts are Dungeons II's everyday way in (H, canon #5, §9).<br>• For Java, "Mojang isn’t talking too much about how to access the Sift" [XW1]. Nothing official ties the vanilla frame to the vanilla Sift (canon #3 is one uncited wiki line).<br>• Using the frame is therefore a design choice grounded in Dungeons II, not a Java fact.<br>• One fan mod on 26.3 already uses it (§8) | canon #2–5, §8, §9 |
| 3 | Souls already exist in vanilla (catalyst `sculk_soul`, soul sand and fire, XP) | **Supported:** souls are the Sift's resource, and the vanilla catalyst turns death XP into sculk charge | §4 |
| 4 | Illagers are the invaders | **Supported:** the High Council and the invasion (official), camps (achievement text) | canon #16 |
| 5 | Genre translation is needed | **Consistent with the evidence:** the documented behaviours (homing barrages, summon waves, ally-buff beams, afterimages) are isometric-action patterns with no direct vanilla analogue. *How* to translate is a design call (Phase 2) | bestiary |
| 6 | Colours vary by area or Tide | **Supported for area** (images H, attribution M). **Partly supported for Tide:** three official stills show one view in three lightings, but which Tide each shows comes from captions (L–M). A review says the Sift "flips, visually and mechanically" [R-PCG] | §5, canon #9 |

## 7. Contradictions and ambiguities
1. **Colour wording** (neon blue and pink vs red/orange stone): mostly different subjects; see §5.
2. **Where the Harmonizer's mission "Wading Rainy Plains" takes place:** the Sift (Harmonizer page) vs the Overworld (Quest page). [W:Harmonizer], [W:Quest]
3. **Boss list:** the Sift page calls the Harmonizer a boss but files it under minibosses. [W:The Sift]
4. **Illager origin:** one echo golem killed [W:Soul Block] vs three [W:Illager].
5. **Monarch location, three answers:**
   - a sculker nest in the Carapace [W:Monarch];
   - a quest filed under Singer's Meadow [W:Wrath of the Sculkers];
   - "in the Sift dimension, in the Ravines region" [P-SK4].
6. **Hunter vs Monarch summons:** the Hunter page says it "can be summoned by the Monarch" [W:Hunter], but the Monarch page lists only "two stalkers and two scavengers" [W:Monarch].
7. **Tone:**
   - Serene: "a bit peaceful - serene, almost" [I-PCG1]; "a wondrous dimension of peace and calm" (novel) [W:The Rift].
   - Threatening: "an uncharted dimension of threats, mysteries, and breathtaking beauty" [MC3].
   - De Llorens reconciles the two: "didn’t feel necessarily threatening or necessarily very benevolent" [XW2].
8. **Species names changed at launch:** Licker → Slabber, Sculk Mage → Scavenger, Sculk Slasher → Stalker, Snout Sifter → Bloombud, Groobler Sentinel → Pollinator. The §3.1 seed list uses the old names. [W:* redirects]
9. **The Grand Illusioner's stronghold:** "While visiting the Sift, the Grand Illusioner's stronghold was raided" [W:Grand Illusioner]. The novel's setting list places the stronghold in the Overworld, under Mountain [W:The Rift]. This is probably a dangling modifier (the Illusioner was away in the Sift) rather than a real conflict.
10. **Procedural vs fixed areas:** "the Sift, a procedurally generated and suitably enigmatic new dimension" [R-PU]. Official copy names fixed areas [XW1] and speaks of "caves and forgotten ruins whose layouts can vary between visits" [MC3]. This may be true of rift runs only.
11. **Humbler Huskland:** it has its own location entry and tracks, and is reached through the Musical Gate on the Meadow questline (§2), yet humbler husks are Carapace fossils [W:The Carapace]. Whether it is part of the Carapace is unknown.
12. **Tide difficulty order:** "the difficulty rises with each" of "Flow, Thrive, and Endure" [P-BB4], against four sources saying Thrive is the easy Tide [R-PU, P-BB3, R-PCG, R-GRP] and the in-game text (canon #7).
13. **Singer colour:** "pale green bodies" (novel previews) [P-BB1] vs "gray" (low-reliability source) [D-JOY].
14. **A Sniffer in the Sift?** "the Sniffer, one of Minecraft’s newer mobs, is also in the Sift" [P-AG] (tier C, single source). No other source mentions it. It may be a misidentified Slabber (then called the Licker), which a low-reliability blog calls "a sniffer cousin" [D-JOY]. Unresolved.

## 8. Prior art: existing fan mods (competitive context, not canon)
Metadata and quotes come from Modrinth, 2026-09-30: `research/prior_art_2026-09-30.md` (IDs PA-1…3).

| ID | Mod | What it does | Runs on 26.3? |
|---|---|---|---|
| PA-1 | **Mielon's The Sift** (mod id **`the_sift`**, MIT, ~48k downloads) | An Ancient City portal opened with "Note Blocks placed on Sonorous Deepslate in Note mode", each with "8 different Sift notes"; "awaken it with sound"; "10 biomes" [PA-1] | **Yes** (1.20.1–26.3) |
| PA-2 | **Deeper and Darker** (`deeperdarker`, AGPL-3.0, ~15.7M downloads) | "the Otherside": "To enter the Otherside, kill the warden and use its heart." [PA-2] That the heart lights the Ancient City frame is our unverified recollection (L) | No (newest 1.21.1) |
| PA-3 | **Sculk Depths** (`sculk-depths`, custom licence, ~112k downloads) | "a new dimension accessed via the ancient cities in the deep dark biome"; items used "on the pedestals near the center of the city to activate the portal" [PA-3] | No (newest 1.21.1) |

- We did not read or reuse their code or assets. For `the_sift` we read only `fabric.mod.json` from its 26.3 jar, to rule out an id collision (theirs is `the_sift`, ours `thesift`), then deleted the jar.

## 9. Official and press sources (WP-003 part 2)
**Coverage.**
- 90 sources read: 22 official, 20 reviews or interviews, 36 news items or guides, and 12 low-reliability sources, which we cite only as leads.
- In the working notes, 558 quoted passages were machine-checked against the saved page text, with 0 mismatches.
- The quotes in this file and the bestiary were checked the same way (see PLAN WP-003 log).
- Page text is not committed (third-party copyright); only metadata is.

**Key additions:**
- **Design intent (the strongest guidance we have).**
  - Måns Olson, reported by PCGamesN [I-PCG1] **M**:
    - The Nether and End "are very hostile and imposing".
    - For the Sift, Mojang "really wanted to make something that felt a bit peaceful - serene, almost - and that gave a very different color palette for players to enjoy."
    - "so it’s still a dangerous place for the player to be," … "but it’s not evil."
  - Laura De Llorens, Design Director, speaking officially [XW2] **H**:
    - "The world has its own independent ecosystem. There’s mobs that thrive through things that hurt the player, for instance, but the mobs live there. They’re adapted to that."
    - "didn’t feel necessarily threatening or necessarily very benevolent. It’s just its own independent thing"
- **Rules.**
  - Official: "once you enter, new rules to learn. Shifting tides within the Sift can affect your character and those around you; hazardous new blocks will alter how you approach exploration" [XW1] **H**.
  - Reviewers **M**:
    - "it flips, visually and mechanically, between different states as you explore, making your life easier in the Thrive but dropping more punishing mobs upon you when the Endure tide hits" [R-PCG];
    - "time-limited, global modifiers called 'Sift Tides'" [R-GRP];
    - "the water in the Sift will set you on fire" [R-DS].
- **Soundtrack structure:** canon #10. The titles are **H**; reading the Tides as the Sift's stand-in for times of day is *Inference* (M).
- **Access in Dungeons II.**
  - Rifts are the everyday way in [MC1] **H**. Rift runs are short and the rift closes behind you [R-KOT] **M**.
  - The Deep Dark portal is the story portal, opened with the Note Block Machine.
  - Steam global achievement rates on 2026-09-30 [ST3]: "Note Block Virtuoso" 2.9% vs "Brave the Unknown" 77.7% (enter the Sift). The snapshot was taken **one day after launch**, so it shows the order players meet things (rifts early, the portal late), not how often each is used. **H** (numbers)
- **Java/Bedrock:** "the Sift will come to Minecraft in 2027"; "While Mojang isn’t talking too much about how to access the Sift, or how it will stand out from Dungeons II’s expression of it, we did get a brief in-development look" [XW1] **H**.
- **Creatures.**
  - The Blub has "become somewhat of the dimension's mascot, similar to the Ghast in the Nether or the Endermen of the End" [P-GRANT] **L** (tier C).
  - "the blue bunnies! … they like to jump on top of one another to form teetering towers that occasionally topple over" [R-KOT] **M**. Kotaku doesn't name them; that they are Blubs is our reading.
  - In the vanilla clip, "bunny-like creatures that walk rather than hop" [P-PCGAMER].
  - IGN mentions "goat things" and "dancing automatons roaming about" without naming species [R-IGN]. Matching them to species would be a guess.
  - Singers have "pale green bodies, shaggy fur, tiny faces on their elongated necks, pale antlers, short legs, and long arms" [P-BB1] **L** (from novel previews).
  - Creatures are "seemingly conversing through melodies" [R-GA] **M**.
- **Lore.**
  - Official [XW2, MC7] **H**: an "environmental crisis" and a clear enemy, the Illager High Council (the Prime Enchanter, the Supreme Evoker and the Grand Illusioner), which "possesses a new power".
  - "The illagers take control of Souls" [R-GT] **M**.
  - Side quest "Breaking Camps" (illager camps) [P-GSC2].
  - Track titles "Caged", "Soul Crisis", "Song of Healing", "Illager Stronghold (Thrive)", "Illager Keep (Thrive)" [OST] **H**.
- **Endgame in Dungeons II:** Soul Storms, timed zones with stronger mobs and generators to destroy [I-PCG2, R-PCG]. This is specific to Dungeons II.
- **Contradictions found in this pass** are in §7 (#10, #12, #13, #14).
- **Not reachable:**
  - GameSpot's review and interviews, TheSixthAxis, Neowin, Mobalytics;
  - YouTube video pages and transcripts (CAPTCHA).

  We found no official patch notes in the sources we searched.

## 10. Unknowns (and what would resolve them)
- **Tide order, duration and triggers:** community gameplay documentation; revisit in Phase 2.
- **Which still shows which Tide:** a first-hand video, or someone who owns the game.
- **The note sequence that opens the portal:** shown in a promotional video (YouTube `PIRZC4Zlp2M`, 2026-05-30) that we could not open.
- **The Singer's appearance:** revealed in an official short (YouTube `ypJN_cWKFo0`, public on 2026-08-20) that we could not open. Only novel-preview text is available [P-BB1].
- **Healthy vs corrupted sculk visuals and mechanics:** more footage; vanilla news in 2027.
- **Names and behaviour** of the Nuzzle, Fusefly, Hurler and Roamroot; official names of the Antenna Sifter and Sift Sheep; the "bird-like creatures", the "goat things" and the Sniffer claim (bestiary): wiki updates.
- **The look of Lullaby Hills; other secret areas; whether Humbler Huskland is part of the Carapace:** wiki updates.
- **Anything about the vanilla Sift beyond the first look** (how to reach it, Tides in Java): Mojang's 2027 announcements. Re-check §3.3 at every milestone.
- **Bedrock previews and betas** were not checked for Sift content (Java target). Low priority.

## Sources index
| ID | Source | Accessed |
|---|---|---|
| S-J1 | Client jars 26.3 (sha1 e877b6a0…), 26.4-snapshot-1 (99dea8ec…), 26.4-snapshot-2 (57390e15…) | 2026-09-30 |
| S-W1 | minecraft.wiki "The Sift" (main namespace, planned vanilla content) | 2026-09-30 |
| S-W2 | minecraft.wiki "Blub" (main namespace); quotes the LIVE audio-described stream (YouTube `536FOix4xE4`, t=2755, not reachable by us) | 2026-09-30 |
| S-W3 | minecraft.wiki "Planned versions" (rev. 2026-09-29T08:19Z) | 2026-09-30 |
| S-W4 | minecraft.wiki "Java Edition 26.4" (rev. 2026-09-29T16:22Z) | 2026-09-30 |
| S-I1 | File:The_Sift.png (LIVE still, vanilla), viewed | 2026-09-30 |
| S-I2 | File:Sift_tides_effects.png (Dungeons II tutorial), viewed | 2026-09-30 |
| S-I3 | File:MCD2_Sift_ambience_1/2/3.png (official promo stills, 2026-08-28; the file pages say "Ambience in the Sift"), viewed | 2026-09-30 |
| S-I4 | File:MCD2_Singer's_Meadow_portal.jpg, viewed | 2026-09-30 |
| S-I5 | File:MCD2_Carapace_environment1.jpg, viewed | 2026-09-30 |
| S-I6 | File:Dungeons 2 Screenshot 5.png (Minecraft Launcher asset, Mojang Studios, 2026-03-21), viewed | 2026-09-30 |
| S-I7 | File:Dungeons II Ancient City Portal lit.png (Steam store asset, 2026-03-21), viewed | 2026-09-30 |
| XW1 | Xbox Wire, "Minecraft Dungeons II's New Dimension Coming to Minecraft Java & Bedrock Edition" (J. Skrebels, 2026-09-26) https://news.xbox.com/en-us/2026/09/26/minecraft-new-dimension-sift-dungeons-2/ | 2026-09-30 |
| XW2 | Xbox Wire, Official XBOX Podcast transcript with Laura De Llorens (2026-09-26) https://news.xbox.com/en-us/2026/09/26/minecraft-dungeons-ii-the-sift-new-mechanics-better-exploration-and-more-official-xbox-podcast/ | 2026-09-30 |
| XW3 | Xbox Wire hands-on (M. Nelson, 2026-09-28) https://news.xbox.com/en-us/2026/09/28/how-minecraft-dungeons-iis-interconnected-world-makes-every-journey-an-adventure/ | 2026-09-30 |
| MC1 | minecraft.net "Minecraft Live: September 2026 Recap" (S. Dankis, 2026-09-26) https://www.minecraft.net/en-us/article/mclive_sept2026_recap | 2026-09-30 |
| MC3 | minecraft.net "New gameplay systems in Minecraft Dungeons II" (P. Landin, 2026-08-31) https://www.minecraft.net/en-us/article/minecraft-dungeons-ii-gameplay-systems | 2026-09-30 |
| MC4 | minecraft.net "Minecraft LIVE 2026: The recap" (March; no Sift or portal content) https://www.minecraft.net/en-us/article/mclive_march2026_recap | 2026-09-30 |
| MC7 | minecraft.net "Minecraft Dungeons II is live" (P. Landin, 2026-09-29) https://www.minecraft.net/en-us/article/minecraft-dungeons-ii-is-live | 2026-09-30 |
| OST | Minecraft Dungeons II Original Game Soundtrack track list (Peter Hont; Deezer album 1103573102) | 2026-09-30 |
| ST3 | Steam global achievement percentages, app 1912410 (snapshot one day after launch) | 2026-09-30 |
| I-PCG1 | PCGamesN interview with Måns Olson & Laura De Llorens (K. Allsop, 2026-09-26) https://www.pcgamesn.com/minecraft/the-sift-live-september-2026 | 2026-09-30 |
| R-* / P-* / D-* | Reviews, news, guides and low-reliability leads. The full table with URLs, dates, authors and tiers is in `research/press_sources_2026-09-30.md` (includes P-GHACKS, P-TJ, P-GRANT) | 2026-09-30 |
| PA-1…3 | Modrinth project metadata for three fan mods: `research/prior_art_2026-09-30.md` | 2026-09-30 |
| W:* | minecraft.wiki `Dungeons II:<Page>`: 572 pages fetched 2026-09-30 (all 536 Dungeons II pages plus 36 others). Titles, URLs, revision timestamps and flags are in `research/wiki_pages_2026-09-30.tsv` | 2026-09-30 |
