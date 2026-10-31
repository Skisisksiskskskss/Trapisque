"""Static timing analysis ("frame data") for Skill Builder timelines.

Model (matches how the timeline runs: nodes fire instantly in order, WAIT
advances time, LOOP replays the previous N nodes, branch transfers are gotos):

* a *path* is the user's main Line, optionally continued into a branch at a
  jump point (BRANCH node / HITBOX on-hit / HITCNCL / TAG or STATE check);
* the user is busy until the path ends or until self-applied Stun ends;
* every HITBOX / PROJECTILE gives (time, damage, stun);
* `advantage` = target stun end - user recovery. > 0 means the user can act
  before the target can, i.e. a follow-up whose first hit comes out faster
  than the advantage is a true combo.
"""
from __future__ import annotations

import json
from dataclasses import dataclass, field


@dataclass
class Hit:
    t: float
    dmg: float
    stun: float
    kind: str = "HITBOX"
    target_branch: str | None = None
    note: str = ""


@dataclass
class Path:
    label: str
    hits: list = field(default_factory=list)
    end: float = 0.0          # when the timeline finishes
    self_lock: float = 0.0    # when self Stun / skill lock ends
    no_m1_until: float = 0.0
    jumps: list = field(default_factory=list)

    @property
    def recovery(self):
        return max(self.end, self.self_lock)

    def first_hit(self):
        return self.hits[0].t if self.hits else None

    def advantage(self):
        """Target stun end after the LAST hit minus user recovery."""
        if not self.hits:
            return None
        last = self.hits[-1]
        return round(last.t + last.stun - self.recovery, 3)


def _expand(line):
    """Expand LOOPs into a flat list of (node) with loop repetitions."""
    out = []
    for i, n in enumerate(line):
        if isinstance(n, dict) and n.get("K_NAME") == "LOOP":
            back = int(n.get("LOOP BACK", 0))
            amount = int(n.get("LOOP AMOUNT", 0))
            seg = line[max(0, i - back):i]
            # loops may contain loops; keep it simple: replay the raw segment
            for _ in range(max(0, min(amount, 200))):
                out.extend(x for x in seg if not (isinstance(x, dict) and x.get("K_NAME") == "LOOP"))
        else:
            out.append(n)
    return out


def walk(line, start=0.0, label="main", branches=None, take=None, depth=0):
    """Simulate one line. `take` is a dict {jump-key: branch} deciding which jump
    points are taken; jump keys are 'hit', 'miss', 'branch:<name>', 'tag:<name>',
    'state:<name>'. Returns a Path (continuing into taken branches)."""
    branches = branches or {}
    take = take or {}
    p = Path(label)
    t = start
    hit_happened = False
    for n in _expand(line):
        if not isinstance(n, dict):
            continue
        k = n.get("K_NAME")
        if k == "WAIT":
            t += float(n.get("TIME", 0) or 0)
        elif k == "STATE" and not n.get("CHECK") and n.get("LAST HIT", -1) in (-1, None):
            st, dur = n.get("STATE"), float(n.get("TIME", 0) or 0)
            if st == "Stun":
                p.self_lock = max(p.self_lock, t + dur)
            elif st == "NoM1":
                p.no_m1_until = max(p.no_m1_until, t + dur)
        elif k in ("HITBOX", "PROJECTILE"):
            if float(n.get("DAMAGE", 0) or 0) > 0 or float(n.get("STUN", 0) or 0) > 0:
                p.hits.append(Hit(round(t, 3), float(n.get("DAMAGE", 0) or 0),
                                  float(n.get("STUN", 0) or 0), k, n.get("BRANCH TARGET")))
            hit_happened = True
            b = n.get("BRANCH")
            if b and take.get("hit") == b and b in branches and depth < 8:
                sub = walk(branches[b]["Line"], t, label, branches, take, depth + 1)
                return _merge(p, sub, f"hit->{b}@{t:.2f}")
        elif k == "HITCNCL":
            b = n.get("BRANCH")
            key = "miss" if n.get("FLIP") else "hit"
            if take.get(key) is not None and (b is None or take.get(key) == b):
                p.jumps.append(f"{key}-cancel@{t:.2f}")
                p.self_lock = max(p.self_lock, t + float(n.get("ENDLAG", 0) or 0))
                if b in branches and depth < 8:
                    sub = walk(branches[b]["Line"], t, label, branches, take, depth + 1)
                    return _merge(p, sub, f"{key}->{b}@{t:.2f}")
                p.end = t
                return p
        elif k == "BRANCH":
            b = n.get("BRANCH")
            if b and take.get(f"branch:{b}") and b in branches and depth < 8:
                sub = walk(branches[b]["Line"], t, label, branches, take, depth + 1)
                return _merge(p, sub, f"->{b}@{t:.2f}")
        elif k in ("TAG", "STATE") and n.get("CHECK"):
            b = n.get("BRANCH")
            name = n.get("TAG") if k == "TAG" else n.get("STATE")
            if b and take.get(f"{k.lower()}:{name}") == b and b in branches and depth < 8:
                sub = walk(branches[b]["Line"], t, label, branches, take, depth + 1)
                return _merge(p, sub, f"{name}->{b}@{t:.2f}")
    p.end = round(t, 3)
    return p


def _merge(head: Path, tail: Path, jump: str) -> Path:
    tail.hits = head.hits + tail.hits
    tail.self_lock = max(head.self_lock, tail.self_lock)
    tail.no_m1_until = max(head.no_m1_until, tail.no_m1_until)
    tail.jumps = head.jumps + [jump] + tail.jumps
    tail.label = head.label
    return tail


def entry_paths(entry: dict, scenarios: dict) -> dict:
    """scenarios: {label: take-dict}. Returns {label: Path}."""
    data = json.loads(entry["DATA"]) if isinstance(entry["DATA"], str) else entry["DATA"]
    br = data.get("Branch") or {}
    out = {}
    for label, take in scenarios.items():
        start_line = data["Line"]
        out[label] = walk(start_line, 0.0, label, br, take)
    return out


def table(rows) -> str:
    """rows: list of (name, Path). Markdown frame-data table."""
    head = "| Move / path | Startup | Hits (t: dmg / stun) | Total dmg | Recovery | Advantage |\n|---|---|---|---|---|---|"
    lines = [head]
    for name, p in rows:
        hits = ", ".join(f"{h.t:.2f}s: {h.dmg:g}/{h.stun:g}" for h in p.hits) or "-"
        dmg = sum(h.dmg for h in p.hits)
        fh = p.first_hit()
        adv = p.advantage()
        lines.append(f"| {name} | {'-' if fh is None else f'{fh:.2f}s'} | {hits} | {dmg:g} | "
                     f"{p.recovery:.2f}s | {'-' if adv is None else f'{adv:+.2f}s'} |")
    return "\n".join(lines)
