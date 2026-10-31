"""Static checks for a JJS character document (list of skill entries).

Errors are things that would break import or make a timeline misbehave
(bad JSON shape, wrong value types, dangling branch names, impossible loops).
Warnings are suspicious-but-legal patterns.
"""
from __future__ import annotations

import json
from dataclasses import dataclass, field

from .nodes import ATTACK_TYPES, BODY_PARTS, EFFECTS, STATES

ENTRY_KINDS = {"SKILL", "MELEE", "CHASE", "SPECIAL", "AWAKENING"}
COND_KINDS = {"AIR", "JUMP", "AIM", "ULT", "HOLD", "DOMAIN", "BAR", "HP", "DUR"}

NUM, BOOL, STR, VEC3, VEC2, LIST, ANY = "num", "bool", "str", "vec3", "vec2", "list", "any"

# field -> expected type, per node kind (only fields we know; extra fields warn)
SPEC = {
    "WAIT": {"TIME": NUM},
    "SFX": {"ID": NUM, "VOLUME": NUM, "SPEED": NUM, "START": NUM, "END": NUM,
            "FADE IN": NUM, "FADE OUT": NUM, "CANCEL": BOOL, "GLOBAL": BOOL,
            "CLIENT SIDED": BOOL, "LAST HIT": NUM, "PROJECTILE TAG": STR},
    "ANIM": {"ANIM_USE": ANY, "PREVIEW": LIST, "SPEED": NUM, "FADE IN": NUM,
             "FADE OUT": NUM, "LOOPED": BOOL, "LAST HIT": NUM},
    "VISUAL": {"EFFECT": STR, "TIME": NUM, "SIZE": NUM, "ALT SIZE": NUM, "SIZE 2": VEC3,
               "ALT SIZE 2": VEC3, "COLOR": VEC3, "ALT COLOR": VEC3, "OPACITY": NUM,
               "ALT OPACITY": NUM, "POSITION": VEC3, "ALT POSITION": VEC3,
               "ROTATION": VEC3, "ALT ROTATION": VEC3, "AMOUNT": NUM, "TEXTURE": NUM,
               "BODY PART": STR, "EASING STYLE": STR, "EASING DIRECTION": STR,
               "RUN ON SERVER": BOOL, "CLIENT SIDED": BOOL, "CANCEL ON INTERRUPT": BOOL,
               "RELATIVE FROM BRANCH": BOOL, "CAN COLLIDE": BOOL, "LAST HIT": NUM,
               "VISUAL TAG": STR, "PROJECTILE TAG": STR},
    "STATE": {"STATE": STR, "VALUE": ANY, "TIME": NUM, "CANCEL ON END": BOOL,
              "DISABLE BURST": BOOL, "LAST HIT": NUM, "CHECK": BOOL, "BRANCH": STR,
              "STATE TAG": STR},
    "VELO": {"FORCE": VEC3, "TIME": NUM, "FADE": BOOL, "TRACK": BOOL, "LAST HIT": NUM,
             "RAGDOLL": NUM, "TRUE RAGDOLL": BOOL, "RELATIVE FROM BRANCH": BOOL},
    "HITBOX": {"PREVIEW": LIST, "DAMAGE": NUM, "SIZE": VEC3, "POSITION": VEC3,
               "ROTATION": VEC3, "STUN": NUM, "STUN ANIM": BOOL, "IGNORE WAKEUP": BOOL,
               "DEBREE": NUM, "ATTACK TYPE": STR, "BLOCKABLE": BOOL, "360 BLOCK": BOOL,
               "CANCEL ENEMY": BOOL, "CLEAR KNOCKBACK": BOOL, "CAN KILL": BOOL,
               "HIT RAGDOLL": BOOL, "HIT USER": BOOL, "SINGLE TARGET": BOOL,
               "LINK USER": NUM, "BRANCH": STR, "BRANCH TARGET": STR,
               "BRANCH FINISHER": STR, "PROJECTILE TAG": STR},
    "PROJECTILE": {"PROJECTILE TAG": STR, "DAMAGE": NUM, "STUN": NUM, "SPEED": NUM,
                   "SIZE": VEC3, "POSITION": VEC3, "ROTATION": VEC3, "ATTACK TYPE": STR,
                   "REFLECT COUNT": NUM, "FILTER INTERVAL": NUM, "CONTINUE": BOOL,
                   "HIT RAGDOLL": BOOL, "STUN ANIM": BOOL, "HIT USER": BOOL,
                   "BLOCKABLE": BOOL, "360 BLOCK": BOOL, "CAN KILL": BOOL,
                   "AIM LAST HIT": NUM, "TIME": NUM, "IGNORE WAKEUP": BOOL, "DEBREE": NUM,
                   "CANCEL ENEMY": BOOL, "CACHE": BOOL, "CLEAR KNOCKBACK": BOOL,
                   "CANCEL PROJECTILE": BOOL, "ID CHECK": BOOL, "BRANCH": STR,
                   "BRANCH TARGET": STR, "BRANCH COLLIDED": STR,
                   "SPAWN AT PROJECTILE TAG": STR},
    "BRANCH": {"BRANCH": STR, "RANDOM": STR, "LAST HIT": NUM},
    "TAG": {"TAG": STR, "VALUE": STR, "TIME": NUM, "CHECK": BOOL, "SET": BOOL,
            "ADD/REMOVE": BOOL, "BRANCH": STR, "LAST HIT": NUM},
    "HITCNCL": {"TIME": NUM, "ENDLAG": NUM, "FLIP": BOOL, "BRANCH": STR},
    "LOOP": {"LOOP BACK": NUM, "LOOP AMOUNT": NUM, "HOLD": BOOL},
    "SKILL": {"MOVE": STR, "SPEED": NUM, "START": NUM, "HOLD FOR": NUM,
              "ENABLE VARIANTS": BOOL, "CANCEL LAST": BOOL},
    "SPECIAL": {"SPEC": STR, "SPEED": NUM, "ENABLE VARIANTS": BOOL, "CANCEL LAST": BOOL},
    "GRAB": {"BODY PART": STR, "BODY PART2": STR, "TIME": NUM, "POSITION": VEC3,
             "ROTATION": VEC3, "LAST HIT": NUM},
    "TELEPORT": {"POSITION": VEC3, "ROTATION": VEC3, "LAST HIT": NUM,
                 "RELATIVE FROM BRANCH": BOOL, "IGNORE WALLS": BOOL, "PROJECTILE TAG": STR},
    "COUNTER": {"TIME": NUM, "STUN": NUM, "ATTACK TYPE2": STR, "CANCEL ENEMY": BOOL,
                "REMOVE ON HIT": BOOL, "REFLECT": BOOL, "CONTINUE": BOOL, "BRANCH": STR,
                "BRANCH TARGET": STR},
    "LOOK": {"TIME": NUM, "SMOOTHNESS": NUM, "CAMERA DIRECTION": BOOL,
             "HORIZONTAL ONLY": BOOL, "GROUNDED": BOOL, "RELATIVE FROM BRANCH": BOOL,
             "LAST HIT": NUM, "PROJECTILE TAG": STR},
    "SETMELEE": {"COMBO": NUM, "OFFSET": NUM, "LAST HIT": NUM},
    "SETCD": {"KEY": NUM, "COOLDOWN": NUM},
    "HPGIB": {"AMOUNT": NUM, "CAN KILL": BOOL},
    "ULTGIB": {"AMOUNT": NUM},
    "EVGIB": {"AMOUNT": NUM},
    "CONNECT": {"SIGNAL": STR, "TIME": NUM, "RANGE": ANY},
    "PARTICLE": None,   # many free-form string sequences; only light checks
}

