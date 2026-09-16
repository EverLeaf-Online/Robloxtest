#!/usr/bin/env bash
set -euo pipefail

require_env() {
  local name="$1"
  if [[ -z "${!name:-}" ]]; then
    echo "Missing required environment variable: ${name}" >&2
    exit 2
  fi
}

require_env ROBLOX_API_KEY
require_env ROBLOX_UNIVERSE_ID
require_env ROBLOX_PLACE_ID

if ! command -v rocale-cli >/dev/null 2>&1; then
  echo "rocale-cli was not found in PATH." >&2
  echo "Install the official Roblox/rocale-cli before running OCALE tests." >&2
  exit 3
fi

if [[ ! -f test.project.json || ! -f spec.lua ]]; then
  echo "Run this script from the repository root; test.project.json/spec.lua were not found." >&2
  exit 4
fi

echo "Running Scrap-to-Bot Jest suite through Roblox Open Cloud Luau Execution..."

rocale-cli run \
  --universeId "$ROBLOX_UNIVERSE_ID" \
  --placeId "$ROBLOX_PLACE_ID" \
  --load.project test.project.json \
  --script spec.lua \
  --timeout 300 \
  --verbose
