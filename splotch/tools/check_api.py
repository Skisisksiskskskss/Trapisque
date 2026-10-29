#!/usr/bin/env python3
"""Static check of Roblox API usage against the official API dump.

Catches the typos Studio would only report at runtime:
  * Enum.Type.Item references that do not exist
  * Instance.new / GetService with unknown or non-creatable class names
  * property, method and event names used on variables whose class is known
    from Instance.new(...), GetService(...), or a type annotation

Usage: tools/check_api.py <api-dump.json> <src dir>
Fetch the dump with tools/fetch_api_dump.sh. Exits non-zero on findings.
"""

import json
import re
import sys
from pathlib import Path

ENUM_RE = re.compile(r"\bEnum\.(\w+)\.(\w+)")
NEW_RE = re.compile(r"\bInstance\.new\(\s*\"(\w+)\"")
SERVICE_RE = re.compile(r"GetService\(\s*\"(\w+)\"")
# local x = Instance.new("Class") / local x = game:GetService("Class")
LOCAL_NEW_RE = re.compile(r"(?<![.\w])(\w+)\s*(?::\s*\w+)?\s*=\s*Instance\.new\(\s*\"(\w+)\"")
LOCAL_SERVICE_RE = re.compile(r"\blocal\s+(\w+)\s*=\s*game:GetService\(\s*\"(\w+)\"\)\s*$", re.M)
# name: Class annotations (locals and parameters)
ANNOTATION_RE = re.compile(r"\b(\w+)\s*:\s*(\w+)\??\s*[,)=\n]")
MEMBER_RE = re.compile(r"\b(\w+)([.:])(\w+)\b")

# Members that every Lua/Luau value or our own code legitimately adds.
IGNORED_MEMBERS = {"new"}


def load_api(path):
    dump = json.loads(Path(path).read_text())
    classes = {c["Name"]: c for c in dump["Classes"]}
    enums = {e["Name"]: {i["Name"] for i in e["Items"]} for e in dump["Enums"]}
    return classes, enums


def members_of(classes, name, cache={}):
    if name in cache:
        return cache[name]
    result = set()
    current = name
    while current and current in classes:
        cls = classes[current]
        for member in cls.get("Members", []):
            result.add(member["Name"])
        current = cls.get("Superclass")
    cache[name] = result
    return result


def strip_comments_and_strings(text):
    # Remove block comments, line comments and string contents (keep quotes so
    # Instance.new("X") style patterns still work on the original text).
    text = re.sub(r"--\[(=*)\[.*?\]\1\]", "", text, flags=re.S)
    text = re.sub(r"--[^\n]*", "", text)
    return text


def check_file(path, classes, enums):
    findings = []
    raw = path.read_text()
    code = strip_comments_and_strings(raw)

    for match in ENUM_RE.finditer(code):
        enum, item = match.groups()
        if enum not in enums:
            findings.append(f"unknown enum Enum.{enum}")
        elif item not in enums[enum] and item not in ("GetEnumItems", "FromName", "FromValue"):
            findings.append(f"unknown enum item Enum.{enum}.{item}")

    for match in NEW_RE.finditer(code):
        name = match.group(1)
        cls = classes.get(name)
        if not cls:
            findings.append(f"Instance.new of unknown class {name}")
        elif "NotCreatable" in cls.get("Tags", []):
            findings.append(f"Instance.new of non-creatable class {name}")

    for match in SERVICE_RE.finditer(code):
        name = match.group(1)
        if name not in classes:
            findings.append(f"GetService of unknown class {name}")

    # Map variable names to classes. A name bound to two different classes in
    # one file is ambiguous and skipped.
    bindings = {}

    def bind(var, cls_name):
        if cls_name not in classes:
            return
        bindings.setdefault(var, set()).add(cls_name)

    for match in LOCAL_NEW_RE.finditer(code):
        bind(*match.groups())
    for match in LOCAL_SERVICE_RE.finditer(code):
        bind(*match.groups())
    for match in ANNOTATION_RE.finditer(code):
        bind(*match.groups())
    bindings["workspace"] = {"Workspace"}

    for match in MEMBER_RE.finditer(code):
        var, sep, member = match.groups()
        kinds = bindings.get(var)
        if not kinds or len(kinds) != 1 or member in IGNORED_MEMBERS:
            continue
        cls_name = next(iter(kinds))
        if member not in members_of(classes, cls_name):
            # Dot access can be a child lookup on containers; only report it
            # for classes that are not meant to hold named children.
            if sep == "." and cls_name in ("Folder", "Model", "Workspace", "ScreenGui", "Frame"):
                continue
            line = code[: match.start()].count("\n") + 1
            findings.append(f"line ~{line}: {cls_name} has no member '{member}' ({var}{sep}{member})")

    findings.extend(check_prop_tables(code, classes))
    return findings


CREATE_RE = re.compile(r"\bUi\.create\(\s*\"(\w+)\"\s*,\s*\{")
LABEL_RE = re.compile(r"\bUi\.label\(\s*\{")
KEY_RE = re.compile(r"(?:^|,)\s*(\w+)\s*=(?!=)", re.M)
# Keys Ui.create handles itself rather than setting as properties.
HELPER_KEYS = {"Parent"}


def table_body(code, open_index):
    """Text of the table literal starting at code[open_index] == '{', top level only."""
    depth = 0
    out = []
    for ch in code[open_index:]:
        if ch in "{([":
            depth += 1
            if depth == 1:
                continue
        elif ch in "})]":
            depth -= 1
            if depth == 0:
                break
        # Keep only top-level text; nested tables and calls become blanks.
        out.append(ch if depth == 1 else " ")
    return "".join(out)


def check_prop_tables(code, classes):
    findings = []
    calls = [(m.group(1), m.end() - 1, m.start()) for m in CREATE_RE.finditer(code)]
    calls += [("TextLabel", m.end() - 1, m.start()) for m in LABEL_RE.finditer(code)]
    for cls_name, open_index, start in calls:
        if cls_name not in classes:
            continue
        members = members_of(classes, cls_name)
        for key in KEY_RE.findall(table_body(code, open_index)):
            if key not in members and key not in HELPER_KEYS:
                line = code[:start].count("\n") + 1
                findings.append(f"line ~{line}: {cls_name} has no property '{key}' (in Ui.create/Ui.label)")
    return findings


def main():
    if len(sys.argv) != 3:
        print(__doc__)
        return 2
    classes, enums = load_api(sys.argv[1])
    total = 0
    for path in sorted(Path(sys.argv[2]).rglob("*.luau")):
        for finding in check_file(path, classes, enums):
            total += 1
            print(f"{path}: {finding}")
    print(f"check_api: {total} finding(s)")
    return 1 if total else 0


if __name__ == "__main__":
    sys.exit(main())
