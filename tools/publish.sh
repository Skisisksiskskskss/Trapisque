#!/usr/bin/env bash
# Publishes the game to Roblox without Studio: builds the place with Rojo (downloading
# it if it isn't installed) and uploads it with Roblox's Open Cloud Place Publishing API.
# Works from anywhere with a shell, e.g. a cloud session started from a phone.
#
#   ROBLOX_UNIVERSE_ID=... ROBLOX_PLACE_ID=... tools/publish.sh          live
#   ROBLOX_UNIVERSE_ID=... ROBLOX_PLACE_ID=... tools/publish.sh --saved  a saved version only
#
# ROBLOX_API_KEY: an Open Cloud API key with the "universe-places" (Place Publishing)
# Write permission for this experience. Keep it in the environment's secrets, never in
# the repo. (If the key is set up as a network secret that the proxy adds to requests
# to apis.roblox.com, leave ROBLOX_API_KEY unset.)
#
# The experience must already exist on Roblox (published once). Servers already running
# keep the old version until they're restarted (Creator Hub > the experience >
# Configure > Server Management > Restart Servers, or the owner panel's Shut Down All).
set -euo pipefail
cd "$(dirname "$0")/.."

: "${ROBLOX_UNIVERSE_ID:?set ROBLOX_UNIVERSE_ID (Creator Hub: the experience menu > Copy Universe ID)}"
: "${ROBLOX_PLACE_ID:?set ROBLOX_PLACE_ID (Creator Hub: the experience > Places > the start place > Copy Place ID)}"
VERSION_TYPE=Published
if [ "${1:-}" = "--saved" ]; then
	VERSION_TYPE=Saved
fi

# Rojo: the one on PATH, else a pinned release downloaded into build/tools
ROJO=${ROJO:-$(command -v rojo || true)}
if [ -z "$ROJO" ]; then
	ROJO_VERSION=7.7.1
	mkdir -p build/tools
	if [ ! -x build/tools/rojo ]; then
		echo "Downloading Rojo $ROJO_VERSION..."
		curl -sSfL -o build/tools/rojo.zip "https://github.com/rojo-rbx/rojo/releases/download/v$ROJO_VERSION/rojo-$ROJO_VERSION-linux-x86_64.zip"
		(cd build/tools && unzip -oq rojo.zip && chmod +x rojo)
	fi
	ROJO=build/tools/rojo
fi

mkdir -p build
"$ROJO" build default.project.json -o build/Trapisque.rbxl
echo "Uploading build/Trapisque.rbxl to place $ROBLOX_PLACE_ID ($VERSION_TYPE)..."

auth=()
if [ -n "${ROBLOX_API_KEY:-}" ]; then
	auth=(-H "x-api-key: $ROBLOX_API_KEY")
fi
response=$(curl -sS -w "\n%{http_code}" -X POST \
	"https://apis.roblox.com/universes/v1/$ROBLOX_UNIVERSE_ID/places/$ROBLOX_PLACE_ID/versions?versionType=$VERSION_TYPE" \
	"${auth[@]}" \
	-H "Content-Type: application/octet-stream" \
	--data-binary @build/Trapisque.rbxl)
code=$(printf '%s\n' "$response" | tail -n 1)
body=$(printf '%s\n' "$response" | sed '$d')
if [ "$code" = "200" ]; then
	echo "Published: $body"
else
	echo "Upload failed (HTTP $code): $body" >&2
	exit 1
fi
