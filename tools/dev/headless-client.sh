#!/usr/bin/env bash
# Runs the dev client with no physical display: Xvfb + Mesa lavapipe (software Vulkan).
# Why Vulkan: Xvfb's GLX offers no sRGB-capable framebuffer configs, which Minecraft 26.3's
# OpenGL backend requires, so only the Vulkan backend works headless (see docs/PLAN.md WP-002 log).
#
# Usage:  tools/dev/headless-client.sh start [extra game args...]   # e.g. --quickPlaySingleplayer "World"
#         tools/dev/headless-client.sh screenshot <out.png>
#         tools/dev/headless-client.sh stop
set -euo pipefail

DISPLAY_NUM="${SIFT_XVFB_DISPLAY:-:98}"
STATE_DIR="${SIFT_DEV_STATE:-${TMPDIR:-/tmp}/thesift-headless}"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
mkdir -p "$STATE_DIR"

ensure_packages() {
	if [ ! -f /usr/share/vulkan/icd.d/lvp_icd.json ] || ! command -v Xvfb >/dev/null; then
		echo "Installing xvfb + mesa-vulkan-drivers (needs root and apt access)..." >&2
		apt-get update -qq && DEBIAN_FRONTEND=noninteractive apt-get install -y -qq xvfb mesa-vulkan-drivers
	fi
}

start() {
	ensure_packages
	if [ ! -f "$STATE_DIR/xvfb.pid" ] || ! kill -0 "$(cat "$STATE_DIR/xvfb.pid")" 2>/dev/null; then
		Xvfb "$DISPLAY_NUM" -screen 0 1280x720x24 -noreset >"$STATE_DIR/xvfb.log" 2>&1 &
		echo $! >"$STATE_DIR/xvfb.pid"
		sleep 2
	fi
	cd "$ROOT"
	DISPLAY="$DISPLAY_NUM" VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json \
		./gradlew runClient --console=plain --args="--graphicsBackend vulkan $*" >"$STATE_DIR/client.log" 2>&1 &
	echo $! >"$STATE_DIR/client.pid"
	echo "client starting; log: $STATE_DIR/client.log (wait for 'Created: ... atlas' lines)"
}

screenshot() {
	python3 -c "from PIL import ImageGrab; ImageGrab.grab(xdisplay='$DISPLAY_NUM').save('$1')"
	echo "saved $1"
}

stop() {
	# The game JVM is a grandchild of gradlew; stop it first so the world saves.
	for pid in $(ps -eo pid,args | awk '/[d]evlaunchinjector/ {print $1}'); do kill "$pid" || true; done
	sleep 3
	for f in client xvfb; do
		[ -f "$STATE_DIR/$f.pid" ] && kill "$(cat "$STATE_DIR/$f.pid")" 2>/dev/null || true
		rm -f "$STATE_DIR/$f.pid"
	done
}

cmd="${1:-}"; shift || true
case "$cmd" in
	start) start "$@" ;;
	screenshot) screenshot "${1:?output path}" ;;
	stop) stop ;;
	*) echo "usage: $0 start|screenshot <png>|stop" >&2; exit 2 ;;
esac