# fields whose value names a branch of the same entry
BRANCH_REFS = {
    "BRANCH": ("BRANCH",), "HITBOX": ("BRANCH", "BRANCH TARGET", "BRANCH FINISHER"),
    "PROJECTILE": ("BRANCH", "BRANCH TARGET", "BRANCH COLLIDED"),
    "COUNTER": ("BRANCH", "BRANCH TARGET"), "TAG": ("BRANCH",), "STATE": ("BRANCH",),
    "HITCNCL": ("BRANCH",),
}
NULL_REFS = {None, "", "nil", "-"}


@dataclass
class Report:
    errors: list = field(default_factory=list)
    warnings: list = field(default_factory=list)

    def err(self, where, msg):
        self.errors.append(f"{where}: {msg}")

    def warn(self, where, msg):
        self.warnings.append(f"{where}: {msg}")

    @property
    def ok(self):
        return not self.errors

    def summary(self):
        lines = [f"{len(self.errors)} error(s), {len(self.warnings)} warning(s)"]
        lines += ["  ERROR " + e for e in self.errors]
        lines += ["  warn  " + w for w in self.warnings]
        return "\n".join(lines)


def _is_num(v):
    return isinstance(v, (int, float)) and not isinstance(v, bool)


def _numeric_string(v):
    if not isinstance(v, str):
        return False
    try:
        float(v)
        return True
    except ValueError:
        return False


