"""Timeline node constructors for the JJS Skill Builder.

Field names, value types and which fields are always present were derived from
~250,000 nodes in 224 real game exports (see docs/FORMAT.md):

* numbers and booleans are always written by the game, so we always write them;
* "reference" strings (branch names, projectile / visual / state tags) are Lua
  nil until the player types something, and the game omits nil keys from its
  JSON, so we only write them when they are actually used;
* vectors are strings like "0, 0, 4", colours "255, 255, 255";
* DMG / KNOCK skill properties are strings; TAG values are strings.

Every constructor returns a plain dict ready to be placed in a timeline.
"""
from __future__ import annotations

from typing import Iterable, Sequence

# ---------------------------------------------------------------- enums ----
ATTACK_TYPES = ("Melee", "Bullet", "Explosion", "Swarm", "Domain")

BODY_PARTS = ("HumanoidRootPart", "Head", "Torso", "Right Arm", "Left Arm",
              "Right Leg", "Left Leg")

EASING_STYLES = ("Linear", "Sine", "Quad", "Cubic", "Exponential", "Back")
EASING_DIRECTIONS = ("In", "Out", "InOut")

# Every EFFECT value observed in game exports (V1.84 adds the Highlight trio).
EFFECTS = (
    "Mesh", "Clash", "Glow", "Wind Expand", "Billboard", "Field of View", "Overlay",
    "Star", "Melee Trail", "Energy Sparks", "Shake Heavy", "Mass Hit", "Screen Color",
    "Cursed Energy", "Shake Light", "Shake Medium", "Sparks", "Whirl Slash", "Beam",
    "Beams", "Cleave", "Circle Glow", "Blood", "Black Flash", "Sphere", "Visibility",
    "Distortion", "Dismantle", "360 Wind", "Light", "Weak Lightning", "Cancel", "Camera",
    "Flames", "Afterimage", "Wind Ring", "Burst", "Wind Streak", "Ring", "Rough Energy",
    "Block", "Cylinder", "Afterimage2", "Shine", "Slash", "Star Outline", "Wedge",
    "Distortion Expand", "HighlightOutline", "HighlightFocus", "HighlightCore",
)

# Every STATE value observed in game exports.
STATES = (
    "Stun", "NoJump", "DirectionLock", "IFrame", "NoSprint", "NoM1", "SpeedMultiplier",
    "NoDash", "DisableChase", "Scale", "JumpMultiplier", "Projection", "Block", "Bleed",
    "Cancel", "InSkill", "CameraMaxZoomDistance", "DamageMultiplier", "LastHit",
    "HealthMultiplier", "NoMass", "Ragdoll", "NoDeath", "Wakeup", "NoBlock",
    "NoParkour", "KnockbackMultiplier", "Character",
)

SPECIALS = (
    "Limitless", "Combat Instincts", "Cleave", "Rhythm", "Door Guard", "Lurking Shadow",
    "Adaptation Wheel", "Self Transfiguration", "Convergence", "Boogie Woogie",
    "Fluttering Pounce", "Domain Amplification", "No Escape", "Mass Buildup",
    "Incantation", "Rika", "Clairvoyance", "Energy Output", "Offload", "Acceleration",
    "Projection Sorcery", "Ratio Point", "Instant Transmission", "Helping Hand", "Flock",
    "Flower Field", "Restyle", "Earthen Insect Trance", "Discard",
)


class NodeError(ValueError):
    pass


# ------------------------------------------------------------- helpers ----
def _num(x, field):
    if isinstance(x, bool) or not isinstance(x, (int, float)):
        raise NodeError(f"{field} must be a number, got {x!r}")
    if isinstance(x, float):
        x = round(x, 4)          # strip binary noise like 1.7999999999999998
        if x.is_integer() and abs(x) < 1e15:
            return int(x)
    return x


def _fmt(x):
    if isinstance(x, float):
        x = round(x, 4)
        if x.is_integer():
            x = int(x)
    return repr(x) if isinstance(x, float) else str(x)


def vec(v, field="vector", n=3) -> str:
    """(0, 0, 4) -> "0, 0, 4" (strings are passed through after a sanity check)."""
    if isinstance(v, str):
        parts = [p.strip() for p in v.split(",")]
        if len(parts) != n:
            raise NodeError(f"{field} needs {n} components: {v!r}")
        [float(p) for p in parts]
        return ", ".join(parts)
    v = list(v)
    if len(v) != n:
        raise NodeError(f"{field} needs {n} components: {v!r}")
    return ", ".join(_fmt(_num(c, field)) for c in v)


