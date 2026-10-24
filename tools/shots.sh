#!/usr/bin/env bash
# Screenshots of the real game (the smoke test's run, on the fake Roblox) into
# docs/previews/shots: the lobby, its pages, the character picker, a match and the
# results, on a PC and on phones. Needs Python 3 with Pillow and the fonts (see
# tools/preview/shot.py).
#
#   tools/shots.sh [pc phone upright ...]     (default: pc phone upright)
#   tools/shots.sh private                    a private match's settings and map vote
#   tools/shots.sh art store                  the store icon and banner, and store
#                                             screenshots (OUT=docs/store)
#   tools/shots.sh badges                     the badge icons (OUT=docs/store: badges/*.png)
#   tools/shots.sh thumbs                     the map vote's pictures of the maps
#                                             (art/maps/*.png; then tools/art.py)
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
	[thumbs]='name = "boards", w = 640, h = 360, orient = "flat", thumbs = true'
	[crew]='name = "crew", w = 1500, h = 900'
	[art]='name = "art", w = 1920, h = 1080'
	[badges]='name = "badges", w = 512, h = 512'
	[store]='name = "store", w = 1920, h = 1080, mode = "chaos", map = "Blissful Tricks", bots = 3, seed = 21, store = true, player = "Marlin"'
	[private]='name = "private", w = 1366, h = 768, mode = "chaos", private = true, seed = 17'
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
	if [ "$name" = boards ] || [ "$name" = thumbs ]; then
		script=tests/smoke/boards.luau # just the maps
	elif [ "$name" = crew ]; then
		script=tests/smoke/crew.luau # just the characters
	elif [ "$name" = art ] || [ "$name" = badges ]; then
		script=tests/smoke/store.luau # the store icon and banner, or the badge icons
	fi
	python3 tools/bundle.py --all "build/shots/$name.run.luau" "build/shots/$name.luau" \
		tests/fake/classes.luau tests/fake/fonts.luau tests/fake/roblox.luau tests/fake/shots.luau "$script"
	if [ "$name" = thumbs ]; then
		# drawn at 640 x 360, kept at half that (art/maps, packed by tools/art.py)
		mkdir -p build/thumbs art/maps
		"$LUAU" "build/shots/$name.run.luau" | python3 tools/preview/shot.py build/thumbs
		python3 -c "
import glob, os
from PIL import Image
for f in sorted(glob.glob('build/thumbs/*.png')):
    Image.open(f).convert('RGB').resize((320, 180), Image.LANCZOS).save(os.path.join('art/maps', os.path.basename(f)), optimize=True)
    print('art/maps/' + os.path.basename(f))
"
		continue
	fi
	"$LUAU" "build/shots/$name.run.luau" | python3 tools/preview/shot.py "$OUT"
done