def _is_vec(v, n):
    if not isinstance(v, str):
        return False
    parts = v.split(",")
    if len(parts) != n:
        return False
    try:
        [float(p) for p in parts]
    except ValueError:
        return False
    return True


def _check_type(v, t):
    return {NUM: _is_num, BOOL: lambda x: isinstance(x, bool), STR: lambda x: isinstance(x, str),
            VEC3: lambda x: _is_vec(x, 3), VEC2: lambda x: _is_vec(x, 2),
            LIST: lambda x: isinstance(x, list), ANY: lambda x: True}[t](v)


def check_node(n, where, rep: Report, known_anims=None):
    if not isinstance(n, dict) or "K_NAME" not in n:
        rep.err(where, "node is not an object with K_NAME")
        return
    k = n["K_NAME"]
    if k not in SPEC:
        rep.err(where, f"unknown node kind {k!r}")
        return
    spec = SPEC[k]
    if spec is not None:
        for f, v in n.items():
            if f == "K_NAME":
                continue
            if f not in spec:
                rep.warn(where, f"{k} has unexpected field {f!r}")
            elif not _check_type(v, spec[f]):
                if spec[f] == NUM and _numeric_string(v):
                    # the game tonumber()s these, real exports contain many
                    rep.warn(where, f"{k}.{f} is a numeric string {v!r}")
                elif spec[f] == NUM and isinstance(v, dict) and v.get("t") == "numeric":
                    pass    # Roblox JSONEncode form of math.huge: {"t":"numeric","v":"inf"}
                else:
                    rep.err(where, f"{k}.{f} has wrong type: {v!r} (want {spec[f]})")
    if k == "VISUAL":
        if n.get("EFFECT") not in EFFECTS:
            rep.warn(where, f"unknown VISUAL effect {n.get('EFFECT')!r}")
        if n.get("BODY PART", "HumanoidRootPart") not in BODY_PARTS:
            rep.err(where, f"bad BODY PART {n.get('BODY PART')!r}")
    if k == "STATE" and n.get("STATE") is not None and n["STATE"] not in STATES:
        rep.warn(where, f"unknown STATE {n['STATE']!r}")
    if k in ("HITBOX", "PROJECTILE") and n.get("ATTACK TYPE") not in (None,) + ATTACK_TYPES:
        rep.err(where, f"bad ATTACK TYPE {n.get('ATTACK TYPE')!r}")
    if k == "ANIM":
        use = n.get("ANIM_USE")
        pv = n.get("PREVIEW")
        if not (isinstance(pv, list) and len(pv) == 2 and all(_is_num(x) for x in pv)):
            rep.err(where, f"ANIM PREVIEW must be [start, end], got {pv!r}")
        elif pv[1] < pv[0]:
            rep.err(where, f"ANIM PREVIEW end before start {pv}")
        if isinstance(use, list):
            if len(use) != 2 or not all(isinstance(x, int) and x > 0 for x in use):
                rep.err(where, f"bad ANIM_USE {use!r}")
            elif known_anims is not None and tuple(use) not in known_anims:
                rep.warn(where, f"ANIM_USE {use} is not in the verified animation catalog")
        elif not isinstance(use, str):
            rep.err(where, f"bad ANIM_USE {use!r}")
    if k == "SFX" and _is_num(n.get("ID")) and n["ID"] <= 0:
        rep.err(where, "SFX ID must be a positive asset id")