def color(c, field="COLOR") -> str:
    if isinstance(c, str):
        parts = [p.strip() for p in c.split(",")]
        if len(parts) != 3:
            raise NodeError(f"{field} needs r, g, b: {c!r}")
        return ", ".join(parts)
    c = list(c)
    if len(c) != 3 or not all(0 <= int(x) <= 255 for x in c):
        raise NodeError(f"{field} needs three 0-255 ints: {c!r}")
    return ", ".join(str(int(x)) for x in c)


def _ref(d: dict, key: str, value):
    """Reference-type string fields are omitted when unset (Lua nil)."""
    if value is not None and value != "":
        if not isinstance(value, str):
            raise NodeError(f"{key} must be a string")
        d[key] = value
    return d


def _choice(value, options, field):
    if value not in options:
        raise NodeError(f"{field}={value!r} is not one of {options}")
    return value


# --------------------------------------------------------------- nodes ----
def Wait(time: float) -> dict:
    return {"K_NAME": "WAIT", "TIME": _num(time, "TIME")}


def Sfx(id: int, vol: float = 2, speed: float = 1, start: float = 0, end: float = 500,
        fade_in: float = 0, fade_out: float = 0, cancel: bool = False,
        global_: bool = False, client: bool = False, last_hit: float = -1,
        ptag: str | None = None) -> dict:
    """Play a sound. GLOBAL disables 3D falloff. CANCEL stops other SFX nodes."""
    d = {"K_NAME": "SFX", "ID": int(id), "VOLUME": _num(vol, "VOLUME"),
         "SPEED": _num(speed, "SPEED"), "START": _num(start, "START"),
         "END": _num(end, "END"), "FADE IN": _num(fade_in, "FADE IN"),
         "FADE OUT": _num(fade_out, "FADE OUT"), "CANCEL": bool(cancel),
         "GLOBAL": bool(global_), "CLIENT SIDED": bool(client),
         "LAST HIT": _num(last_hit, "LAST HIT")}
    return _ref(d, "PROJECTILE TAG", ptag)


def Anim(anim, start: float = 0, end: float | None = None, speed: float = 1,
         fade_in: float = 0.1, fade_out: float = 0, looped: bool = False,
         last_hit: float = -1) -> dict:
    """Play a built-in animation.

    `anim` is either an Animation entry from jjsforge.anims (preferred: it carries the
    verified [character, index] pair and clip length) or a raw [cat, idx] pair, or an
    emote name string. PREVIEW = [start, end] is the clip window that is played.
    """
    length = None
    if hasattr(anim, "use"):
        use, length = list(anim.use), anim.length
    elif isinstance(anim, str):
        use = anim
    else:
        use = [int(anim[0]), int(anim[1])]
    if end is None:
        end = length if length is not None else 1
    if end < start:
        raise NodeError(f"ANIM window end {end} < start {start}")
    return {"K_NAME": "ANIM", "ANIM_USE": use,
            "PREVIEW": [_num(start, "PREVIEW"), _num(end, "PREVIEW")],
            "SPEED": _num(speed, "SPEED"), "FADE IN": _num(fade_in, "FADE IN"),
            "FADE OUT": _num(fade_out, "FADE OUT"), "LOOPED": bool(looped),
            "LAST HIT": _num(last_hit, "LAST HIT")}


