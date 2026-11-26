"""Regenerates tests/mock/ApiIndex.luau from a Roblox API dump.

    python3 tests/mock/gen_api_index.py path/to/API-Dump.json

Get the dump from https://github.com/MaximumADHD/Roblox-Client-Tracker (API-Dump.json).
Each class row is { superclass, events, methods+callbacks, deprecated properties }.
"""

import json
import sys
from pathlib import Path


def main() -> None:
    dump = json.loads(Path(sys.argv[1]).read_text())
    out = [
        "-- Generated from the Roblox API dump: superclass, events and methods per class.",
        "-- Used by the smoke-test mock to tell real (unmocked) members apart from typos.",
        "-- Regenerate with: python3 tests/mock/gen_api_index.py API-Dump.json",
        "return {",
    ]
    for cls in sorted(dump["Classes"], key=lambda c: c["Name"]):
        events, methods, deprecated = [], [], []
        for member in cls["Members"]:
            kind = member["MemberType"]
            tags = member.get("Tags") or []
            if kind == "Event":
                events.append(member["Name"])
            elif kind in ("Function", "YieldFunction", "Callback"):
                methods.append(member["Name"])
            elif kind == "Property" and "Deprecated" in tags:
                deprecated.append(member["Name"])
        out.append(
            '\t["%s"] = { "%s", "%s", "%s", "%s" },'
            % (cls["Name"], cls.get("Superclass") or "", ",".join(events), ",".join(methods), ",".join(deprecated))
        )
    out.append("}")
    target = Path(__file__).with_name("ApiIndex.luau")
    target.write_text("\n".join(out) + "\n")
    print(f"wrote {target} ({len(dump['Classes'])} classes)")


if __name__ == "__main__":
    main()