def _refs(n):
    k = n.get("K_NAME")
    out = []
    for f in BRANCH_REFS.get(k, ()):
        v = n.get(f)
        if v not in NULL_REFS:
            out.append((f, v))
    if k == "BRANCH" and n.get("RANDOM"):
        out += [("RANDOM", r.strip()) for r in n["RANDOM"].split(",") if r.strip()]
    return out


def check_line(line, where, branches, rep, known_anims, used, ptags_made, ptags_used):
    if not isinstance(line, list):
        rep.err(where, "Line must be a list")
        return
    for i, n in enumerate(line):
        w = f"{where}[{i}]"
        check_node(n, w, rep, known_anims)
        if not isinstance(n, dict):
            continue
        for f, b in _refs(n):
            if b not in branches:
                rep.err(w, f"{n['K_NAME']}.{f} -> missing branch {b!r}")
            else:
                used.add(b)
        if n.get("K_NAME") == "LOOP":
            back = n.get("LOOP BACK", 0)
            if not (1 <= back <= i):
                rep.err(w, f"LOOP BACK {back} reaches outside the line (index {i})")
            if n.get("LOOP AMOUNT", 0) < 1:
                rep.warn(w, "LOOP AMOUNT < 1")
            # a loop without any WAIT inside would spin without yielding
            seg = line[max(0, i - back):i]
            if not any(isinstance(s, dict) and s.get("K_NAME") == "WAIT"
                       and s.get("TIME", 0) > 0 for s in seg):
                rep.warn(w, "LOOP body has no positive WAIT")
        if n.get("K_NAME") == "PROJECTILE" and n.get("PROJECTILE TAG"):
            ptags_made.add(n["PROJECTILE TAG"])
        elif isinstance(n.get("PROJECTILE TAG"), str) and n["PROJECTILE TAG"] not in NULL_REFS:
            ptags_used.append((w, n["PROJECTILE TAG"]))


def check_cond(c, where, rep):
    if not isinstance(c, dict) or c.get("K_NAME") not in COND_KINDS:
        rep.err(where, f"bad condition {c!r}")


def _jtype(v):
    if isinstance(v, bool):
        return "bool"
    if isinstance(v, int):
        return "int"
    return {float: "float", str: "str", list: "list", dict: "dict"}.get(type(v), type(v).__name__)


def check_export_types(document, table: dict) -> list:
    """Fields whose JSON value type never occurs in real game exports
    (table: tools/data/field_types.json). Returns a list of messages."""
    issues = []
    for e in document:
        try:
            data = json.loads(e["DATA"])
        except (KeyError, TypeError, ValueError):
            continue
        lines = [data.get("Line", [])] + [b.get("Line", []) for b in
                                          (data.get("Branch") or {}).values()]
        for line in lines:
            for n in line:
                known = table.get(n.get("K_NAME"), {})
                for f, v in n.items():
                    if f == "K_NAME" or f not in known:
                        continue
                    if _jtype(v) not in known[f]:
                        issues.append(f"{e.get('NAME')}: {n['K_NAME']}.{f} is {_jtype(v)} "
                                      f"({v!r}); exports only use {known[f]}")
    return issues


