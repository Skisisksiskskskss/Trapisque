#!/usr/bin/env bash
# Downloads the current Roblox Studio API dump (used by tools/check_api.py).
set -euo pipefail
out="${1:-build/api-dump.json}"
mkdir -p "$(dirname "$out")"
version=$(curl -fsS https://setup.rbxcdn.com/versionQTStudio)
curl -fsS -o "$out" "https://setup.rbxcdn.com/${version}-API-Dump.json"
echo "API dump for ${version} saved to ${out}"
