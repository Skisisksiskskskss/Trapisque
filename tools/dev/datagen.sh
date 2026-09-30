#!/usr/bin/env bash
# Runs Fabric data generation. Datagen runs inside the 26.3 client (models are client-side), so it
# needs a display: this wraps it in Xvfb + Mesa lavapipe, like headless-client.sh (D-019).
#
# Usage:  tools/dev/datagen.sh           # regenerate src/main/generated
#         tools/dev/datagen.sh --check   # regenerate, then fail if anything under src/main/generated changed
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
DISPLAY_NUM="${SIFT_DATAGEN_DISPLAY:-:97}"
cd "$ROOT"

if [ ! -f /usr/share/vulkan/icd.d/lvp_icd.json ] || ! command -v Xvfb >/dev/null; then
	echo "Installing xvfb + mesa-vulkan-drivers (needs root and apt access)..." >&2
	if [ "$(id -u)" = 0 ]; then SUDO=""; else SUDO="sudo"; fi
	$SUDO apt-get update -qq && DEBIAN_FRONTEND=noninteractive $SUDO apt-get install -y -qq xvfb mesa-vulkan-drivers
fi

Xvfb "$DISPLAY_NUM" -screen 0 1280x720x24 -noreset >/dev/null 2>&1 &
XVFB_PID=$!
trap 'kill "$XVFB_PID" 2>/dev/null || true' EXIT
sleep 2

DISPLAY="$DISPLAY_NUM" VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json \
	./gradlew runDatagen --console=plain --args="--graphicsBackend vulkan"

if [ "${1:-}" = "--check" ]; then
	# Changed tracked files (working tree vs index) plus new untracked files.
	changes="$(git diff --name-only -- src/main/generated; git ls-files --others --exclude-standard -- src/main/generated)"
	if [ -n "$changes" ]; then
		echo "Datagen output differs from the committed files:" >&2
		echo "$changes" >&2
		git --no-pager diff --stat -- src/main/generated >&2
		exit 1
	fi
	echo "Datagen output matches the committed files (no diff)."
fi
