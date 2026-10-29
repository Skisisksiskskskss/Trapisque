#!/usr/bin/env bash
# Plays the whole game (server and client) on the fake Roblox in tests/fake, once per
# scenario: a PC, phones held sideways and upright, a team mode, the weekly event, Quick
# Play, the guided first match, a private match with house rules, and a match on each
# of the three newest maps, and one fishing between turns (cast, hook, the fight, a line
# let go on purpose). "art" is the owner's art note instead (tests/smoke/art.luau):
# the ids of the uploaded sheets pasted in, kept by the server, and the art loading.
# Each run joins, tours the lobby, plays a practice match to the end with the real
# controls and goes back to the lobby. Any error, warning or mangled remote / DataStore
# table fails it. See tests/smoke/smoke.luau.
#
#   tools/smoke.sh            every scenario
#   tools/smoke.sh pc phone   just these
#   LUAU=/path/to/luau tools/smoke.sh
set -euo pipefail
cd "$(dirname "$0")/.."
LUAU=${LUAU:-luau}
mkdir -p build/smoke

declare -A SCENARIOS=(
	[pc]='name = "pc", w = 1280, h = 720, mode = "chaos", map = "Slimy Snares", bots = 3, seed = 7'
	[phone]='name = "phone", w = 844, h = 390, touch = true, safe = { l = 47, r = 47, t = 0, b = 21 }, inset = 48, barLeft = 160, mode = "chaos", map = "Junction Dungeon", bots = 2, seed = 11'
	[upright]='name = "upright", w = 390, h = 844, touch = true, safe = { l = 0, r = 0, t = 47, b = 34 }, inset = 95, barLeft = 110, barRight = 340, mode = "chaos", map = "Blissful Tricks", bots = 1, seed = 5'
	[teams]='name = "teams", w = 1366, h = 768, mode = "assist", map = "Blissful Tricks", seed = 3'
	[party]='name = "party", w = 1920, h = 1080, mode = "party", map = "Junction Dungeon", bots = 3, seed = 9'
	[quickplay]='name = "quickplay", w = 1280, h = 800, mode = "chaos", quickplay = true, idle = true, seed = 13'
	[tutorial]='name = "tutorial", w = 1280, h = 720, tutorial = true, seed = 21'
	[private]='name = "private", w = 1280, h = 720, mode = "chaos", private = true, seed = 17'
	[frost]='name = "frost", w = 1280, h = 720, mode = "chaos", map = "Frostbite Floes", bots = 3, seed = 23'
	[kraken]='name = "kraken", w = 844, h = 390, touch = true, safe = { l = 47, r = 47, t = 0, b = 21 }, inset = 48, barLeft = 160, mode = "chaos", map = "Kraken'"'"'s Reach", bots = 3, seed = 29'
	[clockwork]='name = "clockwork", w = 1366, h = 768, mode = "chaos", map = "Clockwork Cove", bots = 3, seed = 31'
	[fish]='name = "fish", w = 1280, h = 720, mode = "chaos", map = "Blissful Tricks", bots = 3, seed = 37, fish = true'
	[art]='name = "art", w = 1280, h = 720'
)
ORDER=(pc phone upright teams party quickplay tutorial private frost kraken clockwork fish art)
if [ $# -gt 0 ]; then
	ORDER=("$@")
fi

failed=0
for name in "${ORDER[@]}"; do
	spec=${SCENARIOS[$name]:?unknown scenario $name}
	echo "SMOKE = { $spec }" > "build/smoke/$name.luau"
	script=tests/smoke/smoke.luau
	if [ "$name" = art ]; then
		script=tests/smoke/art.luau
	fi
	python3 tools/bundle.py --all "build/smoke/$name.run.luau" "build/smoke/$name.luau" \
		tests/fake/classes.luau tests/fake/fonts.luau tests/fake/roblox.luau "$script"
	if "$LUAU" "build/smoke/$name.run.luau" > "build/smoke/$name.out" 2>&1; then
		grep -E "^$name:" "build/smoke/$name.out" || true
		grep -E "^  " "build/smoke/$name.out" || true
	else
		failed=1
		echo "FAILED: $name (build/smoke/$name.out)"
		tail -40 "build/smoke/$name.out"
	fi
done
exit $failed
