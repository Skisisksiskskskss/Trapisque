"""Verified Roblox asset ids for sounds and meshes.

Sounds: every id here was checked with the Roblox Creator Store API (public,
moderation-approved) and comes from one of three sources:
  * the JJS developer's own uploads (AlsoNot_Tze / "Tze's Shenanigans") - the
    game's real SFX, guaranteed to play inside JJS;
  * Roblox's licensed libraries (ProSoundEffects, APMOfficial) - free to use in
    any experience;
  * a few public sounds used by dozens of community movesets.
Long library sounds are trimmed with SFX START / END / FADE OUT.

Meshes: Roblox mesh assets load in any experience. Shapes were identified
from their thumbnails; scale hints are the SIZE ranges creators use for them
(meshes have very different native sizes, so these hints matter).

Particle textures: every id is a Roblox *Image* asset (AssetTypeId 1, checked
with the economy API - a Decal page number would not render) that several
creators already use as a PARTICLE texture in exported JJS movesets.
"""


class SFX:
    # --- official JJS sounds (Tze) ---
    PUNCH_1 = 95723598539974
    PUNCH_2 = 81751127529448
    PUNCH_3 = 102321170538785
    M1_SWING_JJS = 113209095877671       # "m1 first sfx jjs"
    THIRD_M1_HIT = 119908133360580
    ENERGY_HIT = 17169365111             # used by 32 movesets
    ENERGY_HIT_2 = 17169365331
    ENERGY_WINDUP = 17169364965
    ENERGY_WINDUP_2 = 17169364647
    CLAP = 17156034319                   # Boogie Woogie clap
    CURSED_STRIKE_STARTUP = 16773286492
    CURSED_STRIKE_HIT = 16773286330
    LUCK_CHARGE = 17046377464
    LUCK_DASH = 17046281380
    LUCK_HIT = 17046282624
    WORLD_SLASH = 17053666464
    HOLLOW_PURPLE_SNAP = 15075475525
    RED_MAX_CHARGE = 16828657609
    RED_MAX_SHOOT = 16828657180
    EARTHQUAKE = 18205737353
    EARTHQUAKE_START = 18205736907
    CHARGE = 114191015848865
    FULL_CHARGE_DASH = 110086889584801
    CE_SLAM = 113305253204345            # "ce slam nanami"
    HEAVY_HIT = 75089222303073
    IMPACT_FRAMES = 105961802014473
    PERFECT_HIT = 112426502291350
    WAPAM = 83892455359949
    EXPLOSION_TORNADO = 70550841608303
    RIPPLE_EXPLOSION = 129389928559036   # "energy ripple explosion"
    OUTBURST_EXPLOSION = 83796511190884
    MASS_HIT_IMPACT = 72214797814045
    AMP_IGNITION = 84293649223671        # domain amplification aura ignition
    TAKEDOWN_TELEPORT = 18440678071
    WHOOSH_FIRST = 111770082377892       # "first whoosh naoya"
    WHOOSH_ATTEMPT = 101436171540292
    DASH = 80805627087578
    AIR_SLAMMED = 91193070042368

    # --- widely used public sounds ---
    SWING = 4571259077                   # 64 movesets, public domain
    HIT_KICK_M = 8595975878              # 60 movesets
    HIT_KICK_H = 8595974357
    HIT_KICK_L = 8595975458
    JJS_M1S = 140729829050068
    COMBAT_WHOOSH = 128213617026859
    ROCK_IMPACT = 9118614717             # ProSoundEffects
    MAGIC_BURST = 9116384757             # ProSoundEffects
    WHOOSH_FAST = 9126228977             # ProSoundEffects
    GLASS_BREAK = 6737581315

    # --- bells & gongs (ProSoundEffects / APMOfficial) ---
    GONG_RESONANT = 9114630316           # 7 s resonant gong with long tail
    GONG_CRASH_1 = 9114630820            # 8 s
    GONG_CRASH_2 = 9114630822            # 5 s
    GONG_CRASH_3 = 9114630843            # 4 s
    GONG_CHINESE = 9125585534            # 7 s
    DEATH_TOLL = 1835336539              # 6 s church death-toll bell (APM)
    HOLLOW_GONG = 1845411462             # 11 s (APM)
    GONG_APM = 1846269128                # 12 s (APM)
    APOCALYPSE_GONG = 9048840285         # 13 s distorted gong (APM)
    CHURCH_BELL_2 = 9113804175           # single strike, double at head
    CHURCH_BELL_3 = 9113804189
    CHURCH_BELL_4 = 9113804171
    CHURCH_BELL_SOFT = 9113804421
    CHURCH_TOLLING = 9113804436          # 18 s tolling sequence
    TEMPLE_HANDBELL = 9125597663         # small cast-iron Buddhist temple bell
    BRASS_HANDBELL_1 = 9113584742
    BRASS_HANDBELL_2 = 9113584861
    TRIANGLE = 9116224196
    TEMPLE_BLOCK_1 = 9120917438          # wooden temple block (mokugyo) tap
    TEMPLE_BLOCK_6 = 9120917813
    ORCH_BELL_HIT = 1843035275           # orchestral bell hit (APM)


