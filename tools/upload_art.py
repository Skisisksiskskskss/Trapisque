#!/usr/bin/env python3
"""
Puts the art sheets on Roblox, so the game loads them as images (which works in every
game, on every device) instead of building them itself (which Roblox only allows once
an ID-verified owner turns on Allow Mesh / Image APIs).

Upload every sheet in art/sheets that has no current upload (new, or changed since its
upload) with Open Cloud, and write its image id into src/client/UI/ArtAssets.lua:

    ROBLOX_API_KEY=... ROBLOX_CREATOR=user:<your user id> python3 tools/upload_art.py
    (ROBLOX_CREATOR=group:<group id> for a game a group owns)

The key comes from create.roblox.com > Open Cloud > API Keys > Create API Key, with the
Assets API allowed to read and write, made by the user or group that owns the game.

Or write in the ids of sheets uploaded by hand (Studio: the Asset Manager's import
button, then each image's Copy Asset ID):

    python3 tools/upload_art.py scenery_1=123456789 icons_2=987654321

Either way, a sheet that now has a current upload has its pixels (ArtData) dropped from
the place, since the game no longer needs them. Run tools/art.py first if the art
changed, and build the place again after (rojo build, or tools/publish.sh).
"""
import json
import os
import sys
import time
import urllib.error
import urllib.request
import uuid

import artassets

UPLOAD = "https://apis.roblox.com/assets/v1/assets"
OPERATION = "https://apis.roblox.com/assets/v1/operations/"


def creator_of(text: str):
    kind, _, ident = (text or "").partition(":")
    if kind not in ("user", "group") or not ident.isdigit():
        raise SystemExit("ROBLOX_CREATOR should be user:<user id> or group:<group id>")
    return {"userId": ident} if kind == "user" else {"groupId": ident}


def call(req: urllib.request.Request):
    try:
        with urllib.request.urlopen(req, timeout=120) as resp:
            return json.load(resp)
    except urllib.error.HTTPError as err:
        raise SystemExit(f"Roblox said {err.code}: {err.read().decode('utf-8', 'replace')[:500]}")


def upload(key: str, creator, sheet: str) -> int:
    """Uploads art/sheets/<sheet>.png as an image; returns its asset id."""
    with open(os.path.join(artassets.SHEETS, sheet + ".png"), "rb") as fh:
        png = fh.read()
    request = {
        "assetType": "Image",
        "displayName": f"Trapisque {sheet}",
        "description": "Trapisque art sheet (tools/art.py)",
        "creationContext": {"creator": creator},
    }
    boundary = "trapisque" + uuid.uuid4().hex
    body = (
        f"--{boundary}\r\n"
        'Content-Disposition: form-data; name="request"\r\n'
        "Content-Type: application/json\r\n\r\n"
        f"{json.dumps(request)}\r\n"
        f"--{boundary}\r\n"
        f'Content-Disposition: form-data; name="fileContent"; filename="{sheet}.png"\r\n'
        "Content-Type: image/png\r\n\r\n"
    ).encode("utf-8") + png + f"\r\n--{boundary}--\r\n".encode("utf-8")
    op = call(
        urllib.request.Request(
            UPLOAD,
            data=body,
            method="POST",
            headers={"x-api-key": key, "Content-Type": f"multipart/form-data; boundary={boundary}"},
        )
    )
    ident = op.get("operationId") or op.get("path", "").rsplit("/", 1)[-1]
    wait = 1.0
    for _ in range(40):
        if op.get("done"):
            break
        time.sleep(wait)
        wait = min(wait * 1.6, 8)
        op = call(urllib.request.Request(OPERATION + ident, headers={"x-api-key": key}))
    if not op.get("done"):
        raise SystemExit(f"{sheet}: Roblox is still processing the upload (operation {ident}); run this again later")
    asset = (op.get("response") or {}).get("assetId")
    if not asset:
        raise SystemExit(f"{sheet}: the upload finished without an asset id: {json.dumps(op)[:500]}")
    return int(asset)


def main(args):
    vers = artassets.versions()
    known = artassets.read()
    given = {}
    for arg in args:
        name, _, ident = arg.partition("=")
        if name not in vers or not ident.isdigit():
            raise SystemExit(f"{arg}: expected sheet=id, with sheet one of {', '.join(vers)}")
        given[name] = int(ident)
    todo = [s for s in vers if s not in artassets.current(known, vers)]
    if given:
        for name, ident in given.items():
            known[name] = (ident, vers[name])
            print(f"{name}: {ident}")
    elif not todo:
        print("every sheet's upload is current")
    else:
        key = os.environ.get("ROBLOX_API_KEY", "")
        if not key:
            raise SystemExit("set ROBLOX_API_KEY (and ROBLOX_CREATOR), or give the ids: sheet=id ...")
        creator = creator_of(os.environ.get("ROBLOX_CREATOR", ""))
        for name in todo:
            ident = upload(key, creator, name)
            known[name] = (ident, vers[name])
            # (written after each, so a failure halfway keeps what got through)
            artassets.write([(n, *known.get(n, (0, vers[n]))) for n in vers])
            print(f"{name}: {ident}")
    entries = []
    for name, ver in vers.items():
        ident, up = known.get(name, (0, None))
        entries.append((name, ident, ver if ident <= 0 or up is None else up))
    artassets.write(entries)
    done = artassets.current(known, vers)
    for name in done:
        path = os.path.join(artassets.DATA, name + ".lua")
        if os.path.exists(path):
            os.remove(path)
    left = [n for n in vers if n not in done]
    print(f"{len(done)} of {len(vers)} sheets uploaded" + (f"; still to upload: {', '.join(left)}" if left else ""))


if __name__ == "__main__":
    main(sys.argv[1:])
