#!/usr/bin/env bash
# Runs the client GameTests (preview screenshots) under Xvfb + Mesa lavapipe, like datagen.sh.
# Screenshots: build/run/clientGameTest/screenshots/
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
DISPLAY_NUM="${SIFT_CLIENTTEST_DISPLAY:-:96}"
cd "$ROOT"
Xvfb "$DISPLAY_NUM" -screen 0 1280x720x24 -noreset >/dev/null 2>&1 &
XVFB_PID=$!
trap 'kill "$XVFB_PID" 2>/dev/null || true' EXIT
sleep 2
DISPLAY="$DISPLAY_NUM" VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json ALSOFT_DRIVERS=null \
	./gradlew runClientGameTest --console=plain --args="--graphicsBackend vulkan"
