#!/usr/bin/env python3
"""Self-contained checks for jjsforge and the Bellringer build.

    python3 tools/test_jjsforge.py
"""
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "..", "movesets", "bellringer"))

from jjsforge import anims, codec, nodes, validate  # noqa: E402
from jjsforge.model import BASE, Br, Character, Melee, Skill  # noqa: E402


def test_codec_roundtrip():
    doc = [{"NAME": "x", "K_NAME": "SKILL", "KEY": 1, "ADD": False, "TOOL TIP": "",
            "COOLDOWN": 5, "DATA": codec.dumps_compact({"Line": [nodes.Wait(0.1)],
                                                        "Prop": [], "Req": []})}]
    code = codec.encode(doc)
    assert code.startswith("KLUv/"), code[:8]
    assert codec.decode(code) == doc
    # whitespace / missing padding tolerated
    assert codec.decode(" " + code.rstrip("=") + "\n") == doc


def test_node_types():
    v = nodes.Visual("Glow", time=0.3, col=(255, 1, 2), pos=(0, 1.5, 0))
    assert v["COLOR"] == "255, 1, 2" and v["POSITION"] == "0, 1.5, 0"
    assert "VISUAL TAG" not in v           # reference fields omitted when unused
    h = nodes.Hitbox(3, target="hit")
    assert h["BRANCH TARGET"] == "hit" and "BRANCH" not in h
    assert nodes.Sfx(1, vol=0.1 + 0.2)["VOLUME"] == 0.3   # float noise rounded
    a = nodes.Anim(anims.M1_1)
    assert a["ANIM_USE"] == [1, 13] and a["PREVIEW"] == [0, 0.333]
    try:
        nodes.Visual("NotAnEffect")
    except nodes.NodeError:
        pass
    else:
        raise AssertionError("bad effect accepted")


def test_validator_catches_dangling_branch():
    s = Skill("t", 1, 1, [nodes.Branch("nope")], props=BASE())
    rep = validate.validate(Character("t").add(s).document())
    assert not rep.ok and any("missing branch" in e for e in rep.errors)
    good = Skill("t", 1, 1, [nodes.Branch("yes")], {"yes": Br([nodes.Wait(0.1)])}, BASE())
    assert validate.validate(Character("t").add(good).document()).ok


def test_loop_bounds():
    m = Melee("m", [nodes.Wait(0.1), nodes.Loop(3, 2)])
    rep = validate.validate(Character("t").add(m).document(), layout=False)
    assert any("LOOP BACK" in e for e in rep.errors)


def test_combo_checker_respects_nom1():
    from jjsforge import analyze
    p1 = analyze.Path("a", hits=[analyze.Hit(0.2, 3, 0.75)], end=0.35, no_m1_until=0.9)
    p2 = analyze.Path("b", hits=[analyze.Hit(0.2, 3, 0.75)], end=0.35)
    rows, _, ok = analyze.check_combo([analyze.ComboStep("a", p1),
                                       analyze.ComboStep("b", p2, is_m1=True)])
    assert rows[1][1] == 0.9          # the M1 waits for NoM1 to expire
    assert not ok                     # 0.9 + 0.2 > 0.2 + 0.75 -> a gap


def test_skill_lockouts_end_with_skill():
    import bellringer
    ch = bellringer.build(bellringer.MILESTONES[-1][0])
    for e in ch.document():
        if e["K_NAME"] == "MELEE":
            continue
        data = json.loads(e["DATA"])
        for line in [data["Line"]] + [b["Line"] for b in (data.get("Branch") or {}).values()]:
            for n in line:
                if (n["K_NAME"] == "STATE" and n["STATE"] in bellringer.LOCKOUTS
                        and not n["CHECK"]):
                    assert n["CANCEL ON END"], (e["NAME"], n)


def test_bellringer_builds():
    import bellringer
    for stage, version, _ in bellringer.MILESTONES:
        ch = bellringer.build(stage)
        doc = ch.document()
        rep = validate.validate(doc, known_anims=anims.known_pairs())
        assert rep.ok, rep.summary()
        kinds = [e["K_NAME"] for e in doc]
        assert kinds.count("MELEE") == 4
        code = codec.encode(doc)
        assert codec.decode(code) == json.loads(codec.dumps_compact(doc))
        for e in doc:
            data = json.loads(e["DATA"])
            if e["K_NAME"] == "SKILL" and 1 <= e["KEY"] <= 4:
                p = data["Prop"]
                assert p and (p.get("AWK") or p.get("AWK2")), e["NAME"]


if __name__ == "__main__":
    tests = [v for k, v in sorted(globals().items()) if k.startswith("test_")]
    for t in tests:
        t()
        print("ok ", t.__name__)
    print(f"{len(tests)} passed")
