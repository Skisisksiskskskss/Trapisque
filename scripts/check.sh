#!/usr/bin/env bash
# Full quality gate: format check, selene lint, luau-lsp strict type check, unit tests, rojo build and the
# headless runtime check against the built place.
# Usage: bash scripts/check.sh [output.rbxlx]
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export PATH="$ROOT/tools/bin:$PATH"
cd "$ROOT"

echo "== stylua"
stylua --check src tests

echo "== selene"
selene src

echo "== luau-lsp analyze (strict)"
rojo sourcemap default.project.json -o sourcemap.json
luau-lsp analyze \
	--sourcemap=sourcemap.json \
	--definitions="$ROOT/tools/globalTypes.d.luau" \
	--base-luaurc=.luaurc \
	--no-strict-dm-types \
	--ignore="**/home/**" \
	src

echo "== unit tests (lune)"
lune run tests/run

OUT="${1:-builds/BeamABrainrot.rbxlx}"
echo "== rojo build -> $OUT"
rojo build default.project.json -o "$OUT"

echo "== headless runtime check"
lune run tests/runtime "$OUT"

if grep -rniE "\bTODO\b|\bFIXME\b|add your code here|\bstub\b" src >/dev/null; then
	echo "Found TODO/FIXME/stub markers in src:"
	grep -rniE "\bTODO\b|\bFIXME\b|add your code here|\bstub\b" src
	exit 1
fi
echo "ALL CHECKS PASSED"