class MESH:
    # id, typical SIZE -> ALT SIZE range used by creators
    SWIRL_RING = 4681227436       # wind swirl ring            2 -> 2.5
    THIN_RINGS = 3454554153       # several thin rings          0.5 -> 5..10
    RING_LINE = 750305703         # single thin circle          0.03 -> 3..9
    TORUS = 471124075             # thin torus                  0.01 -> 10
    THICK_TORUS = 8188257545      # thick torus (upright)       1 -> 3.6..5
    BAND = 77053510433504         # short band ring             0.1 -> 4..5
    CYL_BAND = 6421915919         # open cylinder wall          SIZE2 (0.5,4,0.5)->(1.25,0,1.25)
    TALL_BAND = 102579357879563   # upright band                3 -> 4..10
    WASHER = 129918216697923      # thick flat ring             0.1 -> 35
    SOUND_RIPPLE = 5543986905     # concentric rings (flat)     0.2..0.5 -> 2
    HARMONIC_RINGS = 881809484    # interlocked rings           10..25 -> 1..5
    WIRE_SPHERE = 5065466321      # wireframe sphere            4.5
    DOME = 8501563708             # half sphere                 0.05..0.5 -> 2..10
    BIG_DOME = 81705790953891     # half sphere (larger)        1 -> 3
    FRUSTUM = 17700114556         # truncated cone (bell body)  0.05 -> 1.5
    FLARED_CUP = 14532716061      # flared cup                  2 / 0.1 -> 140
    BOWL = 125349505454888        # open bowl                   1 -> 3
    SPHERE = 6220352407           # sphere
    SPIKE_CROWN = 643098245       # flat spiky ring (tex 643064975)  0.05 -> 5..8
    SPIKE_BURST = 4316118084      # upward spike burst          0.1 -> 9
    CRATER = 134013476158446      # crater ring                 SIZE2 (100,40,100)
    CRACKS = 106613812363639      # ground crack lines          0.35 / 20..40
    CONE_DISC = 7423457269        # flat cone shockwave         0.01 -> 2000


class TEX:
    # Image id                      name on Roblox / look            (#movesets using it)
    SPARK = 7814053668            # "spark big border": long bright streak       (3)
    LINE = 8985611391             # "Line": thin vertical streak                 (3)
    HIT_STAR = 16910627138        # "hit effect 2": radial impact star           (4)
    SPIKE_STAR = 10357935135      # spiky impact star                            (9)
    OUTLINE = 16170732926         # "outline1": soft-edged circle (ground wave)  (3)
    WIND_RING = 15269685466       # "wind": thin ring                            (3)
    SHOCKWAVE = 10176632695       # "Shockwave7": ring of radial streaks         (7)
    GLOW = 4509687978             # "mariball": soft round glow                  (8)
    FLARE = 14684195806           # "Guiding light particle": lens flare         (3)
    SMOKE = 2870800851            # "Smoke": puff                                (4)
    CIRCLE = 1084982817           # "circle_64": solid dot                       (4)