def Visual(effect: str, time: float = 1, size: float = 1, alt_size: float | None = None,
           size2=None, alt_size2=None, col=(255, 255, 255), alt_col=None,
           opacity: float = 0, alt_opacity: float = 1, pos=(0, 0, 0), alt_pos=None,
           rot=(0, 0, 0), alt_rot=None, amount: float = 1, texture: int = 0,
           part: str = "HumanoidRootPart", ease: str = "Linear", ease_dir: str = "In",
           server: bool = False, client: bool = False, cancel_on_interrupt: bool = False,
           rel_branch: bool = False, collide: bool = False, last_hit: float = -1,
           vtag: str | None = None, ptag: str | None = None) -> dict:
    """A visual effect. OPACITY is really transparency (0 = solid, 1 = invisible) and
    every ALT_* value is what the effect tweens to over TIME (defaults: unchanged,
    except alt_opacity which defaults to 1 = fade out).

    Size semantics (inferred from how creators tune effects, e.g. a static 30-stud
    sky dome uses ALT SIZE 1.2 over 14 s): ALT SIZE is a *multiplier* of SIZE
    (1 = unchanged), whereas SIZE 2 / ALT SIZE 2 are absolute per-axis sizes
    ("-1, -1, -1" = unused). Cylinder / Sphere effects take studs.
    For EFFECT="Mesh" the AMOUNT is the mesh asset id and TEXTURE its texture.
    For "Light" OPACITY is brightness and SIZE the range; for "Shake *" and
    "Field of View" AMOUNT is the intensity / FOV offset."""
    if alt_size is None:
        alt_size = 1
    _choice(effect, EFFECTS, "EFFECT")
    _choice(part, BODY_PARTS, "BODY PART")
    _choice(ease, EASING_STYLES, "EASING STYLE")
    _choice(ease_dir, EASING_DIRECTIONS, "EASING DIRECTION")
    d = {"K_NAME": "VISUAL", "EFFECT": effect, "TIME": _num(time, "TIME"),
         "SIZE": _num(size, "SIZE"),
         "ALT SIZE": _num(alt_size, "ALT SIZE"),
         "SIZE 2": vec(size2 if size2 is not None else (-1, -1, -1), "SIZE 2"),
         "ALT SIZE 2": vec(alt_size2 if alt_size2 is not None else
                           (size2 if size2 is not None else (-1, -1, -1)), "ALT SIZE 2"),
         "COLOR": color(col), "ALT COLOR": color(col if alt_col is None else alt_col),
         "OPACITY": _num(opacity, "OPACITY"), "ALT OPACITY": _num(alt_opacity, "ALT OPACITY"),
         "POSITION": vec(pos, "POSITION"),
         "ALT POSITION": vec(pos if alt_pos is None else alt_pos, "ALT POSITION"),
         "ROTATION": vec(rot, "ROTATION"),
         "ALT ROTATION": vec(rot if alt_rot is None else alt_rot, "ALT ROTATION"),
         "AMOUNT": _num(amount, "AMOUNT"), "TEXTURE": int(texture), "BODY PART": part,
         "EASING STYLE": ease, "EASING DIRECTION": ease_dir,
         "RUN ON SERVER": bool(server), "CLIENT SIDED": bool(client),
         "CANCEL ON INTERRUPT": bool(cancel_on_interrupt),
         "RELATIVE FROM BRANCH": bool(rel_branch), "CAN COLLIDE": bool(collide),
         "LAST HIT": _num(last_hit, "LAST HIT")}
    _ref(d, "VISUAL TAG", vtag)
    return _ref(d, "PROJECTILE TAG", ptag)


def CancelVisual(vtag: str, time: float = 0.1) -> dict:
    """Remove every running visual that carries VISUAL TAG `vtag`."""
    return Visual("Cancel", time=time, alt_opacity=0, vtag=vtag)


def State(state: str, time: float = 1, value=1, cancel_on_end: bool = False,
          disable_burst: bool = False, last_hit: float = -1, check: bool = False,
          branch: str | None = None, stag: str | None = None) -> dict:
    """Apply (or with check=True, test the LAST HIT target for) a gameplay state."""
    _choice(state, STATES, "STATE")
    if isinstance(value, bool) or not isinstance(value, (int, float, str)):
        raise NodeError("STATE VALUE must be a number or numeric string")
    if isinstance(value, float):
        # game exports hold integer VALUEs as numbers and anything else as the
        # string the player typed ("0.3") - never as a JSON float
        value = int(value) if value.is_integer() else _fmt(value)
    d = {"K_NAME": "STATE", "STATE": state, "VALUE": value, "TIME": _num(time, "TIME"),
         "CANCEL ON END": bool(cancel_on_end), "DISABLE BURST": bool(disable_burst),
         "LAST HIT": _num(last_hit, "LAST HIT"), "CHECK": bool(check)}
    _ref(d, "BRANCH", branch)
    return _ref(d, "STATE TAG", stag)


