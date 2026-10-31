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
    hit_ragdoll: bool = False      # can connect on a ragdolled target
    ragdoll: float = 0.0           # ragdoll the target branch applies (s)


@dataclass
class Path:
    label: str
    hits: list = field(default_factory=list)
    end: float = 0.0          # when the timeline finishes
    self_lock: float = 0.0    # when self Stun / skill lock ends
    no_m1_until: float = 0.0  # NoM1 that persists (CANCEL ON END false)
    no_m1_cancel: float = 0.0  # NoM1 that ends with the move (clamped in _finish)
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
                if n.get("CANCEL ON END"):
                    p.no_m1_cancel = max(p.no_m1_cancel, t + dur)
                else:
                    p.no_m1_until = max(p.no_m1_until, t + dur)
        elif k in ("HITBOX", "PROJECTILE"):
            if take.get("whiff"):
                continue     # whiff scenario: nothing connects, only recovery matters
            if float(n.get("DAMAGE", 0) or 0) > 0 or float(n.get("STUN", 0) or 0) > 0:
                tb = n.get("BRANCH TARGET")
                rag = 0.0
                for m in (branches.get(tb) or {}).get("Line", []) if tb else []:
                    if isinstance(m, dict) and m.get("K_NAME") == "VELO":
                        rag = max(rag, float(m.get("RAGDOLL", 0) or 0))
                p.hits.append(Hit(round(t, 3), float(n.get("DAMAGE", 0) or 0),
                                  float(n.get("STUN", 0) or 0), k, tb,
                                  hit_ragdoll=bool(n.get("HIT RAGDOLL")), ragdoll=rag))
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
    if depth == 0:
        _finish(p)
    return p


def _finish(p: Path):
    """Cancel-on-end NoM1 windows stop when the move ends."""
    p.no_m1_until = max(p.no_m1_until, min(p.no_m1_cancel, p.end))


def _merge(head: Path, tail: Path, jump: str) -> Path:
    tail.hits = head.hits + tail.hits
    tail.self_lock = max(head.self_lock, tail.self_lock)
    tail.no_m1_until = max(head.no_m1_until, tail.no_m1_until)
    tail.no_m1_cancel = max(head.no_m1_cancel, tail.no_m1_cancel)
    tail.jumps = head.jumps + [jump] + tail.jumps
    tail.label = head.label
    _finish(tail)
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


@dataclass
class ComboStep:
    label: str
    path: Path
    is_m1: bool = False
    delay: float = 0.0        # deliberate wait before this step (e.g. a jump)


def check_combo(steps, slack: float = 0.0):
    """Simulate a route. Each step starts as soon as the previous one recovers
    (+ its own delay). A step's first hit is a true follow-up if the target is
    still in hitstun, or ragdolled and the hitbox can hit ragdolls. Returns
    (rows, total_damage, ok). Positioning/range is not modelled."""
    rows, now, stun_end, rag_end, total, ok = [], 0.0, None, None, 0.0, True
    m1_free = 0.0                     # absolute time the user may M1 again
    for i, st in enumerate(steps):
        start = now + st.delay
        if st.is_m1:
            start = max(start, m1_free)
        p = st.path
        first = p.hits[0] if p.hits else None
        verdict = "starter"
        if i > 0 and first is not None:
            t_hit = start + first.t
            if rag_end is not None and t_hit <= rag_end:
                verdict = "OTG (hits ragdoll)" if first.hit_ragdoll else "MISSES: target ragdolled"
            elif stun_end is not None and t_hit <= stun_end + slack:
                verdict = f"true combo ({stun_end - t_hit:+.2f}s spare)"
            else:
                gap = t_hit - max(x for x in (stun_end, rag_end) if x is not None)
                verdict = f"GAP {gap:.2f}s"
            if verdict.startswith(("GAP", "MISSES")):
                ok = False
        for h in p.hits:
            th = start + h.t
            total += h.dmg
            stun_end = th + h.stun
            if h.ragdoll > 0:
                rag_end = th + h.ragdoll
            elif rag_end is not None and th > rag_end:
                rag_end = None
        rows.append((st.label, round(start, 2), None if first is None else round(start + first.t, 2),
                     verdict, round(sum(h.dmg for h in p.hits), 2)))
        now = start + p.recovery
        m1_free = max(m1_free, start + p.no_m1_until)
    return rows, round(total, 2), ok


def combo_table(name: str, rows, total: float, ok: bool) -> str:
    out = [f"**{name}** — {total:g} dmg — {'✅ verified' if ok else '❌ broken'}", "",
           "| Step | Starts | First hit | Connects as | Dmg |", "|---|---|---|---|---|"]
    for label, start, fh, verdict, dmg in rows:
        out.append(f"| {label} | {start:.2f}s | {'-' if fh is None else f'{fh:.2f}s'} | "
                   f"{verdict} | {dmg:g} |")
    return "\n".join(out)


def table(rows) -> str:
    """rows: list of (name, Path). Markdown frame-data table."""
    head = "| Move / path | Startup | Hits (t: dmg / stun) | Total dmg | Recovery | Advantage |\n|---|---|---|---|---|---|"
    lines = [head]
    for name, p in rows:
        hits = ", ".join(f"{h.t:.2f}s: {h.dmg:g}/{h.stun:g}" for h in p.hits) or "-"
        dmg = sum(h.dmg for h in p.hits)
        fh = p.first_hit()
        adv = p.advantage()
        lines.append(f"| {name} | {'-' if fh is None else f'{fh:.2f}s'} | {hits} | "
                     f"{dmg:g} | {p.recovery:.2f}s | {'-' if adv is None else f'{adv:+.2f}s'} |")
    lines.append("")
    lines.append("Rows marked *ragdoll* end in knockback/launch: their advantage is decided by "
                 "the ragdoll time rather than hitstun.")
    return "\n".join(lines)
