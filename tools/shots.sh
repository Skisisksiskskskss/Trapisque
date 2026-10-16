#!/usr/bin/env bash
# Screenshots of the real game (the smoke test's run, on the fake Roblox) into
# docs/previews/shots: the lobby, its pages, the character picker, a match and the
# results, on a PC and on phones. Needs Python 3 with Pillow and the fonts (see
# tools/preview/shot.py).
#
#   tools/shots.sh [pc phone upright ...]     (default: pc phone upright)
#   LUAU=/path/to/luau OUT=dir tools/shots.sh
set -euo pipefail
cd "$(dirname "$0")/.."
LUAU=${LUAU:-luau}
OUT=${OUT:-docs/previews/shots}
mkdir -p build/shots "$OUT"
declare -A SCENARIOS=(
	[pc]='name = "pc", w = 1920, h = 1080, mode = "chaos", map = "Slimy Snares", bots = 3, seed = 7'
	[laptop]='name = "laptop", w = 1366, h = 768, mode = "chaos", map = "Junction Dungeon", bots = 3, seed = 4'
	[phone]='name = "phone", w = 844, h = 390, touch = true, safe = { l = 47, r = 47, t = 0, b = 21 }, inset = 48, barLeft = 160, mode = "chaos", map = "Junction Dungeon", bots = 2, seed = 11'
	[boards]='name = "boards", w = 1600, h = 900'
	[upright]='name = "upright", w = 390, h = 844, touch = true, safe = { l = 0, r = 0, t = 47, b = 34 }, inset = 95, barLeft = 110, barRight = 340, mode = "chaos", map = "Blissful Tricks", bots = 3, seed = 5'
)
ORDER=(pc phone upright)
if [ $# -gt 0 ]; then
	ORDER=("$@")
fi
for name in "${ORDER[@]}"; do
	spec=${SCENARIOS[$name]:?unknown scenario $name}
	echo "SMOKE = { $spec, shots = true }" > "build/shots/$name.luau"
	script=tests/smoke/smoke.luau
	if [ "$name" = boards ]; then
		script=tests/smoke/boards.luau # just the maps
	fi
	python3 tools/bundle.py --all "build/shots/$name.run.luau" "build/shots/$name.luau" \
		tests/fake/classes.luau tests/fake/fonts.luau tests/fake/roblox.luau tests/fake/shots.luau "$script"
	"$LUAU" "build/shots/$name.run.luau" | python3 tools/preview/shot.py "$OUT"
done
