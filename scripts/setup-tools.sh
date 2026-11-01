#!/usr/bin/env bash
# Downloads the pinned toolchain into ./tools/bin (gitignored).
# Usage: bash scripts/setup-tools.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BIN="$ROOT/tools/bin"
mkdir -p "$BIN"
cd "$ROOT/tools"

fetch() {
	local name="$1" url="$2"
	if [ ! -f "$name.zip" ]; then
		curl -sSL --retry 4 -o "$name.zip" "$url"
	fi
	unzip -o -q "$name.zip" -d "$BIN"
}

fetch rojo "https://github.com/rojo-rbx/rojo/releases/download/v7.4.4/rojo-7.4.4-linux-x86_64.zip"
fetch selene "https://github.com/Kampfkarren/selene/releases/download/0.27.1/selene-0.27.1-linux.zip"
fetch luau-lsp "https://github.com/JohnnyMorganz/luau-lsp/releases/download/1.38.1/luau-lsp-linux.zip"
fetch lune "https://github.com/lune-org/lune/releases/download/v0.8.9/lune-0.8.9-linux-x86_64.zip"
fetch stylua "https://github.com/JohnnyMorganz/StyLua/releases/download/v0.20.0/stylua-linux-x86_64.zip"
chmod +x "$BIN"/*

if [ ! -f "$ROOT/tools/globalTypes.d.luau" ]; then
	curl -sSL --retry 4 -o "$ROOT/tools/globalTypes.d.luau" \
		"https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/1.38.1/scripts/globalTypes.d.luau" \
		|| curl -sSL --retry 4 -o "$ROOT/tools/globalTypes.d.luau" \
			"https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/main/scripts/globalTypes.d.luau"
fi
echo "Tools installed in $BIN"