def Velo(force=(0, 0, 0), time: float = 0.1, fade: bool = False, track: bool = False,
         last_hit: float = -1, ragdoll: float = 0, true_ragdoll: bool = False,
         rel_branch: bool = False) -> dict:
    """Push the user (or, with last_hit > 0, the last-hit target). FORCE is local
    (X right, Y up, Z forward). RAGDOLL > 0 ragdolls for that many seconds."""
    return {"K_NAME": "VELO", "FORCE": vec(force, "FORCE"), "TIME": _num(time, "TIME"),
            "FADE": bool(fade), "TRACK": bool(track), "LAST HIT": _num(last_hit, "LAST HIT"),
            "RAGDOLL": _num(ragdoll, "RAGDOLL"), "TRUE RAGDOLL": bool(true_ragdoll),
            "RELATIVE FROM BRANCH": bool(rel_branch)}


def Hitbox(dmg: float, size=(6, 6, 6), pos=(0, 0, 4), rot=(0, 0, 0), stun: float = 1,
           stun_anim: bool = True, ignore_wakeup: bool = False, debree: float = 0,
           atk: str = "Melee", blockable: bool = True, block360: bool = False,
           cancel_enemy: bool = True, clear_kb: bool = False, can_kill: bool = True,
           hit_ragdoll: bool = False, hit_user: bool = False, single: bool = False,
           branch: str | None = None, target: str | None = None,
           finisher: str | None = None, ptag: str | None = None,
           link_user: float = 0) -> dict:
    """Damage area. `branch` = where the USER goes on hit, `target` = branch the hit
    TARGET runs (knockback, marks...), `finisher` = user branch on a kill."""
    _choice(atk, ATTACK_TYPES, "ATTACK TYPE")
    d = {"K_NAME": "HITBOX", "PREVIEW": [0, 15], "DAMAGE": _num(dmg, "DAMAGE"),
         "SIZE": vec(size, "SIZE"), "POSITION": vec(pos, "POSITION"),
         "ROTATION": vec(rot, "ROTATION"), "STUN": _num(stun, "STUN"),
         "STUN ANIM": bool(stun_anim), "IGNORE WAKEUP": bool(ignore_wakeup),
         "DEBREE": _num(debree, "DEBREE"), "ATTACK TYPE": atk,
         "BLOCKABLE": bool(blockable), "360 BLOCK": bool(block360),
         "CANCEL ENEMY": bool(cancel_enemy), "CLEAR KNOCKBACK": bool(clear_kb),
         "CAN KILL": bool(can_kill), "HIT RAGDOLL": bool(hit_ragdoll),
         "HIT USER": bool(hit_user), "SINGLE TARGET": bool(single),
         "LINK USER": _num(link_user, "LINK USER")}
    _ref(d, "BRANCH", branch)
    _ref(d, "BRANCH TARGET", target)
    _ref(d, "BRANCH FINISHER", finisher)
    return _ref(d, "PROJECTILE TAG", ptag)


def Projectile(ptag: str, dmg: float = 0, size=(6, 6, 6), pos=(0, 0, 0), rot=(0, 0, 0),
               speed: float = 100, time: float = 1, stun: float = 1,
               stun_anim: bool = True, ignore_wakeup: bool = True, debree: float = 0,
               atk: str = "Bullet", blockable: bool = True, block360: bool = False,
               cancel_enemy: bool = True, clear_kb: bool = False, can_kill: bool = True,
               hit_ragdoll: bool = True, hit_user: bool = False, aim_last_hit: float = -1,
               continue_: bool = False, branch: str | None = None,
               target: str | None = None, collided: str | None = None,
               filter_interval: float = 1, reflect: int = 0, cache: bool = True,
               cancel_projectile: bool = False, id_check: bool = True,
               spawn_at: str | None = None) -> dict:
    """A travelling hit object. VISUAL / HITBOX / SFX / TELEPORT nodes with the same
    PROJECTILE TAG follow it. `collided` = user branch when it hits terrain."""
    _choice(atk, ATTACK_TYPES, "ATTACK TYPE")
    d = {"K_NAME": "PROJECTILE", "PROJECTILE TAG": ptag, "DAMAGE": _num(dmg, "DAMAGE"),
         "STUN": _num(stun, "STUN"), "SPEED": _num(speed, "SPEED"),
         "SIZE": vec(size, "SIZE"), "POSITION": vec(pos, "POSITION"),
         "ROTATION": vec(rot, "ROTATION"), "ATTACK TYPE": atk,
         "REFLECT COUNT": int(reflect), "FILTER INTERVAL": _num(filter_interval, "FILTER INTERVAL"),
         "CONTINUE": bool(continue_), "HIT RAGDOLL": bool(hit_ragdoll),
         "STUN ANIM": bool(stun_anim), "HIT USER": bool(hit_user),
         "BLOCKABLE": bool(blockable), "360 BLOCK": bool(block360),
         "CAN KILL": bool(can_kill), "AIM LAST HIT": _num(aim_last_hit, "AIM LAST HIT"),
         "TIME": _num(time, "TIME"), "IGNORE WAKEUP": bool(ignore_wakeup),
         "DEBREE": _num(debree, "DEBREE"), "CANCEL ENEMY": bool(cancel_enemy),
         "CACHE": bool(cache), "CLEAR KNOCKBACK": bool(clear_kb),
         "CANCEL PROJECTILE": bool(cancel_projectile), "ID CHECK": bool(id_check)}
    _ref(d, "BRANCH", branch)
    _ref(d, "BRANCH TARGET", target)
    _ref(d, "BRANCH COLLIDED", collided)
    return _ref(d, "SPAWN AT PROJECTILE TAG", spawn_at)