def validate(document, known_anims=None, layout=True) -> Report:
    rep = Report()
    if not isinstance(document, list):
        rep.err("doc", "document must be a list")
        return rep
    names = {}
    for ei, e in enumerate(document):
        where = f"#{ei} {e.get('K_NAME')} {e.get('NAME')!r}"
        if e.get("K_NAME") not in ENTRY_KINDS:
            rep.err(where, "unknown entry kind")
            continue
        if not isinstance(e.get("NAME"), str):
            rep.err(where, "NAME must be a string")
        names.setdefault((e["K_NAME"], e.get("NAME")), 0)
        names[(e["K_NAME"], e.get("NAME"))] += 1
        if e["K_NAME"] == "SKILL":
            if not isinstance(e.get("KEY"), int):
                rep.err(where, "SKILL KEY must be an int")
            if not isinstance(e.get("ADD"), bool):
                rep.err(where, "SKILL ADD must be a bool")
        if e["K_NAME"] in ("SKILL", "CHASE", "SPECIAL") and not _is_num(e.get("COOLDOWN")):
            rep.err(where, "COOLDOWN must be a number")
        if e["K_NAME"] == "AWAKENING":
            for f in ("DURATION", "DELAY"):
                if not _is_num(e.get(f)):
                    rep.err(where, f"AWAKENING {f} must be a number")
        raw = e.get("DATA")
        if not isinstance(raw, str):
            rep.err(where, "DATA must be a JSON string")
            continue
        try:
            data = json.loads(raw)
        except ValueError as ex:
            rep.err(where, f"DATA is not valid JSON: {ex}")
            continue
        for key in ("Line", "Prop", "Req"):
            if key not in data:
                rep.err(where, f"DATA missing {key}")
        if not isinstance(data.get("Prop"), (dict, list)):
            rep.err(where, "Prop must be an object or []")
        for ci, c in enumerate(data.get("Req") or []):
            check_cond(c, f"{where} Req[{ci}]", rep)
        branches = data.get("Branch") or {}
        if not isinstance(branches, dict):
            rep.err(where, "Branch must be an object")
            branches = {}
        used, made, ptused = set(), set(), []
        check_line(data.get("Line", []), f"{where} Line", branches, rep, known_anims,
                   used, made, ptused)
        for bname, b in branches.items():
            if not isinstance(b, dict) or "Line" not in b:
                rep.err(where, f"branch {bname!r} must have a Line")
                continue
            for ci, c in enumerate(b.get("Req") or []):
                check_cond(c, f"{where} Branch[{bname}].Req[{ci}]", rep)
            check_line(b["Line"], f"{where} Branch[{bname}]", branches, rep, known_anims,
                       used, made, ptused)
        for bname in branches:
            if bname not in used:
                rep.warn(where, f"branch {bname!r} is never referenced")
        for w, t in ptused:
            if t not in made:
                rep.warn(w, f"PROJECTILE TAG {t!r} has no PROJECTILE in this entry")
    if layout:
        _check_layout(document, rep)
    return rep


def _check_layout(document, rep):
    kinds = [e.get("K_NAME") for e in document]
    melee = kinds.count("MELEE")
    if melee and melee != 4:
        rep.warn("layout", f"{melee} MELEE entries (the M1 string uses them in order)")
    base, awk = {}, {}
    for e in document:
        if e.get("K_NAME") != "SKILL":
            continue
        try:
            p = json.loads(e["DATA"]).get("Prop") or {}
        except (ValueError, KeyError):
            continue
        if isinstance(p, list):
            p = {}
        hidden_base, hidden_awk = p.get("AWK2", False), p.get("AWK", False)
        if hidden_base and hidden_awk:
            continue            # hidden helper skill
        if not hidden_base:
            base.setdefault(e.get("KEY"), []).append(e.get("NAME"))
        if not hidden_awk:
            awk.setdefault(e.get("KEY"), []).append(e.get("NAME"))
    for mode, table in (("base", base), ("awakened", awk)):
        for k, names in table.items():
            if len(names) > 1:
                rep.warn("layout", f"{mode} key {k} has {len(names)} skills: {names}")
