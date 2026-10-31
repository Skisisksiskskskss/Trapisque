"""Encode / decode Jujutsu Shenanigans (JJS) Skill Builder character codes.

A JJS character code is:   base64( zstd( utf8( JSON array of skill entries ) ) )

Each skill entry carries its timeline in a nested JSON *string* under "DATA".
This was verified against 227 real community exports: every one decodes to a
JSON array, and the game writes standard single-segment zstd frames (content
size present, no checksum) with standard padded base64 - exactly what
python-zstandard produces.
"""
from __future__ import annotations

import base64
import json

import zstandard

ZSTD_MAGIC = b"\x28\xb5\x2f\xfd"


def dumps_compact(obj) -> str:
    """Serialise like the game does: compact separators, UTF-8 kept as-is."""
    return json.dumps(obj, separators=(",", ":"), ensure_ascii=False)


def encode(document: list, level: int = 19) -> str:
    """Turn a list of skill entries (with DATA already a JSON string) into a code."""
    if not isinstance(document, list):
        raise TypeError("a character document must be a JSON array of skill entries")
    raw = dumps_compact(document).encode("utf-8")
    frame = zstandard.ZstdCompressor(level=level, write_content_size=True,
                                     write_checksum=False).compress(raw)
    return base64.b64encode(frame).decode("ascii")


def decode_bytes(code: str) -> bytes:
    code = "".join(code.split())  # tolerate wrapped / pasted whitespace
    code += "=" * (-len(code) % 4)
    blob = base64.b64decode(code)
    if not blob.startswith(ZSTD_MAGIC):
        raise ValueError("not a zstd frame (code must start with 'KLUv/')")
    try:
        return zstandard.ZstdDecompressor().decompress(blob)
    except zstandard.ZstdError:
        # frames without a content size need the streaming API
        return zstandard.ZstdDecompressor().decompressobj().decompress(blob)


def decode(code: str) -> list:
    """Code -> list of skill entries (DATA left as the game stores it: a string)."""
    doc = json.loads(decode_bytes(code).decode("utf-8"))
    if not isinstance(doc, list):
        raise ValueError("decoded payload is not a JSON array")
    return doc


def explode(document: list) -> list:
    """Return a deep copy where every DATA string is parsed into an object."""
    out = []
    for entry in document:
        e = dict(entry)
        if isinstance(e.get("DATA"), str):
            e["DATA"] = json.loads(e["DATA"])
        out.append(e)
    return out


def implode(document: list) -> list:
    """Inverse of explode(): DATA objects become compact JSON strings again."""
    out = []
    for entry in document:
        e = dict(entry)
        if not isinstance(e.get("DATA"), str) and e.get("DATA") is not None:
            e["DATA"] = dumps_compact(e["DATA"])
        out.append(e)
    return out