def Branch(branch: str | None = None, random: Sequence[str] | None = None,
           last_hit: float = -1) -> dict:
    """Jump to a branch (if that branch's Req passes; otherwise fall through).
    With `random`, one of the listed branches is picked each time."""
    d = {"K_NAME": "BRANCH", "LAST HIT": _num(last_hit, "LAST HIT")}
    _ref(d, "BRANCH", branch)
    if random:
        d["RANDOM"] = ", ".join(random)
    if "BRANCH" not in d and "RANDOM" not in d:
        raise NodeError("BRANCH node needs a branch or a random list")
    return d


def Tag(tag: str, value="1", time: float = 1, check: bool = False, set_: bool = True,
        add: bool = True, branch: str | None = None, last_hit: float = -1) -> dict:
    """Named variable. check=True compares (prefix value with < or > for ranges) and
    jumps to `branch` on success. Otherwise set_=True stores `value` for `time`
    seconds; set_=False adds (add=True) or subtracts `value`."""
    d = {"K_NAME": "TAG", "TAG": tag, "VALUE": str(value), "TIME": _num(time, "TIME"),
         "CHECK": bool(check), "SET": bool(set_), "ADD/REMOVE": bool(add),
         "LAST HIT": _num(last_hit, "LAST HIT")}
    if check and not branch:
        raise NodeError(f"TAG check on {tag!r} needs a branch")
    return _ref(d, "BRANCH", branch)


def TagCheck(tag: str, value, branch: str, last_hit: float = -1) -> dict:
    return Tag(tag, value, time=1, check=True, set_=False, add=False, branch=branch,
               last_hit=last_hit)


def TagSet(tag: str, value, time: float = 1, last_hit: float = -1) -> dict:
    return Tag(tag, value, time=time, check=False, set_=True, add=True, last_hit=last_hit)


def HitCancel(branch: str, time: float = 0.1, missed: bool = True,
              endlag: float = 0) -> dict:
    """missed=True (FLIP): go to `branch` if NOTHING was hit in the last `time` s.
    missed=False: go to `branch` if something WAS hit."""
    d = {"K_NAME": "HITCNCL", "TIME": _num(time, "TIME"), "ENDLAG": _num(endlag, "ENDLAG"),
         "FLIP": bool(missed)}
    return _ref(d, "BRANCH", branch)


def Loop(back: int, amount: int, hold: bool = False) -> dict:
    """Repeat the previous `back` nodes `amount` more times."""
    return {"K_NAME": "LOOP", "LOOP BACK": int(back), "LOOP AMOUNT": int(amount),
            "HOLD": bool(hold)}


def BaseSkill(move: str, speed: float = 1, start: float = 0, hold_for: float = 0,
              variants: bool = True, cancel_last: bool = False) -> dict:
    """Run a built-in JJS move (or 'Cancel' to stop a running one)."""
    return {"K_NAME": "SKILL", "MOVE": move, "SPEED": _num(speed, "SPEED"),
            "START": _num(start, "START"), "HOLD FOR": _num(hold_for, "HOLD FOR"),
            "ENABLE VARIANTS": bool(variants), "CANCEL LAST": bool(cancel_last)}


def BaseSpecial(spec: str, speed: float = 1, variants: bool = True,
                cancel_last: bool = False) -> dict:
    _choice(spec, SPECIALS, "SPEC")
    return {"K_NAME": "SPECIAL", "SPEC": spec, "SPEED": _num(speed, "SPEED"),
            "ENABLE VARIANTS": bool(variants), "CANCEL LAST": bool(cancel_last)}


