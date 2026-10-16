#!/usr/bin/env python3
"""
Generate tests/fake/classes.luau: the Roblox classes and enums the fake runtime
(tests/fake/roblox.luau) needs, taken from luau-lsp's Roblox type definitions so the
fake knows every real property, its type, every event and every method.

With it the smoke test fails the same way Roblox would on a typo'd property, a value
of the wrong type or a method that doesn't exist.

Usage:
    python3 tools/gen_fake_roblox.py /path/to/globalTypes.d.luau

Only re-run it when the code starts using a class or enum that isn't in the file yet
(the fake says which).
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "tests", "fake", "classes.luau")

# Classes the game creates or gets from the engine (their base classes come along).
CLASSES = [
    # UI
    "ScreenGui", "Frame", "TextLabel", "TextButton", "TextBox", "ImageLabel", "ImageButton",
    "ScrollingFrame", "CanvasGroup", "ViewportFrame", "UICorner", "UIStroke", "UIScale",
    "UIListLayout", "UIGridLayout", "UIPadding", "UISizeConstraint", "UITextSizeConstraint",
    "UIAspectRatioConstraint", "UIGradient", "UIPageLayout", "UIFlexItem",
    # misc instances
    "Folder", "Sound", "SoundGroup", "NumberValue", "StringValue", "BoolValue", "IntValue",
    "ObjectValue", "RemoteEvent", "RemoteFunction", "UnreliableRemoteEvent", "BindableEvent",
    "BindableFunction", "ExperienceInviteOptions", "TeleportOptions", "Tween", "InputObject",
    "Player", "PlayerGui", "PlayerScripts", "Backpack", "Camera", "ModuleScript", "LocalScript",
    "Script",
    # services
    "DataModel", "Workspace", "Players", "ReplicatedStorage", "ReplicatedFirst", "RunService",
    "UserInputService", "TweenService", "GuiService", "StarterGui", "StarterPlayer",
    "SoundService", "SocialService", "MarketplaceService", "HttpService", "ContentProvider",
    "TextService", "DataStoreService", "MemoryStoreService", "TeleportService", "PolicyService",
    "UserService", "ServerScriptService", "ServerStorage", "Lighting", "Debris",
    "CollectionService", "LocalizationService", "GroupService", "BadgeService",
    "MessagingService", "AnalyticsService",
    # what services hand back
    "DataStore", "OrderedDataStore", "DataStorePages", "MemoryStoreSortedMap",
    "MemoryStoreQueue",
]


def parse(src):
    classes = {}
    for name, sup, body in re.findall(r"^declare extern type (\w+)(?: extends (\w+))? with\n(.*?)^end", src, re.M | re.S):
        props, signals, methods = {}, [], []
        for line in body.split("\n"):
            m = re.match(r"^\t\t?function (\w+)\(", line)
            if m:
                methods.append(m.group(1))
                continue
            m = re.match(r"^\t\t?(\w+): (.+)$", line)
            if m:
                pname, ptype = m.group(1), m.group(2).strip()
                if ptype.startswith("RBXScriptSignal"):
                    signals.append(pname)
                else:
                    props[pname] = ptype
        classes[name] = (sup, props, sorted(set(signals)), sorted(set(methods)))
    enums = {}
    for name, body in re.findall(r"^declare extern type Enum(\w+)_INTERNAL extends Enum with\n(.*?)^end", src, re.M | re.S):
        items = re.findall(r"^\t(\w+): Enum\w+$", body, re.M)
        enums[name] = items
    return classes, enums


def simplify(t):
    """The type checks the fake does: a datatype name, an enum, an instance class, or any."""
    t = t.strip()
    optional = t.endswith("?")
    if optional:
        t = t[:-1]
    if t in ("number", "boolean", "string"):
        return t
    if t == "ContentId":
        return "string"
    if t.startswith("Enum") and re.match(r"^Enum\w+$", t):
        return t
    if t in ("UDim", "UDim2", "Vector2", "Vector3", "Color3", "Rect", "Font", "ColorSequence",
             "NumberSequence", "NumberRange", "CFrame", "TweenInfo", "Content", "BrickColor"):
        return t
    if re.match(r"^\w+$", t):
        return "Instance:" + t
    return "any"


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(2)
    src = open(sys.argv[1], encoding="utf-8").read()
    classes, enums = parse(src)
    need = []
    seen = set()
    for c in CLASSES:
        n = c
        chain = []
        while n in classes and n not in seen:
            chain.append(n)
            seen.add(n)
            n = classes[n][0]
        if c not in classes:
            raise SystemExit("unknown class " + c)
        need.extend(chain)
    # enums: the ones used by these classes' properties and the ones the code names
    used = set()
    for n in need:
        for t in classes[n][1].values():
            s = simplify(t)
            if s.startswith("Enum"):
                used.add(s[4:])
    for folder in ("src", "tests"):
        for dirpath, _d, files in os.walk(os.path.join(ROOT, folder)):
            for fn in files:
                if fn.endswith((".lua", ".luau")):
                    text = open(os.path.join(dirpath, fn), encoding="utf-8").read()
                    used.update(re.findall(r"\bEnum\.(\w+)", text))
    used.update(["PlaybackState", "UserInputType", "UserInputState", "KeyCode", "SortDirection",
                 "InfoType", "Platform", "PreferredInput", "MembershipType", "FontStyle", "FontWeight",
                 "AssetFetchStatus", "EasingStyle", "EasingDirection", "ModifierKey", "SwipeDirection"])
    lines = [
        "-- AUTO-GENERATED by tools/gen_fake_roblox.py from luau-lsp's Roblox type definitions.",
        "-- Do not edit: re-run the script instead (see its header).",
        "-- FAKE_CLASSES[name] = { superclass, { property = type }, { events }, { methods } }",
        "-- FAKE_ENUMS[name] = { items in order }",
        "",
        "FAKE_CLASSES = {",
    ]
    for n in sorted(need):
        sup, props, signals, methods = classes[n]
        p = ", ".join("%s = %r" % (k, simplify(v)) if re.match(r"^[A-Za-z_]\w*$", k) else "[%r] = %r" % (k, simplify(v)) for k, v in sorted(props.items()))
        s = ", ".join("%r" % x for x in signals)
        m = ", ".join("%r" % x for x in methods)
        lines.append("\t%s = { %r, { %s }, { %s }, { %s } }," % (n, sup if sup in classes else "", p, s, m))
    lines.append("}")
    lines.append("")
    lines.append("FAKE_ENUMS = {")
    for e in sorted(used):
        if e in enums:
            lines.append("\t%s = { %s }," % (e, ", ".join("%r" % x for x in enums[e])))
    lines.append("}")
    text = "\n".join(lines).replace("'", '"') + "\n"
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", encoding="utf-8") as f:
        f.write(text)
    print("wrote %s: %d classes, %d enums" % (os.path.relpath(OUT, ROOT), len(need), len([e for e in used if e in enums])))


if __name__ == "__main__":
    main()
