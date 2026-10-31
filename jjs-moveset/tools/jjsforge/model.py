"""Character / skill containers that compile to the game's JSON document.

Entry kinds (top-level K_NAME):
  SKILL      hotbar move: KEY (1-4 shown), COOLDOWN, TOOL TIP, ADD
  MELEE      one M1 of the 4-hit string (entries are used in order)
  CHASE      the front dash (Q), COOLDOWN
  SPECIAL    the R ability, COOLDOWN
  AWAKENING  the G awakening: DURATION (s), DELAY, COLOR (bar gradient), Line runs
             once on activation

Skill properties (Prop) - meanings from the in-game tooltips:
  AWK   hide this skill while awakened   (=> a base move)
  AWK2  hide this skill while NOT awakened (=> an awakening move)
  USE   run automatically when obtained (spawn / passive loops)
  USEONDEATH run when the user dies
  NOSTUN    other skills may be used while this one runs
  NOCANCEL  taking damage does not cancel it
  INV   invincible while active
  REP   replace instead of stacking if the slot is occupied
  REP2  prevent override
  KEEP  keep when the moveset switches
  DMG / KNOCK  damage / knockback multipliers (strings)
  VAR   variant tag
"""
from __future__ import annotations

import json
from dataclasses import dataclass, field
from typing import Optional

from . import codec


@dataclass
class Props:
    hide_in_awakening: bool = False   # AWK
    hide_in_base: bool = False        # AWK2
    use_when_obtained: bool = False   # USE
    use_on_death: bool = False        # USEONDEATH
    no_stun: bool = False             # NOSTUN
    no_cancel: bool = False           # NOCANCEL
    invincible: bool = False          # INV
    replace: bool = False             # REP
    prevent_override: bool = False    # REP2
    keep: bool = False                # KEEP
    dmg: Optional[float] = None       # DMG
    knock: Optional[float] = None     # KNOCK
    var: Optional[str] = None         # VAR

    def to_json(self):
        p = {}
        flags = [("AWK", self.hide_in_awakening), ("AWK2", self.hide_in_base),
                 ("USE", self.use_when_obtained), ("USEONDEATH", self.use_on_death),
                 ("NOSTUN", self.no_stun), ("NOCANCEL", self.no_cancel),
                 ("INV", self.invincible), ("REP", self.replace),
                 ("REP2", self.prevent_override), ("KEEP", self.keep)]
        for k, v in flags:
            if v:
                p[k] = True
        if self.dmg is not None:
            p["DMG"] = _numstr(self.dmg)
        if self.knock is not None:
            p["KNOCK"] = _numstr(self.knock)
        if self.var:
            p["VAR"] = self.var
        return p or []          # the game writes an empty Lua table as []


def _numstr(x):
    if isinstance(x, float) and x.is_integer():
        x = int(x)
    return str(x)


# Common property presets
def BASE(**kw):        return Props(hide_in_awakening=True, **kw)
def AWAKENED(**kw):    return Props(hide_in_base=True, **kw)
def PASSIVE(**kw):     return Props(hide_in_awakening=True, hide_in_base=True,
                                    use_when_obtained=True, no_stun=True, no_cancel=True, **kw)


@dataclass
class Br:
    """A named branch: its Req must pass for a BRANCH node to enter it."""
    line: list
    req: list = field(default_factory=list)

    def to_json(self):
        return {"Req": list(self.req), "Line": list(self.line)}


@dataclass
class Entry:
    kind: str
    name: str
    line: list
    branches: dict = field(default_factory=dict)
    props: Props = field(default_factory=Props)
    req: list = field(default_factory=list)
    key: Optional[int] = None
    cooldown: Optional[float] = None
    tooltip: Optional[str] = None
    add: bool = False
    duration: Optional[float] = None
    delay: Optional[float] = None
    color: Optional[str] = None
    notes: str = ""            # design notes (not exported)

    def data(self) -> dict:
        d = {"Line": list(self.line), "Prop": self.props.to_json(), "Req": list(self.req)}
        if self.branches:
            d["Branch"] = {k: (v.to_json() if isinstance(v, Br) else v)
                           for k, v in self.branches.items()}
        return d

    def to_json(self) -> dict:
        e = {"NAME": self.name, "K_NAME": self.kind}
        if self.kind == "SKILL":
            e["ADD"] = bool(self.add)
            e["KEY"] = int(self.key if self.key is not None else 1)
            e["TOOL TIP"] = self.tooltip or ""
            e["COOLDOWN"] = self.cooldown if self.cooldown is not None else 0
        elif self.kind in ("CHASE", "SPECIAL"):
            e["COOLDOWN"] = self.cooldown if self.cooldown is not None else 0
        elif self.kind == "AWAKENING":
            e["DURATION"] = self.duration if self.duration is not None else 60
            e["DELAY"] = self.delay if self.delay is not None else 0
            if self.color:
                e["COLOR"] = self.color
        e["DATA"] = codec.dumps_compact(self.data())
        return e


def Skill(name, key, cooldown, line, branches=None, props=None, req=None, tooltip="",
          add=False, notes=""):
    return Entry("SKILL", name, line, branches or {}, props or Props(), req or [],
                 key=key, cooldown=cooldown, tooltip=tooltip, add=add, notes=notes)


def Melee(name, line, branches=None, props=None, req=None, notes=""):
    return Entry("MELEE", name, line, branches or {}, props or Props(), req or [],
                 notes=notes)


def Chase(name, cooldown, line, branches=None, props=None, req=None, notes=""):
    return Entry("CHASE", name, line, branches or {}, props or Props(), req or [],
                 cooldown=cooldown, notes=notes)


def Special(name, cooldown, line, branches=None, props=None, req=None, notes=""):
    return Entry("SPECIAL", name, line, branches or {}, props or Props(), req or [],
                 cooldown=cooldown, notes=notes)


def Awakening(name, duration, line, branches=None, props=None, req=None, delay=0,
              color=None, notes=""):
    return Entry("AWAKENING", name, line, branches or {}, props or Props(), req or [],
                 duration=duration, delay=delay, color=color, notes=notes)


class Character:
    def __init__(self, name: str, version: str = "0.0"):
        self.name = name
        self.version = version
        self.entries: list[Entry] = []

    def add(self, *entries: Entry):
        self.entries.extend(entries)
        return self

    def document(self) -> list:
        return [e.to_json() for e in self.entries]

    def code(self) -> str:
        return codec.encode(self.document())

    def readable_json(self) -> str:
        """Pretty JSON with DATA expanded (for humans / diffs; not importable)."""
        return json.dumps(codec.explode(self.document()), indent=1, ensure_ascii=False)
