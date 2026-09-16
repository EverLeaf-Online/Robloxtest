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

REPO_ROOT="$(pwd)"
ROCALE_CLI="${ROCALE_CLI:-rocale-cli}"
ROCALE_WORKDIR="${ROCALE_WORKDIR:-$REPO_ROOT}"
PROJECT_FILE="$REPO_ROOT/test.project.json"
SPEC_FILE="$REPO_ROOT/spec.lua"

if [[ "$ROCALE_CLI" == */* ]]; then
  if [[ ! -x "$ROCALE_WORKDIR/$ROCALE_CLI" ]]; then
    echo "rocale-cli was not found at: $ROCALE_WORKDIR/$ROCALE_CLI" >&2
    exit 3
  fi
elif ! command -v "$ROCALE_CLI" >/dev/null 2>&1; then
  echo "rocale-cli was not found in PATH." >&2
  echo "Install the official Roblox/rocale-cli before running OCALE tests." >&2
  exit 3
fi

if [[ ! -f "$PROJECT_FILE" || ! -f "$SPEC_FILE" ]]; then
  echo "Run this script from the repository root; test.project.json/spec.lua were not found." >&2
  exit 4
fi

echo "Running Scrap-to-Bot Jest suite through Roblox Open Cloud Luau Execution..."

pushd "$ROCALE_WORKDIR" >/dev/null
"$ROCALE_CLI" run \
  --universeId "$ROBLOX_UNIVERSE_ID" \
  --placeId "$ROBLOX_PLACE_ID" \
  --load.project "$PROJECT_FILE" \
  --script "$SPEC_FILE" \
  --timeout 300 \
  --verbose
popd >/dev/null