def Grab(time: float = 1, pos=(0, 0, 4), rot=(0, 180, 0), part: str = "HumanoidRootPart",
         target_part: str = "HumanoidRootPart", last_hit: float = 1) -> dict:
    """Weld the last-hit target's `target_part` to the user's `part` at an offset."""
    _choice(part, BODY_PARTS, "BODY PART")
    _choice(target_part, BODY_PARTS, "BODY PART2")
    return {"K_NAME": "GRAB", "BODY PART": part, "BODY PART2": target_part,
            "TIME": _num(time, "TIME"), "POSITION": vec(pos, "POSITION"),
            "ROTATION": vec(rot, "ROTATION"), "LAST HIT": _num(last_hit, "LAST HIT")}


def Teleport(pos=(0, 0, 0), rot=(0, 0, 0), last_hit: float = -1, ptag: str | None = None,
             rel_branch: bool = False, ignore_walls: bool = False) -> dict:
    """Move the user to an offset from the last-hit target (last_hit > 0), a projectile
    (ptag) or itself."""
    d = {"K_NAME": "TELEPORT", "POSITION": vec(pos, "POSITION"),
         "ROTATION": vec(rot, "ROTATION"), "LAST HIT": _num(last_hit, "LAST HIT"),
         "RELATIVE FROM BRANCH": bool(rel_branch), "IGNORE WALLS": bool(ignore_walls)}
    return _ref(d, "PROJECTILE TAG", ptag)


def Counter(types: Iterable[str] = ("Melee",), time: float = 0.5, stun: float = 0,
            cancel_enemy: bool = True, branch: str | None = None,
            target: str | None = None, remove_on_hit: bool = True,
            reflect: bool = False, continue_: bool = False) -> dict:
    """Open a counter window; on being hit by one of `types`, jump to `branch`
    (and send the attacker to `target`)."""
    types = list(types)
    for t in types:
        _choice(t, ATTACK_TYPES, "ATTACK TYPE2")
    d = {"K_NAME": "COUNTER", "TIME": _num(time, "TIME"), "STUN": _num(stun, "STUN"),
         "ATTACK TYPE2": ",".join(types), "CANCEL ENEMY": bool(cancel_enemy),
         "REMOVE ON HIT": bool(remove_on_hit), "REFLECT": bool(reflect),
         "CONTINUE": bool(continue_)}
    _ref(d, "BRANCH", branch)
    return _ref(d, "BRANCH TARGET", target)


def Look(time: float = 1, smooth: int = 200, camera: bool = False,
         horizontal: bool = True, grounded: bool = False, rel_branch: bool = False,
         last_hit: float = -1, ptag: str | None = None) -> dict:
    """Turn the user toward the camera direction / last-hit target / projectile."""
    d = {"K_NAME": "LOOK", "TIME": _num(time, "TIME"), "SMOOTHNESS": int(smooth),
         "CAMERA DIRECTION": bool(camera), "HORIZONTAL ONLY": bool(horizontal),
         "GROUNDED": bool(grounded), "RELATIVE FROM BRANCH": bool(rel_branch),
         "LAST HIT": _num(last_hit, "LAST HIT")}
    return _ref(d, "PROJECTILE TAG", ptag)


def SetMelee(combo: int, offset: float = 1, last_hit: float = -1) -> dict:
    """Set the M1 combo counter (e.g. combo=0 -> next M1 is the 1st hit again)."""
    return {"K_NAME": "SETMELEE", "COMBO": int(combo), "OFFSET": _num(offset, "OFFSET"),
            "LAST HIT": _num(last_hit, "LAST HIT")}


def SetCooldown(key: int = -1, cooldown: float = -1) -> dict:
    """key -1 = this move; cooldown -1 = its default cooldown."""
    return {"K_NAME": "SETCD", "KEY": int(key), "COOLDOWN": _num(cooldown, "COOLDOWN")}


def Health(amount: float, can_kill: bool = False) -> dict:
    return {"K_NAME": "HPGIB", "AMOUNT": _num(amount, "AMOUNT"), "CAN KILL": bool(can_kill)}


def Awaken(amount: float) -> dict:
    """Add to the awakening bar (0-100)."""
    return {"K_NAME": "ULTGIB", "AMOUNT": _num(amount, "AMOUNT")}


