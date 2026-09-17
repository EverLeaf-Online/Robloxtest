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
BUILD_DIR="$REPO_ROOT/.build"
PLACE_FILE="$BUILD_DIR/ocale-tests.rbxl"
PUBLISH_RESPONSE="$BUILD_DIR/place-publish-response.json"

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

if ! command -v rojo >/dev/null 2>&1; then
  echo "rojo was not found in PATH." >&2
  exit 3
fi

if [[ ! -f "$PROJECT_FILE" || ! -f "$SPEC_FILE" ]]; then
  echo "Run this script from the repository root; test.project.json/spec.lua were not found." >&2
  exit 4
fi

mkdir -p "$BUILD_DIR"

echo "Building dedicated OCALE test place..."
rojo build "$PROJECT_FILE" --output "$PLACE_FILE"

publish_url="https://apis.roblox.com/universes/v1/${ROBLOX_UNIVERSE_ID}/places/${ROBLOX_PLACE_ID}/versions?versionType=Published"
version_number=""
max_publish_attempts=2

for attempt in $(seq 1 "$max_publish_attempts"); do
  rm -f "$PUBLISH_RESPONSE"

  set +e
  http_code="$(curl --silent --show-error --location \
    --connect-timeout 20 \
    --max-time 120 \
    --output "$PUBLISH_RESPONSE" \
    --write-out '%{http_code}' \
    --request POST "$publish_url" \
    --header "x-api-key: ${ROBLOX_API_KEY}" \
    --header "Content-Type: application/octet-stream" \
    --header "Accept: application/json" \
    --data-binary "@${PLACE_FILE}")"
  curl_status=$?
  set -e

  if [[ $curl_status -eq 0 && "$http_code" =~ ^2[0-9][0-9]$ ]]; then
    version_number="$(python3 - "$PUBLISH_RESPONSE" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as handle:
    data = json.load(handle)
version = data.get("versionNumber")
if not isinstance(version, int) or version <= 0:
    raise SystemExit("Roblox publish response did not contain a valid versionNumber")
print(version)
PY
)"
    break
  fi

  response_body=""
  if [[ -f "$PUBLISH_RESPONSE" ]]; then
    response_body="$(cat "$PUBLISH_RESPONSE")"
  fi

  if [[ $attempt -lt $max_publish_attempts ]] && { [[ $curl_status -ne 0 ]] || [[ "$http_code" == "409" ]] || [[ "$http_code" =~ ^5[0-9][0-9]$ ]]; }; then
    echo "Roblox place publish attempt ${attempt}/${max_publish_attempts} failed (curl=${curl_status}, HTTP=${http_code:-none}); retrying in 15s..." >&2
    sleep 15
    continue
  fi

  if [[ "$http_code" == "409" ]]; then
    echo "Roblox place publish is conflict-locked (HTTP 409)." >&2
    echo "The OCALE no-publish probe already proves the API key, universe/place pairing, and Luau Execution scope are valid." >&2
    echo "Close any active Roblox Studio/Team Create session for this test place, allow the edit session to release, then rerun." >&2
  else
    echo "Roblox place publish failed (curl=${curl_status}, HTTP=${http_code:-none})." >&2
  fi

  if [[ -n "$response_body" ]]; then
    echo "$response_body" >&2
  fi
  exit 5
done

if [[ -z "$version_number" ]]; then
  echo "Roblox place publish did not return a usable version number." >&2
  exit 5
fi

echo "Published OCALE test place version ${version_number}."
echo "Running Scrap-to-Bot Jest suite through Roblox Open Cloud Luau Execution..."

pushd "$ROCALE_WORKDIR" >/dev/null
"$ROCALE_CLI" run \
  --universeId "$ROBLOX_UNIVERSE_ID" \
  --placeId "$ROBLOX_PLACE_ID" \
  --load.version "$version_number" \
  --script "$SPEC_FILE" \
  --timeout 300 \
  --verbose
popd >/dev/null
