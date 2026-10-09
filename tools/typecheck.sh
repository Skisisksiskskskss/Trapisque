#!/usr/bin/env bash
# Developer tool: type-check the project against Roblox API definitions with luau-lsp.
#
# Every file is copied into a temp tree with `--!strict` prepended (nonstrict mode does
# not report unknown properties), then we keep the errors that point at real mistakes:
# unknown members on Roblox types, wrong argument counts, unknown globals, syntax errors.
#
# Needs: rojo, luau-lsp and Roblox definitions (globalTypes.d.luau from the luau-lsp repo).
#   DEFS=/path/to/globalTypes.d.luau tools/typecheck.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEFS="${DEFS:-$ROOT/.luau/globalTypes.d.luau}"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

cp "$ROOT/default.project.json" "$WORK/"
mkdir -p "$WORK/src"
cp -r "$ROOT/src/." "$WORK/src/"
find "$WORK/src" -name '*.lua' -o -name '*.luau' | while read -r f; do
  if ! head -1 "$f" | grep -q -- '--!'; then
    printf -- '--!strict\n' | cat - "$f" > "$f.tmp" && mv "$f.tmp" "$f"
  fi
done

cd "$WORK"
rojo sourcemap default.project.json -o sourcemap.json >/dev/null
set +e
luau-lsp analyze --definitions="$DEFS" --sourcemap=sourcemap.json src > analyze.txt 2>&1
set -e
# line numbers are shifted by one because of the inserted header
grep -E "not found in (external )?type|Argument count mismatch|Unknown global|SyntaxError|is not a function|cannot be called|ImportUnused|LocalShadow|UnknownGlobal|DeprecatedApi|FunctionUnused|BuiltinGlobalWrite|DuplicateLocal|LocalUnused|Unknown require|could not be resolved" analyze.txt \
  | sed "s#$WORK/##g" | sort -u || true
echo "(raw report: $(wc -l < analyze.txt) lines)"