def Evasive(amount: float) -> dict:
    return {"K_NAME": "EVGIB", "AMOUNT": _num(amount, "AMOUNT")}


PARTICLE_ORIENTATIONS = ("FacingCamera", "FacingCameraWorldUp", "VelocityParallel",
                         "VelocityPerpendicular")
PARTICLE_DIRECTIONS = ("Top", "Bottom", "Front", "Back", "Left", "Right")
PARTICLE_SHAPES = ("Box", "Sphere", "Cylinder", "Disc")
PARTICLE_SHAPE_INOUT = ("Outward", "Inward", "InAndOut")
FLIPBOOK_MODES = ("OneShot", "Loop", "PingPong", "Random")


def seq(v, field="sequence", n=None) -> str:
    """Number sequence in the game's string form: 2 -> "2", (1, 0) -> "1, 0".
    Keypoints are spread evenly over the particle's life. `n` forces a length
    (a single number is repeated, e.g. a range 0.3 -> "0.3, 0.3")."""
    if isinstance(v, str):
        parts = [p.strip() for p in v.split(",")]
        try:
            [float(p) for p in parts]
        except ValueError:
            raise NodeError(f"{field} is not a number sequence: {v!r}") from None
        vals = parts
    elif isinstance(v, (int, float)) and not isinstance(v, bool):
        vals = [_fmt(_num(v, field))]
    else:
        vals = [_fmt(_num(x, field)) for x in v]
    if not vals:
        raise NodeError(f"{field} is empty")
    if n is not None:
        if len(vals) == 1:
            vals = vals * n
        if len(vals) != n:
            raise NodeError(f"{field} needs {n} values: {v!r}")
    return ", ".join(vals)


def color_seq(c, field="COLOR") -> str:
    """Particle colour: one key (255, 0, 0) -> "255,0,0", or a gradient of keys spread
    evenly over the particle's life ((255, 0, 0), (0, 0, 255)) -> "255,0,0 0,0,255"
    (the exported form: no spaces inside a key, one space between keys)."""
    if isinstance(c, str):
        keys = [k.split(",") for k in c.split()]
    else:
        c = list(c)
        keys = [list(k) for k in c] if c and isinstance(c[0], (tuple, list)) else [c]
    if not keys:
        raise NodeError(f"{field} is empty")
    out = []
    for k in keys:
        try:
            k = [int(str(x).strip()) for x in k]
        except ValueError:
            raise NodeError(f"{field} key must be r,g,b: {c!r}") from None
        if len(k) != 3 or not all(0 <= x <= 255 for x in k):
            raise NodeError(f"{field} key must be r,g,b in 0-255: {c!r}")
        out.append(",".join(map(str, k)))
    return " ".join(out)


