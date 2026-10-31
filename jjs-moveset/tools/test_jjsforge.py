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


def test_particle_node():
    p = nodes.Particle(123, col=((255, 0, 0), (0, 0, 255)), size=(1, 0), lifetime=0.3,
                       speed=0)
    assert p["COLOR"] == "255,0,0 0,0,255" and p["SIZE"] == "1, 0"
    assert p["LIFETIME"] == "0.3, 0.3" and p["SPEED"] == "0, 0"
    assert len(p) == 37 and "CANCEL TAG" not in p       # the game's usual 37-field layout
    rep = validate.Report()
    validate.check_node(p, "p", rep)
    assert rep.ok, rep.summary()
    rep = validate.Report()
    validate.check_node(dict(p, **{"ORIENTATION TYPE": "Sideways"}), "p", rep)
    assert not rep.ok
    c = nodes.CancelParticle("aura")
    assert c["CANCEL"] is True and c["CANCEL TAG"] == "aura"
    try:
        nodes.Particle(123, orientation="Sideways")
    except nodes.NodeError:
        pass
    else:
        raise AssertionError("bad orientation accepted")


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


def test_stationary_projectile_is_a_sure_hit_zone():
    from jjsforge import analyze
    zone = nodes.Projectile("Z", dmg=2, speed=0, time=3, stun=1, continue_=True,
                            filter_interval=1)
    p = analyze.walk([zone])
    assert [h.t for h in p.hits] == [0, 1, 2]            # re-hits every FILTER INTERVAL
    moving = nodes.Projectile("M", dmg=2, speed=50, time=3, continue_=True,
                              filter_interval=1)
    assert len(analyze.walk([moving]).hits) == 1           # travelling: one modelled hit


def test_domain_expansion_wiring():
    import bellringer
    doc = {e["NAME"]: e for e in bellringer.build(13).document()}
    data = json.loads(doc["Strike the Bell"]["DATA"])
    br = data["Branch"]
    awk = br["awk"]["Line"]
    assert awk[0]["K_NAME"] == "WAIT" and awk[1] == nodes.Branch("garan")
    assert br["garan"]["Req"] == [nodes.HOLD()]            # hold R while awakened
    garan = br["garan"]["Line"]
    assert garan[0]["K_NAME"] == "TAG" and garan[0]["CHECK"] and garan[0]["BRANCH"] == "awk_gk"
    zone = [n for n in garan if n["K_NAME"] == "PROJECTILE"]
    assert len(zone) == 1 and zone[0]["SPEED"] == 0 and zone[0]["CONTINUE"]
    assert zone[0]["ATTACK TYPE"] == "Domain" and zone[0]["TIME"] > zone[0]["FILTER INTERVAL"]
    riders = [n for n in garan if n.get("PROJECTILE TAG") == bellringer.GARAN
              and n["K_NAME"] != "PROJECTILE"]
    assert len(riders) > 40                                # the temple rides the domain
    # one domain per awakening: the flag is cleared on spawn and on awakening
    for name in ("Bonsho", "Joya no Kane: 108 Tolls"):
        line = json.loads(doc[name]["DATA"])["Line"]
        assert any(n.get("TAG") == bellringer.GARAN_USED and n.get("VALUE") == "0"
                   for n in line), name
    # v1.0 has no domain
    old = {e["NAME"]: e for e in bellringer.build(12).document()}
    assert "garan" not in json.loads(old["Strike the Bell"]["DATA"])["Branch"]


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


def test_value_types_match_real_exports():
    import bellringer
    with open(os.path.join(HERE, "data", "field_types.json")) as f:
        table = json.load(f)
    doc = bellringer.build(bellringer.MILESTONES[-1][0]).document()
    issues = validate.check_export_types(doc, table)
    assert not issues, "\n".join(issues[:10])


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
