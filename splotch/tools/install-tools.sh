#!/usr/bin/env bash
# Installs the pinned toolchain (Linux x86_64) into .tools/bin. Used by CI.
set -euo pipefail
dest="${1:-.tools/bin}"
mkdir -p "$dest"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

fetch() { # url
	curl -fsSL -o "$tmp/tool.zip" "$1"
	unzip -o -q "$tmp/tool.zip" -d "$dest"
}

fetch https://github.com/rojo-rbx/rojo/releases/download/v7.7.1/rojo-7.7.1-linux-x86_64.zip
fetch https://github.com/Kampfkarren/selene/releases/download/0.31.0/selene-0.31.0-linux.zip
fetch https://github.com/JohnnyMorganz/StyLua/releases/download/v2.6.0/stylua-linux-x86_64.zip
fetch https://github.com/lune-org/lune/releases/download/v0.11.1/lune-0.11.1-linux-x86_64.zip
chmod +x "$dest"/*
"$dest/rojo" --version
"$dest/selene" --version
"$dest/stylua" --version
"$dest/lune" --version