def Particle(texture: int, part: str = "HumanoidRootPart", pos=(0, 0, 0), *,
             col=(255, 255, 255), size=(1, 0), transparency=(0, 1), lifetime=(0.3, 0.5),
             speed=(10, 20), rate: float = 0, emit: int = 10, duration: float = 0,
             spread=(360, 360, 0), rotation=(-360, 360), rot_speed=(0, 0),
             accel=(0, 0, 0), drag: float = 0, light_emission: float = 1,
             light_influence: float = 0, brightness: float = 1, zoffset: float = 0,
             orientation: str = "FacingCamera", flip_size=(0, 0), flip_rate=(10, 10),
             flip_mode: str = "OneShot", squash=(0, 0), part_size=(0, 0, 0),
             shape: str = "Box", shape_inout: str = "Outward", shape_partial: float = 0,
             direction: str = "Top", lock: bool = False, server: bool = False,
             client: bool = False, cancel: bool = False, cancel_on_interrupt: bool = False,
             cancel_tag: str | None = None, last_hit: float = -1,
             ptag: str | None = None) -> dict:
    """Particle Emitter block (Skill Builder V1.8+), i.e. a Roblox ParticleEmitter.

    Burst: duration 0 and `emit` particles at once. Stream: duration > 0 at `rate`
    per second. size / transparency / squash are number sequences, lifetime /
    speed / rotation / rot_speed are (min, max) ranges, `col` is one colour or a
    (start, end) pair. Emitters with a `cancel_tag` can be stopped later by
    CancelParticle(tag); `lock` keeps the particles moving with the part."""
    _choice(part, BODY_PARTS, "BODY PART")
    _choice(orientation, PARTICLE_ORIENTATIONS, "ORIENTATION TYPE")
    _choice(direction, PARTICLE_DIRECTIONS, "EMISSION DIRECTION")
    _choice(shape, PARTICLE_SHAPES, "SHAPE")
    _choice(shape_inout, PARTICLE_SHAPE_INOUT, "SHAPE INOUT")
    _choice(flip_mode, FLIPBOOK_MODES, "FLIPBOOK MODE")
    if not cancel and int(texture) <= 0:
        raise NodeError("PARTICLE needs a texture id")
    sp = list(spread) if not isinstance(spread, str) else spread
    if not isinstance(sp, str) and len(sp) == 2:
        sp = sp + [0]
    d = {"K_NAME": "PARTICLE", "TEXTURE": int(texture), "BODY PART": part,
         "POSITION": vec(pos, "POSITION"), "COLOR": color_seq(col),
         "SIZE": seq(size, "SIZE"), "TRANSPARENCY": seq(transparency, "TRANSPARENCY"),
         "LIFETIME": seq(lifetime, "LIFETIME", 2), "SPEED": seq(speed, "SPEED", 2),
         "RATE": _num(rate, "RATE"), "EMIT COUNT": int(emit),
         "DURATION": _num(duration, "DURATION"), "SPREAD ANGLE": vec(sp, "SPREAD ANGLE"),
         "ROTATION": seq(rotation, "ROTATION", 2), "ROT SPEED": seq(rot_speed, "ROT SPEED", 2),
         "ACCELERATION": vec(accel, "ACCELERATION"), "DRAG": _num(drag, "DRAG"),
         "LIGHT EMISSION": _num(light_emission, "LIGHT EMISSION"),
         "LIGHT INFLUENCE": _num(light_influence, "LIGHT INFLUENCE"),
         "BRIGHTNESS": _num(brightness, "BRIGHTNESS"), "ZOFFSET": _num(zoffset, "ZOFFSET"),
         "ORIENTATION TYPE": orientation, "FLIPBOOK SIZE": seq(flip_size, "FLIPBOOK SIZE", 2),
         "FLIPBOOK FRAMERATE": seq(flip_rate, "FLIPBOOK FRAMERATE", 2),
         "FLIPBOOK MODE": flip_mode, "SQUASH": seq(squash, "SQUASH"),
         "PART SIZE": vec(part_size, "PART SIZE"), "SHAPE": shape,
         "SHAPE INOUT": shape_inout, "SHAPE PARTIAL": _num(shape_partial, "SHAPE PARTIAL"),
         "EMISSION DIRECTION": direction, "LOCK TO PART": bool(lock),
         "RUN ON SERVER": bool(server), "CLIENT SIDED": bool(client),
         "CANCEL": bool(cancel), "CANCEL ON INTERRUPT": bool(cancel_on_interrupt),
         "LAST HIT": _num(last_hit, "LAST HIT")}
    _ref(d, "CANCEL TAG", cancel_tag)
    return _ref(d, "PROJECTILE TAG", ptag)


def CancelParticle(tag: str) -> dict:
    """Stop the emitters created with CANCEL TAG `tag` (a PARTICLE block with CANCEL on,
    the way creators end a smoke or aura emitter from another branch or skill)."""
    if not tag:
        raise NodeError("CancelParticle needs a tag")
    return Particle(0, emit=0, speed=0, cancel=True, cancel_tag=tag)


# --------------------------------------------------------- conditions ----
def AIR(flip=False):     return {"K_NAME": "AIR", "FLIP": bool(flip)}
def JUMP(flip=False):    return {"K_NAME": "JUMP", "FLIP": bool(flip)}   # holding jump
def AIM(flip=False):     return {"K_NAME": "AIM", "FLIP": bool(flip)}    # cursor on a player
def ULT(flip=False):     return {"K_NAME": "ULT", "FLIP": bool(flip)}    # awakened
def HOLD(flip=False):    return {"K_NAME": "HOLD", "FLIP": bool(flip)}   # key still held
def DOMAIN(flip=False):  return {"K_NAME": "DOMAIN", "FLIP": bool(flip)}
def BAR(amount, flip=False): return {"K_NAME": "BAR", "AMOUNT": amount, "FLIP": bool(flip)}
def HP(amount, flip=False):  return {"K_NAME": "HP", "AMOUNT": amount, "FLIP": bool(flip)}
